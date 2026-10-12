import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/send_notification.dart';
import 'package:vendor/models/conversation_model.dart';
import 'package:vendor/models/inbox_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/push_payload.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/utils/store_chat.dart';
import 'package:vendor/utils/store_chat_session.dart';

class ChatController extends GetxController {
  Rx<TextEditingController> messageController = TextEditingController().obs;

  Rx<ScrollController> scrollController = ScrollController().obs;

  @override
  void onInit() {
    if (scrollController.value.hasClients) {
      Timer(const Duration(milliseconds: 500), () => scrollController.value.jumpTo(scrollController.value.position.minScrollExtent));
    }
    getArgument();
    super.onInit();
  }

  RxBool isLoading = true.obs;
  RxString orderId = "".obs;
  RxString receivedId = "".obs;
  RxString receivedName = "".obs;
  RxString receivedProfileUrl = "".obs;
  RxString senderId = "".obs;
  RxString senderName = "".obs;
  RxString senderProfileUrl = "".obs;
  RxString token = "".obs;
  RxString chatType = "".obs;
  RxString sectionType = "".obs;
  Rx<UserModel?> receiverUser = UserModel().obs;

  /// The store side of this chat for the signed-in user (lib/utils/store_chat.dart).
  /// For an employee it replaces [senderId] / [senderName] /
  /// [senderProfileUrl] with the store's, so the employee reads, marks seen
  /// and writes the conversation exactly as the owner does.
  Rx<StoreChatIdentity?> identity = Rx<StoreChatIdentity?>(null);

  /// The signed-in user is an employee whose store identity could not be
  /// read, or whose role does not allow chats: nothing is read or written.
  bool get _employeeBlocked => identity.value?.isEmployee == true && identity.value?.ready != true;

  /// Who the messages of the store side are written as: the store's chat id
  /// for an employee, the signed-in user (as before) for the owner.
  String get _writerId => identity.value?.isEmployee == true ? identity.value!.senderId : FireStoreUtils.getCurrentUid();

  /// A message of the thread is the store side's own (shown on the right).
  bool isStoreSide(String? messageSenderId) {
    final StoreChatIdentity? me = identity.value;
    if (me != null && me.isEmployee) return me.isStoreSide(messageSenderId);
    return messageSenderId == FireStoreUtils.getCurrentUid();
  }

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      sectionType.value = argumentData['sectionType'] ?? '';
      orderId.value = argumentData['orderId'] ?? '';
      receivedId.value = argumentData['receivedId'] ?? '';
      receivedName.value = argumentData['receivedName'] ?? '';
      receivedProfileUrl.value = argumentData['receivedProfileUrl'] ?? "";
      senderId.value = argumentData['senderId'] ?? '';
      senderName.value = argumentData['senderName'] ?? '';
      senderProfileUrl.value = argumentData['senderProfileUrl'] ?? "";
      token.value = argumentData['token'] ?? '';
      chatType.value = argumentData['chatType'] ?? '';
      await _applyStoreIdentity();
      if (_employeeBlocked) {
        isLoading.value = false;
        ShowToastDialog.showToast("You don’t have permission to view chats.".tr);
        if (!isClosed) Get.back();
        return;
      }
      if (receivedId.value != 'admin') {
        // getUserById, not getUserProfile: getUserProfile also makes the user
        // it reads the session's user (Constant.userModel), so after opening
        // a chat the store was signed in as the customer - and sign-out then
        // wiped the customer's FCM token.
        receiverUser.value = await FireStoreUtils.getUserById(receivedId.value);
      }
    }
    setSeen();

    isLoading.value = false;
  }

  /// An employee chats as the store: the store's chat id, the store's name
  /// and picture. The owner keeps what the opening screen passed.
  Future<void> _applyStoreIdentity() async {
    if (!StoreChatSession.isEmployee) return;
    final StoreChatIdentity? me = await StoreChatSession.resolve();
    identity.value = me ??
        StoreChatIdentity(storeId: '', actorId: FireStoreUtils.getCurrentUid(), isEmployee: true, canChat: false);
    if (me == null || !me.isEmployee || !me.ready) return;
    senderId.value = me.senderId;
    if (me.displayName.isNotEmpty) senderName.value = me.displayName;
    if (me.photo.isNotEmpty) senderProfileUrl.value = me.photo;
  }

  /// Marks the store side's unread messages of this conversation seen while
  /// it is open (the same messages the inbox badge counts,
  /// `lib/utils/chat_unread.dart`): an admin conversation's messages from
  /// `admin`, any other conversation's messages whose receiver is the store
  /// side ([senderId], the store user the screen was opened for; the
  /// signed-in user when it is missing). Stopped in [onClose].
  Future<void> setSeen() async {
    // Left before the receiver lookup finished: onClose already ran, so a
    // listener started now would never be stopped.
    if (isClosed || _employeeBlocked) return;
    if (receivedId.value == 'admin' || chatType.value == 'admin') {
      FireStoreUtils.setSeenChatForOrder(orderId: orderId.value, senderId: Constant.adminType);
    } else {
      final String me = senderId.value.trim().isNotEmpty ? senderId.value.trim() : FireStoreUtils.getCurrentUid();
      FireStoreUtils.setSeenChatForOrder(orderId: orderId.value, receiverId: me);
    }
  }

  @override
  void onClose() {
    // The listener used to outlive the screen, so messages that arrived after
    // the store left the conversation were marked seen at once.
    FireStoreUtils.stopSeenChatForOrder();
    super.onClose();
  }

  Future<void> sendMessage(String message, Url? url, String videoThumbnail, String messageType) async {
    if (_employeeBlocked) {
      ShowToastDialog.showToast("You don’t have permission to view chats.".tr);
      return;
    }
    List<String> senderReceiverId = [receivedId.value, senderId.value];
    InboxModel inboxModel = InboxModel(
      chatType: chatType.value,
      senderReceiverId: senderReceiverId,
      lastSenderId: senderId.value,
      senderId: senderId.value,
      receiverId: receivedId.value,
      createdAt: Timestamp.now(),
      orderId: orderId.value,
      lastMessage: messageController.value.text,
      lastMessageType: messageType,
      type: chatType.value == 'admin' ? 'admin' : 'orderChat',
    );

    FireStoreUtils.addInbox(inboxModel);

    ConversationModel conversationModel = ConversationModel(
      id: const Uuid().v4(),
      message: message,
      senderId: _writerId,
      receiverId: receivedId.value,
      createdAt: Timestamp.now(),
      url: url,
      orderId: orderId.value,
      messageType: messageType,
      videoThumbnail: videoThumbnail,
      seen: false,
      // An employee's message: who actually wrote it (audit only).
      sentByUserId: identity.value?.auditFields['sentByUserId'],
      sentByName: identity.value?.auditFields['sentByName'],
    );

    if (url != null) {
      if (url.mime.contains('image')) {
        conversationModel.message = "sent a message".tr;
      } else if (url.mime.contains('video')) {
        conversationModel.message = "Sent a video".tr;
      } else if (url.mime.contains('audio')) {
        conversationModel.message = "Sent a audio".tr;
      }
    }

    FireStoreUtils.addChat(conversationModel);
    // No token in the log.
    log("receiverUser.value :: ${receiverUser.value?.id} :: ${inboxModel.type} :: ${inboxModel.chatType}");
    await notifyRecipient(conversationModel.message.toString(), inboxModel);
  }

  /// Push for a message the store just sent (report #3).
  ///
  /// Reached from every send path, because text, image and video all go through
  /// [sendMessage]. Two things were wrong before: the notification was titled
  /// with the *recipient's* own name, and an empty token - or a recipient whose
  /// profile had not been read yet - passed the old `!= null` check and the push
  /// went nowhere. The recipient's current token is read from their user record
  /// at send time, and a recipient with no token at all is skipped (logged): a
  /// chat message must never fail because of its notification.
  Future<void> notifyRecipient(String message, InboxModel inboxModel) async {
    if (receivedId.value.isEmpty || receivedId.value == 'admin') return;
    // SendNotification reads the recipient's current token from their user
    // record (recipientId); the copy loaded with the chat is the fallback.
    final String fcmToken = receiverUser.value?.fcmToken ?? '';
    try {
      await SendNotification.sendChatFcmMessage(
        senderName.value.isEmpty ? "New message".tr : senderName.value,
        message,
        fcmToken,
        {'type': inboxModel.type, 'chatType': inboxModel.chatType, 'orderId': orderId.value, 'senderId': _writerId},
        recipientId: receivedId.value,
        recipient: PushPayload.recipientForRole(receiverUser.value?.role),
      );
    } catch (e) {
      log("chat push failed: $e");
    }
  }

  final ImagePicker imagePicker = ImagePicker();

  // Future pickFile({required ImageSource source}) async {
  //   try {
  //     XFile? image = await imagePicker.pickImage(source: source);
  //     if (image == null) return;
  //     Url url = await FireStoreUtils.uploadChatImageToFireStorage(File(image.path), Get.context!);
  //     sendMessage('', url, '', 'image');
  //     Get.back();
  //   } on PlatformException catch (e) {
  //     ShowToastDialog.showToast("${"failed_to_pick".tr} : \n $e");
  //   }
  // }
}

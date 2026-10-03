import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:vendor/constant/send_notification.dart';
import 'package:vendor/models/conversation_model.dart';
import 'package:vendor/models/inbox_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/push_payload.dart';

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

  Future<void> setSeen() async {
    FireStoreUtils.setSeenChatForOrder(orderId: orderId.value);
  }

  Future<void> sendMessage(String message, Url? url, String videoThumbnail, String messageType) async {
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
      senderId: FireStoreUtils.getCurrentUid(),
      receiverId: receivedId.value,
      createdAt: Timestamp.now(),
      url: url,
      orderId: orderId.value,
      messageType: messageType,
      videoThumbnail: videoThumbnail,
      seen: false,
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
        {'type': inboxModel.type, 'chatType': inboxModel.chatType, 'orderId': orderId.value, 'senderId': FireStoreUtils.getCurrentUid()},
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

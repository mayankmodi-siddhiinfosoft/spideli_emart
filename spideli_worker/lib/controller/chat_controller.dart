import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliworker/model/conversation_model.dart';
import 'package:spideliworker/model/inbox_model.dart';
import 'package:spideliworker/model/user.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/utils/args.dart';
import 'package:spideliworker/services/push_message.dart';
import 'package:spideliworker/services/send_notification.dart';
import 'package:spideliworker/main.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

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
  Rx<User?> receiverUser = User().obs;

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      // `?? ''` only covered an explicit null: a non-String value (a push
      // payload field, an id that arrived as a number) still threw a TypeError
      // here, which left every argument after it unset. See [argString].
      sectionType.value = argString(argumentData, 'sectionType');
      orderId.value = argString(argumentData, 'orderId');
      receivedId.value = argString(argumentData, 'receivedId');
      receivedName.value = argString(argumentData, 'receivedName');
      receivedProfileUrl.value = argString(argumentData, 'receivedProfileUrl');
      senderId.value = argString(argumentData, 'senderId');
      senderName.value = argString(argumentData, 'senderName');
      senderProfileUrl.value = argString(argumentData, 'senderProfileUrl');
      token.value = argString(argumentData, 'token');
      chatType.value = argString(argumentData, 'chatType');
      if (senderId.value.isEmpty) senderId.value = FireStoreUtils.getCurrentUid();
      if (receivedId.value.isNotEmpty && receivedId.value != 'admin') {
        // Side-effect free, and falls back to the workers collection, so the
        // recipient's FCM token actually resolves. An empty id would be a
        // `doc("")` lookup, which throws.
        receiverUser.value = await FireStoreUtils.getChatUser(receivedId.value) ?? receiverUser.value;
      }
    }
    setSeen();

    isLoading.value = false;
  }

  Future<void> setSeen() async {
    // `doc("")` is not a legal Firestore path and throws.
    if (orderId.value.isEmpty) return;
    FireStoreUtils.setSeenChatForOrder(orderId: orderId.value);
  }

  Future<void> sendMessage(String message, Url? url, String videoThumbnail, String messageType) async {
    // The thread document is keyed by the order id and the message is addressed
    // to the recipient; without either there is nothing to write to (Firestore
    // refuses an empty document path).
    if (orderId.value.isEmpty || receivedId.value.isEmpty) {
      ShowToastDialog.showToast("This conversation could not be opened. Open it again from the booking.".tr);
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

    await FireStoreUtils.addChat(conversationModel);
    await _notifyRecipient(conversationModel, inboxModel);
  }

  /// Pushes the message to the recipient. Every send path -- text, image,
  /// video, camera -- goes through [sendMessage], so this covers all of them.
  ///
  /// The recipient is re-read when the profile was not resolved at open time
  /// (the first message used to go out with no push at all in that case), and a
  /// missing or empty token is a silent no-op rather than an FCM call that
  /// fails with a 400.
  Future<void> _notifyRecipient(ConversationModel conversationModel, InboxModel inboxModel) async {
    try {
      final bool canLookUp = receivedId.value.isNotEmpty && receivedId.value != 'admin';
      bool reread = false;
      if (!isUsableFcmToken(receiverUser.value?.fcmToken) && canLookUp) {
        receiverUser.value = await FireStoreUtils.getChatUser(receivedId.value);
        reread = true;
      }
      String token = receiverUser.value?.fcmToken ?? '';
      log("chat push :: token=${isUsableFcmToken(token) ? 'set' : 'none'} :: ${inboxModel.type} :: ${inboxModel.chatType}");
      if (!isUsableFcmToken(token)) return;

      // Title is who sent it (this worker): the recipient used to see their
      // own name when the chat was opened without a sender name (from a push).
      final String me = senderName.value.trim().isNotEmpty ? senderName.value : (MyAppState.currentUser?.fullName().trim() ?? '');
      final String title = me.isNotEmpty ? me : "New message".tr;
      final Map<String, dynamic> payload = {
        'type': inboxModel.type,
        'chatType': inboxModel.chatType,
        'orderId': orderId.value,
        'senderId': FireStoreUtils.getCurrentUid(),
        'senderName': me,
      };
      final bool sent = await SendNotification.sendChatFcmMessage(title, conversationModel.message.toString(), token, payload);
      if (!sent && !reread && canLookUp) {
        // The token read when the chat was opened may have rotated since:
        // read the recipient again and retry once with a changed token.
        receiverUser.value = await FireStoreUtils.getChatUser(receivedId.value);
        final String fresh = receiverUser.value?.fcmToken ?? '';
        if (isUsableFcmToken(fresh) && fresh.trim() != token.trim()) {
          token = fresh;
          await SendNotification.sendChatFcmMessage(title, conversationModel.message.toString(), token, payload);
        }
      }
    } catch (e) {
      // A chat message must never fail because the push could not be sent.
      log("Chat notification not sent: $e");
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

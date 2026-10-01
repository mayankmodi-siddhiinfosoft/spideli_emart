import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/conversation_model.dart';
import 'package:driver/models/inbox_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/args.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class ChatController extends GetxController {
  Rx<TextEditingController> messageController = TextEditingController().obs;

  Rx<ScrollController> scrollController = ScrollController().obs;

  @override
  void onInit() {
    getArgument();
    super.onInit();
  }

  RxBool isLoading = true.obs;
  RxString orderId = "".obs;
  RxString senderId = "".obs;
  RxString senderName = "".obs;
  RxString senderProfileUrl = "".obs;
  RxString receivedId = "".obs;
  RxString receivedName = "".obs;
  RxString receivedProfileUrl = "".obs;
  RxString token = "".obs;
  RxString chatType = "".obs;
  Rx<UserModel?> receiverUser = UserModel().obs;

  /// Reads one argument as a plain string — see [argString] for why every one
  /// of them has to go through a guard.
  static String _arg(dynamic data, String key) => argString(data, key);

  Future<void> getArgument() async {
    // if (scrollController.value.hasClients) {
    //   Timer(const Duration(milliseconds: 500), () => scrollController.value.jumpTo(scrollController.value.position.minScrollExtent));
    // }
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      orderId.value = _arg(argumentData, 'orderId');
      senderId.value = _arg(argumentData, 'senderId');
      senderName.value = _arg(argumentData, 'senderName');
      senderProfileUrl.value = _arg(argumentData, 'senderProfileUrl');
      receivedId.value = _arg(argumentData, 'receivedId');
      receivedName.value = _arg(argumentData, 'receivedName');
      receivedProfileUrl.value = _arg(argumentData, 'receivedProfileUrl');
      token.value = _arg(argumentData, 'token');
      chatType.value = _arg(argumentData, 'chatType');
      if (senderId.value.isEmpty) senderId.value = FireStoreUtils.getCurrentUid();
      if (receivedId.value.isNotEmpty) {
        receiverUser.value = await FireStoreUtils.getUserProfile(receivedId.value);
      }
    }
    setSeen();
    isLoading.value = false;
  }

  Future<void> setSeen() async {
    if (orderId.value.isEmpty) return;
    FireStoreUtils.setSeenChatForOrder(orderId: orderId.value);
  }

  Future<void> sendMessage(String message, Url? url, String videoThumbnail, String messageType) async {
    // The thread document is keyed by the order id; without one there is
    // nothing to write to (Firestore refuses an empty document path).
    if (orderId.value.isEmpty || receivedId.value.isEmpty) {
      ShowToastDialog.showToast("This conversation could not be opened. Open it again from the order.".tr);
      return;
    }
    List<String> senderReceiverId = [senderId.value, receivedId.value];
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
        type: 'orderChat');

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
        seen: false);

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

    await sendChatPush(conversationModel.message.toString(), inboxModel.type ?? 'orderChat', inboxModel.chatType ?? chatType.value);
  }

  /// Client point 3 — a chat message must reach the other side as a push.
  ///
  /// The recipient's token is the live one on their user document, falling
  /// back to the token the opening screen passed in. With no token at all the
  /// message is still stored and the push is skipped silently.
  Future<void> sendChatPush(String message, String type, String chatType) async {
    String recipientToken = (receiverUser.value?.fcmToken ?? '').trim();
    if (recipientToken.isEmpty && receivedId.value.isNotEmpty) {
      // The receiver may have signed in on another device since this screen
      // was opened; re-read once before giving up.
      receiverUser.value = await FireStoreUtils.getUserProfile(receivedId.value) ?? receiverUser.value;
      recipientToken = (receiverUser.value?.fcmToken ?? '').trim();
    }
    if (recipientToken.isEmpty) recipientToken = token.value.trim();
    if (recipientToken.isEmpty) return;

    try {
      await SendNotification.sendChatFcmMessage(
        senderName.value.isEmpty ? "New message".tr : senderName.value,
        message,
        recipientToken,
        {
          'type': type,
          'chatType': chatType,
          'orderId': orderId.value,
          'senderId': senderId.value,
        },
      );
    } catch (e) {
      log("ChatController.sendChatPush failed: $e");
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

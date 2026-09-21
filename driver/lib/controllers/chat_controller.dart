import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/models/conversation_model.dart';
import 'package:driver/models/inbox_model.dart';
import 'package:driver/models/user_model.dart';
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

  Future<void> getArgument() async {
    // if (scrollController.value.hasClients) {
    //   Timer(const Duration(milliseconds: 500), () => scrollController.value.jumpTo(scrollController.value.position.minScrollExtent));
    // }
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      orderId.value = argumentData['orderId'];
      senderId.value = argumentData['senderId'];
      senderName.value = argumentData['senderName'];
      senderProfileUrl.value = argumentData['senderProfileUrl'] ?? "";
      receivedId.value = argumentData['receivedId'];
      receivedName.value = argumentData['receivedName'];
      receivedProfileUrl.value = argumentData['receivedProfileUrl'] ?? "";
      token.value = argumentData['token'];
      chatType.value = argumentData['chatType'];
      receiverUser.value = await FireStoreUtils.getUserProfile(receivedId.value);
    }
    setSeen();
    isLoading.value = false;
  }

  Future<void> setSeen() async {
    FireStoreUtils.setSeenChatForOrder(orderId: orderId.value);
  }

  Future<void> sendMessage(String message, Url? url, String videoThumbnail, String messageType) async {
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

    SendNotification.sendChatFcmMessage(senderName.value, conversationModel.message.toString(), receiverUser.value?.fcmToken ?? '', {'type': inboxModel.type, 'chatType': inboxModel.chatType});
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

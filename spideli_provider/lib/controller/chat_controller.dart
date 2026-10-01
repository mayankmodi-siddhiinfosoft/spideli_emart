import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/model/conversation_model.dart';
import 'package:spideliprovider/model/inbox_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/utils/args.dart';
import 'package:spideliprovider/services/send_notification.dart';
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
      if ((receiverUser.value?.fcmToken ?? '').isEmpty && receivedId.value.isNotEmpty && receivedId.value != 'admin') {
        receiverUser.value = await FireStoreUtils.getChatUser(receivedId.value);
      }
      final String token = receiverUser.value?.fcmToken ?? '';
      log("chat push :: to=${receiverUser.value?.fullName()} :: token=${token.isEmpty ? 'none' : 'set'} :: ${inboxModel.type} :: ${inboxModel.chatType}");
      if (token.isEmpty) return;

      // Title is who sent it: the recipient used to see their own name.
      final String title = senderName.value.trim().isNotEmpty ? senderName.value : receivedName.value;
      await SendNotification.sendChatFcmMessage(title, conversationModel.message.toString(), token, {
        'type': inboxModel.type,
        'chatType': inboxModel.chatType,
        'orderId': orderId.value,
        'senderId': FireStoreUtils.getCurrentUid(),
        'senderName': senderName.value,
      });
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

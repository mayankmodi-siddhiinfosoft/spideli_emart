import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/conversation_model.dart';
import 'package:vendor/models/inbox_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/preferences.dart';

class HelpSupportController extends GetxController {
  Rx<TextEditingController> messageController = TextEditingController().obs;
  Rx<UserModel> userModel = UserModel().obs;
  Rx<ScrollController> scrollController = ScrollController().obs;

  @override
  void onInit() {
    setSeen();
    setPref();
    super.onInit();
  }

  @override
  void onClose() {
    FireStoreUtils.stopSeenListener();
    super.onClose();
  }

  Future<void> setPref() async {
    await Preferences.setBoolean(Preferences.isClickOnNotification, false);
  }

  Future<void> setSeen() async {
    FireStoreUtils.setSeen();
    await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) {
      if (value?.id != null) {
        userModel.value = value!;
      }
    });
  }

  Future<void> sendMessage({required String message, Url? url, required String videoThumbnail, required String messageType}) async {
    List<String> senderReceiverId = [userModel.value.id!, 'admin'];
    InboxModel inboxModel = InboxModel(
      senderReceiverId: senderReceiverId,
      chatType: Constant.userRoleVendor,
      lastSenderId: userModel.value.id,
      senderId: userModel.value.id,
      receiverId: 'admin',
      createdAt: Timestamp.now(),
      orderId: null,
      lastMessage: messageController.value.text,
      lastMessageType: messageType,
      type: 'adminchat',
    );

    FireStoreUtils.addInbox(inboxModel);

    ConversationModel conversationModel = ConversationModel(
      id: const Uuid().v4(),
      message: message,
      senderId: FireStoreUtils.getCurrentUid(),
      receiverId: Constant.adminType,
      createdAt: Timestamp.now(),
      url: url,
      orderId: null,
      messageType: messageType,
      videoThumbnail: videoThumbnail,
      seen: false,
    );

    if (url != null) {
      if (url.mime.contains('image')) {
        conversationModel.message = "sent an image";
      } else if (url.mime.contains('video')) {
        conversationModel.message = "sent an Video";
      } else if (url.mime.contains('audio')) {
        conversationModel.message = "Sent a voice message";
      }
    }

    FireStoreUtils.addChat(conversationModel);
    Timer(const Duration(milliseconds: 500), () => scrollController.value.jumpTo(scrollController.value.position.minScrollExtent));
  }
}

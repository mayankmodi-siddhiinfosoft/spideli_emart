import 'package:customer/constant/constant.dart';
import 'package:customer/models/conversation_model.dart';
import 'package:customer/models/inbox_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/chat_scroll.dart';
import 'package:customer/utils/preferences.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;

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
    // The profile is loaded by setSeen(), which onInit does not await, and the
    // thread document is keyed by this id. `userModel.value.id!` threw on a
    // send that beat the load (or whose profile read failed), so fall back to
    // the signed-in uid and only give up if there is nothing at all.
    final String senderUid = (userModel.value.id ?? '').trim().isNotEmpty ? userModel.value.id!.trim() : FireStoreUtils.getCurrentUid();
    if (senderUid.isEmpty) {
      ShowToastDialog.showToast("Something went wrong, please try again.".tr);
      return;
    }
    List<String> senderReceiverId = [senderUid, 'admin'];
    InboxModel inboxModel = InboxModel(
      senderReceiverId: senderReceiverId,
      chatType: Constant.userRoleCustomer,
      lastSenderId: senderUid,
      senderId: senderUid,
      receiverId: 'admin',
      createdAt: Timestamp.now(),
      orderId: null,
      lastMessage: messageController.value.text,
      lastMessageType: messageType,
      type: 'adminchat',
    );

    await FireStoreUtils.addInbox(inboxModel);

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

    await FireStoreUtils.addChat(conversationModel);
    // The admin side of this thread is the web panel, not a device, so there
    // is no FCM token to push to from here (bug #3 covers the store and driver
    // threads, which do carry one).
    scrollChatToLatest(scrollController.value);
  }
}

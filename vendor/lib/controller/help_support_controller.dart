import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/conversation_model.dart';
import 'package:vendor/models/inbox_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/utils/chat_scroll.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/preferences.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/utils/store_chat.dart';
import 'package:vendor/utils/store_chat_session.dart';

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

  /// The store side of the support chat (lib/utils/store_chat.dart). For an
  /// employee: the store's thread `chat/{owner}`, written as the owner, so
  /// admin keeps one conversation per store. Null for the owner until read;
  /// the owner's thread is their own uid as before.
  Rx<StoreChatIdentity?> identity = Rx<StoreChatIdentity?>(null);

  /// `chat/{threadId}`: the store's chat id. Empty while an employee's store
  /// identity is being read (nothing is shown or written until then).
  RxString threadId = ''.obs;

  /// An employee whose role does not allow chats, or whose store could not be
  /// read: the thread is not opened.
  RxBool blocked = false.obs;

  /// A message of the thread is the store side's own.
  bool isStoreSide(String? senderId) {
    final StoreChatIdentity? me = identity.value;
    if (me != null && me.isEmployee) return me.isStoreSide(senderId);
    return senderId == FireStoreUtils.getCurrentUid();
  }

  Future<void> setSeen() async {
    if (StoreChatSession.isEmployee) {
      final StoreChatIdentity? me = await StoreChatSession.resolve();
      if (isClosed) return;
      identity.value = me;
      if (me == null || !me.ready) {
        blocked.value = true;
        if (me != null && !me.canChat) ShowToastDialog.showToast("You don’t have permission to view chats.".tr);
        return;
      }
      threadId.value = me.supportThreadId;
    } else {
      threadId.value = FireStoreUtils.getCurrentUid();
    }
    FireStoreUtils.setSeen(threadId: threadId.value);
    await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) {
      if (value?.id != null) {
        userModel.value = value!;
      }
    });
  }

  Future<void> sendMessage({required String message, Url? url, required String videoThumbnail, required String messageType}) async {
    final StoreChatIdentity? me = identity.value;
    final bool asStore = me != null && me.isEmployee;
    if (blocked.value || (StoreChatSession.isEmployee && !(me?.ready ?? false))) return;
    // The profile may not have loaded yet; fall back to the signed-in user.
    // An employee writes as the store (its chat id), never as themselves.
    final String senderId = asStore ? me.senderId : ((userModel.value.id ?? '').isNotEmpty ? userModel.value.id! : FireStoreUtils.getCurrentUid());
    if (senderId.isEmpty) return;
    if (!asStore) userModel.value.id ??= senderId;
    List<String> senderReceiverId = [senderId, 'admin'];
    InboxModel inboxModel = InboxModel(
      senderReceiverId: senderReceiverId,
      chatType: Constant.userRoleVendor,
      lastSenderId: senderId,
      senderId: senderId,
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
      senderId: asStore ? senderId : FireStoreUtils.getCurrentUid(),
      receiverId: Constant.adminType,
      createdAt: Timestamp.now(),
      url: url,
      orderId: null,
      messageType: messageType,
      videoThumbnail: videoThumbnail,
      seen: false,
      // An employee's message: who actually wrote it (audit only).
      sentByUserId: me?.auditFields['sentByUserId'],
      sentByName: me?.auditFields['sentByName'],
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
    // Guarded: the thread may be closed (or not laid out yet) when it fires.
    scrollChatToLatest(scrollController.value, delay: const Duration(milliseconds: 500));
  }
}

import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/chat_scroll.dart';
import 'package:image_picker/image_picker.dart';
import '../models/conversation_model.dart';
import '../models/inbox_model.dart';
import '../service/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../service/send_notification.dart';

class ChatController extends GetxController {
  Rx<TextEditingController> messageController = TextEditingController().obs;

  Rx<ScrollController> scrollController = ScrollController().obs;

  @override
  void onInit() {
    // TODO: implement onInit

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
  UserModel? receiverUser;

  /// The Firestore document that holds this thread (`chat/<id>/thread`).
  ///
  /// An order chat is keyed by the order id, and an inbox row written without
  /// an `orderId` field left this empty. `collection.doc('')` throws
  /// ArgumentError, so that empty id used to blow up both the seen-listener and
  /// the screen's own paginated query — the chat came up blank. [hasThread]
  /// lets the callers show the empty view instead.
  String get threadId => orderId.value.trim();

  bool get hasThread => threadId.isNotEmpty;

  Future<void> getArgument() async {
    try {
      await _readArgument();
    } catch (e, s) {
      // Nothing here is worth a blank screen: the thread itself still loads
      // from the arguments we did manage to read.
      log("chat getArgument failed: $e");
      log(s.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _readArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      orderId.value = argumentData['orderId'] ?? '';
      senderId.value = argumentData['senderId'] ?? '';
      senderName.value = argumentData['senderName'] ?? '';
      senderProfileUrl.value = argumentData['senderProfileUrl'] ?? "";
      receivedId.value = argumentData['receivedId'] ?? '';
      receivedName.value = argumentData['receivedName'] ?? '';
      receivedProfileUrl.value = argumentData['receivedProfileUrl'] ?? "";
      token.value = argumentData['token'] ?? '';
      chatType.value = argumentData['chatType'] ?? "";
      receiverUser = await FireStoreUtils.getUserForChat(receivedId.value);
    }
    log("senderId :: ${senderId.value} :: receivedId :: ${receivedId.value}");

    setSeen();
  }

  Future<void> setSeen() async {
    FireStoreUtils.setSeenChatForOrder(orderId: threadId);
  }

  @override
  void onClose() {
    FireStoreUtils.stopSeenForOrderListener();
    super.onClose();
  }

  Future<void> sendMessage(String message, Url? url, String videoThumbnail, String messageType, ChatController controller) async {
    // Without a thread id there is no document to write to; say so instead of
    // throwing out of the send handler.
    if (!hasThread) {
      ShowToastDialog.showToast("Something went wrong, please try again.".tr);
      return;
    }
    List<String> senderReceiverId = [controller.senderId.value, controller.receivedId.value];
    InboxModel inboxModel = InboxModel(
      chatType: controller.chatType.value,
      senderReceiverId: senderReceiverId,
      lastSenderId: senderId.value,
      senderId: senderId.value,
      receiverId: receivedId.value,
      createdAt: Timestamp.now(),
      orderId: orderId.value,
      lastMessage: messageController.value.text,
      lastMessageType: messageType,
      type: 'orderChat',
    );

    await FireStoreUtils.addInbox(inboxModel);

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
    scrollChatToLatest(scrollController.value);
    await notifyReceiver(conversationModel, inboxModel);
  }

  /// Push the message to whoever is on the other side of the thread (bug #3).
  ///
  /// This ran on every send already but never arrived:
  ///
  /// * the token came from `getUserForChat`, which only reads the
  ///   `providersWorkers` collection — a store or a driver lives in `users`,
  ///   so the lookup returned null and FCM was called with an empty token.
  ///   The screens already hand us the recipient's real token in the
  ///   arguments, so that is used first and the lookup is only a fallback;
  /// * the title was the **recipient's** own name, so a delivered
  ///   notification would have read as if they had written it themselves.
  ///
  /// Missing token (the other side never registered one, or an admin thread
  /// with no device) is not an error for the sender: the message is already
  /// saved, so this returns quietly.
  Future<void> notifyReceiver(ConversationModel conversationModel, InboxModel inboxModel) async {
    final String fcmToken = token.value.trim().isNotEmpty ? token.value.trim() : (receiverUser?.fcmToken ?? '').trim();
    if (fcmToken.isEmpty) {
      log("chat push skipped: no fcm token for ${receivedId.value}");
      return;
    }
    // Same payload shape as the app's other notifications: `type` and
    // `chatType` are what NotificationService.handleMessageClick routes on,
    // and FCM data values must be strings.
    await SendNotification.sendChatFcmMessage(senderName.value, conversationModel.message.toString(), fcmToken, {
      'type': inboxModel.type ?? 'orderChat',
      'chatType': inboxModel.chatType ?? '',
      'orderId': orderId.value,
      'senderId': conversationModel.senderId ?? '',
    });
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

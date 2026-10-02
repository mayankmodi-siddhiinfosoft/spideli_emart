import 'dart:convert';
import 'dart:developer';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/dash_board_controller.dart';
import 'package:customer/screen_ui/help_support_screen/help_support_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/driver_inbox_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/restaurant_inbox_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/dash_board_screens/dash_board_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/delivery_code_push.dart';
import 'package:customer/utils/preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';

Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  log("BackGround Message :: ${message.messageId}");
  // NotificationService.redirectScreen(message);
}

class NotificationService {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initInfo() async {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    var request = await FirebaseMessaging.instance.requestPermission(alert: true, announcement: false, badge: true, carPlay: false, criticalAlert: false, provisional: false, sound: true);

    if (request.authorizationStatus == AuthorizationStatus.authorized || request.authorizationStatus == AuthorizationStatus.provisional) {
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      var iosInitializationSettings = const DarwinInitializationSettings();
      final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid, iOS: iosInitializationSettings);
      await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null) {
            final data = jsonDecode(response.payload!);
            final String type = data['type'] ?? '';
            final String role = data['chatType'] ?? '';
            handleMessageClick(type: type, role: role, isBgApp: false, data: data is Map ? Map<String, dynamic>.from(data) : const {});
          }
        },
      );
      setupInteractedMessage();
    }
  }

  Future<void> setupInteractedMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final String type = initialMessage.data['type'] ?? '';
      final String role = initialMessage.data['chatType'] ?? '';
      handleMessageClick(type: type, role: role, isBgApp: true, data: initialMessage.data, coldStart: true);
    }
    if (initialMessage != null) {
      FirebaseMessaging.onBackgroundMessage((message) => firebaseMessageBackgroundHandle(message));
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log("::::::::::::onMessage:::::::::::::::::");
      if (message.notification != null) {
        log(message.notification.toString());
        // display(message);
      }
      // "Your order has arrived — open the app for your delivery code"
      // (POD-OTP-CONTRACT) is shown in the foreground too. iOS already
      // presents it (setForegroundNotificationPresentationOptions); Android
      // does not, so it is shown locally there.
      if (message.data['type'] == DeliveryCodePush.type && defaultTargetPlatform == TargetPlatform.android) {
        display(message);
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage? message) async {
      log("::::::::::::onMessageOpenedApp:::::::::::::::::");
      if (message != null) {
        final String type = message.data['type'] ?? '';
        final String role = message.data['chatType'] ?? '';
        handleMessageClick(type: type, role: role, isBgApp: true, data: message.data);
      }
    });
    log("::::::::::::Permission authorized:::::::::::::::::");
    await FirebaseMessaging.instance.subscribeToTopic("customer");
  }

  static Future<String> getToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      return token ?? '';
    } catch (e) {
      return '';
    }
  }

  // static redirectScreen(RemoteMessage message) async {
  //   Map<String, dynamic> data = message.data;
  //   if (data['type'] == "user_chat") {
  //     String senderId = data['senderId'];
  //     String receiverId = data['receiverId'];
  //
  //     ShowToastDialog.showLoader("Please wait".tr);
  //     UserModel? senderUserModel = await FireStoreUtils.getUserProfile(senderId);
  //     UserModel? receiverUserModel = await FireStoreUtils.getUserProfile(receiverId);
  //     ShowToastDialog.closeLoader();
  //     bool isMe = senderUserModel!.id == senderId;
  //     Get.to(const UserChatScreen(), arguments: {"receiverModel": isMe ? senderUserModel : receiverUserModel});
  //   } else if (data['type'] == "project_chat") {
  //     String isSender = data['isSender'];
  //     String businessId = data['businessId'];
  //     String projectId = data['projectId'];
  //
  //     ShowToastDialog.showLoader("Please wait".tr);
  //     PricingRequestModel? pricingRequestModel = await FireStoreUtils.getPricingRequestById(projectId);
  //     BusinessModel? businessModel = await FireStoreUtils.getBusinessById(businessId);
  //     UserModel? userModel = await FireStoreUtils.getUserProfile(pricingRequestModel!.userId.toString());
  //     ShowToastDialog.closeLoader();
  //     Get.to(ChatScreen(), arguments: {
  //       "userModel": userModel!,
  //       "businessModel": businessModel!,
  //       "projectModel": pricingRequestModel,
  //       "isSender": isSender == "business" ? "user" : "business",
  //     });
  //   } else if (data['type'] == "project_request") {
  //     String businessId = data['businessId'];
  //     String projectId = data['projectId'];
  //     BusinessModel? businessModel = await FireStoreUtils.getBusinessById(businessId);
  //     Get.to(BusinessProjectListScreen(), arguments: {"businessModel": businessModel});
  //   } else if (data['type'] == "review") {
  //     String businessId = data['businessId'];
  //     BusinessModel? businessModel = await FireStoreUtils.getBusinessById(businessId);
  //     Get.to(BusinessDetailsScreen(), arguments: {"businessModel": businessModel});
  //   } else if (data['type'] == "user_follow") {
  //     String userId = data['userId'];
  //     ShowToastDialog.showLoader("Please wait");
  //     UserModel? userModel0 = await FireStoreUtils.getUserProfile(userId.toString());
  //     ShowToastDialog.closeLoader();
  //     Get.to(OtherPeopleScreen(), arguments: {"userModel": userModel0});
  //   }
  // }

  Future<void> handleMessageClick({required String type, required String role, required bool isBgApp, Map<String, dynamic> data = const {}, bool coldStart = false}) async {
    // Opens that order's details with the code card; the payload has no code.
    if (type == DeliveryCodePush.type) {
      await DeliveryCodePush.handleTap(data, coldStart: coldStart);
      return;
    }
    final String uid = FireStoreUtils.getCurrentUid();
    if (type == 'admin_chat' && uid.isNotEmpty) {
      await Preferences.setBoolean(Preferences.isClickOnNotification, true);
      if (isBgApp == false) {
        Get.offAll(HelpSupportScreen(isNavigateViaNotification: true));
      }
    } else if (type == 'orderChat') {
      DashBoardController dashBoardScreen = Get.put(DashBoardController());
      dashBoardScreen.selectedIndex.value = 4;
      Get.offAll(DashBoardScreen());
      if (role == Constant.userRoleVendor) {
        Get.to(RestaurantInboxScreen());
      } else {
        Get.to(DriverInboxScreen());
      }
    }
  }

  void display(RemoteMessage message) async {
    log('Got a message whilst in the foreground!');
    log('Message data: ${message.notification?.body.toString()}');
    try {
      AndroidNotificationChannel channel = const AndroidNotificationChannel('0', 'spideli customer', description: 'Show spideli Notification', importance: Importance.max);
      AndroidNotificationDetails notificationDetails = AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: 'your channel Description',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
      );
      const DarwinNotificationDetails darwinNotificationDetails = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
      NotificationDetails notificationDetailsBoth = NotificationDetails(android: notificationDetails, iOS: darwinNotificationDetails);
      await FlutterLocalNotificationsPlugin().show(
        id: 0,
        title: message.notification?.title ?? (message.data['type'] == DeliveryCodePush.type ? 'Your order has arrived'.tr : null),
        body: message.notification?.body ?? (message.data['type'] == DeliveryCodePush.type ? 'Open the app for your delivery code'.tr : null),
        notificationDetails: notificationDetailsBoth,
        payload: jsonEncode(message.data),
      );
    } on Exception catch (e) {
      log(e.toString());
    }
  }
}

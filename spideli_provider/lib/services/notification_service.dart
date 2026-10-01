import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/controller/dashboard_controller.dart';
import 'package:spideliprovider/ui/booking_list/booking_details_screen.dart';
import 'package:spideliprovider/ui/chat_screen/chat_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  log("BackGround Message :: ${message.messageId}");
}

class NotificationService {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  initInfo() async {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    var request = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (request.authorizationStatus == AuthorizationStatus.authorized || request.authorizationStatus == AuthorizationStatus.provisional) {
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      var iosInitializationSettings = const DarwinInitializationSettings();
      final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid, iOS: iosInitializationSettings);
      await flutterLocalNotificationsPlugin.initialize(
          settings: initializationSettings,
          onDidReceiveNotificationResponse: (payload) {
            if (payload.payload != null) {
              final data = jsonDecode(payload.payload!);
              final String type = data['type'] ?? '';
              final String role = data['chatType'] ?? '';
              handleMessageClick(type: type, role: role, message: payload.data, isBgApp: false);
            }
          });
      setupInteractedMessage();
    }
  }

  Future<void> setupInteractedMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final String type = initialMessage.data['type'] ?? '';
      final String role = initialMessage.data['chatType'] ?? '';
      handleMessageClick(type: type, role: role, message: initialMessage.data, isBgApp: true);
    }
    if (initialMessage != null) {
      FirebaseMessaging.onBackgroundMessage((message) => firebaseMessageBackgroundHandle(message));
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log("::::::::::::onMessage:::::::::::::::::");
      if (message.notification != null) {
        log(message.notification.toString());
        display(message);
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log("::::::::::::MessageOpenedApp:::::::::::::::::");
      log(message.data.toString());
      if (message.data.isNotEmpty == true) {
        final String type = message.data['type'] ?? '';
        final String role = message.data['chatType'] ?? '';
        handleMessageClick(type: type, role: role, message: message.data, isBgApp: true);
      }
    });
    log("::::::::::::Permission authorized:::::::::::::::::");
    await FirebaseMessaging.instance.subscribeToTopic("provider");
  }

  /// The device's FCM token, or an empty string when there is not one yet.
  /// `token!` used to throw on iOS before the APNS token had arrived.
  static Future<String> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken() ?? '';
    } catch (e) {
      log("FCM token unavailable: $e");
      return '';
    }
  }

  static StreamSubscription<String>? _tokenRefreshSubscription;

  /// Writes this device's FCM token to the signed-in provider's document and keeps
  /// writing it whenever Firebase rotates it.
  ///
  /// Without this the token on the document goes stale the first time it is
  /// refreshed and the provider can no longer be reached by chat or order pushes
  /// (bug #3). Safe to call before sign-in: it simply writes nothing.
  static Future<void> syncTokenToUserDoc() async {
    await _writeToken(await getToken());
    _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen(
      _writeToken,
      onError: (Object e) => log("FCM token refresh failed: $e"),
    );
  }

  static Future<void> _writeToken(String token) async {
    if (token.isEmpty) return;
    final String? uid = auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      // `update`, not `set`: a uid with no document yet must not get a stub
      // record created for it. A missing document just logs and moves on.
      await FireStoreUtils.firestore.collection(USERS).doc(uid).update({"fcmToken": token});
    } catch (e) {
      log("FCM token not stored: $e");
    }
  }

  Future<void> handleMessageClick({required String type, required String role, required Map<String, dynamic> message, required bool isBgApp}) async {
    if (type == 'provider_order') {
      Get.to(const BookingDetailsScreen(), arguments: {
        "orderId": message['orderId'],
      });
    } else if (type == 'provider_chat') {
      Get.to(ChatScreen(), arguments: {
        "senderName": message['senderName'],
        "senderId": message["senderId"],
        "senderProfileUrl": message["senderProfileUrl"],
        "receivedName": message["receivedName"],
        "receivedId": message["receivedId"],
        "receivedProfileUrl": message["receivedProfileUrl"],
        "orderId": message["orderId"],
        "token": message["token"],
        "chatType": message["chatType"]
      });
    } else if (type == 'admin_chat') {
      DashBoardController dashBoardScreen = Get.put(DashBoardController());
      dashBoardScreen.onSelectItem(10);
    }
  }
}

void display(RemoteMessage message) async {
  log('Got a message whilst in the foreground!');
  log('Message data: ${message.notification!.body.toString()}');
  log(jsonEncode(message.data));
  try {
    // final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    AndroidNotificationChannel channel = const AndroidNotificationChannel(
      "01",
      "spideli_provider",
      description: 'Show spideli Notification',
      importance: Importance.max,
    );
    AndroidNotificationDetails notificationDetails =
        AndroidNotificationDetails(channel.id, channel.name, channelDescription: 'your channel Description', importance: Importance.high, priority: Priority.high, ticker: 'ticker');
    const DarwinNotificationDetails darwinNotificationDetails = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
    NotificationDetails notificationDetailsBoth = NotificationDetails(android: notificationDetails, iOS: darwinNotificationDetails);
    await FlutterLocalNotificationsPlugin().show(
      id: 0,
      title: message.notification!.title,
      body: message.notification!.body,
      notificationDetails: notificationDetailsBoth,
      payload: jsonEncode(message.data),
    );
  } on Exception catch (e) {
    log(e.toString());
  }
}

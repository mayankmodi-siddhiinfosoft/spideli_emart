import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:vendor/app/chat_screens/restaurant_inbox_screen.dart';
import 'package:vendor/app/help_support_screen/help_support_screen.dart';
import 'package:vendor/controller/dash_board_controller.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/preferences.dart';

/// Runs in its own isolate for a *data* message that arrives while the app is
/// in the background or closed. Registered from `main()` so it is always
/// installed; it used to be registered inside [NotificationService], and only
/// when the app had been launched from a notification, so most background
/// messages reached nothing at all (report #11).
@pragma('vm:entry-point')
Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  log("BackGround Message :: ${message.messageId}");
}

class NotificationService {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Loud channel for a new order: max importance (heads-up + sound even with
  /// the app closed) and the store's own alert tone.
  ///
  /// The id must match `com.google.firebase.messaging.default_notification_channel_id`
  /// in AndroidManifest.xml, and the id the server puts in
  /// `android.notification.channel_id`, or Android posts the push on a channel
  /// it creates itself with default importance - silent and no heads-up. An
  /// existing channel's sound and importance cannot be changed afterwards, so
  /// the id is versioned: bump it if the tone ever changes.
  static const String orderChannelId = 'new_order';

  /// Everything that is not an order (chat, payouts, announcements).
  static const String generalChannelId = 'general';

  /// `res/raw/order_alert.wav`.
  static const String orderSoundResource = 'order_alert';

  static const AndroidNotificationChannel _orderChannel = AndroidNotificationChannel(
    orderChannelId,
    'New orders',
    description: 'Audible alert the moment a customer places an order',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound(orderSoundResource),
    enableVibration: true,
    enableLights: true,
    audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
  );

  static const AndroidNotificationChannel _generalChannel = AndroidNotificationChannel(
    generalChannelId,
    'Store updates',
    description: 'Chat messages, payouts and other store notifications',
    importance: Importance.high,
  );

  Future<void> initInfo() async {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    // Channels first, before the permission request: `requestPermission` blocks
    // on the system dialog, and until it returns the loud order channel would
    // not exist - a background push arriving in that window is posted on a
    // channel Android makes up itself, which is silent and never heads-up.
    await createChannels();
    var request = await FirebaseMessaging.instance.requestPermission(alert: true, announcement: false, badge: true, carPlay: false, criticalAlert: false, provisional: false, sound: true);

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    var iosInitializationSettings = const DarwinInitializationSettings();
    final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid, iOS: iosInitializationSettings);
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          final data = jsonDecode(response.payload!);
          final String type = data['type'] ?? '';
          handleMessageClick(type: type, isBgApp: false);
        }
      },
    );

    if (request.authorizationStatus == AuthorizationStatus.authorized || request.authorizationStatus == AuthorizationStatus.provisional) {
      setupInteractedMessage();
    }
  }

  /// Creates (or re-asserts) the Android channels and asks for the Android 13+
  /// notification permission.
  Future<void> createChannels() async {
    if (!Platform.isAndroid) return;
    final AndroidFlutterLocalNotificationsPlugin? android = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    try {
      await android.createNotificationChannel(_orderChannel);
      await android.createNotificationChannel(_generalChannel);
      await android.requestNotificationsPermission();
    } catch (e) {
      log("notification channel setup failed: $e");
    }
  }

  Future<void> setupInteractedMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final String type = initialMessage.data['type'] ?? '';
      handleMessageClick(type: type, isBgApp: true);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      log("::::::::::::onMessage:::::::::::::::::");
      if (message.notification != null) {
        log(message.notification.toString());
        display(message);
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage? message) {
      if (message != null) {
        final String type = message.data['type'] ?? '';
        handleMessageClick(type: type, isBgApp: false);
      }
    });
    log("::::::::::::Permission authorized:::::::::::::::::");
    await FirebaseMessaging.instance.subscribeToTopic("vendor");
  }

  static Future<String> getToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      return token ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Where a tapped notification takes the vendor.
  ///
  /// The `orderChat` branch used to sit *inside* `if (type == 'admin_chat')`,
  /// so tapping a chat push could never reach it. Cold-start behaviour is
  /// unchanged (the app still comes up through the splash screen); a tap while
  /// the app is running now opens the matching screen.
  Future<void> handleMessageClick({required String type, required bool isBgApp}) async {
    final String uid = FireStoreUtils.getCurrentUid();
    if (uid.isEmpty) return;
    if (type == 'admin_chat') {
      await Preferences.setBoolean(Preferences.isClickOnNotification, true);
      if (isBgApp == false) {
        Get.offAll(HelpSupportScreen(isNavigateViaNotification: true));
      }
    } else if (type == 'orderChat' && isBgApp == false) {
      DashBoardController dashBoardScreen = Get.put(DashBoardController());
      dashBoardScreen.selectedIndex.value = 0;
      Get.to(const RestaurantInboxScreen());
    }
  }

  /// True for the pushes that must be loud: a new order.
  static bool isOrderAlert(RemoteMessage message) {
    final String type = (message.data['type'] ?? '').toString().toLowerCase();
    final String channelId = (message.data['channelId'] ?? message.data['android_channel_id'] ?? '').toString();
    return channelId == orderChannelId || type.contains('order_placed') || type.contains('new_order');
  }

  /// Re-posts a message that arrived while the app was in the foreground.
  ///
  /// Report #11: this used to build a channel object it never created, and then
  /// posted with `Importance.high` and no sound, so nothing was audible. It now
  /// posts on the created order channel, with the alert tone and max
  /// importance, through the already-initialised plugin instance (a fresh
  /// `FlutterLocalNotificationsPlugin()` had never been initialised, so taps on
  /// the notification went nowhere).
  void display(RemoteMessage message) async {
    log('Got a message whilst in the foreground!');
    log('Message data: ${message.notification!.body.toString()}');
    try {
      final bool orderAlert = isOrderAlert(message);
      final AndroidNotificationChannel channel = orderAlert ? _orderChannel : _generalChannel;
      final AndroidNotificationDetails notificationDetails = AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: orderAlert ? Priority.max : Priority.high,
        playSound: true,
        sound: channel.sound,
        enableVibration: true,
        category: orderAlert ? AndroidNotificationCategory.alarm : null,
        ticker: 'ticker',
      );
      // iOS plays the sound named in the push itself; `presentSound` only says
      // that a foreground message may be audible. A custom iOS tone needs the
      // sound file added to the Runner target in Xcode - see the report.
      const DarwinNotificationDetails darwinNotificationDetails = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
      NotificationDetails notificationDetailsBoth = NotificationDetails(android: notificationDetails, iOS: darwinNotificationDetails);
      await flutterLocalNotificationsPlugin.show(
        id: orderAlert ? 1 : 0,
        title: message.notification!.title,
        body: message.notification!.body,
        notificationDetails: notificationDetailsBoth,
        payload: jsonEncode(message.data),
      );
    } on Exception catch (e) {
      log(e.toString());
    }
  }
}

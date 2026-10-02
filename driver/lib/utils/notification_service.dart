import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:driver/app/chat_screens/chat_screen.dart';
import 'package:driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/dash_board_controller.dart';
import 'package:driver/controllers/signup_controller.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/carrier_dispatch_service.dart';
import 'package:driver/services/driver_assignment_watcher.dart';
import 'package:driver/services/driver_job_queue_service.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  log("BackGround Message :: ${message.messageId}");
}

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Client point 19, the half that is not about tokens.
  ///
  /// This id has to match `com.google.firebase.messaging.default_notification_channel_id`
  /// in AndroidManifest.xml. Without that pairing, a `notification` message that
  /// arrives while the app is in the background or closed is posted by the
  /// Firebase SDK on a fallback channel it creates itself with DEFAULT
  /// importance — no heads-up banner and no sound. The driver then only finds
  /// the job by pulling down the shade, which is what "I receive no
  /// notification when an order is available" looks like in practice.
  ///
  /// The channel is also created explicitly at start-up: a channel that only
  /// comes into existence when the first foreground message is shown does not
  /// exist yet for the background case. An existing channel's importance can
  /// never be raised afterwards, so the id is versioned — bump it if the
  /// importance or the tone ever has to change.
  static const String jobChannelId = 'driver_notifications_channel';

  static const AndroidNotificationChannel _jobChannel = AndroidNotificationChannel(
    jobChannelId,
    'Driver Notifications',
    description: 'Available jobs, order updates and chat messages',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Creates [_jobChannel]. Safe to call repeatedly; Android keeps the channel
  /// the user already has (including any sound or importance they changed).
  Future<void> _createChannel() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? android =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_jobChannel);
    } catch (e) {
      log("createNotificationChannel failed: $e");
    }
  }

  Future<void> initInfo() async {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    var request = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (request.authorizationStatus == AuthorizationStatus.authorized || request.authorizationStatus == AuthorizationStatus.provisional) {
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosInitializationSettings = DarwinInitializationSettings();

      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: iosInitializationSettings,
      );

      await _createChannel();

      await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) {
            final data = jsonDecode(response.payload!);
            final String type = data['type'] ?? '';
            final String role = data['chatType'] ?? '';
            final String orderId = data['orderId'] ?? '';
            final String senderId = data['senderId'] ?? '';
            handleMessageClick(type: type, role: role, orderId: orderId, senderId: senderId);
          }
        },
      );

      setupInteractedMessage();
    }
  }

  Future<void> setupInteractedMessage() async {
    // App opened from terminated state
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final String type = initialMessage.data['type'] ?? '';
      final String role = initialMessage.data['chatType'] ?? '';
      final String orderId = initialMessage.data['orderId'] ?? '';
      final String senderId = initialMessage.data['senderId'] ?? '';
      handleMessageClick(type: type, role: role, orderId: orderId, senderId: senderId);
    }

    // App in background and notification tapped
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage? message) {
      if (message != null) {
        final String type = message.data['type'] ?? '';
        final String role = message.data['chatType'] ?? '';
        final String orderId = message.data['orderId'] ?? '';
        final String senderId = message.data['senderId'] ?? '';
        handleMessageClick(type: type, role: role, orderId: orderId, senderId: senderId);
      }
    });

    // App in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        display(message);
      }
    });

    await _subscribe("driver");
  }

  static Future<String> getToken() async {
    final String? token = await FirebaseMessaging.instance.getToken();
    return token ?? '';
  }

  // ── Token + topics (client point 19) ──────────────────────────────────────

  /// Topics the driver is currently subscribed to, so a sign-out (or a change
  /// of section / zone / region) can take them off again.
  static final Set<String> _topics = <String>{};

  static StreamSubscription<String>? _tokenRefreshSub;

  /// FCM topic names only accept `[a-zA-Z0-9-_.~%]`.
  static String _topic(String prefix, String value) {
    final String safe = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9\-_.~%]'), '_');
    return safe.isEmpty ? '' : '${prefix}_$safe';
  }

  static Future<void> _subscribe(String topic) async {
    if (topic.isEmpty || _topics.contains(topic)) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      _topics.add(topic);
    } catch (e) {
      log("subscribeToTopic $topic failed: $e");
    }
  }

  /// Writes [token] on the driver's user document. The server sends a job
  /// notification to this token (or to one of the topics below).
  static Future<void> saveToken(String token) async {
    if (token.isEmpty) return;
    final String uid = FireStoreUtils.getCurrentUid();
    if (uid.isEmpty) return;
    try {
      await FireStoreUtils.fireStore.collection(CollectionName.users).doc(uid).set({'fcmToken': token}, SetOptions(merge: true));
      Constant.userModel?.fcmToken = token;
    } catch (e) {
      log("saveToken failed: $e");
    }
  }

  /// Keeps the stored token current: FCM rotates it (app reinstall, restore,
  /// cache clear) and the old one stops delivering.
  static void listenForTokenRefresh() {
    _tokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen(
      (String token) async {
        log("FCM token refreshed");
        await saveToken(token);
      },
      onError: (Object e) => log("onTokenRefresh failed: $e"),
    );
  }

  /// Subscribes the driver to every topic the server can address them by, so a
  /// "a job is available" push reaches them without the server having to hold
  /// a token list (client point 19).
  ///
  /// Topics: `driver`, `driver_<serviceType>`, `section_<sectionId>`,
  /// `zone_<zoneId>`, `region_<regionId>` and, for a fleet driver,
  /// `company_<ownerId>`.
  static Future<void> subscribeDriverTopics(UserModel? driver) async {
    if (driver == null) return;
    await _subscribe("driver");
    for (final String service in driver.serviceTypes ?? const <String>[]) {
      await _subscribe(_topic('driver', service));
    }
    for (final String sectionId in driver.sectionIds ?? const <String>[]) {
      await _subscribe(_topic('section', sectionId));
    }
    await _subscribe(_topic('zone', driver.zoneId ?? ''));
    await _subscribe(_topic('region', driver.regionId ?? ''));
    await _subscribe(_topic('company', driver.ownerId ?? ''));
    await _subscribe(_topic('carrier', driver.carrierId ?? ''));
  }

  /// Sign-out: the device must stop receiving this driver's work, and the
  /// token must stop pointing at them.
  static Future<void> onSignOut() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    for (final String topic in _topics.toList()) {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      } catch (e) {
        log("unsubscribeFromTopic $topic failed: $e");
      }
    }
    _topics.clear();
    final String uid = FireStoreUtils.getCurrentUid();
    if (uid.isNotEmpty) {
      try {
        await FireStoreUtils.fireStore.collection(CollectionName.users).doc(uid).set({'fcmToken': ''}, SetOptions(merge: true));
      } catch (e) {
        log("clearing fcmToken failed: $e");
      }
    }
    Constant.userModel?.fcmToken = '';
    DriverJobQueueService.reset();
    DriverAssignmentWatcher.stop();
    CarrierDispatchService.clearCache();
  }

  void display(RemoteMessage message) async {
    try {
      // Same channel the background pushes land on, so a job alert looks and
      // sounds the same whichever state the app was in.
      final AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
        _jobChannel.id,
        _jobChannel.name,
        channelDescription: _jobChannel.description,
        importance: _jobChannel.importance,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        ticker: 'ticker',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosDetails,
      );

      await flutterLocalNotificationsPlugin.show(
          id: 0, title: message.notification?.title, body: message.notification?.body, notificationDetails: notificationDetails, payload: jsonEncode(message.data));
    } catch (e) {
      log("Notification display error: $e");
    }
  }

  Future<void> handleMessageClick({required String type, String? senderId, String? orderId, required String role}) async {
    final String uid = FireStoreUtils.getCurrentUid();
    if (type == 'admin_chat' && uid.isNotEmpty) {
      DashBoardController controller = Get.put(DashBoardController());
      controller.drawerIndex.value = 7;
      Get.offAll(DashBoardScreen());
    } else if (type == 'orderChat') {
      ShowToastDialog.showLoader("Please wait".tr);
      log("Customer Notification :: $senderId :: ${FireStoreUtils.getCurrentUid()}");
      UserModel? customer = await FireStoreUtils.getUserProfile(senderId.toString());
      UserModel? driver = await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
      ShowToastDialog.closeLoader();
      // Without both parties (or without the order the thread is keyed by)
      // the chat screen has nothing to open; land on the inbox instead of a
      // blank screen.
      if (customer == null || driver == null || (orderId ?? '').isEmpty) {
        DashBoardController inbox = Get.put(DashBoardController());
        inbox.drawerIndex.value = 5;
        Get.offAll(DashBoardScreen());
        return;
      }
      DashBoardController dashBoardScreen = Get.put(DashBoardController());
      dashBoardScreen.drawerIndex.value = 5;
      Get.offAll(DashBoardScreen());
      Get.to(const ChatScreen(), arguments: {
        "senderName": driver.fullName(),
        "senderId": driver.id,
        "senderProfileUrl": driver.profilePictureURL ?? "",
        "receivedName": customer.fullName(),
        "receivedId": customer.id,
        "receivedProfileUrl": customer.profilePictureURL ?? "",
        "orderId": orderId,
        "token": customer.fcmToken,
        "chatType": Constant.userRoleDriver,
      });
    } else if (_jobTypes.contains(type) && uid.isNotEmpty) {
      // Client point 19: tapping an "order available" push lands the driver on
      // the home of the module the job belongs to.
      final UserModel? me = Constant.userModel ?? await FireStoreUtils.getUserProfile(uid);
      if (me != null) SignupController.navigateByUserModel(me);
    }
  }

  /// `data.type` values the server uses for an available job.
  static const Set<String> _jobTypes = {
    'order',
    'new_order',
    'order_available',
    'vendor_order',
    'parcel_order',
    'rental_order',
    'cab_order',
    'job_queue',
    'job_assigned',
  };
}

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/controller/dashboard_controller.dart';
import 'package:spideliworker/firebase_options.dart';
import 'package:spideliworker/main.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/services/push_message.dart';
import 'package:spideliworker/ui/booking_list/booking_details_screen.dart';
import 'package:spideliworker/ui/chat_screen/chat_screen.dart';
import 'package:spideliworker/ui/chat_screen/inbox_screen.dart';
import 'package:spideliworker/ui/help_support_screen/help_support_screen.dart';
import 'package:spideliworker/utils/fcm_token_reset.dart';

/// Pushes that arrive while the app is in the background or killed.
///
/// The system already shows a push that has a `notification` block (every
/// push sent to the worker has one), so this only has to exist and run: it
/// is top-level and `vm:entry-point` (a release build otherwise tree-shakes
/// it and the background isolate cannot find it), and it initializes
/// Firebase because it can run in a fresh isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    log("Background push: Firebase not initialized: $e");
  }
  log("Background push received (${message.data['type'] ?? 'no type'})");
}

bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Receiving pushes in the worker app: the Android channel, the permission,
/// the FCM token on `providers_workers/{uid}.fcmToken`, foreground display and
/// where a tapped push opens.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _workerChannel = AndroidNotificationChannel(
    workerChannelId,
    workerChannelName,
    description: workerChannelDescription,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Runs in `main()` before `runApp`, never asks anything: creates the
  /// Android channel every push to this app references (it must exist before
  /// the first background push, which is posted without any Dart code
  /// running), and makes iOS show pushes while the app is open. Never throws.
  static Future<void> prepareBeforeRunApp() async {
    try {
      if (_isAndroid) {
        await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_workerChannel);
      }
    } catch (e) {
      log("Notification channel not created: $e");
    }
    try {
      // iOS shows a push that arrives in the foreground itself with these
      // options, so no local notification is posted there (it would show twice).
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    } catch (e) {
      log("Foreground presentation options not set: $e");
    }
  }

  /// The one setup of this launch, shared by every caller.
  static Future<void>? _initInfoFuture;

  /// Wires the notification listeners and requests the notification
  /// permission -- once per launch, however many callers ask.
  ///
  /// This is the app's only `requestPermission` call. Overlapping requests
  /// made firebase_messaging throw "A request for permissions is already
  /// running" and showed the system dialog twice; a second setup also added a
  /// second onMessage listener. Never throws: a failure is logged.
  Future<void> initInfo() => _initInfoFuture ??= _initInfo();

  Future<void> _initInfo() async {
    // Listeners first: a tapped push must open its screen whatever the user
    // answers to the permission dialog, and however long they take.
    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_notification'),
          // firebase_messaging asks for the permission below; the plugin must
          // not raise a second dialog.
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        ),
        onDidReceiveNotificationResponse: (NotificationResponse response) => _onTap(decodeNotificationPayload(response.payload)),
      );
      final NotificationAppLaunchDetails? launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _onTap(decodeNotificationPayload(launch?.notificationResponse?.payload));
      }
    } catch (e) {
      log("Local notifications not set up: $e");
    }
    try {
      await _setupInteractedMessage();
    } catch (e) {
      log("Notification listeners not set up: $e");
    }
    try {
      final NotificationSettings request = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      log("Notification permission: ${request.authorizationStatus.name}");
    } catch (e) {
      log("Notification permission request failed: $e");
    }
  }

  static bool _listening = false;

  Future<void> _setupInteractedMessage() async {
    if (_listening) return;
    _listening = true;
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification == null) return;
      // FCM does not display a push while the app is open on Android: post it
      // on the worker channel. iOS presents it from the options set in main().
      if (_isAndroid) _display(message);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) => _onTap(message.data));
    final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _onTap(initialMessage.data);
  }

  /// A tap that arrived before the dashboard was shown (the app was killed):
  /// the splash opens it right after it navigates to the dashboard, which
  /// would otherwise replace the screen the tap opened.
  static Map<String, dynamic>? _pendingTap;

  static void _onTap(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    if (MyAppState.currentUser == null || auth.FirebaseAuth.instance.currentUser == null) {
      _pendingTap = Map<String, dynamic>.from(data);
      return;
    }
    _open(data);
  }

  /// Opens the screen of a push tapped while the app was starting. Called by
  /// the splash after it shows the dashboard.
  static void openPendingTap() {
    final Map<String, dynamic>? data = _pendingTap;
    _pendingTap = null;
    if (data != null && auth.FirebaseAuth.instance.currentUser != null) _open(data);
  }

  static void _open(Map<String, dynamic> data) {
    String value(String key) {
      final String text = (data[key] ?? '').toString().trim();
      return text == 'null' ? '' : text;
    }

    try {
      switch (pushRouteFor(data)) {
        case PushRoute.booking:
          unawaited(_openJob(value('orderId')));
        case PushRoute.jobList:
          _openJobList();
        case PushRoute.chat:
          // The sender of the push is the other side of the chat.
          Get.to(const ChatScreen(), arguments: {
            "senderName": MyAppState.currentUser?.fullName() ?? '',
            "senderId": FireStoreUtils.getCurrentUid(),
            "senderProfileUrl": MyAppState.currentUser?.profilePictureURL ?? '',
            "receivedName": value('senderName'),
            "receivedId": value('senderId'),
            "receivedProfileUrl": value('senderProfileUrl'),
            "orderId": value('orderId'),
            "chatType": userRoleWorker,
          });
        case PushRoute.inbox:
          Get.to(const InboxScreen());
        case PushRoute.legacyProviderChat:
          Get.to(const ChatScreen(), arguments: {
            "senderName": value('senderName'),
            "senderId": value('senderId'),
            "senderProfileUrl": value('senderProfileUrl'),
            "receivedName": value('receivedName'),
            "receivedId": value('receivedId'),
            "receivedProfileUrl": value('receivedProfileUrl'),
            "orderId": value('orderId'),
            "token": value('token'),
            "chatType": value('chatType'),
          });
        case PushRoute.adminChat:
          Get.to(HelpSupportScreen(isNavigateViaNotification: false));
        case PushRoute.none:
          break;
      }
    } catch (e) {
      log("Push tap not opened: $e");
    }
  }

  /// A booking push (assigned, reassigned, cancelled, rejected): its details
  /// when the booking is still this worker's, else the job list
  /// ([jobTapTarget]). Never throws.
  static Future<void> _openJob(String orderId) async {
    bool? exists;
    String? assignedWorker;
    if (jobTapTarget(orderId: orderId) == JobTapTarget.details) {
      try {
        final snapshot = await FireStoreUtils.firestore.collection(PROVIDER_ORDER).doc(orderId).get().timeout(const Duration(seconds: 8));
        exists = snapshot.exists;
        assignedWorker = snapshot.data()?['workerId']?.toString();
      } catch (e) {
        // Offline or not readable: the details screen shows its own state.
        log("Tapped booking not read: $e");
      }
    }
    try {
      final JobTapTarget target = jobTapTarget(
        orderId: orderId,
        orderExists: exists,
        orderWorkerId: assignedWorker,
        currentWorkerId: auth.FirebaseAuth.instance.currentUser?.uid,
      );
      if (target == JobTapTarget.details) {
        // Not deduplicated: a push for another booking opened from a booking's
        // details must still open (each screen has its own controller).
        Get.to(() => const BookingDetailsScreen(), arguments: {"orderId": orderId.trim()}, preventDuplicates: false);
      } else {
        _openJobList();
      }
    } catch (e) {
      log("Tapped booking not opened: $e");
    }
  }

  /// Back to the dashboard, on the Jobs tab. Never throws.
  static void _openJobList() {
    try {
      Get.until((route) => route.isFirst);
      if (Get.isRegistered<DashBoardController>()) {
        final DashBoardController dashboard = Get.find<DashBoardController>();
        dashboard.selectedIndex.value = 0;
        if (dashboard.pageController.hasClients) dashboard.pageController.jumpToPage(0);
      }
    } catch (e) {
      log("Job list not opened: $e");
    }
  }

  static Future<void> _display(RemoteMessage message) async {
    try {
      final RemoteNotification? notification = message.notification;
      if (notification == null) return;
      const NotificationDetails details = NotificationDetails(
        android: AndroidNotificationDetails(
          workerChannelId,
          workerChannelName,
          channelDescription: workerChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          ticker: 'ticker',
        ),
      );
      await _local.show(
        // One notification per push: a fixed id made each new push replace
        // the previous one.
        id: (message.messageId ?? '${DateTime.now().microsecondsSinceEpoch}').hashCode & 0x7fffffff,
        title: notification.title,
        body: notification.body,
        notificationDetails: details,
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      log("Foreground push not shown: $e");
    }
  }

  // ---------------------------------------------------------------- token --

  /// This device's FCM token, or '' when there is none yet. Never throws.
  ///
  /// On iOS FCM has no token until APNs has given the device one, and
  /// `getToken()` threw `apns-token-not-set` before it: the token was saved as
  /// nothing and iPhones received no push at all. So on iOS this first waits
  /// (up to [apnsWait]) for the APNs token.
  static Future<String> getToken({Duration apnsWait = const Duration(seconds: 10)}) async {
    try {
      if (_isIOS) {
        final DateTime deadline = DateTime.now().add(apnsWait);
        String? apns = await FirebaseMessaging.instance.getAPNSToken();
        while (apns == null && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          apns = await FirebaseMessaging.instance.getAPNSToken();
        }
        if (apns == null) {
          log("FCM token unavailable: no APNs token yet (push capability / APNs key?)");
          return '';
        }
      }
      // A token restored from an Android backup is dead: replace it once.
      await FcmTokenReset.runOnce();
      final String? token = await FirebaseMessaging.instance.getToken();
      if (isUsableFcmToken(token)) {
        _deviceToken = token!.trim();
        return _deviceToken!;
      }
      return '';
    } catch (e) {
      log("FCM token unavailable: $e");
      return '';
    }
  }

  static StreamSubscription<String>? _tokenRefreshSubscription;
  static Future<void>? _syncInFlight;
  static String? _deviceToken;

  /// What this session last wrote, per worker uid.
  static String? _lastWrittenUid;
  static String? _lastWrittenToken;
  static bool _subscribedToTopic = false;

  /// Writes this device's FCM token to the signed-in worker's document, and
  /// keeps writing it whenever Firebase rotates it. Call at every start when
  /// signed in and right after login. Safe before sign-in: it writes nothing.
  ///
  /// Without this the token on the document goes stale the first time it is
  /// refreshed and the worker can no longer be reached by chat or booking
  /// pushes. Never throws.
  static Future<void> syncTokenToUserDoc() {
    final Future<void>? running = _syncInFlight;
    // A sync already running (the launch's) may have passed its write before
    // this sign-in: write the token it got for whoever is signed in now.
    if (running != null) return running.then((_) => _writeToken(_deviceToken ?? ''));
    return _syncInFlight = _syncToken().whenComplete(() => _syncInFlight = null);
  }

  static Future<void> _syncToken() async {
    // Subscribed before the first getToken, so the token iOS generates once
    // the APNs token arrives is not missed. One subscription per launch.
    _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen(
      (String token) {
        if (isUsableFcmToken(token)) _deviceToken = token.trim();
        _writeToken(token);
      },
      onError: (Object e) => log("FCM token refresh failed: $e"),
    );
    final String token = await getToken();
    await _writeToken(token);
    if (token.isNotEmpty && !_subscribedToTopic) {
      try {
        await FirebaseMessaging.instance.subscribeToTopic("worker");
        _subscribedToTopic = true;
      } catch (e) {
        log("Topic subscription failed: $e");
      }
    }
  }

  static Future<void> _writeToken(String token) async {
    final String? uid = auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final String? lastWritten = uid == _lastWrittenUid ? _lastWrittenToken : null;
    // Never an empty token over a good one; not the same token twice.
    if (!shouldWriteDeviceToken(newToken: token, lastWrittenToken: lastWritten)) return;
    final String value = token.trim();
    try {
      // Field-level `update`: only fcmToken, and a uid with no document yet
      // does not get a stub record created for it.
      await FireStoreUtils.firestore.collection(WORKERS).doc(uid).update({"fcmToken": value});
      _lastWrittenUid = uid;
      _lastWrittenToken = value;
      if (MyAppState.currentUser?.id == uid) MyAppState.currentUser?.fcmToken = value;
    } catch (e) {
      log("FCM token not stored: $e");
    }
  }

  /// Before signing out: clears the worker's fcmToken only when it is still
  /// this device's token, so the signed-out phone stops receiving this
  /// worker's pushes but another phone the worker uses keeps them. Field-level,
  /// in a transaction. Never throws.
  static Future<void> clearTokenOnSignOut() async {
    final String? uid = auth.FirebaseAuth.instance.currentUser?.uid;
    _lastWrittenUid = null;
    _lastWrittenToken = null;
    if (uid == null || uid.isEmpty) return;
    try {
      final String device = _deviceToken ?? await getToken(apnsWait: const Duration(seconds: 2));
      if (!isUsableFcmToken(device)) return;
      final ref = FireStoreUtils.firestore.collection(WORKERS).doc(uid);
      await FireStoreUtils.firestore.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(ref);
        final String? stored = snapshot.data()?['fcmToken']?.toString();
        if (snapshot.exists && shouldClearTokenOnSignOut(storedToken: stored, deviceToken: device)) {
          transaction.update(ref, {"fcmToken": ""});
        }
      });
    } catch (e) {
      log("FCM token not cleared on sign-out: $e");
    }
  }
}

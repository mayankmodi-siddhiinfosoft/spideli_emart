import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/firebase_options.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/push_message.dart';
import 'package:spideliprovider/ui/booking_list/booking_details_screen.dart';
import 'package:spideliprovider/ui/chat_screen/chat_screen.dart';
import 'package:spideliprovider/ui/help_support_screen/help_support_screen.dart';

/// Pushes that arrive while the app is in the background or not running.
///
/// Registered once, in main(), before runApp. On Android it runs in its own
/// isolate, so it starts Firebase itself; it must stay a top-level function
/// with the entry-point pragma or a release build cannot find it.
///
/// A notification message is shown by the system (Android, on the channel in
/// the message or the manifest default; iOS, by APNs). A data-only message
/// carrying a title or body is not shown by anyone, so it is shown here.
@pragma('vm:entry-point')
Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    log("Background push: Firebase not started: $e");
  }
  if (message.notification == null) {
    await NotificationService.showLocal(message);
  }
}

/// Receiving pushes: permission, Android channel, foreground display, taps, and
/// this device's FCM token on `users/{uid}.fcmToken`.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// The one Android channel this app posts on, for bookings and chat. Its id
  /// is in AndroidManifest.xml (`default_notification_channel_id`) and is the
  /// channel other apps put in pushes to the provider (.claude/PUSH-CHANNELS.md).
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    PushChannels.provider,
    'Bookings and messages',
    description: 'New bookings, booking updates and chat messages',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// The one setup of this launch, shared by every caller.
  static Future<void>? _initInfoFuture;

  /// Requests the notification permission and wires the notification
  /// listeners -- once per launch, however many callers ask.
  ///
  /// This is the app's only `requestPermission` call. Two overlapping requests
  /// made firebase_messaging throw "A request for permissions is already
  /// running" and showed the system dialog twice; a second setup also added a
  /// second onMessage listener. Never throws: a failure is logged.
  Future<void> initInfo() => _initInfoFuture ??= _initInfo();

  Future<void> _initInfo() async {
    // Listeners and the local plugin do not depend on the answer: a tap must
    // open its booking even when alerts were declined.
    await _ensureLocalReady();
    _listen();
    try {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      final NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      log("Notification permission: ${settings.authorizationStatus.name}");
    } catch (e) {
      log("Notification permission request failed: $e");
    }
    await _handleLaunchTaps();
    unawaited(_subscribeToTopic());
  }

  // ---------------------------------------------------------------------------
  // Android channel and local notifications
  // ---------------------------------------------------------------------------

  /// Creates the app's channel. Called in main() before runApp, so the channel
  /// exists before any push can arrive: a push for a channel the device does not
  /// have lands on a silent "Miscellaneous" channel instead. Needs no permission.
  static Future<void> createAndroidChannels() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_channel);
    } catch (e) {
      log("Notification channel not created: $e");
    }
  }

  static Future<void>? _localInit;

  static Future<void> _ensureLocalReady() {
    return _localInit ??= _initLocal().catchError((Object e) {
      _localInit = null;
      log("Local notifications not initialised: $e");
    });
  }

  static Future<void> _initLocal() async {
    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      // No prompts here: the permission is asked once, by initInfo.
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) => handleTap(decodeTapPayload(response.payload)),
    );
    await createAndroidChannels();
  }

  static NotificationDetails _details() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        ticker: 'ticker',
      ),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );
  }

  /// Shows [message] as a local notification on the app's channel. Its data is
  /// the payload, so a tap routes like a tap on the push itself.
  static Future<void> showLocal(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;
    final String title = (notification?.title ?? '').trim().isNotEmpty ? notification!.title! : pushDataString(message.data, 'title');
    final String body = (notification?.body ?? '').trim().isNotEmpty ? notification!.body! : pushDataString(message.data, 'body');
    if (title.isEmpty && body.isEmpty) return;
    try {
      await _ensureLocalReady();
      await _plugin.show(
        // One id per push: a fixed id made every new push replace the last one.
        id: (message.messageId ?? '${DateTime.now().microsecondsSinceEpoch}').hashCode & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: _details(),
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      log("Local notification not shown: $e");
    }
  }

  /// FCM does not display anything while the app is in the foreground on
  /// Android, so the push is shown locally. iOS presents a notification message
  /// itself (setForegroundNotificationPresentationOptions): a local copy would
  /// show it twice. A data-only message is shown on both.
  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    if (message.notification != null && defaultTargetPlatform == TargetPlatform.iOS) return;
    await showLocal(message);
  }

  static bool _listening = false;

  /// One onMessage and one onMessageOpenedApp listener per launch.
  static void _listen() {
    if (_listening) return;
    _listening = true;
    FirebaseMessaging.onMessage.listen(_onForegroundMessage, onError: (Object e) => log("onMessage failed: $e"));
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) => handleTap(message.data), onError: (Object e) => log("onMessageOpenedApp failed: $e"));
  }

  static Future<void> _subscribeToTopic() async {
    try {
      // iOS refuses topic calls until the APNs token is there.
      if (await _waitForApnsToken()) await FirebaseMessaging.instance.subscribeToTopic("provider");
    } catch (e) {
      log("Topic subscription failed: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // Taps
  // ---------------------------------------------------------------------------

  static Map<String, dynamic>? _pendingTap;
  static bool _homeReady = false;

  /// The app was started by tapping a push (or a local notification).
  static Future<void> _handleLaunchTaps() async {
    try {
      final RemoteMessage? initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        handleTap(initial.data);
        return;
      }
    } catch (e) {
      log("Initial push not read: $e");
    }
    try {
      final NotificationAppLaunchDetails? details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp == true) handleTap(decodeTapPayload(details!.notificationResponse?.payload));
    } catch (e) {
      log("Launch notification not read: $e");
    }
  }

  /// Opens the screen a tapped push is about.
  ///
  /// A tap that arrives before the dashboard is up (a cold start: the splash
  /// replaces every route 3 s later and nobody is signed in yet) is kept and
  /// opened by [onHomeReady].
  static void handleTap(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    if (!_homeReady || MyAppState.currentUser == null || auth.FirebaseAuth.instance.currentUser == null) {
      _pendingTap = data;
      return;
    }
    _route(data);
  }

  /// The dashboard is showing: open a tap that arrived earlier.
  static void onHomeReady() {
    _homeReady = true;
    final Map<String, dynamic>? pending = _pendingTap;
    _pendingTap = null;
    if (pending != null) _route(pending);
  }

  static void _route(Map<String, dynamic> data) {
    try {
      final String type = pushDataString(data, 'type');
      final String orderId = pushDataString(data, 'orderId');
      switch (type) {
        case 'provider_order':
        case 'booking_placed':
          if (orderId.isEmpty) return;
          Get.to(() => const BookingDetailsScreen(), arguments: {"orderId": orderId});
          break;
        case 'orderChat':
          // A customer's or worker's chat message: `senderId` is the other side.
          final String otherId = pushDataString(data, 'senderId');
          if (orderId.isEmpty || otherId.isEmpty) return;
          Get.to(() => const ChatScreen(), arguments: {
            "senderName": MyAppState.currentUser?.fullName() ?? '',
            "senderId": FireStoreUtils.getCurrentUid(),
            "senderProfileUrl": MyAppState.currentUser?.profilePictureURL ?? '',
            "receivedName": pushDataString(data, 'senderName'),
            "receivedId": otherId,
            "receivedProfileUrl": '',
            "orderId": orderId,
            "token": '',
            "chatType": pushDataString(data, 'chatType'),
          });
          break;
        case 'provider_chat':
          if (orderId.isEmpty) return;
          Get.to(() => const ChatScreen(), arguments: {
            "senderName": pushDataString(data, 'senderName'),
            "senderId": pushDataString(data, 'senderId'),
            "senderProfileUrl": pushDataString(data, 'senderProfileUrl'),
            "receivedName": pushDataString(data, 'receivedName'),
            "receivedId": pushDataString(data, 'receivedId'),
            "receivedProfileUrl": pushDataString(data, 'receivedProfileUrl'),
            "orderId": orderId,
            "token": pushDataString(data, 'token'),
            "chatType": pushDataString(data, 'chatType'),
          });
          break;
        case 'admin_chat':
        case 'admin':
          // The drawer position of Help & Support moves with the optional
          // Subscription item, so the screen is opened directly.
          Get.to(() => HelpSupportScreen());
          break;
      }
    } catch (e) {
      log("Notification tap not routed: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // FCM token
  // ---------------------------------------------------------------------------

  static String _deviceToken = '';
  static Future<bool>? _apnsWait;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<auth.User?>? _authSubscription;

  /// This device's FCM token as last read, '' when not known yet.
  static String get deviceToken => _deviceToken;

  /// On iOS FCM has no token, and getToken() throws `apns-token-not-set`,
  /// until APNs has given the app its device token, which can take a few
  /// seconds after launch. Polled every 500 ms for up to 10 s; a failed wait is
  /// retried by the next caller.
  static Future<bool> _waitForApnsToken() {
    if (defaultTargetPlatform != TargetPlatform.iOS) return Future<bool>.value(true);
    return _apnsWait ??= _pollApnsToken().then((bool ok) {
      if (!ok) _apnsWait = null;
      return ok;
    });
  }

  static Future<bool> _pollApnsToken() async {
    for (int attempt = 0; attempt < 20; attempt++) {
      try {
        final String? apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns != null && apns.isNotEmpty) return true;
      } catch (_) {
        // Not registered yet: keep waiting.
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    log("No APNs token after 10 s: check the Push Notifications capability and the APNs key in the Firebase console.");
    return false;
  }

  /// The device's FCM token, or '' when there is not one yet. Never throws.
  /// [apnsWait] bounds the wait for the APNs token on iOS (short in sign-in
  /// flows; the background sync waits longer and refreshes cover the rest).
  static Future<String> getToken({Duration apnsWait = const Duration(seconds: 4)}) async {
    try {
      final bool ready = await _waitForApnsToken().timeout(apnsWait, onTimeout: () => false);
      if (!ready) return '';
      final String token = (await FirebaseMessaging.instance.getToken() ?? '').trim();
      if (!isUsableFcmToken(token)) return '';
      _deviceToken = token;
      return token;
    } catch (e) {
      log("FCM token unavailable: $e");
      return '';
    }
  }

  /// This device's token, or [current] when there is none yet, so a sign-in
  /// never replaces a working stored token with ''.
  static Future<String> freshTokenOr(String? current) async {
    final String token = await getToken();
    return isUsableFcmToken(token) ? token : (current ?? '');
  }

  /// Writes this device's FCM token to the signed-in provider's document now,
  /// and again on every token refresh and every sign-in.
  ///
  /// Without this the token on the document goes stale the first time it is
  /// refreshed, and an iPhone whose APNs token arrived after the first read
  /// never stores one: the provider can no longer be reached by booking or chat
  /// pushes. Safe to call before sign-in: it simply writes nothing.
  static Future<void> syncTokenToUserDoc() async {
    // Subscribed first, so a token generated while we wait is not missed.
    _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen(
      (String token) {
        if (isUsableFcmToken(token)) _deviceToken = token.trim();
        _writeToken(token);
      },
      onError: (Object e) => log("FCM token refresh failed: $e"),
    );
    // Covers every sign-in path (email, phone, Google, Apple, sign-up).
    _authSubscription ??= auth.FirebaseAuth.instance.authStateChanges().listen(
      (auth.User? user) {
        if (user != null) unawaited(getToken(apnsWait: const Duration(seconds: 10)).then(_writeToken));
      },
      onError: (Object e) => log("Auth state listener failed: $e"),
    );
    await _writeToken(await getToken(apnsWait: const Duration(seconds: 10)));
  }

  /// Field-level write of `fcmToken` only, and only onto the signed-in user's
  /// existing provider record (see [shouldWriteDeviceToken]).
  static Future<void> _writeToken(String token) async {
    if (!isUsableFcmToken(token)) return;
    final String? uid = auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      final ref = FireStoreUtils.firestore.collection(USERS).doc(uid);
      final snapshot = await ref.get();
      final Map<String, dynamic>? data = snapshot.data();
      if (MyAppState.currentUser?.id == uid) MyAppState.currentUser?.fcmToken = token.trim();
      if (!shouldWriteDeviceToken(
        token: token,
        docExists: snapshot.exists,
        role: data?['role']?.toString(),
        storedToken: data?['fcmToken']?.toString(),
      )) {
        return;
      }
      await ref.update({"fcmToken": token.trim()});
    } catch (e) {
      log("FCM token not stored: $e");
    }
  }

  /// Before signing out (or turning away a disabled account): clears the stored
  /// token, field-level, only while it is still this device's.
  static Future<void> clearTokenOnSignOut(String uid) async {
    _homeReady = false;
    _pendingTap = null;
    if (uid.isEmpty) return;
    String token = _deviceToken;
    if (!isUsableFcmToken(token)) token = await getToken(apnsWait: const Duration(seconds: 2));
    if (!isUsableFcmToken(token)) return;
    await FireStoreUtils.clearFcmTokenIfMatches(uid, token);
  }
}

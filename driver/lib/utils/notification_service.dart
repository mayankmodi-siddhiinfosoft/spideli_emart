import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/app/chat_screens/chat_screen.dart';
import 'package:driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/dash_board_controller.dart';
import 'package:driver/controllers/signup_controller.dart';
import 'package:driver/firebase_options.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/carrier_dispatch_service.dart';
import 'package:driver/services/driver_assignment_watcher.dart';
import 'package:driver/services/driver_job_queue_service.dart';
import 'package:driver/services/push_message.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Background / terminated messages. Registered once in `main()` with
/// `FirebaseMessaging.onBackgroundMessage`; runs in its own isolate, so it
/// initialises Firebase itself.
///
/// A message with a `notification` block is shown by the system (on the
/// channel the sender named, else the manifest default channel). A data-only
/// message is not shown by anyone, so on Android it is posted here when it
/// carries a title or body.
@pragma('vm:entry-point')
Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    log("Background push: Firebase init failed: $e");
  }
  if (message.notification == null && _isAndroid) {
    await NotificationService.showDataOnly(message);
  }
}

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // ── Android channels ──────────────────────────────────────────────────────
  //
  // Both ids are created in `main()` before `runApp` (and again here), so they
  // exist before any push can arrive. A push names one of them in
  // `android.notification.channel_id`; one that names none lands on the
  // manifest's `default_notification_channel_id` (the general channel).
  // Without that pairing the Firebase SDK posts on a fallback channel it makes
  // itself with DEFAULT importance: no heads-up banner and no sound
  // (report #19). An existing channel's importance and sound can never be
  // changed afterwards, so bump the id if either ever has to change.

  /// General driver channel: order updates, chat, cancellations. Manifest
  /// default. See `.claude/PUSH-CHANNELS.md`.
  static const String generalChannelId = PushChannels.driver;

  /// Loud job channel: a new or assigned delivery / ride / parcel / rental
  /// job. Importance max, played on the ringtone stream.
  static const String jobChannelId = PushChannels.driverJob;

  static const AndroidNotificationChannel _generalChannel = AndroidNotificationChannel(
    generalChannelId,
    'Driver Notifications',
    description: 'Order updates, chat messages and other notifications',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _jobChannel = AndroidNotificationChannel(
    jobChannelId,
    'New jobs',
    description: 'Loud alert for a new or assigned delivery, ride, parcel or rental job',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
  );

  static AndroidNotificationChannel _channel(String id) => id == jobChannelId ? _jobChannel : _generalChannel;

  /// Creates both channels. Safe to call repeatedly: Android keeps a channel
  /// the user already has (including any sound or importance they changed).
  static Future<void> createChannels() async {
    if (!_isAndroid) return;
    try {
      final AndroidFlutterLocalNotificationsPlugin? android =
          FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_generalChannel);
      await android?.createNotificationChannel(_jobChannel);
    } catch (e) {
      log("createNotificationChannel failed: $e");
    }
  }

  // ── Start-up ──────────────────────────────────────────────────────────────

  static bool _initialized = false;
  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<RemoteMessage>? _onOpenedSub;

  /// Once per app run (GlobalSettingController). Nothing here waits for the
  /// permission answer: listeners, channels and the token work without it,
  /// and the permission is asked after the first frame.
  Future<void> initInfo() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // iOS shows a push that arrives in the foreground itself with these
      // options, so the app never posts a second, local copy there.
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    } catch (e) {
      log("setForegroundNotificationPresentationOptions failed: $e");
    }

    await createChannels();

    try {
      const InitializationSettings initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_notification'),
        // The permission is asked once, by FirebaseMessaging.requestPermission
        // below; the plugin's defaults would ask a second time on initialize.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) => _routeTap(_decodePayload(response.payload)),
      );
      // A local notification (job queue, assignment, foreground push) tapped
      // while the app was closed.
      final NotificationAppLaunchDetails? launch = await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _queueTap(_decodePayload(launch?.notificationResponse?.payload));
      }
    } catch (e) {
      log("Local notifications init failed: $e");
    }

    await _setupInteractedMessage();

    // FCM rotates the token; on iOS the first token also arrives through this
    // stream once the APNs token is in.
    listenForTokenRefresh();
    // Warm the token so sign-in / OTP screens can use it without waiting.
    unawaited(getToken());
    unawaited(_requestPermissionAfterFirstFrame());
  }

  static Future<void> _requestPermissionAfterFirstFrame() async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      final NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      log("Notification permission: ${settings.authorizationStatus.name}");
    } catch (e) {
      log("Notification permission request failed: $e");
    }
  }

  Future<void> _setupInteractedMessage() async {
    try {
      // App opened from a terminated state by tapping a push.
      final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) _queueTap(initialMessage.data);
    } catch (e) {
      log("getInitialMessage failed: $e");
    }

    // App in the background, push tapped.
    _onOpenedSub ??= FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) => _routeTap(message.data),
      onError: (Object e) => log("onMessageOpenedApp failed: $e"),
    );

    // App in the foreground.
    _onMessageSub ??= FirebaseMessaging.onMessage.listen(
      _onForegroundMessage,
      onError: (Object e) => log("onMessage failed: $e"),
    );
  }

  void _onForegroundMessage(RemoteMessage message) {
    // FCM never displays a push while the app is in the foreground on
    // Android, so it is posted locally. iOS already shows it (presentation
    // options above): a local copy there would show it twice.
    if (!_isAndroid) return;
    display(message);
  }

  // ── Token + topics (client point 19) ──────────────────────────────────────

  /// This device's last known FCM token.
  static String _deviceToken = '';
  static Future<String>? _tokenFetch;

  /// The last token this device obtained, without waiting ('' if none yet).
  static String get cachedToken => _deviceToken;

  /// This device's FCM token, or '' when there is none yet. Never throws.
  ///
  /// On iOS `getToken()` throws `apns-token-not-set` until the APNs token has
  /// arrived; this waits for it (up to [apnsWait]) first. The callers used to
  /// let that throw escape (the OTP button kept its loader up, the splash
  /// stopped) or saved '' as the token, so the iPhone never got a push.
  static Future<String> getToken({Duration apnsWait = const Duration(seconds: 10)}) {
    return _tokenFetch ??= _fetchToken(apnsWait).whenComplete(() => _tokenFetch = null);
  }

  static Future<String> _fetchToken(Duration apnsWait) async {
    try {
      if (_isIOS && !await _waitForApnsToken(apnsWait)) {
        log("APNs token not available yet; the FCM token is saved from onTokenRefresh when it arrives.");
        return _deviceToken;
      }
      final String token = ((await FirebaseMessaging.instance.getToken()) ?? '').trim();
      if (PushMessage.isUsableToken(token)) _deviceToken = token;
      return _deviceToken;
    } catch (e) {
      log("getToken failed: $e");
      return _deviceToken;
    }
  }

  static Future<bool> _waitForApnsToken(Duration maxWait) async {
    final DateTime deadline = DateTime.now().add(maxWait);
    while (true) {
      try {
        final String? apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns != null && apns.isNotEmpty) return true;
      } catch (e) {
        log("getAPNSToken failed: $e");
      }
      if (!DateTime.now().isBefore(deadline)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

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

  /// Writes [token] on the signed-in driver's user document, field-level
  /// (only `fcmToken`). An unusable token never replaces a good one, and
  /// [storedToken] (when the caller has just read it) skips a write that
  /// would change nothing.
  ///
  /// `update()`, not a merge `set()`: a user document that does not exist
  /// (sign-up not finished, account deleted) is never re-created as a stub,
  /// which would lock the number out of login and sign-up.
  static Future<bool> saveToken(String token, {String? storedToken}) async {
    final String t = token.trim();
    if (!PushMessage.isUsableToken(t)) return false;
    _deviceToken = t;
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return false;
    if (storedToken != null && !PushTokenRules.shouldSave(deviceToken: t, storedToken: storedToken)) return true;
    try {
      await FireStoreUtils.fireStore.collection(CollectionName.users).doc(uid).update({'fcmToken': t});
      if (Constant.userModel?.id == uid) Constant.userModel?.fcmToken = t;
      return true;
    } catch (e) {
      log("saveToken failed: $e");
      return false;
    }
  }

  /// Keeps the stored token current: FCM rotates it (app reinstall, restore,
  /// cache clear) and the old one stops delivering. One subscription for the
  /// whole app run; a refresh while signed out writes nothing.
  static void listenForTokenRefresh() {
    _tokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen(
      (String token) async {
        log("FCM token refreshed");
        await saveToken(token);
      },
      onError: (Object e) => log("onTokenRefresh failed: $e"),
    );
  }

  /// Everything a signed-in driver's device needs to receive pushes: the
  /// token saved (field-level) and kept fresh, and, for an active driver, the
  /// topics the server addresses work by. Called on every app start and after
  /// login / sign-up / OTP. Never throws; safe to call without awaiting.
  static Future<void> syncSignedInDevice(UserModel? driver) async {
    listenForTokenRefresh();
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    try {
      final UserModel? me = (driver != null && driver.id == uid) ? driver : null;
      final String token = await getToken();
      if (PushMessage.isUsableToken(token)) {
        await saveToken(token, storedToken: me == null ? null : (me.fcmToken ?? ''));
      }
      if (me != null && me.active == true) await subscribeDriverTopics(me);
    } catch (e) {
      log("syncSignedInDevice failed: $e");
    }
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

  /// This device's token without the long APNs wait (sign-out must not hang).
  static Future<String> _quickToken() async {
    if (_deviceToken.isNotEmpty) return _deviceToken;
    try {
      if (_isIOS && (await FirebaseMessaging.instance.getAPNSToken()) == null) return '';
      final String token = ((await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 3))) ?? '').trim();
      return PushMessage.isUsableToken(token) ? token : '';
    } catch (_) {
      return '';
    }
  }

  /// Sign-out: the device must stop receiving this driver's work, and the
  /// token must stop pointing at them.
  ///
  /// The stored token is cleared only when it is still THIS device's (the
  /// driver may have signed in on another phone since), in a transaction
  /// that never creates the document.
  ///
  /// [clearStoredToken] false skips the `users/{uid}` write: for an account
  /// whose user document is gone (`DriverSessions.endDeletedAccount`). The
  /// topics are still unsubscribed, so the device stops getting that
  /// driver's job pushes.
  static Future<void> onSignOut({bool clearStoredToken = true}) async {
    for (final String topic in _topics.toList()) {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      } catch (e) {
        log("unsubscribeFromTopic $topic failed: $e");
      }
    }
    _topics.clear();
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (clearStoredToken && uid.isNotEmpty) {
      final String deviceToken = await _quickToken();
      if (PushMessage.isUsableToken(deviceToken)) {
        try {
          final DocumentReference<Map<String, dynamic>> ref = FireStoreUtils.fireStore.collection(CollectionName.users).doc(uid);
          await FireStoreUtils.fireStore.runTransaction<void>((Transaction tx) async {
            final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
            if (!snap.exists) return;
            final String stored = (snap.data()?['fcmToken'] ?? '').toString();
            if (PushTokenRules.shouldClearOnSignOut(storedToken: stored, deviceToken: deviceToken)) {
              tx.update(ref, {'fcmToken': ''});
            }
          }, timeout: const Duration(seconds: 5));
        } catch (e) {
          log("clearing fcmToken failed: $e");
        }
      }
    }
    Constant.userModel?.fcmToken = '';
    DriverJobQueueService.reset();
    DriverAssignmentWatcher.stop();
    CarrierDispatchService.clearCache();
  }

  // ── Display ───────────────────────────────────────────────────────────────

  static int _notificationId(RemoteMessage message) {
    final int id = (message.messageId ?? '${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}').hashCode & 0x7fffffff;
    // 9114 / 9115 belong to the job queue and assignment watcher.
    return (id == 9114 || id == 9115) ? id + 2 : id;
  }

  static NotificationDetails _details(String channelId) {
    final AndroidNotificationChannel channel = _channel(channelId);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: channel.audioAttributesUsage,
        icon: '@drawable/ic_stat_notification',
        ticker: 'ticker',
      ),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );
  }

  /// Posts [message] locally (Android foreground) on the channel it belongs
  /// to: the one the sender named, else the job channel for a job, else the
  /// general channel.
  void display(RemoteMessage message) async {
    try {
      final String? title = message.notification?.title ?? message.data['title']?.toString();
      final String? body = message.notification?.body ?? message.data['body']?.toString();
      if ((title ?? '').isEmpty && (body ?? '').isEmpty) return;
      final String channelId = PushChannels.driverChannelFor(
        type: message.data['type']?.toString(),
        requestedChannelId: message.notification?.android?.channelId,
      );
      await flutterLocalNotificationsPlugin.show(
        id: _notificationId(message),
        title: title,
        body: body,
        notificationDetails: _details(channelId),
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      log("Notification display error: $e");
    }
  }

  /// A data-only push received in the background (Android): nothing else
  /// would show it.
  static Future<void> showDataOnly(RemoteMessage message) async {
    try {
      final String title = (message.data['title'] ?? '').toString();
      final String body = (message.data['body'] ?? '').toString();
      if (title.isEmpty && body.isEmpty) return;
      await createChannels();
      final String channelId = PushChannels.driverChannelFor(type: message.data['type']?.toString());
      await FlutterLocalNotificationsPlugin().show(
        id: _notificationId(message),
        title: title,
        body: body,
        notificationDetails: _details(channelId),
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      log("Background data push display failed: $e");
    }
  }

  // ── Taps ──────────────────────────────────────────────────────────────────

  static Map<String, dynamic>? _pendingTap;
  static bool _appRouted = false;

  static Map<String, dynamic>? _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(payload);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  /// A tap that opened the app: handled once the splash has opened the first
  /// screen, or the splash's own navigation would replace the one the tap
  /// opened.
  static void _queueTap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return;
    if (_appRouted) {
      _routeTap(data);
    } else {
      _pendingTap = data;
    }
  }

  /// Called by the splash once it has navigated.
  static void onAppRouted() {
    _appRouted = true;
    final Map<String, dynamic>? pending = _pendingTap;
    _pendingTap = null;
    if (pending != null) {
      Future<void>.delayed(const Duration(milliseconds: 400), () => _routeTap(pending));
    }
  }

  static void _routeTap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return;
    String field(String key) => (data[key] ?? '').toString();
    handleMessageClick(type: field('type'), role: field('chatType'), orderId: field('orderId'), senderId: field('senderId'))
        .catchError((Object e) => log("Notification tap failed: $e"));
  }

  static Future<void> handleMessageClick({required String type, String? senderId, String? orderId, required String role}) async {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    if (type == 'admin_chat') {
      DashBoardController controller = Get.put(DashBoardController());
      controller.drawerIndex.value = 7;
      Get.offAll(DashBoardScreen());
    } else if (type == 'orderChat') {
      ShowToastDialog.showLoader("Please wait".tr);
      UserModel? customer;
      UserModel? driver;
      try {
        if ((senderId ?? '').isNotEmpty) customer = await FireStoreUtils.getUserProfile(senderId!);
        driver = await FireStoreUtils.getUserProfile(uid);
      } finally {
        ShowToastDialog.closeLoader();
      }
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
    } else if (PushChannels.driverJobTypes.contains(type)) {
      // Client point 19: tapping an "order available" push lands the driver on
      // the home of the module the job belongs to.
      final UserModel? me = Constant.userModel ?? await FireStoreUtils.getUserProfile(uid);
      if (me != null) SignupController.navigateByUserModel(me);
    }
  }
}

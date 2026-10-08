import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/app/chat_screens/chat_screen.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/signup_controller.dart';
import 'package:driver/firebase_options.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/dashboard_navigation.dart';
import 'package:driver/services/carrier_dispatch_service.dart';
import 'package:driver/services/dispatch_offer_rules.dart';
import 'package:driver/services/driver_assignment_watcher.dart';
import 'package:driver/services/driver_job_queue_service.dart';
import 'package:driver/services/incoming_offer_service.dart';
import 'package:driver/services/offer_seen_store.dart';
import 'package:driver/services/push_message.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:driver/utils/fcm_token_reset.dart';

bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Background / terminated messages. Registered once in `main()` with
/// `FirebaseMessaging.onBackgroundMessage`; runs in its own isolate, so it
/// initialises Firebase itself.
///
/// A message with a `notification` block is shown by the system (on the
/// channel the sender named — the dispatch Cloud Function names `spideli` —
/// else the manifest default channel); it is never posted a second time here.
/// A data-only message is not shown by anyone, so on Android it is posted
/// here when it carries a title or body.
///
/// A dispatch offer (DispatchPush) is also recorded per order id at its
/// sentTime — or at its receipt, when the sentTime lies further back than a
/// delivery takes (a device clock ahead of the server, [OfferTiming.pushStart])
/// — in [OfferSeenStore] (SharedPreferences opened directly:
/// `Preferences.initPref` never runs in this isolate), so the incoming-offer
/// countdown starts at the push, and an offer whose window ran out while the
/// app was closed is rejected when it opens (D3).
@pragma('vm:entry-point')
Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    log("Background push: Firebase init failed: $e");
  }
  final DispatchPush? dispatch = DispatchPush.parse(message.data, sentTime: message.sentTime);
  if (dispatch != null) {
    await OfferSeenStore.record(dispatch.orderId, OfferTiming.pushStart(sentTime: message.sentTime, receivedAt: DateTime.now()), push: true);
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

  /// The dispatch Cloud Functions' channel (DRIVER_DISPATCH_DOCUMENTATION.md
  /// §5A): an offer to accept or reject. Importance max, default sound,
  /// vibration.
  static const String dispatchChannelId = PushChannels.dispatch;

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

  static const AndroidNotificationChannel _dispatchChannel = AndroidNotificationChannel(
    dispatchChannelId,
    'Spideli Order Notifications',
    description: 'New delivery, parcel, ride and rental orders to accept or reject',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static AndroidNotificationChannel _channel(String id) {
    switch (id) {
      case jobChannelId:
        return _jobChannel;
      case dispatchChannelId:
        return _dispatchChannel;
      default:
        return _generalChannel;
    }
  }

  /// Creates every channel (general, jobs, dispatch). Safe to call
  /// repeatedly: Android keeps a channel the user already has (including any
  /// sound or importance they changed).
  static Future<void> createChannels() async {
    if (!_isAndroid) return;
    try {
      final AndroidFlutterLocalNotificationsPlugin? android =
          FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_generalChannel);
      await android?.createNotificationChannel(_jobChannel);
      await android?.createNotificationChannel(_dispatchChannel);
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
      if (initialMessage != null) _queueTap(_withSentTime(initialMessage));
    } catch (e) {
      log("getInitialMessage failed: $e");
    }

    // App in the background, push tapped.
    _onOpenedSub ??= FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) => _routeTap(_withSentTime(message)),
      onError: (Object e) => log("onMessageOpenedApp failed: $e"),
    );

    // App in the foreground.
    _onMessageSub ??= FirebaseMessaging.onMessage.listen(
      _onForegroundMessage,
      onError: (Object e) => log("onMessage failed: $e"),
    );
  }

  void _onForegroundMessage(RemoteMessage message) {
    // A dispatch offer (spec §5B): the order is read from Firestore and, while
    // it is still Driver Pending for this driver, the incoming-order dialog
    // opens over whatever screen is up — on both platforms.
    final DispatchPush? dispatch = DispatchPush.parse(message.data, sentTime: message.sentTime);
    if (dispatch != null) {
      unawaited(IncomingOfferService.onDispatchPush(dispatch).catchError((Object e) => log("Dispatch push failed: $e")));
    }
    // FCM never displays a push while the app is in the foreground on
    // Android, so it is posted locally (a dispatch offer on `spideli`, D4).
    // iOS already shows it (presentation options above): a local copy there
    // would show it twice.
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
      // A token restored from an Android backup is dead: replace it once.
      await FcmTokenReset.runOnce();
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

  /// Topics an EARLIER run of the app subscribed this device to and this run
  /// has not re-subscribed or dropped yet. Persisted with [_topics]
  /// ([_topicsPrefKey]) so a zone / region / service that changed while the
  /// app was closed is still unsubscribed at the next start, instead of the
  /// device staying on the old topics for good. Loaded on first use.
  static Set<String>? _previousTopics;

  static const String _topicsPrefKey = 'driverPushTopics';

  static Set<String> _previous() {
    if (_previousTopics != null) return _previousTopics!;
    try {
      _previousTopics = (Preferences.pref.getStringList(_topicsPrefKey) ?? const <String>[]).toSet();
    } catch (e) {
      log("reading stored push topics failed: $e");
      _previousTopics = <String>{};
    }
    return _previousTopics!;
  }

  /// Stores every topic this device may be subscribed to.
  static void _persistTopics() {
    try {
      unawaited(Preferences.pref.setStringList(_topicsPrefKey, {..._topics, ..._previous()}.toList()));
    } catch (e) {
      log("storing push topics failed: $e");
    }
  }

  /// Unsubscribes every held topic (this run's or an earlier one's) that is
  /// not in [wanted]. Not awaited: offline, an unsubscribe can wait a long
  /// time and FCM finishes it on its own.
  static void _dropTopicsNotIn(Set<String> wanted) {
    for (final String topic in {..._topics, ..._previous()}.difference(wanted)) {
      unawaited(_unsubscribe(topic));
    }
  }

  static StreamSubscription<String>? _tokenRefreshSub;

  /// Topic subscribe / unsubscribe calls in flight, so the stream of user
  /// snapshots (one per location update) never stacks the same call.
  static final Set<String> _topicCalls = <String>{};

  static Future<void> _subscribe(String topic) async {
    if (topic.isEmpty || _topics.contains(topic) || !_topicCalls.add(topic)) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      _topics.add(topic);
      _previous().remove(topic);
      _persistTopics();
    } catch (e) {
      log("subscribeToTopic $topic failed: $e");
    } finally {
      _topicCalls.remove(topic);
    }
  }

  static Future<void> _unsubscribe(String topic) async {
    if ((!_topics.contains(topic) && !_previous().contains(topic)) || !_topicCalls.add(topic)) return;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      _topics.remove(topic);
      _previous().remove(topic);
      _persistTopics();
    } catch (e) {
      log("unsubscribeFromTopic $topic failed: $e");
    } finally {
      _topicCalls.remove(topic);
    }
  }

  static Set<String> _topicsFor(UserModel driver, {bool? active}) => PushTopics.forDriver(
        active: active ?? driver.active == true,
        isOwner: driver.isOwner == true,
        // Stored values and the modules they name (spec aliases).
        serviceTypes: {...?driver.serviceTypes, ...driver.serviceModules},
        sectionIds: driver.sectionIds,
        zoneId: driver.zoneId,
        zoneIds: driver.zoneIds,
        regionId: driver.regionId,
        ownerId: driver.ownerId,
        carrierId: driver.carrierId,
      );

  /// Keeps the topics in step with the LIVE driver record (doc 21): called
  /// from every dashboard's `users/{me}` listener, so an account approved,
  /// a zone / region / service changed or a driver moved to a company while
  /// the app is open is addressed by its new topics at once (they used to be
  /// subscribed only at start-up / sign-in), and a topic the driver no longer
  /// belongs to is dropped - including one subscribed by an earlier run of
  /// the app ([_previousTopics]). Cheap when nothing changed: no FCM call.
  static void syncDriverTopics(UserModel? driver) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (driver == null || uid.isEmpty || driver.id != uid) return;
    final Set<String> wanted = _topicsFor(driver);
    _dropTopicsNotIn(wanted);
    for (final String topic in wanted.difference(_topics)) {
      unawaited(_subscribe(topic));
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
  /// a token list (client point 19). The set is [PushTopics.forDriver]:
  /// `driver`, `driver_<serviceType>`, `section_<sectionId>`, `zone_<id>` for
  /// every zone, `region_<regionId>`, `company_<ownerId>`, `carrier_<id>`
  /// (a company account: `company_` / `carrier_` only). Topics an earlier run
  /// subscribed that the account no longer belongs to are dropped.
  static Future<void> subscribeDriverTopics(UserModel? driver) async {
    if (driver == null) return;
    final Set<String> wanted = _topicsFor(driver, active: true);
    _dropTopicsNotIn(wanted);
    for (final String topic in wanted) {
      await _subscribe(topic);
    }
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
    // In parallel and bounded: with Play services slow or offline an
    // unsubscribe can wait indefinitely ("Will retry"), which used to hang
    // the log-out. FCM finishes pending topic operations on its own later.
    final List<String> topics = {..._topics, ..._previous()}.toList();
    _topics.clear();
    _previous().clear();
    _persistTopics();
    try {
      await Future.wait(topics.map((String topic) async {
        try {
          await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
        } catch (e) {
          log("unsubscribeFromTopic $topic failed: $e");
        }
      })).timeout(const Duration(seconds: 4));
    } catch (e) {
      log("Topic unsubscribe did not finish in time: $e");
    }
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
    IncomingOfferService.stop();
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
        data: message.data,
      );
      await flutterLocalNotificationsPlugin.show(
        id: _notificationId(message),
        title: title,
        body: body,
        notificationDetails: _details(channelId),
        payload: jsonEncode(_withSentTime(message)),
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
      final String channelId = PushChannels.driverChannelFor(type: message.data['type']?.toString(), data: message.data);
      await FlutterLocalNotificationsPlugin().show(
        id: _notificationId(message),
        title: title,
        body: body,
        notificationDetails: _details(channelId),
        payload: jsonEncode(_withSentTime(message)),
      );
    } catch (e) {
      log("Background data push display failed: $e");
    }
  }

  // ── Taps ──────────────────────────────────────────────────────────────────

  static Map<String, dynamic>? _pendingTap;
  static bool _appRouted = false;

  /// Key under which a tapped push's sentTime travels with its data until the
  /// tap is routed (a terminated launch is routed after the splash).
  static const String _sentTimeKey = '__sentTime';

  static Map<String, dynamic> _withSentTime(RemoteMessage message) => <String, dynamic>{
        ...message.data,
        if (message.sentTime != null) _sentTimeKey: message.sentTime!.millisecondsSinceEpoch,
      };

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
    IncomingOfferService.onAppReady();
    final Map<String, dynamic>? pending = _pendingTap;
    _pendingTap = null;
    if (pending != null) {
      Future<void>.delayed(const Duration(milliseconds: 400), () => _routeTap(pending));
    }
  }

  static void _routeTap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return;
    String field(String key) => (data[key] ?? '').toString().trim();
    final String orderId = field('orderId').isNotEmpty ? field('orderId') : field('id');
    // A push about an order of a dispatched service (data.type order /
    // parcel / cab / rental): the incoming-order dialog while the order is
    // still Driver Pending for this driver, else that module's job screen.
    // Never Get.offAll, which reset the navigation and showed no dialog.
    final DispatchKind? kind = DispatchKind.fromPushType(field('type'));
    if (kind != null && orderId.isNotEmpty && !orderId.contains('/')) {
      final dynamic sentMs = data[_sentTimeKey];
      final DateTime? sentTime = sentMs is int ? DateTime.fromMillisecondsSinceEpoch(sentMs) : null;
      final bool isDispatch = DispatchPush.parse(data, sentTime: sentTime) != null;
      IncomingOfferService.onDispatchPush(DispatchPush(kind, orderId, sentTime: sentTime), tapped: true, isDispatch: isDispatch)
          .catchError((Object e) => log("Notification tap failed: $e"));
      return;
    }
    handleMessageClick(type: field('type'), role: field('chatType'), orderId: orderId, senderId: field('senderId'))
        .catchError((Object e) => log("Notification tap failed: $e"));
  }

  static Future<void> handleMessageClick({required String type, String? senderId, String? orderId, required String role}) async {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    // DashboardNavigation: the running dashboards are reused (or closed
    // cleanly), never adopted by a second copy that then loses its listeners.
    if (type == 'admin_chat') {
      await DashboardNavigation.openDeliveryPage(7);
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
        await DashboardNavigation.openDeliveryPage(5);
        return;
      }
      await DashboardNavigation.openDeliveryPage(5);
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

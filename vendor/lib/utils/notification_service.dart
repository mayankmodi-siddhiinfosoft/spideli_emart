import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:vendor/app/chat_screens/restaurant_inbox_screen.dart';
import 'package:vendor/app/help_support_screen/help_support_screen.dart';
import 'package:vendor/controller/dash_board_controller.dart';
import 'package:vendor/controller/home_controller.dart';
import 'package:vendor/firebase_options.dart';
import 'package:vendor/service/audio_player_service.dart';
import 'package:vendor/service/order_ringtone_service.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/order_ringtone.dart';
import 'package:vendor/utils/preferences.dart';
import 'package:vendor/utils/push_payload.dart';
import 'package:vendor/utils/fcm_token_reset.dart';
import 'package:vendor/utils/chat_sound.dart';
import 'package:vendor/utils/scheduled_order.dart';

/// Runs for a message that arrives while the app is in the background or
/// closed. Registered once from `main()` so it is always installed (report
/// #11). It runs in its own isolate on Android, so it starts Firebase itself.
///
/// A message with a `notification` block is shown by the system on the
/// channel it names (or the manifest default, `new_order`). A data-only
/// message that carries a title or body was never shown at all; it is shown
/// here.
@pragma('vm:entry-point')
Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    log("background Firebase init failed: $e");
  }
  log("BackGround Message :: ${message.messageId}");
  if (message.notification == null && NotificationService.hasDisplayableData(message.data)) {
    await NotificationService.display(message);
  }
  // A changed order ringtone (admin panel) is prepared here too, bounded, so
  // the next new-order push rings with it even if the app is not opened.
  try {
    FireStoreUtils.instance.init(Firebase.app(), databaseId: currentEnv == FirebaseEnv.defaultDb ? null : 'staging');
    await OrderRingtoneService.catchUpInBackground(forced: message.data['type'] == OrderRingtone.changedPushType);
  } catch (e) {
    log("background ringtone check failed: $e");
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// Loud channel for a new order: max importance (heads-up + sound even with
  /// the app closed) and the store's own alert tone.
  ///
  /// The id must match `com.google.firebase.messaging.default_notification_channel_id`
  /// in AndroidManifest.xml, and the id senders put in
  /// `android.notification.channel_id`, or Android posts the push on a channel
  /// it creates itself with default importance - silent and no heads-up. An
  /// existing channel's sound and importance cannot be changed afterwards, so
  /// the id is versioned: bump it if the tone ever changes.
  static const String orderChannelId = PushPayload.storeOrderChannelId;

  /// Everything that is not an order (chat, payouts, announcements).
  static const String generalChannelId = PushPayload.storeGeneralChannelId;

  /// `res/raw/order_alert.wav` (kept in release builds by `res/raw/keep.xml`).
  static const String orderSoundResource = PushPayload.storeOrderAndroidSound;

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
    playSound: true,
    enableVibration: true,
  );

  /// Chat messages: their own short sound (`res/raw/chat_message.wav`),
  /// never the order tone.
  static const AndroidNotificationChannel _chatChannel = AndroidNotificationChannel(
    ChatSound.channelId,
    ChatSound.channelName,
    description: ChatSound.channelDescription,
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound(ChatSound.androidSound),
    enableVibration: true,
  );

  static bool _initStarted = false;
  static bool _localReady = false;
  static bool _permissionRequested = false;
  static bool _topicSubscribed = false;
  static String _deviceToken = '';
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<RemoteMessage>? _onMessageOpenedSub;

  /// Sets up receiving, once per app run: channels, the local-notification
  /// plugin, the foreground / tap listeners, the permission request, and the
  /// device token on the signed-in user.
  Future<void> initInfo() async {
    if (_initStarted) return;
    _initStarted = true;
    // Each step is guarded on its own, so one failure cannot leave the app
    // without listeners or without a saved token.
    // Channels first: a push can only ring on a channel that exists.
    await _guard('channels', createChannels);
    await _guard('local notifications', _initLocalNotifications);
    if (Platform.isIOS) {
      // iOS shows a `notification` message in the foreground only with
      // these options; Android needs the local notification in [display].
      await _guard('presentation options', () => FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true));
      // A new-order push presented while the in-app alert rings loses only
      // its sound (AppDelegate asks; no double sound).
      await _guard('foreground order sound', () async => OrderRingtoneService.handleForegroundPresentation(_silentOnIos));
    }
    // Listeners no longer depend on the permission answer: a denied (or not
    // yet answered) request used to leave the app with no foreground and no
    // tap handling at all for that run.
    await _guard('listeners', () async => _listen());
    await _guard('launch notification', _openLaunchNotification);
    // Not awaited: the token does not depend on the answer, and saving it
    // must not wait for the user to dismiss the system dialog.
    unawaited(requestPermissionOnce());
    await _guard('token refresh', () async => listenTokenRefresh());
    await _guard('token', syncToken);
  }

  static Future<void> _guard(String step, Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      log("notification setup ($step) failed: $e");
    }
  }

  /// Creates (or re-asserts) the Android channels. Idempotent; called from
  /// `main()` before the first frame and again here and in the background
  /// handler.
  static Future<void> createChannels() async {
    if (!Platform.isAndroid) return;
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    try {
      await android.createNotificationChannel(_orderChannel);
      await android.createNotificationChannel(_generalChannel);
      await android.createNotificationChannel(_chatChannel);
    } catch (e) {
      log("notification channel setup failed: $e");
    }
  }

  static Future<void> _initLocalNotifications() async {
    if (_localReady) return;
    const AndroidInitializationSettings android = AndroidInitializationSettings('@drawable/ic_stat_notification');
    // No permission prompt from this plugin: [requestPermissionOnce] asks once.
    const DarwinInitializationSettings ios = DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse response) => _openFromPayload(response.payload, coldStart: false),
    );
    _localReady = true;
  }

  /// Asks for notification permission (alert, badge, sound) once per run,
  /// after the first frame. On Android 13+ this is the POST_NOTIFICATIONS
  /// prompt; it used to be asked twice (plugin and FCM).
  static Future<void> requestPermissionOnce() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    try {
      await WidgetsBinding.instance.endOfFrame;
      final NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      log("notification permission: ${settings.authorizationStatus}");
    } catch (e) {
      log("notification permission request failed: $e");
    }
  }

  void _listen() {
    _onMessageSub ??= FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    _onMessageOpenedSub ??= FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) => _openFromData(message.data, coldStart: false));
  }

  /// A notification tapped while the app was closed (FCM or local).
  Future<void> _openLaunchNotification() async {
    try {
      final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        unawaited(_openFromData(initialMessage.data, coldStart: true));
        return;
      }
      final NotificationAppLaunchDetails? details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp == true) {
        _openFromPayload(details?.notificationResponse?.payload, coldStart: true);
      }
    } catch (e) {
      log("launch notification check failed: $e");
    }
  }

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    log("::::::::::::onMessage::::::::::::::::: ${message.messageId}");
    // A scheduled order is due (`scheduledOrderNotifier` Cloud Function):
    // move it to New now. It is shown below like any new-order push.
    final String? dueOrderId = ScheduledOrderDuePush.orderIdOf(message.data);
    if (dueOrderId != null) HomeController.onScheduledOrderPush(dueOrderId, serverDue: ScheduledOrderDuePush.isServerDue(message.data));
    final bool hasNotification = message.notification != null;
    if (!hasNotification && !hasDisplayableData(message.data)) return;
    // iOS already presents a `notification` message in the foreground
    // (setForegroundNotificationPresentationOptions); a local notification
    // as well showed it twice.
    if (Platform.isIOS && hasNotification) return;
    await display(message, foreground: true);
  }

  /// iOS, a push presented in the foreground: true to present it without its
  /// sound because the in-app alert is ringing the same order sound.
  static Future<bool> _silentOnIos(Map<String, dynamic> data, String apsSound) async {
    final String channelId = (data['channelId'] ?? data['android_channel_id'] ?? '').toString();
    final bool orderAlert = PushPayload.isStoreOrderAlert(type: data['type']?.toString(), channelId: channelId) || ForegroundOrderSound.isOrderSound(apsSound);
    return _foregroundSilent(orderAlert: orderAlert, type: data['type']?.toString());
  }

  /// A new-order alert in the foreground is silent while the in-app alert
  /// rings; when the orders screen is up it may start a moment after the
  /// push, so this waits up to 1.5 s for it.
  static Future<bool> _foregroundSilent({required bool orderAlert, String? type}) async {
    if (!orderAlert) return false;
    bool ringing = AudioPlayerService.isRinging;
    if (!ringing && ForegroundOrderSound.inAppRingExpected(orderAlert: orderAlert, type: type, ordersScreenAlive: Get.isRegistered<HomeController>())) {
      ringing = await AudioPlayerService.waitForRing(const Duration(milliseconds: 1500));
    }
    return ForegroundOrderSound.silent(orderAlert: orderAlert, foreground: true, inAppRinging: ringing);
  }

  // ── Token ──

  /// This device's FCM token, or `''`.
  ///
  /// iOS: `getToken()` throws `apns-token-not-set` until the APNs token has
  /// arrived, and the old code saved that failure as an empty token - so
  /// iPhones never received anything. It now waits for the APNs token (up to
  /// ~10 s); if it is still missing, the FCM token is saved later by
  /// [listenTokenRefresh].
  static Future<String> getToken() async {
    try {
      if (Platform.isIOS && await _waitForApnsToken() == null) {
        log("APNs token not available yet; the FCM token is saved when it arrives");
        return '';
      }
      // A token restored from an Android backup is dead: replace it once.
      await FcmTokenReset.runOnce();
      final String token = (await FirebaseMessaging.instance.getToken())?.trim() ?? '';
      if (PushPayload.isUsableToken(token)) _deviceToken = token;
      return token;
    } catch (e) {
      log("getToken failed: $e");
      return '';
    }
  }

  static Future<String?> _waitForApnsToken() async {
    for (int attempt = 0; attempt < 20; attempt++) {
      try {
        final String? apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns != null && apns.isNotEmpty) return apns;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  /// Saves this device's token on the signed-in user (`fcmToken` only, and
  /// on the stores an owner owns). Called on every start, after login,
  /// sign-up and OTP. Never writes an empty token.
  static Future<void> syncToken() async {
    final String token = await getToken();
    if (!PushPayload.isUsableToken(token)) return;
    await _subscribeTopic();
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    await FireStoreUtils.saveDeviceFcmToken(uid, token);
  }

  /// One `onTokenRefresh` subscription per run. customer and store had none,
  /// so a rotated token was never saved and pushes went to the old one.
  static void listenTokenRefresh() {
    _tokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen(
      (String token) async {
        if (!PushPayload.isUsableToken(token)) return;
        _deviceToken = token.trim();
        await _subscribeTopic();
        final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        if (uid.isNotEmpty) await FireStoreUtils.saveDeviceFcmToken(uid, _deviceToken);
      },
      onError: (Object e) => log("onTokenRefresh failed: $e"),
    );
  }

  /// Before sign-out: clears the stored token only where it is still this
  /// device's, so the account's other phone keeps receiving.
  static Future<void> clearTokenOnSignOut() async {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    String token = _deviceToken;
    if (!PushPayload.isUsableToken(token)) {
      try {
        token = (await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 3)))?.trim() ?? '';
      } catch (_) {
        token = '';
      }
    }
    // Bounded: sign-out must not hang on a slow or missing connection.
    await FireStoreUtils.clearDeviceFcmToken(uid, token).timeout(const Duration(seconds: 8), onTimeout: () => log("clearing the FCM token timed out"));
  }

  /// Admin broadcasts to the store app. Needs the APNs token on iOS, so it
  /// runs once a token exists.
  static Future<void> _subscribeTopic() async {
    if (_topicSubscribed) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic("vendor");
      _topicSubscribed = true;
    } catch (e) {
      log("subscribeToTopic vendor failed: $e");
    }
  }

  // ── Taps ──

  static void _openFromPayload(String? payload, {required bool coldStart}) {
    Map<String, dynamic> data = const {};
    try {
      final dynamic decoded = jsonDecode(payload ?? '');
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    unawaited(_openFromData(data, coldStart: coldStart));
  }

  /// Where a tapped notification takes the store user. Missing or unexpected
  /// data does nothing; it never throws (the old handler read the uid with
  /// `currentUser!` and crashed on a tap while signed out).
  static Future<void> _openFromData(Map<String, dynamic> data, {required bool coldStart}) async {
    try {
      final NotificationTarget target = NotificationRouting.targetFor(type: data['type']?.toString(), chatType: data['chatType']?.toString());
      if (target == NotificationTarget.none) return;
      if (FirebaseAuth.instance.currentUser == null) return;
      // A tapped "scheduled order is due" push: the order is New now.
      final String? dueOrderId = ScheduledOrderDuePush.orderIdOf(data);
      if (dueOrderId != null) HomeController.onScheduledOrderPush(dueOrderId, serverDue: ScheduledOrderDuePush.isServerDue(data));
      if (target == NotificationTarget.adminChat) {
        await Preferences.setBoolean(Preferences.isClickOnNotification, true);
      }
      // After a cold start the splash screen opens the dashboard a few
      // seconds later; the screen is opened from there.
      if (!await _dashboardReady(wait: coldStart)) return;
      switch (target) {
        case NotificationTarget.adminChat:
          Get.offAll(HelpSupportScreen(isNavigateViaNotification: true));
          break;
        case NotificationTarget.orderChat:
          Get.to(const RestaurantInboxScreen());
          break;
        case NotificationTarget.orders:
          Get.until((route) => route.isFirst);
          Get.find<DashBoardController>().openTab(DashBoardController.homeTab);
          // Due scheduled order: its New tab (the home may be on another one).
          if (dueOrderId != null) HomeController.requestNewTab();
          break;
        case NotificationTarget.dineIn:
          Get.until((route) => route.isFirst);
          Get.find<DashBoardController>().openTab(DashBoardController.dineInTab);
          break;
        case NotificationTarget.none:
          break;
      }
    } catch (e) {
      log("notification tap handling failed: $e");
    }
  }

  static Future<bool> _dashboardReady({required bool wait}) async {
    if (Get.isRegistered<DashBoardController>()) return true;
    if (!wait) return false;
    for (int i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (Get.isRegistered<DashBoardController>()) return true;
    }
    return false;
  }

  // ── Display ──

  /// True for the pushes that must be loud: a new order or booking.
  static bool isOrderAlert(RemoteMessage message) {
    final String channelId = (message.notification?.android?.channelId ?? message.data['channelId'] ?? message.data['android_channel_id'] ?? '').toString();
    return PushPayload.isStoreOrderAlert(type: message.data['type']?.toString(), channelId: channelId);
  }

  /// A chat message (chat channel, or a chat `type`).
  static bool isChat(RemoteMessage message) {
    final String channelId = (message.notification?.android?.channelId ?? message.data['channelId'] ?? message.data['android_channel_id'] ?? '').toString();
    return ChatSound.isChatPush(type: message.data['type']?.toString(), channelId: channelId);
  }

  /// A data-only message that has something to show.
  static bool hasDisplayableData(Map<String, dynamic> data) => (data['title'] ?? '').toString().trim().isNotEmpty || (data['body'] ?? '').toString().trim().isNotEmpty;

  /// Shows [message] as a local notification: on Android for every message
  /// received in the foreground (FCM does not display there), and on both
  /// platforms for a data-only message that carries a title or body.
  ///
  /// Order alerts go on the loud order channel with the alert tone and max
  /// importance - the admin's order sound (`new_order_rt_<key>`, iOS
  /// `order_ringtone_<key>.caf`) once this device has prepared it, else
  /// `new_order` / `order_alert` - and everything else on the general
  /// channel. [foreground]: received with the app open; an order alert is
  /// then posted silently while the in-app alert rings ([_foregroundSilent]).
  static Future<void> display(RemoteMessage message, {bool foreground = false}) async {
    try {
      if (!_localReady) {
        // Background isolate: the plugin and channels of the main isolate are
        // not there.
        await createChannels();
        await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_stat_notification'), iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false)));
        _localReady = true;
      }
      final bool chat = isChat(message);
      final bool orderAlert = !chat && isOrderAlert(message);
      final PreparedOrderRingtone? ringtone = orderAlert ? await OrderRingtoneService.current() : null;
      final AndroidNotificationChannel channel = chat ? _chatChannel : (!orderAlert ? _generalChannel : (ringtone != null && Platform.isAndroid ? OrderRingtoneService.channelFor(ringtone) : _orderChannel));
      final bool silent = foreground && await _foregroundSilent(orderAlert: orderAlert, type: message.data['type']?.toString());
      final String? title = message.notification?.title ?? message.data['title']?.toString();
      final String? body = message.notification?.body ?? message.data['body']?.toString();
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: orderAlert ? Priority.max : Priority.high,
        playSound: true,
        sound: channel.sound,
        enableVibration: true,
        // The channel's sound is not played for this one notification.
        silent: silent,
        category: orderAlert ? AndroidNotificationCategory.alarm : null,
        ticker: 'ticker',
      );
      final DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: !silent,
        sound: chat ? ChatSound.apnsSound : (orderAlert ? (ringtone?.iosSound ?? PushPayload.storeOrderApnsSound) : null),
      );
      await _plugin.show(
        // A distinct id per message: a fixed id made every new order replace
        // the previous one in the shade.
        id: (message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString()).hashCode & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: androidDetails, iOS: darwinDetails),
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      log("display notification failed: $e");
    }
  }
}

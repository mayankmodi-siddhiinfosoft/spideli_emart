import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:customer/service/chat_sound.dart';
import 'package:customer/firebase_options.dart';
import 'package:customer/models/customer_notification_model.dart';
import 'package:customer/screen_ui/help_support_screen/help_support_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/driver_inbox_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/restaurant_inbox_screen.dart';
import 'package:customer/screen_ui/on_demand_service/provider_inbox_screen.dart';
import 'package:customer/screen_ui/on_demand_service/worker_inbox_screen.dart';
import 'package:customer/service/customer_notification_service.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/service/push_message.dart';
import 'package:customer/utils/customer_notification_record.dart';
import 'package:customer/utils/delivery_code_push.dart';
import 'package:customer/utils/on_demand_booking_opener.dart';
import 'package:customer/utils/on_demand_push.dart';
import 'package:customer/utils/order_notification_opener.dart';
import 'package:customer/utils/push_tap.dart';
import 'package:customer/utils/push_token.dart';
import 'package:customer/utils/push_token_sync.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

/// Runs for a push that arrives while the app is in the background or closed.
///
/// Registered once, from `main()` (it used to be registered only when the app
/// had been opened from a notification, and as a closure, which the plugin
/// cannot call from its background isolate). A notification message is shown
/// by the system on its own; this starts Firebase for the isolate and records
/// the push in the Notification Center when its sender did not
/// (`.claude/CUSTOMER-NOTIFICATIONS.md` §1, fallback).
@pragma('vm:entry-point')
Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FireStoreUtils.ensureInitialized();
  } catch (e) {
    log('push: background Firebase init failed (${e.runtimeType})');
    return;
  }
  log('push: background message ${PushTap.field(message.data, 'type')}');
  // The signed-in user is restored asynchronously in a fresh isolate.
  await CustomerNotificationService.recordPush(message, waitForAuth: true);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  FlutterLocalNotificationsPlugin get flutterLocalNotificationsPlugin => _plugin;

  /// The customer app's channel. Also the manifest's
  /// `default_notification_channel_id`, so background pushes land on it, and
  /// what the other apps put in `android.notification.channel_id`
  /// (`.claude/PUSH-CHANNELS.md`). The manifest used to name this channel
  /// while the app only ever created '0', and only when it showed a
  /// foreground delivery-code push: every background push went to Android's
  /// silent fallback channel. An existing channel's importance and sound
  /// cannot be changed, so the id must change if they ever have to.
  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    PushChannels.customer,
    'Spideli notifications',
    description: 'Order, ride, parcel and booking updates, delivery codes and chat messages',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Chat messages: their own short sound (`res/raw/chat_message.wav`).
  static const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
    ChatSound.channelId,
    ChatSound.channelName,
    description: ChatSound.channelDescription,
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound(ChatSound.androidSound),
    enableVibration: true,
  );

  static bool _initialized = false;
  static StreamSubscription<RemoteMessage>? _onMessageSubscription;
  static StreamSubscription<RemoteMessage>? _onOpenedSubscription;

  /// A tap that launched the app, held until the customer reaches the home.
  static Map<String, dynamic>? _pendingTap;
  static bool _appReady = false;

  static bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Creates the Android channel. Called from `main()` before `runApp`, so it
  /// exists before any push can arrive; repeated calls are harmless.
  static Future<void> createChannels() async {
    if (!_isAndroid) return;
    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(channel);
      await android?.createNotificationChannel(chatChannel);
    } catch (e) {
      log('push: createNotificationChannel failed (${e.runtimeType})');
    }
  }

  /// Sets up receiving. Call once, after the first frame (it shows the
  /// permission dialog). Never throws.
  Future<void> initInfo() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await createChannels();
      // iOS shows a push that arrives while the app is open only with these.
      // No local copy is posted on iOS, so it is never shown twice.
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    } catch (e) {
      log('push: presentation options failed (${e.runtimeType})');
    }
    await _initLocalNotifications();
    _listen();
    unawaited(_handleLaunchTap());
    await _requestPermission();
    unawaited(_subscribeToTopic());
  }

  static Future<void> _initLocalNotifications() async {
    try {
      const InitializationSettings settings = InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_notification'),
        // The permission is asked once, by FirebaseMessaging.requestPermission.
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          unawaited(routeTap(PushTap.decodePayload(response.payload)));
        },
      );
    } catch (e) {
      log('push: local notifications init failed (${e.runtimeType})');
    }
  }

  /// One subscription each, whatever the permission answer (the listeners
  /// used to be set up only when the permission was granted, and the app
  /// threw before reaching them when opened from a notification).
  static void _listen() {
    _onMessageSubscription ??= FirebaseMessaging.onMessage.listen(_onForegroundMessage, onError: (Object e) => log('push: onMessage error (${e.runtimeType})'));
    _onOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) {
        unawaited(CustomerNotificationService.recordPush(message));
        unawaited(routeTap(message.data));
      },
      onError: (Object e) => log('push: onMessageOpenedApp error (${e.runtimeType})'),
    );
  }

  /// Android does not display a notification message while the app is in the
  /// foreground, so it is posted locally (this used to happen for delivery
  /// codes only: order, ride and chat pushes were silently dropped). iOS
  /// already presents it (presentation options above).
  static void _onForegroundMessage(RemoteMessage message) {
    // Every platform: the Notification Center keeps it (when the sender did not).
    unawaited(CustomerNotificationService.recordPush(message));
    if (!_isAndroid) return;
    unawaited(display(message));
  }

  static Future<void> _handleLaunchTap() async {
    try {
      final RemoteMessage? initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        unawaited(CustomerNotificationService.recordPush(initial));
        await routeTap(initial.data, coldStart: true);
        return;
      }
      // A foreground notification posted by this app (Android) that was
      // tapped after the app had been closed.
      final NotificationAppLaunchDetails? details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp == true) {
        await routeTap(PushTap.decodePayload(details!.notificationResponse?.payload), coldStart: true);
      }
    } catch (e) {
      log('push: launch notification failed (${e.runtimeType})');
    }
  }

  static Future<void> _requestPermission() async {
    try {
      final NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      log('push: permission ${settings.authorizationStatus.name}');
    } catch (e) {
      log('push: permission request failed (${e.runtimeType})');
    }
  }

  /// Topic `customer` (admin broadcasts). On iOS a topic call also needs the
  /// APNs token first.
  static Future<void> _subscribeToTopic() async {
    try {
      if (_isIOS && !await PushToken.waitForApns(() => FirebaseMessaging.instance.getAPNSToken())) return;
      await FirebaseMessaging.instance.subscribeToTopic('customer');
    } catch (e) {
      log('push: topic subscribe failed (${e.runtimeType})');
    }
  }

  /// This device's FCM token, '' when there is none (on iOS after waiting for
  /// the APNs token). Saving it is [PushTokenSync]'s job.
  static Future<String> getToken() async => await PushTokenSync.deviceToken() ?? '';

  /// Called by the home (ServiceListController.onReady): a tap that launched
  /// the app (chat, support, on-demand booking) is opened now, on top of the
  /// home.
  static void markAppReady() {
    _appReady = true;
    final Map<String, dynamic>? pending = _pendingTap;
    _pendingTap = null;
    if (pending != null) unawaited(routeTap(pending));
  }

  /// Opens what a tapped push is about. Never throws, whatever the payload.
  static Future<void> routeTap(Map<String, dynamic> data, {bool coldStart = false}) async {
    try {
      // Opens that order's details with the code card; the payload has no code.
      if (PushTap.field(data, 'type') == DeliveryCodePush.type) {
        await DeliveryCodePush.handleTap(data, coldStart: coldStart);
        return;
      }
      if (FirebaseAuth.instance.currentUser == null) return;
      final PushTapTarget? target = PushTap.targetOf(data);
      if (target == null) return;
      if (coldStart && !_appReady) {
        _pendingTap = data;
        return;
      }
      // Pushed on top of whatever is open. This used to reset the stack to the
      // multi-vendor dashboard, whose controller reads the selected service
      // (`Constant.sectionConstantModel!`) and threw when there was none -
      // a cold start, or the service list.
      switch (target) {
        case PushTapTarget.supportChat:
          await Get.to(() => HelpSupportScreen());
        case PushTapTarget.storeInbox:
          await Get.to(() => const RestaurantInboxScreen());
        case PushTapTarget.driverInbox:
          await Get.to(() => const DriverInboxScreen());
        case PushTapTarget.providerInbox:
          await Get.to(() => const ProviderInboxScreen());
        case PushTapTarget.workerInbox:
          await Get.to(() => const WorkerInboxScreen());
        case PushTapTarget.onDemandBooking:
        case PushTapTarget.onDemandBookings:
          // The booking's details, or the bookings list without a usable id.
          await OnDemandBookingOpener.open(OnDemandPush.orderIdOf(data));
      }
    } catch (e) {
      log('push: tap routing failed (${e.runtimeType})');
    }
  }

  /// A tap on a Notification Center row (already marked read): routed like
  /// the push it was ([routeTap]); an order / ride / parcel / rental /
  /// booking update, which a push tap only opens the app for, opens that
  /// order's or booking's details.
  /// Anything else leaves the customer on the list. Never throws.
  static Future<void> openNotification(CustomerNotificationModel notification) async {
    try {
      final Map<String, dynamic> data = notification.routeData;
      if (PushTap.field(data, 'type') == DeliveryCodePush.type || PushTap.targetOf(data) != null) {
        await routeTap(data);
        return;
      }
      final String orderId = notification.orderId.isNotEmpty ? notification.orderId : CustomerNotificationRecord.orderIdOf(data);
      final String category = CustomerNotificationRecord.normalizeCategory(notification.category);
      // A booking the push router has no target for (a table booking, an
      // on-demand event it does not know) opens its details too.
      if (orderId.isNotEmpty && (category == CustomerNotificationRecord.categoryOrder || category == CustomerNotificationRecord.categoryBooking)) {
        await OrderNotificationOpener.open(orderId);
      }
    } catch (e) {
      log('push: notification center tap failed (${e.runtimeType})');
    }
  }

  /// Posts [message] on [channel] (Android, app in the foreground).
  static Future<void> display(RemoteMessage message) async {
    try {
      final text = PushTap.displayText(
        title: message.notification?.title,
        body: message.notification?.body,
        data: message.data,
      );
      if (text == null) return;
      // A chat message on the chat channel with its own sound.
      final bool chat = ChatSound.isChatPush(type: message.data['type']?.toString(), channelId: message.notification?.android?.channelId ?? message.data['channelId']?.toString());
      final AndroidNotificationChannel target = chat ? chatChannel : channel;
      final AndroidNotificationDetails android = AndroidNotificationDetails(
        target.id,
        target.name,
        channelDescription: target.description,
        importance: target.importance,
        priority: Priority.high,
        playSound: true,
        sound: target.sound,
        enableVibration: true,
        ticker: 'ticker',
      );
      final DarwinNotificationDetails darwin = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true, sound: chat ? ChatSound.apnsSound : null);
      await _plugin.show(
        id: PushTap.notificationId(message.messageId),
        title: text.title,
        body: text.body,
        notificationDetails: NotificationDetails(android: android, iOS: darwin),
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      log('push: foreground display failed (${e.runtimeType})');
    }
  }
}

import 'dart:convert';

import 'package:vendor/utils/chat_sound.dart';
import 'package:vendor/utils/order_ringtone.dart';

/// Pure pieces of the store's push sending and receiving: no Firebase, no
/// Flutter, so every rule here is unit tested (test/push_payload_test.dart).
///
/// Why each rule exists is written next to it; the cross-app channel table is
/// in `.claude/PUSH-CHANNELS.md`.

/// The app a push from the store is going to. Each app creates its own Android
/// notification channels, so the channel id in a push has to be one the
/// RECEIVING app created (or Android posts it on a silent fallback channel).
/// The store only ever sends to customers and drivers; [store] is here for the
/// store's own channel table (orders the customer app sends to the store).
enum PushRecipient { customer, store, driver }

/// Channel and sound for one push, on both platforms.
class PushChannel {
  /// `android.notification.channel_id`: a channel the receiving app creates.
  final String androidChannelId;

  /// `android.notification.sound`: `default` or a `res/raw` name (no extension)
  /// in the receiving app.
  final String androidSound;

  /// `apns.payload.aps.sound`: `default` or a file in the receiving app's
  /// bundle. iOS plays the default tone when the named file is missing.
  final String apnsSound;

  const PushChannel({required this.androidChannelId, required this.androidSound, required this.apnsSound});

  @override
  bool operator ==(Object other) => other is PushChannel && other.androidChannelId == androidChannelId && other.androidSound == androidSound && other.apnsSound == apnsSound;

  @override
  int get hashCode => Object.hash(androidChannelId, androidSound, apnsSound);

  @override
  String toString() => 'PushChannel($androidChannelId, $androidSound, $apnsSound)';
}

class PushPayload {
  PushPayload._();

  // ── Channel ids each receiving app creates (read from its code/manifest) ──

  /// Store: loud new-order channel (`NotificationService._orderChannel`, the
  /// store manifest's `default_notification_channel_id`).
  static const String storeOrderChannelId = 'new_order';

  /// Store: everything that is not a new order (`NotificationService._generalChannel`).
  static const String storeGeneralChannelId = 'general';

  /// Store: `android/app/src/main/res/raw/order_alert.wav`.
  static const String storeOrderAndroidSound = 'order_alert';

  /// Store: `ios/Runner/order_alert.caf` (bundled in the Runner target).
  static const String storeOrderApnsSound = 'order_alert.caf';

  /// Customer: the customer manifest's `default_notification_channel_id`.
  /// Android also falls back to the manifest default when a push names a
  /// channel the device does not have, so the manifest default is the safest
  /// id to name.
  static const String customerChannelId = 'high_importance_channel';

  /// Driver: everything that is not a new job (chat, cancellations). Also the
  /// driver manifest's `default_notification_channel_id`
  /// (`driver/lib/services/push_message.dart` `PushChannels`).
  static const String driverChannelId = 'driver_notifications_channel';

  /// Driver: loud channel for a new or assigned job. An older driver build
  /// without it falls back to the manifest default, [driverChannelId].
  static const String driverJobChannelId = 'driver_jobs';

  /// Kinds that are a new or assigned job for the driver (the driver app's
  /// job set, see `.claude/PUSH-CHANNELS.md`).
  static const Set<String> driverJobKinds = {'new_delivery_order', 'assign_order', 'driver_job', 'order_available', 'job_assigned', 'job_queue', 'new_ride', 'new_parcel', 'new_rental'};

  static const String defaultSound = 'default';

  /// Every app's chat channel (`chat_messages`) and bundled chat sound.
  static const PushChannel chatChannel = PushChannel(androidChannelId: ChatSound.channelId, androidSound: ChatSound.androidSound, apnsSound: ChatSound.apnsSound);

  /// Template types that are a new order or booking for the store (they ring
  /// on the loud channel). Matches the server's `order_alert` profile plus the
  /// store-side booking types the customer app sends, and the
  /// `scheduledOrderNotifier` Cloud Function's `scheduled_order_due`.
  static const Set<String> storeOrderAlertTypes = {'order_placed', 'new_order', 'schedule_order', 'scheduled_order_due', 'dinein_placed', 'new_order_placed'};

  /// Channel and sound for a push of [kind] to [recipient].
  ///
  /// [orderRingtoneUrl] is `globalSettings.order_ringtone_url`. When it is
  /// set, a NEW job for a driver goes on `driver_jobs_rt_<key>` and a new
  /// order for a store on `new_order_rt_<key>`, both with the iOS sound
  /// `order_ringtone_<key>.caf` (the receiving app prepares that channel and
  /// file from the same URL, [OrderRingtone]). A device that has not prepared
  /// them yet shows the push on its manifest default channel (store:
  /// `new_order`, driver: `driver_notifications_channel`) and iOS plays the
  /// default tone. The Android `sound` field (Android 7 and older only) keeps
  /// today's value. Without a ringtone: exactly today's channels and sounds.
  static PushChannel channelFor(PushRecipient recipient, String? kind, {String? orderRingtoneUrl}) {
    // A chat message, to any app: the dedicated chat channel and sound,
    // never an order channel or the order ringtone.
    if (ChatSound.isChatPush(type: kind)) return chatChannel;
    switch (recipient) {
      case PushRecipient.customer:
        return const PushChannel(androidChannelId: customerChannelId, androidSound: defaultSound, apnsSound: defaultSound);
      case PushRecipient.driver:
        if (driverJobKinds.contains((kind ?? '').trim().toLowerCase())) {
          if (OrderRingtone.isConfigured(orderRingtoneUrl)) {
            return PushChannel(androidChannelId: OrderRingtone.driverJobChannelIdFor(orderRingtoneUrl)!, androidSound: defaultSound, apnsSound: OrderRingtone.iosSoundFor(orderRingtoneUrl)!);
          }
          return const PushChannel(androidChannelId: driverJobChannelId, androidSound: defaultSound, apnsSound: defaultSound);
        }
        return const PushChannel(androidChannelId: driverChannelId, androidSound: defaultSound, apnsSound: defaultSound);
      case PushRecipient.store:
        if (isStoreOrderAlert(type: kind)) {
          if (OrderRingtone.isConfigured(orderRingtoneUrl)) {
            return PushChannel(androidChannelId: OrderRingtone.storeChannelIdFor(orderRingtoneUrl)!, androidSound: storeOrderAndroidSound, apnsSound: OrderRingtone.iosSoundFor(orderRingtoneUrl)!);
          }
          return const PushChannel(androidChannelId: storeOrderChannelId, androidSound: storeOrderAndroidSound, apnsSound: storeOrderApnsSound);
        }
        return const PushChannel(androidChannelId: storeGeneralChannelId, androidSound: defaultSound, apnsSound: defaultSound);
    }
  }

  /// Which app a user record belongs to, from its `role`. Anything that is not
  /// a driver or a store account is treated as a customer.
  static PushRecipient recipientForRole(String? role) {
    switch ((role ?? '').trim().toLowerCase()) {
      case 'driver':
        return PushRecipient.driver;
      case 'vendor':
      case 'employee':
        return PushRecipient.store;
      default:
        return PushRecipient.customer;
    }
  }

  /// True when a message received by the store is a new order / booking and
  /// must ring on [storeOrderChannelId] (or its ringtone version
  /// `new_order_rt_<key>`, [OrderRingtone]).
  static bool isStoreOrderAlert({String? type, String? channelId}) {
    // A chat message never rings as an order.
    if (ChatSound.isChatPush(type: type, channelId: channelId)) return false;
    final String channel = (channelId ?? '').trim();
    if (channel == storeOrderChannelId || OrderRingtone.isStoreRingtoneChannel(channel)) return true;
    final String t = (type ?? '').trim().toLowerCase();
    if (t.isEmpty) return false;
    return storeOrderAlertTypes.contains(t) || t.contains('order_placed') || t.contains('new_order');
  }

  // ── Tokens ──

  /// A token that can be sent to. Senders used to send to `''` and to the
  /// string `'null'` (from `fcmToken.toString()` on a null field); FCM rejects
  /// both with 400.
  static bool isUsableToken(String? token) {
    final String t = (token ?? '').trim();
    return t.isNotEmpty && t != 'null';
  }

  // ── Project path ──

  /// The FCM v1 project path segment. The settings document holds the project
  /// NUMBER in `senderId`; the real project id from the Firebase options is
  /// preferred, the settings value is only a fallback.
  static String fcmProjectId({String? firebaseProjectId, String? settingsSenderId}) {
    final String id = (firebaseProjectId ?? '').trim();
    if (id.isNotEmpty) return id;
    return (settingsSenderId ?? '').trim();
  }

  static Uri fcmSendUri(String projectId) => Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

  // ── Data payload ──

  /// Keys FCM refuses in `data` (the whole message is rejected with 400).
  static bool isReservedDataKey(String key) {
    final String k = key.toLowerCase();
    return k == 'from' || k == 'notification' || k == 'message_type' || k == 'collapse_key' || k.startsWith('google') || k.startsWith('gcm');
  }

  /// FCM v1 `data`: string values only. FCM rejects the WHOLE message when a
  /// value is a number, a bool, null, a map or a list. Nulls are dropped,
  /// maps and lists are JSON encoded, anything else uses `toString()`.
  /// [type] is added when the caller did not set one: every receiver routes a
  /// tap on `data.type`.
  static Map<String, String> stringData(Map<String, dynamic>? payload, {String? type}) {
    final Map<String, String> out = {};
    payload?.forEach((key, value) {
      if (value == null || key.isEmpty || isReservedDataKey(key)) return;
      if (value is String) {
        out[key] = value;
      } else if (value is Map || value is List) {
        out[key] = jsonEncode(value, toEncodable: (Object? o) => o.toString());
      } else {
        out[key] = value.toString();
      }
    });
    final String t = (type ?? '').trim();
    if ((out['type'] ?? '').trim().isEmpty && t.isNotEmpty) out['type'] = t;
    return out;
  }

  /// Notification text limits (the server function's limits; a notification
  /// preview never needs more, and FCM refuses a message over 4 KB).
  static const int maxTitleLength = 200;
  static const int maxBodyLength = 1000;

  static String clip(String? text, int max) {
    final String t = text ?? '';
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }

  /// Body of a legacy FCM v1 `messages:send` call. The `android` and `apns`
  /// blocks are what make the push show and sound with the app in the
  /// background or closed: high priority, a channel the receiver created, and
  /// a sound on both platforms.
  static Map<String, dynamic> legacyMessage({required String token, required String title, required String body, required Map<String, String> data, required PushChannel channel}) {
    return {
      'message': {
        'token': token.trim(),
        'notification': {'title': clip(title, maxTitleLength), 'body': clip(body, maxBodyLength)},
        if (data.isNotEmpty) 'data': data,
        'android': {
          'priority': 'high',
          'notification': {'channel_id': channel.androidChannelId, 'sound': channel.androidSound},
        },
        'apns': {
          'headers': {'apns-priority': '10'},
          'payload': {
            'aps': {'sound': channel.apnsSound, 'content-available': 1},
          },
        },
      },
    };
  }

  /// Body of a call to the `sendPush` function (`.claude/SERVER-PUSH-CONTRACT.md`):
  /// same text, data, kind and channel as the legacy message.
  static Map<String, dynamic> serverBody({required String token, required String title, required String body, required Map<String, String> data, String? kind, required PushChannel channel}) {
    return {
      'token': token.trim(),
      'title': clip(title, maxTitleLength),
      'body': clip(body, maxBodyLength),
      'data': data,
      if ((kind ?? '').trim().isNotEmpty) 'kind': kind!.trim(),
      'android': {'channelId': channel.androidChannelId, 'sound': channel.androidSound},
      'apns': {'sound': channel.apnsSound},
    };
  }

  /// `settings/notification_setting.serverPushUrl` switches sending to the
  /// server function when it is a non-empty https URL.
  static bool isServerPushUrl(String? url) {
    final Uri? u = Uri.tryParse((url ?? '').trim());
    return u != null && u.scheme == 'https' && u.host.isNotEmpty;
  }

  // ── Responses ──

  static bool isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  /// The error code of a failed send, for logs and for [isDeadToken]: the FCM
  /// `FcmError.errorCode` (e.g. `UNREGISTERED`), else the Google status
  /// (e.g. `INVALID_ARGUMENT`), else the server function's `error`. Never
  /// includes the token.
  static String errorCode(String body) {
    try {
      final dynamic json = jsonDecode(body);
      if (json is! Map) return '';
      final dynamic error = json['error'];
      if (error is String) return error;
      if (error is Map) {
        final dynamic details = error['details'];
        if (details is List) {
          for (final dynamic d in details) {
            if (d is Map && d['errorCode'] is String && (d['errorCode'] as String).isNotEmpty) return d['errorCode'] as String;
          }
        }
        if (error['status'] is String) return error['status'] as String;
      }
    } catch (_) {}
    return '';
  }

  /// FCM's message for a failed send (never contains the token).
  static String errorMessage(String body) {
    try {
      final dynamic json = jsonDecode(body);
      if (json is! Map) return '';
      final dynamic error = json['error'];
      if (error is Map && error['message'] is String) return error['message'] as String;
      if (json['message'] is String) return json['message'] as String;
    } catch (_) {}
    return '';
  }

  /// True when the send failed because the recipient's token is dead, so the
  /// stored token can be cleared. `INVALID_ARGUMENT` alone also covers a bad
  /// payload, so it only counts when FCM says the token is the problem.
  static bool isDeadToken(int statusCode, String body) {
    final String code = errorCode(body);
    if (code == 'UNREGISTERED' || code == 'unregistered' || code == 'invalid_token') return true;
    if (code == 'INVALID_ARGUMENT') {
      final String message = errorMessage(body).toLowerCase();
      return message.contains('registration token') || message.contains('message.token');
    }
    return false;
  }
}

/// Decisions about the device's FCM token on `users/{uid}.fcmToken` (and the
/// owner's `vendors/{id}.fcmToken`).
class PushTokenPolicy {
  PushTokenPolicy._();

  /// Write [newToken] only when it is a real token and differs from what is
  /// stored. An empty token (iOS before the APNs token arrives, or a failed
  /// `getToken`) used to be written over a good one, and that phone then
  /// received nothing until the next successful start.
  static bool shouldSave({required String? newToken, required String? storedToken}) {
    if (!PushPayload.isUsableToken(newToken)) return false;
    return newToken!.trim() != (storedToken ?? '').trim();
  }

  /// On sign-out, clear the stored token only when it is still this device's:
  /// if the account has since signed in on another phone, that phone's token
  /// must stay.
  static bool shouldClearOnSignOut({required String? storedToken, required String? deviceToken}) {
    if (!PushPayload.isUsableToken(deviceToken)) return false;
    return (storedToken ?? '').trim() == deviceToken!.trim();
  }

  /// After FCM reported [badToken] dead, clear the stored token only when it
  /// still equals [badToken] (the recipient may have refreshed it meanwhile).
  static bool shouldClearStale({required String? storedToken, required String badToken}) {
    if (!PushPayload.isUsableToken(badToken)) return false;
    return (storedToken ?? '').trim() == badToken.trim();
  }
}

/// Where a tapped notification takes the store user.
enum NotificationTarget { none, adminChat, orderChat, orders, dineIn }

class NotificationRouting {
  NotificationRouting._();

  static NotificationTarget targetFor({String? type, String? chatType}) {
    final String t = (type ?? '').trim();
    final String lower = t.toLowerCase();
    if (lower == 'admin_chat' || (chatType ?? '').trim().toLowerCase() == 'admin') return NotificationTarget.adminChat;
    if (t == 'orderChat' || lower == 'chat' || lower.endsWith('_chat')) return NotificationTarget.orderChat;
    if (lower.startsWith('dinein')) return NotificationTarget.dineIn;
    if (PushPayload.isStoreOrderAlert(type: t) || lower.startsWith('driver_') || lower.startsWith('customer_cancelled') || lower.startsWith('store_') || lower.startsWith('restaurant_')) {
      return NotificationTarget.orders;
    }
    return NotificationTarget.none;
  }
}

/// No double sound in the foreground: the store's in-app alert
/// (`AudioPlayerService`, started by the orders screen for every order in
/// New) loops the same order sound, so a new-order notification that arrives
/// while it rings is shown without a sound of its own (Android: posted
/// silent; iOS: presented without sound). Never a second notification.
class ForegroundOrderSound {
  ForegroundOrderSound._();

  /// True when the in-app alert can be expected to ring for this push, so the
  /// app waits briefly for it before deciding: an order alert other than a
  /// dine-in booking (the orders screen does not ring for those), while the
  /// orders screen is alive ([ordersScreenAlive]).
  static bool inAppRingExpected({required bool orderAlert, String? type, required bool ordersScreenAlive}) {
    if (!orderAlert || !ordersScreenAlive) return false;
    return !(type ?? '').trim().toLowerCase().startsWith('dinein');
  }

  /// Show the notification without its own sound: a new-order alert received
  /// in the foreground while the in-app alert rings.
  static bool silent({required bool orderAlert, required bool foreground, required bool inAppRinging}) => orderAlert && foreground && inAppRinging;

  /// iOS: the push's `aps.sound` is one of the store's order sounds.
  static bool isOrderSound(String? apsSound) {
    final String s = (apsSound ?? '').trim();
    return s == PushPayload.storeOrderApnsSound || OrderRingtone.isRingtoneSoundName(s);
  }
}

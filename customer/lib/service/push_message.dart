import 'dart:convert';

import 'package:customer/service/chat_sound.dart';
import 'package:customer/service/order_ringtone.dart';

/// The app a push is meant for. The Android channel and the sound always
/// belong to the RECEIVING app (see `.claude/PUSH-CHANNELS.md`).
enum PushRecipient { customer, store, driver, provider, worker }

/// Where a push is posted on the receiving device, and the sound it plays.
class PushChannelSpec {
  const PushChannelSpec({this.androidChannelId, this.androidSound = 'default', this.apnsSound = 'default'});

  /// A channel the receiving app creates. `null` leaves the choice to the
  /// receiving app's manifest `default_notification_channel_id`.
  final String? androidChannelId;

  /// `default`, or the name of a sound in the receiving app's `res/raw`
  /// (no extension). Android 8+ plays the channel's sound instead.
  final String androidSound;

  /// `default`, or a sound file in the receiving app's iOS bundle. A missing
  /// file plays the default tone.
  final String apnsSound;

  @override
  bool operator ==(Object other) =>
      other is PushChannelSpec && other.androidChannelId == androidChannelId && other.androidSound == androidSound && other.apnsSound == apnsSound;

  @override
  int get hashCode => Object.hash(androidChannelId, androidSound, apnsSound);

  @override
  String toString() => 'PushChannelSpec($androidChannelId, $androidSound, $apnsSound)';
}

/// The channel each receiving app creates (read from that app's
/// notification service and AndroidManifest; kept in `.claude/PUSH-CHANNELS.md`).
abstract final class PushChannels {
  /// The customer app's only channel (`NotificationService.channel`), also its
  /// manifest default.
  static const String customer = 'high_importance_channel';

  /// Store (vendor): loud new-order channel with `res/raw/order_alert.wav`,
  /// also the store's manifest default.
  static const String storeOrder = 'new_order';
  static const String storeOrderSound = 'order_alert';

  /// iOS file name of the store's order tone. Until it is added to the store's
  /// Runner bundle iOS plays the default tone, which is harmless.
  static const String storeOrderApnsSound = 'order_alert.caf';

  /// Store (vendor): everything that is not a new order (chat, updates).
  static const String storeGeneral = 'general';

  /// Driver: jobs, order updates and chat; also the driver's manifest default.
  static const String driver = 'driver_notifications_channel';

  /// Provider: `01` "Bookings and messages", also the provider's manifest
  /// default (`spideli_provider/lib/services/push_message.dart`).
  static const String provider = '01';

  /// Worker: `01` "Jobs and messages", also the worker's manifest default.
  static const String worker = '01';

  /// Template types that are a NEW order or booking request for the store:
  /// they use the store's loud order channel.
  static const Set<String> storeOrderKinds = {'order_placed', 'schedule_order', 'dinein_placed', 'new_order'};

  /// A new order / booking for a store (the store's loud order channel).
  static bool isStoreNewOrder(PushRecipient? recipient, String? kind) => recipient == PushRecipient.store && storeOrderKinds.contains((kind ?? '').trim().toLowerCase());

  /// [orderRingtoneUrl] is `globalSettings.order_ringtone_url`. When it is
  /// set, a new order / booking for a store goes on `new_order_rt_<key>`
  /// with the iOS sound `order_ringtone_<key>.caf` (the store app prepares
  /// both from the same URL, [OrderRingtone]); a store that has not prepared
  /// them yet shows it on its manifest default `new_order`. The Android
  /// `sound` field (Android 7 and older only) stays `order_alert`. Without a
  /// ringtone: exactly today's channel and sounds.
  /// Every app's chat channel (`chat_messages`) and bundled chat sound.
  static const PushChannelSpec chat = PushChannelSpec(androidChannelId: ChatSound.channelId, androidSound: ChatSound.androidSound, apnsSound: ChatSound.apnsSound);

  static PushChannelSpec forRecipient(PushRecipient? recipient, {String? kind, String? orderRingtoneUrl}) {
    // A chat message, to any app: the dedicated chat channel and bundled
    // chat sound, never an order channel or the order ringtone.
    if (ChatSound.isChatPush(type: kind)) return chat;
    switch (recipient) {
      case PushRecipient.customer:
        return const PushChannelSpec(androidChannelId: customer);
      case PushRecipient.store:
        if (storeOrderKinds.contains((kind ?? '').trim().toLowerCase())) {
          if (OrderRingtone.isConfigured(orderRingtoneUrl)) {
            return PushChannelSpec(androidChannelId: OrderRingtone.storeChannelIdFor(orderRingtoneUrl), androidSound: storeOrderSound, apnsSound: OrderRingtone.iosSoundFor(orderRingtoneUrl)!);
          }
          return const PushChannelSpec(androidChannelId: storeOrder, androidSound: storeOrderSound, apnsSound: storeOrderApnsSound);
        }
        return const PushChannelSpec(androidChannelId: storeGeneral);
      case PushRecipient.driver:
        return const PushChannelSpec(androidChannelId: driver);
      case PushRecipient.provider:
        return const PushChannelSpec(androidChannelId: provider);
      case PushRecipient.worker:
        return const PushChannelSpec(androidChannelId: worker);
      case null:
        return const PushChannelSpec();
    }
  }

  /// The recipient of a chat message, from the thread's `chatType` (the role
  /// of the other side: `vendor`, `driver`, `provider`, `worker`).
  static PushRecipient? recipientForChatType(String? chatType) {
    switch ((chatType ?? '').trim().toLowerCase()) {
      case 'vendor':
      case 'store':
      case 'restaurant':
        return PushRecipient.store;
      case 'driver':
        return PushRecipient.driver;
      case 'provider':
        return PushRecipient.provider;
      case 'worker':
        return PushRecipient.worker;
      case 'customer':
        return PushRecipient.customer;
      default:
        return null;
    }
  }
}

/// Builds what is sent to FCM. Pure, so it can be unit tested.
abstract final class PushPayload {
  /// Data keys FCM refuses (the whole message fails with 400).
  static const Set<String> reservedDataKeys = {'from', 'notification', 'message_type', 'collapse_key'};

  /// A registration token worth sending to: not empty, not the string 'null'
  /// (what `fcmToken.toString()` gives for a user without one).
  static bool isUsableToken(String? token) {
    final String t = token?.trim() ?? '';
    return t.isNotEmpty && t.toLowerCase() != 'null';
  }

  /// `settings/notification_setting.serverPushUrl` switches sending to the
  /// server function when it is an https URL with a host.
  static bool isServerPushUrl(String? url) {
    final Uri? uri = Uri.tryParse((url ?? '').trim());
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  /// The project in the FCM v1 path: the Firebase project id the app was
  /// built with, falling back to the settings value.
  static String projectId({String? firebaseProjectId, String? settingsSenderId}) {
    final String fromApp = firebaseProjectId?.trim() ?? '';
    if (fromApp.isNotEmpty) return fromApp;
    return settingsSenderId?.trim() ?? '';
  }

  static Uri fcmSendUri(String projectId) => Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

  /// FCM v1 takes a map of string to string and rejects the whole message
  /// when one value is anything else. Nulls are dropped, maps and lists are
  /// JSON-encoded, everything else uses `toString()`. `type` is always
  /// present ([type] fills it when the caller gave none), and the receiving
  /// channel is added as `channelId` so a receiver showing the push itself in
  /// the foreground can use the same channel.
  static Map<String, String> stringData(Map<String, dynamic>? payload, {String? type, PushChannelSpec? spec}) {
    final Map<String, String> out = {};
    payload?.forEach((key, value) {
      final String k = key.trim();
      if (k.isEmpty || value == null) return;
      final String lower = k.toLowerCase();
      if (reservedDataKeys.contains(lower) || lower.startsWith('google') || lower.startsWith('gcm')) return;
      out[k] = _stringValue(value);
    });
    final String fallbackType = type?.trim() ?? '';
    if ((out['type'] ?? '').trim().isEmpty && fallbackType.isNotEmpty) out['type'] = fallbackType;
    final String? channel = spec?.androidChannelId;
    if (channel != null && channel.isNotEmpty) out.putIfAbsent('channelId', () => channel);
    return out;
  }

  static String _stringValue(Object value) {
    if (value is String) return value;
    if (value is Map || value is List) {
      try {
        return jsonEncode(value, toEncodable: (Object? o) => o.toString());
      } catch (_) {
        return value.toString();
      }
    }
    return value.toString();
  }

  /// The `message` object of an FCM v1 `messages:send` request: the
  /// notification, string data, and the platform blocks that make it show
  /// and sound on the receiving app (Android channel, high priority; APNs
  /// alert priority, sound, background wake-up).
  static Map<String, dynamic> fcmV1Message({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
    required PushChannelSpec spec,
  }) {
    return {
      'token': token.trim(),
      'notification': {'title': title, 'body': body},
      if (data.isNotEmpty) 'data': data,
      'android': {
        'priority': 'high',
        'notification': {
          if (spec.androidChannelId != null && spec.androidChannelId!.isNotEmpty) 'channel_id': spec.androidChannelId,
          'sound': spec.androidSound,
        },
      },
      'apns': {
        'headers': {'apns-priority': '10'},
        'payload': {
          'aps': {'sound': spec.apnsSound, 'content-available': 1},
        },
      },
    };
  }

  /// The request body of the `sendPush` function (`.claude/SERVER-PUSH-CONTRACT.md`):
  /// the same title, body, data and channel as the legacy message.
  static Map<String, dynamic> serverRequest({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
    required PushChannelSpec spec,
    String? kind,
  }) {
    final String k = kind?.trim() ?? '';
    return {
      'token': token.trim(),
      'title': title,
      'body': body,
      'data': data,
      if (k.isNotEmpty) 'kind': k,
      'android': {
        if (spec.androidChannelId != null && spec.androidChannelId!.isNotEmpty) 'channelId': spec.androidChannelId,
        'sound': spec.androidSound,
      },
      'apns': {'sound': spec.apnsSound},
    };
  }
}

/// What FCM said when a send failed, for logs. Never holds the token.
class FcmSendError {
  const FcmSendError({required this.statusCode, this.status, this.errorCode, this.tokenRejected = false});

  final int statusCode;

  /// `error.status`, e.g. `NOT_FOUND`, `INVALID_ARGUMENT`.
  final String? status;

  /// `error.details[].errorCode`, e.g. `UNREGISTERED`, `INVALID_ARGUMENT`,
  /// `SENDER_ID_MISMATCH`, `QUOTA_EXCEEDED`, `THIRD_PARTY_AUTH_ERROR`.
  final String? errorCode;

  /// FCM refused the registration token itself (as opposed to the payload).
  final bool tokenRejected;

  /// The recipient's token is dead: the app was uninstalled, the token
  /// rotated, or it belongs to another Firebase project.
  bool get isDeadToken => errorCode == 'UNREGISTERED' || errorCode == 'SENDER_ID_MISMATCH' || tokenRejected;

  factory FcmSendError.parse(int statusCode, String body) {
    String? status;
    String? errorCode;
    bool tokenRejected = false;
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        final Map error = decoded['error'] as Map;
        status = error['status']?.toString();
        final Object? details = error['details'];
        if (details is List) {
          for (final Object? d in details) {
            if (d is Map && d['errorCode'] != null) {
              errorCode = d['errorCode'].toString();
              break;
            }
          }
        }
        final String message = (error['message'] ?? '').toString().toLowerCase();
        tokenRejected = (errorCode ?? status) == 'INVALID_ARGUMENT' && message.contains('registration token');
      }
    } catch (_) {
      // Not JSON (a proxy or HTML error page): the status code is all we have.
    }
    return FcmSendError(statusCode: statusCode, status: status, errorCode: errorCode, tokenRejected: tokenRejected);
  }

  @override
  String toString() => 'HTTP $statusCode ${status ?? '-'} ${errorCode ?? '-'}${tokenRejected ? ' (token rejected)' : ''}';
}

/// An OAuth access token minted from the service account, reused until
/// shortly before it expires instead of downloading the key for every push.
class CachedAccessToken {
  const CachedAccessToken({required this.token, required this.expiry});

  final String token;

  /// UTC.
  final DateTime expiry;

  static const Duration safetyMargin = Duration(minutes: 5);

  bool isUsable(DateTime nowUtc) => token.isNotEmpty && nowUtc.isBefore(expiry.subtract(safetyMargin));
}

/// Orders for a later time. The store is NOT told when such an order is
/// placed: the `scheduledOrderNotifier` Cloud Function (`functions/`) pushes
/// the store owner when the order becomes due (its scheduled time minus the
/// admin lead time in `settings/scheduleOrderNotification`). It finds the
/// orders by [sentField] == false, which the cart writes with the order.
abstract final class ScheduledOrderNotice {
  /// Order field the function queries and flips to true (once) when it has
  /// notified the store.
  static const String sentField = 'scheduledNotificationSent';

  /// True when [scheduleTime] is still ahead of [now]: no push now, the
  /// function notifies the store later. A time that has already passed (or
  /// none) is an immediate order: today's `order_placed` push.
  static bool isFutureSchedule(DateTime? scheduleTime, DateTime now) => scheduleTime != null && scheduleTime.isAfter(now);

  /// Extra fields written with a new order (same write, no extra round trip):
  /// `{scheduledNotificationSent: false}` for a future scheduled order,
  /// nothing for an immediate one.
  static Map<String, dynamic> orderFields({required DateTime? scheduleTime, required DateTime now}) {
    return isFutureSchedule(scheduleTime, now) ? const {sentField: false} : const {};
  }
}

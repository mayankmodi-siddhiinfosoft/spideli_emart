import 'dart:convert';

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

  static PushChannelSpec forRecipient(PushRecipient? recipient, {String? kind}) {
    switch (recipient) {
      case PushRecipient.customer:
        return const PushChannelSpec(androidChannelId: customer);
      case PushRecipient.store:
        if (storeOrderKinds.contains((kind ?? '').trim().toLowerCase())) {
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

  // ── Scheduled orders (data-only) ──

  /// `data.type` of the silent push that tells the store about an order for
  /// a later time. The store app shows nothing for it; it sets a local alarm
  /// for the order's time instead (`vendor/lib/utils/scheduled_order.dart`).
  static const String scheduledOrderType = 'scheduled_order';

  /// True when an order's [scheduleTime] is still ahead of [now]: the store
  /// is told silently now and alerted at that time. A time that has already
  /// passed (or none) is an immediate order: the normal `order_placed` push.
  static bool isFutureSchedule(DateTime? scheduleTime, DateTime now) => scheduleTime != null && scheduleTime.isAfter(now);

  /// Data of the silent scheduled-order push: `{type, orderId, scheduleAt}`,
  /// `scheduleAt` in epoch milliseconds (a string, as FCM requires).
  static Map<String, String> scheduledOrderData({required String orderId, required DateTime scheduleAt}) {
    return {'type': scheduledOrderType, 'orderId': orderId, 'scheduleAt': scheduleAt.millisecondsSinceEpoch.toString()};
  }

  /// The `message` of a DATA-ONLY FCM v1 send: no `notification` block, so
  /// nothing is shown or sounded on the receiving device; the receiving app's
  /// handler gets the data. Android high priority (delivered at once, even in
  /// Doze); APNs background push (`content-available: 1`, no alert / sound /
  /// badge, `apns-priority: 5` and `apns-push-type: background`, which Apple
  /// requires for a push that only has `content-available`).
  static Map<String, dynamic> fcmV1DataMessage({required String token, required Map<String, String> data}) {
    return {
      'token': token.trim(),
      'data': data,
      'android': {'priority': 'high'},
      'apns': {
        'headers': {'apns-priority': '5', 'apns-push-type': 'background'},
        'payload': {
          'aps': {'content-available': 1},
        },
      },
    };
  }

  /// The `sendPush` request of a data-only push: no `title`, no `body`, no
  /// channel or sound, so the function sends exactly [fcmV1DataMessage]
  /// (`.claude/SERVER-PUSH-CONTRACT.md` section 2, "A data-only request").
  static Map<String, dynamic> serverDataRequest({required String token, required Map<String, String> data, String? kind}) {
    final String k = kind?.trim() ?? '';
    return {
      'token': token.trim(),
      'data': data,
      if (k.isNotEmpty) 'kind': k,
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

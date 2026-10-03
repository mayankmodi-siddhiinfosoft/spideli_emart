/// Pure pieces of the driver app's push handling: no Firebase, no network,
/// so every rule here is unit tested (test/push_message_test.dart).
///
/// See `.claude/PUSH-CHANNELS.md` (driver section) for the full channel map
/// and `.claude/SERVER-PUSH-CONTRACT.md` for the server path.
library;

import 'dart:convert';

/// The app a push is addressed to. The Android channel in the message must be
/// one the RECEIVING app creates, or Android posts it on that app's manifest
/// default channel (or a silent "Miscellaneous" fallback).
enum PushRecipient {
  /// Customer app (`customer/`).
  customer,

  /// Store app (`vendor/`), anything that is not a new order.
  store,

  /// Store app (`vendor/`), a new order (loud `new_order` channel).
  storeNewOrder,

  /// Driver app, anything that is not a job (chat, updates, cancellations).
  driver,

  /// Driver app, a new / assigned job (loud job channel).
  driverJob,

  /// Provider app (`spideli_provider/`).
  provider,

  /// Worker app (`spideli_worker/`).
  worker,
}

/// Channel and sounds a push must carry for its recipient app.
class PushTarget {
  final String androidChannelId;
  final String androidSound;
  final String apnsSound;

  const PushTarget({required this.androidChannelId, this.androidSound = 'default', this.apnsSound = 'default'});
}

/// Channel ids each app creates at start-up (read from each app's
/// notification_service.dart / AndroidManifest.xml).
class PushChannels {
  PushChannels._();

  /// customer/lib/utils/notification_service.dart, manifest default.
  static const String customer = 'high_importance_channel';

  /// vendor/lib/utils/notification_service.dart (`orderChannelId`), manifest default.
  static const String storeNewOrder = 'new_order';

  /// vendor/lib/utils/notification_service.dart (`generalChannelId`).
  static const String storeGeneral = 'general';

  /// `res/raw/order_alert.wav` in the store app.
  static const String storeOrderSound = 'order_alert';

  /// Driver: everything that is not a job. Manifest default.
  static const String driver = 'driver_notifications_channel';

  /// Driver: a new or assigned job (importance max, ringtone stream).
  static const String driverJob = 'driver_jobs';

  /// spideli_provider/lib/services/notification_service.dart.
  static const String provider = '01';

  /// spideli_worker/lib/services/notification_service.dart.
  static const String worker = '01';

  static PushTarget forRecipient(PushRecipient recipient) {
    switch (recipient) {
      case PushRecipient.customer:
        return const PushTarget(androidChannelId: customer);
      case PushRecipient.store:
        return const PushTarget(androidChannelId: storeGeneral);
      case PushRecipient.storeNewOrder:
        return const PushTarget(androidChannelId: storeNewOrder, androidSound: storeOrderSound, apnsSound: 'order_alert.caf');
      case PushRecipient.driver:
        return const PushTarget(androidChannelId: driver);
      case PushRecipient.driverJob:
        return const PushTarget(androidChannelId: driverJob);
      case PushRecipient.provider:
        return const PushTarget(androidChannelId: provider);
      case PushRecipient.worker:
        return const PushTarget(androidChannelId: worker);
    }
  }

  /// `type` / kind values that announce a job to a driver: these go on
  /// [driverJob]. Template types (`new_delivery_order`, `assign_order`), the
  /// server contract's driver-job kinds, and the `data.type` values the
  /// driver app's own local notifications use.
  static const Set<String> driverJobTypes = {
    'new_delivery_order',
    'assign_order',
    'driver_job',
    'order_available',
    'job_assigned',
    'job_queue',
    'new_ride',
    'new_parcel',
    'new_rental',
    'order',
    'new_order',
    'vendor_order',
    'parcel_order',
    'rental_order',
    'cab_order',
  };

  /// Channel the driver app shows an incoming push on (foreground display):
  /// the channel the sender named when it is one of the driver's, otherwise
  /// the job channel for a job type, otherwise the general driver channel.
  static String driverChannelFor({String? type, String? requestedChannelId}) {
    final String requested = (requestedChannelId ?? '').trim();
    if (requested == driver || requested == driverJob) return requested;
    if (driverJobTypes.contains((type ?? '').trim())) return driverJob;
    return driver;
  }
}

/// Builds and checks FCM messages.
class PushMessage {
  PushMessage._();

  /// A registration token worth sending to: not empty and not a stringified
  /// null.
  static bool isUsableToken(String? token) {
    final String t = (token ?? '').trim();
    if (t.isEmpty) return false;
    final String lower = t.toLowerCase();
    return lower != 'null' && lower != 'undefined' && lower != 'nil';
  }

  /// FCM HTTP v1 rejects the WHOLE message (400) when any data value is not a
  /// string. Nulls are dropped, maps and lists are JSON-encoded, everything
  /// else goes through `toString()`. `type` is always present: the caller's,
  /// or [type] (the template type) when the caller gave none.
  static Map<String, String> stringData(Map<String, dynamic>? payload, {String? type}) {
    final Map<String, String> out = <String, String>{};
    payload?.forEach((String key, dynamic value) {
      if (key.isEmpty || value == null) return;
      if (value is Map || value is Iterable) {
        out[key] = jsonEncode(_jsonSafe(value));
      } else {
        out[key] = value.toString();
      }
    });
    final String fallbackType = (type ?? '').trim();
    if ((out['type'] ?? '').trim().isEmpty && fallbackType.isNotEmpty) out['type'] = fallbackType;
    return out;
  }

  /// Values jsonEncode cannot handle (Timestamps, DateTimes, models) become
  /// their `toString()`.
  static dynamic _jsonSafe(dynamic value) {
    if (value == null || value is String || value is num || value is bool) return value;
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), _jsonSafe(v)));
    if (value is Iterable) return value.map(_jsonSafe).toList();
    return value.toString();
  }

  /// The project id for the FCM v1 path: the Firebase app's own project id
  /// (`spideli-870b0`), falling back to the settings `senderId` (the project
  /// NUMBER) only when the app has none.
  static String projectId({String? firebaseProjectId, String? settingsSenderId}) {
    final String fromApp = (firebaseProjectId ?? '').trim();
    if (fromApp.isNotEmpty) return fromApp;
    return (settingsSenderId ?? '').trim();
  }

  static Uri fcmSendUri(String projectId) => Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

  /// The legacy (on-device) FCM v1 message: notification + string data, plus
  /// the platform blocks that make it show and sound in the background on
  /// both platforms.
  static Map<String, dynamic> v1Message({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
    required PushRecipient recipient,
  }) {
    final PushTarget target = PushChannels.forRecipient(recipient);
    return <String, dynamic>{
      'message': <String, dynamic>{
        'token': token.trim(),
        'notification': <String, String>{'title': title, 'body': body},
        if (data.isNotEmpty) 'data': data,
        'android': <String, dynamic>{
          'priority': 'high',
          'notification': <String, String>{
            'channel_id': target.androidChannelId,
            'sound': target.androidSound,
          },
        },
        'apns': <String, dynamic>{
          'headers': <String, String>{'apns-priority': '10'},
          'payload': <String, dynamic>{
            'aps': <String, dynamic>{
              'sound': target.apnsSound,
              'content-available': 1,
            },
          },
        },
      },
    };
  }

  /// Body for the `sendPush` function (SERVER-PUSH-CONTRACT.md section 2).
  static Map<String, dynamic> serverRequest({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
    required PushRecipient recipient,
    String? kind,
  }) {
    final PushTarget target = PushChannels.forRecipient(recipient);
    final String k = (kind ?? '').trim();
    return <String, dynamic>{
      'token': token.trim(),
      'title': title,
      'body': body,
      'data': data,
      if (k.isNotEmpty) 'kind': k,
      'android': <String, String>{'channelId': target.androidChannelId, 'sound': target.androidSound},
      'apns': <String, String>{'sound': target.apnsSound},
    };
  }

  /// `settings/notification_setting.serverPushUrl` switches to the server
  /// path only when it is an https URL with a host.
  static bool isHttpsUrl(String? url) {
    final Uri? u = Uri.tryParse((url ?? '').trim());
    return u != null && u.scheme == 'https' && u.host.isNotEmpty;
  }

  /// FCM v1 error body -> its error code (`UNREGISTERED`, `INVALID_ARGUMENT`,
  /// `SENDER_ID_MISMATCH`, ...): the FcmError detail when present, else the
  /// Google API status. Empty when the body is not an error.
  static FcmFailure parseFcmError(int statusCode, String responseBody) {
    String code = '';
    String message = '';
    try {
      final dynamic decoded = jsonDecode(responseBody);
      final dynamic error = decoded is Map ? decoded['error'] : null;
      if (error is Map) {
        message = (error['message'] ?? '').toString();
        final dynamic details = error['details'];
        if (details is List) {
          for (final dynamic d in details) {
            if (d is Map && (d['errorCode'] ?? '').toString().isNotEmpty) {
              code = d['errorCode'].toString();
              break;
            }
          }
        }
        if (code.isEmpty) code = (error['status'] ?? '').toString();
      }
    } catch (_) {
      // Not JSON (proxy page, empty body): the status alone is reported.
    }
    return FcmFailure(statusCode: statusCode, code: code, message: message);
  }

  /// The server function's error body -> its `error` code (`unregistered`,
  /// `invalid_token`, `rate_limited`, ...).
  static String parseServerError(String responseBody) {
    try {
      final dynamic decoded = jsonDecode(responseBody);
      if (decoded is Map) return (decoded['error'] ?? '').toString();
    } catch (_) {}
    return '';
  }

  /// The recipient's token is dead (app uninstalled, token rotated, or not a
  /// token at all): retrying never helps.
  static bool isDeadTokenError({String? fcmCode, String? fcmMessage, String? serverCode}) {
    final String f = (fcmCode ?? '').toUpperCase();
    if (f == 'UNREGISTERED') return true;
    if (f == 'INVALID_ARGUMENT' && (fcmMessage ?? '').toLowerCase().contains('registration token')) return true;
    final String s = (serverCode ?? '').toLowerCase();
    return s == 'unregistered' || s == 'invalid_token';
  }
}

/// A failed FCM v1 send, safe to log (never contains the token).
class FcmFailure {
  final int statusCode;
  final String code;
  final String message;

  const FcmFailure({required this.statusCode, required this.code, required this.message});

  @override
  String toString() {
    final String m = message.length > 160 ? '${message.substring(0, 160)}...' : message;
    return 'HTTP $statusCode ${code.isEmpty ? '-' : code}${m.isEmpty ? '' : ': $m'}';
  }
}

/// When this device writes or clears `users/{uid}.fcmToken`.
class PushTokenRules {
  PushTokenRules._();

  /// Save [deviceToken] only when it is usable and differs from what is
  /// stored: an empty token (iOS before the APNs token arrived) never
  /// replaces a good one.
  static bool shouldSave({required String? deviceToken, required String? storedToken}) {
    if (!PushMessage.isUsableToken(deviceToken)) return false;
    return deviceToken!.trim() != (storedToken ?? '').trim();
  }

  /// On sign-out clear the stored token only when it is still THIS device's:
  /// the driver may have signed in on another phone since.
  static bool shouldClearOnSignOut({required String? storedToken, required String? deviceToken}) {
    if (!PushMessage.isUsableToken(deviceToken)) return false;
    return (storedToken ?? '').trim() == deviceToken!.trim();
  }
}

/// A minted OAuth access token and when it stops working.
class CachedAccessToken {
  final String value;
  final DateTime expiresAt;

  const CachedAccessToken(this.value, this.expiresAt);

  /// Still usable at [now] with [margin] to spare (tokens live an hour; a
  /// token is replaced five minutes before it expires).
  bool isFresh(DateTime now, {Duration margin = const Duration(minutes: 5)}) {
    if (value.isEmpty) return false;
    return now.toUtc().isBefore(expiresAt.toUtc().subtract(margin));
  }
}

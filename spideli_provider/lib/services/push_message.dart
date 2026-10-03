// Pure pieces of push sending and token handling: no Flutter, no Firebase, so
// they are unit tested (test/push_message_test.dart). The I/O lives in
// send_notification.dart (sending) and notification_service.dart (receiving).
//
// The channel ids of every app are documented in .claude/PUSH-CHANNELS.md.
import 'dart:convert';

/// The app a push is meant for. Each app creates its own Android channels, so
/// the channel in the message depends on who receives it.
enum PushApp { customer, provider, worker }

/// Android channel and sounds for one receiving app.
class PushRoute {
  final String channelId;
  final String androidSound;
  final String apnsSound;

  const PushRoute({required this.channelId, this.androidSound = 'default', this.apnsSound = 'default'});
}

/// Android channel ids, per receiving app.
class PushChannels {
  /// Created by this app at startup (NotificationService.createAndroidChannels)
  /// and named in android/app/src/main/AndroidManifest.xml as
  /// `default_notification_channel_id`. Bookings and chat both use it.
  ///
  /// The id is "01" because that is the channel earlier builds already created
  /// on devices (an existing channel's importance and sound cannot be changed
  /// afterwards, and other apps' senders were written against this id).
  static const String provider = '01';

  /// The customer app's `default_notification_channel_id`
  /// (customer/android/app/src/main/AndroidManifest.xml).
  static const String customer = 'high_importance_channel';

  /// The worker app's channel (spideli_worker/lib/services/notification_service.dart).
  static const String worker = '01';
}

/// Channel and sound for a push to [app]. None of these apps ships a custom
/// sound, so the platform default tone plays.
PushRoute pushRouteFor(PushApp app) {
  switch (app) {
    case PushApp.customer:
      return const PushRoute(channelId: PushChannels.customer);
    case PushApp.worker:
      return const PushRoute(channelId: PushChannels.worker);
    case PushApp.provider:
      return const PushRoute(channelId: PushChannels.provider);
  }
}

/// Who receives a `dynamic_notification` template sent by this app: a worker
/// for an assignment, the customer for every booking status.
PushApp recipientForKind(String kind) {
  switch (kind.trim()) {
    case 'worker_assigned':
      return PushApp.worker;
    default:
      return PushApp.customer;
  }
}

/// Keys FCM refuses in `data` (the whole message is rejected with 400).
bool _isReservedDataKey(String key) {
  final String k = key.toLowerCase();
  return k.isEmpty || k == 'from' || k == 'notification' || k == 'message_type' || k == 'collapse_key' || k.startsWith('google') || k.startsWith('gcm');
}

/// [payload] as FCM v1 accepts it: string values only. A null value drops its
/// key, a map or list is JSON-encoded, anything else uses `toString()`.
/// FCM rejects the whole message when a single data value is not a string.
Map<String, String> stringifyPushData(Map<String, dynamic>? payload) {
  final Map<String, String> out = <String, String>{};
  payload?.forEach((String key, dynamic value) {
    if (value == null || _isReservedDataKey(key)) return;
    if (value is String) {
      out[key] = value;
    } else if (value is Map || value is List) {
      out[key] = jsonEncode(value, toEncodable: (Object? o) => o.toString());
    } else {
      out[key] = value.toString();
    }
  });
  return out;
}

/// The data block of a push: [payload] stringified, and always a `type` (the
/// receiving app routes taps on it). [kind] is used when the payload has none.
Map<String, String> buildPushData(Map<String, dynamic>? payload, {required String kind}) {
  final Map<String, String> data = stringifyPushData(payload);
  if ((data['type'] ?? '').trim().isEmpty && kind.trim().isNotEmpty) {
    data['type'] = kind.trim();
  }
  return data;
}

/// Whether [token] can be sent to. Empty and "null" (a stringified null from an
/// old record) are not tokens: FCM answers 400 for them.
bool isUsableFcmToken(String? token) {
  if (token == null) return false;
  final String t = token.trim();
  return t.isNotEmpty && t.toLowerCase() != 'null';
}

/// The token to send to. [fresh] is the token on the recipient's record read
/// at send time ('' when the record has none), or null when the record could
/// not be read or does not exist. [fallback] (a copy on an order or a list
/// loaded earlier) is used only in that null case: a record with an empty
/// token means the recipient signed out on that phone, and the copied token
/// may now belong to the next account signed in there, so nothing is sent.
String preferFreshToken({String? fresh, String? fallback}) {
  if (fresh != null) return isUsableFcmToken(fresh) ? fresh.trim() : '';
  if (isUsableFcmToken(fallback)) return fallback!.trim();
  return '';
}

/// The project in the FCM v1 path. `settings/notification_setting.senderId`
/// holds the project NUMBER, so the project id of the running app comes first,
/// then the service account's `project_id`, and the setting is the last resort.
String fcmProjectId({String? optionsProjectId, String? serviceAccountProjectId, String? settingsSenderId}) {
  for (final String? candidate in <String?>[optionsProjectId, serviceAccountProjectId, settingsSenderId]) {
    final String value = (candidate ?? '').trim();
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return '';
}

Uri fcmSendUri(String projectId) => Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

/// Longest notification title / body sent (the `sendPush` function refuses
/// more, and FCM refuses a message over 4 KB; a long chat message is read in
/// the chat anyway).
const int maxPushTitleLength = 200;
const int maxPushBodyLength = 1000;

/// [text] cut to at most [max] UTF-16 units, never inside a surrogate pair,
/// with an ellipsis when it was cut.
String clipPushText(String text, int max) {
  if (text.length <= max) return text;
  final StringBuffer out = StringBuffer();
  for (final int rune in text.runes) {
    final String char = String.fromCharCode(rune);
    if (out.length + char.length > max - 1) break;
    out.write(char);
  }
  out.write('\u2026');
  return out.toString();
}

/// The FCM v1 request body of the legacy path. The android and apns blocks
/// make the push heads-up and audible: a high priority message on the receiving
/// app's channel, and an APNs alert with a sound (without `sound` an iPhone
/// shows the banner silently).
Map<String, dynamic> buildFcmV1Message({
  required String token,
  required String title,
  required String body,
  required Map<String, String> data,
  required PushRoute route,
}) {
  return <String, dynamic>{
    'message': <String, dynamic>{
      'token': token.trim(),
      'notification': <String, String>{'title': clipPushText(title, maxPushTitleLength), 'body': clipPushText(body, maxPushBodyLength)},
      if (data.isNotEmpty) 'data': data,
      'android': <String, dynamic>{
        'priority': 'high',
        'notification': <String, String>{'channel_id': route.channelId, 'sound': route.androidSound},
      },
      'apns': <String, dynamic>{
        'headers': <String, String>{'apns-priority': '10'},
        'payload': <String, dynamic>{
          'aps': <String, dynamic>{'sound': route.apnsSound, 'content-available': 1},
        },
      },
    },
  };
}

/// The request body for the `sendPush` function (.claude/SERVER-PUSH-CONTRACT.md):
/// same title, body, data, channel and sound as the legacy path.
Map<String, dynamic> buildServerPushRequest({
  required String token,
  required String title,
  required String body,
  required Map<String, String> data,
  required String kind,
  required PushRoute route,
}) {
  return <String, dynamic>{
    'token': token.trim(),
    'title': clipPushText(title, maxPushTitleLength),
    'body': clipPushText(body, maxPushBodyLength),
    if (data.isNotEmpty) 'data': data,
    if (kind.trim().isNotEmpty) 'kind': kind.trim(),
    'android': <String, String>{'channelId': route.channelId, 'sound': route.androidSound},
    'apns': <String, String>{'sound': route.apnsSound},
  };
}

/// Whether `settings/notification_setting.serverPushUrl` switches sending to the
/// server: a non-empty https URL with a host.
bool isUsableServerPushUrl(String? url) {
  final Uri? u = Uri.tryParse((url ?? '').trim());
  return u != null && u.scheme == 'https' && u.host.isNotEmpty;
}

/// A failed send, without the token or any credential.
class PushSendError {
  final int httpStatus;

  /// FCM `errorCode` (UNREGISTERED, INVALID_ARGUMENT, SENDER_ID_MISMATCH, ...)
  /// or the function's `error` (unregistered, invalid_token, ...).
  final String code;

  /// The recipient's token is dead or malformed: retrying cannot help, the
  /// recipient app has to save a new one.
  final bool isDeadToken;

  const PushSendError({required this.httpStatus, required this.code, required this.isDeadToken});

  @override
  String toString() => 'HTTP $httpStatus${code.isEmpty ? '' : ' $code'}${isDeadToken ? ' (dead token)' : ''}';
}

/// Reads an FCM v1 error response.
PushSendError parseFcmError(int httpStatus, String responseBody) {
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
    // Not JSON (a proxy or HTML error page): the status alone is reported.
  }
  final bool invalidToken = code == 'INVALID_ARGUMENT' && message.toLowerCase().contains('registration token');
  return PushSendError(httpStatus: httpStatus, code: code, isDeadToken: code == 'UNREGISTERED' || invalidToken);
}

/// Reads an error response of the `sendPush` function.
PushSendError parseServerPushError(int httpStatus, String responseBody) {
  String code = '';
  try {
    final dynamic decoded = jsonDecode(responseBody);
    if (decoded is Map) code = (decoded['error'] ?? '').toString();
  } catch (_) {
    // Malformed JSON request or a non-JSON body: the status alone is reported.
  }
  return PushSendError(httpStatus: httpStatus, code: code, isDeadToken: code == 'unregistered' || code == 'invalid_token');
}

/// An 8-character fingerprint of a token for logs (FNV-1a), never the token.
String tokenFingerprint(String token) {
  int hash = 0x811c9dc5;
  for (final int unit in utf8.encode(token.trim())) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// Whether a cached OAuth access token can still be used: it must stay valid
/// for at least [margin] more.
bool isAccessTokenFresh(DateTime? expiry, DateTime now, {Duration margin = const Duration(minutes: 5)}) {
  if (expiry == null) return false;
  return expiry.toUtc().isAfter(now.toUtc().add(margin));
}

/// Whether this device's [token] should be written to `users/{uid}.fcmToken`.
///
/// Only onto an existing provider record (`users` also holds customers, store
/// owners and drivers, whose own app's token must never be replaced by this
/// one), and only when it changes something.
bool shouldWriteDeviceToken({required String token, required bool docExists, String? role, String? storedToken}) {
  if (!isUsableFcmToken(token) || !docExists) return false;
  if ((role ?? '').trim() != 'provider') return false;
  return (storedToken ?? '').trim() != token.trim();
}

/// The `fcmToken` a full write of the signed-in provider's record should carry,
/// or null to leave the stored field alone.
///
/// The record is often an in-memory copy loaded before the token was refreshed
/// (or before iOS had an APNs token, so the copy says ""): writing it back would
/// replace the live token with a stale or empty one. This device's current
/// token wins, then a usable token on the copy; "" is never written.
String? tokenForUserWrite({String? deviceToken, String? modelToken}) {
  if (isUsableFcmToken(deviceToken)) return deviceToken!.trim();
  if (isUsableFcmToken(modelToken)) return modelToken!.trim();
  return null;
}

/// Whether signing out should clear the stored token: only when it is still
/// this device's. Another device of the same account that signed in later owns
/// the field now, and clearing it would silence that device.
bool shouldClearTokenOnSignOut({String? storedToken, String? deviceToken}) {
  if (!isUsableFcmToken(deviceToken) || !isUsableFcmToken(storedToken)) return false;
  return storedToken!.trim() == deviceToken!.trim();
}

/// One value of a received push or tap payload as a string, "" when missing.
/// Payloads decoded from a local notification can hold non-string values.
String pushDataString(Map<dynamic, dynamic>? data, String key) {
  final dynamic value = data?[key];
  if (value == null) return '';
  final String text = value.toString().trim();
  return text.toLowerCase() == 'null' ? '' : text;
}

/// A local notification payload (the push's data, JSON-encoded) back as a map;
/// an empty map for a missing or malformed payload.
Map<String, dynamic> decodeTapPayload(String? payload) {
  if (payload == null || payload.trim().isEmpty) return <String, dynamic>{};
  try {
    final dynamic decoded = jsonDecode(payload);
    if (decoded is Map) return decoded.map((dynamic k, dynamic v) => MapEntry(k.toString(), v));
  } catch (_) {
    // Malformed payload: nothing to route on.
  }
  return <String, dynamic>{};
}

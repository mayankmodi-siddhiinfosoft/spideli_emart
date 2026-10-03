/// The pure pieces of sending and receiving a push in the worker app: the FCM
/// message and server-push bodies, the channel each recipient app creates, the
/// FCM project path, how an FCM error is read, the token-save decisions and
/// where a tapped push opens.
///
/// No Firebase or Flutter plugin is used here, so all of it is unit tested
/// (test/push_message_test.dart). See also `.claude/PUSH-CHANNELS.md`.
library;

import 'dart:convert';

/// The worker app's Android notification channel.
///
/// Every push the worker receives (assigned bookings from the provider, chat
/// from customers) is posted on it. It is created in `main()` before `runApp`
/// (NotificationService.createAndroidChannels) and is the manifest's
/// `default_notification_channel_id`, so a push carrying another channel id
/// still lands here. The id stays `01`: it is what the app already used for
/// foreground notifications, so devices that have it keep it, and it is what
/// the other apps read from this app's code.
const String workerChannelId = '01';
const String workerChannelName = 'Jobs and messages';
const String workerChannelDescription = 'Assigned bookings and chat messages';

/// The customer app's channel: created at start-up and its manifest default
/// (customer/lib/utils/notification_service.dart, `.claude/PUSH-CHANNELS.md`).
const String customerChannelId = 'high_importance_channel';

/// The provider app's channel (spideli_provider NotificationService,
/// `.claude/PUSH-CHANNELS.md`).
const String providerChannelId = '01';

/// Who receives a push sent by the worker app.
enum PushRecipient { customer, provider, worker }

/// The Android channel and sounds a push must carry for its receiving app.
class PushChannel {
  final String androidChannelId;
  final String androidSound;
  final String apnsSound;

  const PushChannel(this.androidChannelId, {this.androidSound = 'default', this.apnsSound = 'default'});
}

/// The channel the receiving app creates. A channel the device does not have
/// falls back to that app's manifest default, so a wrong guess still shows.
PushChannel pushChannelFor(PushRecipient recipient) {
  switch (recipient) {
    case PushRecipient.customer:
      return const PushChannel(customerChannelId);
    case PushRecipient.provider:
      return const PushChannel(providerChannelId);
    case PushRecipient.worker:
      return const PushChannel(workerChannelId);
  }
}

/// A token that FCM could deliver to. Records written by older builds hold
/// `''` or the string `'null'`, which FCM rejects with a 400.
bool isUsableFcmToken(String? token) {
  final String t = token?.trim() ?? '';
  return t.isNotEmpty && t.toLowerCase() != 'null';
}

/// The project in `https://fcm.googleapis.com/v1/projects/<id>/messages:send`.
///
/// The project ID of the Firebase app this build runs on (`spideli-870b0`).
/// Settings `senderId` holds the project NUMBER; it is only the fallback.
String fcmProjectId({String? optionsProjectId, String? settingsSenderId}) {
  final String fromOptions = optionsProjectId?.trim() ?? '';
  if (fromOptions.isNotEmpty) return fromOptions;
  final String fromSettings = settingsSenderId?.trim() ?? '';
  return fromSettings.toLowerCase() == 'null' ? '' : fromSettings;
}

/// Data keys FCM refuses (the whole message is rejected with a 400).
bool _reservedDataKey(String key) {
  final String k = key.toLowerCase();
  return k == 'from' || k == 'notification' || k == 'message_type' || k == 'collapse_key' || k.startsWith('google') || k.startsWith('gcm');
}

/// The FCM `data` map: string values only.
///
/// FCM v1 rejects the WHOLE message when one data value is not a string, is
/// null, or is a map or list. So: nulls are dropped, maps and lists are
/// JSON-encoded, everything else is `toString()`-ed, and reserved keys are
/// dropped. `type` is always present when [fallbackType] is given, because
/// the receiving apps route a tapped push on it.
Map<String, String> fcmDataPayload(Map<String, dynamic>? payload, {String? fallbackType}) {
  final Map<String, String> out = <String, String>{};
  payload?.forEach((String key, dynamic value) {
    if (value == null || key.trim().isEmpty || _reservedDataKey(key)) return;
    if (value is String) {
      out[key] = value;
    } else if (value is Map || value is Iterable) {
      out[key] = jsonEncode(value is Iterable ? value.toList() : value, toEncodable: (Object? o) => o.toString());
    } else {
      out[key] = value.toString();
    }
  });
  final String fallback = fallbackType?.trim() ?? '';
  if ((out['type'] ?? '').trim().isEmpty && fallback.isNotEmpty) out['type'] = fallback;
  return out;
}

String _clip(String text, int max) => text.length <= max ? text : text.substring(0, max);

/// Limits of the server function (SERVER-PUSH-CONTRACT.md); also keeps a
/// legacy message well under FCM's 4 KB.
const int maxPushTitleLength = 200;
const int maxPushBodyLength = 1000;

/// The FCM HTTP v1 request body (legacy path).
///
/// The `android` block makes the receiving app post it on its own channel with
/// high priority; the `apns` block gives it a sound (an iOS push without
/// `aps.sound` arrives silently) and wakes the app for its background handler.
Map<String, dynamic> buildFcmV1Message({
  required String token,
  required String title,
  required String body,
  required Map<String, String> data,
  required PushChannel channel,
}) {
  return <String, dynamic>{
    'message': <String, dynamic>{
      'token': token.trim(),
      'notification': <String, String>{'title': _clip(title, maxPushTitleLength), 'body': _clip(body, maxPushBodyLength)},
      if (data.isNotEmpty) 'data': data,
      'android': <String, dynamic>{
        'priority': 'high',
        'notification': <String, String>{'channel_id': channel.androidChannelId, 'sound': channel.androidSound},
      },
      'apns': <String, dynamic>{
        'headers': <String, String>{'apns-priority': '10'},
        'payload': <String, dynamic>{
          'aps': <String, dynamic>{'sound': channel.apnsSound, 'content-available': 1},
        },
      },
    },
  };
}

/// The request body for the `sendPush` function (SERVER-PUSH-CONTRACT.md 2):
/// same text, data and channel as the legacy message.
Map<String, dynamic> buildServerPushBody({
  required String token,
  required String title,
  required String body,
  required Map<String, String> data,
  required PushChannel channel,
  String? kind,
}) {
  final String k = kind?.trim() ?? '';
  return <String, dynamic>{
    'token': token.trim(),
    'title': _clip(title, maxPushTitleLength),
    'body': _clip(body, maxPushBodyLength),
    if (data.isNotEmpty) 'data': data,
    if (k.isNotEmpty) 'kind': k,
    'android': <String, String>{'channelId': channel.androidChannelId, 'sound': channel.androidSound},
    'apns': <String, String>{'sound': channel.apnsSound},
  };
}

/// `settings/notification_setting.serverPushUrl` switches sending to the
/// server function when it is an https URL with a host.
bool isHttpsUrl(String? url) {
  final Uri? uri = Uri.tryParse(url?.trim() ?? '');
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}

/// What a failed send said, without the token or any credential.
class PushSendError {
  final int statusCode;

  /// FCM `error.status` (e.g. `NOT_FOUND`) or the function's `error`.
  final String status;

  /// FCM `FcmError.errorCode` (e.g. `UNREGISTERED`), when present.
  final String errorCode;

  /// The recipient's token is dead or not a token: retrying cannot help.
  final bool isDeadToken;

  const PushSendError({required this.statusCode, this.status = '', this.errorCode = '', this.isDeadToken = false});

  @override
  String toString() => 'HTTP $statusCode${status.isEmpty ? '' : ' $status'}${errorCode.isEmpty ? '' : ' $errorCode'}${isDeadToken ? ' (stale recipient token)' : ''}';
}

Map<String, dynamic>? _jsonObject(String body) {
  try {
    final dynamic decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

/// Reads an FCM v1 error response
/// (`{"error":{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}`).
PushSendError parseFcmError(int statusCode, String body) {
  final dynamic error = _jsonObject(body)?['error'];
  String status = '';
  String errorCode = '';
  String message = '';
  if (error is Map) {
    status = (error['status'] ?? '').toString();
    message = (error['message'] ?? '').toString();
    final dynamic details = error['details'];
    if (details is List) {
      for (final dynamic d in details) {
        if (d is Map && d['errorCode'] != null) {
          errorCode = d['errorCode'].toString();
          break;
        }
      }
    }
  }
  final bool deadToken = errorCode == 'UNREGISTERED' ||
      errorCode == 'SENDER_ID_MISMATCH' ||
      ((errorCode == 'INVALID_ARGUMENT' || status == 'INVALID_ARGUMENT') && message.toLowerCase().contains('registration token'));
  return PushSendError(statusCode: statusCode, status: status, errorCode: errorCode, isDeadToken: deadToken);
}

/// Reads a `sendPush` function error (`{"ok":false,"error":"unregistered"}`).
PushSendError parseServerPushError(int statusCode, String body) {
  final String code = (_jsonObject(body)?['error'] ?? '').toString();
  return PushSendError(
    statusCode: statusCode,
    status: code,
    isDeadToken: code == 'unregistered' || code == 'invalid_token' || code == 'sender_mismatch',
  );
}

/// The cached OAuth access token may be reused until shortly before it expires.
bool accessTokenUsable(DateTime? expiry, DateTime now, {Duration margin = const Duration(minutes: 5)}) {
  return expiry != null && now.toUtc().isBefore(expiry.toUtc().subtract(margin));
}

/// The recipient's current token from their profile ([fresh]: '' when the
/// profile has none, null when it could not be read or does not exist). The
/// copy embedded in the order ([snapshot]) is used only in that null case: a
/// profile with an empty token means the recipient signed out on that phone,
/// and the copied token may now belong to the next account signed in there,
/// so nothing is sent.
String pickRecipientToken({String? fresh, String? snapshot}) {
  if (fresh != null) return isUsableFcmToken(fresh) ? fresh.trim() : '';
  if (isUsableFcmToken(snapshot)) return snapshot!.trim();
  return '';
}

/// This device's token must be written to the signed-in worker's document:
/// never an empty token (it would erase a good one), and not again when this
/// session already wrote the same token for the same worker.
bool shouldWriteDeviceToken({required String? newToken, String? lastWrittenToken}) {
  return isUsableFcmToken(newToken) && newToken!.trim() != (lastWrittenToken ?? '').trim();
}

/// On sign-out the worker's token is cleared only when it is still this
/// device's: if the worker has since signed in on another phone, that phone's
/// token stays.
bool shouldClearTokenOnSignOut({required String? storedToken, required String? deviceToken}) {
  return isUsableFcmToken(deviceToken) && isUsableFcmToken(storedToken) && storedToken!.trim() == deviceToken!.trim();
}

// ------------------------------------------------- on-demand bookings --

/// The `type` every on-demand booking push carries (all three apps route on
/// it). See `.claude/ONDEMAND-NOTIFICATIONS.md`.
const String onDemandPushType = 'provider_order';

/// The `event` codes of `.claude/ONDEMAND-NOTIFICATIONS.md` (one per action).
class OnDemandEvent {
  OnDemandEvent._();

  static const String bookingPlaced = 'booking_placed'; // 1
  static const String bookingCancelledByCustomer = 'booking_cancelled_by_customer'; // 2
  static const String providerAccepted = 'provider_accepted'; // 3
  static const String providerRejected = 'provider_rejected'; // 4
  static const String workerAssigned = 'worker_assigned'; // 5
  static const String workerAssignedCustomer = 'worker_assigned_customer'; // 6
  static const String workerUnassigned = 'worker_unassigned'; // 7
  static const String serviceInTransit = 'service_intransit'; // 8
  static const String stopTime = 'stop_time'; // 9
  static const String serviceCharges = 'service_charges'; // 10
  static const String serviceCompleted = 'service_completed'; // 11
  static const String workerAccepted = 'worker_accepted'; // 12
  static const String workerRejected = 'worker_rejected'; // 13

  /// Every code above: a push whose `type` is one of them (older senders put
  /// the template type there) is an on-demand booking push too.
  static const Set<String> all = <String>{
    bookingPlaced,
    bookingCancelledByCustomer,
    providerAccepted,
    providerRejected,
    workerAssigned,
    workerAssignedCustomer,
    workerUnassigned,
    serviceInTransit,
    stopTime,
    serviceCharges,
    serviceCompleted,
    workerAccepted,
    workerRejected,
  };
}

/// The data of an on-demand booking push sent by the worker app (contract
/// "Data payload"): `type`, `event`, `orderId`, `status`, the service and the
/// parties when known, `senderRole` = `worker`. Blank or `"null"` values are
/// dropped, never sent.
Map<String, String> onDemandPushData({
  required String event,
  required String orderId,
  required String status,
  String? serviceId,
  String? serviceName,
  String? customerId,
  String? providerId,
  String? workerId,
  String senderRole = 'worker',
}) {
  final Map<String, String> out = <String, String>{};
  void put(String key, String? value) {
    final String text = value?.trim() ?? '';
    final String lower = text.toLowerCase();
    if (text.isEmpty || lower == 'null' || lower == 'undefined' || lower == 'nil') return;
    out[key] = text;
  }

  put('type', onDemandPushType);
  put('event', event);
  put('orderId', orderId);
  put('status', status);
  put('serviceId', serviceId);
  put('serviceName', serviceName);
  put('customerId', customerId);
  put('providerId', providerId);
  put('workerId', workerId);
  put('senderRole', senderRole);
  return out;
}

/// Where a tapped push opens.
///
/// [jobList] is the Jobs tab: an on-demand booking push without a usable
/// `orderId`, or one telling the worker the booking was taken off them
/// (`worker_unassigned`).
enum PushRoute { none, booking, jobList, chat, inbox, legacyProviderChat, adminChat }

String _value(Map<String, dynamic> data, String key) {
  final String text = (data[key] ?? '').toString().trim();
  final String lower = text.toLowerCase();
  return (lower == 'null' || lower == 'undefined' || lower == 'nil') ? '' : text;
}

/// The screen a tapped push opens, from its data. Missing fields never throw:
/// a push without what its screen needs opens nothing (the app just comes to
/// the front).
///
/// - `provider_order` (or an on-demand `event` code as the type) + `orderId`:
///   the booking ([jobTapTarget] then decides details or job list); without a
///   usable `orderId`, or `event` = `worker_unassigned`: the job list.
/// - `orderChat` / `chat` + `orderId` + `senderId` (chat from a customer): that
///   chat; without the order or the sender: the inbox.
/// - `provider_chat` + `orderId`: the chat, with the arguments in the payload.
/// - `admin` / `admin_chat`, or chatType `admin`: Help & Support.
/// - any other type that carries an `orderId`: the booking.
PushRoute pushRouteFor(Map<String, dynamic> data) {
  final String type = _value(data, 'type');
  final String orderId = _value(data, 'orderId');
  if (type == 'admin' || type == 'admin_chat' || _value(data, 'chatType').toLowerCase() == 'admin') return PushRoute.adminChat;
  switch (type) {
    case 'orderChat':
    case 'chat':
      return orderId.isEmpty || _value(data, 'senderId').isEmpty ? PushRoute.inbox : PushRoute.chat;
    case 'provider_chat':
      return orderId.isEmpty ? PushRoute.none : PushRoute.legacyProviderChat;
  }
  final String event = _value(data, 'event');
  final bool onDemand = type == onDemandPushType || OnDemandEvent.all.contains(type) || OnDemandEvent.all.contains(event);
  if (onDemand) {
    // A booking taken off this worker is no longer theirs to open.
    if (event == OnDemandEvent.workerUnassigned || type == OnDemandEvent.workerUnassigned) return PushRoute.jobList;
    return orderId.isEmpty ? PushRoute.jobList : PushRoute.booking;
  }
  return orderId.isEmpty ? PushRoute.none : PushRoute.booking;
}

/// What a tapped booking push opens once the booking was looked up.
enum JobTapTarget { details, jobList }

/// The job a tapped on-demand push opens ([pushRouteFor] said
/// [PushRoute.booking]), after reading `provider_orders/{orderId}`:
/// - [orderExists] false (no such booking): the job list;
/// - the booking is now assigned to another worker ([orderWorkerId] set and not
///   [currentWorkerId]): the job list (it was reassigned);
/// - otherwise, and when the booking could not be read ([orderExists] null:
///   offline, timeout), its details: that screen shows its own error state.
JobTapTarget jobTapTarget({required String orderId, bool? orderExists, String? orderWorkerId, String? currentWorkerId}) {
  final String id = orderId.trim();
  final String lower = id.toLowerCase();
  if (id.isEmpty || lower == 'null' || lower == 'undefined' || lower == 'nil' || id.contains('/')) return JobTapTarget.jobList;
  if (orderExists == false) return JobTapTarget.jobList;
  final String assigned = orderWorkerId?.trim() ?? '';
  final String me = currentWorkerId?.trim() ?? '';
  if (orderExists == true && assigned.isNotEmpty && me.isNotEmpty && assigned != me) return JobTapTarget.jobList;
  return JobTapTarget.details;
}

/// The text of a booking push shown in the foreground when the push itself
/// carries none (a template missing on Firestore): untranslated keys of
/// `lib/lang/app_en.dart`, or null for pushes that are not on-demand events
/// the worker receives.
({String title, String body})? onDemandFallbackText(Map<String, dynamic> data) {
  final String event = _value(data, 'event').isEmpty ? _value(data, 'type') : _value(data, 'event');
  switch (event) {
    case OnDemandEvent.workerAssigned:
      return (title: 'New job assigned', body: 'A new booking has been assigned to you. Tap to view it.');
    case OnDemandEvent.workerUnassigned:
      return (title: 'Booking reassigned', body: 'This booking is no longer assigned to you');
    case OnDemandEvent.bookingCancelledByCustomer:
      return (title: 'Booking cancelled', body: 'The customer cancelled this booking.');
    case OnDemandEvent.providerRejected:
      return (title: 'Booking cancelled', body: 'The provider cancelled this booking.');
    default:
      return null;
  }
}

/// The data of a tapped local notification (its payload is the push data as
/// JSON). Anything unreadable is an empty map, never a throw.
Map<String, dynamic> decodeNotificationPayload(String? payload) {
  if (payload == null || payload.trim().isEmpty) return <String, dynamic>{};
  final Map<String, dynamic>? decoded = _jsonObject(payload);
  return decoded ?? <String, dynamic>{};
}

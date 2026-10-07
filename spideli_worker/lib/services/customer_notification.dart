/// The customer's Notification Center record the worker app writes next to
/// every push it sends to a customer (`.claude/CUSTOMER-NOTIFICATIONS.md` 1,
/// "Senders"): `users/{customerId}/notifications/{id}`, same title and body
/// as the push, and the push data then carries `notificationId: <id>` so the
/// customer app does not store it a second time.
///
/// Pure (no Firebase): the Firestore write is
/// `FireStoreUtils.recordCustomerNotification`, which adds `createdAt`
/// (server timestamp). Unit tested in test/customer_notification_test.dart.
library;

import 'package:spideliworker/services/push_message.dart';

/// `users/{customerId}/<this>/{notificationId}`.
const String customerNotificationsCollection = 'notifications';

/// The push data key that names the record (contract 1).
const String notificationIdKey = 'notificationId';

/// `source` of every record this app writes.
const String customerNotificationSource = 'worker';

/// Contract `category` values the worker app uses.
class CustomerNotificationCategory {
  CustomerNotificationCategory._();

  static const String booking = 'booking';
  static const String chat = 'chat';
}

/// The push `kind` of a chat message (SendNotification.sendChatFcmMessage).
const String chatPushKind = 'chat';

String _clean(String? value) {
  final String text = value?.trim() ?? '';
  final String lower = text.toLowerCase();
  return (lower == 'null' || lower == 'undefined' || lower == 'nil') ? '' : text;
}

/// A usable Firestore document id: not blank, not `"null"`, no `/`.
bool isUsableDocumentId(String? id) {
  final String text = _clean(id);
  return text.isNotEmpty && !text.contains('/');
}

/// The id a caller already put in the push data (a chat retry reuses it, so
/// the record is written once per message), else null.
String? existingNotificationId(Map<String, dynamic>? payload) {
  final String id = _clean(payload?[notificationIdKey]?.toString());
  return isUsableDocumentId(id) ? id : null;
}

/// The record's `category`: `chat` for a chat push, `booking` for every job
/// status / extra-charges push.
String customerNotificationCategoryFor(String kind) => kind == chatPushKind ? CustomerNotificationCategory.chat : CustomerNotificationCategory.booking;

/// The record's `type`: the `dynamic_notification` template type of a job
/// push (`service_intransit`, `stop_time`, `service_completed`,
/// `service_charges`), the data `type` of a chat push (`orderChat`).
String customerNotificationTypeFor(String kind, Map<String, String> data) {
  if (kind != chatPushKind && _clean(kind).isNotEmpty) return _clean(kind);
  final String type = _clean(data['type']);
  return type.isNotEmpty ? type : _clean(kind);
}

/// Whether a push gets a record: it goes to a customer with a usable id, and
/// it has some text to show (a missing template sends an empty push, which
/// would be an empty row in the Notification Center).
bool shouldRecordCustomerNotification({required PushRecipient recipient, required String? customerId, required String title, required String body}) {
  if (recipient != PushRecipient.customer) return false;
  if (!isUsableDocumentId(customerId)) return false;
  return title.trim().isNotEmpty || body.trim().isNotEmpty;
}

/// The record without `createdAt` (the Firestore layer adds the server
/// timestamp). [data] is the push data as sent, including `notificationId`.
Map<String, dynamic> customerNotificationRecord({
  required String id,
  required String title,
  required String body,
  required String kind,
  required Map<String, String> data,
}) {
  return <String, dynamic>{
    'id': id,
    'title': title.length <= maxPushTitleLength ? title : title.substring(0, maxPushTitleLength),
    'body': body.length <= maxPushBodyLength ? body : body.substring(0, maxPushBodyLength),
    'type': customerNotificationTypeFor(kind, data),
    'category': customerNotificationCategoryFor(kind),
    'orderId': _clean(data['orderId']),
    'status': _clean(data['status']),
    'data': Map<String, String>.of(data),
    'read': false,
    'source': customerNotificationSource,
  };
}

/// [data] with `notificationId` set to [id].
Map<String, String> withNotificationId(Map<String, String> data, String id) => <String, String>{...data, notificationIdKey: id};

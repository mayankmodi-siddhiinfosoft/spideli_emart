// Pure pieces of the customer Notification Center record and of the chat
// unread badges (.claude/CUSTOMER-NOTIFICATIONS.md): no Flutter, no Firebase,
// so they are unit tested (test/customer_notification_test.dart). The write
// lives in send_notification.dart, the badges in ui/chat_screen.
import 'package:spideliprovider/services/push_message.dart';

/// `users/{customerId}/notifications`: one document per push the customer gets.
const String customerNotificationsCollection = 'notifications';

/// The push data key that tells the customer app the sender already stored
/// the notification (so it does not write its own fallback copy).
const String notificationIdDataKey = 'notificationId';

/// `source` of every record this app writes.
const String customerNotificationSource = 'provider';

/// The `category` of a push to the customer: `chat` for a chat message, else
/// `booking` (every other push this app sends a customer is about an
/// on-demand booking).
String customerNotificationCategory(String kind, Map<String, String> data) {
  final String k = kind.trim();
  final String type = (data['type'] ?? '').trim();
  if (k == 'chat' || type == 'orderChat' || type == 'chat' || type == 'admin_chat') return 'chat';
  return 'booking';
}

/// The `type` stored with the record: the template type for a booking push
/// (`provider_accepted`, `service_charges`, ...), the data `type` for a chat
/// push (`orderChat`).
String customerNotificationType(String kind, Map<String, String> data) {
  final String k = kind.trim();
  final String type = (data['type'] ?? '').trim();
  if (k == 'chat') return type.isNotEmpty ? type : 'orderChat';
  if (k.isNotEmpty) return k;
  return type.isNotEmpty ? type : 'other';
}

/// The `users/{customerId}/notifications/{id}` record of a push, without
/// `createdAt` (the writer adds a server timestamp). [data] is the push data
/// as sent (strings only), [title] / [body] the push text before clipping:
/// they are stored clipped exactly like the push.
Map<String, dynamic> buildCustomerNotificationRecord({
  required String id,
  required String title,
  required String body,
  required String kind,
  required Map<String, String> data,
}) {
  final Map<String, String> storedData = Map<String, String>.of(data)..[notificationIdDataKey] = id;
  return <String, dynamic>{
    'id': id,
    'title': clipPushText(title, maxPushTitleLength),
    'body': clipPushText(body, maxPushBodyLength),
    'type': customerNotificationType(kind, data),
    'category': customerNotificationCategory(kind, data),
    'orderId': (data['orderId'] ?? '').trim(),
    'status': (data['status'] ?? '').trim(),
    'data': storedData,
    'read': false,
    'source': customerNotificationSource,
  };
}

/// Whether a push gets a Notification Center record: only a push to the
/// customer app whose customer uid is known (the record lives under it), with
/// some text to show, and a uid that is a single document id.
bool shouldRecordCustomerNotification({required PushApp recipient, required String customerId, required String title, required String body}) {
  if (recipient != PushApp.customer) return false;
  final String id = customerId.trim();
  if (id.isEmpty || id.contains('/') || id == 'admin' || id.toLowerCase() == 'null') return false;
  return title.trim().isNotEmpty || body.trim().isNotEmpty;
}

/// The most unread messages a badge listener asks for: enough to show "99+".
const int unreadBadgeQueryLimit = 100;

/// The text of an unread badge: '' for none (no badge), the count up to
/// [cap], then "[cap]+".
String unreadBadgeLabel(int count, {int cap = 99}) {
  if (count <= 0) return '';
  return count > cap ? '$cap+' : '$count';
}

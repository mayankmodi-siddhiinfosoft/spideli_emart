import 'package:vendor/utils/push_payload.dart';

/// The customer's Notification Center entry the store writes next to every
/// push it sends to a customer: `users/{customerId}/notifications/{id}`
/// (`.claude/CUSTOMER-NOTIFICATIONS.md` section 1, "Senders").
///
/// Pure (no Firebase, no Flutter) so every rule is unit tested
/// (test/customer_notification_test.dart). The write itself is
/// `FireStoreUtils.addCustomerNotification`, called from
/// `SendNotification` (best effort: waited at most 8 s, never stops the push).
class CustomerNotification {
  CustomerNotification._();

  /// Subcollection under `users/{customerId}`.
  static const String collection = 'notifications';

  /// `source` of every entry the store writes.
  static const String sourceStore = 'store';

  /// Push data key carrying the entry id, so the customer app does not store
  /// the same notification a second time when the push arrives.
  static const String idDataKey = 'notificationId';

  static const String categoryOrder = 'order';
  static const String categoryChat = 'chat';
  static const String categoryBooking = 'booking';
  static const String categoryAccount = 'account';
  static const String categoryOther = 'other';

  /// The icon / filter group of a push, from its data `type` (or template
  /// type). A push with an order id and an unknown type is an order update.
  static String categoryFor(String? type, {String? orderId}) {
    final String t = (type ?? '').trim().toLowerCase();
    if (t.contains('chat')) return categoryChat;
    if (t.startsWith('dinein') || t.startsWith('booking') || t.startsWith('provider_') || t.startsWith('service_')) return categoryBooking;
    if (t.contains('wallet') || t.contains('payout') || t.contains('account') || t.contains('refund')) return categoryAccount;
    if (t.contains('order') ||
        t.startsWith('restaurant_') ||
        t.startsWith('store_') ||
        t.startsWith('takeaway_') ||
        t.startsWith('driver_') ||
        t.endsWith('_otp') ||
        t.startsWith('parcel_') ||
        t.startsWith('rental_')) {
      return categoryOrder;
    }
    if ((orderId ?? '').trim().isNotEmpty) return categoryOrder;
    return categoryOther;
  }

  /// True when the store records a push it sends to [recipient] / [recipientId]:
  /// only customers have a Notification Center, and only a known user id can
  /// hold the entry.
  static bool shouldRecord({required PushRecipient recipient, String? recipientId}) {
    final String id = (recipientId ?? '').trim();
    return recipient == PushRecipient.customer && id.isNotEmpty && id != 'admin' && id != 'null';
  }

  /// [data] as it is pushed: the same map plus [idDataKey].
  static Map<String, String> dataWithId(Map<String, String> data, String id) => {...data, idDataKey: id};

  /// The document for `users/{customerId}/notifications/{id}`.
  ///
  /// [data] is the push data as sent (string to string, including
  /// [idDataKey]); `type` and `orderId` are read from it when given, else
  /// [kind] (the template type). [createdAt] is the server timestamp sentinel
  /// (kept as a parameter so this stays free of Firebase).
  static Map<String, dynamic> document({
    required String id,
    required String title,
    required String body,
    required Map<String, String> data,
    String? kind,
    String? status,
    required Object createdAt,
  }) {
    final String dataType = (data['type'] ?? '').trim();
    final String type = dataType.isNotEmpty ? dataType : (kind ?? '').trim();
    final String orderId = (data['orderId'] ?? '').trim();
    return {
      'id': id,
      'title': PushPayload.clip(title, PushPayload.maxTitleLength),
      'body': PushPayload.clip(body, PushPayload.maxBodyLength),
      'type': type,
      'category': categoryFor(type, orderId: orderId),
      'orderId': orderId,
      'status': (status ?? '').trim(),
      'data': Map<String, String>.from(data),
      'read': false,
      'createdAt': createdAt,
      'source': sourceStore,
    };
  }
}

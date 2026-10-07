/// Pure pieces of the customer Notification Center record the driver app
/// writes next to every push it sends to a customer
/// (`.claude/CUSTOMER-NOTIFICATIONS.md` section 1, "Senders"). No Firebase
/// here, so every rule is unit tested (test/customer_notification_test.dart).
///
/// The document lives at `users/{customerId}/notifications/{id}`; the push
/// data then carries `notificationId: <id>` so the customer app does not
/// store the same notification a second time.
library;

class CustomerNotification {
  CustomerNotification._();

  /// `source` of every record this app writes.
  static const String source = 'driver';

  /// Push data key that names the stored record.
  static const String idKey = 'notificationId';

  /// Contract categories (icon / filter in the customer app).
  static const String categoryOrder = 'order';
  static const String categoryChat = 'chat';
  static const String categoryBooking = 'booking';
  static const String categoryAccount = 'account';
  static const String categoryOther = 'other';

  static const Set<String> _chatTypes = <String>{'orderChat', 'chat', 'admin_chat', 'admin'};

  /// True when a record should be written: the push goes to the customer app,
  /// there is a customer to write it for and some text to show.
  static bool shouldRecord({required bool toCustomer, required String? customerId, required String? title, required String? body}) {
    if (!toCustomer) return false;
    if ((customerId ?? '').trim().isEmpty) return false;
    return (title ?? '').trim().isNotEmpty || (body ?? '').trim().isNotEmpty;
  }

  /// The category for a push [type] (template type or data `type`). Every
  /// other push the driver app sends to a customer concerns an order, ride,
  /// parcel or rental; one without an order id is `other`.
  static String categoryFor(String? type, {String? orderId}) {
    final String t = (type ?? '').trim();
    if (_chatTypes.contains(t) || t.toLowerCase().endsWith('chat')) return categoryChat;
    if ((orderId ?? '').trim().isNotEmpty) return categoryOrder;
    return categoryOther;
  }

  /// The push [data] with [id] added as [idKey].
  static Map<String, String> withId(Map<String, String> data, String id) {
    final Map<String, String> out = Map<String, String>.of(data);
    if (id.trim().isNotEmpty) out[idKey] = id;
    return out;
  }

  /// The push [data] without [idKey] (the record could not be written, so the
  /// customer app must store the notification itself).
  static Map<String, String> withoutId(Map<String, String> data) {
    final Map<String, String> out = Map<String, String>.of(data);
    out.remove(idKey);
    return out;
  }

  /// The document for `users/{customerId}/notifications/{id}`.
  /// [type] is the template type (or the data `type` for a push with its own
  /// text); [data] is the push data as sent (with [idKey]). [createdAt] is
  /// the server timestamp sentinel in the app.
  static Map<String, dynamic> document({
    required String id,
    required String title,
    required String body,
    required String type,
    required Map<String, String> data,
    required Object createdAt,
    String? status,
  }) {
    final String orderId = (data['orderId'] ?? '').trim();
    final String resolvedType = type.trim().isNotEmpty ? type.trim() : (data['type'] ?? '').trim();
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'type': resolvedType,
      'category': categoryFor(resolvedType.isNotEmpty ? resolvedType : data['type'], orderId: orderId),
      'orderId': orderId,
      'status': (status ?? '').trim(),
      'data': Map<String, String>.of(data),
      'read': false,
      'createdAt': createdAt,
      'source': source,
    };
  }
}

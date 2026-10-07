import 'package:cloud_firestore/cloud_firestore.dart';

/// One entry of the customer's Notification Center:
/// `users/{customerId}/notifications/{id}` (`.claude/CUSTOMER-NOTIFICATIONS.md` §1).
///
/// Written by the app that sent the push (store, driver, provider, worker) or,
/// for a push without a `notificationId`, by this app when the push arrives
/// (`CustomerNotificationService.recordPush`). Reading never throws: a missing
/// or mistyped field reads as empty.
class CustomerNotificationModel {
  final String id;
  final String title;
  final String body;

  /// The template type or push data `type` (`store_accepted`, `orderChat`, ...).
  final String type;

  /// `order` | `chat` | `booking` | `account` | `other`.
  final String category;
  final String orderId;

  /// The order / booking status after the event, '' when unknown.
  final String status;

  /// The push data payload as sent; a tap is routed on it like a push tap.
  final Map<String, String> data;
  final bool read;

  /// Null while the server timestamp of a just-written document is pending.
  final DateTime? createdAt;

  /// `store` | `driver` | `provider` | `worker` | `customer`, '' when unknown.
  final String source;

  const CustomerNotificationModel({
    required this.id,
    this.title = '',
    this.body = '',
    this.type = '',
    this.category = 'other',
    this.orderId = '',
    this.status = '',
    this.data = const {},
    this.read = false,
    this.createdAt,
    this.source = '',
  });

  factory CustomerNotificationModel.fromMap(String docId, Map<String, dynamic>? map) {
    final Map<String, dynamic> m = map ?? const {};
    String text(String key) {
      final Object? v = m[key];
      if (v == null) return '';
      final String s = v.toString().trim();
      return s.toLowerCase() == 'null' ? '' : s;
    }

    final Object? rawData = m['data'];
    final Map<String, String> data = {};
    if (rawData is Map) {
      rawData.forEach((key, value) {
        if (value != null) data[key.toString()] = value.toString();
      });
    }
    final String id = text('id');
    final String category = text('category');
    return CustomerNotificationModel(
      id: docId.isNotEmpty ? docId : id,
      title: text('title'),
      body: text('body'),
      type: text('type'),
      category: category.isEmpty ? 'other' : category,
      orderId: text('orderId'),
      status: text('status'),
      data: data,
      read: m['read'] == true,
      createdAt: dateOf(m['createdAt']),
      source: text('source'),
    );
  }

  /// A Firestore `Timestamp`, a `DateTime` or epoch milliseconds; else null.
  static DateTime? dateOf(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  /// What a tap is routed on: the stored push data, completed with this
  /// document's `type` / `orderId` when the data lacks them (a sender that
  /// wrote the fields but not the payload).
  Map<String, dynamic> get routeData {
    final Map<String, dynamic> out = Map<String, dynamic>.from(data);
    if ((out['type']?.toString().trim() ?? '').isEmpty && type.isNotEmpty) out['type'] = type;
    if ((out['orderId']?.toString().trim() ?? '').isEmpty && orderId.isNotEmpty) out['orderId'] = orderId;
    return out;
  }
}

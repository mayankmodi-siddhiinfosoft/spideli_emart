import 'dart:convert';

import 'package:customer/models/customer_notification_model.dart';
import 'package:customer/utils/on_demand_push.dart';
import 'package:customer/utils/push_tap.dart';
import 'package:get/get.dart';

/// The pure parts of the customer Notification Center
/// (`.claude/CUSTOMER-NOTIFICATIONS.md` §1): which received pushes the app
/// records itself, under which id and category, and how a row's time reads.
/// No Firebase, so it is unit tested; the Firestore side is
/// `CustomerNotificationService`.
abstract final class CustomerNotificationRecord {
  static const String categoryOrder = 'order';
  static const String categoryChat = 'chat';
  static const String categoryBooking = 'booking';
  static const String categoryAccount = 'account';
  static const String categoryOther = 'other';

  /// Push `type`s of a chat message (to the customer).
  static const Set<String> chatTypes = {'orderchat', 'chat', 'admin_chat', 'adminchat', 'provider_chat'};

  /// Words of an order / ride / parcel / rental / dine-in event type
  /// (`restaurant_accepted`, `driver_completed`, `parcel_accepted`,
  /// `dinein_canceled`, `delivery_otp`, ...).
  static const List<String> _orderWords = [
    'order',
    'accept',
    'reject',
    'cancel',
    'complet',
    'placed',
    'dinein',
    'ride',
    'parcel',
    'rental',
    'takeaway',
    'deliver',
    'pickup',
    'picked',
    'ship',
    'transit',
    'arriv',
    'driver',
    'restaurant',
    'store',
    'otp',
  ];

  /// Words of an account alert (wallet, referral, gift card, subscription).
  static const List<String> _accountWords = ['wallet', 'account', 'refer', 'gift', 'cashback', 'subscription', 'payout', 'password', 'profile'];

  /// A push needs recording by this app only when its sender did not record
  /// it already (its data carries no `notificationId`).
  static bool needsFallback(Map<String, dynamic> data) => PushTap.field(data, 'notificationId').isEmpty;

  /// The document id of a push this app records: `msg_<FCM messageId>`, so
  /// the foreground, background and opened-app handlers all write the same
  /// document. Without a message id: `msg_h<hash of type, orderId, sentTime>`
  /// (title and body join in when the sent time is missing too).
  static String fallbackId({String? messageId, Map<String, dynamic> data = const {}, DateTime? sentTime, String? title, String? body}) {
    final String mid = (messageId ?? '').trim();
    if (mid.isNotEmpty) return 'msg_${_safeIdPart(mid)}';
    final String seed = [
      PushTap.field(data, 'type'),
      orderIdOf(data),
      sentTime?.millisecondsSinceEpoch.toString() ?? '',
      if (sentTime == null) ...[title ?? '', body ?? ''],
    ].join('|');
    return 'msg_h${fnv1a(seed).toRadixString(16)}';
  }

  /// A Firestore document id never contains '/', and `.` / `..` are reserved.
  static String _safeIdPart(String s) {
    final String out = s.replaceAll('/', '_');
    return (out == '.' || out == '..') ? '_' : out;
  }

  /// 32-bit FNV-1a: stable across runs and isolates (`String.hashCode` is not
  /// guaranteed to be).
  static int fnv1a(String s) {
    int hash = 0x811c9dc5;
    for (final int byte in utf8.encode(s)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  /// The order / booking id of a push payload, '' when it has none.
  static String orderIdOf(Map<String, dynamic> data) {
    for (final String key in const ['orderId', 'order_id', 'orderID']) {
      final String v = PushTap.field(data, key);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  /// `order` | `chat` | `booking` | `account` | `other`, from the push type.
  static String categoryOf(Map<String, dynamic> data) {
    final String type = PushTap.field(data, 'type').toLowerCase();
    if (chatTypes.contains(type) || type.contains('chat')) return categoryChat;
    // Before the order words: `provider_order` and `booking_placed` are bookings.
    if (OnDemandPush.isOnDemand(data) || type.contains('booking') || type.contains('provider') || type.contains('service')) return categoryBooking;
    if (_orderWords.any(type.contains)) return categoryOrder;
    if (_accountWords.any(type.contains)) return categoryAccount;
    if (orderIdOf(data).isNotEmpty) return categoryOrder;
    return categoryOther;
  }

  /// `source` of a document this app records on receipt (contract §1): the
  /// sender's role, when the push said, stays in `data.senderRole`.
  static const String sourceCustomer = 'customer';

  /// The push data as stored: string values only, nulls dropped, maps and
  /// lists JSON-encoded.
  static Map<String, String> stringData(Map<String, dynamic> data) {
    final Map<String, String> out = {};
    data.forEach((key, value) {
      if (value == null) return;
      if (value is Map || value is List) {
        try {
          out[key] = jsonEncode(value);
        } catch (_) {
          out[key] = value.toString();
        }
        return;
      }
      out[key] = value.toString();
    });
    return out;
  }

  /// The document this app writes for a received push (contract §1 fields).
  /// [createdAt] is `FieldValue.serverTimestamp()` in the app.
  static Map<String, dynamic> document({
    required String id,
    required String? title,
    required String? body,
    required Map<String, dynamic> data,
    required Object createdAt,
  }) {
    return {
      'id': id,
      'title': (title ?? '').trim(),
      'body': (body ?? '').trim(),
      'type': PushTap.field(data, 'type'),
      'category': categoryOf(data),
      'orderId': orderIdOf(data),
      'status': PushTap.field(data, 'status'),
      'data': stringData(data),
      'read': false,
      'createdAt': createdAt,
      'source': sourceCustomer,
    };
  }

  /// Ids the Notification Center marks read now: the unread ones on screen
  /// that were not marked during this visit already.
  static List<String> idsToMarkRead(Iterable<CustomerNotificationModel> shown, Set<String> alreadyMarked) {
    return [
      for (final n in shown)
        if (!n.read && n.id.isNotEmpty && !alreadyMarked.contains(n.id)) n.id,
    ];
  }

  /// A row's relative time: "Just now", "5 min ago", "3 h ago", "Yesterday",
  /// else '' (the row shows the date only).
  static String relativeTime(DateTime? at, DateTime now) {
    if (at == null) return 'Just now'.tr;
    final Duration age = now.difference(at);
    if (age.inMinutes < 1) return 'Just now'.tr;
    if (age.inMinutes < 60) return '@n min ago'.trParams({'n': '${age.inMinutes}'});
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(at.year, at.month, at.day);
    if (!day.isBefore(today)) return '@n h ago'.trParams({'n': '${age.inHours}'});
    if (today.difference(day).inDays == 1) return 'Yesterday'.tr;
    return '';
  }

  /// The icon key of a category ([categoryOther] for anything unknown).
  static String normalizeCategory(String category) {
    const Set<String> all = {categoryOrder, categoryChat, categoryBooking, categoryAccount, categoryOther};
    final String c = category.trim().toLowerCase();
    return all.contains(c) ? c : categoryOther;
  }
}

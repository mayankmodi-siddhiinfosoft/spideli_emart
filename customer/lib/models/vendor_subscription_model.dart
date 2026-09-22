import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:intl/intl.dart';

/// Store-sold subscriptions (spec 4.7 / 7.9, APP-DEV-BRIEF Part B): a customer
/// pays a store for e.g. a daily bread delivery. Three collections, none of
/// them touching the platform plan fields on `users` (subscriptionPlanId /
/// subscription_plan / subscriptionExpiryDate belong to the full-history plan).
///
/// Mirrors the Store app's `vendor_subscription_*` models so both apps read
/// the same documents the same way.

/// Tolerant timestamp parser for data written by other clients.
Timestamp? parseSubscriptionTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value;
  if (value is DateTime) return Timestamp.fromDate(value);
  if (value is int) return Timestamp.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    return parsed == null ? null : Timestamp.fromDate(parsed);
  }
  if (value is Map) {
    final seconds = value['_seconds'] ?? value['seconds'];
    if (seconds is int) return Timestamp(seconds, (value['_nanoseconds'] ?? value['nanoseconds'] ?? 0) as int);
  }
  return null;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// `vendor_subscription_plans/{id}` - written by the store.
class VendorSubscriptionPlanModel {
  static const String frequencyDaily = "daily";
  static const String frequencyWeekly = "weekly";
  static const List<String> weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

  /// The document exactly as read, so the snapshot written on purchase keeps
  /// every field the store panel stored (including ones this app ignores).
  Map<String, dynamic> raw = {};

  String? id;
  String? vendorID;
  String? regionId;
  String? sectionId;
  String? title;
  String? description;
  String? photo;
  String? price;
  String? expiryDay;
  bool? isEnable;
  List<VendorSubscriptionPlanItem> items = [];
  String? frequency;
  List<String> deliveryDays = [];
  VendorSubscriptionTimeSlot? timeSlot;

  VendorSubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    raw = Map<String, dynamic>.from(json);
    id = json['id']?.toString();
    vendorID = json['vendorID']?.toString();
    regionId = (json['regionId'] == null || json['regionId'].toString().isEmpty) ? null : json['regionId'].toString();
    sectionId = json['sectionId']?.toString();
    title = json['title']?.toString();
    description = json['description']?.toString();
    photo = json['photo']?.toString();
    price = json['price']?.toString();
    expiryDay = json['expiryDay']?.toString();
    isEnable = json['isEnable'] is bool ? json['isEnable'] : json['isEnable']?.toString() == 'true';
    if (json['items'] is List) {
      items = (json['items'] as List)
          .whereType<Map>()
          .map((e) => VendorSubscriptionPlanItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => (e.name ?? '').trim().isNotEmpty)
          .toList();
    }
    final freq = json['frequency']?.toString().trim().toLowerCase();
    frequency = (freq == frequencyDaily || freq == frequencyWeekly) ? freq : null;
    if (json['deliveryDays'] is List) {
      final days = <String>{};
      for (final d in json['deliveryDays'] as List) {
        final canonical = canonicalWeekday(d);
        if (canonical != null) days.add(canonical);
      }
      deliveryDays = weekdays.where(days.contains).toList();
    }
    timeSlot = json['timeSlot'] is Map ? VendorSubscriptionTimeSlot.fromJson(Map<String, dynamic>.from(json['timeSlot'])) : null;
  }

  /// Full snapshot for `vendor_subscriptions.plan`: every stored field, with
  /// the id always set.
  Map<String, dynamic> snapshot() => {...raw, 'id': id};

  int get expiryDays => int.tryParse(expiryDay ?? '') ?? 0;

  double get priceValue => double.tryParse(price ?? '') ?? 0;

  /// Same rule as the Store app: a daily plan with no stored days = every
  /// day; a weekly plan uses its first day.
  List<String> get effectiveDeliveryDays {
    if (deliveryDays.isNotEmpty) return frequency == frequencyWeekly ? [deliveryDays.first] : deliveryDays;
    if (frequency == frequencyDaily) return List<String>.from(weekdays);
    return [];
  }

  bool get hasSchedule => effectiveDeliveryDays.isNotEmpty;

  bool deliversOn(DateTime date) => effectiveDeliveryDays.contains(weekdays[date.weekday - 1]);

  static String? canonicalWeekday(dynamic value) {
    if (value == null) return null;
    if (value is int) return value >= 1 && value <= 7 ? weekdays[value - 1] : null;
    final s = value.toString().trim().toLowerCase();
    if (s.isEmpty) return null;
    final asInt = int.tryParse(s);
    if (asInt != null) return asInt >= 1 && asInt <= 7 ? weekdays[asInt - 1] : null;
    for (final d in weekdays) {
      if (d.toLowerCase() == s || (s.length >= 3 && d.toLowerCase().startsWith(s))) return d;
    }
    return null;
  }
}

class VendorSubscriptionPlanItem {
  String? name;
  String? quantity;

  VendorSubscriptionPlanItem.fromJson(Map<String, dynamic> json) {
    name = json['name']?.toString();
    quantity = json['quantity']?.toString();
  }
}

class VendorSubscriptionTimeSlot {
  String? from;
  String? to;

  VendorSubscriptionTimeSlot.fromJson(Map<String, dynamic> json) {
    from = json['from']?.toString();
    to = json['to']?.toString();
  }

  bool get isSet => (from ?? '').isNotEmpty && (to ?? '').isNotEmpty;

  String get label => isSet ? "$from - $to" : '';
}

/// `vendor_subscriptions/{id}` - written by this app on purchase; the
/// customer can pause, skip a day or cancel it.
class VendorSubscriptionModel {
  static const String statusActive = "active";
  static const String statusPaused = "paused";
  static const String statusCancelled = "cancelled";
  static const String statusExpired = "expired";

  /// `skippedDates` entries are local calendar days in this format.
  static final DateFormat dayFormat = DateFormat('yyyy-MM-dd');

  String? id;
  String? planId;
  String? vendorID;
  String? customerId;
  VendorSubscriptionPlanModel? plan;
  Timestamp? startDate;
  Timestamp? expiryDate;
  String? status;
  String? regionId;
  dynamic deliveryAddress;
  Timestamp? pausedFrom;
  Timestamp? pausedUntil;
  List<String> skippedDates = [];
  Timestamp? cancelledAt;
  bool? autoRenew;
  Timestamp? createdAt;

  VendorSubscriptionModel.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    planId = json['planId']?.toString();
    vendorID = json['vendorID']?.toString();
    customerId = json['customerId']?.toString();
    plan = json['plan'] is Map ? VendorSubscriptionPlanModel.fromJson(Map<String, dynamic>.from(json['plan'])) : null;
    startDate = parseSubscriptionTimestamp(json['startDate']);
    expiryDate = parseSubscriptionTimestamp(json['expiryDate']);
    status = json['status']?.toString();
    regionId = (json['regionId'] == null || json['regionId'].toString().isEmpty) ? null : json['regionId'].toString();
    deliveryAddress = json['deliveryAddress'] ?? json['address'];
    pausedFrom = parseSubscriptionTimestamp(json['pausedFrom']);
    pausedUntil = parseSubscriptionTimestamp(json['pausedUntil']);
    if (json['skippedDates'] is List) skippedDates = (json['skippedDates'] as List).map((e) => e.toString()).toList();
    cancelledAt = parseSubscriptionTimestamp(json['cancelledAt']);
    autoRenew = json['autoRenew'] is bool ? json['autoRenew'] : null;
    createdAt = parseSubscriptionTimestamp(json['createdAt']);
  }

  String get effectivePlanId => (planId ?? '').isNotEmpty ? planId! : (plan?.id ?? '');

  /// Nothing expires subscriptions server-side: a past expiryDate reads as
  /// expired whatever the stored status. A pause whose `pausedUntil` has
  /// passed reads as active again.
  String get effectiveStatus {
    final stored = (status ?? '').toLowerCase();
    if (stored == statusCancelled) return statusCancelled;
    if (expiryDate != null && expiryDate!.toDate().isBefore(DateTime.now())) return statusExpired;
    if (stored == statusPaused) {
      if (pausedUntil != null && _day(pausedUntil!.toDate()).isBefore(_day(DateTime.now()))) return statusActive;
      return statusPaused;
    }
    if (stored.isEmpty) return statusActive;
    return stored;
  }

  /// Paused on [day]: between `pausedFrom` and `pausedUntil` (inclusive,
  /// open-ended when either is absent).
  bool isPausedOn(DateTime day) {
    if ((status ?? '').toLowerCase() != statusPaused) return false;
    final d = _day(day);
    if (pausedFrom != null && d.isBefore(_day(pausedFrom!.toDate()))) return false;
    if (pausedUntil != null && d.isAfter(_day(pausedUntil!.toDate()))) return false;
    return true;
  }

  bool isSkipped(DateTime day) => skippedDates.contains(dayFormat.format(day));

  String get deliveryAddressText {
    final value = deliveryAddress;
    if (value is String) return value;
    if (value is Map) {
      return [value['address'], value['locality'], value['landmark']].map((e) => e?.toString().trim() ?? '').where((e) => e.isNotEmpty).join(', ');
    }
    return '';
  }

  /// The next delivery day from today (skips paused and skipped days), or
  /// null when the plan has no schedule or nothing is left before expiry.
  DateTime? nextDeliveryDay({int searchDays = 60}) {
    final p = plan;
    if (p == null || !p.hasSchedule) return null;
    final status = effectiveStatus;
    if (status == statusCancelled || status == statusExpired) return null;
    DateTime d = _day(DateTime.now());
    final start = startDate == null ? null : _day(startDate!.toDate());
    if (start != null && start.isAfter(d)) d = start;
    for (int i = 0; i < searchDays; i++) {
      final day = DateTime(d.year, d.month, d.day + i);
      if (expiryDate != null && !expiryDate!.toDate().isAfter(day)) return null;
      if (p.deliversOn(day) && !isPausedOn(day) && !isSkipped(day)) return day;
    }
    return null;
  }
}

/// `vendor_subscription_payments/{id}` - written by this app on purchase,
/// with the commission computed and stored at payment time.
class VendorSubscriptionPaymentModel {
  String? id;
  String? subscriptionId;
  String? planId;
  String? vendorID;
  String? customerId;
  String? amount;
  String? adminCommission;
  String? adminCommissionType;
  String? vendorEarning;
  String? paymentMethod;
  String? status;
  String? regionId;
  Timestamp? createdAt;

  VendorSubscriptionPaymentModel.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    subscriptionId = json['subscriptionId']?.toString();
    planId = json['planId']?.toString();
    vendorID = json['vendorID']?.toString();
    customerId = json['customerId']?.toString();
    amount = json['amount']?.toString();
    adminCommission = json['adminCommission']?.toString();
    adminCommissionType = json['adminCommissionType']?.toString();
    vendorEarning = json['vendorEarning']?.toString();
    paymentMethod = json['payment_method']?.toString();
    status = json['status']?.toString();
    regionId = (json['regionId'] == null || json['regionId'].toString().isEmpty) ? null : json['regionId'].toString();
    createdAt = parseSubscriptionTimestamp(json['createdAt']);
  }
}

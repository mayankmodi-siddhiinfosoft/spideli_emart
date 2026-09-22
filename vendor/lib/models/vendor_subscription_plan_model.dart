import 'package:cloud_firestore/cloud_firestore.dart';

/// A plan a store sells to its OWN customers ("Customer Subscriptions").
/// Stored in `vendor_subscription_plans`. Not to be confused with the platform
/// subscription plans in `subscription_plans` (SubscriptionPlanModel).
///
/// Delivery schedule fields (`items`, `frequency`, `deliveryDays`, `timeSlot`)
/// are optional: plans created before they existed parse with them empty and
/// keep working everywhere; [hasSchedule] tells the two apart.
class VendorSubscriptionPlanModel {
  static const String frequencyDaily = "daily";
  static const String frequencyWeekly = "weekly";

  /// Canonical weekday names as stored in `deliveryDays`, indexed like
  /// `DateTime.weekday - 1` (Monday first).
  static const List<String> weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

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
  Timestamp? createdAt;

  /// What one delivery contains.
  List<VendorSubscriptionPlanItem> items = [];

  /// `daily` | `weekly`; null for plans without a schedule.
  String? frequency;

  /// Canonical weekday names (see [weekdays]), Monday-first order.
  List<String> deliveryDays = [];

  VendorSubscriptionTimeSlot? timeSlot;

  VendorSubscriptionPlanModel({
    this.id,
    this.vendorID,
    this.regionId,
    this.sectionId,
    this.title,
    this.description,
    this.photo,
    this.price,
    this.expiryDay,
    this.isEnable,
    this.createdAt,
    List<VendorSubscriptionPlanItem>? items,
    this.frequency,
    List<String>? deliveryDays,
    this.timeSlot,
  })  : items = items ?? [],
        deliveryDays = deliveryDays ?? [];

  VendorSubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    vendorID = json['vendorID']?.toString();
    regionId = json['regionId']?.toString();
    sectionId = json['sectionId']?.toString();
    title = json['title']?.toString();
    description = json['description']?.toString();
    photo = json['photo']?.toString();
    price = json['price']?.toString();
    expiryDay = json['expiryDay']?.toString();
    isEnable = json['isEnable'] is bool ? json['isEnable'] : json['isEnable']?.toString() == 'true';
    createdAt = parseSubscriptionTimestamp(json['createdAt']);

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

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'id': id,
      'vendorID': vendorID,
      'regionId': regionId,
      'sectionId': sectionId,
      'title': title,
      'description': description,
      'photo': photo,
      'price': price,
      'expiryDay': expiryDay,
      'isEnable': isEnable ?? true,
      'createdAt': createdAt,
    };
    // Schedule fields are written only when set, so an unscheduled plan's
    // document keeps its original shape.
    if (items.isNotEmpty) data['items'] = items.map((e) => e.toJson()).toList();
    if (frequency != null) data['frequency'] = frequency;
    if (deliveryDays.isNotEmpty) data['deliveryDays'] = deliveryDays;
    if (timeSlot != null) data['timeSlot'] = timeSlot!.toJson();
    return data;
  }

  int get expiryDays => int.tryParse(expiryDay ?? '') ?? 0;

  /// The days this plan actually delivers on. A daily plan with no stored
  /// days means every day; a weekly plan uses its first day only; a plan with
  /// neither has no usable schedule.
  List<String> get effectiveDeliveryDays {
    if (deliveryDays.isNotEmpty) return frequency == frequencyWeekly ? [deliveryDays.first] : deliveryDays;
    if (frequency == frequencyDaily) return List<String>.from(weekdays);
    return [];
  }

  /// True when the plan carries a delivery schedule (newer plans).
  bool get hasSchedule => effectiveDeliveryDays.isNotEmpty;

  bool deliversOn(DateTime date) => effectiveDeliveryDays.contains(weekdays[date.weekday - 1]);

  /// Maps "monday", "Mon", "MONDAY" or 1..7 (ISO, Monday = 1) to a canonical name.
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

/// One line of what a delivery contains, e.g. `{name: "Baguette", quantity: "2"}`.
class VendorSubscriptionPlanItem {
  String? name;
  String? quantity;

  VendorSubscriptionPlanItem({this.name, this.quantity});

  VendorSubscriptionPlanItem.fromJson(Map<String, dynamic> json) {
    name = json['name']?.toString();
    quantity = json['quantity']?.toString();
  }

  Map<String, dynamic> toJson() => {'name': name, 'quantity': quantity};

  /// Tolerates numbers or numeric strings from other clients; 0 when unparseable.
  double get quantityValue => double.tryParse((quantity ?? '').trim()) ?? 0;
}

/// Delivery window as 24h "HH:mm" strings, e.g. `{from: "07:00", to: "09:00"}`.
class VendorSubscriptionTimeSlot {
  String? from;
  String? to;

  VendorSubscriptionTimeSlot({this.from, this.to});

  VendorSubscriptionTimeSlot.fromJson(Map<String, dynamic> json) {
    from = json['from']?.toString();
    to = json['to']?.toString();
  }

  Map<String, dynamic> toJson() => {'from': from, 'to': to};

  bool get isSet => (from ?? '').isNotEmpty && (to ?? '').isNotEmpty;

  String get label => isSet ? "$from - $to" : '';

  /// Minutes since midnight for an "HH:mm" string; null when malformed.
  static int? minutesOf(String? hhmm) {
    final parts = (hhmm ?? '').trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return h * 60 + m;
  }
}

/// Tolerant timestamp parser for data written by other clients (Timestamp,
/// epoch milliseconds, ISO string, or a serialized {_seconds} map).
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor/models/vendor_subscription_plan_model.dart';

/// A customer's subscription to one of this store's plans.
/// Stored in `vendor_subscriptions`; written by the customer app, read-only here.
class VendorSubscriptionModel {
  /// "Expiring soon" window used by the Subscribers filters.
  static const int expiringSoonDays = 7;

  String? id;
  String? planId;
  String? vendorID;
  String? customerId;
  VendorSubscriptionPlanModel? plan;
  Timestamp? startDate;
  Timestamp? expiryDate;
  String? status;
  String? regionId;

  /// Optional delivery address written by the customer app: `deliveryAddress`
  /// (or `address`), as a plain string or a shipping-address map.
  String? deliveryAddress;

  VendorSubscriptionModel({this.id, this.planId, this.vendorID, this.customerId, this.plan, this.startDate, this.expiryDate, this.status, this.regionId, this.deliveryAddress});

  VendorSubscriptionModel.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    planId = json['planId']?.toString();
    vendorID = json['vendorID']?.toString();
    customerId = json['customerId']?.toString();
    plan = json['plan'] is Map ? VendorSubscriptionPlanModel.fromJson(Map<String, dynamic>.from(json['plan'])) : null;
    startDate = parseSubscriptionTimestamp(json['startDate']);
    expiryDate = parseSubscriptionTimestamp(json['expiryDate']);
    status = json['status']?.toString();
    regionId = json['regionId']?.toString();
    deliveryAddress = _parseAddress(json['deliveryAddress']) ?? _parseAddress(json['address']);
  }

  static String? _parseAddress(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    if (value is Map) {
      final parts = [value['address'], value['locality'], value['landmark']].map((e) => e?.toString().trim() ?? '').where((e) => e.isNotEmpty).toList();
      return parts.isEmpty ? null : parts.join(', ');
    }
    return null;
  }

  /// The plan id this subscription belongs to (top-level, else the snapshot's).
  String get effectivePlanId => (planId ?? '').isNotEmpty ? planId! : (plan?.id ?? '');

  /// Nothing expires subscriptions server-side, so a past expiryDate is treated
  /// as expired regardless of the stored status.
  String get effectiveStatus {
    final stored = (status ?? '').toLowerCase();
    if (stored == 'cancelled') return 'cancelled';
    if (expiryDate != null && expiryDate!.toDate().isBefore(DateTime.now())) return 'expired';
    if (stored.isEmpty) return 'active';
    return stored;
  }

  /// Calendar days from today to the expiry date (negative once past);
  /// null when there is no expiry date.
  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    final now = DateTime.now();
    final expiry = expiryDate!.toDate();
    return DateTime(expiry.year, expiry.month, expiry.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// Active and ending within [expiringSoonDays] days.
  bool get isExpiringSoon {
    final days = daysUntilExpiry;
    return effectiveStatus == 'active' && days != null && days <= expiringSoonDays;
  }

  /// Whether the subscription was running on [day] (local calendar day): not
  /// cancelled (nor an unpaid `pending` / `failed`), started before the day
  /// ends and not expired before it began. A stored `expired` status is fine
  /// here - the dates decide, so past days can still be viewed.
  bool isActiveOn(DateTime day) {
    final stored = (status ?? '').toLowerCase();
    if (stored == 'cancelled' || stored == 'pending' || stored == 'failed') return false;
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    if (startDate != null && !startDate!.toDate().isBefore(dayEnd)) return false;
    if (expiryDate != null && !expiryDate!.toDate().isAfter(dayStart)) return false;
    return true;
  }
}

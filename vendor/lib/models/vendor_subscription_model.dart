import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor/models/vendor_subscription_plan_model.dart';

/// A customer's subscription to one of this store's plans.
/// Stored in `vendor_subscriptions`; written by the customer app, read-only here.
class VendorSubscriptionModel {
  String? id;
  String? planId;
  String? vendorID;
  String? customerId;
  VendorSubscriptionPlanModel? plan;
  Timestamp? startDate;
  Timestamp? expiryDate;
  String? status;
  String? regionId;

  VendorSubscriptionModel({this.id, this.planId, this.vendorID, this.customerId, this.plan, this.startDate, this.expiryDate, this.status, this.regionId});

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
  }

  /// Nothing expires subscriptions server-side, so a past expiryDate is treated
  /// as expired regardless of the stored status.
  String get effectiveStatus {
    final stored = (status ?? '').toLowerCase();
    if (stored == 'cancelled') return 'cancelled';
    if (expiryDate != null && expiryDate!.toDate().isBefore(DateTime.now())) return 'expired';
    if (stored.isEmpty) return 'active';
    return stored;
  }
}

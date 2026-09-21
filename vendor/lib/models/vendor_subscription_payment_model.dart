import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor/models/vendor_subscription_plan_model.dart';

/// A payment a customer made for a store's customer subscription.
/// Stored in `vendor_subscription_payments`; read-only here. The commission and
/// earning values are stored at payment time and must be displayed as-is.
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

  VendorSubscriptionPaymentModel({
    this.id,
    this.subscriptionId,
    this.planId,
    this.vendorID,
    this.customerId,
    this.amount,
    this.adminCommission,
    this.adminCommissionType,
    this.vendorEarning,
    this.paymentMethod,
    this.status,
    this.regionId,
    this.createdAt,
  });

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
    regionId = json['regionId']?.toString();
    createdAt = parseSubscriptionTimestamp(json['createdAt']);
  }
}

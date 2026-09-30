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
    // `payment_method` is the stored name (STORE spec 4); the camelCase spelling
    // is tolerated on read so a payment written that way is not shown blank.
    paymentMethod = (json['payment_method'] ?? json['paymentMethod'])?.toString();
    status = json['status']?.toString();
    regionId = json['regionId']?.toString();
    createdAt = parseSubscriptionTimestamp(json['createdAt']);
  }

  double get amountValue => double.tryParse(amount?.trim() ?? '') ?? 0;

  /// The platform's cut as recorded on the payment. **It is deducted from the
  /// price, not added on top** (STORE spec 4), so it can never be more than the
  /// amount: a fixed cut larger than a cheap plan is capped at the price rather
  /// than handing the store a negative earning.
  double get commissionValue {
    final double stored = double.tryParse(adminCommission?.trim() ?? '') ?? 0;
    if (stored <= 0) return 0;
    return amountValue > 0 && stored > amountValue ? amountValue : stored;
  }

  /// What the store earned: the STORED `vendorEarning` whenever the payment
  /// carries one (never recomputed - changing the platform's rate later must not
  /// rewrite an older payment). Only a payment written without it falls back to
  /// price minus the capped commission, which is the same subtraction the
  /// customer side does.
  double get earningValue {
    final String raw = vendorEarning?.trim() ?? '';
    final double? stored = double.tryParse(raw);
    if (raw.isNotEmpty && stored != null) return stored;
    return amountValue - commissionValue;
  }
}

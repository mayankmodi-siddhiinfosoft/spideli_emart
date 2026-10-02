import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor/models/cart_product_model.dart';
import 'package:vendor/models/cashback_model.dart';
import 'package:vendor/models/tax_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/cancellation.dart';
import 'package:vendor/utils/pod_otp.dart';

class OrderModel {
  ShippingAddress? address;
  String? status;
  String? couponId;
  String? vendorID;
  String? driverID;
  num? discount;
  String? authorID;
  String? estimatedTimeToPrepare;
  Timestamp? createdAt;
  Timestamp? triggerDelivery;
  String? paymentMethod;
  List<CartProductModel>? products;
  String? adminCommissionType;
  VendorModel? vendor;
  String? id;
  String? adminCommission;
  String? couponCode;
  String? sectionId;
  Map<String, dynamic>? specialDiscount;
  String? deliveryCharge;
  Timestamp? scheduleTime;
  String? tipAmount;
  String? notes;
  UserModel? author;
  UserModel? driver;
  bool? takeAway;
  List<dynamic>? rejectedByDrivers;
  CashbackModel? cashback;
  String? courierCompanyName;
  String? courierTrackingId;
  List<TaxModel>? taxSetting;
  List<TaxModel>? driverDeliveryTax;
  List<TaxModel>? packagingTax;
  List<TaxModel>? platformTax;
  String? taxScope;
  String? platformFee;
  bool? isPosOrder;
  bool? isFreeDelivery;
  bool? packagingChargeEnable;

  /// Region the order was placed in (inherited from the store by the customer
  /// app). Order amounts are shown in this region's currency.
  String? regionId;

  /// Why the order was cancelled or rejected, who did it and when — the
  /// shared contract (`.claude/CANCEL-REASON-CONTRACT.md`). [cancelReasonCode]
  /// is the list entry the reason was picked from, or "other" for free text;
  /// [cancelledBy] is "customer" | "vendor" | "driver" | "admin" (older store
  /// records may say "store" / "restaurant"); [cancelAction] is "cancelled" or
  /// "rejected". Read tolerantly, written only when set, so a later save of
  /// this order never clears what another actor recorded.
  String? cancelReason;
  String? cancelReasonCode;
  String? cancelledBy;
  String? cancelledByName;
  Timestamp? cancelledAt;
  String? cancelAction;

  /// Drivers who passed on this order's offer (`driverRejections`, written
  /// with arrayUnion by the driver app). Read only: the store never writes it
  /// back, so a stale copy can never overwrite a driver's newer entry.
  List<DriverRejection> driverRejections = const [];

  /// Set by [markEndedByVendor]: the next write stamps `cancelledAt` with the
  /// server's clock instead of this device's. Cleared once that write lands.
  bool stampCancelledAtOnServer = false;

  /// Proof of delivery by customer OTP (`.claude/POD-OTP-CONTRACT.md`): who
  /// verified the delivery code, who delivered and when. Null on every order
  /// from before the contract. Never holds the code itself.
  OrderPod? pod;

  OrderModel({
    this.address,
    this.status,
    this.couponId,
    this.vendorID,
    this.driverID,
    this.discount,
    this.authorID,
    this.estimatedTimeToPrepare,
    this.createdAt,
    this.triggerDelivery,
    this.paymentMethod,
    this.products,
    this.adminCommissionType,
    this.vendor,
    this.id,
    this.adminCommission,
    this.couponCode,
    this.sectionId,
    this.specialDiscount,
    this.deliveryCharge,
    this.scheduleTime,
    this.tipAmount,
    this.notes,
    this.author,
    this.driver,
    this.takeAway,
    this.rejectedByDrivers,
    this.cashback,
    this.courierCompanyName,
    this.courierTrackingId,
    this.taxSetting,
    this.driverDeliveryTax,
    this.packagingTax,
    this.platformTax,
    this.taxScope,
    this.platformFee,
    this.isPosOrder,
    this.isFreeDelivery,
    this.packagingChargeEnable,
    this.cancelReason,
    this.cancelReasonCode,
    this.cancelledBy,
    this.cancelledByName,
    this.cancelledAt,
    this.cancelAction,
    this.pod,
  });

  OrderModel.fromJson(Map<String, dynamic> json) {
    address = json['address'] != null ? ShippingAddress.fromJson(json['address']) : null;
    status = json['status'];
    couponId = json['couponId'];
    vendorID = json['vendorID'];
    driverID = json['driverID'];
    discount = json['discount'];
    authorID = json['authorID'];
    estimatedTimeToPrepare = json['estimatedTimeToPrepare'];
    createdAt = json['createdAt'];
    courierCompanyName = json['courierCompanyName'];
    courierTrackingId = json['courierTrackingId'];
    triggerDelivery = json['triggerDelevery'] ?? Timestamp.now();

    paymentMethod = json['payment_method'];
    if (json['products'] != null) {
      products = <CartProductModel>[];
      json['products'].forEach((v) {
        products!.add(CartProductModel.fromJson(v));
      });
    }
    adminCommissionType = json['adminCommissionType'];
    vendor = json['vendor'] != null ? VendorModel.fromJson(json['vendor']) : null;
    id = json['id'];
    adminCommission = json['adminCommission'];
    couponCode = json['couponCode'];
    sectionId = json['section_id'];
    specialDiscount = json['specialDiscount'];
    deliveryCharge = json['deliveryCharge'].toString().isEmpty ? "0.0" : json['deliveryCharge'] ?? '0.0';
    scheduleTime = json['scheduleTime'];
    tipAmount = json['tip_amount'].toString().isEmpty ? "0.0" : json['tip_amount'] ?? "0.0";
    notes = json['notes'];
    author = json['author'] != null ? UserModel.fromJson(json['author']) : null;
    driver = json['driver'] != null ? UserModel.fromJson(json['driver']) : null;
    takeAway = json['takeAway'];
    rejectedByDrivers = json['rejectedByDrivers'] ?? [];
    cashback = json['cashback'] != null ? CashbackModel.fromJson(json['cashback']) : null;
    if (json['taxSetting'] != null) {
      taxSetting = <TaxModel>[];
      json['taxSetting'].forEach((v) {
        taxSetting!.add(TaxModel.fromJson(v));
      });
    }
    if (json['platformTax'] != null) {
      platformTax = <TaxModel>[];
      json['platformTax'].forEach((v) {
        platformTax!.add(TaxModel.fromJson(v));
      });
    }
    if (json['packagingTax'] != null) {
      packagingTax = <TaxModel>[];
      json['packagingTax'].forEach((v) {
        packagingTax!.add(TaxModel.fromJson(v));
      });
    }

    if (json['driverDeliveryTax'] != null) {
      driverDeliveryTax = <TaxModel>[];
      json['driverDeliveryTax'].forEach((v) {
        driverDeliveryTax!.add(TaxModel.fromJson(v));
      });
    }
    taxScope = json['taxScope'];
    platformFee = json['platformFee'];
    regionId = json['regionId']?.toString();
    isFreeDelivery = json['isFreeDelivery'] ?? false;
    isPosOrder = json['isPosOrder'] ?? false;
    packagingChargeEnable = json['packagingChargeEnable'] ?? false;
    // Tolerant: older panels named the reason differently, and "null" written
    // as a string is no reason at all.
    cancelReason = firstText(json, const ['cancelReason', 'cancellationReason', 'cancel_reason', 'rejectReason', 'rejectionReason']);
    cancelReasonCode = firstText(json, const ['cancelReasonCode', 'cancel_reason_code']);
    cancelledBy = firstText(json, const ['cancelledBy', 'canceledBy', 'cancelled_by']);
    cancelledByName = firstText(json, const ['cancelledByName', 'canceledByName']);
    cancelledAt = parseTimestamp(json['cancelledAt'] ?? json['canceledAt']);
    cancelAction = firstText(json, const ['cancelAction']);
    driverRejections = DriverRejection.listFrom(json['driverRejections']);
    pod = OrderPod.fromJson(json['pod']);
  }

  /// Records that the store [action]ed this order ("cancelled" / "rejected")
  /// for [reason]. Only sets the fields; the caller writes them together with
  /// the status change in one [FireStoreUtils.updateOrder].
  void markEndedByVendor({required String action, required String reason, required String code, String? byName}) {
    cancelReason = reason;
    cancelReasonCode = code;
    cancelledBy = 'vendor';
    cancelledByName = isBlankText(byName) ? null : byName!.trim();
    cancelAction = action;
    // Shown at once; the stored value is the server's time.
    cancelledAt = Timestamp.now();
    stampCancelledAtOnServer = true;
  }

  /// The contract's block for this order, for the cards and details screen.
  CancellationDetails get cancellation => CancellationDetails.of(
    status: status,
    cancelAction: cancelAction,
    reason: cancelReason,
    cancelledBy: cancelledBy,
    cancelledByName: cancelledByName,
    cancelledAt: cancelledAt,
    driverRejections: driverRejections,
  );

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (address != null) {
      data['address'] = address!.toJson();
    }
    data['status'] = status;
    data['couponId'] = couponId;
    data['vendorID'] = vendorID;
    data['driverID'] = driverID;
    data['discount'] = discount;
    data['authorID'] = authorID;
    data['estimatedTimeToPrepare'] = estimatedTimeToPrepare;
    data['createdAt'] = createdAt;
    data['triggerDelivery'] = triggerDelivery;

    data['payment_method'] = paymentMethod;
    if (products != null) {
      data['products'] = products!.map((v) => v.toJson()).toList();
    }
    data['adminCommissionType'] = adminCommissionType;
    if (vendor != null) {
      data['vendor'] = vendor!.toJson();
    }
    data['id'] = id;
    data['adminCommission'] = adminCommission;
    data['couponCode'] = couponCode;
    data['section_id'] = sectionId;
    data['specialDiscount'] = specialDiscount;
    data['deliveryCharge'] = deliveryCharge;
    data['scheduleTime'] = scheduleTime;
    data['tip_amount'] = tipAmount;
    data['courierCompanyName'] = courierCompanyName;
    data['courierTrackingId'] = courierTrackingId;
    data['notes'] = notes;
    if (author != null) {
      data['author'] = author!.toJson();
    }
    if (driver != null) {
      data['driver'] = driver!.toJson();
    }
    data['takeAway'] = takeAway;
    // rejectedByDrivers / driverRejections are not written back: drivers add
    // to them with arrayUnion, and the store never changes them, so echoing a
    // copy read earlier could only drop a driver's newer entry.
    data['cashback'] = cashback?.toJson();
    if (taxSetting != null) {
      data['taxSetting'] = taxSetting!.map((v) => v.toJson()).toList();
    }
    if (platformTax != null) {
      data['platformTax'] = platformTax!.map((v) => v.toJson()).toList();
    }
    if (packagingTax != null) {
      data['packagingTax'] = packagingTax!.map((v) => v.toJson()).toList();
    }
    if (driverDeliveryTax != null) {
      data['driverDeliveryTax'] = driverDeliveryTax!.map((v) => v.toJson()).toList();
    }
    data['taxScope'] = taxScope;
    data['platformFee'] = platformFee;
    data['isFreeDelivery'] = isFreeDelivery ?? false;
    data['isPosOrder'] = isPosOrder ?? false;
    data['packagingChargeEnable'] = packagingChargeEnable ?? false;
    if (regionId != null) {
      data['regionId'] = regionId;
    }
    // Only written once the order has actually been cancelled, so a normal
    // order update never blanks a reason another actor recorded.
    if (cancelReason != null) data['cancelReason'] = cancelReason;
    if (cancelReasonCode != null) data['cancelReasonCode'] = cancelReasonCode;
    if (cancelledBy != null) data['cancelledBy'] = cancelledBy;
    if (cancelledByName != null) data['cancelledByName'] = cancelledByName;
    if (cancelAction != null) data['cancelAction'] = cancelAction;
    if (stampCancelledAtOnServer) {
      data['cancelledAt'] = FieldValue.serverTimestamp();
    } else if (cancelledAt != null) {
      data['cancelledAt'] = cancelledAt;
    }
    // Proof of delivery: never written from here, only by PodOtpService's
    // (and the Driver app's) transactions. updateOrder() replaces each field
    // it writes whole, so echoing an in-memory `pod` - pending when it was
    // read, or a partial verified copy - would roll back or strip what the
    // verification wrote. Leaving it out keeps whatever is stored.
    return data;
  }
}

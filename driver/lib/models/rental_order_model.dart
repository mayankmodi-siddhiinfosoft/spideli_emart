import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/models/rental_package_model.dart';
import 'package:driver/models/rental_vehicle_type.dart';
import 'package:driver/models/tax_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/vendor_model.dart';

class RentalOrderModel {
  String? status;
  List<dynamic>? rejectedByDrivers;
  String? couponId;
  Timestamp? bookingDateTime;
  bool? paymentStatus;
  String? discount;
  String? authorID;
  Timestamp? createdAt;
  String? adminCommissionType;
  String? sourceLocationName;
  List<TaxModel>? taxSetting;
  String? id;
  String? adminCommission;
  String? couponCode;
  String? sectionId;
  String? tipAmount;
  String? vehicleId;
  String? paymentMethod;
  RentalVehicleType? rentalVehicleType;
  RentalPackageModel? rentalPackageModel;
  String? otpCode;
  DestinationLocation? sourceLocation;
  UserModel? author;
  UserModel? driver;
  String? driverId;
  String? subTotal;
  Timestamp? startTime;
  Timestamp? endTime;
  String? startKitoMetersReading;
  String? endKitoMetersReading;
  String? zoneId;
  G? sourcePoint;
  String? platformFee;
  List<TaxModel>? platformTax;

  // ── Spideli additions (all optional; absent = today's behaviour) ──────────
  /// Region of the booking (the driver's region, spec 18.12).
  String? regionId;

  /// Customer price proposal (spec 4.9), kept raw so it round-trips:
  /// `{ amount, message, status, counterAmount, respondedBy, respondedAt, history }`.
  Map<String, dynamic>? priceProposal;

  /// Listed price kept when a proposal is accepted (read-only here; written
  /// once by RentalProposalService, never by a model save).
  String? listedPrice;

  String? cancelReason;
  String? cancelReasonCode;
  String? cancelledBy;
  Timestamp? cancelledAt;

  RentalOrderModel({
    this.status,
    this.rejectedByDrivers,
    this.bookingDateTime,
    this.paymentStatus,
    this.discount,
    this.authorID,
    this.createdAt,
    this.adminCommissionType,
    this.sourceLocationName,
    this.id,
    this.adminCommission,
    this.couponCode,
    this.couponId,
    this.sectionId,
    this.tipAmount,
    this.vehicleId,
    this.paymentMethod,
    this.rentalVehicleType,
    this.rentalPackageModel,
    this.otpCode,
    this.sourceLocation,
    this.author,
    this.subTotal,
    this.driver,
    this.driverId,
    this.startTime,
    this.endTime,
    this.startKitoMetersReading,
    this.endKitoMetersReading,
    this.zoneId,
    this.sourcePoint,
    this.platformFee,
    this.taxSetting,
    this.platformTax,
  });

  RentalOrderModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    rejectedByDrivers = json['rejectedByDrivers'] ?? [];
    couponId = json['couponId'];
    bookingDateTime = json['bookingDateTime'];
    paymentStatus = json['paymentStatus'];
    discount = json['discount'] == null ? "0.0" : json['discount'].toString();
    authorID = json['authorID'];
    createdAt = json['createdAt'];
    adminCommissionType = json['adminCommissionType'];
    sourceLocationName = json['sourceLocationName'];
    id = json['id'];
    adminCommission = json['adminCommission'];
    couponCode = json['couponCode'];
    sectionId = json['sectionId'];
    tipAmount = json['tip_amount'];
    vehicleId = json['vehicleId'];
    paymentMethod = json['paymentMethod'];
    rentalVehicleType = json['rentalVehicleType'] != null ? RentalVehicleType.fromJson(json['rentalVehicleType']) : null;
    rentalPackageModel = json['rentalPackageModel'] != null ? RentalPackageModel.fromJson(json['rentalPackageModel']) : null;
    otpCode = json['otpCode'];
    sourceLocation = json['sourceLocation'] != null ? DestinationLocation.fromJson(json['sourceLocation']) : null;
    author = json['author'] != null ? UserModel.fromJson(json['author']) : null;
    subTotal = json['subTotal'];
    driver = json['driver'] != null ? UserModel.fromJson(json['driver']) : null;
    driverId = json['driverId'];
    startTime = json['startTime'];
    endTime = json['endTime'];
    startKitoMetersReading = json['startKitoMetersReading'] ?? "0.0";
    endKitoMetersReading = json['endKitoMetersReading'] ?? "0.0";
    zoneId = json['zoneId'];
    sourcePoint = json['sourcePoint'] != null ? G.fromJson(json['sourcePoint']) : null;
    if (json['taxSetting'] != null) {
      taxSetting = <TaxModel>[];
      json['taxSetting'].forEach((v) {
        taxSetting!.add(TaxModel.fromJson(v));
      });
    }
    platformFee = json['platformFee'];
    if (json['platformTax'] != null) {
      platformTax = <TaxModel>[];
      json['platformTax'].forEach((v) {
        platformTax!.add(TaxModel.fromJson(v));
      });
    }
    regionId = json['regionId']?.toString();
    priceProposal = json['priceProposal'] is Map ? Map<String, dynamic>.from(json['priceProposal']) : null;
    listedPrice = json['listedPrice']?.toString();
    cancelReason = json['cancelReason']?.toString();
    cancelReasonCode = json['cancelReasonCode']?.toString();
    cancelledBy = json['cancelledBy']?.toString();
    cancelledAt = json['cancelledAt'] is Timestamp ? json['cancelledAt'] : null;
  }

  String? get proposalStatus => priceProposal?['status']?.toString();

  bool get hasPendingProposal => proposalStatus == 'pending';

  num? get proposedAmount => num.tryParse(priceProposal?['amount']?.toString() ?? '');

  num? get counterAmount => num.tryParse(priceProposal?['counterAmount']?.toString() ?? '');

  String? get proposalMessage => (priceProposal?['message']?.toString().isNotEmpty == true) ? priceProposal!['message'].toString() : null;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    if (rejectedByDrivers != null) {
      data['rejectedByDrivers'] = rejectedByDrivers;
    }
    data['couponId'] = couponId;
    data['bookingDateTime'] = bookingDateTime;
    data['paymentStatus'] = paymentStatus;
    data['discount'] = discount;
    data['authorID'] = authorID;
    data['createdAt'] = createdAt;
    data['adminCommissionType'] = adminCommissionType;
    data['sourceLocationName'] = sourceLocationName;
    if (taxSetting != null) {
      data['taxSetting'] = taxSetting!.map((v) => v.toJson()).toList();
    }
    data['id'] = id;
    data['adminCommission'] = adminCommission;
    data['couponCode'] = couponCode;
    data['sectionId'] = sectionId;
    data['tip_amount'] = tipAmount;
    data['vehicleId'] = vehicleId;
    data['paymentMethod'] = paymentMethod;
    data['driverId'] = driverId;
    if (driver != null) {
      data['driver'] = driver!.toJson();
    }

    if (rentalVehicleType != null) {
      data['rentalVehicleType'] = rentalVehicleType!.toJson();
    }

    if (rentalPackageModel != null) {
      data['rentalPackageModel'] = rentalPackageModel!.toJson();
    }
    data['otpCode'] = otpCode;
    if (sourceLocation != null) {
      data['sourceLocation'] = sourceLocation!.toJson();
    }
    if (author != null) {
      data['author'] = author!.toJson();
    }
    data['subTotal'] = subTotal;
    data['startTime'] = startTime;
    data['endTime'] = endTime;
    data['startKitoMetersReading'] = startKitoMetersReading;
    data['endKitoMetersReading'] = endKitoMetersReading;
    data['zoneId'] = zoneId;
    if (sourcePoint != null) {
      data['sourcePoint'] = sourcePoint!.toJson();
    }
    data['platformFee'] = platformFee;
    if (taxSetting != null) {
      data['taxSetting'] = taxSetting!.map((v) => v.toJson()).toList();
    }
    if (platformTax != null) {
      data['platformTax'] = platformTax!.map((v) => v.toJson()).toList();
    }
    // Additive fields: only written when known, so a save never clears them.
    if (regionId != null && regionId!.isNotEmpty) data['regionId'] = regionId;
    if (priceProposal != null) data['priceProposal'] = priceProposal;
    if (cancelReason != null) data['cancelReason'] = cancelReason;
    if (cancelReasonCode != null) data['cancelReasonCode'] = cancelReasonCode;
    if (cancelledBy != null) data['cancelledBy'] = cancelledBy;
    if (cancelledAt != null) data['cancelledAt'] = cancelledAt;
    return data;
  }
}

class DestinationLocation {
  double? longitude;
  double? latitude;

  DestinationLocation({this.longitude, this.latitude});

  DestinationLocation.fromJson(Map<String, dynamic> json) {
    longitude = json['longitude'];
    latitude = json['latitude'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['longitude'] = longitude;
    data['latitude'] = latitude;
    return data;
  }
}

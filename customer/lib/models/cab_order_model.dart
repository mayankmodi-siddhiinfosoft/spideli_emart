import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/tax_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vehicle_type.dart';

class CabOrderModel {
  /// Region the record belongs to (spec 18.12). History amounts use its
  /// currency; see `RegionService.currencyForRecord`.
  String? regionId;
  String? status;
  List<dynamic>? rejectedByDrivers;
  String? couponId;
  Timestamp? scheduleDateTime;
  String? duration;
  bool? roundTrip;
  bool? paymentStatus;
  String? discount;
  String? destinationLocationName;
  String? authorID;
  Timestamp? createdAt;
  DestinationLocation? destinationLocation;
  String? adminCommissionType;
  String? sourceLocationName;
  String? rideType;
  Timestamp? triggerDelevery;
  String? id;
  String? adminCommission;
  String? couponCode;
  Timestamp? scheduleReturnDateTime;
  String? sectionId;
  String? tipAmount;
  String? distance;
  String? vehicleId;
  String? paymentMethod;
  VehicleType? vehicleType;
  String? otpCode;
  DestinationLocation? sourceLocation;
  UserModel? author;
  UserModel? driver;
  String? driverId;
  String? subTotal;
  String? platformFee;
  List<TaxModel>? taxSetting;
  List<TaxModel>? platformTax;

  // --- CabCar extras (spec 4.8 / 7.10, APP-CONTRACT). All additive: absent =
  // today's behaviour. ---

  /// Intermediate stops between pickup and destination, kept raw:
  /// `{address, lat, lng, order, reached, reachedAt}`. The Driver app marks
  /// `reached` / `reachedAt`, so [toJson] never writes this field (a stale
  /// customer-side update must not undo a reached stop); the booking writes it
  /// once at creation (see `CabRideOptions.creationFields`).
  List<Map<String, dynamic>>? stops;

  /// `{ adults, children }`
  Map<String, dynamic>? passengers;

  /// Free text to the driver.
  String? instructions;

  /// The customer can only communicate in writing (driver should chat).
  bool? writtenCommunicationOnly;

  /// `{ name, phone, email }` when the ride is booked for someone else.
  Map<String, dynamic>? rideFor;

  /// Driver passes / cancellations (Driver app, APP-CONTRACT "CHANGED after
  /// review"): `[{driverId, reason, code, at, afterAccept}]`. Read only.
  List<Map<String, dynamic>>? driverRejections;

  // Final cancellation (by the customer). Written by a dedicated field
  // update, never by [toJson].
  String? cancelReason;
  String? cancelReasonCode;
  String? cancelledBy;
  Timestamp? cancelledAt;

  CabOrderModel({
    this.status,
    this.rejectedByDrivers,
    this.scheduleDateTime,
    this.duration,
    this.roundTrip,
    this.paymentStatus,
    this.discount,
    this.destinationLocationName,
    this.authorID,
    this.createdAt,
    this.destinationLocation,
    this.adminCommissionType,
    this.sourceLocationName,
    this.rideType,
    this.triggerDelevery,
    this.id,
    this.adminCommission,
    this.couponCode,
    this.couponId,
    this.scheduleReturnDateTime,
    this.sectionId,
    this.tipAmount,
    this.distance,
    this.vehicleId,
    this.paymentMethod,
    this.vehicleType,
    this.otpCode,
    this.sourceLocation,
    this.author,
    this.subTotal,
    this.driver,
    this.driverId,
    this.platformFee,
    this.taxSetting,
    this.platformTax,
  });

  CabOrderModel.fromJson(Map<String, dynamic> json) {
    regionId = (json['regionId'] == null || json['regionId'].toString().isEmpty) ? null : json['regionId'].toString();
    status = json['status'];
    rejectedByDrivers = json['rejectedByDrivers'] ?? [];
    couponId = json['couponId'];
    scheduleDateTime = json['scheduleDateTime'];
    duration = json['duration'];
    roundTrip = json['roundTrip'];
    paymentStatus = json['paymentStatus'];
    discount = json['discount'] == null ? "0.0" : json['discount'].toString();
    destinationLocationName = json['destinationLocationName'];
    authorID = json['authorID'];
    createdAt = json['createdAt'];
    destinationLocation = json['destinationLocation'] != null ? DestinationLocation.fromJson(json['destinationLocation']) : null;
    adminCommissionType = json['adminCommissionType'];
    sourceLocationName = json['sourceLocationName'];
    rideType = json['rideType'];
    triggerDelevery = json['trigger_delevery'];
    id = json['id'];
    adminCommission = json['adminCommission'];
    couponCode = json['couponCode'];
    scheduleReturnDateTime = json['scheduleReturnDateTime'];
    sectionId = json['sectionId'];
    tipAmount = json['tip_amount'];
    distance = json['distance'];
    vehicleId = json['vehicleId'];
    paymentMethod = json['paymentMethod'];
    vehicleType = json['vehicleType'] != null ? VehicleType.fromJson(json['vehicleType']) : null;
    otpCode = json['otpCode'];
    sourceLocation = json['sourceLocation'] != null ? DestinationLocation.fromJson(json['sourceLocation']) : null;
    author = json['author'] != null ? UserModel.fromJson(json['author']) : null;
    subTotal = json['subTotal'];
    driver = json['driver'] != null ? UserModel.fromJson(json['driver']) : null;
    driverId = json['driverId'];
    platformFee = json['platformFee'];
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
    if (json['stops'] is List) {
      stops = (json['stops'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    passengers = json['passengers'] is Map ? Map<String, dynamic>.from(json['passengers']) : null;
    instructions = json['instructions']?.toString();
    writtenCommunicationOnly = json['writtenCommunicationOnly'] is bool ? json['writtenCommunicationOnly'] : null;
    rideFor = json['rideFor'] is Map ? Map<String, dynamic>.from(json['rideFor']) : null;
    if (json['driverRejections'] is List) {
      driverRejections = (json['driverRejections'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    cancelReason = json['cancelReason']?.toString();
    cancelReasonCode = json['cancelReasonCode']?.toString();
    cancelledBy = json['cancelledBy']?.toString();
    cancelledAt = json['cancelledAt'] is Timestamp ? json['cancelledAt'] : null;
  }

  /// Stops sorted by their `order` key (falls back to list position).
  List<Map<String, dynamic>> get orderedStops {
    final list = List<Map<String, dynamic>>.from(stops ?? const []);
    final indexed = list.asMap().entries.toList()
      ..sort((a, b) => ((a.value['order'] as num?)?.toInt() ?? a.key).compareTo((b.value['order'] as num?)?.toInt() ?? b.key));
    return indexed.map((e) => e.value).toList();
  }

  int get adults => (passengers?['adults'] as num?)?.toInt() ?? 0;

  int get children => (passengers?['children'] as num?)?.toInt() ?? 0;

  bool get hasPassengers => passengers != null && (adults > 0 || children > 0);

  String? get riderName => (rideFor?['name']?.toString().isNotEmpty == true) ? rideFor!['name'].toString() : null;

  String? get riderPhone => (rideFor?['phone']?.toString().isNotEmpty == true) ? rideFor!['phone'].toString() : null;

  String? get riderEmail => (rideFor?['email']?.toString().isNotEmpty == true) ? rideFor!['email'].toString() : null;

  bool get isForSomeoneElse => rideFor != null && (riderName != null || riderPhone != null);

  /// The latest driver pass / cancellation, if any.
  Map<String, dynamic>? get lastDriverRejection => (driverRejections?.isNotEmpty ?? false) ? driverRejections!.last : null;

  /// The assigned driver cancelled after accepting and the ride went back to
  /// dispatch (not a final cancellation): `status == "Driver Rejected"` and
  /// the LAST `driverRejections` entry has `afterAccept == true`.
  bool get isDriverCancelledRedispatch => status == 'Driver Rejected' && lastDriverRejection?['afterAccept'] == true;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    // if (rejectedByDrivers != null) {
    //   data['rejectedByDrivers'] = rejectedByDrivers!.map((v) => v.toJson()).toList();
    // }
    if (rejectedByDrivers != null) {
      data['rejectedByDrivers'] = rejectedByDrivers;
    }
    data['couponId'] = couponId;
    data['scheduleDateTime'] = scheduleDateTime;
    data['duration'] = duration;
    data['roundTrip'] = roundTrip;
    data['paymentStatus'] = paymentStatus;
    data['discount'] = discount;
    data['destinationLocationName'] = destinationLocationName;
    data['authorID'] = authorID;
    data['createdAt'] = createdAt;
    if (destinationLocation != null) {
      data['destinationLocation'] = destinationLocation!.toJson();
    }
    data['adminCommissionType'] = adminCommissionType;
    data['sourceLocationName'] = sourceLocationName;
    data['rideType'] = rideType;
    data['trigger_delevery'] = triggerDelevery!;
    data['id'] = id;
    data['adminCommission'] = adminCommission;
    data['couponCode'] = couponCode;
    data['scheduleReturnDateTime'] = scheduleReturnDateTime;
    data['sectionId'] = sectionId;
    data['tip_amount'] = tipAmount;
    data['distance'] = distance;
    data['vehicleId'] = vehicleId;
    data['paymentMethod'] = paymentMethod;
    data['driverId'] = driverId;
    if (driver != null) {
      data['driver'] = driver!.toJson();
    }

    if (vehicleType != null) {
      data['vehicleType'] = vehicleType!.toJson();
    }
    data['otpCode'] = otpCode;
    if (sourceLocation != null) {
      data['sourceLocation'] = sourceLocation!.toJson();
    }
    if (author != null) {
      data['author'] = author!.toJson();
    }
    data['subTotal'] = subTotal;
    data['platformFee'] = platformFee;
    if (taxSetting != null) {
      data['taxSetting'] = taxSetting!.map((v) => v.toJson()).toList();
    }
    if (platformTax != null) {
      data['platformTax'] = platformTax!.map((v) => v.toJson()).toList();
    }
    if (regionId != null) data['regionId'] = regionId;
    // Customer-owned booking extras never change after creation, so rewriting
    // them is harmless. `stops` and the cancellation fields are deliberately
    // left out (see their docs).
    if (passengers != null) data['passengers'] = passengers;
    if (instructions != null) data['instructions'] = instructions;
    if (writtenCommunicationOnly != null) data['writtenCommunicationOnly'] = writtenCommunicationOnly;
    if (rideFor != null) data['rideFor'] = rideFor;
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

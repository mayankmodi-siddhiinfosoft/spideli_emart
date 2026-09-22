import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/models/tax_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/vendor_model.dart';

class ParcelOrderModel {
  /// Region the parcel order was charged in, when known.
  String? regionId;
  UserModel? author;
  UserModel? driver;

  LocationInformation? sender;
  Timestamp? senderPickupDateTime;
  String? id;
  String? driverId;

  UserLocation? receiverLatLong;
  bool? paymentCollectByReceiver;
  String? adminCommissionType;
  List<dynamic>? rejectedByDrivers;
  String? adminCommission;
  List<dynamic>? parcelImages;
  String? parcelWeight;
  String? discountType;
  String? discountLabel;
  LocationInformation? receiver;
  String? paymentMethod;
  String? distance;
  Timestamp? createdAt;
  bool? isSchedule;
  String? subTotal;
  Timestamp? triggerDelevery;
  String? status;
  String? parcelType;
  bool? sendToDriver;
  String? sectionId;
  UserLocation? senderLatLong;
  String? authorID;
  String? parcelWeightCharge;
  String? parcelCategoryID;
  String? discount;
  Timestamp? receiverPickupDateTime;
  String? note;
  String? receiverNote;
  String? senderZoneId;
  String? receiverZoneId;
  G? sourcePoint;
  G? destinationPoint;
  List<ParcelStatus>? statusHistory;
  String? platformFee;
  List<TaxModel>? taxSetting;
  List<TaxModel>? platformTax;

  // ── Parcel / mail contract (PARCEL-CONTRACT.md). Read-only in this model:
  // they are NOT written back by toJson(), so the merge writes of the
  // existing eMart flow never touch them. Writes go through
  // ParcelTrackingService as field updates.
  String? shipmentType;
  String? scope;
  Map<String, dynamic>? origin;
  Map<String, dynamic>? destination;
  String? trackingNumber;
  String? qrValue;
  String? pickupMethod;
  String? originPickupPointId;
  String? deliveryMethod;
  String? destinationPickupPointId;
  String? pickupCode;
  String? declaredValue;
  Map<String, dynamic>? dimensions;
  String? contentDescription;
  String? carrierId;
  String? carrierName;
  bool? quoteRequested;
  num? manualPrice;
  String? parcelStatus;
  List<ParcelTrackingEvent> trackingEvents = [];
  Map<String, dynamic>? deliveryProof;

  ParcelOrderModel({
    this.author,
    this.sender,
    this.senderPickupDateTime,
    this.id,
    this.driverId,
    this.receiverLatLong,
    this.paymentCollectByReceiver,
    this.adminCommissionType,
    this.rejectedByDrivers,
    this.adminCommission,
    this.parcelImages,
    this.parcelWeight,
    this.discountType,
    this.discountLabel,
    this.receiver,
    this.paymentMethod,
    this.distance,
    this.createdAt,
    this.isSchedule,
    this.subTotal,
    this.triggerDelevery,
    this.status,
    this.parcelType,
    this.sendToDriver,
    this.sectionId,
    this.senderLatLong,
    this.authorID,
    this.parcelWeightCharge,
    this.parcelCategoryID,
    this.discount,
    this.receiverPickupDateTime,
    this.note,
    this.receiverNote,
    this.senderZoneId,
    this.sourcePoint,
    this.destinationPoint,
    this.receiverZoneId,
    this.driver,
    this.statusHistory,
    this.platformFee,
    this.taxSetting,
    this.platformTax,
  });

  ParcelOrderModel.fromJson(Map<String, dynamic> json) {
    author = json['author'] != null ? UserModel.fromJson(json['author']) : null;
    driver = json['driver'] != null ? UserModel.fromJson(json['driver']) : null;
    sender = json['sender'] != null ? LocationInformation.fromJson(json['sender']) : null;
    senderPickupDateTime = json['senderPickupDateTime'];
    id = json['id'];
    driverId = json['driverId'];
    receiverLatLong = json['receiverLatLong'] != null ? UserLocation.fromJson(json['receiverLatLong']) : null;
    paymentCollectByReceiver = json['paymentCollectByReceiver'];
    adminCommissionType = json['adminCommissionType'];
    rejectedByDrivers = json['rejectedByDrivers'] ?? [];
    adminCommission = json['adminCommission'];
    parcelImages = json['parcelImages'] ?? [];
    parcelWeight = json['parcelWeight'];
    discountType = json['discountType'];
    discountLabel = json['discountLabel'];
    receiver = json['receiver'] != null ? LocationInformation.fromJson(json['receiver']) : null;
    paymentMethod = json['payment_method'];
    distance = json['distance'];
    createdAt = json['createdAt'];
    isSchedule = json['isSchedule'];
    subTotal = json['subTotal'];
    triggerDelevery = json['trigger_delevery'];
    status = json['status'];
    parcelType = json['parcelType'];
    sendToDriver = json['sendToDriver'];
    sectionId = json['sectionId'];
    senderLatLong = json['senderLatLong'] != null ? UserLocation.fromJson(json['senderLatLong']) : null;
    authorID = json['authorID'];
    parcelWeightCharge = json['parcelWeightCharge'];
    parcelCategoryID = json['parcelCategoryID'];
    discount = json['discount'];
    receiverPickupDateTime = json['receiverPickupDateTime'];
    note = json['note'];
    senderZoneId = json['senderZoneId'];
    receiverZoneId = json['receiverZoneId'];
    receiverNote = json['receiverNote'];
    sourcePoint = json['sourcePoint'] != null ? G.fromJson(json['sourcePoint']) : null;
    destinationPoint = json['destinationPoint'] != null ? G.fromJson(json['destinationPoint']) : null;
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
    regionId = json['regionId']?.toString();

    String? str(dynamic v) => v?.toString();
    Map<String, dynamic>? map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;
    shipmentType = str(json['shipmentType']);
    scope = str(json['scope']);
    origin = map(json['origin']);
    destination = map(json['destination']);
    trackingNumber = str(json['trackingNumber']);
    qrValue = str(json['qrValue']);
    pickupMethod = str(json['pickupMethod']);
    originPickupPointId = str(json['originPickupPointId']);
    deliveryMethod = str(json['deliveryMethod']);
    destinationPickupPointId = str(json['destinationPickupPointId']);
    pickupCode = str(json['pickupCode']);
    declaredValue = str(json['declaredValue']);
    dimensions = map(json['dimensions']);
    contentDescription = str(json['contentDescription']);
    carrierId = str(json['carrierId']);
    carrierName = str(json['carrierName']);
    quoteRequested = json['quoteRequested'] is bool ? json['quoteRequested'] as bool : null;
    manualPrice = json['manualPrice'] is num ? json['manualPrice'] as num : num.tryParse('${json['manualPrice']}');
    parcelStatus = str(json['parcelStatus']);
    deliveryProof = map(json['deliveryProof']);
    trackingEvents = [];
    if (json['trackingEvents'] is List) {
      for (final e in json['trackingEvents'] as List) {
        if (e is Map) trackingEvents.add(ParcelTrackingEvent.fromMap(Map<String, dynamic>.from(e)));
      }
    }
  }

  /// True when the order was created with the parcel/mail contract fields.
  bool get hasTrackingContract => parcelStatus != null || trackingNumber != null || qrValue != null;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (author != null) {
      data['author'] = author!.toJson();
    }
    if (driver != null) {
      data['driver'] = driver!.toJson();
    }
    if (sender != null) {
      data['sender'] = sender!.toJson();
    }
    data['senderPickupDateTime'] = senderPickupDateTime;
    data['id'] = id;
    if (receiverLatLong != null) {
      data['receiverLatLong'] = receiverLatLong!.toJson();
    }
    data['paymentCollectByReceiver'] = paymentCollectByReceiver;
    data['driverId'] = driverId;
    data['adminCommissionType'] = adminCommissionType;
    data['rejectedByDrivers'] = rejectedByDrivers;
    data['adminCommission'] = adminCommission;
    data['parcelImages'] = parcelImages;
    data['parcelWeight'] = parcelWeight;
    data['discountType'] = discountType;
    data['discountLabel'] = discountLabel;
    if (receiver != null) {
      data['receiver'] = receiver!.toJson();
    }
    data['payment_method'] = paymentMethod;
    data['distance'] = distance;
    data['createdAt'] = createdAt;
    data['isSchedule'] = isSchedule;
    data['subTotal'] = subTotal;
    data['trigger_delevery'] = triggerDelevery;
    data['status'] = status;
    data['parcelType'] = parcelType;
    data['sendToDriver'] = sendToDriver;
    data['sectionId'] = sectionId;
    if (senderLatLong != null) {
      data['senderLatLong'] = senderLatLong!.toJson();
    }
    if (sourcePoint != null) {
      data['sourcePoint'] = sourcePoint!.toJson();
    }
    if (destinationPoint != null) {
      data['destinationPoint'] = destinationPoint!.toJson();
    }
    data['authorID'] = authorID;
    data['parcelWeightCharge'] = parcelWeightCharge;
    data['parcelCategoryID'] = parcelCategoryID;
    data['discount'] = discount;
    data['receiverPickupDateTime'] = receiverPickupDateTime;
    data['note'] = note;
    data['senderZoneId'] = senderZoneId;
    data['receiverZoneId'] = receiverZoneId;
    data['receiverNote'] = receiverNote;
    data['platformFee'] = platformFee;
    if (taxSetting != null) {
      data['taxSetting'] = taxSetting!.map((v) => v.toJson()).toList();
    }
    if (platformTax != null) {
      data['platformTax'] = platformTax!.map((v) => v.toJson()).toList();
    }
    if (regionId != null && regionId!.isNotEmpty) data['regionId'] = regionId;

    return data;
  }
}

class LocationInformation {
  String? address;
  String? name;
  String? phone;
  String? email;

  LocationInformation({this.address, this.name, this.phone, this.email});

  LocationInformation.fromJson(Map<String, dynamic> json) {
    address = json['address'];
    name = json['name'];
    phone = json['phone'];
    email = json['email']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['address'] = address;
    data['name'] = name;
    data['phone'] = phone;
    if (email != null) data['email'] = email;
    return data;
  }
}

class ParcelStatus {
  final String? status;
  final DateTime? time;

  ParcelStatus({this.status, this.time});

  factory ParcelStatus.fromMap(Map<String, dynamic> map) {
    return ParcelStatus(status: map['status'] as String?, time: map['time'] != null ? (map['time'] as Timestamp).toDate() : null);
  }

  Map<String, dynamic> toMap() {
    return {'status': status, 'time': time != null ? Timestamp.fromDate(time!) : null};
  }
}

/// One entry of `parcel_orders.trackingEvents` (append-only, newest last).
class ParcelTrackingEvent {
  final String? status;
  final Timestamp? at;
  final String? by;
  final String? role;
  final String? pickupPointId;
  final String? note;
  final num? lat;
  final num? lng;

  ParcelTrackingEvent({this.status, this.at, this.by, this.role, this.pickupPointId, this.note, this.lat, this.lng});

  factory ParcelTrackingEvent.fromMap(Map<String, dynamic> map) {
    return ParcelTrackingEvent(
      status: map['status']?.toString(),
      at: map['at'] is Timestamp ? map['at'] as Timestamp : null,
      by: map['by']?.toString(),
      role: map['role']?.toString(),
      pickupPointId: map['pickupPointId']?.toString(),
      note: map['note']?.toString(),
      lat: map['lat'] is num ? map['lat'] as num : null,
      lng: map['lng'] is num ? map['lng'] as num : null,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/tax_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/utils/parcel_pricing.dart';

class ParcelOrderModel {
  /// Region the record belongs to (spec 18.12). History amounts use its
  /// currency; see `RegionService.currencyForRecord`.
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

  // ---- Parcel / mail shipping (PARCEL-CONTRACT). All additive: absent = the
  // legacy same-city parcel. Written by the customer app at creation only;
  // `parcelStatus`, `trackingEvents`, `manualPrice` and `deliveryProof` are
  // read here but never written back by [toJson] (drivers / operators / admin
  // append to them - see ParcelShippingService).
  String? shipmentType; // "parcel" | "mail"
  String? scope; // ParcelScope
  ParcelPlace? origin;
  ParcelPlace? destination;
  String? trackingNumber;
  String? qrValue;
  String? pickupMethod; // "home" | "pickup_point"
  String? originPickupPointId;
  String? deliveryMethod; // "home" | "pickup_point"
  String? destinationPickupPointId;
  String? pickupCode;
  String? declaredValue;
  Map<String, dynamic>? dimensions; // {l, w, h} cm
  String? contentDescription;
  num? weightKg;
  String? carrierId;
  String? carrierName;
  Map<String, dynamic>? priceBreakdown;

  /// Fixed intercity / intercountry tax (priceBreakdown.fixedTax): platform
  /// revenue charged on top of the payable total. Kept OUT of [subTotal] so
  /// VAT, % coupons, commission and the driver's credit never apply to it.
  num? parcelScopeTax;
  bool? quoteRequested;
  num? manualPrice;
  String? parcelStatus;
  List<ParcelTrackingEvent> trackingEvents = [];
  Map<String, dynamic>? deliveryProof;

  /// True for orders created by the shipping flow (tracking number present).
  bool get isTrackable => (trackingNumber ?? '').isNotEmpty;

  /// Same city, home to home, platform drivers: today's parcel.
  bool get isLegacyShape =>
      (scope ?? 'city') == 'city' && (pickupMethod ?? ParcelShipping.home) == ParcelShipping.home && (deliveryMethod ?? ParcelShipping.home) == ParcelShipping.home && carrierId == null && quoteRequested != true;

  /// Fixed scope tax added to the payable total (0 when none).
  double get scopeTaxAmount => (parcelScopeTax ?? 0).toDouble();

  /// Either leg goes through a pickup point: the sender pays, no cash.
  bool get usesPickupPoint => pickupMethod == ParcelShipping.pickupPoint || deliveryMethod == ParcelShipping.pickupPoint;

  /// Quote requested and the admin has not priced it yet.
  bool get awaitingQuote => quoteRequested == true && manualPrice == null;

  /// Quote priced by the admin and not paid yet.
  bool get quoteReadyToPay => quoteRequested == true && manualPrice != null && status == ParcelShipping.quoteRequestedStatus;

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
    regionId = (json['regionId'] == null || json['regionId'].toString().isEmpty) ? null : json['regionId'].toString();
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
    shipmentType = _str(json['shipmentType']);
    scope = _str(json['scope']);
    origin = json['origin'] is Map ? ParcelPlace.fromJson(json['origin']) : null;
    destination = json['destination'] is Map ? ParcelPlace.fromJson(json['destination']) : null;
    trackingNumber = _str(json['trackingNumber']);
    qrValue = _str(json['qrValue']);
    pickupMethod = _str(json['pickupMethod']);
    originPickupPointId = _str(json['originPickupPointId']);
    deliveryMethod = _str(json['deliveryMethod']);
    destinationPickupPointId = _str(json['destinationPickupPointId']);
    pickupCode = _str(json['pickupCode']);
    declaredValue = _str(json['declaredValue']);
    dimensions = json['dimensions'] is Map ? Map<String, dynamic>.from(json['dimensions']) : null;
    contentDescription = _str(json['contentDescription']);
    weightKg = json['weightKg'] is num ? json['weightKg'] : num.tryParse(json['weightKg']?.toString() ?? '');
    carrierId = _str(json['carrierId']);
    carrierName = _str(json['carrierName']);
    priceBreakdown = json['priceBreakdown'] is Map ? Map<String, dynamic>.from(json['priceBreakdown']) : null;
    parcelScopeTax = json['parcelScopeTax'] is num ? json['parcelScopeTax'] : num.tryParse(json['parcelScopeTax']?.toString() ?? '');
    quoteRequested = json['quoteRequested'] == true;
    manualPrice = json['manualPrice'] is num ? json['manualPrice'] : num.tryParse(json['manualPrice']?.toString() ?? '');
    parcelStatus = _str(json['parcelStatus']);
    trackingEvents = [];
    if (json['trackingEvents'] is List) {
      for (final e in json['trackingEvents']) {
        if (e is Map) trackingEvents.add(ParcelTrackingEvent.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    deliveryProof = json['deliveryProof'] is Map ? Map<String, dynamic>.from(json['deliveryProof']) : null;
  }

  static String? _str(dynamic v) => (v == null || v.toString().isEmpty) ? null : v.toString();

  /// The shipping fields written when the order is created (known-fields; nulls
  /// omitted so nothing panel/driver-written is ever cleared).
  Map<String, dynamic> shippingJson() {
    final Map<String, dynamic> data = {
      'shipmentType': shipmentType,
      'scope': scope,
      'origin': origin?.toJson(),
      'destination': destination?.toJson(),
      'trackingNumber': trackingNumber,
      'qrValue': qrValue,
      'pickupMethod': pickupMethod,
      'originPickupPointId': originPickupPointId,
      'deliveryMethod': deliveryMethod,
      'destinationPickupPointId': destinationPickupPointId,
      // The admin panel links a parcel to its point with a single
      // `pickupPointId` (admin spec §12): the origin point when there is one,
      // else the destination. Ours stay the truth for the app.
      'pickupPointId': originPickupPointId ?? destinationPickupPointId,
      'pickupCode': pickupCode,
      'declaredValue': declaredValue,
      'dimensions': dimensions,
      'contentDescription': contentDescription,
      'weightKg': weightKg,
      'carrierId': carrierId,
      'carrierName': carrierName,
      'priceBreakdown': priceBreakdown,
      'parcelScopeTax': parcelScopeTax,
      if (quoteRequested == true) 'quoteRequested': true,
    };
    data.removeWhere((key, value) => value == null);
    return data;
  }

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

    if (regionId != null) data['regionId'] = regionId;
    data.addAll(shippingJson());
    return data;
  }
}

/// Tracking statuses (spec 7.5) and method values of the shipping contract.
class ParcelShipping {
  ParcelShipping._();

  static const String created = 'Created';
  static const String paid = 'Paid';
  static const String waitingDropOff = 'Waiting drop-off';
  static const String collected = 'Collected';
  static const String atOriginPickupPoint = 'At origin pickup point';
  static const String inTransit = 'In transit';
  static const String arrivedDestination = 'Arrived destination';
  static const String atDestinationPickupPoint = 'At destination pickup point';
  static const String outForDelivery = 'Out for delivery';
  static const String delivered = 'Delivered';
  static const String returned = 'Returned';
  static const String cancelled = 'Cancelled';

  static const List<String> statuses = [created, paid, waitingDropOff, collected, atOriginPickupPoint, inTransit, arrivedDestination, atDestinationPickupPoint, outForDelivery, delivered, returned, cancelled];

  static const String home = 'home';
  static const String pickupPoint = 'pickup_point';
  static const String parcel = 'parcel';
  static const String mail = 'mail';

  /// eMart `status` of an unpriced quote request: not "Order Placed", so no
  /// driver is dispatched before the admin sets `manualPrice` and it is paid.
  static const String quoteRequestedStatus = 'Quote Requested';

  /// The parcel is still with the sender (not collected / dropped at the
  /// origin point yet): the only tracking statuses a customer may cancel at.
  static bool beforeHandOver(String? parcelStatus) => parcelStatus == null || parcelStatus.isEmpty || parcelStatus == created || parcelStatus == paid || parcelStatus == waitingDropOff;
}

/// One entry of `trackingEvents` (append-only, newest last).
class ParcelTrackingEvent {
  final String status;
  final Timestamp? at;
  final String? by;
  final String? role;
  final String? pickupPointId;
  final String? note;
  final double? lat;
  final double? lng;

  ParcelTrackingEvent({required this.status, this.at, this.by, this.role, this.pickupPointId, this.note, this.lat, this.lng});

  factory ParcelTrackingEvent.fromJson(Map<String, dynamic> json) {
    double? d(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    final dynamic at = json['at'];
    return ParcelTrackingEvent(
      status: (json['status'] ?? '').toString(),
      at: at is Timestamp ? at : (at is DateTime ? Timestamp.fromDate(at) : null),
      by: json['by']?.toString(),
      role: json['role']?.toString(),
      pickupPointId: (json['pickupPointId'] ?? '').toString().isEmpty ? null : json['pickupPointId'].toString(),
      note: (json['note'] ?? '').toString().isEmpty ? null : json['note'].toString(),
      lat: d(json['lat']),
      lng: d(json['lng']),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {'status': status, 'at': at ?? Timestamp.now(), 'by': by, 'role': role, 'pickupPointId': pickupPointId, 'note': note, 'lat': lat, 'lng': lng};
    data.removeWhere((key, value) => value == null);
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
    email = (json['email'] ?? '').toString().isEmpty ? null : json['email'].toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['address'] = address;
    data['name'] = name;
    data['phone'] = phone;
    if (email != null && email!.isNotEmpty) data['email'] = email;
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

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/constant.dart';
import 'package:driver/models/admin_commission.dart';
import 'package:driver/models/cab_order_model.dart';
import 'package:driver/models/subscription_plan_model.dart';
import 'package:driver/services/dispatch_offer_rules.dart';
import 'package:driver/utils/address_format.dart';

class UserModel {
  String? id;
  String? firstName;
  String? lastName;
  String? email;
  String? profilePictureURL;
  String? fcmToken;
  String? countryCode;
  String? countryISOCode;
  String? phoneNumber;
  num? walletAmount;
  bool? active;
  bool? isActive;
  bool? isDocumentVerify;
  Timestamp? createdAt;
  String? role;
  UserLocation? location;
  UserBankDetails? userBankDetails;
  /// Assigning it clears [shippingAddressUnreadable]: the list is then
  /// written as set.
  List<ShippingAddress>? get shippingAddress => _shippingAddress;
  set shippingAddress(List<ShippingAddress>? value) {
    _shippingAddress = value;
    _shippingAddressUnreadable = false;
  }

  List<ShippingAddress>? _shippingAddress;

  /// An entry of the stored `shippingAddress` did not parse and was left out
  /// of [shippingAddress]: the shortened list is never written back.
  bool get shippingAddressUnreadable => _shippingAddressUnreadable;
  bool _shippingAddressUnreadable = false;
  String? carPictureURL;
  List<dynamic>? inProgressOrderID;
  List<dynamic>? orderRequestData;
  String? vendorID;
  String? zoneId;

  /// A delivery company's zones (report Doc 43): several, chosen at
  /// registration / on the profile. [zoneId] stays the first of them for the
  /// readers of the single field. Absent on drivers and older companies.
  List<String>? zoneIds;
  num? rotation;
  String? appIdentifier;
  String? provider;
  String? subscriptionPlanId;
  Timestamp? subscriptionExpiryDate;
  SubscriptionPlanModel? subscriptionPlan;
  List<String>? serviceTypes;
  List<String>? sectionIds;
  Map<String, String>? sectionNames; // {sectionId: sectionName}
  Map<String, dynamic>? vehicleDetails; // {sectionId: {vehicleId, vehicleType, carBrand, carModel, carPlateNumber}}
  String? reviewsCount;
  String? reviewsSum;
  AdminCommission? adminCommissionModel;
  /// Assigning it (null included, to clear the offer) clears
  /// [cabRequestUnreadable].
  CabOrderModel? get orderCabRequestData => _orderCabRequestData;
  set orderCabRequestData(CabOrderModel? value) {
    _orderCabRequestData = value;
    _cabRequestUnreadable = false;
  }

  CabOrderModel? _orderCabRequestData;

  /// The stored `ordercabRequestData` is there but did not parse, so
  /// [orderCabRequestData] is null: [FireStoreUtils.updateUser] must not take
  /// that null for "no offer" and delete the driver's live ride offer.
  bool get cabRequestUnreadable => _cabRequestUnreadable;
  bool _cabRequestUnreadable = false;
  String? rideType;
  String? ownerId;
  bool? isOwner;
  bool? isAutoVerify;

  /// Management zone (spec 3.1 / 18.4). Absent = global settings.
  String? regionId;

  /// "individual" | "company" (spec 4.11). Absent = individual.
  String? driverType;

  /// `isCompany: true` — how older records mark a company (report §3 02#8).
  /// Read only, never written.
  bool? legacyIsCompany;

  /// The delivery carrier (`delivery_carriers/{id}`) this driver is registered
  /// under — admin spec §11. Read only; the panel owns it. Absent = the driver
  /// belongs to no carrier and sees platform work exactly as before.
  String? carrierId;

  /// Company identification (spec 4.11), additive on the user doc.
  String? companyName;

  /// Report Doc 38: the company's address, as typed at registration / on the
  /// profile. Never saved before, so absent on every older company.
  String? companyAddress;
  String? operatingLicence;
  String? commercialRegister;
  String? uniqueIdNumber;
  String? operatingLicenceFile;
  String? commercialRegisterFile;
  String? uniqueIdNumberFile;

  UserModel({
    this.id,
    this.firstName,
    this.lastName,
    this.active,
    this.isActive,
    this.isDocumentVerify,
    this.email,
    this.profilePictureURL,
    this.fcmToken,
    this.countryCode,
    this.countryISOCode,
    this.phoneNumber,
    this.walletAmount,
    this.createdAt,
    this.role,
    this.location,
    List<ShippingAddress>? shippingAddress,
    this.carPictureURL,
    this.inProgressOrderID,
    this.orderRequestData,
    this.vendorID,
    this.zoneId,
    this.zoneIds,
    this.rotation,
    this.appIdentifier,
    this.provider,
    this.subscriptionPlanId,
    this.subscriptionExpiryDate,
    this.subscriptionPlan,
    this.serviceTypes,
    this.sectionIds,
    this.sectionNames,
    this.vehicleDetails,
    this.reviewsCount,
    this.reviewsSum,
    this.adminCommissionModel,
    CabOrderModel? orderCabRequestData,
    this.rideType,
    this.ownerId,
    this.isOwner,
    this.isAutoVerify,
    this.regionId,
    this.driverType,
    this.companyName,
    this.companyAddress,
    this.operatingLicence,
    this.commercialRegister,
    this.uniqueIdNumber,
    this.operatingLicenceFile,
    this.commercialRegisterFile,
    this.uniqueIdNumberFile,
  }) {
    this.shippingAddress = shippingAddress;
    this.orderCabRequestData = orderCabRequestData;
  }

  String fullName() {
    return "${firstName ?? ''} ${lastName ?? ''}";
  }

  double get averageRating {
    final double sum = double.tryParse(reviewsSum ?? '0') ?? 0.0;
    final double count = double.tryParse(reviewsCount ?? '0') ?? 0.0;

    if (count <= 0) return 0.0;
    return sum / count;
  }

  /// Read tolerantly: driver documents are written by this app, the Store
  /// app and the admin panel, and a value of an unexpected type (a number
  /// stored as text, "true" for a bool, a malformed nested map) used to throw
  /// here. getUserProfile then returned null, so the driver was told the
  /// account "is not created in driver application" and signed out, or the
  /// splash screen never moved on.
  UserModel.fromJson(Map<String, dynamic> json) {
    id = _text(json['id']);
    email = _text(json['email']);
    firstName = _text(json['firstName']);
    lastName = _text(json['lastName']);
    profilePictureURL = _text(json['profilePictureURL']);
    fcmToken = _text(json['fcmToken']);
    countryCode = _text(json['countryCode']);
    countryISOCode = _text(json['countryISOCode']);
    phoneNumber = _text(json['phoneNumber']);
    walletAmount = _num(json['wallet_amount']) ?? 0;
    createdAt = _timestamp(json['createdAt']);
    active = _bool(json['active']);
    isActive = _bool(json['isActive']);
    isDocumentVerify = _bool(json['isDocumentVerify']) ?? false;
    role = _text(json['role']) ?? 'user';
    location = _nested(json['location'], UserLocation.fromJson);
    userBankDetails = _nested(json['userBankDetails'], UserBankDetails.fromJson);
    if (json['shippingAddress'] is List) {
      final List<ShippingAddress> addresses = <ShippingAddress>[];
      for (final v in json['shippingAddress'] as List) {
        final ShippingAddress? address = _nested(v, ShippingAddress.fromJson);
        if (address != null) addresses.add(address);
      }
      _shippingAddress = addresses;
      _shippingAddressUnreadable = addresses.length != (json['shippingAddress'] as List).length;
    }
    carPictureURL = _text(json['carPictureURL']);
    inProgressOrderID = json['inProgressOrderID'] is List ? List<dynamic>.from(json['inProgressOrderID']) : [];
    orderRequestData = json['orderRequestData'] is List ? List<dynamic>.from(json['orderRequestData']) : [];
    vendorID = _text(json['vendorID']) ?? '';
    zoneId = _text(json['zoneId']) ?? '';
    zoneIds = json['zoneIds'] is Iterable ? _textList(json['zoneIds']) : null;
    rotation = _num(json['rotation']);
    appIdentifier = _text(json['appIdentifier']);
    provider = _text(json['provider']);
    subscriptionPlanId = _text(json['subscriptionPlanId']);
    subscriptionExpiryDate = _timestamp(json['subscriptionExpiryDate']);
    subscriptionPlan = _nested(json['subscription_plan'], SubscriptionPlanModel.fromJson);
    // serviceTypes: use new field; fall back to legacy serviceType for old documents
    serviceTypes = _textList(json['serviceTypes']) ?? _textList(json['serviceType']);
    // sectionIds: use new field; fall back to legacy sectionId for old documents
    sectionIds = _textList(json['sectionIds']) ?? _textList(json['sectionId']);
    // sectionNames: use new field; fall back to legacy serviceDetails for old documents
    if (json['sectionNames'] is Map) {
      sectionNames = {for (final e in (json['sectionNames'] as Map).entries) e.key.toString(): '${e.value ?? ''}'};
    } else if (json['serviceDetails'] is Map) {
      final legacy = Map<String, dynamic>.from(json['serviceDetails']);
      sectionNames = {for (final e in legacy.entries) e.key: ((e.value is Map ? e.value['sectionName'] : null) ?? e.key).toString()};
    }
    vehicleDetails = json['vehicleDetails'] is Map ? Map<String, dynamic>.from(json['vehicleDetails']) : null;
    reviewsCount = json['reviewsCount'] == null ? '0' : json['reviewsCount'].toString();
    reviewsSum = json['reviewsSum'] == null ? '0' : json['reviewsSum'].toString();
    adminCommissionModel = _nested(json['adminCommission'], AdminCommission.fromJson);
    _orderCabRequestData = _nested(json['ordercabRequestData'], CabOrderModel.fromJson);
    _cabRequestUnreadable = json['ordercabRequestData'] is Map && _orderCabRequestData == null;
    rideType = _text(json['rideType']);
    ownerId = _text(json['ownerId']);
    isOwner = _bool(json['isOwner']);
    isAutoVerify = _bool(json['isAutoVerify']);
    regionId = _str(json['regionId']);
    driverType = _str(json['driverType']);
    legacyIsCompany = _bool(json['isCompany']);
    // Carrier membership, read tolerantly: the panel may spell it either way.
    carrierId = _str(json['carrierId']) ?? _str(json['deliveryCarrierId']);
    companyName = _str(json['companyName']);
    companyAddress = _str(json['companyAddress']);
    operatingLicence = _str(json['operatingLicence']);
    commercialRegister = _str(json['commercialRegister']);
    uniqueIdNumber = _str(json['uniqueIdNumber']);
    operatingLicenceFile = _str(json['operatingLicenceFile']);
    commercialRegisterFile = _str(json['commercialRegisterFile']);
    uniqueIdNumberFile = _str(json['uniqueIdNumberFile']);
  }

  /// A string value as stored ('' kept), anything else as its text.
  static String? _text(dynamic value) => value == null ? null : (value is String ? value : value.toString());

  static num? _num(dynamic value) => value is num ? value : (value == null ? null : num.tryParse(value.toString().trim()));

  static bool? _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'true':
        case '1':
          return true;
        case 'false':
        case '0':
          return false;
      }
    }
    return null;
  }

  static Timestamp? _timestamp(dynamic value) {
    if (value is Timestamp) return value;
    if (value is int) return Timestamp.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final DateTime? date = DateTime.tryParse(value);
      return date == null ? null : Timestamp.fromDate(date);
    }
    return null;
  }

  /// A list of strings from a list (nulls and blanks dropped) or a single
  /// non-blank value (the legacy single-value fields).
  static List<String>? _textList(dynamic value) {
    if (value is Iterable) {
      return value.where((e) => e != null && e.toString().trim().isNotEmpty).map((e) => e.toString()).toList();
    }
    if (value != null && value is! Map && value.toString().trim().isNotEmpty) return [value.toString()];
    return null;
  }

  /// A nested model, or null when the value is not a map or does not parse.
  static T? _nested<T>(dynamic value, T Function(Map<String, dynamic>) parse) {
    if (value is! Map) return null;
    try {
      return parse(Map<String, dynamic>.from(value));
    } catch (_) {
      return null;
    }
  }

  static String? _str(dynamic value) {
    final text = value?.toString();
    return (text == null || text.isEmpty) ? null : text;
  }

  bool get isCompany => driverType == 'company' || isOwner == true || legacyIsCompany == true;

  /// [serviceTypes] with the dispatch spec's aliases read as the module they
  /// name (`parcel-service` -> `parcel_delivery`, `ecommerce-service` ->
  /// `delivery-service`), each module once. For routing and watching only:
  /// the stored values are never rewritten.
  List<String> get serviceModules => DriverServiceTypes.normalizeAll(serviceTypes);

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['email'] = email;
    data['firstName'] = firstName;
    data['lastName'] = lastName;
    data['profilePictureURL'] = profilePictureURL;
    data['fcmToken'] = fcmToken;
    data['countryCode'] = countryCode;
    data['countryISOCode'] = countryISOCode;
    data['phoneNumber'] = phoneNumber;
    data['wallet_amount'] = walletAmount ?? 0;
    data['createdAt'] = createdAt;
    data['active'] = active;
    data['isActive'] = isActive;
    data['role'] = role;
    data['isDocumentVerify'] = isDocumentVerify;
    data['zoneId'] = zoneId;

    if (location != null) {
      data['location'] = location!.toJson();
    }
    if (userBankDetails != null) {
      data['userBankDetails'] = userBankDetails!.toJson();
    }
    // Not written when an entry could not be read: merge would replace the
    // stored list with the shortened one.
    if (shippingAddress != null && !shippingAddressUnreadable) {
      data['shippingAddress'] = shippingAddress!.map((v) => v.toJson()).toList();
    }
    data['serviceTypes'] = serviceTypes ?? ['delivery-service'];
    data['sectionIds'] = sectionIds ?? [];
    if (sectionNames != null) data['sectionNames'] = sectionNames;
    if (vehicleDetails != null) data['vehicleDetails'] = vehicleDetails;
    data['rotation'] = rotation;
    data['inProgressOrderID'] = inProgressOrderID;

    if (role == Constant.userRoleDriver) {
      data['vendorID'] = vendorID;
      data['carPictureURL'] = carPictureURL;
      data['orderRequestData'] = orderRequestData;
      if (orderCabRequestData != null) {
        data['ordercabRequestData'] = orderCabRequestData!.toJson();
      }
      data['ownerId'] = ownerId;
      data['isOwner'] = isOwner;
    }
    if (role == Constant.userRoleVendor) {
      data['vendorID'] = vendorID;
      data['subscriptionPlanId'] = subscriptionPlanId;
      data['subscriptionExpiryDate'] = subscriptionExpiryDate;
      data['subscription_plan'] = subscriptionPlan?.toJson();
    }
    data['appIdentifier'] = appIdentifier;
    data['provider'] = provider;
    data['reviewsCount'] = reviewsCount;
    data['reviewsSum'] = reviewsSum;
    data['isAutoVerify'] = isAutoVerify;
    if (adminCommissionModel != null) {
      data['adminCommission'] = adminCommissionModel!.toJson();
    }
    // Additive fields: written only when known, so an update never clears a
    // value the admin panel set (e.g. regionId).
    if (regionId != null) data['regionId'] = regionId;
    if (driverType != null) data['driverType'] = driverType;
    if (carrierId != null) data['carrierId'] = carrierId;
    if (companyName != null) data['companyName'] = companyName;
    if (companyAddress != null) data['companyAddress'] = companyAddress;
    if (zoneIds != null) data['zoneIds'] = zoneIds;
    if (operatingLicence != null) data['operatingLicence'] = operatingLicence;
    if (commercialRegister != null) data['commercialRegister'] = commercialRegister;
    if (uniqueIdNumber != null) data['uniqueIdNumber'] = uniqueIdNumber;
    if (operatingLicenceFile != null) data['operatingLicenceFile'] = operatingLicenceFile;
    if (commercialRegisterFile != null) data['commercialRegisterFile'] = commercialRegisterFile;
    if (uniqueIdNumberFile != null) data['uniqueIdNumberFile'] = uniqueIdNumberFile;
    return data;
  }
}

class UserLocation {
  double? latitude;
  double? longitude;

  UserLocation({this.latitude, this.longitude});

  /// Numbers as stored by any writer: an integer (or numeric text) used to
  /// throw on these `double?` fields, and the whole location was dropped.
  UserLocation.fromJson(Map<String, dynamic> json) {
    latitude = _coordinate(json['latitude']);
    longitude = _coordinate(json['longitude']);
  }

  static double? _coordinate(dynamic value) {
    final num? n = value is num ? value : num.tryParse((value ?? '').toString().trim());
    return n == null || !n.isFinite ? null : n.toDouble();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    return data;
  }
}

class ShippingAddress {
  String? id;
  String? address;
  String? addressAs;
  String? landmark;
  String? locality;
  UserLocation? location;
  bool? isDefault;

  ShippingAddress({this.address, this.landmark, this.locality, this.location, this.isDefault, this.addressAs, this.id});

  ShippingAddress.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    address = json['address'];
    landmark = json['landmark'];
    locality = json['locality'];
    isDefault = json['isDefault'];
    addressAs = json['addressAs'];
    location = json['location'] == null ? null : UserLocation.fromJson(json['location']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['address'] = address;
    data['landmark'] = landmark;
    data['locality'] = locality;
    data['isDefault'] = isDefault;
    data['addressAs'] = addressAs;
    if (location != null) {
      data['location'] = location!.toJson();
    }
    return data;
  }

  /// Client point 17: never render a missing part as the literal "null", and
  /// never leave the separator a dropped part would have been between.
  String getFullAddress() {
    return AddressFormat.join([address, locality, landmark]);
  }
}

class UserBankDetails {
  String bankName;
  String branchName;
  String holderName;
  String accountNumber;
  String otherDetails;

  UserBankDetails({this.bankName = '', this.otherDetails = '', this.branchName = '', this.accountNumber = '', this.holderName = ''});

  factory UserBankDetails.fromJson(Map<String, dynamic> parsedJson) {
    return UserBankDetails(
      bankName: parsedJson['bankName'] ?? '',
      branchName: parsedJson['branchName'] ?? '',
      holderName: parsedJson['holderName'] ?? '',
      accountNumber: parsedJson['accountNumber'] ?? '',
      otherDetails: parsedJson['otherDetails'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'bankName': bankName, 'branchName': branchName, 'holderName': holderName, 'accountNumber': accountNumber, 'otherDetails': otherDetails};
  }
}

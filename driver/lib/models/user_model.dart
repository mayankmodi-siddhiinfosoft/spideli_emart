import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/constant.dart';
import 'package:driver/models/admin_commission.dart';
import 'package:driver/models/cab_order_model.dart';
import 'package:driver/models/subscription_plan_model.dart';

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
  List<ShippingAddress>? shippingAddress;
  String? carPictureURL;
  List<dynamic>? inProgressOrderID;
  List<dynamic>? orderRequestData;
  String? vendorID;
  String? zoneId;
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
  CabOrderModel? orderCabRequestData;
  String? rideType;
  String? ownerId;
  bool? isOwner;
  bool? isAutoVerify;

  /// Management zone (spec 3.1 / 18.4). Absent = global settings.
  String? regionId;

  /// "individual" | "company" (spec 4.11). Absent = individual.
  String? driverType;

  /// The delivery carrier (`delivery_carriers/{id}`) this driver is registered
  /// under — admin spec §11. Read only; the panel owns it. Absent = the driver
  /// belongs to no carrier and sees platform work exactly as before.
  String? carrierId;

  /// Company identification (spec 4.11), additive on the user doc.
  String? companyName;
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
    this.shippingAddress,
    this.carPictureURL,
    this.inProgressOrderID,
    this.orderRequestData,
    this.vendorID,
    this.zoneId,
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
    this.orderCabRequestData,
    this.rideType,
    this.ownerId,
    this.isOwner,
    this.isAutoVerify,
    this.regionId,
    this.driverType,
    this.companyName,
    this.operatingLicence,
    this.commercialRegister,
    this.uniqueIdNumber,
    this.operatingLicenceFile,
    this.commercialRegisterFile,
    this.uniqueIdNumberFile,
  });

  String fullName() {
    return "${firstName ?? ''} ${lastName ?? ''}";
  }

  double get averageRating {
    final double sum = double.tryParse(reviewsSum ?? '0') ?? 0.0;
    final double count = double.tryParse(reviewsCount ?? '0') ?? 0.0;

    if (count <= 0) return 0.0;
    return sum / count;
  }

  UserModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    email = json['email'];
    firstName = json['firstName'];
    lastName = json['lastName'];
    profilePictureURL = json['profilePictureURL'];
    fcmToken = json['fcmToken'];
    countryCode = json['countryCode'];
    countryISOCode = json['countryISOCode'];
    phoneNumber = json['phoneNumber'];
    walletAmount = json['wallet_amount'] ?? 0;
    createdAt = json['createdAt'];
    active = json['active'];
    isActive = json['isActive'];
    isDocumentVerify = json['isDocumentVerify'] ?? false;
    role = json['role'] ?? 'user';
    location = json['location'] != null ? UserLocation.fromJson(json['location']) : null;
    userBankDetails = json['userBankDetails'] != null ? UserBankDetails.fromJson(json['userBankDetails']) : null;
    if (json['shippingAddress'] != null) {
      shippingAddress = <ShippingAddress>[];
      json['shippingAddress'].forEach((v) {
        shippingAddress!.add(ShippingAddress.fromJson(v));
      });
    }
    carPictureURL = json['carPictureURL'];
    inProgressOrderID = json['inProgressOrderID'] ?? [];
    orderRequestData = json['orderRequestData'] ?? [];
    vendorID = json['vendorID'] ?? '';
    zoneId = json['zoneId'] ?? '';
    rotation = json['rotation'];
    appIdentifier = json['appIdentifier'];
    provider = json['provider'];
    subscriptionPlanId = json['subscriptionPlanId'];
    subscriptionExpiryDate = json['subscriptionExpiryDate'];
    subscriptionPlan = json['subscription_plan'] != null ? SubscriptionPlanModel.fromJson(json['subscription_plan']) : null;
    // serviceTypes: use new field; fall back to legacy serviceType for old documents
    serviceTypes = json['serviceTypes'] != null ? List<String>.from(json['serviceTypes']) : (json['serviceType'] != null ? [json['serviceType'] as String] : null);
    // sectionIds: use new field; fall back to legacy sectionId for old documents
    sectionIds = json['sectionIds'] != null ? List<String>.from(json['sectionIds']) : (json['sectionId'] != null && json['sectionId'].toString().isNotEmpty ? [json['sectionId'].toString()] : null);
    // sectionNames: use new field; fall back to legacy serviceDetails for old documents
    if (json['sectionNames'] != null) {
      sectionNames = Map<String, String>.from(json['sectionNames']);
    } else if (json['serviceDetails'] != null) {
      final legacy = Map<String, dynamic>.from(json['serviceDetails']);
      sectionNames = {for (final e in legacy.entries) e.key: (e.value['sectionName'] ?? e.key).toString()};
    }
    vehicleDetails = json['vehicleDetails'] != null ? Map<String, dynamic>.from(json['vehicleDetails']) : null;
    reviewsCount = json['reviewsCount'] == null ? '0' : json['reviewsCount'].toString();
    reviewsSum = json['reviewsSum'] == null ? '0' : json['reviewsSum'].toString();
    adminCommissionModel = json['adminCommission'] != null ? AdminCommission.fromJson(json['adminCommission']) : null;
    orderCabRequestData = json['ordercabRequestData'] != null ? CabOrderModel.fromJson(json['ordercabRequestData']) : null;
    rideType = json['rideType'];
    ownerId = json['ownerId'];
    isOwner = json['isOwner'];
    isAutoVerify = json['isAutoVerify'];
    regionId = _str(json['regionId']);
    driverType = _str(json['driverType']);
    // Carrier membership, read tolerantly: the panel may spell it either way.
    carrierId = _str(json['carrierId']) ?? _str(json['deliveryCarrierId']);
    companyName = _str(json['companyName']);
    operatingLicence = _str(json['operatingLicence']);
    commercialRegister = _str(json['commercialRegister']);
    uniqueIdNumber = _str(json['uniqueIdNumber']);
    operatingLicenceFile = _str(json['operatingLicenceFile']);
    commercialRegisterFile = _str(json['commercialRegisterFile']);
    uniqueIdNumberFile = _str(json['uniqueIdNumberFile']);
  }

  static String? _str(dynamic value) {
    final text = value?.toString();
    return (text == null || text.isEmpty) ? null : text;
  }

  bool get isCompany => driverType == 'company' || isOwner == true;

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
    if (shippingAddress != null) {
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

  UserLocation.fromJson(Map<String, dynamic> json) {
    latitude = json['latitude'];
    longitude = json['longitude'];
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

  String getFullAddress() {
    return '${address == null || address!.isEmpty ? "" : address} $locality ${landmark == null || landmark!.isEmpty ? "" : landmark.toString()}';
  }
}

class UserBankDetails {
  String bankName;
  String branchName;
  String holderName;
  String accountNumber;
  String otherDetails;

  UserBankDetails({
    this.bankName = '',
    this.otherDetails = '',
    this.branchName = '',
    this.accountNumber = '',
    this.holderName = '',
  });

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
    return {
      'bankName': bankName,
      'branchName': branchName,
      'holderName': holderName,
      'accountNumber': accountNumber,
      'otherDetails': otherDetails,
    };
  }
}

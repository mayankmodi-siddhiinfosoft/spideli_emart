import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/admin_commission_model.dart';
import 'package:vendor/models/subscription_plan_model.dart';

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
  String? carName;
  String? carNumber;
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
  String? serviceType;
  String? sectionId;
  List<String>? sectionIds;
  List<String>? serviceTypes;
  Map<String, String>? sectionNames;
  String? vehicleType;
  String? carMakes;
  String? reviewsCount;
  String? reviewsSum;
  AdminCommission? adminCommissionModel;
  String? employeePermissionId;
  bool? isAutoVerify;

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
    this.carName,
    this.carNumber,
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
    this.serviceType,
    this.sectionId,
    this.sectionIds,
    this.serviceTypes,
    this.sectionNames,
    this.vehicleType,
    this.carMakes,
    this.reviewsCount,
    this.reviewsSum,
    this.adminCommissionModel,
    this.employeePermissionId,
    this.isAutoVerify,
  });

  String fullName() {
    return "${firstName ?? ''} ${lastName ?? ''}";
  }

  double get averageRating {
    final num sum = num.tryParse(reviewsSum ?? '0') ?? 0;
    final num count = num.tryParse(reviewsCount ?? '0') ?? 0;
    if (count == 0) return 0.0;
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

    walletAmount = num.tryParse(json['wallet_amount']?.toString() ?? '0') ?? 0;

    createdAt = json['createdAt'] is Timestamp ? json['createdAt'] : null;

    active = json['active'];
    isActive = json['isActive'];
    isDocumentVerify = json['isDocumentVerify'] ?? false;
    role = json['role'] ?? 'user';

    /// ✅ Safe Map parsing
    location = json['location'] is Map ? UserLocation.fromJson(json['location']) : null;

    userBankDetails = json['userBankDetails'] is Map ? UserBankDetails.fromJson(json['userBankDetails']) : null;

    /// ✅ FIXED (Main Issue)
    shippingAddress = parseShipping(json['shippingAddress']);

    carName = json['carName'];
    carNumber = json['carNumber'];
    carPictureURL = json['carPictureURL'];

    inProgressOrderID = json['inProgressOrderID'] is List ? json['inProgressOrderID'] : [];

    orderRequestData = json['orderRequestData'] is List ? json['orderRequestData'] : [];

    vendorID = json['vendorID'] ?? '';
    zoneId = json['zoneId'] ?? '';
    rotation = json['rotation'];

    appIdentifier = json['appIdentifier'];
    provider = json['provider'];

    subscriptionPlanId = json['subscriptionPlanId'];
    subscriptionExpiryDate = json['subscriptionExpiryDate'];

    subscriptionPlan = json['subscription_plan'] is Map ? SubscriptionPlanModel.fromJson(json['subscription_plan']) : null;

    serviceType = json['serviceType'];
    sectionId = json['sectionId'] ?? '';
    sectionIds = (json['sectionIds'] as List?)?.map((e) => e.toString()).toList();
    serviceTypes = (json['serviceTypes'] as List?)?.map((e) => e.toString()).toList();
    sectionNames = (json['sectionNames'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString()));
    vehicleType = json['vehicleType'];
    carMakes = json['carMakes'];

    reviewsCount = json['reviewsCount']?.toString() ?? '0';
    reviewsSum = json['reviewsSum']?.toString() ?? '0';

    adminCommissionModel = json['adminCommission'] is Map ? AdminCommission.fromJson(json['adminCommission']) : null;

    employeePermissionId = json['employeePermissionId'];

    isAutoVerify = json['isAutoVerify'];
  }

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
    data['isActive'] = isActive ?? false;
    data['role'] = role;
    data['isDocumentVerify'] = isDocumentVerify;
    data['zoneId'] = zoneId;
    data['sectionId'] = sectionId ?? '';
    if (location != null) {
      data['location'] = location!.toJson();
    }
    if (userBankDetails != null) {
      data['userBankDetails'] = userBankDetails!.toJson();
    }
    if (shippingAddress != null) {
      data['shippingAddress'] = shippingAddress!.map((v) => v.toJson()).toList();
    }

    if (role == Constant.userRoleDriver) {
      data['vendorID'] = vendorID;
      data['carName'] = carName;
      data['carNumber'] = carNumber;
      data['carPictureURL'] = carPictureURL;
      data['inProgressOrderID'] = inProgressOrderID;
      data['orderRequestData'] = orderRequestData;
      data['rotation'] = rotation;
      data['serviceType'] = serviceType;

      data['vehicleType'] = vehicleType;
      data['carMakes'] = carMakes;

      if (sectionIds != null) data['sectionIds'] = sectionIds;
      if (serviceTypes != null) data['serviceTypes'] = serviceTypes;
      if (sectionNames != null) data['sectionNames'] = sectionNames;
    }
    if (role == Constant.userRoleVendor) {
      data['vendorID'] = vendorID;
      data['subscriptionPlanId'] = subscriptionPlanId;
      data['subscriptionExpiryDate'] = subscriptionExpiryDate;
      data['subscription_plan'] = subscriptionPlan?.toJson();
      data['isAutoVerify'] = isAutoVerify;
    }
    data['appIdentifier'] = appIdentifier;
    data['provider'] = provider;
    data['reviewsCount'] = reviewsCount;
    data['reviewsSum'] = reviewsSum;
    if (adminCommissionModel != null) {
      data['adminCommission'] = adminCommissionModel!.toJson();
    }
    if (role == Constant.userRoleEmployee) {
      data['vendorID'] = vendorID;
      data['employeePermissionId'] = employeePermissionId;
    }

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

List<ShippingAddress> parseShipping(dynamic data) {
  if (data is List) {
    return data.map((e) => ShippingAddress.fromJson(e as Map<String, dynamic>)).toList();
  } else if (data is Map) {
    return [ShippingAddress.fromJson(data as Map<String, dynamic>)];
  }
  return [];
}

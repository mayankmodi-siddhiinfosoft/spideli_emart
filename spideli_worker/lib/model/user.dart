import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliworker/model/admin_commission_model.dart';
import 'package:spideliworker/model/provider_service_model.dart';
import 'package:spideliworker/model/subscription_plan_model.dart';
import 'package:flutter/foundation.dart';

class User with ChangeNotifier {
  String id;
  String firstName;
  String lastName;
  String email;
  String phoneNumber;
  String profilePictureURL;
  String fcmToken;
  bool active;
  String role;

  Timestamp? createdAt;
  Timestamp lastOnlineTimestamp;

  num reviewsCount;
  num reviewsSum;

  double latitude;
  double longitude;
  GeoFireData geoFireData;
  UserLocation location;

  String? address;
  String? salary;
  String? providerId;
  bool? online;

  String? countryCode;
  String? provider;
  num walletAmount;
  List<dynamic> photos;
  UserBankDetails userBankDetails;

  String? subscriptionPlanId;
  Timestamp? subscriptionExpiryDate;
  SubscriptionPlanModel? subscriptionPlan;
  String? subscriptionTotalOrders;

  String sectionId;
  AdminCommissionModel? adminCommission;
  String? appIdentifier;

  /// Panel-written, READ ONLY here (never put in toJson, so a profile save
  /// can never erase them): the worker's management zone and the admin's
  /// document-verification flag (same field the Driver app uses).
  String? regionId;
  bool? isDocumentVerify;

  User(
      {this.id = '',
      this.firstName = '',
      this.lastName = '',
      this.email = '',
      this.phoneNumber = '',
      this.profilePictureURL = '',
      this.fcmToken = '',
      this.active = false,
      this.role = '',
      Timestamp? lastOnlineTimestamp,
      this.createdAt,
      this.reviewsCount = 0,
      this.reviewsSum = 0,
      this.latitude = 0.1,
      this.longitude = 0.1,
      GeoFireData? geoFireData,
      UserLocation? location,
      this.address,
      this.salary,
      this.providerId,
      this.online,
      this.countryCode,
      this.provider,
      this.walletAmount = 0.0,
      this.photos = const [],
      UserBankDetails? userBankDetails,
      this.subscriptionPlanId,
      this.subscriptionExpiryDate,
      this.subscriptionPlan,
      this.subscriptionTotalOrders,
      this.sectionId = '',
      this.adminCommission,
      this.appIdentifier,
      this.regionId,
      this.isDocumentVerify})
      : lastOnlineTimestamp = lastOnlineTimestamp ?? Timestamp.now(),
        userBankDetails = userBankDetails ?? UserBankDetails(),
        location = location ?? UserLocation(),
        geoFireData = geoFireData ??
            GeoFireData(
              geohash: "",
              geoPoint: const GeoPoint(0.0, 0.0),
            );

  String fullName() => '$firstName $lastName';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['userID'],
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      profilePictureURL: json['profilePictureURL'] ?? '',
      fcmToken: json['fcmToken'] ?? '',
      active: json['active'] ?? json['isActive'] ?? false,
      role: json['role'] ?? '',
      createdAt: json['createdAt'],
      lastOnlineTimestamp: json['lastOnlineTimestamp'] ?? Timestamp.now(),
      reviewsCount: json['reviewsCount'] == null ? 0 : (json['reviewsCount'] is String ? int.tryParse(json['reviewsCount']) ?? 0 : json['reviewsCount']),
      reviewsSum: json['reviewsSum'] == null ? 0 : (json['reviewsSum'] is String ? int.tryParse(json['reviewsSum']) ?? 0 : json['reviewsSum']),
      latitude: json['latitude'] ?? 0.1,
      longitude: json['longitude'] ?? 0.1,
      geoFireData: json.containsKey('g')
          ? GeoFireData.fromJson(json['g'])
          : GeoFireData(
              geohash: "",
              geoPoint: const GeoPoint(0.0, 0.0),
            ),
      location: json.containsKey('location') ? UserLocation.fromJson(json['location']) : UserLocation(),
      address: json['address'],
      salary: json['salary'],
      providerId: json['providerId'],
      online: json['online'],
      countryCode: json['countryCode'],
      provider: json['provider'],
      walletAmount: json['wallet_amount'] ?? 0.0,
      photos: json['photos'] ?? [],
      userBankDetails: json.containsKey('userBankDetails') ? UserBankDetails.fromJson(json['userBankDetails']) : UserBankDetails(),
      subscriptionPlanId: json['subscriptionPlanId'],
      subscriptionExpiryDate: json['subscriptionExpiryDate'],
      subscriptionTotalOrders: json['subscriptionTotalOrders'],
      subscriptionPlan: json['subscription_plan'] != null ? SubscriptionPlanModel.fromJson(json['subscription_plan']) : null,
      appIdentifier: json['appIdentifier'],
      sectionId: json['section_id'] ?? '',
      adminCommission: json['adminCommission'] != null ? AdminCommissionModel.fromJson(json['adminCommission']) : null,
      regionId: (json['regionId']?.toString().isNotEmpty == true) ? json['regionId'].toString() : null,
      isDocumentVerify: json['isDocumentVerify'] is bool ? json['isDocumentVerify'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userID': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'profilePictureURL': profilePictureURL,
      'fcmToken': fcmToken,
      'active': active,
      'isActive': active,
      'role': role,
      'appIdentifier': appIdentifier,
      'createdAt': createdAt,
      'lastOnlineTimestamp': lastOnlineTimestamp,
      'reviewsCount': reviewsCount,
      'reviewsSum': reviewsSum,
      'latitude': latitude,
      'longitude': longitude,
      'g': geoFireData.toJson(),
      'location': location.toJson(),
      'address': address,
      'salary': salary,
      'providerId': providerId,
      'online': online,
      'countryCode': countryCode,
      'provider': provider,
      'wallet_amount': walletAmount,
      'photos': photos,
      'userBankDetails': userBankDetails.toJson(),
      'subscriptionPlanId': subscriptionPlanId,
      'subscriptionExpiryDate': subscriptionExpiryDate,
      'subscription_plan': subscriptionPlan?.toJson(),
      'subscriptionTotalOrders': subscriptionTotalOrders,
      'section_id': sectionId,
      if (adminCommission != null) 'adminCommission': adminCommission!.toJson(),
    };
  }
}

class UserSettings {
  bool pushNewMessages;

  bool orderUpdates;

  bool newArrivals;

  bool promotions;

  bool photos;

  bool reststatus;

  UserSettings({this.pushNewMessages = false, this.orderUpdates = false, this.newArrivals = false, this.promotions = false, this.photos = false, this.reststatus = false});

  factory UserSettings.fromJson(Map<dynamic, dynamic> parsedJson) {
    return UserSettings(
        pushNewMessages: parsedJson['pushNewMessages'] ?? true,
        orderUpdates: parsedJson['orderUpdates'] ?? true,
        newArrivals: parsedJson['newArrivals'] ?? true,
        promotions: parsedJson['promotions'] ?? true,
        photos: parsedJson['photos'] ?? true,
        reststatus: parsedJson['reststatus'] ?? false);
  }

  Map<String, dynamic> toJson() {
    return {'pushNewMessages': pushNewMessages, 'orderUpdates': orderUpdates, 'newArrivals': newArrivals, 'promotions': promotions, 'photos': photos, 'reststatus': reststatus};
  }
}

class UserLocation {
  double latitude;

  double longitude;

  UserLocation({this.latitude = 0.01, this.longitude = 0.01});

  factory UserLocation.fromJson(Map<dynamic, dynamic> parsedJson) {
    double userlat = 0.1, userlog = 0.1;

    if (parsedJson.containsKey('latitude') && parsedJson['latitude'] != null && parsedJson['latitude'] != '') {
      if (parsedJson['latitude'] is double) {
        userlat = parsedJson['latitude'];
      }
      if (parsedJson['latitude'] is String) {
        userlat = double.parse(parsedJson['latitude']);
      }
    }

    if (parsedJson.containsKey('longitude') && parsedJson['longitude'] != null && parsedJson['longitude'] != '') {
      if (parsedJson['longitude'] is double) {
        userlog = parsedJson['longitude'];
      }
      if (parsedJson['longitude'] is String) {
        userlog = double.parse(parsedJson['longitude']);
      }
    }

    return new UserLocation(
      latitude: userlat,
      longitude: userlog,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': this.latitude,
      'longitude': this.longitude,
    };
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
      'bankName': this.bankName,
      'branchName': this.branchName,
      'holderName': this.holderName,
      'accountNumber': this.accountNumber,
      'otherDetails': this.otherDetails,
    };
  }
}

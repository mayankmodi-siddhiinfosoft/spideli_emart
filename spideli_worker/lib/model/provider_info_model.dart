import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ProviderInfo with ChangeNotifier {
  String email;
  String firstName;
  String lastName;
  String phoneNumber;
  bool active;
  Timestamp lastOnlineTimestamp;
  String userID;
  String profilePictureURL;
  String appIdentifier;
  String fcmToken;
  UserLocation location;
  List<dynamic> photos;
  String role;
  UserBankDetails userBankDetails;
  dynamic walletAmount;
  Timestamp? createdAt;
  num reviewsCount;
  num reviewsSum;

  ProviderInfo({
    this.email = '',
    this.userID = '',
    this.profilePictureURL = '',
    this.firstName = '',
    this.phoneNumber = '',
    this.lastName = '',
    this.active = true,
    this.walletAmount = 0.0,
    lastOnlineTimestamp,
    userBankDetails,
    this.fcmToken = '',
    location,
    this.photos = const [],
    this.role = '',
    this.createdAt,
    this.reviewsCount = 0,
    this.reviewsSum = 0,
  })  : lastOnlineTimestamp = lastOnlineTimestamp ?? Timestamp.now(),
        userBankDetails = userBankDetails ?? UserBankDetails(),
        appIdentifier = 'Flutter spideli Provider Dashboard ${Platform.operatingSystem}',
        location = location ?? UserLocation();

  String fullName() {
    return '$firstName $lastName';
  }

  factory ProviderInfo.fromJson(Map<String, dynamic> parsedJson) {
    return ProviderInfo(
      walletAmount: parsedJson['wallet_amount'] ?? 0.0,
      email: parsedJson['email'] ?? '',
      firstName: parsedJson['firstName'] ?? '',
      lastName: parsedJson['lastName'] ?? '',
      active: ((parsedJson.containsKey('active')) ? parsedJson['active'] : parsedJson['isActive']) ?? false,
      lastOnlineTimestamp: parsedJson['lastOnlineTimestamp'],
      phoneNumber: parsedJson['phoneNumber'] ?? '',
      userID: parsedJson['id'] ?? parsedJson['userID'] ?? '',
      profilePictureURL: parsedJson['profilePictureURL'] ?? '',
      fcmToken: parsedJson['fcmToken'] ?? '',
      location: parsedJson.containsKey('location') ? UserLocation.fromJson(parsedJson['location']) : UserLocation(),
      photos: parsedJson['photos'] ?? [].cast<dynamic>(),
      role: parsedJson['role'] ?? '',
      createdAt: parsedJson['createdAt'],
      userBankDetails: parsedJson.containsKey('userBankDetails') ? UserBankDetails.fromJson(parsedJson['userBankDetails']) : UserBankDetails(),
      reviewsCount: parsedJson['reviewsCount'] ?? 0,
      reviewsSum: parsedJson['reviewsSum'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    photos.toList().removeWhere((element) => element == null);
    Map<String, dynamic> json = {
      'email': email,
      'wallet_amount': walletAmount,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'id': userID,
      'isActive': active,
      'active': active,
      'lastOnlineTimestamp': lastOnlineTimestamp,
      'userBankDetails': userBankDetails.toJson(),
      'profilePictureURL': profilePictureURL,
      'appIdentifier': appIdentifier,
      'fcmToken': fcmToken,
      'location': location.toJson(),
      'photos': photos,
      'role': role,
      'createdAt': createdAt,
      'reviewsCount': reviewsCount,
      'reviewsSum': reviewsSum,
    };

    return json;
  }

  static void fromPayload(e) {}

  Map<String, dynamic> toPayload() {
    Map<String, dynamic> json = {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'id': userID,
      'active': active,
      'lastOnlineTimestamp': lastOnlineTimestamp.millisecondsSinceEpoch,
      'profilePictureURL': profilePictureURL,
      'appIdentifier': appIdentifier,
      'fcmToken': fcmToken,
      'location': location.toJson(),
      'role': role,
      'createdAt': createdAt
    };
    return json;
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

    return UserLocation(
      latitude: userlat,
      longitude: userlog,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
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
      'bankName': bankName,
      'branchName': branchName,
      'holderName': holderName,
      'accountNumber': accountNumber,
      'otherDetails': otherDetails,
    };
  }
}

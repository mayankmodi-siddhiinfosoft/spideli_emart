// import 'package:cloud_firestore/cloud_firestore.dart';

// class User {
//   String? id;
//   String? firstName;
//   String? lastName;
//   String? email;
//   String? phoneNumber;
//   String? address;
//   String? salary;
//   Timestamp? createdAt;
//   GeoFireData geoFireData;
//   double? latitude;
//   double? longitude;
//   String? providerId;
//   bool? active;
//   String fcmToken;
//   String profilePictureURL;
//   bool? online;
//   num? reviewsCount;
//   num? reviewsSum;

//   User({
//     this.id = '',
//     this.firstName = '',
//     this.lastName = '',
//     this.email = '',
//     this.phoneNumber = '',
//     this.address = '',
//     this.salary,
//     this.createdAt,
//     geoFireData,
//     this.latitude = 0.1,
//     this.longitude = 0.1,
//     this.providerId,
//     this.active = false,
//     this.fcmToken = '',
//     this.profilePictureURL = '',
//     this.online,
//     this.reviewsCount = 0,
//     this.reviewsSum = 0,
//   }) : geoFireData = geoFireData ??
//             GeoFireData(
//               geohash: "",
//               geoPoint: const GeoPoint(0.0, 0.0),
//             );

//   String fullName() {
//     return '$firstName $lastName';
//   }

//   factory User.fromJson(Map<String, dynamic> parsedJson) {
//     return User(
//       id: parsedJson['id'] ?? '',
//       firstName: parsedJson['firstName'] ?? '',
//       lastName: parsedJson['lastName'] ?? '',
//       email: parsedJson['email'] ?? '',
//       phoneNumber: parsedJson['phoneNumber'] ?? '',
//       address: parsedJson['address'] ?? '',
//       salary: parsedJson['salary'] ?? '',
//       createdAt: parsedJson['createdAt'] ?? Timestamp.now(),
//       geoFireData: parsedJson.containsKey('g')
//           ? GeoFireData.fromJson(parsedJson['g'])
//           : GeoFireData(
//               geohash: "",
//               geoPoint: const GeoPoint(0.0, 0.0),
//             ),
//       latitude: parsedJson['latitude'] ?? 0.1,
//       longitude: parsedJson['longitude'] ?? 0.1,
//       providerId: parsedJson['providerId'] ?? '',
//       active: parsedJson['active'] ?? false,
//       fcmToken: parsedJson['fcmToken'] ?? '',
//       profilePictureURL: parsedJson['profilePictureURL'] ?? '',
//       online: parsedJson['online'] ?? false,
//       reviewsCount: parsedJson['reviewsCount'] ?? 0,
//       reviewsSum: parsedJson['reviewsSum'] ?? 0,
//     );
//   }

//   Map<String, dynamic> toJson() {
//     Map<String, dynamic> json = {
//       'id': id,
//       'firstName': firstName,
//       'lastName': lastName,
//       'email': email,
//       'phoneNumber': phoneNumber,
//       'address': address,
//       'salary': salary,
//       'createdAt': createdAt,
//       "g": geoFireData.toJson(),
//       'latitude': latitude,
//       'longitude': longitude,
//       'providerId': providerId,
//       'active': active,
//       'fcmToken': fcmToken,
//       'profilePictureURL': profilePictureURL,
//       'online': online,
//       'reviewsCount': reviewsCount,
//       'reviewsSum': reviewsSum,
//     };
//     return json;
//   }
// }

// class GeoFireData {
//   String? geohash;
//   GeoPoint? geoPoint;

//   GeoFireData({this.geohash, this.geoPoint});

//   factory GeoFireData.fromJson(Map<dynamic, dynamic> parsedJson) {
//     return GeoFireData(
//       geohash: parsedJson['geohash'] ?? '',
//       geoPoint: parsedJson['geopoint'] ?? '',
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'geohash': geohash,
//       'geopoint': geoPoint,
//     };
//   }
// }

// class GeoPointClass {
//   double latitude;

//   double longitude;

//   GeoPointClass({this.latitude = 0.01, this.longitude = 0.0});

//   factory GeoPointClass.fromJson(Map<dynamic, dynamic> parsedJson) {
//     return GeoPointClass(
//       latitude: parsedJson['latitude'] ?? 00.1,
//       longitude: parsedJson['longitude'] ?? 00.1,
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'latitude': latitude,
//       'longitude': longitude,
//     };
//   }
// }

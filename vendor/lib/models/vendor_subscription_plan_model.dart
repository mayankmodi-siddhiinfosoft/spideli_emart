import 'package:cloud_firestore/cloud_firestore.dart';

/// A plan a store sells to its OWN customers ("Customer Subscriptions").
/// Stored in `vendor_subscription_plans`. Not to be confused with the platform
/// subscription plans in `subscription_plans` (SubscriptionPlanModel).
class VendorSubscriptionPlanModel {
  String? id;
  String? vendorID;
  String? regionId;
  String? sectionId;
  String? title;
  String? description;
  String? photo;
  String? price;
  String? expiryDay;
  bool? isEnable;
  Timestamp? createdAt;

  VendorSubscriptionPlanModel({this.id, this.vendorID, this.regionId, this.sectionId, this.title, this.description, this.photo, this.price, this.expiryDay, this.isEnable, this.createdAt});

  VendorSubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    vendorID = json['vendorID']?.toString();
    regionId = json['regionId']?.toString();
    sectionId = json['sectionId']?.toString();
    title = json['title']?.toString();
    description = json['description']?.toString();
    photo = json['photo']?.toString();
    price = json['price']?.toString();
    expiryDay = json['expiryDay']?.toString();
    isEnable = json['isEnable'] is bool ? json['isEnable'] : json['isEnable']?.toString() == 'true';
    createdAt = parseSubscriptionTimestamp(json['createdAt']);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendorID': vendorID,
      'regionId': regionId,
      'sectionId': sectionId,
      'title': title,
      'description': description,
      'photo': photo,
      'price': price,
      'expiryDay': expiryDay,
      'isEnable': isEnable ?? true,
      'createdAt': createdAt,
    };
  }

  int get expiryDays => int.tryParse(expiryDay ?? '') ?? 0;
}

/// Tolerant timestamp parser for data written by other clients (Timestamp,
/// epoch milliseconds, ISO string, or a serialized {_seconds} map).
Timestamp? parseSubscriptionTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value;
  if (value is DateTime) return Timestamp.fromDate(value);
  if (value is int) return Timestamp.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    return parsed == null ? null : Timestamp.fromDate(parsed);
  }
  if (value is Map) {
    final seconds = value['_seconds'] ?? value['seconds'];
    if (seconds is int) return Timestamp(seconds, (value['_nanoseconds'] ?? value['nanoseconds'] ?? 0) as int);
  }
  return null;
}

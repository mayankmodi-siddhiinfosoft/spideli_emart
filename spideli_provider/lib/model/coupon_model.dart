import 'package:cloud_firestore/cloud_firestore.dart';

class CouponModel {
  String? id;
  String? code;
  String? discount;
  String? discountType;
  Timestamp? expiresAt;
  bool? isEnabled;
  bool? isPublic = false;
  String? image = "";
  String? providerId;
  String? sectionId;

  CouponModel({
    this.discount,
    this.discountType,
    this.expiresAt,
    this.image = "",
    this.isEnabled,
    this.code,
    this.id,
    this.providerId,
    this.sectionId,
    this.isPublic,
  });

  factory CouponModel.fromJson(Map<String, dynamic> parsedJson) {
    return CouponModel(
      id: parsedJson["id"],
      discount: parsedJson["discount"],
      discountType: parsedJson["discountType"],
      expiresAt: parsedJson["expiresAt"],
      image: parsedJson["image"] == null ? ((parsedJson["photo"] == null ? "" : parsedJson["photo"])) : parsedJson["image"],
      isEnabled: parsedJson["isEnabled"],
      code: parsedJson["code"],
      providerId: parsedJson["providerId"],
      sectionId: parsedJson["sectionId"],
      isPublic: parsedJson['isPublic'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "providerId": this.providerId,
      "sectionId": this.sectionId,
      "discount": this.discount,
      "discountType": this.discountType,
      "expiresAt": this.expiresAt,
      "image": this.image,
      "isEnabled": this.isEnabled,
      "code": this.code,
      "id": this.id,
      "isPublic": this.isPublic
    };
  }
}

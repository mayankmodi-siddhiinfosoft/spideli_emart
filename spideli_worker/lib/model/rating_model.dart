import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  String? id;
  double? rating;
  String? comment;
  String? orderId;
  String? customerId;
  String? productId;
  String? uname;
  String? profile;
  Timestamp? createdAt;
  String? providerId;

  RatingModel(
      {this.id = '',
      this.comment = '',
      this.rating = 0.0,
      this.orderId = '',
      this.productId = '',
      this.customerId = '',
      this.uname = '',
      this.createdAt,
      this.profile = '',
      this.providerId});

  factory RatingModel.fromJson(Map<String, dynamic> parsedJson) {
    return RatingModel(
      comment: parsedJson['comment'] ?? '',
      rating: parsedJson['rating'].toDouble() ?? 0.0,
      id: parsedJson['Id'] ?? '',
      orderId: parsedJson['orderid'] ?? '',
      productId: parsedJson['productId'] ?? '',
      customerId: parsedJson['CustomerId'] ?? '',
      uname: parsedJson['uname'] ?? '',
      createdAt: parsedJson['createdAt'] ?? Timestamp.now(),
      profile: parsedJson['profile'] ?? '',
      providerId: parsedJson['providerId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'comment': comment,
      'rating': rating,
      'Id': id,
      'orderid': orderId,
      'productId': productId,
      'CustomerId': customerId,
      'uname': uname,
      'profile': profile,
      'createdAt': createdAt,
      'providerId': providerId,
    };
  }
}

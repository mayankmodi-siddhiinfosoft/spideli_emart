import 'package:cloud_firestore/cloud_firestore.dart';

class TopupTranHistoryModel {
  String userId;
  String paymentMethod;
  final amount;
  bool isTopup;
  String orderId;
  String paymentStatus;
  Timestamp date;
  String id;
  String transactionUser;
  String? serviceType;
  String? note;


  TopupTranHistoryModel({
    required this.amount,
    required this.userId,
    required this.orderId,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.date,
    required this.id,
    required this.isTopup,
    required this.serviceType,
    required this.transactionUser,
    required this.note,
  });

  factory TopupTranHistoryModel.fromJson(Map<String, dynamic> parsedJson) {
    return TopupTranHistoryModel(
      amount: parsedJson['amount'] ?? 0.0,
      id: parsedJson['id'],
      isTopup: parsedJson['isTopUp'] ?? false,
      date: parsedJson['date'] ?? '',
      orderId: parsedJson['order_id'] ?? '',
      paymentMethod: parsedJson['payment_method'] ?? '',
      paymentStatus: parsedJson['payment_status'] ?? false,
      userId: parsedJson['user_id'],
      serviceType: parsedJson['serviceType'] ?? '',
      transactionUser: parsedJson['transactionUser'],
      note: parsedJson['note'],
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      'amount': amount,
      'id': id,
      'date': date,
      'isTopUp': isTopup,
      'payment_status': paymentStatus,
      'order_id': orderId,
      'payment_method': paymentMethod,
      'user_id': userId,
      'transactionUser': transactionUser,
      'serviceType': serviceType,
      'note': note,
    };
    return json;
  }
}

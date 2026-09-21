import 'package:cloud_firestore/cloud_firestore.dart';

class WalletTransactionModel {
  String? id;
  String? userId;
  String? paymentMethod;
  double amount;
  bool isTopup;
  String? orderId;
  String subscriptionId;
  String? paymentStatus;
  Timestamp? date;
  String transactionUser;
  String note;

  WalletTransactionModel({
    this.id,
    this.userId,
    this.paymentMethod,
    this.amount = 0.0,
    this.isTopup = false,
    this.orderId,
    this.subscriptionId = '',
    this.paymentStatus,
    this.date,
    this.transactionUser = 'customer',
    this.note = 'Order Amount credited',
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'],
      userId: json['user_id'],
      paymentMethod: json['payment_method'],
      amount: json['amount'] == null || json['amount'] == '' ? 0.0 : double.parse(json['amount'].toString()),
      isTopup: json['isTopUp'] ?? false,
      orderId: json['order_id'],
      subscriptionId: json['subscription_id'] ?? '',
      paymentStatus: json['payment_status'],
      date: json['date'],
      transactionUser: json['transactionUser'] ?? 'customer',
      note: json['note'] ?? 'Order Amount credited',
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['user_id'] = userId;
    data['payment_method'] = paymentMethod;
    data['amount'] = amount;
    data['isTopUp'] = isTopup;
    data['order_id'] = orderId;
    data['subscription_id'] = subscriptionId;
    data['payment_status'] = paymentStatus;
    data['date'] = date;
    data['transactionUser'] = transactionUser;
    data['note'] = note;
    return data;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class WalletTransactionModel {
  /// Region the record belongs to (spec 18.12). History amounts use its
  /// currency; see `RegionService.currencyForRecord`.
  String? regionId;
  String? userId;
  String? paymentMethod;
  double? amount;
  bool? isTopup;
  String? orderId;
  String? paymentStatus;
  Timestamp? date;
  String? id;
  String? transactionUser;
  String? note;
  String? serviceType;

  WalletTransactionModel({
    this.userId,
    this.paymentMethod,
    this.amount,
    this.isTopup,
    this.orderId,
    this.paymentStatus,
    this.date,
    this.id,
    this.transactionUser,
    this.note,
    this.serviceType,
    this.regionId,
  });

  WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    regionId = (json['regionId'] == null || json['regionId'].toString().isEmpty) ? null : json['regionId'].toString();
    id = json['id'];
    userId = json['user_id'];
    paymentMethod = json['payment_method'];
    amount = double.parse("${json['amount'] ?? 0.0}");
    isTopup = json['isTopUp'];
    orderId = json['order_id'];
    paymentStatus = json['payment_status'];
    date = json['date'];
    transactionUser = json['transactionUser'] ?? 'customer';
    note = json['note'] ?? 'Wallet Top-up';
    serviceType = json['serviceType'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['user_id'] = userId;
    data['payment_method'] = paymentMethod;
    data['amount'] = amount;
    data['isTopUp'] = isTopup;
    data['order_id'] = orderId;
    data['payment_status'] = paymentStatus;
    data['date'] = date;
    data['transactionUser'] = transactionUser;
    data['note'] = note;
    if (regionId != null) data['regionId'] = regionId;
    return data;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Transaction types for company cash ledger
class CompanyCashTransactionType {
  static const String collection = 'collection'; // COD collected from customer
  static const String settlement = 'settlement'; // Cash handed over to owner
  static const String adjustment = 'adjustment'; // Audited owner adjustment
}

/// Transaction statuses for company cash ledger
class CompanyCashTransactionStatus {
  static const String confirmed = 'confirmed';
  static const String pending = 'pending';
  static const String rejected = 'rejected';
}

/// Represents an auditable entry in `company_cash_ledger`.
/// Outstanding Cash = Total Confirmed Cash Collections - Total Confirmed Cash Settlements.
class CompanyCashTransactionModel {
  String? id;
  String? ownerId;
  String? driverId;
  String? driverName;
  String? orderId;
  String? orderType; // 'parcel', 'rental', 'delivery'
  String? type; // collection, settlement, adjustment
  double? amount;
  String? paymentMethod;
  String? status; // confirmed, pending, rejected
  Timestamp? createdAt;
  Timestamp? confirmedAt;
  String? notes;
  String? verifiedBy; // Owner ID who verified
  String? rejectionReason;
  bool? isCredit; // For adjustments: true adds to balance, false reduces

  CompanyCashTransactionModel({
    this.id,
    this.ownerId,
    this.driverId,
    this.driverName,
    this.orderId,
    this.orderType,
    this.type,
    this.amount,
    this.paymentMethod,
    this.status,
    this.createdAt,
    this.confirmedAt,
    this.notes,
    this.verifiedBy,
    this.rejectionReason,
    this.isCredit,
  });

  /// [items] newest first by `createdAt` (a record without one last).
  static List<CompanyCashTransactionModel> newestFirst(Iterable<CompanyCashTransactionModel> items) {
    final List<CompanyCashTransactionModel> list = items.toList();
    list.sort((a, b) => (b.createdAt?.millisecondsSinceEpoch ?? -1).compareTo(a.createdAt?.millisecondsSinceEpoch ?? -1));
    return list;
  }

  factory CompanyCashTransactionModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CompanyCashTransactionModel();
    return CompanyCashTransactionModel(
      id: json['id']?.toString(),
      ownerId: json['ownerId']?.toString(),
      driverId: json['driverId']?.toString(),
      driverName: json['driverName']?.toString(),
      orderId: json['orderId']?.toString(),
      orderType: json['orderType']?.toString(),
      type: json['type']?.toString(),
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      paymentMethod: json['paymentMethod']?.toString(),
      status: json['status']?.toString(),
      createdAt: json['createdAt'] is Timestamp ? json['createdAt'] as Timestamp : null,
      confirmedAt: json['confirmedAt'] is Timestamp ? json['confirmedAt'] as Timestamp : null,
      notes: json['notes']?.toString(),
      verifiedBy: json['verifiedBy']?.toString(),
      rejectionReason: json['rejectionReason']?.toString(),
      isCredit: json['isCredit'] is bool ? json['isCredit'] as bool : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (ownerId != null) 'ownerId': ownerId,
      if (driverId != null) 'driverId': driverId,
      if (driverName != null) 'driverName': driverName,
      if (orderId != null) 'orderId': orderId,
      if (orderType != null) 'orderType': orderType,
      if (type != null) 'type': type,
      'amount': amount ?? 0.0,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      'status': status ?? CompanyCashTransactionStatus.confirmed,
      if (createdAt != null) 'createdAt': createdAt,
      if (confirmedAt != null) 'confirmedAt': confirmedAt,
      if (notes != null) 'notes': notes,
      if (verifiedBy != null) 'verifiedBy': verifiedBy,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (isCredit != null) 'isCredit': isCredit,
    };
  }
}

/// Aggregated summary for a driver or company.
class DriverCashSummary {
  final double totalCollected;
  final double totalSettled;
  final double pendingSettlement;
  final double outstandingBalance;

  const DriverCashSummary({
    this.totalCollected = 0.0,
    this.totalSettled = 0.0,
    this.pendingSettlement = 0.0,
    this.outstandingBalance = 0.0,
  });

  factory DriverCashSummary.fromTransactions(List<CompanyCashTransactionModel> transactions) {
    double collected = 0.0;
    double settled = 0.0;
    double pending = 0.0;

    for (final tx in transactions) {
      final amt = tx.amount ?? 0.0;
      if (tx.type == CompanyCashTransactionType.collection && tx.status == CompanyCashTransactionStatus.confirmed) {
        collected += amt;
      } else if (tx.type == CompanyCashTransactionType.settlement) {
        if (tx.status == CompanyCashTransactionStatus.confirmed) {
          settled += amt;
        } else if (tx.status == CompanyCashTransactionStatus.pending) {
          pending += amt;
        }
      } else if (tx.type == CompanyCashTransactionType.adjustment && tx.status == CompanyCashTransactionStatus.confirmed) {
        if (tx.isCredit == true) {
          collected += amt; // Positive balance adjustment
        } else {
          settled += amt; // Deductive balance adjustment
        }
      }
    }

    final double outstanding = (collected - settled).clamp(0.0, double.infinity);
    return DriverCashSummary(
      totalCollected: collected,
      totalSettled: settled,
      pendingSettlement: pending,
      outstandingBalance: outstanding,
    );
  }
}

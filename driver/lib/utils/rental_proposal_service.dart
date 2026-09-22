import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/utils/fire_store_utils.dart';

/// RentalCar price proposal (spec 4.9, APP-CONTRACT): the customer proposes
/// `priceProposal.amount`; the car's driver/owner accepts, rejects or counters.
/// Every response appends to `priceProposal.history`.
///
/// Each write runs in a transaction that re-reads the order and only proceeds
/// while the proposal is still "pending", so two drivers (or a driver and the
/// admin) cannot both answer the same proposal. Writes are field updates only.
class RentalProposalService {
  RentalProposalService._();

  static DocumentReference<Map<String, dynamic>> _ref(String orderId) => FireStoreUtils.fireStore.collection(CollectionName.rentalOrders).doc(orderId);

  /// Returns null on success, else a user-facing error.
  static Future<String?> _respond(String orderId, Map<String, dynamic> Function(Map<String, dynamic> order, Map<String, dynamic> proposal) build) async {
    try {
      return await FireStoreUtils.fireStore.runTransaction<String?>((tx) async {
        final snap = await tx.get(_ref(orderId));
        final data = snap.data();
        if (data == null) return "Booking not found";
        final raw = data['priceProposal'];
        if (raw is! Map || raw['status']?.toString() != 'pending') return "This price proposal was already answered";
        final proposal = Map<String, dynamic>.from(raw);
        tx.update(_ref(orderId), build(data, proposal));
        return null;
      });
    } catch (e) {
      log("RentalProposalService failed: $e");
      return "Something went wrong. Please try again.";
    }
  }

  static List<dynamic> _history(Map<String, dynamic> proposal, Map<String, dynamic> entry) {
    final history = proposal['history'] is List ? List<dynamic>.from(proposal['history']) : <dynamic>[];
    history.add(entry);
    return history;
  }

  /// Accept: the agreed amount becomes the booking price (`subTotal`); the
  /// listed price is kept in `listedPrice` (written once, never overwritten).
  static Future<String?> accept(String orderId) {
    return _respond(orderId, (order, proposal) {
      final amount = num.tryParse(proposal['amount']?.toString() ?? '');
      final now = Timestamp.now();
      proposal
        ..['status'] = 'accepted'
        ..['respondedBy'] = 'driver'
        ..['respondedAt'] = now
        ..['history'] = _history(proposal, {'by': 'driver', 'amount': amount, 'message': 'accepted', 'at': now});
      return {
        'priceProposal': proposal,
        if (amount != null) 'subTotal': amount.toString(),
        if (order['listedPrice'] == null) 'listedPrice': order['subTotal'],
      };
    });
  }

  static Future<String?> reject(String orderId, {String? message}) {
    return _respond(orderId, (order, proposal) {
      final now = Timestamp.now();
      proposal
        ..['status'] = 'rejected'
        ..['respondedBy'] = 'driver'
        ..['respondedAt'] = now
        ..['history'] = _history(proposal, {
          'by': 'driver',
          'amount': num.tryParse(proposal['amount']?.toString() ?? ''),
          'message': (message == null || message.trim().isEmpty) ? 'rejected' : message.trim(),
          'at': now,
        });
      return {'priceProposal': proposal};
    });
  }

  static Future<String?> counter(String orderId, {required num amount, String? message}) {
    return _respond(orderId, (order, proposal) {
      final now = Timestamp.now();
      proposal
        ..['status'] = 'countered'
        ..['counterAmount'] = amount
        ..['respondedBy'] = 'driver'
        ..['respondedAt'] = now
        ..['history'] = _history(proposal, {
          'by': 'driver',
          'amount': amount,
          if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
          'at': now,
        });
      return {'priceProposal': proposal};
    });
  }
}

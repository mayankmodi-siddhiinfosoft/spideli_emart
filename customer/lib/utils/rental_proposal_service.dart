import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:get/get.dart';

/// Customer side of the RentalCar price proposal (spec 4.9 / 7.11,
/// APP-CONTRACT "As built in the Driver app"):
/// - the customer proposes `priceProposal.amount` when booking ([initial]);
/// - the car's driver/owner accepts, rejects or counters (Driver app);
/// - on "countered" the customer accepts the counter ([acceptCounter]) or
///   rejects it ([rejectCounter]);
/// - on "rejected" the customer keeps the listed price ([keepListedPrice]) or
///   proposes again ([proposeAgain]).
///
/// Every write is a field update inside a transaction that re-reads the order
/// and only proceeds while the expected proposal status (and, for a new
/// proposal, the booking's "Order Placed" status) still holds - the Driver app
/// guards its answers the same way. Every step appends to `history`.
class RentalProposalService {
  RentalProposalService._();

  static DocumentReference<Map<String, dynamic>> _ref(String orderId) => FireStoreUtils.fireStore.collection(CollectionName.rentalOrders).doc(orderId);

  /// `priceProposal` written when the booking is created.
  static Map<String, dynamic> initial({required num amount, String? message}) {
    final now = Timestamp.now();
    final text = message?.trim() ?? '';
    return {
      'amount': amount,
      'message': text,
      'status': 'pending',
      'history': [
        {'by': 'customer', 'amount': amount, if (text.isNotEmpty) 'message': text, 'at': now},
      ],
    };
  }

  static List<dynamic> _history(Map<String, dynamic> proposal, Map<String, dynamic> entry) {
    final history = proposal['history'] is List ? List<dynamic>.from(proposal['history']) : <dynamic>[];
    history.add(entry);
    return history;
  }

  /// Returns null on success, else a message for the customer.
  static Future<String?> _update(
    String orderId, {
    required String expectedStatus,
    bool requireOpenBooking = false,
    required Map<String, dynamic> Function(Map<String, dynamic> order, Map<String, dynamic> proposal) build,
  }) async {
    try {
      return await FireStoreUtils.fireStore.runTransaction<String?>((tx) async {
        final snap = await tx.get(_ref(orderId));
        final data = snap.data();
        if (data == null) return "Booking not found".tr;
        final raw = data['priceProposal'];
        if (raw is! Map || raw['status']?.toString() != expectedStatus) return "This price proposal has changed. Please check the latest status.".tr;
        if (requireOpenBooking && data['status']?.toString() != Constant.orderPlaced) return "This booking can no longer be negotiated".tr;
        tx.update(_ref(orderId), build(data, Map<String, dynamic>.from(raw)));
        return null;
      });
    } catch (e) {
      log("RentalProposalService failed: $e");
      return "Something went wrong. Please try again.".tr;
    }
  }

  /// Accept the driver's counter: the agreed amount becomes the booking price
  /// (`subTotal`); the listed price is kept once in `listedPrice`.
  static Future<String?> acceptCounter(String orderId) {
    return _update(
      orderId,
      expectedStatus: 'countered',
      // A cancelled booking must not have its price rewritten.
      requireOpenBooking: true,
      build: (order, proposal) {
        final counter = num.tryParse(proposal['counterAmount']?.toString() ?? '');
        final now = Timestamp.now();
        proposal
          ..['status'] = 'accepted'
          ..['history'] = _history(proposal, {'by': 'customer', 'amount': counter, 'message': 'accepted', 'at': now});
        return {
          'priceProposal': proposal,
          if (counter != null) 'subTotal': counter.toString(),
          if (order['listedPrice'] == null) 'listedPrice': order['subTotal'],
        };
      },
    );
  }

  /// Reject the driver's counter. The booking stays open at the listed price;
  /// the customer may propose again.
  static Future<String?> rejectCounter(String orderId) {
    return _update(
      orderId,
      expectedStatus: 'countered',
      // A cancelled booking must not have its price rewritten.
      requireOpenBooking: true,
      build: (order, proposal) {
        final counter = num.tryParse(proposal['counterAmount']?.toString() ?? '');
        proposal
          ..['status'] = 'rejected'
          ..['history'] = _history(proposal, {'by': 'customer', 'amount': counter, 'message': 'rejected', 'at': Timestamp.now()});
        return {'priceProposal': proposal};
      },
    );
  }

  /// After a rejection: a new proposal (back to "pending").
  static Future<String?> proposeAgain(String orderId, {required num amount, String? message}) {
    return _update(
      orderId,
      expectedStatus: 'rejected',
      requireOpenBooking: true,
      build: (order, proposal) {
        final text = message?.trim() ?? '';
        proposal
          ..remove('counterAmount')
          ..remove('respondedBy')
          ..remove('respondedAt')
          ..['amount'] = amount
          ..['message'] = text
          ..['status'] = 'pending'
          ..['history'] = _history(proposal, {'by': 'customer', 'amount': amount, if (text.isNotEmpty) 'message': text, 'at': Timestamp.now()});
        return {'priceProposal': proposal};
      },
    );
  }

  /// After a rejection: the customer confirms booking at the listed price.
  /// Nothing about the price changes (the booking already carries the listed
  /// `subTotal`); the choice is recorded in the history for the driver.
  static Future<String?> keepListedPrice(String orderId) {
    return _update(
      orderId,
      expectedStatus: 'rejected',
      requireOpenBooking: true,
      build: (order, proposal) {
        proposal['history'] = _history(proposal, {
          'by': 'customer',
          'amount': num.tryParse(order['subTotal']?.toString() ?? ''),
          'message': 'book at listed price',
          'at': Timestamp.now(),
        });
        return {'priceProposal': proposal};
      },
    );
  }
}

/// Customer cancellation of a rental booking with the mandatory reason
/// (APP-CONTRACT). Field update only, guarded by the booking's current status
/// so a trip that has just started is not cancelled from a stale screen.
class RentalBookingCancellation {
  RentalBookingCancellation._();

  static bool isCancellable(String? status) => status == Constant.orderPlaced || status == Constant.driverAccepted;

  /// Returns null on success, else a message for the customer.
  static Future<String?> cancel(String orderId, Map<String, dynamic> reasonFields) async {
    final ref = FireStoreUtils.fireStore.collection(CollectionName.rentalOrders).doc(orderId);
    try {
      return await FireStoreUtils.fireStore.runTransaction<String?>((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data();
        if (data == null) return "Booking not found".tr;
        if (!isCancellable(data['status']?.toString())) return "This booking can no longer be cancelled".tr;
        tx.update(ref, {'status': Constant.orderCancelled, ...reasonFields});
        return null;
      });
    } catch (e) {
      log("RentalBookingCancellation failed: $e");
      return "Failed to cancel booking".tr;
    }
  }
}

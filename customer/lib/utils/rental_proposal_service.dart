import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/booking_status_tabs.dart';
import 'package:get/get.dart';

/// Customer side of the RentalCar price proposal (spec 4.9 / 7.11,
/// APP-CONTRACT "As built in the Driver app"):
/// - the customer proposes `priceProposal.amount` when booking ([initial]);
/// - the car's driver/owner accepts, rejects or counters (Driver app);
/// - on "countered" the customer accepts the counter ([acceptCounter]) - only
///   while the booking is still offered to the driver who made it
///   ([canAcceptCounter], `priceProposal.counteredBy`) - or rejects it
///   ([rejectCounter]);
/// - on "rejected" the customer keeps the listed price ([keepListedPrice]) or
///   proposes again ([proposeAgain]).
///
/// Every write is a field update inside a transaction that re-reads the order
/// and only proceeds while the expected proposal status (and the booking
/// still being open, [openBookingStatuses]) still holds - the Driver app
/// guards its answers the same way. Every step appends to `history`.
class RentalProposalService {
  RentalProposalService._();

  /// A booking no driver has taken yet, so its price can still be negotiated:
  /// "Order Placed", and the dispatch states `rentalDispatch` writes at once
  /// ("Driver Pending" while a driver is offered it, "Driver Rejected" while
  /// the next one is looked for).
  static const Set<String> openBookingStatuses = {Constant.orderPlaced, Constant.driverPending, Constant.driverRejected};

  static bool isOpenBooking(String? status) => openBookingStatuses.contains(status);

  /// The uid of the driver who made the open counter-offer: the Driver app
  /// writes it as `priceProposal.counteredBy` with its counter (`respondedBy`
  /// only says "driver", a role). Null when the counter does not say.
  static String? counteredBy(Map<dynamic, dynamic>? proposal) {
    final String id = (proposal?['counteredBy'] ?? '').toString().trim();
    return id.isEmpty ? null : id;
  }

  /// Whether the customer may ACCEPT the counter-offer in [proposal] of a
  /// booking in [status] whose `driverId` is [driverId]: only while the
  /// booking is still offered ("Driver Pending") to the driver who made it.
  ///
  /// The dispatch offers a booking to one driver at a time, for
  /// `driverOrderAcceptRejectDuration` seconds; once that driver rejected it
  /// or let the offer expire ("Driver Rejected", then the next driver at
  /// "Driver Pending") the price would be agreed with a driver who is no
  /// longer on the booking and can never be offered it again. A counter that
  /// does not name its driver cannot be tied to the current one either.
  static bool canAcceptCounter({required String? status, required String? driverId, required Map<dynamic, dynamic>? proposal}) {
    if (proposal?['status']?.toString() != 'countered') return false;
    final String? by = counteredBy(proposal);
    return by != null && status == Constant.driverPending && (driverId ?? '').trim() == by;
  }

  /// Whether the customer may REJECT the counter-offer in [proposal]: on any
  /// open booking. Declining agrees to no price, and it is how a counter whose
  /// driver has left the booking is cleared - the Driver app does not let the
  /// next driver accept while a counter is waiting for the customer.
  static bool canRejectCounter({required String? status, required Map<dynamic, dynamic>? proposal}) =>
      proposal?['status']?.toString() == 'countered' && isOpenBooking(status);

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
    String? Function(Map<String, dynamic> order, Map<String, dynamic> proposal)? refuse,
    required Map<String, dynamic> Function(Map<String, dynamic> order, Map<String, dynamic> proposal) build,
  }) async {
    try {
      return await FireStoreUtils.fireStore.runTransaction<String?>((tx) async {
        final snap = await tx.get(_ref(orderId));
        final data = snap.data();
        if (data == null) return "Booking not found".tr;
        final raw = data['priceProposal'];
        if (raw is! Map || raw['status']?.toString() != expectedStatus) return "This price proposal has changed. Please check the latest status.".tr;
        if (requireOpenBooking && !isOpenBooking(data['status']?.toString())) return "This booking can no longer be negotiated".tr;
        final Map<String, dynamic> proposal = Map<String, dynamic>.from(raw);
        final String? refusal = refuse?.call(data, proposal);
        if (refusal != null) return refusal;
        tx.update(_ref(orderId), build(data, proposal));
        return null;
      });
    } catch (e) {
      log("RentalProposalService failed: $e");
      return "Something went wrong. Please try again.".tr;
    }
  }

  /// Accept the driver's counter: the agreed amount becomes the booking price
  /// (`subTotal`); the listed price is kept once in `listedPrice`. Only while
  /// the driver who made it is still the one offered the booking
  /// ([canAcceptCounter]), checked on the order as it is now.
  static Future<String?> acceptCounter(String orderId) {
    return _update(
      orderId,
      expectedStatus: 'countered',
      // A cancelled booking must not have its price rewritten.
      requireOpenBooking: true,
      refuse: (order, proposal) => canAcceptCounter(
        status: order['status']?.toString(),
        driverId: (order['driverId'] ?? order['driverID'])?.toString(),
        proposal: proposal,
      )
          ? null
          : "This counter-offer has expired: the driver who made it is no longer on your booking.".tr,
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
  /// the customer may propose again. Also a counter whose driver has left the
  /// booking ([canRejectCounter]): that clears it for the next driver.
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

  /// No trip has started: still waiting for a driver (Placed, or the
  /// dispatch's Driver Pending / Driver Rejected), or a driver has accepted
  /// but not picked the car up yet.
  static const Set<String> cancellableStatuses = {Constant.orderPlaced, Constant.driverPending, Constant.driverRejected, Constant.driverAccepted};

  static bool isCancellable(String? status) => cancellableStatuses.contains(status);

  /// Returns null on success, else a message for the customer.
  static Future<String?> cancel(String orderId, Map<String, dynamic> reasonFields) async {
    final ref = FireStoreUtils.fireStore.collection(CollectionName.rentalOrders).doc(orderId);
    try {
      return await FireStoreUtils.fireStore.runTransaction<String?>((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data();
        if (data == null) return "Booking not found".tr;
        if (!isCancellable(data['status']?.toString())) return "This booking can no longer be cancelled".tr;
        // Before any driver accepted: the driver the dispatch was only
        // offering it to comes off the booking. An accepted driver stays.
        tx.update(ref, {'status': Constant.orderCancelled, ...BookingStatusTabs.offeredDriverCleared(data['status']?.toString()), ...reasonFields});
        return null;
      });
    } catch (e) {
      log("RentalBookingCancellation failed: $e");
      return "Failed to cancel booking".tr;
    }
  }
}

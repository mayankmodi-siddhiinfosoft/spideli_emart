import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cab_ride_options.dart';
import 'package:customer/controllers/order_controller.dart';
import 'package:customer/models/cab_order_model.dart';
import 'package:customer/models/parcel_order_model.dart';
import 'package:customer/models/rental_order_model.dart';
import 'package:customer/service/parcel_cancellation.dart';
import 'package:customer/utils/booking_status_tabs.dart';
import 'package:customer/utils/rental_proposal_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Driver dispatch belongs to the Cloud Functions (DRIVER_DISPATCH_DOCUMENTATION.md):
/// "Driver Pending" while a driver is offered the order, "Driver Rejected"
/// after a reject / timeout, which re-dispatches. Neither is a cancellation,
/// and the driver id written at "Driver Pending" is not the order's driver.
void main() {
  group('booking history tabs', () {
    test('rides: both dispatch states wait with the new bookings, never as cancelled', () {
      expect(BookingStatusTabs.rideNew, containsAll(<String>[Constant.orderPlaced, Constant.driverPending, Constant.driverRejected]));
      expect(BookingStatusTabs.cancelled, {Constant.orderRejected, Constant.orderCancelled});
      expect(BookingStatusTabs.cancelled.contains(Constant.driverRejected), isFalse);
      expect(BookingStatusTabs.onGoing, {Constant.driverAccepted, Constant.orderShipped, Constant.orderInTransit});
    });

    test('rentals', () {
      expect(BookingStatusTabs.rentalNew, {Constant.orderPlaced, Constant.orderAccepted, Constant.driverPending, Constant.driverRejected});
    });

    test('parcels: Driver Pending is not "In Transit" before a driver accepted it', () {
      expect(BookingStatusTabs.parcelNew, {Constant.orderPlaced, ParcelShipping.quoteRequestedStatus, Constant.driverPending, Constant.driverRejected});
      expect(BookingStatusTabs.parcelInTransit, {Constant.orderAccepted, Constant.driverAccepted, Constant.orderShipped, Constant.orderInTransit});
    });

    test('every status lands in exactly one tab', () {
      for (final Set<String> news in [BookingStatusTabs.rideNew, BookingStatusTabs.rentalNew, BookingStatusTabs.parcelNew]) {
        final Set<String> live = news == BookingStatusTabs.parcelNew ? BookingStatusTabs.parcelInTransit : BookingStatusTabs.onGoing;
        for (final Set<String> other in [live, BookingStatusTabs.completed, BookingStatusTabs.cancelled]) {
          expect(news.intersection(other), isEmpty);
        }
      }
    });

    test('the chip reads "Looking for a driver" for the dispatch states', () {
      expect(BookingStatusTabs.label(Constant.driverPending), 'Looking for a driver');
      expect(BookingStatusTabs.label(Constant.driverRejected), 'Looking for a driver');
      expect(BookingStatusTabs.label(Constant.orderShipped), Constant.orderShipped);
      expect(BookingStatusTabs.label(null), '');
    });
  });

  test('My Orders "In Progress" lists every live dispatch state', () {
    expect(
      OrderController.inProgressStatuses,
      {Constant.orderAccepted, Constant.driverPending, Constant.driverAccepted, Constant.driverRejected, Constant.orderShipped, Constant.orderInTransit},
    );
  });

  group('the driver of a booking', () {
    test('only once a driver accepted it', () {
      expect(BookingStatusTabs.hasAssignedDriver(Constant.driverPending, 'd1', acceptedDriverId: null), isFalse, reason: 'only offered');
      expect(BookingStatusTabs.hasAssignedDriver(Constant.orderPlaced, 'd1', acceptedDriverId: null), isFalse);
      expect(BookingStatusTabs.hasAssignedDriver(Constant.driverRejected, 'd1', acceptedDriverId: null), isFalse);
      expect(BookingStatusTabs.hasAssignedDriver(Constant.driverAccepted, 'd1', acceptedDriverId: 'd1'), isTrue);
      expect(BookingStatusTabs.hasAssignedDriver(Constant.orderShipped, 'd1', acceptedDriverId: 'd1'), isTrue);
      expect(BookingStatusTabs.hasAssignedDriver(Constant.orderCompleted, 'd1', acceptedDriverId: 'd1'), isTrue);
      // A live or completed booking keeps today's rule, with or without a snapshot.
      expect(BookingStatusTabs.hasAssignedDriver(Constant.orderCompleted, 'd1', acceptedDriverId: null), isTrue);
    });

    test('never without an id', () {
      expect(BookingStatusTabs.hasAssignedDriver(Constant.driverAccepted, null, acceptedDriverId: 'd1'), isFalse);
      expect(BookingStatusTabs.hasAssignedDriver(Constant.driverAccepted, '  ', acceptedDriverId: 'd1'), isFalse);
    });

    test('a booking cancelled while it was only offered names no driver', () {
      for (final String status in [Constant.orderRejected, Constant.orderCancelled]) {
        // Cancelled at "Driver Pending": the offered driver's id, no snapshot.
        expect(BookingStatusTabs.hasAssignedDriver(status, 'd1', acceptedDriverId: null), isFalse, reason: status);
        // ... or the snapshot of an earlier driver who handed it back.
        expect(BookingStatusTabs.hasAssignedDriver(status, 'd2', acceptedDriverId: 'd1'), isFalse, reason: status);
        expect(BookingStatusTabs.driverAccepted(status, 'd1', null), isFalse, reason: status);
        // Cancelled after d1 accepted it: d1 wrote the snapshot.
        expect(BookingStatusTabs.hasAssignedDriver(status, 'd1', acceptedDriverId: 'd1'), isTrue, reason: status);
        expect(BookingStatusTabs.driverAccepted(status, 'd1', 'd1'), isTrue, reason: status);
      }
    });

    test("a customer's cancel before any acceptance takes the offered driver off", () {
      for (final String? status in [Constant.orderPlaced, Constant.driverPending, Constant.driverRejected, ParcelShipping.quoteRequestedStatus]) {
        expect(BookingStatusTabs.offeredDriverCleared(status), {'driverId': null, 'driverID': null}, reason: status);
      }
      // Once a driver accepted (rental cancel at "Driver Accepted"), they stay.
      expect(BookingStatusTabs.offeredDriverCleared(Constant.driverAccepted), isEmpty);
      expect(BookingStatusTabs.offeredDriverCleared(Constant.orderAccepted), isEmpty);
    });
  });

  group('"your driver cancelled" while the ride is back with the dispatch', () {
    CabOrderModel ride(List<String> rejectedBy, List<Map<String, dynamic>> rejections) => CabOrderModel.fromJson({
          'id': 'r1',
          'status': Constant.driverRejected,
          'rejectedByDrivers': rejectedBy,
          'driverRejections': rejections,
        });
    final Map<String, dynamic> d1Cancelled = {'driverId': 'd1', 'reason': 'Car broke down', 'afterAccept': true};

    test('right after the accepted driver cancelled', () {
      expect(ride(['d1'], [d1Cancelled]).isDriverCancelledRedispatch, isTrue);
    });

    test("not again after a later driver's silent timeout", () {
      // d2 was offered the ride and let the window expire: excluded, no entry.
      expect(ride(['d1', 'd2'], [d1Cancelled]).isDriverCancelledRedispatch, isFalse);
    });

    test('not after a pass, and not for an offer that was only declined', () {
      expect(ride(['d1', 'd2'], [d1Cancelled, {'driverId': 'd2', 'reason': 'Too far', 'afterAccept': false}]).isDriverCancelledRedispatch, isFalse);
      expect(ride(['d1'], [{'driverId': 'd1', 'reason': 'Too far', 'afterAccept': false}]).isDriverCancelledRedispatch, isFalse);
    });

    test('a ride without an exclusion list keeps the entry rule; other statuses never', () {
      expect(ride([], [d1Cancelled]).isDriverCancelledRedispatch, isTrue);
      expect((ride(['d1'], [d1Cancelled])..status = Constant.driverPending).isDriverCancelledRedispatch, isFalse);
    });
  });

  group('rentals while the dispatch runs', () {
    test("a counter-offer is accepted only while its driver is the one offered the booking", () {
      final Map<String, dynamic> byD1 = {'status': 'countered', 'counterAmount': 90, 'respondedBy': 'driver', 'counteredBy': 'd1'};
      expect(RentalProposalService.counteredBy(byD1), 'd1');
      expect(RentalProposalService.canAcceptCounter(status: Constant.driverPending, driverId: 'd1', proposal: byD1), isTrue);
      // d1's window closed (reject / timeout), then the next driver is offered it.
      expect(RentalProposalService.canAcceptCounter(status: Constant.driverRejected, driverId: null, proposal: byD1), isFalse);
      expect(RentalProposalService.canAcceptCounter(status: Constant.driverPending, driverId: 'd2', proposal: byD1), isFalse);
      expect(RentalProposalService.canAcceptCounter(status: Constant.orderPlaced, driverId: null, proposal: byD1), isFalse);
      // A counter that does not name its driver cannot be tied to anyone.
      final Map<String, dynamic> unnamed = {'status': 'countered', 'counterAmount': 90, 'respondedBy': 'driver'};
      expect(RentalProposalService.counteredBy(unnamed), isNull);
      expect(RentalProposalService.canAcceptCounter(status: Constant.driverPending, driverId: 'd1', proposal: unnamed), isFalse);
      // Not a counter at all.
      expect(RentalProposalService.canAcceptCounter(status: Constant.driverPending, driverId: 'd1', proposal: {...byD1, 'status': 'pending'}), isFalse);
      expect(RentalProposalService.canAcceptCounter(status: Constant.driverPending, driverId: 'd1', proposal: null), isFalse);
    });

    test('any open counter may be declined, which clears a stale one', () {
      final Map<String, dynamic> byD1 = {'status': 'countered', 'counteredBy': 'd1'};
      for (final String status in [Constant.orderPlaced, Constant.driverPending, Constant.driverRejected]) {
        expect(RentalProposalService.canRejectCounter(status: status, proposal: byD1), isTrue, reason: status);
      }
      expect(RentalProposalService.canRejectCounter(status: Constant.driverAccepted, proposal: byD1), isFalse);
      expect(RentalProposalService.canRejectCounter(status: Constant.driverPending, proposal: {'status': 'rejected'}), isFalse);
    });

    test('the price can still be negotiated', () {
      for (final String status in [Constant.orderPlaced, Constant.driverPending, Constant.driverRejected]) {
        expect(RentalProposalService.isOpenBooking(status), isTrue, reason: status);
      }
      for (final String status in [Constant.driverAccepted, Constant.orderInTransit, Constant.orderCancelled, Constant.orderCompleted]) {
        expect(RentalProposalService.isOpenBooking(status), isFalse, reason: status);
      }
    });

    test('the booking stays cancellable until the trip starts', () {
      for (final String status in [Constant.orderPlaced, Constant.driverPending, Constant.driverRejected, Constant.driverAccepted]) {
        expect(RentalBookingCancellation.isCancellable(status), isTrue, reason: status);
      }
      for (final String status in [Constant.orderInTransit, Constant.orderCompleted, Constant.orderCancelled]) {
        expect(RentalBookingCancellation.isCancellable(status), isFalse, reason: status);
      }
    });
  });

  group('parcels while the dispatch runs', () {
    test('cancellable placed, quoted or with the dispatch, before hand-over', () {
      for (final String status in [Constant.orderPlaced, ParcelShipping.quoteRequestedStatus, Constant.driverPending, Constant.driverRejected]) {
        expect(ParcelCancellation.canCancel(status, ParcelShipping.created), isTrue, reason: status);
        expect(ParcelCancellation.canCancel(status, null), isTrue, reason: status);
      }
      expect(ParcelCancellation.canCancel(Constant.driverAccepted, ParcelShipping.created), isFalse);
      expect(ParcelCancellation.canCancel(Constant.driverPending, ParcelShipping.collected), isFalse, reason: 'handed over');
    });

    test('the refusal says why', () {
      expect(ParcelCancellation.refusal(Constant.driverAccepted, ParcelShipping.created), 'A driver has already accepted this parcel');
      expect(ParcelCancellation.refusal(Constant.orderCancelled, ParcelShipping.cancelled), 'This parcel order is no longer active');
      expect(ParcelCancellation.refusal(Constant.driverPending, ParcelShipping.collected), 'This parcel has already been handed over and can no longer be cancelled.');
    });

    ParcelOrderModel paid({String method = 'wallet', bool sms = true}) => ParcelOrderModel(
      status: Constant.driverPending,
      subTotal: '1000',
      discount: '100',
      platformFee: '20',
      paymentMethod: method,
      paymentCollectByReceiver: false,
    )
      ..parcelScopeTax = 30
      ..sendReceiverSms = sms
      ..smsCharge = sms ? 50 : 0;

    test('one refund rule for both cancel paths: everything charged while no receiver text went out', () {
      // 1000 - 100 + 20 + 30 (scope tax) + 50 (SMS fee, nothing sent yet).
      expect(ParcelCancellation.refundAmount(paid()), 1000);
      expect(ParcelCancellation.refundAmount(paid(sms: false)), 950);
      // `eventsEnabled` without "placed", or a failed send: not marked sent.
      expect(ParcelCancellation.refundAmount(paid()..smsSent = {'placed': false}), 1000);
      expect(ParcelCancellation.refundAmount(paid()..smsSent = {}), 1000);
    });

    test('the receiver-SMS fee is kept once the trigger sent a text', () {
      expect(ParcelCancellation.refundAmount(paid()..smsSent = {'placed': true}), 950);
      expect(ParcelCancellation.refundAmount(paid()..smsSent = {'placed': Timestamp.now()}), 950);
      expect(ParcelCancellation.keepsReceiverSmsFee(paid()..smsSent = {'placed': true}), isTrue);
      expect(ParcelCancellation.keepsReceiverSmsFee(paid()), isFalse);
      // Read from the order as the trigger wrote it.
      final ParcelOrderModel read = ParcelOrderModel.fromJson({
        'id': 'p1',
        'status': Constant.driverPending,
        'subTotal': '1000',
        'payment_method': 'wallet',
        'paymentCollectByReceiver': false,
        'sendReceiverSms': true,
        'smsCharge': 50,
        'smsSent': {'placed': true},
      });
      expect(read.receiverSmsWasSent, isTrue);
      expect(ParcelCancellation.refundAmount(read), 1000);
    });

    test('nothing to refund for cash, receiver-pays or an unpaid quote', () {
      expect(ParcelCancellation.refundAmount(paid(method: 'cod')), 0);
      expect(ParcelCancellation.refundAmount(paid(method: '')), 0);
      expect(ParcelCancellation.refundAmount(paid()..paymentCollectByReceiver = true), 0);
      expect(ParcelCancellation.refundAmount(paid()..status = ParcelShipping.quoteRequestedStatus), 0);
    });
  });

  group('rides that end while the customer waits', () {
    test('a ride that is already over is refused as such, not as "accepted"', () {
      expect(CabRideCancellation.refusal(Constant.orderCancelled), 'This ride is no longer active');
      expect(CabRideCancellation.refusal(Constant.orderRejected), 'This ride is no longer active');
      expect(CabRideCancellation.refusal(Constant.driverAccepted), 'A driver has already accepted this ride');
    });

    test('the toast comes from the cancellation fields, never a fixed text', () {
      final CabOrderModel byAdmin = CabOrderModel(status: Constant.orderCancelled)
        ..cancelledBy = 'admin'
        ..cancelReason = 'No driver available'
        ..cancelAction = 'cancelled';
      expect(CabRideCancellation.endedMessage(byAdmin), 'Cancelled by Admin: No driver available');

      final CabOrderModel auto = CabOrderModel(status: Constant.orderCancelled);
      expect(CabRideCancellation.endedMessage(auto), 'Your ride was cancelled');

      expect(CabRideCancellation.endedMessage(CabOrderModel(status: Constant.driverRejected)), 'This ride is no longer active');
    });
  });

  test("rides and rentals never write the dispatch's exclusion list", () {
    final Map<String, dynamic> ride = CabOrderModel.fromJson({'id': 'r1', 'trigger_delevery': Timestamp.now(), 'rejectedByDrivers': ['d1']}).toJson();
    final Map<String, dynamic> rental = RentalOrderModel.fromJson({'id': 'b1', 'rejectedByDrivers': ['d1']}).toJson();
    expect(ride.containsKey('rejectedByDrivers'), isFalse);
    expect(rental.containsKey('rejectedByDrivers'), isFalse);
  });
}

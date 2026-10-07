import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/constant.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/dispatch_offer_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// DRIVER_DISPATCH_DOCUMENTATION.md and decisions D2-D4: the pure rules of the
/// Cloud Function dispatch as the driver app applies them.
void main() {
  const String me = 'driver-me';
  const String other = 'driver-other';

  Map<String, dynamic> order(String status, {String? driverId, String? driverID, List<String>? rejected, Map<String, dynamic>? extra}) => {
        'id': 'o1',
        'status': status,
        'driverId': ?driverId,
        'driverID': ?driverID,
        'rejectedByDrivers': ?rejected,
        ...?extra,
      };

  group('DispatchPush.parse (spec §3 / §5B)', () {
    test('the Cloud Function payload of each service', () {
      for (final (String type, DispatchKind kind) in const [
        ('order', DispatchKind.delivery),
        ('parcel', DispatchKind.parcel),
        ('cab', DispatchKind.cab),
        ('rental', DispatchKind.rental),
      ]) {
        final DispatchPush? push = DispatchPush.parse(
          {'click_action': 'FLUTTER_NOTIFICATION_CLICK', 'id': 'abc', 'orderId': 'abc', 'type': type, 'status': 'Driver Pending', 'sound': 'default'},
          sentTime: DateTime(2026, 10, 7, 12),
        );
        expect(push, isNotNull, reason: type);
        expect(push!.kind, kind);
        expect(push.orderId, 'abc');
        expect(push.sentTime, DateTime(2026, 10, 7, 12));
      }
    });

    test('data.id stands in for data.orderId; either marker is enough', () {
      expect(DispatchPush.parse({'type': 'cab', 'id': 'r1', 'click_action': 'FLUTTER_NOTIFICATION_CLICK'})?.orderId, 'r1');
      expect(DispatchPush.parse({'type': 'rental', 'orderId': 'b1', 'status': 'Driver Pending'})?.orderId, 'b1');
    });

    test('not a dispatch push', () {
      expect(DispatchPush.parse(null), isNull);
      expect(DispatchPush.parse({'type': 'order', 'orderId': 'o1'}), isNull, reason: 'no marker');
      expect(DispatchPush.parse({'type': 'orderChat', 'orderId': 'o1', 'click_action': 'FLUTTER_NOTIFICATION_CLICK'}), isNull);
      expect(DispatchPush.parse({'type': 'order', 'click_action': 'FLUTTER_NOTIFICATION_CLICK'}), isNull, reason: 'no id');
      expect(DispatchPush.parse({'type': 'order', 'orderId': 'a/b', 'status': 'Driver Pending'}), isNull, reason: 'not a document id');
    });
  });

  group('service types (spec §4 aliases)', () {
    test('parcel-service and ecommerce-service read as the module they name', () {
      expect(DriverServiceTypes.normalize('parcel-service'), 'parcel_delivery');
      expect(DriverServiceTypes.normalize('ecommerce-service'), 'delivery-service');
      expect(DriverServiceTypes.normalize(' cab-service '), 'cab-service');
      expect(DriverServiceTypes.normalizeAll(['delivery-service', 'ecommerce-service', 'parcel-service', '', 'rental-service']),
          ['delivery-service', 'parcel_delivery', 'rental-service']);
    });

    test('the modules a driver serves; none stored is delivery', () {
      expect(DispatchKind.servedBy(['parcel-service', 'cab-service']), [DispatchKind.parcel, DispatchKind.cab]);
      expect(DispatchKind.servedBy(null), [DispatchKind.delivery]);
      expect(DispatchKind.servedBy(const []), [DispatchKind.delivery]);
    });

    test('UserModel.serviceModules never rewrites the stored value', () {
      final UserModel user = UserModel.fromJson({'id': 'u', 'role': 'driver', 'serviceTypes': ['parcel-service']});
      expect(user.serviceModules, ['parcel_delivery']);
      expect(user.toJson()['serviceTypes'], ['parcel-service']);
    });

    test('the collections and driver fields the listeners query', () {
      expect(DispatchKind.delivery.collection, 'vendor_orders');
      expect(DispatchKind.delivery.driverField, 'driverID');
      expect(DispatchKind.cab.collection, 'rides');
      expect(DispatchKind.parcel.collection, 'parcel_orders');
      expect(DispatchKind.rental.collection, 'rental_orders');
      for (final DispatchKind kind in [DispatchKind.cab, DispatchKind.parcel, DispatchKind.rental]) {
        expect(kind.driverField, 'driverId');
      }
    });
  });

  group('settings/DriverNearBy (spec §6), read tolerantly', () {
    test('driverOrderAcceptRejectDuration: seconds, 120 when missing, unreadable or not positive', () {
      expect(DispatchSettings.acceptRejectSeconds(90), 90);
      expect(DispatchSettings.acceptRejectSeconds('45'), 45);
      expect(DispatchSettings.acceptRejectSeconds(30.6), 31);
      for (final dynamic bad in [null, '', 'abc', 0, -5, double.nan, double.infinity]) {
        expect(DispatchSettings.acceptRejectSeconds(bad), 120, reason: '$bad');
      }
    });

    test('numbers stored as numbers or text keep the String constants numeric', () {
      expect(DispatchSettings.amount(50, '0'), '50');
      expect(DispatchSettings.amount(12.5, '0'), '12.5');
      expect(DispatchSettings.amount(' 7 ', '0'), '7');
      expect(DispatchSettings.amount(null, '0'), '0');
      expect(DispatchSettings.amount('n/a', '50'), '50');
      expect(double.parse(DispatchSettings.amount(100, '0')), 100);
    });

    test('flags stored as bool, text or 1 / 0', () {
      expect(DispatchSettings.flag(true), isTrue);
      expect(DispatchSettings.flag('true'), isTrue);
      expect(DispatchSettings.flag(1), isTrue);
      expect(DispatchSettings.flag('false'), isFalse);
      expect(DispatchSettings.flag(0), isFalse);
      expect(DispatchSettings.flag(null), isFalse);
      expect(DispatchSettings.flag('maybe', fallback: true), isTrue);
    });
  });

  group('OfferTiming (D3 countdown)', () {
    final DateTime now = DateTime(2026, 10, 7, 12, 0, 0);

    test('starts at the earliest of push sentTime, dispatch time and first seen', () {
      final DateTime sent = now.subtract(const Duration(seconds: 50));
      final DateTime seen = now.subtract(const Duration(seconds: 10));
      expect(OfferTiming.start(sentTime: sent, firstSeen: seen, now: now), sent);
      expect(OfferTiming.start(firstSeen: seen, now: now), seen);
      expect(OfferTiming.start(now: now), now);
    });

    test('a time before the dispatch time belongs to an earlier dispatch', () {
      final DateTime dispatched = now.subtract(const Duration(seconds: 30));
      final DateTime staleSeen = now.subtract(const Duration(hours: 2));
      expect(OfferTiming.start(dispatchedAt: dispatched, firstSeen: staleSeen, now: now), dispatched);
    });

    test('a clock ahead of this device never extends the window', () {
      expect(OfferTiming.start(sentTime: now.add(const Duration(minutes: 1)), now: now), now);
    });

    test('a push received now: its sentTime within a delivery, else the receipt (clock skew)', () {
      final DateTime sent = now.subtract(const Duration(seconds: 3));
      expect(OfferTiming.pushStart(sentTime: sent, receivedAt: now), sent);
      expect(OfferTiming.pushStart(sentTime: now.subtract(OfferTiming.deliveryTolerance), receivedAt: now), now.subtract(OfferTiming.deliveryTolerance));
      // A device clock 3 minutes fast makes every push look 3 minutes old:
      // the window counts from the receipt, never expired on arrival.
      final DateTime skewed = now.subtract(const Duration(minutes: 3));
      final DateTime start = OfferTiming.pushStart(sentTime: skewed, receivedAt: now);
      expect(start, now);
      expect(OfferTiming.isExpired(start, 120, now), isFalse);
      expect(OfferTiming.remaining(start, 120, now), const Duration(seconds: 120));
      // A server clock ahead of this device, or no sentTime at all.
      expect(OfferTiming.pushStart(sentTime: now.add(const Duration(seconds: 30)), receivedAt: now), now);
      expect(OfferTiming.pushStart(receivedAt: now), now);
    });

    test('remaining, expiry, ring fraction and label', () {
      final DateTime start = now.subtract(const Duration(seconds: 30));
      expect(OfferTiming.remaining(start, 120, now), const Duration(seconds: 90));
      expect(OfferTiming.isExpired(start, 120, now), isFalse);
      expect(OfferTiming.isExpired(start, 30, now), isTrue);
      expect(OfferTiming.fractionLeft(start, 120, now), closeTo(0.75, 0.0001));
      expect(OfferTiming.fractionLeft(start, 20, now), 0);
      expect(OfferTiming.label(const Duration(seconds: 90)), '1:30');
      expect(OfferTiming.label(const Duration(milliseconds: 4200)), '5');
      expect(OfferTiming.label(const Duration(seconds: -3)), '0');
    });

    test('an offer whose window ran out while the app was closed is expired at once', () {
      final DateTime sent = now.subtract(const Duration(minutes: 5));
      final DateTime start = OfferTiming.start(sentTime: sent, firstSeen: now, now: now);
      expect(OfferTiming.isExpired(start, 120, now), isTrue);
    });

    test('dispatch time read from the order, whatever its encoding', () {
      final DateTime at = DateTime(2026, 10, 7, 11, 59);
      expect(OfferTiming.dispatchedAt({'dispatchedAt': Timestamp.fromDate(at)}), at);
      expect(OfferTiming.dispatchedAt({'driverPendingAt': at.millisecondsSinceEpoch}), at);
      expect(OfferTiming.dispatchedAt({'offeredAt': at.millisecondsSinceEpoch ~/ 1000}), at);
      expect(OfferTiming.dispatchedAt({'dispatchTime': at.toIso8601String()}), at);
      expect(OfferTiming.dispatchedAt({'lastDispatchedAt': {'_seconds': at.millisecondsSinceEpoch ~/ 1000}}), at);
      expect(OfferTiming.dispatchedAt({'createdAt': Timestamp.fromDate(at)}), isNull, reason: 'creation is not dispatch');
      expect(OfferTiming.dispatchedAt(null), isNull);
    });
  });

  group('OfferSeenLog (first seen, persisted per order)', () {
    final DateTime t0 = DateTime(2026, 10, 7, 12);

    test('the earliest time wins and a push mark is kept', () {
      Map<String, OfferSeen> log = OfferSeenLog.record(const {}, 'o1', t0);
      log = OfferSeenLog.record(log, 'o1', t0.subtract(const Duration(seconds: 20)), push: true);
      log = OfferSeenLog.record(log, 'o1', t0.add(const Duration(seconds: 20)));
      expect(log['o1']!.at, t0.subtract(const Duration(seconds: 20)));
      expect(log['o1']!.push, isTrue);
    });

    test('survives encoding; an unreadable log is empty', () {
      final Map<String, OfferSeen> log = OfferSeenLog.record(OfferSeenLog.record(const {}, 'a', t0, push: true), 'b', t0);
      final Map<String, OfferSeen> back = OfferSeenLog.decode(OfferSeenLog.encode(log));
      expect(back.keys, unorderedEquals(['a', 'b']));
      expect(back['a']!.at, t0);
      expect(back['a']!.push, isTrue);
      expect(back['b']!.push, isFalse);
      expect(OfferSeenLog.decode('not json'), isEmpty);
      expect(OfferSeenLog.decode(null), isEmpty);
    });

    test('a later dispatch push starts a new round: an old round\'s time is not inherited', () {
      // Offered at t0 and seen; withdrawn while the app was closed; offered
      // again ten minutes later by a new push.
      Map<String, OfferSeen> log = OfferSeenLog.record(const {}, 'o1', t0, push: true);
      final DateTime again = t0.add(const Duration(minutes: 10));
      log = OfferSeenLog.record(log, 'o1', again, push: true);
      expect(log['o1']!.at, again);
      expect(OfferTiming.isExpired(OfferTiming.start(firstSeen: log['o1']!.at, now: again), 120, again), isFalse);
      // The listener saw it a moment before its push: the same round.
      Map<String, OfferSeen> same = OfferSeenLog.record(const {}, 'o2', t0);
      same = OfferSeenLog.record(same, 'o2', t0.add(const Duration(seconds: 2)), push: true);
      expect(same['o2']!.at, t0);
      expect(same['o2']!.push, isTrue);
      // A first-seen time never replaces anything.
      final Map<String, OfferSeen> seen = OfferSeenLog.record(log, 'o1', again.add(const Duration(minutes: 5)));
      expect(seen['o1']!.at, again);
    });

    test('pushedAfter: a dispatch push recorded after a given time', () {
      final Map<String, OfferSeen> log = OfferSeenLog.record(OfferSeenLog.record(const {}, 'p', t0, push: true), 's', t0);
      expect(OfferSeenLog.pushedAfter(log['p'], t0.subtract(const Duration(minutes: 1))), isTrue);
      expect(OfferSeenLog.pushedAfter(log['p'], t0.add(const Duration(minutes: 1))), isFalse);
      expect(OfferSeenLog.pushedAfter(log['s'], t0.subtract(const Duration(minutes: 1))), isFalse, reason: 'seen, never pushed');
      expect(OfferSeenLog.pushedAfter(null, t0), isFalse);
    });

    test('old entries are forgotten', () {
      final Map<String, OfferSeen> log = OfferSeenLog.record(OfferSeenLog.record(const {}, 'old', t0.subtract(const Duration(days: 2))), 'new', t0);
      expect(OfferSeenLog.prune(log, t0).keys, ['new']);
    });
  });

  group('which pending order is a dispatch offer (D3, gap 23)', () {
    final Map<String, dynamic> offer = order(Constant.driverPending, driverId: me, driverID: me);

    test('Driver Pending naming this driver, in either field', () {
      expect(DispatchOrderRules.isPendingFor(offer, me), isTrue);
      expect(DispatchOrderRules.isPendingFor(order(Constant.driverPending, driverID: me), me), isTrue);
      expect(DispatchOrderRules.isPendingFor(order(Constant.driverPending, driverId: me), me), isTrue);
      expect(DispatchOrderRules.isPendingFor(order(Constant.driverPending, driverId: other, driverID: other), me), isFalse);
      expect(DispatchOrderRules.isPendingFor(order(Constant.driverPending), me), isFalse);
      expect(DispatchOrderRules.isPendingFor(order(Constant.driverAccepted, driverId: me), me), isFalse);
      expect(DispatchOrderRules.isPendingFor(null, me), isFalse);
    });

    test('timed when the id is in orderRequestData or a dispatch push named it', () {
      expect(DispatchOrderRules.isTimedOffer(offer, uid: me, orderId: 'o1', requests: ['o1']), isTrue);
      expect(DispatchOrderRules.isTimedOffer(offer, uid: me, orderId: 'o1', pushSeen: true), isTrue);
      expect(DispatchOrderRules.isTimedOffer(offer, uid: me, orderId: 'o1'), isFalse, reason: 'named on the order only: maybe a hand assignment');
    });

    test("a store's own delivery man (inProgressOrderID) and a hand assignment get no timer", () {
      expect(DispatchOrderRules.isTimedOffer(offer, uid: me, orderId: 'o1', requests: ['o1'], inProgress: ['o1']), isFalse);
      expect(DispatchOrderRules.isTimedOffer(offer, uid: me, orderId: 'o1', requests: ['o1'], handAssigned: true), isFalse);
      expect(DispatchOrderRules.isTimedOffer(order(Constant.orderAccepted, driverID: me), uid: me, orderId: 'o1', requests: ['o1']), isFalse);
    });

    test('never for a driver who already rejected it', () {
      expect(DispatchOrderRules.isTimedOffer(order(Constant.driverPending, driverId: me, rejected: [me]), uid: me, orderId: 'o1', pushSeen: true), isFalse);
    });

    test('a rental waiting for the customer\'s answer to THIS driver\'s counter-offer has no countdown', () {
      Map<String, dynamic> rental(Map<String, dynamic>? proposal) =>
          order(Constant.driverPending, driverId: me, driverID: me, extra: {'priceProposal': ?proposal});
      final Map<String, dynamic> mine = rental({'status': 'countered', 'counterAmount': 900, 'counteredBy': me});
      expect(DispatchOrderRules.proposalStatus(mine), 'countered');
      expect(DispatchOrderRules.awaitsCustomer(mine, me), isTrue);
      expect(DispatchOrderRules.isTimedOffer(mine, uid: me, orderId: 'o1', requests: ['o1'], pushSeen: true), isFalse);
      // Another driver's counter, or one that does not say whose: the
      // customer cannot accept it for this driver — the offer stays timed.
      for (final Map<String, dynamic> p in [
        {'status': 'countered', 'counteredBy': other},
        {'status': 'countered'},
      ]) {
        expect(DispatchOrderRules.awaitsCustomer(rental(p), me), isFalse);
        expect(DispatchOrderRules.isTimedOffer(rental(p), uid: me, orderId: 'o1', requests: ['o1']), isTrue);
      }
      // A proposal the driver answers in the dialog, an answered one, none.
      for (final String status in ['pending', 'accepted', 'rejected']) {
        expect(DispatchOrderRules.isTimedOffer(rental({'status': status, 'counteredBy': me}), uid: me, orderId: 'o1', requests: ['o1']), isTrue, reason: status);
      }
      expect(DispatchOrderRules.proposalStatus(rental(null)), '');
      expect(DispatchOrderRules.awaitsCustomer(rental(null), me), isFalse);
    });
  });

  group('accept precondition (D2: never an offer that is no longer this driver\'s)', () {
    test('Driver Pending for this driver: ok, in every collection', () {
      for (final DispatchKind kind in DispatchKind.values) {
        expect(DispatchOrderRules.acceptCheck(kind, order(Constant.driverPending, driverId: me, driverID: me), me), AcceptCheck.ok, reason: kind.name);
      }
    });

    test('re-dispatched to another driver, rejected, cancelled or gone: gone', () {
      for (final DispatchKind kind in DispatchKind.values) {
        expect(DispatchOrderRules.acceptCheck(kind, order(Constant.driverPending, driverId: other, driverID: other), me), AcceptCheck.gone);
        expect(DispatchOrderRules.acceptCheck(kind, order(Constant.driverRejected, rejected: [me]), me), AcceptCheck.gone);
        expect(DispatchOrderRules.acceptCheck(kind, order(Constant.orderCancelled, driverId: me), me), AcceptCheck.gone);
        expect(DispatchOrderRules.acceptCheck(kind, null, me), AcceptCheck.gone);
      }
    });

    test('already this driver\'s job (the CF advanced vendor_orders to Order Shipped): held, nothing written', () {
      expect(DispatchOrderRules.acceptCheck(DispatchKind.delivery, order(Constant.orderShipped, driverID: me), me), AcceptCheck.held);
      expect(DispatchOrderRules.acceptCheck(DispatchKind.cab, order(Constant.driverAccepted, driverId: me), me), AcceptCheck.held);
    });

    test('an unnamed legacy offer only when the driver holds it', () {
      expect(DispatchOrderRules.acceptCheck(DispatchKind.delivery, order(Constant.driverPending), me), AcceptCheck.gone);
      expect(DispatchOrderRules.acceptCheck(DispatchKind.delivery, order(Constant.driverPending), me, heldAsRequest: true), AcceptCheck.ok);
      expect(DispatchOrderRules.acceptCheck(DispatchKind.cab, order(Constant.orderPlaced), me, heldAsRequest: true), AcceptCheck.ok);
      expect(DispatchOrderRules.acceptCheck(DispatchKind.cab, order(Constant.orderPlaced, rejected: [me]), me, heldAsRequest: true), AcceptCheck.gone);
    });

    test('the admin hand assignment of a delivery (Order Accepted + driverID)', () {
      expect(DispatchOrderRules.acceptCheck(DispatchKind.delivery, order(Constant.orderAccepted, driverID: me), me), AcceptCheck.ok);
      expect(DispatchOrderRules.acceptCheck(DispatchKind.delivery, order(Constant.orderAccepted), me), AcceptCheck.gone);
    });

    test('the open parcel / rental search takes an Order Placed order naming nobody, nothing else', () {
      for (final DispatchKind kind in [DispatchKind.parcel, DispatchKind.rental]) {
        expect(DispatchOrderRules.acceptCheck(kind, order(Constant.orderPlaced), me, fromOpenSearch: true), AcceptCheck.ok);
        expect(DispatchOrderRules.acceptCheck(kind, order(Constant.orderPlaced), me), AcceptCheck.gone);
        // parcelDispatch / rentalDispatch offered it to another driver meanwhile.
        expect(DispatchOrderRules.acceptCheck(kind, order(Constant.driverPending, driverId: other, driverID: other), me, fromOpenSearch: true), AcceptCheck.gone);
        expect(DispatchOrderRules.acceptCheck(kind, order(Constant.driverPending, driverId: me, driverID: me), me, fromOpenSearch: true), AcceptCheck.ok);
      }
    });

    test('accept fields: Driver Accepted with this driver in both fields', () {
      final Map<String, dynamic> fields = DispatchOrderRules.acceptFields(me, {'id': me}, extra: {'regionId': 'r1'});
      expect(fields['status'], Constant.driverAccepted);
      expect(fields['driverId'], me);
      expect(fields['driverID'], me);
      expect(fields['driver'], {'id': me});
      expect(fields['regionId'], 'r1');
      expect(fields.containsKey('rejectedByDrivers'), isFalse, reason: 'never a stale copy of the array');
    });
  });

  group('hand-back after accept (rental cancelBooking, spec §1)', () {
    test('goes back to dispatch as Driver Rejected, never Order Placed', () {
      final Map<String, dynamic> reason = {'driverRejections': FieldValue.arrayUnion([{'driverId': me, 'afterAccept': true}])};
      final Map<String, dynamic> fields = DispatchOrderRules.handBackFields(me, reasonFields: reason);
      expect(fields['status'], Constant.driverRejected);
      expect(fields['rejectedByDrivers'], isA<FieldValue>());
      expect(fields.containsKey('driverId'), isTrue);
      expect(fields['driverId'], isNull);
      expect(fields.containsKey('driverID'), isTrue);
      expect(fields['driverID'], isNull);
      expect(fields['driver'], isA<FieldValue>());
      expect(fields['driverRejections'], isA<FieldValue>());
      for (final String key in const ['cancelReason', 'cancelReasonCode', 'cancelledBy', 'cancelledAt']) {
        expect(fields.containsKey(key), isFalse, reason: key);
      }
    });

    test('only a booking this driver holds and has not started', () {
      expect(DispatchOrderRules.canHandBack(order(Constant.driverAccepted, driverId: me), me), isTrue);
      expect(DispatchOrderRules.canHandBack(order(Constant.driverAccepted, driverId: me, driverID: me), me), isTrue);
      expect(DispatchOrderRules.canHandBack(order(Constant.orderPlaced, driverId: me), me), isTrue);
      expect(DispatchOrderRules.canHandBack(order(Constant.orderInTransit, driverId: me), me), isFalse);
      expect(DispatchOrderRules.canHandBack(order(Constant.orderCancelled, driverId: me), me), isFalse);
      expect(DispatchOrderRules.canHandBack(order(Constant.driverRejected), me), isFalse);
      expect(DispatchOrderRules.canHandBack(order(Constant.driverAccepted, driverId: other), me), isFalse);
      expect(DispatchOrderRules.canHandBack(order(Constant.driverAccepted, driverId: me, driverID: other), me), isFalse);
      expect(DispatchOrderRules.canHandBack(null, me), isFalse);
    });

    test('a hand-back leaves the driver: stale in inProgressOrderID', () {
      final Map<String, dynamic> handedBack = order(Constant.driverRejected, rejected: [me]);
      expect(DispatchOrderRules.isStaleInProgress(DispatchKind.rental, handedBack, me), isTrue);
    });
  });

  group('reject / timeout (D2)', () {
    test('both driver fields set to null, this driver excluded, no final cancellation fields', () {
      final Map<String, dynamic> fields = DispatchOrderRules.rejectFields(me);
      expect(fields['status'], Constant.driverRejected);
      expect(fields['rejectedByDrivers'], isA<FieldValue>());
      expect(fields.containsKey('driverId'), isTrue);
      expect(fields['driverId'], isNull);
      expect(fields.containsKey('driverID'), isTrue);
      expect(fields['driverID'], isNull);
      for (final String key in const ['cancelReason', 'cancelReasonCode', 'cancelledBy', 'cancelledAt', 'driverRejections']) {
        expect(fields.containsKey(key), isFalse, reason: key);
      }
    });

    test('a manual reject adds its reason; a timeout never does', () {
      final Map<String, dynamic> reason = {'driverRejections': FieldValue.arrayUnion([{'driverId': me}])};
      expect(DispatchOrderRules.rejectFields(me, reasonFields: reason).containsKey('driverRejections'), isTrue);
      expect(DispatchOrderRules.rejectFields(me, reasonFields: null).containsKey('driverRejections'), isFalse);
    });

    test('a timeout answers only an order still Driver Pending for this driver', () {
      for (final DispatchKind kind in DispatchKind.values) {
        expect(DispatchOrderRules.canReject(kind, order(Constant.driverPending, driverId: me, driverID: me), me, timeout: true), isTrue);
        expect(DispatchOrderRules.canReject(kind, order(Constant.driverAccepted, driverId: me), me, timeout: true), isFalse);
        expect(DispatchOrderRules.canReject(kind, order(Constant.driverPending, driverId: other, driverID: other), me, timeout: true), isFalse);
        expect(DispatchOrderRules.canReject(kind, order(Constant.driverPending), me, timeout: true, heldAsRequest: true), isFalse);
        expect(DispatchOrderRules.canReject(kind, order(Constant.orderCancelled, driverId: me), me, timeout: true), isFalse);
      }
    });

    test('a manual reject: an offer, a hand assignment, or a legacy request the driver holds', () {
      expect(DispatchOrderRules.canReject(DispatchKind.cab, order(Constant.driverPending, driverId: me), me), isTrue);
      expect(DispatchOrderRules.canReject(DispatchKind.cab, order(Constant.orderPlaced), me, heldAsRequest: true), isTrue);
      expect(DispatchOrderRules.canReject(DispatchKind.cab, order(Constant.orderPlaced), me), isFalse);
      expect(DispatchOrderRules.canReject(DispatchKind.cab, order(Constant.orderCancelled, driverId: me), me), isFalse, reason: 'never back to dispatch');
      expect(DispatchOrderRules.canReject(DispatchKind.delivery, order(Constant.orderAccepted, driverID: me), me), isTrue);
      expect(DispatchOrderRules.canReject(DispatchKind.parcel, order(Constant.orderPlaced), me), isFalse, reason: 'an open parcel is not this driver\'s');
      expect(DispatchOrderRules.canReject(DispatchKind.rental, order(Constant.driverPending, driverId: other), me), isFalse);
    });
  });

  group('orderRequestData housekeeping (server data only)', () {
    test('kept while still waiting for this driver', () {
      expect(DispatchOrderRules.requestVerdict(order(Constant.driverPending, driverId: me), me), RequestVerdict.keep);
      expect(DispatchOrderRules.requestVerdict(order(Constant.driverPending), me), RequestVerdict.keep, reason: 'a legacy unnamed offer');
      expect(DispatchOrderRules.requestVerdict(order(Constant.orderAccepted, driverID: me), me), RequestVerdict.keep, reason: 'hand assignment');
    });

    test('dropped when gone, finished, re-dispatched or back to dispatch', () {
      expect(DispatchOrderRules.requestVerdict(null, me), RequestVerdict.stale);
      expect(DispatchOrderRules.requestVerdict(order(Constant.orderCancelled, driverId: me), me), RequestVerdict.stale);
      expect(DispatchOrderRules.requestVerdict(order(Constant.driverPending, driverId: other, driverID: other), me), RequestVerdict.stale);
      expect(DispatchOrderRules.requestVerdict(order(Constant.driverRejected, rejected: [me]), me), RequestVerdict.stale);
      expect(DispatchOrderRules.requestVerdict(order(Constant.orderAccepted), me), RequestVerdict.stale);
    });

    test('accepted by this driver: it belongs in inProgressOrderID', () {
      expect(DispatchOrderRules.requestVerdict(order(Constant.orderShipped, driverID: me), me), RequestVerdict.accepted);
      expect(DispatchOrderRules.requestVerdict(order(Constant.driverAccepted), me), RequestVerdict.stale);
    });
  });

  group('inProgressOrderID housekeeping for rides / parcels / rentals (spec §4)', () {
    test('kept while this driver works it', () {
      for (final DispatchKind kind in [DispatchKind.cab, DispatchKind.parcel, DispatchKind.rental]) {
        expect(DispatchOrderRules.isStaleInProgress(kind, order(Constant.driverAccepted, driverId: me), me), isFalse);
        expect(DispatchOrderRules.isStaleInProgress(kind, order(Constant.orderInTransit, driverId: me), me), isFalse);
      }
    });

    test('finished, cancelled, returned, handed back, reassigned or deleted', () {
      for (final DispatchKind kind in [DispatchKind.cab, DispatchKind.parcel, DispatchKind.rental]) {
        expect(DispatchOrderRules.isStaleInProgress(kind, null, me), isTrue);
        expect(DispatchOrderRules.isStaleInProgress(kind, order(Constant.orderCompleted, driverId: me), me), isTrue);
        expect(DispatchOrderRules.isStaleInProgress(kind, order(Constant.orderCancelled, driverId: me), me), isTrue);
        expect(DispatchOrderRules.isStaleInProgress(kind, order(Constant.orderInTransit, driverId: other), me), isTrue);
        expect(DispatchOrderRules.isStaleInProgress(kind, order(Constant.driverRejected, rejected: [me]), me), isTrue);
        expect(DispatchOrderRules.isStaleInProgress(kind, order(Constant.orderPlaced), me), isTrue, reason: 'handed back to the open search');
      }
      expect(DispatchOrderRules.isStaleInProgress(DispatchKind.parcel, order(Constant.orderInTransit, driverId: me, extra: {'parcelStatus': 'Returned'}), me), isTrue);
    });
  });

  group('offer gates (the module cards)', () {
    OfferGate gate({bool freelance = true, bool docs = false, String? ownerId, num? own, num? owner}) => DispatchGateRules.check(
          freelance: freelance,
          documentsPending: docs,
          ownerId: ownerId,
          ownWallet: own,
          ownerWallet: owner,
          minimumDeposit: 100,
          ownerMinimumDeposit: 500,
        );

    test('an independent driver against minimumDepositToRideAccept', () {
      expect(gate(own: 100), OfferGate.open);
      expect(gate(own: 99), OfferGate.ownWallet);
      expect(gate(), OfferGate.ownWallet);
    });

    test("a company's driver against the owner minimum, on the company's wallet", () {
      expect(gate(ownerId: 'c1', own: 0, owner: 500), OfferGate.open);
      expect(gate(ownerId: 'c1', own: 10000, owner: 499), OfferGate.ownerWallet);
      expect(gate(ownerId: 'c1', owner: null), OfferGate.ownerWallet, reason: 'the company wallet could not be read');
    });

    test("a store's own delivery man pays no deposit; an unverified freelance driver is held back", () {
      expect(gate(freelance: false, own: 0), OfferGate.open);
      expect(gate(docs: true, own: 1000), OfferGate.documentsPending);
      expect(gate(freelance: false, docs: true, own: 0), OfferGate.open);
    });

    test('a hand assignment by name is not held back by pending documents (as on the cab home); the wallet still is', () {
      OfferGate hand({num? own, String? ownerId, num? owner}) => DispatchGateRules.check(
            freelance: true,
            documentsPending: true,
            ownerId: ownerId,
            ownWallet: own,
            ownerWallet: owner,
            minimumDeposit: 100,
            ownerMinimumDeposit: 500,
            handAssigned: true,
          );
      expect(hand(own: 100), OfferGate.open);
      expect(hand(own: 10), OfferGate.ownWallet);
      expect(hand(ownerId: 'c1', owner: 10), OfferGate.ownerWallet);
    });
  });

  group('OfferSummary (what the dialog shows), read tolerantly', () {
    test('delivery: store to customer, charge and tip', () {
      final OfferSummary s = OfferSummary.fromOrder(DispatchKind.delivery, 'o1', {
        'vendor': {'title': 'Chez Awa', 'location': '12 Rue, null, Yaoundé', 'latitude': '3.86', 'longitude': 11.5},
        'author': {'firstName': 'Paul', 'lastName': null},
        'address': {'address': 'Bastos', 'locality': null, 'location': {'latitude': 3.9, 'longitude': 11.51}},
        'deliveryCharge': '500',
        'tip_amount': 100,
        'section_id': 's1',
      });
      expect(s.pickupLabel, 'Chez Awa');
      expect(s.pickupAddress, '12 Rue, Yaoundé');
      expect(s.dropLabel, 'Paul');
      expect(s.dropAddress, 'Bastos');
      expect(s.fare, '500');
      expect(s.tip, '100');
      expect(s.pickupLat, 3.86);
      expect(s.dropLng, 11.51);
      expect(s.sectionId, 's1');
    });

    test('parcel, cab and rental read their own fields; missing ones stay empty', () {
      final OfferSummary parcel = OfferSummary.fromOrder(DispatchKind.parcel, 'p1', {
        'sender': {'name': 'Awa', 'address': 'Tsinga'},
        'receiver': {'name': 'Ben', 'address': 'Mvog-Mbi'},
        'subTotal': '1500',
        'distance': '4.2',
        'parcelWeight': '2 kg',
      });
      expect([parcel.pickupLabel, parcel.pickupAddress, parcel.dropLabel, parcel.dropAddress], ['Awa', 'Tsinga', 'Ben', 'Mvog-Mbi']);
      expect(double.parse(parcel.fare!), 1500);
      expect(parcel.distance, '4.2');
      expect(parcel.weight, '2 kg');

      final OfferSummary cab = OfferSummary.fromOrder(DispatchKind.cab, 'r1', {'sourceLocationName': 'A', 'destinationLocationName': 'B', 'rideType': 'Moto'});
      expect([cab.pickupAddress, cab.dropAddress, cab.rideType], ['A', 'B', 'Moto']);
      expect(cab.fare, isNull);

      final OfferSummary rental = OfferSummary.fromOrder(DispatchKind.rental, 'b1', {
        'sourceLocationName': 'Airport',
        'rentalPackageModel': {'name': '4h', 'includedDistance': 40, 'includedHours': '4'},
      });
      expect(rental.packageName, '4h');
      expect(rental.includedDistance, '40');
      expect(rental.includedHours, '4');
      expect(OfferSummary.fromOrder(DispatchKind.rental, 'b2', const {}).pickupAddress, '');
    });

    test('parcel: the Amount is the total the customer was charged, as on every other parcel screen', () {
      Map<String, dynamic> tax(String type, String value) => {'title': 'VAT', 'type': type, 'tax': value, 'enable': true};
      final OfferSummary cod = OfferSummary.fromOrder(DispatchKind.parcel, 'p4', {
        'subTotal': '1000',
        'platformFee': '200',
        'platformTax': [tax('percentage', '5')],
        'parcelScopeTax': 300,
        'sendReceiverSms': true,
        'smsCharge': 50,
      });
      expect(double.parse(cod.fare!), 1560); // 1000 + 200 + 10 + 300 + 50
      // A record the parcel model cannot read: the raw fare.
      expect(OfferSummary.fromOrder(DispatchKind.parcel, 'p5', {'subTotal': 700, 'parcelWeight': 2}).fare, '700');
      expect(OfferSummary.fromOrder(DispatchKind.parcel, 'p6', const {}).fare, isNull);
    });

    test('parcel: the flat receiver name (app-spec-parcel-sms.md) wins over the map', () {
      final OfferSummary withFlat = OfferSummary.fromOrder(DispatchKind.parcel, 'p2', {
        'receiverName': 'Awa Njoya',
        'receiver': {'name': 'Awa', 'address': 'Mvog-Mbi'},
      });
      expect(withFlat.dropLabel, 'Awa Njoya');
      expect(withFlat.dropAddress, 'Mvog-Mbi');
      final OfferSummary flatOnly = OfferSummary.fromOrder(DispatchKind.parcel, 'p3', {'receiverName': 'Awa Njoya'});
      expect(flatOnly.dropLabel, 'Awa Njoya');
    });
  });

  group('UserLocation (spec §4: numbers)', () {
    test('an integer or numeric text is read, not thrown on', () {
      final UserModel user = UserModel.fromJson({
        'id': 'u',
        'location': {'latitude': 4, 'longitude': '11.5'}
      });
      expect(user.location?.latitude, 4.0);
      expect(user.location?.longitude, 11.5);
    });
  });
}

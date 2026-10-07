/// Pure rules of the Cloud Function driver dispatch
/// (DRIVER_DISPATCH_DOCUMENTATION.md, decisions D2-D4): which push is a
/// dispatch offer, which order is an offer to this driver, when its window
/// started and ends, which writes accept / reject / time it out, and which
/// ids the driver's `orderRequestData` / `inProgressOrderID` may keep.
///
/// No Firebase calls, no widgets: every rule here is unit tested
/// (test/dispatch_offer_rules_test.dart). The Firestore side is
/// `DispatchOfferService`, the dialog side `IncomingOfferService`.
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, Timestamp;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/utils/address_format.dart';
import 'package:driver/utils/parcel_amounts.dart';

/// The driver service types as stored on `users.serviceTypes`, and the
/// aliases the dispatch spec (§4) also accepts. Readers normalise; stored
/// values are never rewritten.
abstract final class DriverServiceTypes {
  static const String delivery = 'delivery-service';
  static const String cab = 'cab-service';
  static const String parcel = 'parcel_delivery';
  static const String rental = 'rental-service';

  /// `parcel-service` is the spec's alias of `parcel_delivery`, and an
  /// `ecommerce-service` driver delivers through the delivery module.
  static String normalize(String? value) {
    final String v = (value ?? '').trim();
    switch (v) {
      case 'parcel-service':
        return parcel;
      case 'ecommerce-service':
        return delivery;
    }
    return v;
  }

  /// [values] normalised, blanks dropped, each module once, in stored order.
  static List<String> normalizeAll(Iterable<String>? values) {
    final List<String> out = <String>[];
    for (final String value in values ?? const <String>[]) {
      final String n = normalize(value);
      if (n.isNotEmpty && !out.contains(n)) out.add(n);
    }
    return out;
  }
}

/// The four dispatched services (spec §1, §3).
enum DispatchKind {
  delivery('order', CollectionName.vendorOrders, DriverServiceTypes.delivery),
  parcel('parcel', CollectionName.parcelOrders, DriverServiceTypes.parcel),
  cab('cab', CollectionName.ridesBooking, DriverServiceTypes.cab),
  rental('rental', CollectionName.rentalOrders, DriverServiceTypes.rental);

  const DispatchKind(this.pushType, this.collection, this.serviceType);

  /// `data.type` of the dispatch push.
  final String pushType;

  /// The Firestore collection of the order.
  final String collection;

  /// The `users.serviceTypes` module that serves it.
  final String serviceType;

  /// The field this app queries the order's driver by. The Cloud Function
  /// writes both `driverId` and `driverID`; `vendor_orders` has always been
  /// read by `driverID`, the other collections by `driverId`.
  String get driverField => this == DispatchKind.delivery ? 'driverID' : 'driverId';

  static DispatchKind? fromPushType(String? type) {
    final String t = (type ?? '').trim();
    for (final DispatchKind kind in DispatchKind.values) {
      if (kind.pushType == t) return kind;
    }
    return null;
  }

  static DispatchKind? fromServiceType(String? serviceType) {
    final String s = DriverServiceTypes.normalize(serviceType);
    for (final DispatchKind kind in DispatchKind.values) {
      if (kind.serviceType == s) return kind;
    }
    return null;
  }

  /// The modules a driver with [serviceTypes] serves (none stored: delivery,
  /// as every reader of the field has always assumed).
  static List<DispatchKind> servedBy(Iterable<String>? serviceTypes) {
    final List<String> services = DriverServiceTypes.normalizeAll(serviceTypes);
    if (services.isEmpty) return const <DispatchKind>[DispatchKind.delivery];
    return <DispatchKind>[
      for (final String s in services)
        if (fromServiceType(s) != null) fromServiceType(s)!,
    ];
  }
}

/// A push the dispatch Cloud Function sent (spec §3 / §5B): `data.type`
/// order | parcel | cab | rental, the order id in `data.orderId` (or
/// `data.id`), and either `click_action: FLUTTER_NOTIFICATION_CLICK` or
/// `status: Driver Pending`.
class DispatchPush {
  final DispatchKind kind;
  final String orderId;

  /// When FCM accepted the message (`RemoteMessage.sentTime`), if known.
  final DateTime? sentTime;

  const DispatchPush(this.kind, this.orderId, {this.sentTime});

  static const String clickAction = 'FLUTTER_NOTIFICATION_CLICK';

  static DispatchPush? parse(Map<String, dynamic>? data, {DateTime? sentTime}) {
    if (data == null || data.isEmpty) return null;
    final DispatchKind? kind = DispatchKind.fromPushType(data['type']?.toString());
    if (kind == null) return null;
    String text(dynamic v) => (v ?? '').toString().trim();
    final String orderId = text(data['orderId']).isNotEmpty ? text(data['orderId']) : text(data['id']);
    if (orderId.isEmpty || orderId.contains('/')) return null;
    final bool click = text(data['click_action']) == clickAction;
    final bool pending = text(data['status']) == Constant.driverPending;
    if (!click && !pending) return null;
    return DispatchPush(kind, orderId, sentTime: sentTime);
  }
}

/// `settings/DriverNearBy`, read tolerantly (spec §6): a number may be stored
/// as a number or as text, and one unreadable key must not stop the others.
abstract final class DispatchSettings {
  static const int defaultAcceptRejectSeconds = 120;

  /// Seconds a driver has to answer an offer: 120 when missing, unreadable
  /// or not positive.
  static int acceptRejectSeconds(dynamic value) {
    final num? n = value is num ? value : num.tryParse((value ?? '').toString().trim());
    if (n == null || !n.isFinite || n <= 0) return defaultAcceptRejectSeconds;
    final int seconds = n.round();
    return seconds < 1 ? defaultAcceptRejectSeconds : seconds;
  }

  /// A bool stored as a bool, `"true"` / `"false"` or 1 / 0.
  static bool flag(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    switch ((value ?? '').toString().trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
        return false;
    }
    return fallback;
  }

  /// A number kept as the numeric text the existing `String` constants hold
  /// (they are read with `double.parse`): a stored number or numeric text,
  /// else [fallback].
  static String amount(dynamic value, String fallback) {
    if (value is num) return value.isFinite ? value.toString() : fallback;
    final String text = (value ?? '').toString().trim();
    final num? n = num.tryParse(text);
    return (n == null || !n.isFinite) ? fallback : text;
  }

  /// A text setting, else [fallback].
  static String text(dynamic value, String fallback) {
    final String t = (value ?? '').toString().trim();
    return t.isEmpty ? fallback : t;
  }
}

/// The countdown of an offer (D3).
abstract final class OfferTiming {
  /// Fields a dispatch time may be written in. None is in the spec yet; the
  /// first one present is used (see the contract note for the CF team).
  static const List<String> dispatchTimeFields = [
    'dispatchedAt',
    'driverDispatchedAt',
    'lastDispatchedAt',
    'dispatchTime',
    'driverPendingAt',
    'offeredAt',
  ];

  /// The dispatch time written on [order], if any.
  static DateTime? dispatchedAt(Map<String, dynamic>? order) {
    if (order == null) return null;
    for (final String field in dispatchTimeFields) {
      final DateTime? at = readTime(order[field]);
      if (at != null) return at;
    }
    return null;
  }

  /// A Timestamp, a DateTime, epoch milliseconds (or seconds), an ISO text or
  /// a serialised `{seconds | _seconds}` map.
  static DateTime? readTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) {
      if (!value.isFinite || value <= 0) return null;
      final int ms = value < 100000000000 ? (value * 1000).round() : value.round();
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    if (value is Map) {
      final dynamic s = value['seconds'] ?? value['_seconds'];
      return s is num ? DateTime.fromMillisecondsSinceEpoch((s * 1000).round()) : null;
    }
    if (value is String) return DateTime.tryParse(value.trim());
    return null;
  }

  /// How far a push's `sentTime` (the FCM server's clock) may lie before the
  /// moment this device received it and still be taken as the offer's start.
  /// Further back, the gap is either a delayed delivery or a device clock
  /// ahead of the server — the two cannot be told apart — so the receipt time
  /// is used: a device clock set minutes fast must not shorten, or use up,
  /// every offer's window. Also the gap after which a dispatch push starts a
  /// new dispatch round ([OfferSeenLog.record]).
  static const Duration deliveryTolerance = Duration(seconds: 10);

  /// Where the countdown of a push RECEIVED NOW starts (foreground
  /// `onMessage`, the background handler): its [sentTime] while that is
  /// within [deliveryTolerance] before [receivedAt], else [receivedAt]
  /// (D3 keeps sentTime; this bounds the device / server clock skew).
  static DateTime pushStart({DateTime? sentTime, required DateTime receivedAt}) {
    if (sentTime == null || sentTime.isAfter(receivedAt)) return receivedAt;
    return receivedAt.difference(sentTime) > deliveryTolerance ? receivedAt : sentTime;
  }

  /// Start of the countdown: the earliest of the push's [sentTime], the
  /// order's [dispatchedAt] and the time this device first saw the offer
  /// ([firstSeen]). A time before the order's own dispatch time belongs to an
  /// earlier dispatch and is ignored; a time after [now] (a clock ahead of
  /// this device) never extends the window.
  static DateTime start({DateTime? sentTime, DateTime? dispatchedAt, DateTime? firstSeen, required DateTime now}) {
    DateTime? earliest;
    for (final DateTime? t in [sentTime, dispatchedAt, firstSeen]) {
      if (t == null) continue;
      if (dispatchedAt != null && t.isBefore(dispatchedAt)) continue;
      if (earliest == null || t.isBefore(earliest)) earliest = t;
    }
    if (earliest == null || earliest.isAfter(now)) return now;
    return earliest;
  }

  static DateTime deadline(DateTime start, int seconds) => start.add(Duration(seconds: seconds));

  /// What is left of the window; negative once it is over.
  static Duration remaining(DateTime start, int seconds, DateTime now) => deadline(start, seconds).difference(now);

  static bool isExpired(DateTime start, int seconds, DateTime now) => remaining(start, seconds, now) <= Duration.zero;

  /// 0..1 of the window left, for the countdown ring.
  static double fractionLeft(DateTime start, int seconds, DateTime now) {
    if (seconds <= 0) return 0;
    final double left = remaining(start, seconds, now).inMilliseconds / (seconds * 1000);
    return left.clamp(0.0, 1.0);
  }

  /// `m:ss` (or `s`) of what is left, never negative.
  static String label(Duration remaining) {
    final int total = remaining.isNegative ? 0 : (remaining.inMilliseconds / 1000).ceil();
    final int m = total ~/ 60;
    final int s = total % 60;
    return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '$s';
  }
}

/// When this device first saw each offer, and whether a dispatch push
/// announced it — persisted (SharedPreferences, `prefKey`) so the countdown
/// survives a restart and the background isolate can record a push.
class OfferSeen {
  final DateTime at;
  final bool push;

  const OfferSeen(this.at, {this.push = false});
}

abstract final class OfferSeenLog {
  static const String prefKey = 'dispatchOfferSeen';

  /// Entries older than this are forgotten.
  static const Duration keep = Duration(hours: 24);
  static const int cap = 200;

  static Map<String, OfferSeen> decode(String? raw) {
    final Map<String, OfferSeen> out = <String, OfferSeen>{};
    if (raw == null || raw.isEmpty) return out;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return out;
      decoded.forEach((dynamic key, dynamic value) {
        if (value is Map && value['t'] is num) {
          out[key.toString()] = OfferSeen(DateTime.fromMillisecondsSinceEpoch((value['t'] as num).toInt()), push: value['p'] == true);
        }
      });
    } catch (_) {
      // An unreadable log is an empty one.
    }
    return out;
  }

  static String encode(Map<String, OfferSeen> log) => jsonEncode({
        for (final MapEntry<String, OfferSeen> e in log.entries) e.key: {'t': e.value.at.millisecondsSinceEpoch, if (e.value.push) 'p': true},
      });

  /// Records [orderId] seen at [at]: the earliest time wins, and a push mark
  /// is never lost.
  ///
  /// Except for a new dispatch round: the Cloud Function sends one push per
  /// dispatch, and writes no dispatch time on the order, so a dispatch
  /// [push] later than the recorded time by more than
  /// [OfferTiming.deliveryTolerance] belongs to a later dispatch of the same
  /// order to this driver (the earlier one was withdrawn, reassigned or
  /// answered while the app could not see it) and replaces the entry. Kept,
  /// the old time made the new offer expire on arrival.
  static Map<String, OfferSeen> record(Map<String, OfferSeen> log, String orderId, DateTime at, {bool push = false}) {
    final Map<String, OfferSeen> out = Map<String, OfferSeen>.of(log);
    final OfferSeen? old = out[orderId];
    if (push && old != null && at.difference(old.at) > OfferTiming.deliveryTolerance) {
      out[orderId] = OfferSeen(at, push: true);
      return out;
    }
    final DateTime earliest = old == null || at.isBefore(old.at) ? at : old.at;
    out[orderId] = OfferSeen(earliest, push: push || (old?.push ?? false));
    return out;
  }

  /// A dispatch push named the offer [seen] after [at] (a hand assignment
  /// marked then has ended: the Cloud Function offered the order again).
  static bool pushedAfter(OfferSeen? seen, DateTime at) => seen != null && seen.push && seen.at.isAfter(at);

  /// Drops entries older than [keep] and keeps the newest [cap].
  static Map<String, OfferSeen> prune(Map<String, OfferSeen> log, DateTime now) {
    final List<MapEntry<String, OfferSeen>> entries = log.entries.where((e) => now.difference(e.value.at) <= keep).toList()
      ..sort((a, b) => b.value.at.compareTo(a.value.at));
    return Map<String, OfferSeen>.fromEntries(entries.take(cap));
  }
}

/// What a check of a live order decided about an answer.
enum AcceptCheck {
  /// The answer may be written.
  ok,

  /// Accept only: the order is already this driver's job (a retried tap, a
  /// second device, the Cloud Function already advanced it).
  held,

  /// The order is no longer an offer this driver may answer.
  gone,
}

/// What `users/{me}.orderRequestData` may keep for an order.
enum RequestVerdict {
  /// Still an offer (or a hand assignment) waiting for this driver.
  keep,

  /// Not this driver's offer any more: dropped.
  stale,

  /// Accepted by this driver: it belongs in `inProgressOrderID`.
  accepted,
}

/// Order-level rules on raw order maps, the same for the four collections.
abstract final class DispatchOrderRules {
  /// The driver is working the order.
  static const List<String> workingStatuses = [Constant.driverAccepted, Constant.orderShipped, Constant.orderInTransit];

  /// Nothing is left for any driver to do.
  static const List<String> terminalStatuses = [Constant.orderCompleted, Constant.orderCancelled, Constant.orderRejected];

  /// `parcel_orders.parcelStatus` values that end a parcel (ParcelTrackingStatus).
  static const List<String> parcelEndStatuses = ['Returned', 'Cancelled'];

  static String _text(dynamic value) => (value ?? '').toString().trim();

  static String status(Map<String, dynamic> order) => _text(order['status']);

  /// The non-empty driver ids the order names (`driverId` and / or `driverID`).
  static Set<String> driverNames(Map<String, dynamic> order) => {_text(order['driverId']), _text(order['driverID'])}..remove('');

  static bool namesDriver(Map<String, dynamic> order, String uid) => uid.isNotEmpty && driverNames(order).contains(uid);

  static bool namesOther(Map<String, dynamic> order, String uid) {
    final Set<String> names = driverNames(order);
    return names.isNotEmpty && !names.contains(uid);
  }

  static bool rejectedBy(Map<String, dynamic> order, String uid) {
    final dynamic list = order['rejectedByDrivers'];
    return uid.isNotEmpty && list is List && list.map((e) => e.toString()).contains(uid);
  }

  /// D3: dispatched to this driver and waiting — `Driver Pending` with this
  /// driver named in either field.
  static bool isPendingFor(Map<String, dynamic>? order, String uid) =>
      order != null && status(order) == Constant.driverPending && namesDriver(order, uid);

  /// An offer the dispatch Cloud Function made, answered with the dialog and
  /// its countdown (D3, gap 23): pending for this driver, not one they
  /// rejected before, and announced as a dispatch — its id is in
  /// `orderRequestData` or a dispatch push named it. A store's own delivery
  /// man is assigned through `inProgressOrderID`, and an admin / store hand
  /// assignment the app put on the record itself is [handAssigned]: both stay
  /// on the module cards with no timer.
  ///
  /// A rental this driver countered the customer's price on and that waits
  /// for the customer's answer ([awaitsCustomer]) is not timed either: it
  /// cannot be accepted until the customer answers, so its countdown would
  /// only reject it on the driver's behalf.
  static bool isTimedOffer(
    Map<String, dynamic>? order, {
    required String uid,
    required String orderId,
    Iterable<dynamic> requests = const [],
    Iterable<dynamic> inProgress = const [],
    bool pushSeen = false,
    bool handAssigned = false,
  }) {
    if (!isPendingFor(order, uid) || rejectedBy(order!, uid)) return false;
    bool holds(Iterable<dynamic> ids) => ids.any((id) => id.toString() == orderId);
    if (holds(inProgress) || handAssigned || awaitsCustomer(order, uid)) return false;
    return holds(requests) || pushSeen;
  }

  /// The customer's price proposal on a rental (spec 4.9): `pending` (this
  /// driver answers it first, then the booking), `countered`, `accepted`,
  /// `rejected`; '' when there is none.
  static String proposalStatus(Map<String, dynamic>? order) {
    final dynamic proposal = order?['priceProposal'];
    return proposal is Map ? _text(proposal['status']) : '';
  }

  /// The rental waits for the customer's answer to the counter-offer THIS
  /// driver made (`priceProposal.counteredBy`, which the customer app
  /// requires to accept a counter). A counter left by another driver, or one
  /// that does not say who made it, can never be accepted by the customer
  /// for this driver: not waiting on them.
  static bool awaitsCustomer(Map<String, dynamic>? order, String uid) {
    if (uid.isEmpty || proposalStatus(order) != 'countered') return false;
    final dynamic proposal = order!['priceProposal'];
    return _text((proposal as Map)['counteredBy']) == uid;
  }

  /// Accept preconditions (D2), read inside the accept transaction.
  ///
  /// [heldAsRequest]: the driver's record holds the id as an offer
  /// (`orderRequestData`, a legacy `ordercabRequestData`, or a legacy pending
  /// ride in `inProgressOrderID`) — the only way an order that names nobody is
  /// this driver's to accept. [fromOpenSearch]: the parcel / rental search
  /// list, where an open `Order Placed` order that names nobody may be taken.
  static AcceptCheck acceptCheck(DispatchKind kind, Map<String, dynamic>? order, String uid, {bool heldAsRequest = false, bool fromOpenSearch = false}) {
    if (order == null || uid.isEmpty) return AcceptCheck.gone;
    final String s = status(order);
    final bool mine = namesDriver(order, uid);
    if (mine && workingStatuses.contains(s)) return AcceptCheck.held;
    if (namesOther(order, uid) || terminalStatuses.contains(s) || s == Constant.driverRejected) return AcceptCheck.gone;
    final bool unnamed = driverNames(order).isEmpty;
    final bool legacyRequest = unnamed && heldAsRequest && !rejectedBy(order, uid);
    if (s == Constant.driverPending) return mine || legacyRequest ? AcceptCheck.ok : AcceptCheck.gone;
    switch (kind) {
      case DispatchKind.delivery:
        // The admin panel's hand assignment: the store's status, this driver named.
        return s == Constant.orderAccepted && mine ? AcceptCheck.ok : AcceptCheck.gone;
      case DispatchKind.cab:
        // Rides offered before the Cloud Function (ordercabRequestData) or
        // handed over by name.
        if (s == Constant.orderPlaced || s == Constant.orderAccepted) return mine || legacyRequest ? AcceptCheck.ok : AcceptCheck.gone;
        return AcceptCheck.gone;
      case DispatchKind.parcel:
      case DispatchKind.rental:
        if (s != Constant.orderPlaced) return AcceptCheck.gone;
        if (mine) return AcceptCheck.ok;
        return fromOpenSearch && unnamed ? AcceptCheck.ok : AcceptCheck.gone;
    }
  }

  /// Reject preconditions (D2). A [timeout] answers only a `Driver Pending`
  /// offer that names this driver; a manual reject also answers a hand
  /// assignment waiting in its module's pending status and a legacy offer the
  /// driver holds ([heldAsRequest]).
  static bool canReject(DispatchKind kind, Map<String, dynamic>? order, String uid, {bool heldAsRequest = false, bool timeout = false}) {
    if (order == null || uid.isEmpty) return false;
    final String s = status(order);
    final bool mine = namesDriver(order, uid);
    if (timeout) return s == Constant.driverPending && mine;
    if (namesOther(order, uid)) return false;
    final bool legacyRequest = driverNames(order).isEmpty && heldAsRequest && !rejectedBy(order, uid);
    if (s == Constant.driverPending) return mine || legacyRequest;
    switch (kind) {
      case DispatchKind.delivery:
        return s == Constant.orderAccepted && mine;
      case DispatchKind.cab:
        return (s == Constant.orderPlaced || s == Constant.orderAccepted) && (mine || legacyRequest);
      case DispatchKind.parcel:
      case DispatchKind.rental:
        return s == Constant.orderPlaced && mine;
    }
  }

  /// D2 accept, order side: `Driver Accepted` with this driver in both
  /// fields. [extra] adds known fields (`regionId`, `receiverPickupDateTime`).
  static Map<String, dynamic> acceptFields(String uid, Map<String, dynamic> driverJson, {Map<String, dynamic> extra = const {}}) => <String, dynamic>{
        'status': Constant.driverAccepted,
        'driverId': uid,
        'driverID': uid,
        'driver': driverJson,
        ...extra,
      };

  /// D2 reject / timeout, order side: back to dispatch with this driver
  /// excluded, both driver fields set to null (not deleted, not ''). A manual
  /// reject adds [reasonFields] (`driverRejections`, CANCEL-REASON-CONTRACT);
  /// a timeout writes no reason. Never the final cancellation fields.
  static Map<String, dynamic> rejectFields(String uid, {Map<String, dynamic>? reasonFields}) => <String, dynamic>{
        'status': Constant.driverRejected,
        'rejectedByDrivers': FieldValue.arrayUnion([uid]),
        'driverId': null,
        'driverID': null,
        ...?reasonFields,
      };

  /// A booking this driver accepted and now gives back (a rental cancelled
  /// after accept, CANCEL-REASON-CONTRACT `afterAccept: true`): allowed while
  /// it names this driver and nobody else and has not started yet
  /// (`Order Placed` hand assignment or `Driver Accepted`).
  static bool canHandBack(Map<String, dynamic>? order, String uid) {
    if (order == null || uid.isEmpty) return false;
    final Set<String> names = driverNames(order);
    if (names.length != 1 || names.single != uid) return false;
    final String s = status(order);
    return s == Constant.orderPlaced || s == Constant.driverAccepted;
  }

  /// The hand-back write: the same D2 `Driver Rejected` record as a reject
  /// (DRIVER_DISPATCH_DOCUMENTATION.md §1: the dispatch functions re-offer an
  /// order on `Driver Rejected`; `Order Placed` is only the creation status),
  /// with the reason [reasonFields] and this driver's snapshot removed.
  static Map<String, dynamic> handBackFields(String uid, {required Map<String, dynamic> reasonFields}) => <String, dynamic>{
        ...rejectFields(uid, reasonFields: reasonFields),
        'driver': FieldValue.delete(),
      };

  /// What `orderRequestData` may keep for [order] (server data only; null =
  /// the order does not exist).
  static RequestVerdict requestVerdict(Map<String, dynamic>? order, String uid) {
    if (order == null) return RequestVerdict.stale;
    final String s = status(order);
    final bool mine = namesDriver(order, uid);
    if (namesOther(order, uid) || terminalStatuses.contains(s) || s == Constant.driverRejected) return RequestVerdict.stale;
    if (workingStatuses.contains(s)) return mine ? RequestVerdict.accepted : RequestVerdict.stale;
    if (rejectedBy(order, uid) && !mine) return RequestVerdict.stale;
    if (s == Constant.driverPending) return RequestVerdict.keep;
    // A hand assignment waiting in the module's own pending status.
    if ((s == Constant.orderAccepted || s == Constant.orderPlaced) && mine) return RequestVerdict.keep;
    return RequestVerdict.stale;
  }

  /// An `inProgressOrderID` entry of a ride / parcel / rental that can never
  /// be this driver's active job again (spec §4: accepted and active only):
  /// gone, finished, handed back to dispatch or to the open search, or
  /// another driver's. Server data only. Delivery keeps
  /// `AssignedDeliveryOrders.isStaleInProgress`.
  static bool isStaleInProgress(DispatchKind kind, Map<String, dynamic>? order, String uid) {
    if (order == null) return true;
    final String s = status(order);
    if (terminalStatuses.contains(s)) return true;
    if (kind == DispatchKind.parcel && parcelEndStatuses.contains(_text(order['parcelStatus']))) return true;
    if (namesOther(order, uid)) return true;
    final bool mine = namesDriver(order, uid);
    if (s == Constant.driverRejected) return !mine || rejectedBy(order, uid);
    // Back in the open search / not yet dispatched, and naming nobody.
    if (s == Constant.orderPlaced || s == Constant.orderAccepted) return !mine;
    return false;
  }
}

/// Why a driver may not take an offer right now — the gates of the module
/// cards (cab_home_screen.dart, the parcel and rental search), applied the
/// same way by the incoming-offer dialog.
enum OfferGate {
  open,

  /// A freelance driver whose documents are not verified (and who is not
  /// auto-verified).
  documentsPending,

  /// An independent driver below `minimumDepositToRideAccept`.
  ownWallet,

  /// A company's driver whose company is below
  /// `ownerMinimumDepositToRideAccept`.
  ownerWallet,
}

abstract final class DispatchGateRules {
  /// [freelance]: no `vendorID` (not a store's own delivery man).
  /// [ownerWallet] null: the company's wallet could not be read.
  /// [handAssigned]: an order the admin / store handed to this driver by
  /// name (no countdown) — like a ride assigned on the cab home, it is never
  /// held back by pending documents; the wallet minimum still applies, as on
  /// every module's Accept.
  static OfferGate check({
    required bool freelance,
    required bool documentsPending,
    required String? ownerId,
    required num? ownWallet,
    required num? ownerWallet,
    required num minimumDeposit,
    required num ownerMinimumDeposit,
    bool handAssigned = false,
  }) {
    if (freelance && documentsPending && !handAssigned) return OfferGate.documentsPending;
    if ((ownerId ?? '').trim().isNotEmpty) {
      return ownerWallet != null && ownerWallet >= ownerMinimumDeposit ? OfferGate.open : OfferGate.ownerWallet;
    }
    // A store's own delivery man works for the store: no deposit.
    if (!freelance) return OfferGate.open;
    return (ownWallet ?? 0) >= minimumDeposit ? OfferGate.open : OfferGate.ownWallet;
  }
}

/// What the incoming-offer dialog shows for an order, read tolerantly from
/// the raw document (a record written by a panel may lack any field).
class OfferSummary {
  final DispatchKind kind;
  final String orderId;
  final String pickupLabel;
  final String pickupAddress;
  final String dropLabel;
  final String dropAddress;

  /// Numeric texts, null when absent.
  final String? fare;
  final String? tip;
  final String? distance;
  final String? weight;
  final String? rideType;
  final String? packageName;
  final String? includedDistance;
  final String? includedHours;
  final DateTime? scheduledAt;
  final String? sectionId;
  final String? regionId;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropLat;
  final double? dropLng;

  const OfferSummary({
    required this.kind,
    required this.orderId,
    this.pickupLabel = '',
    this.pickupAddress = '',
    this.dropLabel = '',
    this.dropAddress = '',
    this.fare,
    this.tip,
    this.distance,
    this.weight,
    this.rideType,
    this.packageName,
    this.includedDistance,
    this.includedHours,
    this.scheduledAt,
    this.sectionId,
    this.regionId,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
  });

  static Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

  static String _text(dynamic v) => AddressFormat.part(v) ?? '';

  static String? _number(dynamic v) {
    if (v == null) return null;
    final num? n = v is num ? v : num.tryParse(v.toString().trim());
    return n == null || !n.isFinite ? null : n.toString();
  }

  static double? _coord(dynamic v) {
    final num? n = v is num ? v : num.tryParse((v ?? '').toString().trim());
    return n == null || !n.isFinite ? null : n.toDouble();
  }

  /// A parcel's "Amount": the total the customer was charged
  /// ([ParcelAmounts]: platform fee and its taxes, the fixed tax and the
  /// receiver-SMS fee included) — the figure the parcel search, the home job
  /// card, the details "Order Total" and the export show, and the cash a
  /// driver collects on a cash parcel. The bare `subTotal` when the record
  /// cannot be read as a parcel.
  static String? _parcelTotal(Map<String, dynamic> order) {
    try {
      final double total = ParcelAmounts.of(ParcelOrderModel.fromJson(order)).total;
      if (total.isFinite && (total != 0 || order['subTotal'] != null)) return _number(total);
    } catch (_) {
      // Unreadable as a parcel: the raw fare below.
    }
    return _number(order['subTotal']);
  }

  static String _person(dynamic author) {
    final Map<String, dynamic> a = _map(author);
    return [_text(a['firstName']), _text(a['lastName'])].where((p) => p.isNotEmpty).join(' ');
  }

  factory OfferSummary.fromOrder(DispatchKind kind, String orderId, Map<String, dynamic> order) {
    switch (kind) {
      case DispatchKind.delivery:
        final Map<String, dynamic> vendor = _map(order['vendor']);
        final Map<String, dynamic> address = _map(order['address']);
        final Map<String, dynamic> drop = _map(address['location']);
        return OfferSummary(
          kind: kind,
          orderId: orderId,
          pickupLabel: _text(vendor['title']),
          pickupAddress: AddressFormat.clean(vendor['location']),
          dropLabel: _person(order['author']),
          dropAddress: AddressFormat.fromMap(address),
          fare: _number(order['deliveryCharge']),
          tip: _number(order['tip_amount']),
          sectionId: _text(order['section_id']).isEmpty ? null : _text(order['section_id']),
          regionId: _text(order['regionId']).isEmpty ? null : _text(order['regionId']),
          pickupLat: _coord(vendor['latitude']),
          pickupLng: _coord(vendor['longitude']),
          dropLat: _coord(drop['latitude']),
          dropLng: _coord(drop['longitude']),
        );
      case DispatchKind.cab:
        final Map<String, dynamic> from = _map(order['sourceLocation']);
        final Map<String, dynamic> to = _map(order['destinationLocation']);
        return OfferSummary(
          kind: kind,
          orderId: orderId,
          pickupLabel: _person(order['author']),
          pickupAddress: AddressFormat.clean(order['sourceLocationName']),
          dropAddress: AddressFormat.clean(order['destinationLocationName']),
          fare: _number(order['subTotal']),
          tip: _number(order['tip_amount']),
          distance: _number(order['distance']),
          rideType: _text(order['rideType']).isEmpty ? null : _text(order['rideType']),
          scheduledAt: OfferTiming.readTime(order['scheduleDateTime']),
          sectionId: _text(order['sectionId']).isEmpty ? null : _text(order['sectionId']),
          regionId: _text(order['regionId']).isEmpty ? null : _text(order['regionId']),
          pickupLat: _coord(from['latitude']),
          pickupLng: _coord(from['longitude']),
          dropLat: _coord(to['latitude']),
          dropLng: _coord(to['longitude']),
        );
      case DispatchKind.parcel:
        final Map<String, dynamic> sender = _map(order['sender']);
        final Map<String, dynamic> receiver = _map(order['receiver']);
        final Map<String, dynamic> from = _map(order['senderLatLong']);
        final Map<String, dynamic> to = _map(order['receiverLatLong']);
        return OfferSummary(
          kind: kind,
          orderId: orderId,
          pickupLabel: _text(sender['name']),
          pickupAddress: AddressFormat.clean(sender['address']),
          // The flat receiver name first (an order the website / panel wrote
          // may carry only that), else the receiver map's.
          dropLabel: _text(order['receiverName']).isNotEmpty ? _text(order['receiverName']) : _text(receiver['name']),
          dropAddress: AddressFormat.clean(receiver['address']),
          fare: _parcelTotal(order),
          distance: _number(order['distance']),
          weight: _text(order['parcelWeight']).isEmpty ? null : _text(order['parcelWeight']),
          scheduledAt: OfferTiming.readTime(order['senderPickupDateTime']),
          sectionId: _text(order['sectionId']).isEmpty ? null : _text(order['sectionId']),
          regionId: _text(order['regionId']).isEmpty ? null : _text(order['regionId']),
          pickupLat: _coord(from['latitude']),
          pickupLng: _coord(from['longitude']),
          dropLat: _coord(to['latitude']),
          dropLng: _coord(to['longitude']),
        );
      case DispatchKind.rental:
        final Map<String, dynamic> package = _map(order['rentalPackageModel']);
        final Map<String, dynamic> from = _map(order['sourceLocation']);
        return OfferSummary(
          kind: kind,
          orderId: orderId,
          pickupLabel: _person(order['author']),
          pickupAddress: AddressFormat.clean(order['sourceLocationName']),
          fare: _number(order['subTotal']),
          packageName: _text(package['name']).isEmpty ? null : _text(package['name']),
          includedDistance: _number(package['includedDistance']),
          includedHours: _number(package['includedHours']),
          scheduledAt: OfferTiming.readTime(order['bookingDateTime']),
          sectionId: _text(order['sectionId']).isEmpty ? null : _text(order['sectionId']),
          regionId: _text(order['regionId']).isEmpty ? null : _text(order['regionId']),
          pickupLat: _coord(from['latitude']),
          pickupLng: _coord(from['longitude']),
        );
    }
  }
}

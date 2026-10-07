import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/dispatch_offer_rules.dart';
import 'package:driver/utils/fire_store_utils.dart';

/// Which delivery orders (`vendor_orders`) a driver can act on, decided from
/// the order record itself rather than from the position of its id in
/// `users.inProgressOrderID`.
///
/// Why this exists ("drivers cannot perform any actions when an order is
/// assigned to them"): the home screens used to take `inProgressOrderID.first`
/// and show whatever that order was. That array is written by several hands —
/// this app, the Store app (which writes the driver's WHOLE user document from
/// a copy it read when its "assign" dialog opened), the admin panel and
/// [DriverAssignmentWatcher] — so it can hold an id that is already finished
/// (completed, cancelled, rejected) or that was handed to another driver. A
/// stale id in first place hid the order that was really assigned: the screen
/// showed a finished order (no buttons) or nothing at all.
abstract final class AssignedDeliveryOrders {
  /// The driver is working the order: heading to the store, or to the customer.
  static const List<String> workingStatuses = [
    Constant.driverAccepted,
    Constant.orderShipped,
    Constant.orderInTransit,
  ];

  /// Nothing is left for any driver to do.
  static const List<String> terminalStatuses = [
    Constant.orderCompleted,
    Constant.orderCancelled,
    Constant.orderRejected,
  ];

  static bool _rejectedBy(OrderModel order, String? uid) => uid != null && (order.rejectedByDrivers ?? const []).contains(uid);

  static bool _otherDriver(OrderModel order, String? uid) {
    final String driverId = (order.driverID ?? '').trim();
    return driverId.isNotEmpty && uid != null && driverId != uid;
  }

  /// An order this driver can pick up / deliver now. An order whose
  /// `driverID` is still empty is accepted as before (older writers set only
  /// `inProgressOrderID`); one that names another driver is not.
  static bool isWorkableFor(OrderModel order, String? uid) {
    if (order.id == null) return false;
    if (!workingStatuses.contains(order.status)) return false;
    // An order this driver once rejected counts again only when it was then
    // handed to them by name.
    if (_rejectedBy(order, uid) && !isNamedFor(order, uid)) return false;
    return !_otherDriver(order, uid);
  }

  /// A request this driver may accept or reject: a dispatched offer, or a
  /// hand assignment written as `Driver Pending` with this driver named. A
  /// pending order that names ANOTHER driver is that driver's hand
  /// assignment, not an offer: accepting it took their job.
  static bool isOfferFor(OrderModel order, String? uid) {
    if (order.id == null || !awaitsDriver(order, uid)) return false;
    return !_rejectedBy(order, uid) && !_otherDriver(order, uid);
  }

  /// The order waits for this driver to accept or reject it: `Driver Pending`
  /// (dispatched or hand-assigned), or a hand assignment that left the order
  /// at the store's `Order Accepted` with this driver named (`driverID`). The
  /// admin panel assigns that way: the driver used to get no button at all,
  /// because `Order Accepted` was neither an offer nor a job in progress.
  static bool awaitsDriver(OrderModel order, String? uid) {
    if (order.status == Constant.driverPending) return true;
    return order.status == Constant.orderAccepted && isNamedFor(order, uid);
  }

  /// A `Driver Pending` order that names this driver (`driverID == uid`) — a
  /// hand assignment rather than a dispatched offer.
  static bool isNamedFor(OrderModel order, String? uid) => uid != null && (order.driverID ?? '').trim() == uid;

  /// An `inProgressOrderID` entry that can never become workable again for
  /// this driver: the order is finished, or another driver is working it.
  static bool isStaleInProgress(OrderModel order, String uid) {
    if (terminalStatuses.contains(order.status)) return true;
    if (order.status == Constant.driverRejected && _rejectedBy(order, uid)) return true;
    return workingStatuses.contains(order.status) && _otherDriver(order, uid);
  }

  static final Set<String> _pruning = {};

  /// Removes stale entries from `users/{uid}.inProgressOrderID` with a
  /// field-level `arrayRemove`, so nothing else on the document is touched.
  /// Only call it with orders read from the server (not the local cache).
  static void pruneStale(String uid, List<dynamic>? inProgress, Map<String, OrderModel> orders) {
    final List<String> stale = [];
    for (final dynamic raw in inProgress ?? const []) {
      final String id = raw.toString();
      final OrderModel? order = orders[id];
      if (order == null || !isStaleInProgress(order, uid)) continue;
      if (_pruning.add(id)) stale.add(id);
    }
    if (stale.isEmpty) return;
    log("AssignedDeliveryOrders: removing finished / reassigned $stale from $uid.inProgressOrderID");
    FireStoreUtils.updateUserFields(uid, {'inProgressOrderID': FieldValue.arrayRemove(stale)}).whenComplete(() => _pruning.removeAll(stale));
  }

  static DocumentReference<Map<String, dynamic>> _orderRef(String orderId) => FireStoreUtils.fireStore.collection(CollectionName.vendorOrders).doc(orderId);

  static OrderModel? _parse(Map<String, dynamic>? data) {
    if (data == null) return null;
    try {
      return OrderModel.fromJson(data);
    } catch (e) {
      log("AssignedDeliveryOrders: an order could not be read: $e");
      return null;
    }
  }

  /// Accepts the delivery offer [orderId] for [driver] (D2), in a transaction
  /// that first re-checks the live order ([DispatchOrderRules.acceptCheck]):
  /// only a `Driver Pending` order that names this driver (`driverID` or
  /// `driverId`), the admin's `Order Accepted` + `driverID` hand assignment,
  /// or a legacy offer that names nobody and that the driver holds
  /// ([heldAsRequest]; by default: the id is on the driver's record). A
  /// cancelled order, one handed to another driver or one whose window is
  /// over is never taken, whatever the screen still shows.
  ///
  /// The order gets `Driver Accepted` with this driver in both fields and
  /// `driver` (known fields only); then the driver's arrays move field-level:
  /// `inProgressOrderID` arrayUnion, `orderRequestData` arrayRemove. The
  /// Cloud Function then advances the order to `Order Shipped` itself: a
  /// retried tap afterwards finds it [OfferAnswer.held] and writes nothing.
  ///
  /// [OfferAnswer.gone] drops the id from `orderRequestData`.
  static Future<({OfferAnswer answer, OrderModel? order})> acceptOffer(String orderId, UserModel driver, {bool? heldAsRequest}) async {
    final String uid = driver.id ?? '';
    if (uid.isEmpty || orderId.isEmpty) return (answer: OfferAnswer.failed, order: null);
    final bool held = heldAsRequest ?? [...?driver.orderRequestData, ...?driver.inProgressOrderID].any((id) => id.toString() == orderId);
    final DocumentReference<Map<String, dynamic>> ref = _orderRef(orderId);
    final ({AcceptCheck check, Map<String, dynamic>? data}) outcome;
    try {
      outcome = await FireStoreUtils.fireStore.runTransaction<({AcceptCheck check, Map<String, dynamic>? data})>((tx) async {
        final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
        final Map<String, dynamic>? data = snap.exists ? snap.data() : null;
        final AcceptCheck check = DispatchOrderRules.acceptCheck(DispatchKind.delivery, data, uid, heldAsRequest: held);
        if (check == AcceptCheck.ok) {
          final Map<String, dynamic> fields = DispatchOrderRules.acceptFields(uid, driver.toJson());
          tx.set(ref, fields, SetOptions(mergeFields: fields.keys.map((key) => FieldPath([key])).toList()));
        }
        return (check: check, data: data);
      });
    } catch (e) {
      log("AssignedDeliveryOrders.acceptOffer($orderId) failed: $e");
      return (answer: OfferAnswer.failed, order: null);
    }
    final OrderModel? live = _parse(outcome.data);
    switch (outcome.check) {
      case AcceptCheck.ok:
        await _holdAccepted(uid, orderId);
        return (answer: OfferAnswer.done, order: live);
      case AcceptCheck.held:
        // Already this driver's (a retried tap, a second device, or the
        // Cloud Function already moved it on): only make sure the driver's
        // record holds it.
        await _holdAccepted(uid, orderId);
        return (answer: OfferAnswer.held, order: live);
      case AcceptCheck.gone:
        await FireStoreUtils.updateUserFields(uid, {
          'orderRequestData': FieldValue.arrayRemove([orderId])
        });
        return (answer: OfferAnswer.gone, order: live);
    }
  }

  static Future<bool> _holdAccepted(String uid, String orderId) => FireStoreUtils.updateUserFields(uid, {
        'inProgressOrderID': FieldValue.arrayUnion([orderId]),
        'orderRequestData': FieldValue.arrayRemove([orderId]),
      });

  /// Rejects the delivery offer [orderId] for [uid] (D2) in a transaction that
  /// first re-checks the live order: a manual reject answers an offer
  /// ([isOfferFor]), a [timeout] only a `Driver Pending` order that still names
  /// this driver ([DispatchOrderRules.isPendingFor]). A rejection used to
  /// write "Driver Rejected" unconditionally, sending a cancelled order back
  /// to dispatch or killing a job another driver was already working.
  ///
  /// The order goes back to dispatch: `Driver Rejected`, this driver in
  /// `rejectedByDrivers`, `driverId` and `driverID` set to null. A manual
  /// reject also appends its mandatory reason ([reasonFields],
  /// `CancelReasonResult.toFields`) to `driverRejections`; a timeout and the
  /// automatic out-of-region decline write no reason.
  ///
  /// Afterwards the id leaves the driver's arrays, field-level: on
  /// [OfferAnswer.done] both `orderRequestData` and `inProgressOrderID` (a
  /// store's own assignment is held there), on [OfferAnswer.gone]
  /// `orderRequestData` only.
  static Future<OfferAnswer> rejectOffer(String orderId, String uid, {Map<String, dynamic>? reasonFields, bool timeout = false}) async {
    if (orderId.isEmpty || uid.isEmpty) return OfferAnswer.failed;
    final DocumentReference<Map<String, dynamic>> ref = _orderRef(orderId);
    final OfferAnswer answer;
    try {
      answer = await FireStoreUtils.fireStore.runTransaction<OfferAnswer>((tx) async {
        final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
        final Map<String, dynamic>? data = snap.exists ? snap.data() : null;
        if (data == null) return OfferAnswer.gone;
        if (timeout) {
          if (!DispatchOrderRules.isPendingFor(data, uid)) return OfferAnswer.gone;
        } else {
          final OrderModel? order = _parse(data);
          if (order == null || !isOfferFor(order, uid) || DispatchOrderRules.namesOther(data, uid)) return OfferAnswer.gone;
        }
        final Map<String, dynamic> fields = DispatchOrderRules.rejectFields(uid, reasonFields: timeout ? null : reasonFields);
        tx.set(ref, fields, SetOptions(mergeFields: fields.keys.map((key) => FieldPath([key])).toList()));
        return OfferAnswer.done;
      });
    } catch (e) {
      log("AssignedDeliveryOrders.rejectOffer($orderId) failed: $e");
      return OfferAnswer.failed;
    }
    await FireStoreUtils.updateUserFields(uid, {
      'orderRequestData': FieldValue.arrayRemove([orderId]),
      if (answer == OfferAnswer.done) 'inProgressOrderID': FieldValue.arrayRemove([orderId]),
    });
    return answer;
  }
}

/// What became of a driver's accept / reject of a delivery offer.
enum OfferAnswer {
  /// Written.
  done,

  /// Accept only: the order was already this driver's; nothing was written
  /// to it.
  held,

  /// The live order is no longer an offer this driver may answer (cancelled,
  /// taken, handed to another driver, already rejected). The order was not
  /// touched; the id was dropped from the driver's requests.
  gone,

  /// The order could not be read or written (offline, rules). Nothing
  /// changed; the driver can try again.
  failed,

  /// Accept only: refused for a reason the driver can act on (a rental whose
  /// price proposal is still open). Nothing was written.
  blocked,
}

/// One live query over a set of order ids in [collection] (`whereIn` on the
/// `id` field, chunks of 30), re-opened only when the set of ids changes.
/// Replaces a new listener per user-document snapshot — the user document is
/// rewritten on every location update, so those piled up, and an old order's
/// listener could overwrite the order on screen.
///
/// A failed listen keeps the set of ids ([watch] with the same ids stays a
/// no-op) and is retried by this class after [retryDelays]. It used to forget
/// the ids, and a caller that calls [watch] again from [onChange] (the cab
/// screen) re-opened the failing query at once, in a tight loop. A `whereIn`
/// query that keeps failing ([queryFailuresBeforeFallback] times in a row —
/// e.g. rules that allow reading each order but not the query) is replaced by
/// one listener per order document, for the rest of this watch's life.
class OrdersByIdWatch<T> {
  OrdersByIdWatch({required this.collection, required this.parse, required this.idOf, required this.onChange});

  final String collection;
  final T Function(Map<String, dynamic> json) parse;
  final String? Function(T order) idOf;

  /// Every order currently found for the ids, and whether the data came from
  /// the server (true) or only from the local cache (false).
  final void Function(Map<String, T> orders, bool fromServer) onChange;

  /// Waits before re-opening a failed listener: 2s, 5s, 15s, then every 30s.
  static const List<Duration> retryDelays = [Duration(seconds: 2), Duration(seconds: 5), Duration(seconds: 15), Duration(seconds: 30)];

  /// Consecutive failures of a `whereIn` chunk after which every id is
  /// watched through its own document listener instead.
  static const int queryFailuresBeforeFallback = 3;

  // One "unit" per open listener: a `whereIn` chunk ('q0', 'q1', ...) or,
  // after the fallback, one order document ('d<id>').
  final Map<String, StreamSubscription<dynamic>> _subs = {};
  final Map<String, Timer> _retries = {};
  final Map<String, int> _failures = {};
  final Map<String, Map<String, T>> _found = {};
  final Map<String, bool> _fromServer = {};
  List<String> _ids = const [];
  int _units = 0;
  int _generation = 0;
  bool _byDocument = false;
  String? _key;
  bool _loaded = false;

  /// True once every chunk has delivered its first snapshot (or failed).
  bool get loaded => _loaded;

  void watch(Iterable<dynamic> rawIds) {
    // Sorted: the key is the SET of ids. Moving an id between the driver's
    // arrays (accept moves it from requests to in-progress) reordered the
    // list, re-opened the listener, and its first event, straight from the
    // cache, replaced the order being accepted with an older copy.
    final List<String> ids = <String>{for (final dynamic id in rawIds) if (id != null && id.toString().isNotEmpty) id.toString()}.toList()..sort();
    final String key = ids.join(',');
    if (key == _key) return;
    cancel();
    _key = key;
    _ids = ids;
    if (ids.isEmpty) {
      _loaded = true;
      onChange(const {}, true);
      return;
    }
    _open();
  }

  void _open() {
    final int generation = _generation;
    if (_byDocument) {
      _units = _ids.length;
      for (final String id in _ids) {
        _listenDocument(id, generation);
      }
      return;
    }
    final List<List<String>> chunks = [
      for (int start = 0; start < _ids.length; start += 30) _ids.sublist(start, start + 30 > _ids.length ? _ids.length : start + 30),
    ];
    _units = chunks.length;
    for (int index = 0; index < chunks.length; index++) {
      _listenQuery('q$index', chunks[index], generation);
    }
  }

  void _listenQuery(String unit, List<String> chunk, int generation) {
    if (generation != _generation) return;
    _subs.remove(unit)?.cancel();
    _subs[unit] = FireStoreUtils.fireStore.collection(collection).where('id', whereIn: chunk).snapshots().listen(
      (snap) {
        if (generation != _generation) return;
        if (!snap.metadata.isFromCache) _failures.remove(unit);
        final Map<String, T> found = {};
        for (final doc in snap.docs) {
          try {
            final T order = parse(doc.data());
            found[idOf(order) ?? doc.id] = order;
          } catch (e) {
            // One unreadable record must not hide every other order.
            log("OrdersByIdWatch($collection): ${doc.id} could not be read: $e");
          }
        }
        _deliver(unit, found, !snap.metadata.isFromCache);
      },
      onError: (Object e) {
        if (generation != _generation) return;
        final int failures = (_failures[unit] ?? 0) + 1;
        _failures[unit] = failures;
        log("OrdersByIdWatch($collection) failed ($failures in a row): $e");
        _failed(unit);
        if (generation != _generation) return; // onChange watched other ids
        if (failures >= queryFailuresBeforeFallback) {
          log("OrdersByIdWatch($collection): the query keeps failing, watching each order document instead");
          _switchToDocuments();
          return;
        }
        _retryLater(unit, failures, () => _listenQuery(unit, chunk, generation));
      },
      cancelOnError: true,
    );
  }

  void _listenDocument(String id, int generation) {
    if (generation != _generation) return;
    final String unit = 'd$id';
    _subs.remove(unit)?.cancel();
    _subs[unit] = FireStoreUtils.fireStore.collection(collection).doc(id).snapshots().listen(
      (snap) {
        if (generation != _generation) return;
        if (!snap.metadata.isFromCache) _failures.remove(unit);
        final Map<String, T> found = {};
        final Map<String, dynamic>? data = snap.data();
        if (snap.exists && data != null) {
          try {
            final T order = parse(data);
            found[idOf(order) ?? snap.id] = order;
          } catch (e) {
            log("OrdersByIdWatch($collection): $id could not be read: $e");
          }
        }
        _deliver(unit, found, !snap.metadata.isFromCache);
      },
      onError: (Object e) {
        if (generation != _generation) return;
        final int failures = (_failures[unit] ?? 0) + 1;
        _failures[unit] = failures;
        log("OrdersByIdWatch($collection): $id failed ($failures in a row): $e");
        _failed(unit);
        if (generation != _generation) return;
        _retryLater(unit, failures, () => _listenDocument(id, generation));
      },
      cancelOnError: true,
    );
  }

  /// The ids stay the same: whatever was last found for [unit] is kept (a
  /// failure is not "the order is gone"), only marked as not from the server.
  void _failed(String unit) {
    _subs.remove(unit);
    _found.putIfAbsent(unit, () => const {});
    _fromServer[unit] = false;
    _emit();
  }

  void _retryLater(String unit, int failures, void Function() reopen) {
    final Duration delay = retryDelays[(failures - 1).clamp(0, retryDelays.length - 1)];
    _retries.remove(unit)?.cancel();
    _retries[unit] = Timer(delay, () {
      _retries.remove(unit);
      reopen();
    });
  }

  /// Same ids, one document listener each. What is on screen stays until
  /// every document has answered.
  void _switchToDocuments() {
    final String? key = _key;
    final List<String> ids = _ids;
    final bool loaded = _loaded;
    cancel();
    _byDocument = true;
    _key = key;
    _ids = ids;
    _loaded = loaded;
    _open();
  }

  void _deliver(String unit, Map<String, T> found, bool fromServer) {
    _found[unit] = found;
    _fromServer[unit] = fromServer;
    _emit();
  }

  void _emit() {
    if (_found.length < _units) return;
    _loaded = true;
    final Map<String, T> all = {};
    for (final Map<String, T> unit in _found.values) {
      all.addAll(unit);
    }
    onChange(all, _fromServer.values.every((v) => v));
  }

  void cancel() {
    _generation++;
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _subs.clear();
    for (final timer in _retries.values) {
      timer.cancel();
    }
    _retries.clear();
    _failures.clear();
    _found.clear();
    _fromServer.clear();
    _ids = const [];
    _units = 0;
    _key = null;
    _loaded = false;
  }
}

/// [OrdersByIdWatch] over `vendor_orders`.
class VendorOrdersWatch extends OrdersByIdWatch<OrderModel> {
  VendorOrdersWatch(void Function(Map<String, OrderModel> orders, bool fromServer) onChange)
      : super(collection: CollectionName.vendorOrders, parse: OrderModel.fromJson, idOf: (order) => order.id, onChange: onChange);
}

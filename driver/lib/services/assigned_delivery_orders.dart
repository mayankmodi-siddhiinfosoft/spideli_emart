import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/user_model.dart';
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
    if (order.id == null || order.status != Constant.driverPending) return false;
    return !_rejectedBy(order, uid) && !_otherDriver(order, uid);
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

  /// Accepts the delivery offer [orderId] for [driver], re-checked against
  /// the live order first: the screen may show an id that is no longer an
  /// offer (cancelled while still offered, handed to another driver, already
  /// taken), and accepting it brought a cancelled order back or took another
  /// driver's job.
  ///
  /// The order is written first (`status`, `driverID`, `driver` only), then
  /// the driver's arrays with `arrayUnion` / `arrayRemove`, never the whole
  /// user document from a local copy. Both are ordinary writes rather than a
  /// transaction on purpose: a transaction's write reaches the listeners
  /// without the local pending write, and `DriverAssignmentWatcher` then
  /// announces the driver's own accept as "a job has been assigned to you".
  ///
  /// [OfferAnswer.gone] drops the id from `orderRequestData`.
  static Future<({OfferAnswer answer, OrderModel? order})> acceptOffer(String orderId, UserModel driver) async {
    final String? uid = driver.id;
    if (uid == null || orderId.isEmpty) return (answer: OfferAnswer.failed, order: null);
    final OrderModel? live;
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await _orderRef(orderId).get();
      final Map<String, dynamic>? data = snap.data();
      live = snap.exists && data != null ? OrderModel.fromJson(data) : null;
    } catch (e) {
      log("AssignedDeliveryOrders.acceptOffer($orderId): the order could not be read: $e");
      return (answer: OfferAnswer.failed, order: null);
    }
    // Already this driver's (a retried tap, a second device): only make sure
    // the driver's record holds it.
    if (live != null && isWorkableFor(live, uid) && isNamedFor(live, uid)) {
      await _holdAccepted(uid, orderId);
      return (answer: OfferAnswer.held, order: live);
    }
    if (live == null || !isOfferFor(live, uid)) {
      await FireStoreUtils.updateUserFields(uid, {
        'orderRequestData': FieldValue.arrayRemove([orderId])
      });
      return (answer: OfferAnswer.gone, order: live);
    }
    final bool written = await FireStoreUtils.updateVendorOrderFields(orderId, {
      'status': Constant.driverAccepted,
      'driverID': uid,
      'driver': driver.toJson(),
    });
    if (!written) return (answer: OfferAnswer.failed, order: live);
    await _holdAccepted(uid, orderId);
    return (answer: OfferAnswer.done, order: live);
  }

  static Future<bool> _holdAccepted(String uid, String orderId) => FireStoreUtils.updateUserFields(uid, {
        'inProgressOrderID': FieldValue.arrayUnion([orderId]),
        'orderRequestData': FieldValue.arrayRemove([orderId]),
      });

  /// Rejects the delivery offer [orderId] for [uid] in a transaction that
  /// first re-checks the live order ([isOfferFor]): a rejection used to write
  /// "Driver Rejected" unconditionally, sending a cancelled order back to
  /// dispatch or killing a job another driver was already working.
  /// [reasonFields] is the mandatory reason (`CancelReasonResult.toFields`).
  ///
  /// Afterwards the id leaves the driver's arrays, field-level: on
  /// [OfferAnswer.done] both `orderRequestData` and `inProgressOrderID`, on
  /// [OfferAnswer.gone] `orderRequestData` only.
  static Future<OfferAnswer> rejectOffer(String orderId, String uid, Map<String, dynamic> reasonFields) async {
    if (orderId.isEmpty || uid.isEmpty) return OfferAnswer.failed;
    final DocumentReference<Map<String, dynamic>> ref = _orderRef(orderId);
    final OfferAnswer answer;
    try {
      answer = await FireStoreUtils.fireStore.runTransaction<OfferAnswer>((tx) async {
        final DocumentSnapshot<Map<String, dynamic>> snap = await tx.get(ref);
        final Map<String, dynamic>? data = snap.data();
        if (!snap.exists || data == null || !isOfferFor(OrderModel.fromJson(data), uid)) return OfferAnswer.gone;
        final Map<String, dynamic> fields = {
          'status': Constant.driverRejected,
          'rejectedByDrivers': FieldValue.arrayUnion([uid]),
          ...reasonFields,
        };
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
}

/// One live query over a set of order ids in [collection] (`whereIn` on the
/// `id` field, chunks of 30), re-opened only when the set of ids changes.
/// Replaces a new listener per user-document snapshot — the user document is
/// rewritten on every location update, so those piled up, and an old order's
/// listener could overwrite the order on screen.
class OrdersByIdWatch<T> {
  OrdersByIdWatch({required this.collection, required this.parse, required this.idOf, required this.onChange});

  final String collection;
  final T Function(Map<String, dynamic> json) parse;
  final String? Function(T order) idOf;

  /// Every order currently found for the ids, and whether the data came from
  /// the server (true) or only from the local cache (false).
  final void Function(Map<String, T> orders, bool fromServer) onChange;

  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs = [];
  final Map<int, Map<String, T>> _chunks = {};
  final Map<int, bool> _chunkFromServer = {};
  String? _key;
  bool _loaded = false;

  /// True once every chunk has delivered its first snapshot.
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
    if (ids.isEmpty) {
      _loaded = true;
      onChange(const {}, true);
      return;
    }
    for (int start = 0, index = 0; start < ids.length; start += 30, index++) {
      final List<String> chunk = ids.sublist(start, start + 30 > ids.length ? ids.length : start + 30);
      final int chunkIndex = index;
      _subs.add(
        FireStoreUtils.fireStore.collection(collection).where('id', whereIn: chunk).snapshots().listen(
          (snap) {
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
            _chunks[chunkIndex] = found;
            _chunkFromServer[chunkIndex] = !snap.metadata.isFromCache;
            _emit();
          },
          onError: (Object e) {
            log("OrdersByIdWatch($collection) failed: $e");
            // A failed stream is closed for good; the next watch() reopens it.
            _key = null;
            _chunks[chunkIndex] = const {};
            _chunkFromServer[chunkIndex] = false;
            _emit();
          },
        ),
      );
    }
  }

  void _emit() {
    if (_chunks.length < _subs.length) return;
    _loaded = true;
    final Map<String, T> all = {};
    for (final Map<String, T> chunk in _chunks.values) {
      all.addAll(chunk);
    }
    onChange(all, _chunkFromServer.values.every((v) => v));
  }

  void cancel() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _chunks.clear();
    _chunkFromServer.clear();
    _key = null;
    _loaded = false;
  }
}

/// [OrdersByIdWatch] over `vendor_orders`.
class VendorOrdersWatch extends OrdersByIdWatch<OrderModel> {
  VendorOrdersWatch(void Function(Map<String, OrderModel> orders, bool fromServer) onChange)
      : super(collection: CollectionName.vendorOrders, parse: OrderModel.fromJson, idOf: (order) => order.id, onChange: onChange);
}

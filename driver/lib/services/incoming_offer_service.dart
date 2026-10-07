import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/app/incoming_offer/incoming_offer_dialog.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/assigned_delivery_orders.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/services/dispatch_navigation.dart';
import 'package:driver/services/dispatch_offer_rules.dart';
import 'package:driver/services/dispatch_offer_service.dart';
import 'package:driver/services/driver_assignment_watcher.dart';
import 'package:driver/services/offer_seen_store.dart';
import 'package:driver/utils/document_verification.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/cancel_reason_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// One order waiting for this driver's answer, as [IncomingOfferService]
/// knows it.
class IncomingOffer {
  final DispatchKind kind;
  final String orderId;

  /// The live order document.
  final Map<String, dynamic> order;

  /// A dispatch offer (D3): answered in the incoming-offer dialog against a
  /// countdown, rejected automatically when it runs out. False: a store or
  /// admin hand assignment, left to the module's card with no timer.
  final bool timed;

  /// Countdown start (timed offers).
  final DateTime start;

  /// The order data came from the server, not only from the local cache.
  final bool fromServer;

  const IncomingOffer({required this.kind, required this.orderId, required this.order, required this.timed, required this.start, required this.fromServer});

  OfferSummary get summary => OfferSummary.fromOrder(kind, orderId, order);

  DateTime get deadline => OfferTiming.deadline(start, IncomingOfferService.windowSeconds);

  Duration remaining(DateTime now) => OfferTiming.remaining(start, IncomingOfferService.windowSeconds, now);
}

/// The driver app's single incoming-order dialog (decision D3 of the dispatch
/// spec, DRIVER_DISPATCH_DOCUMENTATION.md §5B), app-wide, over any screen.
///
/// **Where offers come from.** Two sources feed it, so a missed push still
/// shows the offer:
///   * a dispatch push — foreground `onMessage`, a background tap, a
///     terminated launch ([onDispatchPush], from NotificationService); and
///   * live listeners on the orders dispatched to this driver: one query per
///     served module (`Driver Pending` + `driverID` on `vendor_orders`,
///     `driverId` on `rides` / `parcel_orders` / `rental_orders`), plus a
///     document listener for every id in `users/{me}.orderRequestData` the
///     queries do not return (an order that names the driver only in the
///     other spelling, or one that stopped being pending).
///
/// Started from every dashboard's `users/{me}` listener ([onDriverSnapshot],
/// cheap when nothing changed) and stopped on sign-out ([stop]); a company
/// account holds no jobs and never starts it.
///
/// **What is shown.** Every order pending for this driver is in [offers] (the
/// parcel and rental homes list them as cards). Only a dispatch offer
/// ([DispatchOrderRules.isTimedOffer]: its id is in `orderRequestData` or a
/// dispatch push named it, and it is neither in `inProgressOrderID` — a
/// store's own delivery — nor a hand assignment the app put on the record) is
/// answered in the dialog, with a countdown of
/// `settings/DriverNearBy.driverOrderAcceptRejectDuration` seconds (default
/// 120). One dialog at a time, never two for one order; others queue.
///
/// **The countdown** starts at the earliest known of the push's sentTime, a
/// dispatch time on the order and the moment this device first saw the
/// offer (persisted per order, [OfferSeenStore], also by the background
/// push isolate). A push received live counts from its sentTime only while
/// that is within [OfferTiming.deliveryTolerance] of its receipt (a device
/// clock ahead of the server must not eat the window). Those times belong to
/// one dispatch round: they are forgotten when the offer stops waiting for
/// this driver without an answer (withdrawn, reassigned), and a later push
/// replaces them ([OfferSeenLog.record]), so a re-dispatch of the same order
/// never inherits an expired window. When it runs out the reject flow runs
/// once, without a reason and only while the order is still `Driver Pending`
/// for this driver ([DispatchOfferService.timeout]); an offer whose window
/// was already over when the app opened is rejected the same way, unseen.
///
/// **Cache vs server.** The listeners include metadata changes: a first
/// snapshot served from the local cache is confirmed by the server's own
/// event even when the data did not change. Only server-confirmed offers are
/// shown in the dialog or timed out.
///
/// **Housekeeping (server data only).** `orderRequestData` keeps only orders
/// still dispatched to this driver, and `inProgressOrderID` only orders this
/// driver is working (spec §4): finished, cancelled, reassigned or deleted
/// orders are removed with `arrayRemove`, so the Cloud Function's
/// `singleOrderReceive` never counts the driver as busy for good.
class IncomingOfferService {
  IncomingOfferService._();

  static int get windowSeconds => Constant.driverOrderAcceptRejectDuration;

  /// Every order waiting for this driver's answer, by id.
  static final RxMap<String, IncomingOffer> offers = <String, IncomingOffer>{}.obs;

  /// Offers answered (or expired) on this device: never shown again while
  /// they still show as pending (a later dispatch of the same order, once it
  /// has left, is a new offer).
  static final RxSet<String> handled = <String>{}.obs;

  /// Offers whose answer is being written.
  static final RxSet<String> answering = <String>{}.obs;

  static String? _uid;
  static UserModel? _driver;
  static String _key = '';
  static List<DispatchKind> _kinds = const [];
  static final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs = [];
  static final Map<DispatchKind, Map<String, Map<String, dynamic>>> _queried = {};
  static final Map<DispatchKind, bool> _queriedFromServer = {};
  static final Map<String, _Watched> _watched = {};
  static final Map<String, DispatchKind> _kindOf = {};

  /// When this device first saw each offer of the current dispatch round,
  /// and whether a dispatch push announced it (merged with [OfferSeenStore]).
  static Map<String, OfferSeen> _seen = {};
  static bool _seenLoaded = false;

  /// The log has been checked against the server once this session.
  static bool _seenPruned = false;
  static final Map<String, Timer> _timers = {};
  static final Map<String, DateTime> _timerDeadlines = {};
  static final Map<String, DateTime> _answeredAt = {};
  static final Set<String> _expiring = {};
  static final Map<String, Timer> _requestChecks = {};
  static final Set<String> _requestWrites = {};
  static String _requestsKey = '';
  static String _lastReconciledRequests = '';
  static String _inProgressKey = '';
  static final Map<String, DateTime> _firstConsidered = {};
  static DateTime? _lastPrune;
  static bool _pruning = false;
  static String? _dialogId;
  static bool _appReady = false;
  static int _generation = 0;

  /// The id the dialog shows, if any.
  static String? get dialogOrderId => _dialogId;

  // ── Life cycle ────────────────────────────────────────────────────────────

  /// From every dashboard's `users/{me}` listener. Listeners are (re)opened
  /// only for a new driver or a change of service types. [fromDashboard]
  /// false: started early by a push, before the splash has routed.
  static void onDriverSnapshot(UserModel? driver, {bool fromDashboard = true}) {
    final String uid = (driver?.id ?? '').trim();
    if (driver == null || uid.isEmpty) return;
    if (FirebaseAuth.instance.currentUser?.uid != uid) return;
    if (driver.isOwner == true) {
      stop();
      return;
    }
    // A dashboard exists: the splash has routed.
    if (fromDashboard) _appReady = true;
    final List<DispatchKind> kinds = DispatchKind.servedBy(driver.serviceTypes);
    final String key = '$uid|${kinds.map((k) => k.name).join(',')}';
    if (key != _key) _start(uid, driver, kinds, key);
    _driver = driver;
    _onDriverRecord(driver);
  }

  /// The splash has opened the first screen: a dialog can be shown.
  static void onAppReady() {
    _appReady = true;
    _maybeShowDialog();
  }

  /// Back from the background: the background isolate may have recorded
  /// pushes meanwhile.
  static Future<void> onAppResumed() async {
    if (_uid == null) return;
    final int generation = _generation;
    final Map<String, OfferSeen> stored = await OfferSeenStore.read();
    if (generation != _generation) return;
    _mergeSeen(stored);
    _reconcile();
  }

  /// Sign-out, account deletion, or a company account.
  static void stop() {
    _generation++;
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    for (final w in _watched.values) {
      w.sub?.cancel();
    }
    _watched.clear();
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _timerDeadlines.clear();
    for (final t in _requestChecks.values) {
      t.cancel();
    }
    _requestChecks.clear();
    _requestWrites.clear();
    _queried.clear();
    _queriedFromServer.clear();
    _kindOf.clear();
    _answeredAt.clear();
    _expiring.clear();
    _seen = {};
    _seenLoaded = false;
    _seenPruned = false;
    _uid = null;
    _driver = null;
    _key = '';
    _kinds = const [];
    _requestsKey = '';
    _lastReconciledRequests = '';
    _inProgressKey = '';
    _firstConsidered.clear();
    _lastPrune = null;
    offers.clear();
    handled.clear();
    answering.clear();
  }

  static void _start(String uid, UserModel driver, List<DispatchKind> kinds, String key) {
    stop();
    final int generation = _generation;
    _uid = uid;
    _driver = driver;
    _key = key;
    _kinds = kinds;
    OfferSeenStore.read().then((stored) {
      if (generation != _generation) return;
      _mergeSeen(stored);
      _seenLoaded = true;
      _pruneSeenOnce();
      _reconcile();
    });
    for (final DispatchKind kind in kinds) {
      _subs.add(FireStoreUtils.fireStore
          .collection(kind.collection)
          .where(kind.driverField, isEqualTo: uid)
          .where('status', isEqualTo: Constant.driverPending)
          // A first snapshot from the cache is followed by the server's
          // confirmation even when nothing changed (without metadata changes
          // that event never came, and a cached offer was never timed).
          .snapshots(includeMetadataChanges: true)
          .listen(
            (snap) => _onQuery(kind, uid, generation, snap),
            onError: (Object e) => log("IncomingOfferService ${kind.collection} failed: $e"),
          ));
    }
  }

  /// Once per session, when the log is loaded and every query has answered
  /// from the server: times kept for orders that are no longer waiting for
  /// this driver (an offer that ended while the app was closed) are
  /// forgotten, so a later offer of the same order starts its own window.
  static void _pruneSeenOnce() {
    if (_seenPruned || !_seenLoaded || _uid == null) return;
    if (_kinds.any((k) => _queriedFromServer[k] != true)) return;
    _seenPruned = true;
    final Set<String> waiting = {for (final Map<String, Map<String, dynamic>> found in _queried.values) ...found.keys, ..._watched.keys};
    final List<String> ended = _seen.keys.where((id) => !waiting.contains(id)).toList();
    if (ended.isEmpty) return;
    for (final String id in ended) {
      _seen.remove(id);
    }
    unawaited(OfferSeenStore.forget(ended));
  }

  static void _mergeSeen(Map<String, OfferSeen> stored) {
    Map<String, OfferSeen> merged = Map<String, OfferSeen>.of(_seen);
    stored.forEach((id, seen) => merged = OfferSeenLog.record(merged, id, seen.at, push: seen.push));
    _seen = merged;
  }

  static List<String> _ids(List<dynamic>? raw) => [for (final dynamic id in raw ?? const []) if (id != null && id.toString().trim().isNotEmpty) id.toString().trim()];

  static void _onDriverRecord(UserModel driver) {
    final List<String> requests = _ids(driver.orderRequestData);
    final List<String> inProgress = _ids(driver.inProgressOrderID);
    final String requestsKey = (List<String>.of(requests)..sort()).join(',');
    final String inProgressKey = (List<String>.of(inProgress)..sort()).join(',');
    if (requestsKey != _requestsKey) {
      _requestsKey = requestsKey;
      _syncWatches();
    }
    final bool arraysChanged = requestsKey != _lastReconciledRequests || inProgressKey != _inProgressKey;
    final DateTime now = DateTime.now();
    if (inProgressKey != _inProgressKey || _lastPrune == null || now.difference(_lastPrune!) > const Duration(minutes: 10)) {
      _inProgressKey = inProgressKey;
      unawaited(_pruneInProgress());
    }
    // The record is rewritten on every location update: the offers depend on
    // its two arrays only.
    if (arraysChanged) {
      _lastReconciledRequests = requestsKey;
      _reconcile();
    }
  }

  // ── Sources ───────────────────────────────────────────────────────────────

  static void _onQuery(DispatchKind kind, String uid, int generation, QuerySnapshot<Map<String, dynamic>> snap) {
    if (generation != _generation || uid != _uid) return;
    final Map<String, Map<String, dynamic>> found = {};
    for (final doc in snap.docs) {
      final Map<String, dynamic> data = doc.data();
      final String id = (data['id'] ?? doc.id).toString();
      _kindOf[id] = kind;
      if (DispatchOrderRules.isPendingFor(data, uid)) found[id] = data;
    }
    _queried[kind] = found;
    _queriedFromServer[kind] = !snap.metadata.isFromCache;
    // An offer that left the query while still on the driver's record
    // (cancelled, re-dispatched) is followed by its own listener until the
    // record is cleaned.
    if (!snap.metadata.isFromCache) {
      _syncWatches();
      _pruneSeenOnce();
    }
    _reconcile();
  }

  static bool _inQueries(String id) => _queried.values.any((m) => m.containsKey(id));

  /// Keeps one document listener per id that is on the driver's record (or
  /// was named by a push) but not returned by the queries.
  static void _syncWatches() {
    final UserModel? driver = _driver;
    if (driver == null || _uid == null) return;
    final Set<String> requests = _ids(driver.orderRequestData).toSet();
    for (final String id in requests) {
      if (!_inQueries(id) && !_watched.containsKey(id)) unawaited(_watch(id));
    }
    for (final String id in _watched.keys.toList()) {
      final _Watched w = _watched[id]!;
      if (requests.contains(id)) continue;
      if (w.byPush && w.data != null && DispatchOrderRules.isPendingFor(w.data, _uid!)) continue;
      if (w.locating) continue;
      w.sub?.cancel();
      _watched.remove(id);
    }
  }

  /// Follows one order by id. Without [kind] it is first located (server
  /// reads) in the collections of the modules the driver serves.
  static Future<void> _watch(String id, {DispatchKind? kind, bool byPush = false, Map<String, dynamic>? initial, bool initialFromServer = false}) async {
    final String? uid = _uid;
    if (uid == null || id.isEmpty) return;
    final _Watched? existing = _watched[id];
    if (existing != null) {
      if (byPush) existing.byPush = true;
      return;
    }
    final int generation = _generation;
    final _Watched w = _Watched(byPush: byPush);
    // An order just read (a push) is known before its listener answers.
    if (initial != null && kind != null) {
      w.kind = kind;
      w.data = initial;
      w.exists = true;
      w.fromServer = initialFromServer;
    }
    _watched[id] = w;
    DispatchKind? found = kind ?? _kindOf[id];
    if (found == null) {
      bool failed = false;
      for (final DispatchKind k in [..._kinds, ...DispatchKind.values.where((k) => !_kinds.contains(k))]) {
        try {
          final DocumentSnapshot<Map<String, dynamic>> snap = await FireStoreUtils.fireStore.collection(k.collection).doc(id).get(const GetOptions(source: Source.server));
          if (snap.exists) {
            found = k;
            break;
          }
        } catch (e) {
          failed = true;
        }
      }
      if (generation != _generation) return;
      if (found == null) {
        _watched.remove(id);
        // Nowhere, by the server: the record keeps a dead id.
        if (!failed) _scheduleRequestCheck(id);
        return;
      }
      _kindOf[id] = found;
    }
    w.kind = found;
    w.locating = false;
    w.sub = FireStoreUtils.fireStore.collection(found.collection).doc(id).snapshots(includeMetadataChanges: true).listen(
      (snap) {
        if (generation != _generation) return;
        w.data = snap.exists ? snap.data() : null;
        w.exists = snap.exists;
        w.fromServer = !snap.metadata.isFromCache;
        if (w.fromServer) _scheduleRequestCheck(id);
        _syncWatches();
        _reconcile();
      },
      onError: (Object e) => log("IncomingOfferService: $id failed: $e"),
    );
  }

  // ── orderRequestData / inProgressOrderID housekeeping ─────────────────────

  /// A request whose order looks finished, taken or gone is dropped only if
  /// it still looks so a little later: the Cloud Function writes the order
  /// and the driver's record one after the other, and a listener may see the
  /// record first.
  static void _scheduleRequestCheck(String id) {
    final UserModel? driver = _driver;
    if (driver == null || !_ids(driver.orderRequestData).contains(id)) return;
    if (_requestChecks.containsKey(id)) return;
    _requestChecks[id] = Timer(const Duration(seconds: 20), () {
      _requestChecks.remove(id);
      unawaited(_checkRequest(id));
    });
  }

  static Future<void> _checkRequest(String id) async {
    final String? uid = _uid;
    final UserModel? driver = _driver;
    if (uid == null || driver == null || !_ids(driver.orderRequestData).contains(id)) return;
    if (_requestWrites.contains(id) || answering.contains(id)) return;
    Map<String, dynamic>? data;
    final DispatchKind? kind = _kindOf[id];
    try {
      if (kind != null) {
        final DocumentSnapshot<Map<String, dynamic>> snap = await FireStoreUtils.fireStore.collection(kind.collection).doc(id).get(const GetOptions(source: Source.server));
        data = snap.exists ? snap.data() : null;
      } else {
        // Located nowhere: confirm across every collection once more.
        for (final DispatchKind k in DispatchKind.values) {
          final DocumentSnapshot<Map<String, dynamic>> snap = await FireStoreUtils.fireStore.collection(k.collection).doc(id).get(const GetOptions(source: Source.server));
          if (snap.exists) {
            data = snap.data();
            _kindOf[id] = k;
            break;
          }
        }
      }
    } catch (e) {
      // Offline: decide nothing.
      return;
    }
    if (uid != _uid) return;
    final RequestVerdict verdict = DispatchOrderRules.requestVerdict(data, uid);
    if (verdict == RequestVerdict.keep) return;
    _requestWrites.add(id);
    log("IncomingOfferService: $id is ${verdict.name} - leaving $uid.orderRequestData");
    await FireStoreUtils.updateUserFields(uid, {
      'orderRequestData': FieldValue.arrayRemove([id]),
      if (verdict == RequestVerdict.accepted) 'inProgressOrderID': FieldValue.arrayUnion([id]),
    });
    _requestWrites.remove(id);
  }

  /// Drops `inProgressOrderID` entries that can never be this driver's active
  /// job again (spec §4), read from the server only.
  static Future<void> _pruneInProgress() async {
    final String? uid = _uid;
    final UserModel? driver = _driver;
    if (uid == null || driver == null || _pruning) return;
    final List<String> ids = _ids(driver.inProgressOrderID).toSet().toList();
    _lastPrune = DateTime.now();
    if (ids.isEmpty) return;
    _pruning = true;
    final int generation = _generation;
    final List<String> stale = [];
    try {
      for (final String id in ids) {
        final ({DispatchKind? kind, Map<String, dynamic>? data, bool ok}) found = await _locate(id);
        if (!found.ok) continue;
        if (found.kind == null) {
          stale.add(id);
          continue;
        }
        final bool isStale;
        if (found.kind == DispatchKind.delivery) {
          OrderModel? order;
          try {
            order = OrderModel.fromJson(found.data!);
          } catch (_) {
            order = null;
          }
          isStale = order != null && AssignedDeliveryOrders.isStaleInProgress(order, uid);
        } else {
          isStale = DispatchOrderRules.isStaleInProgress(found.kind!, found.data, uid);
        }
        if (isStale) stale.add(id);
      }
    } finally {
      _pruning = false;
    }
    if (stale.isEmpty || generation != _generation || uid != _uid) return;
    log("IncomingOfferService: removing finished / reassigned $stale from $uid.inProgressOrderID");
    await FireStoreUtils.updateUserFields(uid, {'inProgressOrderID': FieldValue.arrayRemove(stale)});
  }

  /// The order [id] in whichever collection holds it, from the server.
  /// `ok` false when a read failed (nothing is decided then).
  static Future<({DispatchKind? kind, Map<String, dynamic>? data, bool ok})> _locate(String id) async {
    final DispatchKind? known = _kindOf[id];
    final List<DispatchKind> order = [?known, ..._kinds.where((k) => k != known), ...DispatchKind.values.where((k) => k != known && !_kinds.contains(k))];
    bool ok = true;
    for (final DispatchKind k in order) {
      try {
        final DocumentSnapshot<Map<String, dynamic>> snap = await FireStoreUtils.fireStore.collection(k.collection).doc(id).get(const GetOptions(source: Source.server));
        if (snap.exists) {
          _kindOf[id] = k;
          return (kind: k, data: snap.data(), ok: true);
        }
      } catch (e) {
        ok = false;
      }
    }
    return (kind: null, data: null, ok: ok);
  }

  // ── Pushes ────────────────────────────────────────────────────────────────

  /// Whether a dispatch push named [orderId] in its current dispatch round
  /// (this run, or recorded by the background isolate).
  static bool wasPushed(String orderId) => _seen[orderId]?.push == true;

  /// A dispatch push named [orderId] after [at] (DriverAssignmentWatcher: a
  /// hand assignment marked at [at] has ended and the order was dispatched
  /// to this driver again).
  static bool pushedAfter(String orderId, DateTime at) => OfferSeenLog.pushedAfter(_seen[orderId], at);

  /// A dispatch push arrived in the foreground ([tapped] false), or a push
  /// about an order of a dispatched service was tapped. [isDispatch]: the
  /// push carried the dispatch markers (click_action / Driver Pending) and so
  /// counts as "announced by a dispatch push".
  ///
  /// The order is read from Firestore first: nothing is shown unless it is
  /// still `Driver Pending` for this driver. A tap on one that is not opens
  /// that module's job screen (the existing tap behaviour).
  static Future<void> onDispatchPush(DispatchPush push, {bool tapped = false, bool isDispatch = true}) async {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    final DateTime now = DateTime.now();
    final DateTime? pushedAt = isDispatch ? await _pushTime(push, tapped: tapped, now: now) : null;
    if (!await _ensureStarted(uid)) {
      if (tapped) DispatchNavigation.openJob(push.kind);
      return;
    }
    Map<String, dynamic>? data;
    bool fromServer = false;
    bool unread = false;
    try {
      DocumentSnapshot<Map<String, dynamic>> snap;
      try {
        snap = await FireStoreUtils.fireStore.collection(push.kind.collection).doc(push.orderId).get(const GetOptions(source: Source.server));
        fromServer = true;
      } catch (_) {
        snap = await FireStoreUtils.fireStore.collection(push.kind.collection).doc(push.orderId).get();
        fromServer = !snap.metadata.isFromCache;
      }
      data = snap.exists ? snap.data() : null;
    } catch (e) {
      unread = true;
      log("IncomingOfferService: ${push.orderId} could not be read: $e");
    }
    if (uid != _uid) return;
    // The push starts the offer's countdown — only while the order is (or,
    // unread, may be) waiting for this driver: an old notification tapped
    // after its offer ended must not leave a push time behind for a later
    // offer of the same order.
    if (pushedAt != null && (unread || DispatchOrderRules.isPendingFor(data, uid))) {
      _mergeSeen(await OfferSeenStore.record(push.orderId, pushedAt, push: true));
      if (uid != _uid) return;
    }
    _kindOf[push.orderId] = push.kind;
    if (DispatchOrderRules.isPendingFor(data, uid)) {
      await _watch(push.orderId, kind: push.kind, byPush: isDispatch, initial: data, initialFromServer: fromServer);
      _reconcile();
      // A pending order that is not a dispatch offer (a hand assignment) is
      // answered on its module's card.
      final IncomingOffer? offer = offers[push.orderId];
      if (tapped && (offer == null || !offer.timed)) DispatchNavigation.openJob(push.kind);
      return;
    }
    if (!tapped) return;
    if (data == null || !DispatchOrderRules.namesDriver(data, uid)) {
      ShowToastDialog.showToast("This order is no longer available.".tr);
    }
    DispatchNavigation.openJob(push.kind);
  }

  /// The countdown start a dispatch push gives, or null when it adds nothing.
  ///
  /// Received live (foreground): [OfferTiming.pushStart] — its sentTime,
  /// unless that lies further before now than a delivery takes (skew).
  /// Tapped: the push was already recorded when it arrived (the foreground
  /// listener or the background handler, both skew-safe) and that record
  /// wins; only a push nothing recorded (an iOS app the user had closed)
  /// falls back to its sentTime, so an offer whose window ran out meanwhile
  /// is still rejected on opening (D3).
  static Future<DateTime?> _pushTime(DispatchPush push, {required bool tapped, required DateTime now}) async {
    if (!tapped) return OfferTiming.pushStart(sentTime: push.sentTime, receivedAt: now);
    final DateTime? sent = push.sentTime;
    final bool usable = sent != null && sent.isBefore(now);
    final DateTime at = usable ? sent : now;
    // A push record this tap's push is not newer than (by more than a
    // delivery) is the record of this same push; without a usable sentTime
    // any push record is.
    bool recorded(OfferSeen? seen) => seen != null && seen.push && (!usable || !at.isAfter(seen.at.add(OfferTiming.deliveryTolerance)));
    if (recorded(_seen[push.orderId])) return null;
    if (recorded((await OfferSeenStore.read())[push.orderId])) return null;
    return at;
  }

  /// Starts the listeners for the signed-in driver when no dashboard has yet
  /// (the app was opened by a tap). False for a company account.
  static Future<bool> _ensureStarted(String uid) async {
    if (_uid == uid) return true;
    UserModel? me = Constant.userModel?.id == uid ? Constant.userModel : null;
    me ??= await FireStoreUtils.getUserProfile(uid);
    if (me == null || me.id != uid || me.isOwner == true) return false;
    onDriverSnapshot(me, fromDashboard: false);
    return _uid == uid;
  }

  // ── Reconcile ─────────────────────────────────────────────────────────────

  static void _reconcile() {
    final String? uid = _uid;
    final UserModel? driver = _driver;
    if (uid == null || driver == null) return;
    final DateTime now = DateTime.now();
    final List<String> requests = _ids(driver.orderRequestData);
    final List<String> inProgress = _ids(driver.inProgressOrderID);
    _answeredAt.removeWhere((_, at) => now.difference(at) > const Duration(seconds: 15));

    final Map<String, IncomingOffer> next = {};
    void consider(DispatchKind kind, String id, Map<String, dynamic>? data, bool fromServer) {
      if (data == null || _answeredAt.containsKey(id)) return;
      // One copy per order; a server-confirmed copy (a document listener, a
      // push's server read) wins over a copy known only from the cache.
      final IncomingOffer? have = next[id];
      if (have != null && (have.fromServer || !fromServer)) return;
      if (!DispatchOrderRules.isPendingFor(data, uid)) {
        if (have != null) next.remove(id);
        return;
      }
      // A rental waiting for the customer's answer to this driver's counter:
      // no countdown now, and a fresh one once the customer has answered.
      if (DispatchOrderRules.awaitsCustomer(data, uid)) _forgetRound(id);
      final bool timed = DispatchOrderRules.isTimedOffer(
        data,
        uid: uid,
        orderId: id,
        requests: requests,
        inProgress: inProgress,
        pushSeen: wasPushed(id),
        handAssigned: DriverAssignmentWatcher.isHandAssigned(id),
      );
      // A hand assignment has no countdown; its start only orders the cards.
      DateTime start = _firstConsidered[id] ??= now;
      if (timed) {
        if (_seenLoaded && _seen[id] == null) {
          _seen = OfferSeenLog.record(_seen, id, now);
          unawaited(OfferSeenStore.record(id, now));
        }
        start = OfferTiming.start(dispatchedAt: OfferTiming.dispatchedAt(data), firstSeen: _seen[id]?.at, now: now);
      }
      next[id] = IncomingOffer(kind: kind, orderId: id, order: data, timed: timed, start: start, fromServer: fromServer);
    }

    _queried.forEach((kind, found) => found.forEach((id, data) => consider(kind, id, data, _queriedFromServer[kind] ?? false)));
    _watched.forEach((id, w) {
      if (w.kind != null) consider(w.kind!, id, w.data, w.fromServer);
    });

    for (final String id in offers.keys.toList()) {
      if (!next.containsKey(id)) {
        _cancelTimer(id);
        _firstConsidered.remove(id);
        // Gone without an answer from this device (withdrawn, reassigned,
        // cancelled): its dispatch round is over. Should the same order be
        // offered to this driver again, that is a new offer with a window of
        // its own — the Cloud Function writes no dispatch time to tell the
        // two apart. (An answer already forgot it: markAnswered.)
        if (!_answeredAt.containsKey(id)) _forgetRound(id);
      }
    }
    // An answered offer stays "handled" only while it still shows as
    // pending (the listeners lag the answer); once it has left, a later
    // offer of the same order is a new one.
    final List<String> over = handled.where((id) => !next.containsKey(id) && !_answeredAt.containsKey(id) && !answering.contains(id) && !_expiring.contains(id)).toList();
    if (over.isNotEmpty) handled.removeAll(over);
    final bool unchanged = next.length == offers.length &&
        next.entries.every((e) {
          final IncomingOffer? old = offers[e.key];
          return old != null &&
              identical(old.order, e.value.order) &&
              old.timed == e.value.timed &&
              old.start == e.value.start &&
              old.fromServer == e.value.fromServer;
        });
    if (!unchanged) offers.assignAll(next);

    if (!_seenLoaded) return;
    for (final IncomingOffer offer in next.values) {
      if (!offer.timed || !offer.fromServer || handled.contains(offer.orderId)) continue;
      final DateTime deadline = offer.deadline;
      if (!deadline.isAfter(now)) {
        unawaited(_expire(offer.orderId));
      } else if (_timerDeadlines[offer.orderId] != deadline) {
        _cancelTimer(offer.orderId);
        _timerDeadlines[offer.orderId] = deadline;
        _timers[offer.orderId] = Timer(deadline.difference(now) + const Duration(milliseconds: 200), () {
          _timers.remove(offer.orderId);
          _timerDeadlines.remove(offer.orderId);
          unawaited(_expire(offer.orderId));
        });
      }
    }
    _maybeShowDialog();
  }

  static void _cancelTimer(String id) {
    _timers.remove(id)?.cancel();
    _timerDeadlines.remove(id);
  }

  /// Forgets the countdown times of [id]'s current dispatch round, here and
  /// in [OfferSeenStore].
  static void _forgetRound(String id) {
    if (_seen.remove(id) != null) unawaited(OfferSeenStore.forget([id]));
  }

  /// The window of a dispatch offer is over (D3): rejected once, without a
  /// reason, only while it is still `Driver Pending` for this driver. A write
  /// that fails (offline) is tried again while the offer stays pending.
  static Future<void> _expire(String id) async {
    final String? uid = _uid;
    final IncomingOffer? offer = offers[id];
    if (uid == null || offer == null || !offer.timed) return;
    if (_expiring.contains(id) || answering.contains(id)) return;
    _expiring.add(id);
    handled.add(id);
    log("IncomingOfferService: the offer ${offer.kind.collection}/$id timed out");
    final DispatchResult result = await DispatchOfferService.timeout(offer.kind, id, uid);
    _expiring.remove(id);
    if (result.answer == OfferAnswer.failed && uid == _uid) {
      _cancelTimer(id);
      _timers[id] = Timer(const Duration(seconds: 15), () {
        _timers.remove(id);
        if (offers.containsKey(id)) unawaited(_expire(id));
      });
    }
  }

  /// True when [orderId] is a dispatch offer whose window is over: it is
  /// never accepted late.
  static bool isExpired(String orderId) {
    final IncomingOffer? offer = offers[orderId];
    return offer != null && offer.timed && !offer.deadline.isAfter(DateTime.now());
  }

  /// An answer to [orderId] was written (by the dialog, a card or a timeout).
  static void markAnswered(String orderId) {
    handled.add(orderId);
    _answeredAt[orderId] = DateTime.now();
    _cancelTimer(orderId);
    _seen.remove(orderId);
    unawaited(OfferSeenStore.forget([orderId]));
    if (offers.containsKey(orderId)) offers.remove(orderId);
  }

  // ── Dialog ────────────────────────────────────────────────────────────────

  static void _maybeShowDialog() {
    if (!_appReady || _dialogId != null || _uid == null) return;
    final DateTime now = DateTime.now();
    final List<IncomingOffer> waiting = offers.values
        .where((o) => o.timed && o.fromServer && !handled.contains(o.orderId) && !answering.contains(o.orderId) && o.deadline.isAfter(now))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    if (waiting.isEmpty) return;
    final String id = waiting.first.orderId;
    try {
      _dialogId = id;
      Get.dialog(IncomingOfferDialog(orderId: id), barrierDismissible: false, name: '$dialogRoutePrefix$id');
    } catch (e) {
      // No navigator yet: shown on the next change.
      _dialogId = null;
      log("IncomingOfferService: the dialog could not open: $e");
    }
  }

  /// The dialog for [orderId] is gone (answered, expired, withdrawn).
  static void dialogClosed(String orderId) {
    if (_dialogId != orderId) return;
    _dialogId = null;
    Future<void>.delayed(const Duration(milliseconds: 300), _maybeShowDialog);
  }

  /// Route names of the incoming-order dialog: `incoming-offer-<orderId>`.
  static const String dialogRoutePrefix = 'incoming-offer-';

  /// [route] is the incoming-order dialog (a screen's own pop must never
  /// close it: DispatchNavigation.ownRoute / closeRoute).
  static bool isDialogRoute(Route<dynamic>? route) => (route?.settings.name ?? '').startsWith(dialogRoutePrefix);

  /// The offer is still waiting for an answer on this device.
  static bool isOpen(String orderId) => offers.containsKey(orderId) && !handled.contains(orderId);

  /// The offer is still one the dialog answers: waiting, with a countdown (a
  /// rental whose counter-offer now waits for the customer is not).
  static bool isDialogOffer(String orderId) => isOpen(orderId) && (offers[orderId]?.timed ?? false);

  /// The offers of [kind], oldest first (the module cards).
  static List<IncomingOffer> offersOf(DispatchKind kind) => offers.values.where((o) => o.kind == kind).toList()..sort((a, b) => a.start.compareTo(b.start));

  // ── Answers (dialog and module cards) ─────────────────────────────────────

  /// [handAssigned]: an untimed offer — an order handed to this driver by
  /// name — is not held back by pending documents (as on the cab home).
  static Future<OfferGate> _gate(UserModel me, {bool handAssigned = false}) async {
    num? ownerWallet;
    final String ownerId = (me.ownerId ?? '').trim();
    if (ownerId.isNotEmpty) {
      final UserModel? owner = await FireStoreUtils.getUserProfile(ownerId);
      ownerWallet = owner?.walletAmount;
    }
    return DispatchGateRules.check(
      freelance: (me.vendorID ?? '').isEmpty,
      documentsPending: DocumentVerification.isPending(me),
      ownerId: me.ownerId,
      ownWallet: me.walletAmount,
      ownerWallet: ownerWallet,
      minimumDeposit: double.tryParse(Constant.minimumDepositToRideAccept) ?? 0,
      ownerMinimumDeposit: double.tryParse(Constant.ownerMinimumDepositToRideAccept) ?? 0,
      handAssigned: handAssigned,
    );
  }

  static String _gateMessage(OfferGate gate) {
    switch (gate) {
      case OfferGate.documentsPending:
        return "Document verification is pending. Please proceed to set up your document verification.".tr;
      case OfferGate.ownWallet:
        String minimum = Constant.minimumDepositToRideAccept;
        try {
          minimum = Constant.amountShow(amount: Constant.minimumDepositToRideAccept);
        } catch (_) {
          // No currency loaded yet: the bare number.
        }
        return "${'You must have at least'.tr} $minimum ${'in your wallet to receive orders'.tr}";
      case OfferGate.ownerWallet:
        return "Your owner doesn't have the minimum wallet amount to receive orders. Please contact your owner.".tr;
      case OfferGate.open:
        return '';
    }
  }

  /// Accept of the offer [orderId] (dialog or card): the cards' wallet /
  /// verification gates, then [DispatchOfferService.accept]; on success the
  /// module's job screen opens. True when the order is this driver's now.
  static Future<bool> accept(String orderId) async {
    final IncomingOffer? offer = offers[orderId];
    final UserModel? me = _driver ?? Constant.userModel;
    if (offer == null || handled.contains(orderId) || me == null) {
      ShowToastDialog.showToast("This order is no longer available.".tr);
      return false;
    }
    if (answering.contains(orderId)) return false;
    // Decided at the tap: the company wallet read below must not turn an
    // accept tapped in time into a timeout.
    final bool inWindow = !isExpired(orderId);
    answering.add(orderId);
    try {
      final OfferGate gate = await _gate(me, handAssigned: !offer.timed);
      if (gate != OfferGate.open) {
        ShowToastDialog.showToast(_gateMessage(gate));
        return false;
      }
      ShowToastDialog.showLoader("Please wait".tr);
      final DispatchResult result = await DispatchOfferService.accept(offer.kind, orderId, _driver ?? me, tappedInWindow: inWindow);
      ShowToastDialog.closeLoader();
      switch (result.answer) {
        case OfferAnswer.done:
        case OfferAnswer.held:
          await AudioPlayerService.playSound(false);
          DispatchNavigation.openJob(offer.kind);
          return true;
        case OfferAnswer.gone:
          ShowToastDialog.showToast("This order is no longer available.".tr);
          return false;
        case OfferAnswer.blocked:
          ShowToastDialog.showToast((result.message ?? "Something went wrong. Please try again.").tr);
          return false;
        case OfferAnswer.failed:
          ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
          return false;
      }
    } finally {
      answering.remove(orderId);
      _expireIfOver(orderId);
    }
  }

  /// The window ran out while an answer was being written and the answer did
  /// not go through: the timeout still runs, once.
  static void _expireIfOver(String orderId) {
    if (isOpen(orderId) && isExpired(orderId)) unawaited(_expire(orderId));
  }

  static String _rejectTitle(DispatchKind kind) {
    switch (kind) {
      case DispatchKind.cab:
        return "Why are you rejecting this ride?".tr;
      case DispatchKind.rental:
        return "Why are you rejecting this booking?".tr;
      case DispatchKind.delivery:
      case DispatchKind.parcel:
        return "Why are you rejecting this order?".tr;
    }
  }

  /// Manual reject of the offer [orderId] (dialog or card): the mandatory
  /// reason first (backing out of the sheet changes nothing), then
  /// [DispatchOfferService.reject].
  static Future<bool> reject(String orderId) async {
    final IncomingOffer? first = offers[orderId];
    final String? uid = _uid;
    if (first == null || uid == null || handled.contains(orderId)) {
      ShowToastDialog.showToast("This order is no longer available.".tr);
      return false;
    }
    if (answering.contains(orderId)) return false;
    final CancelReasonResult? reason = await CancelReasonSheet.show(title: _rejectTitle(first.kind));
    if (reason == null) return false;
    // The offer as it is NOW, after the sheet (it may have timed out).
    if (!isOpen(orderId) || uid != _uid) {
      ShowToastDialog.showToast("This order is no longer available.".tr);
      return false;
    }
    answering.add(orderId);
    try {
      ShowToastDialog.showLoader("Please wait".tr);
      final UserModel? me = _driver;
      final bool held = me != null && [...?me.orderRequestData, ...?me.inProgressOrderID].any((id) => id.toString() == orderId);
      final DispatchResult result = await DispatchOfferService.reject(first.kind, orderId, uid,
          reasonFields: reason.toFields(uid), heldAsRequest: held, cabRequestId: me?.orderCabRequestData?.id);
      ShowToastDialog.closeLoader();
      switch (result.answer) {
        case OfferAnswer.done:
          await AudioPlayerService.playSound(false);
          return true;
        case OfferAnswer.gone:
          ShowToastDialog.showToast("This order is no longer available.".tr);
          return true;
        case OfferAnswer.held:
        case OfferAnswer.blocked:
        case OfferAnswer.failed:
          ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
          return false;
      }
    } finally {
      answering.remove(orderId);
      _expireIfOver(orderId);
    }
  }
}

class _Watched {
  _Watched({this.byPush = false});

  DispatchKind? kind;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;
  Map<String, dynamic>? data;
  bool exists = false;
  bool fromServer = false;
  bool locating = true;
  bool byPush;
}

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/notification_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/incoming_offer_service.dart';
import 'package:driver/services/push_message.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:driver/utils/preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

/// Jobs **assigned** to this driver, learned from the records alone — panel
/// report 01, §4 "Driver assignment no longer requires an `fcmToken`".
///
/// The admin panel may now assign a driver who has no `fcmToken`: the
/// assignment is written as before and only the push is skipped. No module of
/// this app ever took its state from a push (every home screen reads the
/// driver's own user document or the orders assigned to them), so what a
/// missing push actually loses is:
///
///   1. **the alert** — nothing tells the driver a job is waiting; and
///   2. for delivery and cab, a job whose order says `driverID == me` but
///      that never reached `users/{me}.inProgressOrderID` (a writer that sets
///      only the order) has no screen that shows it.
///
/// This watcher covers both, and is the counterpart of IncomingOfferService
/// (jobs *offered* by the dispatch Cloud Functions) for jobs *assigned*:
///
///   * one live query per module the driver serves, on the orders assigned to
///     them in an accepted state (`Driver Accepted`, `Order Shipped`,
///     `In Transit`) — the same shape the parcel and rental home screens
///     already query;
///   * **delivery / cab** — an assigned order missing from the driver's
///     `inProgressOrderID` is added to it (`arrayUnion`, so never twice), which
///     is exactly what accepting it would have written; the existing home
///     screens then show it with their existing actions. Only recent orders
///     are adopted ([_adoptWindow]) so an abandoned record is never revived;
///   * **parcel / rental** — the home screens list these records directly
///     (both live), nothing to adopt;
///   * every assignment is **announced once** — a toast and one local
///     notification — the first time it is seen, persisted per driver so
///     reopening the app does not announce it again. A job this device
///     accepted itself (the snapshot still carries its own pending write) is
///     recorded silently, and the first run on a device records what is
///     already there without announcing it.
///
/// **Hand assignments still waiting for the driver's answer** — an order that
/// names this driver but is still pending (delivery: `Driver Pending`, or the
/// admin panel's `Order Accepted` + `driverID`; cab: `Driver Pending` /
/// `Order Placed` / `Order Accepted` + `driverId`) — are watched by a second
/// query per module. When such an order never reached the driver's own record
/// (the writer set only the order, and the push that used to carry it may now
/// be skipped), it is added to `orderRequestData`, where the delivery and cab
/// home screens look for a request (never to `inProgressOrderID`, which the
/// dispatch spec reserves for accepted, active jobs), and remembered as a
/// hand assignment ([isHandAssigned]) so it gets no offer countdown. Accept
/// and reject then keep their existing rules and writes. See
/// [pendingIdToAdopt]. The mark lasts as long as the hand assignment: it is
/// dropped once the server shows the order pending for this driver in none
/// of the watched modules (checked on every server snapshot, the first one
/// after a start included, so an assignment that ended while the app was
/// closed is forgotten too), and a dispatch push for the order received
/// after the mark overrides it (the Cloud Function offered it again).
///
/// **Dispatch offers are not assignments.** The dispatch Cloud Functions name
/// the driver on every offer (`Driver Pending` + `driverId` / `driverID`, the
/// id in `users.orderRequestData`, a push). Such an offer is announced once —
/// by its push and the incoming-order dialog (IncomingOfferService) — and is
/// neither announced here as "a job has been assigned to you" nor adopted.
/// A `Driver Pending` order that names the driver but is on neither of their
/// arrays is decided after a short grace period ([_dispatchGrace]): the
/// function writes the order and the driver's record one after the other, so
/// only an order still missing from the record (and with no dispatch push)
/// is a hand assignment.
class DriverAssignmentWatcher {
  DriverAssignmentWatcher._();

  /// Assigned jobs currently held, all modules — a screen may badge it.
  static final RxInt assignedCount = 0.obs;

  static const List<String> _assignedStatuses = [
    Constant.driverAccepted,
    Constant.orderShipped,
    Constant.orderInTransit,
  ];

  static const List<_Module> _modules = [
    _Module('delivery-service', CollectionName.vendorOrders, 'driverID',
        adoptsIntoUser: true, pendingStatuses: [Constant.driverPending, Constant.orderAccepted], pendingAdoptField: 'orderRequestData'),
    _Module('cab-service', CollectionName.ridesBooking, 'driverId',
        adoptsIntoUser: true, pendingStatuses: [Constant.driverPending, Constant.orderPlaced, Constant.orderAccepted], pendingAdoptField: 'orderRequestData'),
    _Module('parcel_delivery', CollectionName.parcelOrders, 'driverId'),
    _Module('rental-service', CollectionName.rentalOrders, 'driverId'),
  ];

  /// Service type -> the `users` array a pending hand assignment of that
  /// module is adopted into (null: not adopted).
  static Map<String, String?> get pendingAdoptFields => {for (final _Module m in _modules) m.serviceType: m.pendingAdoptField};

  /// How old an order may be and still be adopted into `inProgressOrderID`.
  /// A hand assignment is acted on straight away; an older order still in an
  /// active state is an abandoned record, not a job.
  static const Duration _adoptWindow = Duration(hours: 48);

  /// The loud job channel (`NotificationService.jobChannelId`), created at start-up.
  static const String _channelId = PushChannels.driverJob;
  static const int _notificationId = 9115; // next to the job queue's 9114.
  static const int _seenCap = 300;

  static String? _uid;
  static String _servicesKey = '';
  static UserModel? _driver;
  static final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs = [];

  /// Module name -> the assigned records of the last snapshot.
  static final Map<String, Map<String, _Assigned>> _held = {};

  /// Module name -> the pending hand assignments of the last snapshot that
  /// [pendingIdToAdopt] accepted.
  static final Map<String, Map<String, _Assigned>> _pendingHeld = {};

  /// Modules whose first snapshot is still to come on a device that has never
  /// recorded anything for this driver: their records are seeded silently.
  static final Set<String> _seeding = {};

  /// Persisted "already surfaced" ids, `module:id`.
  static List<String> _seen = [];

  /// Ids with an `arrayUnion` in flight, so a burst of snapshots writes once.
  static final Set<String> _adopting = {};

  /// Pending orders this watcher decided are hand assignments, with when
  /// (epoch ms; persisted per driver): the only ones it adopts, and the ones
  /// the incoming-offer dialog leaves to the module cards.
  static Map<String, int> _handAssigned = {};

  /// The served modules that have a pending query (delivery, cab).
  static List<String> _pendingModules = [];

  /// Module name -> every pending order naming this driver in the last
  /// snapshot that [pendingIdToAdopt] kept (hand assignment or offer).
  static final Map<String, Set<String>> _pendingNow = {};

  /// Module name -> every order the pending query returned in the last server
  /// snapshot (all of them name this driver in a pending status).
  static final Map<String, Set<String>> _pendingNamed = {};

  /// `Driver Pending` orders waiting out [_dispatchGrace] before they are
  /// classified, by `module:id`.
  static final Map<String, Timer> _graceTimers = {};

  /// Time the dispatch Cloud Function has to put an offer on the driver's
  /// record after naming them on the order.
  static const Duration _dispatchGrace = Duration(seconds: 20);

  static String _prefKey(String uid) => 'assignedJobsSeen_$uid';
  static String _handPrefKey(String uid) => 'handAssignedPending_$uid';

  /// A pending order the app put on this driver's record as a hand
  /// assignment (not a dispatch offer) — unless a dispatch push named it
  /// after it was marked: that assignment ended and the Cloud Function
  /// offered the order again, a timed offer.
  static bool isHandAssigned(String orderId) {
    final int? at = _handAssigned[orderId];
    return at != null && !IncomingOfferService.pushedAfter(orderId, DateTime.fromMillisecondsSinceEpoch(at));
  }

  /// The persisted marks: `{id: epoch ms}`, or the older plain list of ids
  /// (marked at an unknown time: 0). Unreadable: none.
  static Map<String, int> decodeHandAssigned(String? raw) {
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map) {
        return {
          for (final MapEntry<dynamic, dynamic> e in decoded.entries)
            if (e.key.toString().isNotEmpty) e.key.toString(): e.value is num ? (e.value as num).toInt() : 0,
        };
      }
      if (decoded is List) return {for (final dynamic id in decoded) if (id != null && id.toString().isNotEmpty) id.toString(): 0};
    } catch (_) {
      // Unreadable: no marks.
    }
    return <String, int>{};
  }

  /// [marks] without the orders the server no longer shows pending for this
  /// driver in any watched module ([stillPending], the union of each pending
  /// query's last server snapshot): those hand assignments have ended.
  static Map<String, int> pruneHandAssigned(Map<String, int> marks, Set<String> stillPending) =>
      {for (final MapEntry<String, int> e in marks.entries) if (stillPending.contains(e.key)) e.key: e.value};

  /// This device answered [orderId] itself: the accepted job is recorded as
  /// seen so it is never announced back as "a job has been assigned to you"
  /// (a transaction's write reaches the listeners without the local
  /// pending-write mark).
  static void markOwnAnswer(String serviceType, String orderId) {
    final String? uid = _uid;
    if (uid == null || orderId.isEmpty) return;
    final String key = '$serviceType:$orderId';
    if (_seen.contains(key)) return;
    _seen.add(key);
    _persistSeen(uid);
  }

  /// Called from every dashboard controller's `users/{uid}` listener.
  /// Cheap: listeners are (re)opened only for a new driver or a change of
  /// service types; otherwise it only re-checks adoption in memory.
  static void onDriverSnapshot(UserModel? driver) {
    final String uid = (driver?.id ?? '').trim();
    if (driver == null || uid.isEmpty) return;
    // A company account holds no jobs itself; its drivers do.
    if (driver.isOwner == true) {
      stop();
      return;
    }
    final List<String> services = List<String>.from(driver.serviceModules.isEmpty ? const <String>['delivery-service'] : driver.serviceModules)..sort();
    final String servicesKey = services.join(',');
    _driver = driver;
    if (uid != _uid || servicesKey != _servicesKey) {
      _start(uid, services, servicesKey);
      return;
    }
    _adoptMissing();
  }

  /// Sign-out, or a company account: no listener survives.
  static void stop() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _held.clear();
    _pendingHeld.clear();
    _seeding.clear();
    _adopting.clear();
    for (final Timer t in _graceTimers.values) {
      t.cancel();
    }
    _graceTimers.clear();
    _pendingNow.clear();
    _pendingNamed.clear();
    _uid = null;
    _servicesKey = '';
    _driver = null;
    _seen = [];
    _handAssigned = {};
    _pendingModules = [];
    assignedCount.value = 0;
  }

  static void _start(String uid, List<String> services, String servicesKey) {
    final UserModel? driver = _driver;
    stop();
    _driver = driver;
    _uid = uid;
    _servicesKey = servicesKey;

    final String? stored = Preferences.pref.getString(_prefKey(uid));
    final bool firstRun = stored == null;
    try {
      _seen = firstRun ? <String>[] : List<String>.from(jsonDecode(stored) as List);
    } catch (_) {
      _seen = <String>[];
    }
    try {
      _handAssigned = decodeHandAssigned(Preferences.pref.getString(_handPrefKey(uid)));
    } catch (_) {
      _handAssigned = <String, int>{};
    }
    _pendingModules = [
      for (final _Module m in _modules)
        if (m.pendingStatuses.isNotEmpty && services.contains(m.serviceType)) m.serviceType,
    ];

    for (final module in _modules) {
      if (!services.contains(module.serviceType)) continue;
      if (firstRun) _seeding.add(module.serviceType);
      _subs.add(
        FireStoreUtils.fireStore
            .collection(module.collection)
            .where(module.driverField, isEqualTo: uid)
            .where('status', whereIn: _assignedStatuses)
            .snapshots()
            .listen(
              (snap) => _onSnapshot(module, uid, snap),
              onError: (Object e) => log("DriverAssignmentWatcher ${module.collection} failed: $e"),
            ),
      );
      if (module.pendingStatuses.isEmpty) continue;
      final String pendingKey = '${module.serviceType}#pending';
      if (firstRun) _seeding.add(pendingKey);
      _subs.add(
        FireStoreUtils.fireStore
            .collection(module.collection)
            .where(module.driverField, isEqualTo: uid)
            .where('status', whereIn: module.pendingStatuses)
            // The server's confirmation of a first snapshot served from the
            // cache comes even when nothing changed: the marks are checked
            // against it (and pending hand assignments adopted) on start.
            .snapshots(includeMetadataChanges: true)
            .listen(
              (snap) => _onPendingSnapshot(module, uid, snap),
              onError: (Object e) => log("DriverAssignmentWatcher ${module.collection} (pending) failed: $e"),
            ),
      );
    }
  }

  /// The id of a pending hand assignment that should be put on this
  /// driver's record, or null. [data] is an order returned by the pending
  /// query (it names [uid] in a pending status). Skipped: an order this
  /// driver already rejected (`rejectedByDrivers`), one whose status is not
  /// one of [pendingStatuses] or that names someone else, and one older than
  /// the adoption window by its latest date ([now] - 48 h) — an abandoned
  /// record, not a job. An order with no date at all is adopted.
  static String? pendingIdToAdopt(Map<String, dynamic> data, String uid, String driverField, List<String> pendingStatuses, DateTime now, {String? docId}) {
    if (uid.isEmpty) return null;
    if ((data[driverField] ?? '').toString().trim() != uid) return null;
    if (!pendingStatuses.contains(data['status'])) return null;
    final dynamic rejected = data['rejectedByDrivers'];
    if (rejected is List && rejected.map((e) => e.toString()).contains(uid)) return null;
    final DateTime? at = _latest([data['createdAt'], data['scheduleTime'], data['scheduleDateTime']]);
    if (at != null && at.isBefore(now.subtract(_adoptWindow))) return null;
    final String id = (data['id'] ?? docId ?? '').toString().trim();
    return id.isEmpty ? null : id;
  }

  static void _onPendingSnapshot(_Module module, String uid, QuerySnapshot<Map<String, dynamic>> snap) {
    if (uid != _uid) return;
    final bool seeding = _seeding.remove('${module.serviceType}#pending');
    final Map<String, _Assigned> held = {};
    final List<String> fresh = [];
    bool seenChanged = false;
    final DateTime now = DateTime.now();
    final List<dynamic> requests = _driver?.orderRequestData ?? const [];
    final List<dynamic> inProgress = _driver?.inProgressOrderID ?? const [];
    final Set<String> pendingNow = {};

    for (final doc in snap.docs) {
      final Map<String, dynamic> data = doc.data();
      final String? id = pendingIdToAdopt(data, uid, module.driverField, module.pendingStatuses, now, docId: doc.id);
      if (id == null) continue;
      pendingNow.add(id);
      // A mark a later dispatch push overrode is dropped for good.
      if (_handAssigned.containsKey(id) && !isHandAssigned(id)) {
        _handAssigned.remove(id);
        _persistHandAssigned(uid);
      }
      // Same key as the accepted query: an assignment is announced once,
      // whether it is first seen pending or already accepted.
      final String key = '${module.serviceType}:$id';
      final bool driverPending = data['status'] == Constant.driverPending;

      // A dispatch offer: announced by its push and the incoming-order
      // dialog, never here, never adopted. Recorded as seen so its accept is
      // not announced either.
      if (driverPending && !isHandAssigned(id) && (requests.contains(id) || IncomingOfferService.wasPushed(id)) && !inProgress.contains(id)) {
        _graceTimers.remove(key)?.cancel();
        if (!_seen.contains(key)) {
          _seen.add(key);
          seenChanged = true;
        }
        continue;
      }

      // Named on the order but on neither array yet, with no dispatch push:
      // decided once the grace period is over (see the class doc).
      final bool onRecord = requests.contains(id) || inProgress.contains(id);
      if (driverPending && !onRecord && !isHandAssigned(id)) {
        _graceTimers[key] ??= Timer(_dispatchGrace, () => _resolveAfterGrace(module, uid, id));
        continue;
      }

      if (!onRecord) _markHandAssigned(uid, id);
      held[id] = _Assigned(id, _latest([data['createdAt'], data['scheduleTime'], data['scheduleDateTime']]));
      if (_seen.contains(key)) continue;
      _seen.add(key);
      seenChanged = true;
      if (seeding || doc.metadata.hasPendingWrites) continue;
      fresh.add(key);
    }

    _pendingHeld[module.serviceType] = held;
    // A hand assignment that stopped waiting (answered, cancelled, handed to
    // someone else) is forgotten: should the dispatch Cloud Function offer
    // the same order to this driver later, that is a dispatch offer. Checked
    // against the server's pending orders of every watched module, from the
    // first server snapshot on — so one that ended while the app was closed
    // is forgotten as well.
    final Set<String> named = {for (final doc in snap.docs) (doc.data()['id'] ?? doc.id).toString()};
    if (!snap.metadata.isFromCache) {
      _pendingNamed[module.serviceType] = named;
      _pruneHandAssigned(uid);
    }
    _pendingNow[module.serviceType] = pendingNow;
    if (seenChanged || seeding) _persistSeen(uid);
    // Server data only: a cached copy may still show as pending an order this
    // driver has already answered.
    if (!snap.metadata.isFromCache) _adoptPending(module);
    if (fresh.isNotEmpty) _announce(fresh.length);
  }

  /// The grace period of a `Driver Pending` order that named this driver
  /// without reaching their record is over: still missing from the record,
  /// with no dispatch push — a hand assignment (adopted and announced);
  /// otherwise a dispatch offer (recorded silently).
  static void _resolveAfterGrace(_Module module, String uid, String id) {
    final String key = '${module.serviceType}:$id';
    _graceTimers.remove(key);
    // Answered, cancelled or re-dispatched meanwhile: nothing to decide.
    if (uid != _uid || !(_pendingNow[module.serviceType] ?? const <String>{}).contains(id)) return;
    final List<dynamic> requests = _driver?.orderRequestData ?? const [];
    final List<dynamic> inProgress = _driver?.inProgressOrderID ?? const [];
    final bool dispatchOffer = (requests.contains(id) || IncomingOfferService.wasPushed(id)) && !inProgress.contains(id);
    final bool firstTime = !_seen.contains(key);
    if (firstTime) {
      _seen.add(key);
      _persistSeen(uid);
    }
    if (dispatchOffer) return;
    _markHandAssigned(uid, id);
    final Map<String, _Assigned> held = Map<String, _Assigned>.of(_pendingHeld[module.serviceType] ?? const {});
    held[id] = _Assigned(id, null);
    _pendingHeld[module.serviceType] = held;
    _adoptPending(module);
    if (firstTime) _announce(1);
  }

  static void _markHandAssigned(String uid, String id) {
    if (_handAssigned.containsKey(id)) return;
    _handAssigned[id] = DateTime.now().millisecondsSinceEpoch;
    if (_handAssigned.length > _seenCap) {
      _handAssigned = Map<String, int>.fromEntries(_handAssigned.entries.skip(_handAssigned.length - _seenCap));
    }
    _persistHandAssigned(uid);
  }

  /// Once every watched module has had a server snapshot: the marks of
  /// orders none of them shows pending any more are dropped.
  static void _pruneHandAssigned(String uid) {
    if (_handAssigned.isEmpty || _pendingModules.any((m) => !_pendingNamed.containsKey(m))) return;
    final Map<String, int> kept = pruneHandAssigned(_handAssigned, {for (final String m in _pendingModules) ...?_pendingNamed[m]});
    if (kept.length == _handAssigned.length) return;
    _handAssigned = kept;
    _persistHandAssigned(uid);
  }

  static void _persistHandAssigned(String uid) {
    try {
      Preferences.pref.setString(_handPrefKey(uid), jsonEncode(_handAssigned));
    } catch (e) {
      log("DriverAssignmentWatcher: could not persist hand assignments: $e");
    }
  }

  static void _onSnapshot(_Module module, String uid, QuerySnapshot<Map<String, dynamic>> snap) {
    if (uid != _uid) return;
    final bool seeding = _seeding.remove(module.serviceType);
    final Map<String, _Assigned> held = {};
    final List<String> fresh = [];
    bool seenChanged = false;

    for (final doc in snap.docs) {
      final Map<String, dynamic> data = doc.data();
      // No `rejectedByDrivers` filter here: every record this query returns
      // NAMES this driver in an accepted state, i.e. it was handed to them
      // after any earlier rejection (cancelling an accepted job clears the
      // driver field). Skipping it left such a hand assignment invisible.
      final String id = (data['id'] ?? doc.id).toString();
      held[id] = _Assigned(id, _latest([data['createdAt'], data['scheduleTime'], data['scheduleDateTime']]));

      final String key = '${module.serviceType}:$id';
      if (_seen.contains(key)) continue;
      _seen.add(key);
      seenChanged = true;
      // Seeded silently: the first run on this device, or this device's own
      // accept (the snapshot still carries the local write).
      if (seeding || doc.metadata.hasPendingWrites) continue;
      fresh.add(key);
    }

    _held[module.serviceType] = held;
    assignedCount.value = _held.values.fold<int>(0, (total, m) => total + m.length);
    if (seenChanged || seeding) _persistSeen(uid);
    if (module.adoptsIntoUser) _adoptMissing();
    if (fresh.isNotEmpty) _announce(fresh.length);
  }

  /// Delivery / cab: an assigned order the driver's own record does not hold
  /// yet is added to `inProgressOrderID` — what accepting it would write.
  static void _adoptMissing() {
    final UserModel? driver = _driver;
    final String? uid = _uid;
    if (driver == null || uid == null || driver.id != uid) return;
    final List<dynamic> inProgress = driver.inProgressOrderID ?? const [];
    final DateTime cutoff = DateTime.now().subtract(_adoptWindow);

    for (final module in _modules) {
      if (!module.adoptsIntoUser) continue;
      for (final assigned in (_held[module.serviceType] ?? const <String, _Assigned>{}).values) {
        if (inProgress.contains(assigned.id)) continue;
        final DateTime? at = assigned.at;
        if (at != null && at.isBefore(cutoff)) continue;
        if (!_adopting.add(assigned.id)) continue;
        log("DriverAssignmentWatcher: ${module.collection}/${assigned.id} is assigned to $uid but not in inProgressOrderID; adopting it");
        FireStoreUtils.updateUserFields(uid, {
          'inProgressOrderID': FieldValue.arrayUnion([assigned.id]),
        }).whenComplete(() => _adopting.remove(assigned.id));
      }
    }
  }

  /// A pending hand assignment of [module] that the driver's record does not
  /// hold yet goes where that module's home screen looks for a request.
  ///
  /// Only on a snapshot of the pending ORDERS, never on a change of the
  /// driver's own record: answering a request removes its id from the record
  /// before the order's new status is back from the server (a reject writes
  /// the order in a transaction, a ride's reject writes the driver first),
  /// and adopting from the record's snapshot then put the rejected id
  /// straight back on the driver's list.
  static void _adoptPending(_Module module) {
    final UserModel? driver = _driver;
    final String? uid = _uid;
    final String? field = module.pendingAdoptField;
    if (field == null || driver == null || uid == null || driver.id != uid) return;
    final List<dynamic> holds = [...?driver.inProgressOrderID, ...?driver.orderRequestData];
    for (final assigned in (_pendingHeld[module.serviceType] ?? const <String, _Assigned>{}).values) {
      if (holds.contains(assigned.id) || !isHandAssigned(assigned.id)) continue;
      if (!_adopting.add(assigned.id)) continue;
      log("DriverAssignmentWatcher: ${module.collection}/${assigned.id} is assigned to $uid (pending) but not on their record; adding it to $field");
      FireStoreUtils.updateUserFields(uid, {
        field: FieldValue.arrayUnion([assigned.id]),
      }).whenComplete(() => _adopting.remove(assigned.id));
    }
  }

  static DateTime? _latest(List<dynamic> values) {
    DateTime? latest;
    for (final v in values) {
      final DateTime? t = v is Timestamp ? v.toDate() : null;
      if (t != null && (latest == null || t.isAfter(latest))) latest = t;
    }
    return latest;
  }

  static void _persistSeen(String uid) {
    if (_seen.length > _seenCap) _seen = _seen.sublist(_seen.length - _seenCap);
    try {
      Preferences.pref.setString(_prefKey(uid), jsonEncode(_seen));
    } catch (e) {
      log("DriverAssignmentWatcher: could not persist seen ids: $e");
    }
  }

  /// Template types the system alert of a new assignment takes its wording
  /// from (`dynamic_notification`, in this order): the driver's job-assigned
  /// template, else the store's own-delivery-man one. Notification text never
  /// lives in the app: with neither template there is no system notification
  /// (the in-app toast, a UI label, still shows).
  static const List<String> announceTemplateTypes = ['job_assigned', 'new_delivery_order'];

  static Future<void> _announce(int count) async {
    final String body = count == 1 ? "A job has been assigned to you.".tr : "${count.toString()} ${'jobs have been assigned to you.'.tr}";
    ShowToastDialog.showToast("${'New assignment'.tr} · $body");
    NotificationModel? template;
    for (final String type in announceTemplateTypes) {
      try {
        final NotificationModel? found = await FireStoreUtils.getNotificationContent(type);
        if (found != null && ((found.subject ?? '').trim().isNotEmpty || (found.message ?? '').trim().isNotEmpty)) {
          template = found;
          break;
        }
      } catch (e) {
        log("DriverAssignmentWatcher: template '$type' could not be read: $e");
      }
    }
    if (template == null) {
      log("DriverAssignmentWatcher: no dynamic_notification template (${announceTemplateTypes.join(' / ')}); no system notification.");
      return;
    }
    try {
      // The job channel - with the admin's order sound once prepared - and
      // silent while the module's request card already rings that sound.
      final bool silent = await NotificationService.foregroundSilent(jobAlert: true);
      await FlutterLocalNotificationsPlugin().show(
        id: _notificationId,
        title: template.subject,
        body: template.message,
        notificationDetails: await NotificationService.alertDetails(_channelId, silent: silent),
        payload: jsonEncode({'type': 'job_assigned'}),
      );
    } catch (e) {
      log("DriverAssignmentWatcher notification failed: $e");
    }
  }
}

class _Module {
  final String serviceType;
  final String collection;
  final String driverField;

  /// True where the home screen finds a job through `users.inProgressOrderID`
  /// (delivery, cab) rather than by querying the orders (parcel, rental).
  final bool adoptsIntoUser;

  /// Statuses in which an order naming this driver still waits for their
  /// Accept / Reject (a hand assignment). Empty: not watched.
  final List<String> pendingStatuses;

  /// The `users` array a pending hand assignment is added to so the home
  /// screen shows it as a request.
  final String? pendingAdoptField;

  const _Module(this.serviceType, this.collection, this.driverField,
      {this.adoptsIntoUser = false, this.pendingStatuses = const [], this.pendingAdoptField});
}

class _Assigned {
  final String id;
  final DateTime? at;

  const _Assigned(this.id, this.at);
}

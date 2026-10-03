import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/push_message.dart';
import 'package:driver/utils/fire_store_utils.dart';
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
/// This watcher covers both, and is the counterpart of [DriverJobQueueService]
/// (jobs *offered* while offline) for jobs *assigned*:
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
/// Offers (`Driver Pending` + `users.orderRequestData` / `ordercabRequestData`)
/// are untouched: they keep coming from dispatch, and accept / reject keep
/// their existing rules.
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
    _Module('delivery-service', CollectionName.vendorOrders, 'driverID', adoptsIntoUser: true),
    _Module('cab-service', CollectionName.ridesBooking, 'driverId', adoptsIntoUser: true),
    _Module('parcel_delivery', CollectionName.parcelOrders, 'driverId'),
    _Module('rental-service', CollectionName.rentalOrders, 'driverId'),
  ];

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

  /// Modules whose first snapshot is still to come on a device that has never
  /// recorded anything for this driver: their records are seeded silently.
  static final Set<String> _seeding = {};

  /// Persisted "already surfaced" ids, `module:id`.
  static List<String> _seen = [];

  /// Ids with an `arrayUnion` in flight, so a burst of snapshots writes once.
  static final Set<String> _adopting = {};

  static String _prefKey(String uid) => 'assignedJobsSeen_$uid';

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
    final List<String> services = List<String>.from(driver.serviceTypes ?? const <String>['delivery-service'])..sort();
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
    _seeding.clear();
    _adopting.clear();
    _uid = null;
    _servicesKey = '';
    _driver = null;
    _seen = [];
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

  static Future<void> _announce(int count) async {
    final String body = count == 1 ? "A job has been assigned to you.".tr : "${count.toString()} ${'jobs have been assigned to you.'.tr}";
    ShowToastDialog.showToast("${'New assignment'.tr} · $body");
    try {
      const AndroidNotificationDetails android = AndroidNotificationDetails(
        _channelId,
        'New jobs',
        channelDescription: 'Loud alert for a new or assigned delivery, ride, parcel or rental job',
        importance: Importance.max,
        priority: Priority.high,
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        ticker: 'ticker',
      );
      const DarwinNotificationDetails ios = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
      await FlutterLocalNotificationsPlugin().show(
        id: _notificationId,
        title: "New assignment".tr,
        body: body,
        notificationDetails: const NotificationDetails(android: android, iOS: ios),
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

  const _Module(this.serviceType, this.collection, this.driverField, {this.adoptsIntoUser = false});
}

class _Assigned {
  final String id;
  final DateTime? at;

  const _Assigned(this.id, this.at);
}

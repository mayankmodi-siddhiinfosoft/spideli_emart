import 'dart:convert';
import 'dart:developer';

import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/dash_board_controller.dart';
import 'package:driver/controllers/parcel_search_controller.dart';
import 'package:driver/controllers/rental_booking_search_controller.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/region_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

/// The automatic half of the delivery-assignment queue — admin spec §14,
/// client point 9.
///
/// The panel can assign an order to a named driver and resend that assignment
/// by hand. What it cannot do is reach a driver who **comes online after the
/// order was placed**: nothing on the server re-runs dispatch for them. This
/// is that app-side trigger.
///
/// Shape of the trigger, deliberately cheap:
///   * it runs on the **transition** into online — the first user snapshot
///     after app start when the driver is already online, and every
///     offline → online switch afterwards. Never on a timer, never on every
///     snapshot (the user document is rewritten on each location update).
///   * it reuses the existing search controllers, so the eligibility rules
///     (section, zone, region, vehicle / service type, scope, carrier) are
///     read from exactly one place and cannot drift.
///   * it announces an order **once per id per session** ([_announced]), so a
///     driver toggling their status does not get the same job twice.
class DriverJobQueueService {
  DriverJobQueueService._();

  /// Jobs waiting for this driver, found by the last scan. Observables, so a
  /// screen can show a badge with `Obx`.
  static final RxInt parcelJobCount = 0.obs;
  static final RxInt rentalJobCount = 0.obs;

  /// Everything the last scan found — the badge number.
  static final RxInt waitingJobCount = 0.obs;

  /// True while a scan is in flight (a screen may show a subtle spinner).
  static final RxBool isScanning = false.obs;

  static const String _channelId = 'driver_notifications_channel';
  static const int _notificationId = 9114; // spec §9 / §14, kept out of FCM's range.

  static final Set<String> _announced = <String>{};
  static String? _uid;
  static bool? _wasOnline;
  static bool _busy = false;

  /// Detached search controllers used when the matching screen is closed —
  /// built once per session so a scan allocates nothing.
  static ParcelSearchController? _parcelSearch;
  static RentalBookingSearchController? _rentalSearch;

  static const Duration _vendorRetriggerGap = Duration(minutes: 2);
  static DateTime? _lastVendorRetrigger;

  /// Called from every dashboard controller's `users/{uid}` listener.
  /// Does nothing at all unless the driver just became available.
  static void onDriverSnapshot(UserModel? driver) {
    final String uid = driver?.id ?? FireStoreUtils.getCurrentUid();
    if (uid != _uid) reset(uid: uid);

    final bool online = driver?.isActive == true;
    final bool? wasOnline = _wasOnline;
    _wasOnline = online;

    if (!online) {
      _clearCounts();
      return;
    }
    // Already online on the previous snapshot: nothing changed, no query.
    if (wasOnline == true) return;

    // `wasOnline == null` is app start (the driver was already online): the
    // dashboard's own `updateDriverOrder()` has just run, so the vendor-order
    // re-trigger is skipped and only the pull-based services are scanned.
    scan(driver: driver, retriggerVendorOrders: wasOnline == false);
  }

  /// Forgets what was announced (sign-out, or a different driver signing in).
  static void reset({String? uid}) {
    _uid = uid;
    _wasOnline = null;
    _announced.clear();
    _parcelSearch = null;
    _rentalSearch = null;
    _lastVendorRetrigger = null;
    _clearCounts();
  }

  static void _clearCounts() {
    parcelJobCount.value = 0;
    rentalJobCount.value = 0;
    waitingJobCount.value = 0;
  }

  /// One pass over everything this driver is eligible for. Safe to call by
  /// hand (a pull-to-refresh); concurrent calls collapse into one.
  static Future<void> scan({UserModel? driver, bool retriggerVendorOrders = true}) async {
    final UserModel? me = driver ?? Constant.userModel;
    if (me == null || me.isActive != true) return;
    if (_busy) return;
    _busy = true;
    isScanning.value = true;
    try {
      await RegionService.ensureLoaded();

      final double lat = Constant.locationDataFinal?.latitude ?? me.location?.latitude ?? 0.0;
      final double lng = Constant.locationDataFinal?.longitude ?? me.location?.longitude ?? 0.0;
      final List<String> services = me.serviceTypes ?? const <String>[];
      final List<String> freshIds = [];

      if (_hasLocation(lat, lng) && services.contains('parcel_delivery')) {
        freshIds.addAll(await _scanParcels(me, lat, lng));
      }
      if (_hasLocation(lat, lng) && services.contains('rental-service')) {
        freshIds.addAll(await _scanRentals(me, lat, lng));
      }
      if (retriggerVendorOrders && services.contains('delivery-service')) {
        await _renotifyVendorOrders();
      }

      waitingJobCount.value = parcelJobCount.value + rentalJobCount.value;
      if (freshIds.isNotEmpty) await _announce(freshIds.length);
    } catch (e, s) {
      log("DriverJobQueueService scan failed: $e", stackTrace: s);
    } finally {
      isScanning.value = false;
      _busy = false;
    }
  }

  static bool _hasLocation(double lat, double lng) => lat != 0.0 || lng != 0.0;

  // ───────────────────────────────────────────────────────────────────────
  // Parcel
  // ───────────────────────────────────────────────────────────────────────

  static Future<List<String>> _scanParcels(UserModel me, double lat, double lng) async {
    // The registered controller when the search screen is open, otherwise a
    // detached instance kept for the session: either way the query and its
    // rules are the search screen's own.
    final bool live = Get.isRegistered<ParcelSearchController>();
    final ParcelSearchController controller = live ? Get.find<ParcelSearchController>() : (_parcelSearch ??= ParcelSearchController());
    controller.driverModel.value = me;

    final List<ParcelOrderModel> jobs = await controller.searchParcelsOnce(
      srcLat: lat,
      srcLng: lng,
      date: DateTime.now(),
    );

    final String uid = FireStoreUtils.getCurrentUid();
    final List<ParcelOrderModel> waiting = jobs.where((order) {
      final bool unassigned = order.driverId == null || order.driverId!.isEmpty;
      final bool rejectedByMe = (order.rejectedByDrivers ?? const []).contains(uid);
      return unassigned && !rejectedByMe;
    }).toList();

    parcelJobCount.value = waiting.length;
    // The pending-jobs list itself, refreshed in place when it is on screen.
    // (The assigned-parcel list is a live snapshot and needs no refresh.)
    if (live) controller.parcelList.value = waiting;

    return _newIds(waiting.map((o) => o.id));
  }

  // ───────────────────────────────────────────────────────────────────────
  // Rental
  // ───────────────────────────────────────────────────────────────────────

  static Future<List<String>> _scanRentals(UserModel me, double lat, double lng) async {
    final bool live = Get.isRegistered<RentalBookingSearchController>();
    final RentalBookingSearchController controller = live ? Get.find<RentalBookingSearchController>() : (_rentalSearch ??= RentalBookingSearchController());
    controller.driverModel.value = me;

    // Same method the search screen calls (rejectedByDrivers, zone, region and
    // the per-section vehicle match are applied inside it).
    final List<RentalOrderModel> jobs = await controller.searchParcelsOnce(srcLat: lat, srcLng: lng);
    final List<RentalOrderModel> waiting = jobs.where((o) => o.driverId == null || o.driverId!.isEmpty).toList();

    rentalJobCount.value = waiting.length;
    // Same as parcel: refresh the pending-jobs list in place when it is on
    // screen. `RentalHomeController` holds a live snapshot of the ACCEPTED
    // bookings and must not be re-run (it would attach a second listener).
    if (live) controller.rentalBookingData.value = waiting;

    return _newIds(waiting.map((o) => o.id));
  }

  // ───────────────────────────────────────────────────────────────────────
  // eMart / delivery
  // ───────────────────────────────────────────────────────────────────────

  /// Vendor orders are pushed to a driver (`users.orderRequestData`) by the
  /// platform, not pulled by the app, so the app cannot re-offer one itself.
  /// What it can do is re-stamp `triggerDelivery` on the orders still waiting
  /// for a driver, which is exactly what the dashboard already does on start —
  /// running it again on the transition is the re-notification for this
  /// service.
  static Future<void> _renotifyVendorOrders() async {
    if (!Get.isRegistered<DashBoardController>()) return;
    // It rewrites every order still waiting for a driver, so it is rate
    // limited: flipping the availability switch must not storm Firestore.
    final DateTime now = DateTime.now();
    final DateTime? last = _lastVendorRetrigger;
    if (last != null && now.difference(last) < _vendorRetriggerGap) return;
    _lastVendorRetrigger = now;
    await Get.find<DashBoardController>().updateDriverOrder();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Surfacing
  // ───────────────────────────────────────────────────────────────────────

  /// Ids not announced yet this session; marks them announced.
  static List<String> _newIds(Iterable<String?> ids) {
    final List<String> fresh = [];
    for (final id in ids) {
      if (id == null || id.isEmpty) continue;
      if (_announced.add(id)) fresh.add(id);
    }
    return fresh;
  }

  static Future<void> _announce(int count) async {
    final String body = count == 1
        ? "1 request is waiting for you.".tr
        : "${count.toString()} ${'requests are waiting for you.'.tr}";
    ShowToastDialog.showToast("${'New job requests'.tr} · $body");
    await _showLocalNotification(title: "New job requests".tr, body: body);
  }

  /// The app's own local-notification plugin (the same singleton and channel
  /// `NotificationService` sets up for FCM), so no second channel is created.
  static Future<void> _showLocalNotification({required String title, required String body}) async {
    try {
      const AndroidNotificationDetails android = AndroidNotificationDetails(
        _channelId,
        'Driver Notifications',
        channelDescription: 'App Notifications',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
      );
      const DarwinNotificationDetails ios = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
      const NotificationDetails details = NotificationDetails(android: android, iOS: ios);

      await FlutterLocalNotificationsPlugin().show(
        id: _notificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: jsonEncode({'type': 'job_queue'}),
      );
    } catch (e) {
      log("DriverJobQueueService notification failed: $e");
    }
  }
}

import 'dart:developer';

import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/parcel_search_controller.dart';
import 'package:driver/controllers/rental_booking_search_controller.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/dispatch_offer_rules.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/region_service.dart';
import 'package:get/get.dart';

/// A passive count of the open parcel and rental requests in the driver's
/// search lists — the "N requests are waiting" badge of the parcel and rental
/// homes, which opens the search screen.
///
/// **Dispatch belongs to the Cloud Functions** (decision D1,
/// DRIVER_DISPATCH_DOCUMENTATION.md): `deliveryDispatch`, `parcelDispatch`,
/// `cabDispatch` and `rentalDispatch` pick a driver and send the push; the
/// app answers through the incoming-offer dialog. This service therefore
/// announces nothing (no toast, no local notification) and re-triggers
/// nothing: it used to rewrite every waiting `vendor_orders` record
/// (`triggerDelivery`) from each phone that went online, which reverted
/// orders the Cloud Function had just dispatched and produced double offers.
///
/// It counts on the **transition** into online (the first user snapshot of
/// a session when the driver is already online, then every offline -> online
/// switch), never on a timer and never on every snapshot, and reuses the
/// search controllers' own queries so the eligibility rules cannot drift.
class DriverJobQueueService {
  DriverJobQueueService._();

  /// Open requests found by the last count. Observables, for a badge (`Obx`).
  static final RxInt parcelJobCount = 0.obs;
  static final RxInt rentalJobCount = 0.obs;

  /// Everything the last count found.
  static final RxInt waitingJobCount = 0.obs;

  /// True while a count is in flight.
  static final RxBool isScanning = false.obs;

  static String? _uid;
  static bool? _wasOnline;
  static bool _busy = false;

  /// Detached search controllers used when the matching screen is closed —
  /// built once per session.
  static ParcelSearchController? _parcelSearch;
  static RentalBookingSearchController? _rentalSearch;

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
    scan(driver: driver);
  }

  /// Forgets the counts (sign-out, or a different driver signing in).
  static void reset({String? uid}) {
    _uid = uid;
    _wasOnline = null;
    _parcelSearch = null;
    _rentalSearch = null;
    _clearCounts();
  }

  static void _clearCounts() {
    parcelJobCount.value = 0;
    rentalJobCount.value = 0;
    waitingJobCount.value = 0;
  }

  /// One count over the open parcel / rental requests this driver may take
  /// from the search lists. Safe to call by hand (a pull-to-refresh);
  /// concurrent calls collapse into one.
  static Future<void> scan({UserModel? driver}) async {
    final UserModel? me = driver ?? Constant.userModel;
    if (me == null || me.isActive != true || me.isOwner == true) return;
    if (_busy) return;
    _busy = true;
    isScanning.value = true;
    try {
      await RegionService.ensureLoaded();

      final double lat = Constant.locationDataFinal?.latitude ?? me.location?.latitude ?? 0.0;
      final double lng = Constant.locationDataFinal?.longitude ?? me.location?.longitude ?? 0.0;
      final List<String> services = me.serviceModules;

      if (_hasLocation(lat, lng) && services.contains(DriverServiceTypes.parcel)) {
        await _countParcels(me, lat, lng);
      }
      if (_hasLocation(lat, lng) && services.contains(DriverServiceTypes.rental)) {
        await _countRentals(me, lat, lng);
      }
      waitingJobCount.value = parcelJobCount.value + rentalJobCount.value;
    } catch (e, s) {
      log("DriverJobQueueService count failed: $e", stackTrace: s);
    } finally {
      isScanning.value = false;
      _busy = false;
    }
  }

  static bool _hasLocation(double lat, double lng) => lat != 0.0 || lng != 0.0;

  static Future<void> _countParcels(UserModel me, double lat, double lng) async {
    // The registered controller when the search screen is open, otherwise a
    // detached instance kept for the session: either way the query and its
    // rules are the search screen's own.
    final bool live = Get.isRegistered<ParcelSearchController>();
    final ParcelSearchController controller = live ? Get.find<ParcelSearchController>() : (_parcelSearch ??= ParcelSearchController());
    controller.driverModel.value = me;

    final List<ParcelOrderModel> jobs = await controller.searchParcelsOnce(srcLat: lat, srcLng: lng, date: DateTime.now());
    final List<ParcelOrderModel> waiting = jobs.where((order) => order.driverId == null || order.driverId!.isEmpty).toList();
    parcelJobCount.value = waiting.length;
    // The open-requests list itself, refreshed in place when it is on screen.
    if (live) controller.parcelList.value = waiting;
  }

  static Future<void> _countRentals(UserModel me, double lat, double lng) async {
    final bool live = Get.isRegistered<RentalBookingSearchController>();
    final RentalBookingSearchController controller = live ? Get.find<RentalBookingSearchController>() : (_rentalSearch ??= RentalBookingSearchController());
    controller.driverModel.value = me;

    // Same method the search screen calls (rejectedByDrivers, zone, region and
    // the per-section vehicle match are applied inside it).
    final List<RentalOrderModel> jobs = await controller.searchParcelsOnce(srcLat: lat, srcLng: lng);
    final List<RentalOrderModel> waiting = jobs.where((o) => o.driverId == null || o.driverId!.isEmpty).toList();
    rentalJobCount.value = waiting.length;
    if (live) controller.rentalBookingData.value = waiting;
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/assigned_delivery_orders.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/utils/args.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/region_service.dart';
import 'package:driver/utils/utils.dart';
import 'package:driver/widget/cancel_reason_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as location;

import '../models/order_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeController extends GetxController {
  RxBool isLoading = true.obs;
  flutterMap.MapController osmMapController = flutterMap.MapController();
  RxList<flutterMap.Marker> osmMarkers = <flutterMap.Marker>[].obs;

  @override
  void onInit() {
    _initController();
    super.onInit();
  }

  Future<void> _initController() async {
    getArgument();
    await setIcons(); // wait for icons first
    getDriver();
    await _initDeviceLocation();
  }

  /// Fetches device GPS immediately — works offline.
  /// Sets [current] and moves both maps as soon as a controller is available.
  Future<void> _initDeviceLocation() async {
    try {
      double lat = 0.0, lng = 0.0;

      // Use already-cached location if DashBoardController got it first
      final cached = Constant.locationDataFinal;
      if (cached != null && cached.latitude != 0) {
        lat = cached.latitude;
        lng = cached.longitude;
      } else {
        // Direct GPS fetch — works even when offline (no internet needed for GPS)
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }

      current.value = location.LatLng(lat, lng);

      // Move OSM map
      try {
        osmMapController.move(location.LatLng(lat, lng), 16);
      } catch (_) {}

      // Move Google Maps if controller is already assigned
      try {
        mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: LatLng(lat, lng), zoom: 16),
          ),
        );
      } catch (_) {}
    } catch (e) {
      print('HomeController._initDeviceLocation error: $e');
    }
  }

  Rx<OrderModel> orderModel = OrderModel().obs;
  Rx<OrderModel> currentOrder = OrderModel().obs;
  Rx<UserModel> driverModel = UserModel().obs;

  void getArgument() {
    // This screen is BOTH a dashboard tab (opened with whatever arguments the
    // dashboard route carries, or none) and a pushed route from the
    // multiple-order list. `argumentData['orderModel']` therefore has to
    // tolerate a non-map and a missing key: assigning null into this
    // non-nullable Rx threw inside `_initController`, so `getDriver()` never
    // ran and the screen stayed on its loading skeleton forever.
    final OrderModel? passed = argOf<OrderModel>(Get.arguments, 'orderModel');
    if (passed != null) {
      orderModel.value = passed;
    } else {
      _pinnedId = _pendingContinueId;
      _pendingContinueId = null;
    }
  }

  /// "Continue delivery" pressed on the order details (single-order mode).
  /// The home tab is the job screen there, and it used to show whatever it
  /// selected itself — another job, or nothing for an order that names the
  /// driver but is missing from `inProgressOrderID`. The order is now pinned:
  /// watched even when the driver's arrays lack it, and shown first while it
  /// is still the driver's to work.
  static String? _pendingContinueId;

  static void continueDelivery(String orderId) {
    if (orderId.isEmpty) return;
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>()._pin(orderId);
    } else {
      // The home tab builds its controller when it is shown.
      _pendingContinueId = orderId;
    }
  }

  String? _pinnedId;

  void _pin(String orderId) {
    if (orderModel.value.id != null) return; // a screen opened for another order
    _pinnedId = orderId;
    getCurrentOrder();
  }

  /// The offer whose accept is being written. Until it is done that order
  /// stays on screen, whatever the snapshots in between say about it.
  String? _acceptingId;

  Future<void> acceptOrder() async {
    // Captured before any await: `currentOrder` follows the live snapshots
    // and can be reset or replaced while the writes are in flight. Writing
    // `currentOrder.value` afterwards saved an EMPTY order (`doc(null)`
    // created a junk vendor_orders record) and lost the accepted one.
    final OrderModel order = currentOrder.value;
    final String? orderId = order.id;
    final UserModel driver = driverModel.value;
    if (orderId == null || driver.id == null || _acceptingId != null) return;
    _acceptingId = orderId;
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      await AudioPlayerService.playSound(false);
      // Re-checked against the live order, then the order and the driver's
      // arrays are written field by field (never the whole user document).
      final result = await AssignedDeliveryOrders.acceptOffer(orderId, driver);
      ShowToastDialog.closeLoader();
      switch (result.answer) {
        case OfferAnswer.done:
          final OrderModel notified = result.order ?? order;
          // Customer and store, each on its app's channel, by their live tokens.
          unawaited(SendNotification.notifyOrderAccepted(notified));
        case OfferAnswer.held:
          break;
        case OfferAnswer.gone:
          ShowToastDialog.showToast("This order is no longer available.".tr);
        case OfferAnswer.failed:
          ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
      }
    } finally {
      _acceptingId = null;
      await _selectOrder();
    }
  }

  /// Driver passes on the delivery offer on screen. A reason is mandatory
  /// and nothing changes until one is given. The order goes back to dispatch
  /// (status "Driver Rejected", this driver in `rejectedByDrivers`) and the
  /// reason is appended to `driverRejections`, after a re-check of the live
  /// order. The driver's arrays are changed field by field: the whole user
  /// document used to be written back from a copy taken BEFORE the reason
  /// sheet opened, undoing every offer and assignment that arrived meanwhile.
  Future<void> rejectOrder() async {
    final String? uid = driverModel.value.id;
    final String? orderId = currentOrder.value.id;
    if (orderId == null || uid == null) {
      debugPrint("⚠️ No valid order or driver found for rejection.");
      return;
    }

    final reason = await CancelReasonSheet.show(title: "Why are you rejecting this order?".tr);
    if (reason == null) return;
    // The driver's record as it is NOW, after the sheet. The screen may have
    // moved on to a job assigned meanwhile: the offer is still rejected while
    // the driver holds it, and rejectOffer re-checks the live order.
    final UserModel driverNow = driverModel.value;
    if (!(driverNow.orderRequestData ?? const []).contains(orderId) && !(driverNow.inProgressOrderID ?? const []).contains(orderId)) {
      ShowToastDialog.showToast("This order is no longer available.".tr);
      return;
    }

    ShowToastDialog.showLoader("Please wait".tr);
    // 🔊 Stop any ongoing alert sound (if playing)
    await AudioPlayerService.playSound(false);

    final OfferAnswer answer = await AssignedDeliveryOrders.rejectOffer(orderId, uid, reason.toFields(uid));
    if (answer == OfferAnswer.failed) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
      return;
    }

    // Reset order states — only if the screen still shows the rejected order;
    // the snapshots may already have moved it on to the next one.
    orderModel.value = OrderModel();
    if (currentOrder.value.id == orderId) {
      currentOrder.value = OrderModel();
      // Clear map visuals and UI
      await clearMap();
    }
    update();

    // If multiple orders allowed, close dialog/screen
    ShowToastDialog.closeLoader();
    // After closeLoader: EasyLoading shows one overlay, so dismissing the
    // loader would also remove a toast shown while it was up.
    if (answer == OfferAnswer.gone) {
      ShowToastDialog.showToast("This order is no longer available.".tr);
    }
    if (Constant.singleOrderReceive == false) {
      Get.back();
    } else {
      await _selectOrder();
    }
    debugPrint("✅ Order $orderId rejected by driver $uid");
  }

  /// [DeliverOrderScreen] completed [deliveredId]. Only that id leaves
  /// `inProgressOrderID` (field-level). `currentOrder` may already show the
  /// NEXT job by then: removing `currentOrder.value.id` here deleted that job
  /// from the driver's record, and the screen went blank.
  Future<void> onDelivered(String deliveredId) async {
    final String? uid = driverModel.value.id;
    if (uid != null) {
      await FireStoreUtils.updateUserFields(uid, {
        'inProgressOrderID': FieldValue.arrayRemove([deliveredId])
      });
    }
    if (_pinnedId == deliveredId) _pinnedId = null;
    if (currentOrder.value.id == deliveredId) {
      currentOrder.value = OrderModel();
      await clearMap();
    }
    await _selectOrder();
  }

  Future<void> clearMap() async {
    await AudioPlayerService.playSound(false);
    if (Constant.selectedMapType != 'osm') {
      markers.clear();
      polyLines.clear();
    } else {
      osmMarkers.clear();
      routePoints.clear();
    }
    update();
  }

  /// The order on screen comes from ONE live query over the ids this driver
  /// holds ([VendorOrdersWatch]), re-opened only when those ids change, and is
  /// chosen by what each order says ([AssignedDeliveryOrders]) — not by being
  /// `inProgressOrderID.first`.
  ///
  /// Before, every `users/{me}` snapshot (one per location update) opened a
  /// new listener that was never cancelled, and the screen showed whatever
  /// `inProgressOrderID.first` was. A finished or reassigned id in first place
  /// (the Store app writes the driver's whole user document from an older
  /// copy; the admin panel can cancel without touching the driver) hid the
  /// order that was really assigned, and a leftover listener for an earlier
  /// order could replace the live order with a finished one — no buttons.
  late final VendorOrdersWatch _ordersWatch = VendorOrdersWatch(_onOrdersChanged);
  Map<String, OrderModel> _orders = const {};
  final Set<String> _declinedOutOfRegion = {};
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _driverSub;

  @override
  void onClose() {
    _driverSub?.cancel();
    _ordersWatch.cancel();
    super.onClose();
  }

  Future<void> getCurrentOrder() async {
    final driver = driverModel.value;
    final String? explicitId = orderModel.value.id;
    if (explicitId != null) {
      // Opened for one order (the multiple-order list, the order details).
      _ordersWatch.watch([explicitId]);
    } else if (Constant.singleOrderReceive == true) {
      _ordersWatch.watch([...?driver.inProgressOrderID, ...?driver.orderRequestData, if (_pinnedId != null) _pinnedId]);
    } else {
      _ordersWatch.watch(const []);
    }
    await _selectOrder();
  }

  void _onOrdersChanged(Map<String, OrderModel> orders, bool fromServer) {
    _orders = orders;
    final String? uid = driverModel.value.id;
    // Finished / reassigned ids are dropped from the driver's record, so the
    // Store app and the panel stop counting this driver as busy with them.
    if (fromServer && uid != null) {
      AssignedDeliveryOrders.pruneStale(uid, driverModel.value.inProgressOrderID, orders);
    }
    _selectOrder();
  }

  /// Whether [order] may be on this driver's screen at all.
  bool _canShow(OrderModel order, UserModel driver) {
    final String? uid = driver.id;
    final List<dynamic> inProgress = driver.inProgressOrderID ?? const [];
    final List<dynamic> requests = driver.orderRequestData ?? const [];
    if (AssignedDeliveryOrders.isWorkableFor(order, uid)) {
      // Assigned by name (`driverID`), or held in progress by an older writer
      // that never set `driverID`.
      return AssignedDeliveryOrders.isNamedFor(order, uid) || inProgress.contains(order.id);
    }
    if (AssignedDeliveryOrders.isOfferFor(order, uid)) {
      // The offer being accepted right now stays on screen until its writes
      // are done, whichever array the snapshots show it in meanwhile.
      if (order.id != null && order.id == _acceptingId) return true;
      // A dispatched offer, or a hand assignment left at `Driver Pending`.
      // An unnamed pending order in progress with no accept running here is
      // not shown again as a request.
      return requests.contains(order.id) || (inProgress.contains(order.id) && AssignedDeliveryOrders.isNamedFor(order, uid));
    }
    return false;
  }

  /// The order waits for this driver's Accept / Reject (see
  /// [AssignedDeliveryOrders.awaitsDriver]): shown, routed and rung like a
  /// `Driver Pending` request.
  bool isAwaitingAccept(OrderModel order) {
    if (order.id == null) return false;
    final String? uid = driverModel.value.id ?? FirebaseAuth.instance.currentUser?.uid;
    return AssignedDeliveryOrders.awaitsDriver(order, uid);
  }

  bool _outOfRegion(OrderModel order, UserModel driver) {
    // Zone-bound (spec 9.1): never offer a request from another region. A
    // hand assignment that names this driver is not an offer and is kept.
    return order.status == Constant.driverPending &&
        order.id != null &&
        driver.id != null &&
        !AssignedDeliveryOrders.isNamedFor(order, driver.id) &&
        RegionService.isOutOfDriverRegion(order.regionId, driver: driver);
  }

  Future<void> _selectOrder() async {
    if (!_ordersWatch.loaded) return;
    final UserModel driver = driverModel.value;
    final String? uid = driver.id;
    OrderModel? next;

    final String? explicitId = orderModel.value.id;
    if (explicitId != null) {
      final OrderModel? order = _orders[explicitId];
      if (order != null && _canShow(order, driver) && !_outOfRegion(order, driver)) next = order;
    } else if (Constant.singleOrderReceive == true) {
      // The order "Continue delivery" was pressed for, while it is still this
      // driver's to work.
      final String? pinnedId = _pinnedId;
      if (pinnedId != null && uid != null) {
        final OrderModel? pinned = _orders[pinnedId];
        if (pinned != null && AssignedDeliveryOrders.isWorkableFor(pinned, uid) && _canShow(pinned, driver)) {
          next = pinned;
        } else {
          _pinnedId = null; // finished, reassigned or gone: the usual choice
        }
      }
      // Keep the job already on screen while it is still valid, so a second
      // assignment does not swap the screen under the driver's thumb. Only a
      // JOB is kept ahead of the assignments: an offer on screen used to hide
      // an order assigned to this driver until the offer was dealt with.
      final OrderModel? current = currentOrder.value.id == null ? null : _orders[currentOrder.value.id];
      final OrderModel? onScreen = current != null && _canShow(current, driver) && !_outOfRegion(current, driver) ? current : null;
      if (next == null && onScreen != null && (AssignedDeliveryOrders.isWorkableFor(onScreen, uid) || onScreen.id == _acceptingId)) {
        next = onScreen;
      }
      // Then the first order actually being worked, in the driver's order —
      // it replaces an offer on screen (changeData stops the offer's sound)...
      if (next == null) {
        for (final dynamic id in driver.inProgressOrderID ?? const []) {
          final OrderModel? order = _orders[id.toString()];
          if (order != null && AssignedDeliveryOrders.isWorkableFor(order, uid) && _canShow(order, driver)) {
            next = order;
            break;
          }
        }
      }
      // ...then the offer already on screen...
      next ??= onScreen;
      // ...then a request: a named hand assignment, then dispatched offers.
      if (next == null) {
        for (final dynamic id in [...?driver.inProgressOrderID, ...?driver.orderRequestData]) {
          final OrderModel? order = _orders[id.toString()];
          if (order == null || !AssignedDeliveryOrders.isOfferFor(order, uid) || !_canShow(order, driver)) continue;
          if (_outOfRegion(order, driver)) {
            if (_declinedOutOfRegion.add(order.id!)) {
              FireStoreUtils.declineOutOfRegionVendorOrder(order.id!, uid!);
            }
            continue;
          }
          next = order;
          break;
        }
      }
    }

    if (next == null) {
      if (currentOrder.value.id != null) await _resetCurrentOrder();
      return;
    }
    if (identical(currentOrder.value, next)) return;

    currentOrder.value = next;
    // Update section model to match this order's section (multi-section support)
    final sid = next.sectionId;
    if (sid != null && sid.isNotEmpty) {
      FireStoreUtils.getSectionBySectionId(sid).then((s) {
        if (s != null) Constant.sectionModels[sid] = s;
      });
    }
    changeData();
  }

  Future<void> _resetCurrentOrder() async {
    currentOrder.value = OrderModel();
    await clearMap();
    await AudioPlayerService.playSound(false);
    update();
  }

  RxBool isChange = false.obs;

  Future<void> changeData() async {
    print(
        "currentOrder.value.status :: ${currentOrder.value.id} :: ${currentOrder.value.status} :: ( ${orderModel.value.driver?.vendorID != null} :: ${orderModel.value.status})");

    if (Constant.mapType == "inappmap") {
      if (Constant.selectedMapType == "osm") {
        getOSMPolyline();
      } else {
        getDirections();
      }
    }
    if (isAwaitingAccept(currentOrder.value)) {
      await AudioPlayerService.playSound(true);
    } else {
      await AudioPlayerService.playSound(false);
    }
  }

  void getDriver() {
    _driverSub?.cancel();
    _driverSub = FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).snapshots().listen(
      (event) async {
        if (!event.exists) {
          // Nothing more is coming for a document that is not there; without
          // this the screen sat on its loading skeleton for good.
          isLoading.value = false;
          update();
          return;
        }
        if (event.exists) {
          driverModel.value = UserModel.fromJson(event.data()!);
          _updateCurrentLocationMarkers();
          if (driverModel.value.id != null) {
            isLoading.value = false;
            update();
            changeData();
            getCurrentOrder();
            // Preload all registered sections into cache
            for (final sid in driverModel.value.sectionIds ?? <String>[]) {
              if (!Constant.sectionModels.containsKey(sid)) {
                FireStoreUtils.getSectionBySectionId(sid).then((s) {
                  if (s != null) Constant.sectionModels[sid] = s;
                });
              }
            }
          }
        }
      },
      // A stream error (offline, rules refused, a cancelled session) used to
      // leave `isLoading` true for the rest of the session, because it was
      // only ever cleared inside the data callback.
      onError: (Object e) {
        log("HomeController.getDriver failed: $e");
        isLoading.value = false;
        update();
      },
    );
  }

  GoogleMapController? mapController;

  Rx<PolylinePoints> polylinePoints = PolylinePoints(apiKey: Constant.mapAPIKey).obs;
  RxMap<PolylineId, Polyline> polyLines = <PolylineId, Polyline>{}.obs;
  RxMap<String, Marker> markers = <String, Marker>{}.obs;

  BitmapDescriptor? departureIcon;
  BitmapDescriptor? destinationIcon;
  BitmapDescriptor? taxiIcon;

  Future<void> setIcons() async {
    if (Constant.selectedMapType == 'google') {
      final Uint8List departure = await Constant().getBytesFromAsset('assets/images/location_black3x.png', 100);
      final Uint8List destination = await Constant().getBytesFromAsset('assets/images/location_orange3x.png', 100);
      final Uint8List driver = await Constant().getBytesFromAsset('assets/images/food_delivery.png', 120);

      departureIcon = BitmapDescriptor.fromBytes(departure);
      destinationIcon = BitmapDescriptor.fromBytes(destination);
      taxiIcon = BitmapDescriptor.fromBytes(driver);
    }
  }

  Future<void> getDirections() async {
    final order = currentOrder.value;
    final driver = driverModel.value;

    // 1️⃣ Safety checks
    if (order.id == null) {
      debugPrint("⚠️ getDirections: Order ID is null");
      return;
    }

    final driverLoc = driver.location;
    if (driverLoc == null) {
      debugPrint("⚠️ getDirections: Driver location is null");
      return;
    }

    // Icons must be loaded before proceeding
    if (taxiIcon == null || destinationIcon == null || departureIcon == null) {
      debugPrint("⚠️ getDirections: One or more map icons are null");
      return;
    }

    // 2️⃣ Get start and end coordinates based on order status
    LatLng? origin;
    LatLng? destination;

    switch (isAwaitingAccept(order) ? Constant.driverPending : order.status) {
      // Driver Accepted is also on the way to the store (it had no route).
      case Constant.driverAccepted:
      case Constant.orderShipped:
        origin = LatLng(driverLoc.latitude ?? 0.0, driverLoc.longitude ?? 0.0);
        destination = _toLatLng(order.vendor?.latitude, order.vendor?.longitude);
        break;

      case Constant.orderInTransit:
        origin = LatLng(driverLoc.latitude ?? 0.0, driverLoc.longitude ?? 0.0);
        destination = _toLatLng(
          order.address?.location?.latitude,
          order.address?.location?.longitude,
        );
        break;

      case Constant.driverPending:
        origin = _toLatLng(
          order.author?.location?.latitude,
          order.author?.location?.longitude,
        );
        destination = _toLatLng(order.vendor?.latitude, order.vendor?.longitude);
        break;

      default:
        debugPrint("⚠️ getDirections: Unknown order status ${order.status}");
        return;
    }

    // 3️⃣ Fetch polyline route. None when an end has no position (a store
    // saved with "" coordinates, report 02#2): the pins that do exist are
    // still drawn, and nothing is routed or pinned at 0,0.
    final List<LatLng> polylineCoordinates = (origin == null || destination == null) ? <LatLng>[] : await _fetchPolyline(origin, destination);
    if (polylineCoordinates.isEmpty) {
      debugPrint("⚠️ getDirections: No route (missing origin / destination, or none found)");
    }

    // 4️⃣ Update markers safely
    markers.remove("Departure");
    markers.remove("Destination");
    markers.remove("Driver");

    final LatLng? storePoint = _toLatLng(order.vendor?.latitude, order.vendor?.longitude);
    if (storePoint != null && (order.status == Constant.orderShipped || order.status == Constant.driverAccepted || isAwaitingAccept(order))) {
      markers['Departure'] = Marker(
        markerId: const MarkerId('Departure'),
        infoWindow: const InfoWindow(title: "Departure"),
        position: storePoint,
        icon: departureIcon!,
      );
    }

    final LatLng? dropPoint = _toLatLng(order.address?.location?.latitude, order.address?.location?.longitude);
    if (dropPoint != null && (order.status == Constant.orderInTransit || isAwaitingAccept(order))) {
      markers['Destination'] = Marker(
        markerId: const MarkerId('Destination'),
        infoWindow: const InfoWindow(title: "Destination"),
        position: dropPoint,
        icon: destinationIcon!,
      );
    }

    markers['Driver'] = Marker(
      markerId: const MarkerId('Driver'),
      infoWindow: const InfoWindow(title: "Driver"),
      position: LatLng(
        driverLoc.latitude ?? 0.0, // ✅ safe fallback
        driverLoc.longitude ?? 0.0, // ✅ safe fallback
      ),
      icon: taxiIcon!,
      rotation: double.tryParse(driver.rotation.toString()) ?? 0,
    );

    // 5️⃣ Draw polyline
    addPolyLine(polylineCoordinates);
  }

  /// Helper: a LatLng only for a real position — null for a missing, NaN or
  /// 0,0 one (a store saved without a position, report 02#2).
  LatLng? _toLatLng(double? lat, double? lng) {
    if (!Utils.isRoutable(lat, lng)) return null;
    return LatLng(lat!, lng!);
  }

  /// Helper: fetch polyline safely
  Future<List<LatLng>> _fetchPolyline(LatLng origin, LatLng destination) async {
    try {
      final result = await polylinePoints.value.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isEmpty) return [];

      return result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    } catch (e, st) {
      debugPrint("❌ getDirections _fetchPolyline error: $e\n$st");
      return [];
    }
  }

  void addPolyLine(List<LatLng> polylineCoordinates) {
    PolylineId id = const PolylineId("poly");
    Polyline polyline = Polyline(
      polylineId: id,
      color: AppThemeData.primary300,
      points: polylineCoordinates,
      width: 8,
      geodesic: true,
    );
    polyLines[id] = polyline;
    update();
    // No route (or no map yet): `.first` / `mapController!` threw here.
    if (polylineCoordinates.isEmpty || mapController == null) return;
    updateCameraLocation(polylineCoordinates.first, mapController);
  }

  Future<void> updateCameraLocation(
    LatLng source,
    GoogleMapController? mapController,
  ) async {
    mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: source,
          zoom: currentOrder.value.id == null || isAwaitingAccept(currentOrder.value) ? 16 : 20,
          bearing: double.parse(driverModel.value.rotation.toString()),
        ),
      ),
    );
  }

  void animateToSource() {
    double lat = 0.0;
    double lng = 0.0;
    final loc = driverModel.value.location;
    if (loc != null) {
      // Use string parsing to avoid nullable-toDouble issues and handle numbers/strings.
      lat = double.tryParse('${loc.latitude}') ?? 0.0;
      lng = double.tryParse('${loc.longitude}') ?? 0.0;
    }
    _updateCurrentLocationMarkers();
    osmMapController.move(location.LatLng(lat, lng), 16);
  }

  void _updateCurrentLocationMarkers() async {
    try {
      final loc = driverModel.value.location;
      final latLng = _safeLatLngFromLocation(loc);

      // Update reactive current location
      current.value = location.LatLng(latLng.latitude, latLng.longitude);

      // --- OSM Section ---
      try {
        setOsmMapMarker();

        if (latLng.latitude != 0.0 || latLng.longitude != 0.0) {
          osmMapController.move(location.LatLng(latLng.latitude, latLng.longitude), 16);
        }
      } catch (e) {
        print("OSM map move ignored (controller not ready): $e");
      }

      // --- GOOGLE MAP Section ---
      try {
        // Remove old driver marker
        markers.remove("Driver");

        // Create new Google Marker
        markers["Driver"] = Marker(
          markerId: const MarkerId("Driver"),
          infoWindow: const InfoWindow(title: "Driver"),
          position: LatLng(current.value.latitude, current.value.longitude),
          icon: taxiIcon!,
          rotation: _safeRotation(),
          anchor: const Offset(0.5, 0.5),
          flat: true,
        );

        // Animate camera to current driver location
        if (mapController != null && !(current.value.latitude == 0.0 && current.value.longitude == 0.0)) {
          mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(current.value.latitude, current.value.longitude),
                zoom: 16,
                bearing: _safeRotation(),
              ),
            ),
          );
        }
      } catch (e) {
        print("Google map update ignored (controller not ready): $e");
      }

      update();
    } catch (e) {
      print("_updateCurrentLocationMarkers error: $e");
    }
  }

  double _safeRotation() {
    return double.tryParse(driverModel.value.rotation.toString()) ?? 0.0;
  }

  LatLng _safeLatLngFromLocation(dynamic loc) {
    final lat = (loc?.latitude is num) ? loc.latitude.toDouble() : 0.0;
    final lng = (loc?.longitude is num) ? loc.longitude.toDouble() : 0.0;
    return LatLng(lat, lng);
  }

  /// The pickup (store) of the order on screen, or null when it has no
  /// position or there is no order. It was a hard-coded default (Surat),
  /// pinned on the map for every order.
  Rx<location.LatLng?> source = Rx<location.LatLng?>(null);
  Rx<location.LatLng> current = location.LatLng(21.1800, 72.8400).obs; // Moving marker
  Rx<location.LatLng> destination = location.LatLng(21.2000, 72.8600).obs; // Destination

  /// False while the OSM target has no position (a store saved without one),
  /// or before any order was routed: no destination pin, and no route,
  /// rather than one at 0,0 or at the default above.
  bool _osmHasDestination = false;

  /// Routes the OSM map from [from] to [to], or draws no route and no
  /// destination pin when [to] is null.
  void _osmRouteTo(location.LatLng from, location.LatLng? to) {
    _osmHasDestination = to != null;
    if (to == null) {
      routePoints.clear();
      setOsmMapMarker();
      return;
    }
    destination.value = to;
    fetchRoute(from, to).then((value) {
      setOsmMapMarker();
    });
  }

  location.LatLng? _osmPoint(double? lat, double? lng) => Utils.isRoutable(lat, lng) ? location.LatLng(lat!, lng!) : null;

  void setOsmMapMarker() {
    final OrderModel order = currentOrder.value;
    final bool hasOrder = order.id != null;
    // The store's real position, or no pin (a store saved without one).
    final location.LatLng? store = hasOrder ? _osmPoint(order.vendor?.latitude, order.vendor?.longitude) : null;
    source.value = store;
    final bool hasDestination = hasOrder && _osmHasDestination;
    // On the way to the store the store IS the destination pin: not twice.
    final bool storeIsDestination = hasDestination && destination.value == store;
    osmMarkers.value = [
      if (Utils.isRoutable(current.value.latitude, current.value.longitude))
        flutterMap.Marker(
          point: current.value,
          width: 45,
          height: 45,
          rotate: true,
          child: Image.asset('assets/images/food_delivery.png'),
        ),
      if (store != null && !storeIsDestination)
        flutterMap.Marker(
          point: store,
          width: 40,
          height: 40,
          child: Image.asset('assets/images/location_black3x.png'),
        ),
      if (hasDestination)
        flutterMap.Marker(
          point: destination.value,
          width: 40,
          height: 40,
          child: Image.asset('assets/images/location_orange3x.png'),
        )
    ];
  }

  void getOSMPolyline() async {
    try {
      if (currentOrder.value.id != null) {
        if (!isAwaitingAccept(currentOrder.value)) {
          print("Order Status :: ${currentOrder.value.status} :: OrderId :: ${currentOrder.value.id}} ::");
          if (currentOrder.value.status == Constant.orderShipped || currentOrder.value.status == Constant.driverAccepted) {
            current.value = location.LatLng(driverModel.value.location!.latitude ?? 0.0, driverModel.value.location!.longitude ?? 0.0);
            final store = _osmPoint(currentOrder.value.vendor?.latitude, currentOrder.value.vendor?.longitude);
            if (store != null) destination.value = store;
            _osmHasDestination = store != null;
            animateToSource();
            _osmRouteTo(current.value, store);
          } else if (currentOrder.value.status == Constant.orderInTransit) {
            print(":::::::::::::${currentOrder.value.status}::::::::::::::::::44");
            current.value = location.LatLng(driverModel.value.location!.latitude ?? 0.0, driverModel.value.location!.longitude ?? 0.0);
            final drop = _osmPoint(currentOrder.value.address?.location?.latitude, currentOrder.value.address?.location?.longitude);
            if (drop != null) destination.value = drop;
            _osmHasDestination = drop != null;
            setOsmMapMarker();
            _osmRouteTo(current.value, drop);
            animateToSource();
          }
        } else {
          print("====>5");
          current.value =
              location.LatLng(currentOrder.value.author!.location!.latitude ?? 0.0, currentOrder.value.author!.location!.longitude ?? 0.0);

          final store = _osmPoint(currentOrder.value.vendor?.latitude, currentOrder.value.vendor?.longitude);
          if (store != null) destination.value = store;
          _osmHasDestination = store != null;
          animateToSource();
          _osmRouteTo(current.value, store);
          animateToSource();
        }
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  RxList<location.LatLng> routePoints = <location.LatLng>[].obs;

  Future<void> fetchRoute(location.LatLng source, location.LatLng destination) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${source.longitude},${source.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final geometry = decoded['routes'][0]['geometry']['coordinates'];

      routePoints.clear();
      for (var coord in geometry) {
        final lon = coord[0];
        final lat = coord[1];
        routePoints.add(location.LatLng(lat, lon));
      }
    } else {
      print("Failed to get route: ${response.body}");
    }
  }
}

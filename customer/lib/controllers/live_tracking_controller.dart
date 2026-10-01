import 'dart:async';
import 'dart:convert';
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/order_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as location;
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;

/// Live order tracking.
///
/// The screen used to come up empty (bug #4, 1 October). Three things had to
/// line up before anything was ever drawn:
///
/// 1. markers and the camera were only ever touched from the **driver**
///    snapshot, which is subscribed to only once `driverID` is set — before a
///    driver is assigned the map sat at lat/lng 0,0 with no markers at all;
/// 2. the route call came first and was unguarded, so a failing Directions /
///    OSRM request (no network, Directions API not enabled on the key) threw
///    and the marker + camera code after it never ran;
/// 3. on the Google side the camera was only ever moved from `_addPolyLine`,
///    which returns early when the route comes back empty — so the map stayed
///    on its `initialCameraPosition` of 0,0 (open ocean, which reads as "the
///    map does not display").
///
/// Markers and the camera are therefore now driven by the **order** (which is
/// available immediately), the route is loaded afterwards and may fail without
/// taking anything else with it, and camera moves are deferred until the map
/// itself reports that it is ready.
class LiveTrackingController extends GetxController {
  GoogleMapController? mapController;
  final flutterMap.MapController osmMapController = flutterMap.MapController();

  Rx<OrderModel> orderModel = OrderModel().obs;
  Rx<UserModel> driverUserModel = UserModel().obs;
  RxBool isLoading = true.obs;

  Rx<location.LatLng> source = location.LatLng(0, 0).obs;
  Rx<location.LatLng> destination = location.LatLng(0, 0).obs;
  Rx<location.LatLng> driverCurrent = location.LatLng(0, 0).obs;

  RxList<location.LatLng> routePoints = <location.LatLng>[].obs;
  RxMap<MarkerId, Marker> markers = <MarkerId, Marker>{}.obs;
  RxMap<PolylineId, Polyline> polyLines = <PolylineId, Polyline>{}.obs;
  RxList<flutterMap.Marker> osmMarkers = <flutterMap.Marker>[].obs;

  BitmapDescriptor? pickupIcon;
  BitmapDescriptor? dropoffIcon;
  BitmapDescriptor? driverIcon;

  /// Resolved once the three marker bitmaps are decoded; awaited before the
  /// first Google marker is built so markers are never dropped for want of an
  /// icon that was still loading.
  Future<void>? _iconsReady;

  PolylinePoints polylinePoints = PolylinePoints(apiKey: Constant.mapAPIKey);

  StreamSubscription? orderSub;
  StreamSubscription? driverSub;

  /// The map widget is only safe to drive once it exists: `MapController.move`
  /// throws before the first layout, and the Google controller does not exist
  /// until `onMapCreated`.
  bool _mapReady = false;

  bool get isOsm => Constant.selectedMapType == 'osm';

  @override
  void onInit() {
    super.onInit();
    _iconsReady = addMarkerIcons();
    getArguments();
  }

  @override
  void onClose() {
    orderSub?.cancel();
    driverSub?.cancel();
    super.onClose();
  }

  Future<void> getArguments() async {
    try {
      final args = Get.arguments;
      final dynamic argOrder = args is Map ? args['orderModel'] : null;
      if (argOrder is! OrderModel) return;

      orderModel.value = argOrder;
      // Draw from the order we were handed straight away: waiting for the
      // first snapshot (or for a driver to be assigned) is what left the map
      // blank.
      applyOrder();

      orderSub = FireStoreUtils.fireStore.collection(CollectionName.vendorOrders).doc(orderModel.value.id).snapshots().listen((orderSnap) {
        if (orderSnap.data() == null) return;
        orderModel.value = OrderModel.fromJson(orderSnap.data()!);
        applyOrder();

        if (orderModel.value.driverID != null) {
          driverSub?.cancel();
          driverSub = FireStoreUtils.fireStore.collection(CollectionName.users).doc(orderModel.value.driverID).snapshots().listen((driverSnap) {
            if (driverSnap.data() == null) return;
            driverUserModel.value = UserModel.fromJson(driverSnap.data()!);
            updateLiveTracking();
          });
        }

        if (orderModel.value.status == Constant.orderCompleted) {
          Get.back();
        }
      });
    } finally {
      // Never leave the screen on its spinner, whatever the arguments were.
      isLoading.value = false;
    }
  }

  /// The store and the delivery address come from the order, so they are known
  /// before (and independently of) any driver.
  void applyOrder() {
    source.value = location.LatLng(orderModel.value.vendor?.latitude ?? 0.0, orderModel.value.vendor?.longitude ?? 0.0);
    destination.value = location.LatLng(orderModel.value.address?.location?.latitude ?? 0.0, orderModel.value.address?.location?.longitude ?? 0.0);
    updateLiveTracking();
  }

  Future<void> updateLiveTracking() async {
    driverCurrent.value = location.LatLng(driverUserModel.value.location?.latitude ?? 0.0, driverUserModel.value.location?.longitude ?? 0.0);

    // Before pickup the leg that matters is driver → store; afterwards it is
    // driver → customer. Both ends are still marked either way so the map is
    // never empty.
    final bool beforePickup = orderModel.value.status == Constant.orderPlaced || orderModel.value.status == Constant.orderAccepted;
    final location.LatLng legEnd = beforePickup ? source.value : destination.value;

    await drawMarkers();
    moveCamera();

    // The route is a bonus on top of the markers: it must never be able to
    // stop them being drawn, so it is loaded last and failures are swallowed.
    await loadRoute(driverCurrent.value, legEnd);
  }

  /// Every point the map should be able to show, in drawing order.
  List<location.LatLng> get trackedPoints => [
    if (hasPoint(driverCurrent.value)) driverCurrent.value,
    if (hasPoint(source.value)) source.value,
    if (hasPoint(destination.value)) destination.value,
  ];

  /// 0,0 is this data model's "not set" — a real order is never in the Gulf of
  /// Guinea, and centring there is what made the map look broken.
  static bool hasPoint(location.LatLng point) => point.latitude != 0 || point.longitude != 0;

  /// Where the map should open before anything has loaded: the driver if we
  /// have one, else the store, else the delivery address.
  location.LatLng get initialTarget => trackedPoints.isEmpty ? const location.LatLng(0, 0) : trackedPoints.first;

  Future<void> drawMarkers() async {
    if (isOsm) {
      addOsmMarkers();
    } else {
      await addGoogleMarkers();
    }
  }

  Future<void> loadRoute(location.LatLng from, location.LatLng to) async {
    if (!hasPoint(from) || !hasPoint(to)) return;
    // The leg changes when the order moves from "heading to the store" to
    // "heading to you", so drop the old line before drawing the new one.
    routePoints.clear();
    polyLines.clear();
    try {
      if (isOsm) {
        await fetchRoute(from, to);
      } else {
        await getPolyline(sourceLatitude: from.latitude, sourceLongitude: from.longitude, destinationLatitude: to.latitude, destinationLongitude: to.longitude);
      }
    } catch (e) {
      // No network, Directions API not enabled on the key, OSRM down: keep the
      // markers and the camera, just without the line.
      debugPrint('Live tracking route unavailable: $e');
    }
  }

  // ---------------------------------------------------------------- camera

  /// Called from the map widgets once they can actually be driven.
  void onOsmMapReady() {
    _mapReady = true;
    moveCamera();
  }

  void onGoogleMapCreated(GoogleMapController controller) {
    mapController = controller;
    _mapReady = true;
    moveCamera();
  }

  void moveCamera() {
    if (!_mapReady) return;
    final points = trackedPoints;
    if (points.isEmpty) return;
    try {
      if (isOsm) {
        if (points.length == 1) {
          osmMapController.move(points.first, 15);
        } else {
          osmMapController.fitCamera(flutterMap.CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(60)));
        }
      } else {
        final controller = mapController;
        if (controller == null) return;
        if (points.length == 1) {
          controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(points.first.latitude, points.first.longitude), 15));
        } else {
          controller.animateCamera(CameraUpdate.newLatLngBounds(boundsOf(points), 80));
        }
      }
    } catch (e) {
      debugPrint('Live tracking camera move failed: $e');
    }
  }

  static LatLngBounds boundsOf(List<location.LatLng> points) {
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  // ------------------------------------------------------------------- OSM

  Future<void> fetchRoute(location.LatLng source, location.LatLng destination) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${source.longitude},${source.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final routes = data['routes'];
      if (routes is List && routes.isNotEmpty) {
        final coords = routes[0]['geometry']['coordinates'];
        routePoints.value = (coords as List).map<location.LatLng>((c) => location.LatLng(c[1].toDouble(), c[0].toDouble())).toList();
      }
    }
  }

  void addOsmMarkers() {
    osmMarkers.value = [
      if (hasPoint(driverCurrent.value)) flutterMap.Marker(point: driverCurrent.value, width: 40, height: 40, child: Image.asset('assets/images/food_delivery.png')),
      if (hasPoint(source.value)) flutterMap.Marker(point: source.value, width: 40, height: 40, child: Image.asset('assets/images/pickup.png')),
      if (hasPoint(destination.value)) flutterMap.Marker(point: destination.value, width: 40, height: 40, child: Image.asset('assets/images/dropoff.png')),
    ];
  }

  // ---------------------------------------------------------------- Google

  Future<void> getPolyline({
    required double sourceLatitude,
    required double sourceLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(origin: PointLatLng(sourceLatitude, sourceLongitude), destination: PointLatLng(destinationLatitude, destinationLongitude), mode: TravelMode.driving),
    );

    if (result.points.isEmpty) return;
    _addPolyLine(result.points.map((e) => LatLng(e.latitude, e.longitude)).toList());
  }

  Future<void> addGoogleMarkers() async {
    await _iconsReady;
    markers.clear();

    if (hasPoint(driverCurrent.value)) {
      addMarker(
        id: "Driver",
        latitude: driverCurrent.value.latitude,
        longitude: driverCurrent.value.longitude,
        descriptor: driverIcon,
        rotation: (driverUserModel.value.rotation ?? 0).toDouble(),
      );
    }
    if (hasPoint(source.value)) {
      addMarker(id: "Pickup", latitude: source.value.latitude, longitude: source.value.longitude, descriptor: pickupIcon, rotation: 0.0);
    }
    if (hasPoint(destination.value)) {
      addMarker(id: "Drop", latitude: destination.value.latitude, longitude: destination.value.longitude, descriptor: dropoffIcon, rotation: 0.0);
    }
  }

  void addMarker({required String id, required double latitude, required double longitude, required BitmapDescriptor? descriptor, required double rotation}) {
    final MarkerId markerId = MarkerId(id);
    markers[markerId] = Marker(
      markerId: markerId,
      // A bitmap that failed to decode must not cost us the marker.
      icon: descriptor ?? BitmapDescriptor.defaultMarker,
      position: LatLng(latitude, longitude),
      rotation: rotation,
      anchor: const Offset(0.5, 0.5),
    );
  }

  Future<void> addMarkerIcons() async {
    if (isOsm) return;
    try {
      pickupIcon = BitmapDescriptor.fromBytes(await Constant().getBytesFromAsset('assets/images/pickup.png', 100));
      dropoffIcon = BitmapDescriptor.fromBytes(await Constant().getBytesFromAsset('assets/images/dropoff.png', 100));
      driverIcon = BitmapDescriptor.fromBytes(await Constant().getBytesFromAsset('assets/images/food_delivery.png', 100));
    } catch (e) {
      debugPrint('Live tracking marker icons unavailable: $e');
    }
  }

  void _addPolyLine(List<LatLng> polylineCoordinates) {
    if (polylineCoordinates.isEmpty) return;
    const PolylineId id = PolylineId("poly");
    polyLines[id] = Polyline(polylineId: id, color: Colors.blue, width: 5, points: polylineCoordinates);
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/utils/fire_store_utils.dart';
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
      if (cached != null && (cached.latitude ?? 0) != 0) {
        lat = cached.latitude!;
        lng = cached.longitude!;
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
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      orderModel.value = argumentData['orderModel'];
    }
  }

  Future<void> acceptOrder() async {
    ShowToastDialog.showLoader("Please wait".tr);

    await AudioPlayerService.playSound(false);

    currentOrder.value.status = Constant.driverAccepted;
    currentOrder.value.driverID = driverModel.value.id;
    currentOrder.value.driver = driverModel.value;

    driverModel.value.inProgressOrderID ??= [];
    driverModel.value.orderRequestData!.remove(currentOrder.value.id);
    driverModel.value.inProgressOrderID!.add(currentOrder.value.id);

    await FireStoreUtils.updateUser(driverModel.value);
    await FireStoreUtils.setOrder(currentOrder.value);
    print("SendNotification ===========>");
    SendNotification.sendFcmMessage(Constant.driverAcceptedNotification, currentOrder.value.author?.fcmToken ?? '', {});
    SendNotification.sendFcmMessage(Constant.driverAcceptedNotification, currentOrder.value.vendor?.fcmToken ?? '', {});
    ShowToastDialog.closeLoader();
  }

  Future<void> rejectOrder() async {
    ShowToastDialog.showLoader("Please wait".tr);
    // 🔊 Stop any ongoing alert sound (if playing)
    await AudioPlayerService.playSound(false);

    final driver = driverModel.value;
    final order = currentOrder.value;

    // 1️⃣ Validate order and driver
    if (order.id == null || driver.id == null) {
      debugPrint("⚠️ No valid order or driver found for rejection.");
      return;
    }

    // 2️⃣ Add driver to rejected list safely
    order.rejectedByDrivers ??= [];
    if (!order.rejectedByDrivers!.contains(driver.id)) {
      order.rejectedByDrivers!.add(driver.id);
    }

    // 3️⃣ Update order status
    order.status = Constant.driverRejected;

    // 4️⃣ Push order update to Firestore
    await FireStoreUtils.setOrder(order);

    // 5️⃣ Clean up driver's order tracking data safely
    driver.orderRequestData?.remove(order.id);
    driver.inProgressOrderID?.remove(order.id);

    // 6️⃣ Update driver info in Firestore
    await FireStoreUtils.updateUser(driver);

    // 7️⃣ Reset order states
    currentOrder.value = OrderModel();
    orderModel.value = OrderModel();

    // 8️⃣ Clear map visuals and UI
    await clearMap();
    update();

    // 9️⃣ If multiple orders allowed, close dialog/screen
    ShowToastDialog.closeLoader();
    if (Constant.singleOrderReceive == false) {
      Get.back();
    }
    debugPrint("✅ Order ${order.id} rejected by driver ${driver.id}");
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

  Future<void> getCurrentOrder() async {
    final driver = driverModel.value;
    final currentId = currentOrder.value.id;

    // 1️⃣ Reset if current order is invalid
    if (currentId != null &&
        !(driver.orderRequestData?.contains(currentId) ?? false) &&
        !(driver.inProgressOrderID?.contains(currentId) ?? false)) {
      await _resetCurrentOrder();
      return;
    }

    // 2️⃣ Handle single-order mode
    if (Constant.singleOrderReceive == true) {
      final inProgress = driver.inProgressOrderID;
      final requests = driver.orderRequestData;

      if (inProgress != null && inProgress.isNotEmpty) {
        _listenToOrder(inProgress.first);
        return;
      }

      if (requests != null && requests.isNotEmpty) {
        _listenToOrder(requests.first, checkInRequestData: true);
        return;
      }
    }

    // 3️⃣ Handle fallback (when orderModel has ID)
    final fallbackId = orderModel.value.id;
    if (fallbackId != null) {
      _listenToOrder(fallbackId);
    }
  }

  Future<void> _resetCurrentOrder() async {
    currentOrder.value = OrderModel();
    await clearMap();
    await AudioPlayerService.playSound(false);
    update();
  }

  /// 🔹 Listen to Firestore order updates for a specific orderId
  void _listenToOrder(String orderId, {bool checkInRequestData = false}) {
    FireStoreUtils.fireStore
        .collection(CollectionName.vendorOrders)
        .where('status', whereNotIn: [
          Constant.orderCancelled,
          Constant.driverRejected,
        ])
        .where('id', isEqualTo: orderId)
        .snapshots()
        .listen((event) async {
          if (event.docs.isEmpty) {
            await _handleOrderNotFound();
            return;
          }

          final data = event.docs.first.data();
          final newOrder = OrderModel.fromJson(data);

          if (checkInRequestData && !(driverModel.value.orderRequestData?.contains(newOrder.id) ?? false)) {
            await _handleOrderNotFound();
            return;
          }

          if (newOrder.rejectedByDrivers!.contains(driverModel.value.id)) {
            await _handleOrderNotFound();
            return;
          }

          // Guard: skip stale driverPending update if driver already accepted this order
          if (newOrder.status == Constant.driverPending && (driverModel.value.inProgressOrderID?.contains(newOrder.id) ?? false)) {
            return;
          }

          currentOrder.value = newOrder;
          // Update section model to match this order's section (multi-section support)
          final sid = newOrder.sectionId;
          if (sid != null && sid.isNotEmpty) {
            FireStoreUtils.getSectionBySectionId(sid).then((s) {
              if (s != null) Constant.sectionModels[sid] = s;
            });
          }
          changeData();
        });
  }

  Future<void> _handleOrderNotFound() async {
    currentOrder.value = OrderModel();
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
    if (currentOrder.value.status == Constant.driverPending) {
      await AudioPlayerService.playSound(true);
    } else {
      await AudioPlayerService.playSound(false);
    }
  }

  void getDriver() {
    FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).snapshots().listen(
      (event) async {
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

    switch (order.status) {
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

    if (origin == null || destination == null) {
      debugPrint("⚠️ getDirections: Missing origin or destination");
      return;
    }

    // 3️⃣ Fetch polyline route
    final polylineCoordinates = await _fetchPolyline(origin, destination);
    if (polylineCoordinates.isEmpty) {
      debugPrint("⚠️ getDirections: No route found between origin and destination");
    }

    // 4️⃣ Update markers safely
    markers.remove("Departure");
    markers.remove("Destination");
    markers.remove("Driver");

    if (order.status == Constant.orderShipped || order.status == Constant.driverPending) {
      markers['Departure'] = Marker(
        markerId: const MarkerId('Departure'),
        infoWindow: const InfoWindow(title: "Departure"),
        position: _toLatLng(order.vendor?.latitude, order.vendor?.longitude) ?? const LatLng(0, 0),
        icon: departureIcon!,
      );
    }

    if (order.status == Constant.orderInTransit || order.status == Constant.driverPending) {
      markers['Destination'] = Marker(
        markerId: const MarkerId('Destination'),
        infoWindow: const InfoWindow(title: "Destination"),
        position: _toLatLng(
              order.address?.location?.latitude,
              order.address?.location?.longitude,
            ) ??
            const LatLng(0, 0),
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

  /// Helper: safely convert to LatLng if valid
  LatLng? _toLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
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
          zoom: currentOrder.value.id == null || currentOrder.value.status == Constant.driverPending ? 16 : 20,
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

  Rx<location.LatLng> source = location.LatLng(21.1702, 72.8311).obs; // Start (e.g., Surat)
  Rx<location.LatLng> current = location.LatLng(21.1800, 72.8400).obs; // Moving marker
  Rx<location.LatLng> destination = location.LatLng(21.2000, 72.8600).obs; // Destination

  void setOsmMapMarker() {
    osmMarkers.value = [
      flutterMap.Marker(
        point: current.value,
        width: 45,
        height: 45,
        rotate: true,
        child: Image.asset('assets/images/food_delivery.png'),
      ),
      flutterMap.Marker(
        point: source.value,
        width: 40,
        height: 40,
        child: Image.asset('assets/images/location_black3x.png'),
      ),
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
        if (currentOrder.value.status != Constant.driverPending) {
          print("Order Status :: ${currentOrder.value.status} :: OrderId :: ${currentOrder.value.id}} ::");
          if (currentOrder.value.status == Constant.orderShipped) {
            current.value = location.LatLng(driverModel.value.location!.latitude ?? 0.0, driverModel.value.location!.longitude ?? 0.0);
            destination.value = location.LatLng(
              currentOrder.value.vendor!.latitude ?? 0.0,
              currentOrder.value.vendor!.longitude ?? 0.0,
            );
            animateToSource();
            fetchRoute(current.value, destination.value).then((value) {
              setOsmMapMarker();
            });
          } else if (currentOrder.value.status == Constant.orderInTransit) {
            print(":::::::::::::${currentOrder.value.status}::::::::::::::::::44");
            current.value = location.LatLng(driverModel.value.location!.latitude ?? 0.0, driverModel.value.location!.longitude ?? 0.0);
            destination.value = location.LatLng(
              currentOrder.value.address!.location!.latitude ?? 0.0,
              currentOrder.value.address!.location!.longitude ?? 0.0,
            );
            setOsmMapMarker();
            fetchRoute(current.value, destination.value).then((value) {
              setOsmMapMarker();
            });
            animateToSource();
          }
        } else {
          print("====>5");
          current.value =
              location.LatLng(currentOrder.value.author!.location!.latitude ?? 0.0, currentOrder.value.author!.location!.longitude ?? 0.0);

          destination.value = location.LatLng(currentOrder.value.vendor!.latitude ?? 0.0, currentOrder.value.vendor!.longitude ?? 0.0);
          animateToSource();
          fetchRoute(current.value, destination.value).then((value) {
            setOsmMapMarker();
          });
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

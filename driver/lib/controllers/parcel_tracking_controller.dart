// import 'dart:async';
// import 'dart:convert';
// import 'dart:developer';
// import 'package:driver/constant/collection_name.dart';
// import 'package:driver/constant/constant.dart';
// import 'package:driver/constant/show_toast_dialog.dart';
// import 'package:driver/themes/app_them_data.dart';
// import 'package:driver/utils/fire_store_utils.dart';
// import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:latlong2/latlong.dart' as location;
// import 'package:flutter_map/flutter_map.dart' as flutterMap;
// import 'package:http/http.dart' as http;
// import '../models/parcel_order_model.dart';
// import '../models/user_model.dart';
// import 'package:flutter/material.dart';
//
// class ParcelTrackingController extends GetxController {
//   GoogleMapController? mapController;
//   final flutterMap.MapController osmMapController = flutterMap.MapController();
//
//   Rx<UserModel> driverUserModel = UserModel().obs;
//   Rx<ParcelOrderModel> orderModel = ParcelOrderModel().obs;
//   RxBool isLoading = true.obs;
//   RxString type = "parcelOrder".obs;
//
//   StreamSubscription? orderSubscription;
//   StreamSubscription? driverSubscription;
//
//   // Google Map markers & polylines
//   RxMap<MarkerId, Marker> markers = <MarkerId, Marker>{}.obs;
//   RxMap<PolylineId, Polyline> polyLines = <PolylineId, Polyline>{}.obs;
//
//   // OSM map markers & route
//   RxList<flutterMap.Marker> osmMarkers = <flutterMap.Marker>[].obs;
//   RxList<location.LatLng> routePoints = <location.LatLng>[].obs;
//
//   BitmapDescriptor? pickupIcon;
//   BitmapDescriptor? dropoffIcon;
//   BitmapDescriptor? driverIcon;
//
//   PolylinePoints polylinePoints = PolylinePoints(apiKey: Constant.mapAPIKey);
//
//   Rx<location.LatLng> source = location.LatLng(0.0, 0.0).obs;
//   Rx<location.LatLng> destination = location.LatLng(0.0, 0.0).obs;
//
//   @override
//   void onInit() {
//     super.onInit();
//     _loadIcons();
//     _initArguments();
//   }
//
//   @override
//   void onClose() {
//     orderSubscription?.cancel();
//     driverSubscription?.cancel();
//     ShowToastDialog.closeLoader();
//     super.onClose();
//   }
//
//   Future<void> _initArguments() async {
//     final args = Get.arguments;
//     if (args != null && args['parcelOrder'] != null) {
//       orderModel.value = args['parcelOrder'];
//       type.value = args['type'] ?? "parcelOrder";
//       _listenToOrder();
//     } else {
//       ShowToastDialog.showToast("Order data not found");
//       Get.back();
//     }
//   }
//
//   /// Listen to order and driver updates
//   void _listenToOrder() {
//     orderSubscription = FireStoreUtils.fireStore.collection(CollectionName.parcelOrders).doc(orderModel.value.id).snapshots().listen((event) {
//       if (event.data() != null) {
//         orderModel.value = ParcelOrderModel.fromJson(event.data()!);
//
//         // listen driver
//         if (orderModel.value.driverId != null) {
//           driverSubscription = FireStoreUtils.fireStore.collection(CollectionName.users).doc(orderModel.value.driverId).snapshots().listen((driverSnap) {
//             if (driverSnap.data() != null) {
//               driverUserModel.value = UserModel.fromJson(driverSnap.data()!);
//               _updateTracking();
//             }
//           });
//         }
//
//         if (orderModel.value.status == Constant.orderCompleted) {
//           Get.back();
//         }
//       }
//     });
//
//     isLoading.value = false;
//   }
//
//   void _updateTracking() {
//     if (Constant.selectedMapType == 'google') {
//       _updateGoogleMap();
//     } else {
//       _updateOsmMap();
//     }
//   }
//
//   void _updateGoogleMap() async {
//     final driverLat = driverUserModel.value.location?.latitude?.toDouble();
//     final driverLng = driverUserModel.value.location?.longitude?.toDouble();
//     if (driverLat == null || driverLng == null) return;
//
//     double? dstLat;
//     double? dstLng;
//
//     if (orderModel.value.status == Constant.driverAccepted) {
//       dstLat = orderModel.value.senderLatLong?.latitude?.toDouble();
//       dstLng = orderModel.value.senderLatLong?.longitude?.toDouble();
//     } else {
//       dstLat = orderModel.value.receiverLatLong?.latitude?.toDouble();
//       dstLng = orderModel.value.receiverLatLong?.longitude?.toDouble();
//     }
//
//     if (dstLat == null || dstLng == null) return;
//
//     final result = await polylinePoints.getRouteBetweenCoordinates(
//       request: PolylineRequest(
//         origin: PointLatLng(driverLat, driverLng),
//         destination: PointLatLng(dstLat, dstLng),
//         mode: TravelMode.driving,
//       ),
//     );
//
//     final List<LatLng> routeCoords = [];
//     for (var p in result.points) {
//       routeCoords.add(LatLng(p.latitude, p.longitude));
//     }
//
//     markers.clear();
//     polyLines.clear();
//
//     _addGoogleMarker(driverLat, driverLng, "Driver", driverIcon!);
//     _addGoogleMarker(orderModel.value.senderLatLong?.latitude?.toDouble(), orderModel.value.senderLatLong?.longitude?.toDouble(), "Pickup", pickupIcon!);
//     _addGoogleMarker(orderModel.value.receiverLatLong?.latitude?.toDouble(), orderModel.value.receiverLatLong?.longitude?.toDouble(), "Dropoff", dropoffIcon!);
//
//     if (routeCoords.isNotEmpty) {
//       PolylineId id = const PolylineId("route");
//       Polyline polyline = Polyline(
//         polylineId: id,
//         color: AppThemeData.primary300,
//         width: 6,
//         points: routeCoords,
//       );
//       polyLines[id] = polyline;
//     }
//
//     if (routeCoords.length >= 2) {
//       await _animateCameraBounds(routeCoords.first, routeCoords.last);
//     }
//
//     update();
//   }
//
//   void _addGoogleMarker(double? lat, double? lng, String id, BitmapDescriptor icon) {
//     if (lat == null || lng == null) return;
//     markers[MarkerId(id)] = Marker(
//       markerId: MarkerId(id),
//       position: LatLng(lat, lng),
//       icon: icon,
//     );
//   }
//
//   Future<void> _animateCameraBounds(LatLng src, LatLng dest) async {
//     if (mapController == null) return;
//
//     LatLngBounds bounds;
//     if (src.latitude > dest.latitude && src.longitude > dest.longitude) {
//       bounds = LatLngBounds(southwest: dest, northeast: src);
//     } else if (src.longitude > dest.longitude) {
//       bounds = LatLngBounds(southwest: LatLng(src.latitude, dest.longitude), northeast: LatLng(dest.latitude, src.longitude));
//     } else if (src.latitude > dest.latitude) {
//       bounds = LatLngBounds(southwest: LatLng(dest.latitude, src.longitude), northeast: LatLng(src.latitude, dest.longitude));
//     } else {
//       bounds = LatLngBounds(southwest: src, northeast: dest);
//     }
//
//     CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 60);
//     await mapController?.animateCamera(cameraUpdate);
//   }
//
//   void _updateOsmMap() async {
//     final driverLat = driverUserModel.value.location?.latitude?.toDouble() ?? 0.0;
//     final driverLng = driverUserModel.value.location?.longitude?.toDouble() ?? 0.0;
//
//     double? dstLat;
//     double? dstLng;
//
//     if (orderModel.value.status == Constant.driverAccepted) {
//       dstLat = orderModel.value.senderLatLong?.latitude?.toDouble();
//       dstLng = orderModel.value.senderLatLong?.longitude?.toDouble();
//     } else {
//       dstLat = orderModel.value.receiverLatLong?.latitude?.toDouble();
//       dstLng = orderModel.value.receiverLatLong?.longitude?.toDouble();
//     }
//
//     if (dstLat == null || dstLng == null) return;
//
//     source.value = location.LatLng(driverLat, driverLng);
//     destination.value = location.LatLng(dstLat, dstLng);
//
//     await _fetchOsmRoute(source.value, destination.value);
//
//     // Update OSM markers
//     osmMarkers.clear();
//     osmMarkers.addAll([
//       flutterMap.Marker(
//         point: source.value,
//         width: 40,
//         height: 40,
//         child: Image.asset('assets/images/food_delivery.png', width: 40),
//       ),
//       flutterMap.Marker(
//         point: location.LatLng(
//           orderModel.value.senderLatLong?.latitude?.toDouble() ?? 0.0,
//           orderModel.value.senderLatLong?.longitude?.toDouble() ?? 0.0,
//         ),
//         width: 40,
//         height: 40,
//         child: Image.asset('assets/images/pickup.png', width: 40),
//       ),
//       flutterMap.Marker(
//         point: location.LatLng(
//           orderModel.value.receiverLatLong?.latitude?.toDouble() ?? 0.0,
//           orderModel.value.receiverLatLong?.longitude?.toDouble() ?? 0.0,
//         ),
//         width: 40,
//         height: 40,
//         child: Image.asset('assets/images/dropoff.png', width: 40),
//       ),
//     ]);
//
//     osmMapController.move(source.value, 14);
//     update();
//   }
//
//   Future<void> _fetchOsmRoute(location.LatLng src, location.LatLng dest) async {
//     try {
//       final url =
//           Uri.parse('https://router.project-osrm.org/route/v1/driving/${src.longitude},${src.latitude};${dest.longitude},${dest.latitude}?overview=full&geometries=geojson');
//       final response = await http.get(url);
//       if (response.statusCode == 200) {
//         final decoded = json.decode(response.body);
//         final geometry = decoded['routes'][0]['geometry']['coordinates'];
//         routePoints.clear();
//         for (var coord in geometry) {
//           final lon = coord[0];
//           final lat = coord[1];
//           routePoints.add(location.LatLng(lat, lon));
//         }
//       }
//     } catch (e) {
//       log("Error fetching OSM route: $e");
//     }
//   }
//
//   Future<void> _loadIcons() async {
//     if (Constant.selectedMapType == 'google') {
//       pickupIcon = BitmapDescriptor.fromBytes(await Constant().getBytesFromAsset('assets/images/pickup.png', 100));
//       dropoffIcon = BitmapDescriptor.fromBytes(await Constant().getBytesFromAsset('assets/images/dropoff.png', 100));
//       driverIcon = BitmapDescriptor.fromBytes(await Constant().getBytesFromAsset('assets/images/food_delivery.png', 80));
//     }
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as location;
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../models/parcel_order_model.dart';
import '../models/user_model.dart';

class ParcelTrackingController extends GetxController {
  GoogleMapController? mapController;
  final flutterMap.MapController osmMapController = flutterMap.MapController();

  Rx<UserModel> driverUserModel = UserModel().obs;
  Rx<ParcelOrderModel> orderModel = ParcelOrderModel().obs;
  RxBool isLoading = true.obs;
  RxString type = "parcelOrder".obs;

  StreamSubscription? orderSubscription;
  StreamSubscription? driverSubscription;

  // Google Maps
  RxMap<MarkerId, Marker> markers = <MarkerId, Marker>{}.obs;
  RxMap<PolylineId, Polyline> polyLines = <PolylineId, Polyline>{}.obs;

  // OSM Map
  RxList<flutterMap.Marker> osmMarkers = <flutterMap.Marker>[].obs;
  RxList<location.LatLng> routePoints = <location.LatLng>[].obs;

  BitmapDescriptor? pickupIcon;
  BitmapDescriptor? dropoffIcon;
  BitmapDescriptor? driverIcon;

  PolylinePoints polylinePoints = PolylinePoints(apiKey: Constant.mapAPIKey);

  Rx<location.LatLng> source = location.LatLng(0.0, 0.0).obs;
  Rx<location.LatLng> destination = location.LatLng(0.0, 0.0).obs;

  @override
  void onInit() {
    super.onInit();
    _initArguments();
  }

  @override
  void onClose() {
    orderSubscription?.cancel();
    driverSubscription?.cancel();
    ShowToastDialog.closeLoader();
    super.onClose();
  }

  Future<void> _initArguments() async {
   await _loadIcons();

    final args = Get.arguments;
    if (args != null && args['parcelOrder'] != null) {
      orderModel.value = args['parcelOrder'];
      type.value = args['type'] ?? "parcelOrder";
      _listenToOrder();
    } else {
      ShowToastDialog.showToast("Order data not found");
      Get.back();
    }
   isLoading.value = false;
  }

  void _listenToOrder() {
    orderSubscription =
        FireStoreUtils.fireStore.collection(CollectionName.parcelOrders).doc(orderModel.value.id).snapshots().listen((event) {
      if (event.data() != null) {
        orderModel.value = ParcelOrderModel.fromJson(event.data()!);

        // Listen to driver updates
        if (orderModel.value.driverId != null) {
          driverSubscription =
              FireStoreUtils.fireStore.collection(CollectionName.users).doc(orderModel.value.driverId).snapshots().listen((driverSnap) {
            if (driverSnap.data() != null) {
              driverUserModel.value = UserModel.fromJson(driverSnap.data()!);
              _updateTracking();
            }
          });
        }

        if (orderModel.value.status == Constant.orderCompleted) {
          Get.back();
        }
      }
    });


  }

  void _updateTracking() {
    if (Constant.selectedMapType == 'google') {
      _updateGoogleMap();
    } else {
      _updateOsmMap();
    }
  }

  void _updateGoogleMap() async {
    final driverLat = driverUserModel.value.location?.latitude?.toDouble();
    final driverLng = driverUserModel.value.location?.longitude?.toDouble();
    if (driverLat == null || driverLng == null) return;

    double? dstLat;
    double? dstLng;

    // Decide destination based on order status
    if (orderModel.value.status == Constant.driverAccepted) {
      dstLat = orderModel.value.senderLatLong?.latitude?.toDouble();
      dstLng = orderModel.value.senderLatLong?.longitude?.toDouble();
    } else if ([Constant.orderInTransit].contains(orderModel.value.status)) {
      dstLat = orderModel.value.receiverLatLong?.latitude?.toDouble();
      dstLng = orderModel.value.receiverLatLong?.longitude?.toDouble();
    } else {
      return;
    }

    if (dstLat == null || dstLng == null) return;

    final result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(driverLat, driverLng),
        destination: PointLatLng(dstLat, dstLng),
        mode: TravelMode.driving,
      ),
    );

    final List<LatLng> routeCoords = [];
    for (var p in result.points) {
      routeCoords.add(LatLng(p.latitude, p.longitude));
    }

    markers.clear();
    polyLines.clear();

    // Add markers
    _addGoogleMarker(driverLat, driverLng, "Driver", driverIcon!);
    if (orderModel.value.status == Constant.driverAccepted) {
      _addGoogleMarker(orderModel.value.senderLatLong?.latitude?.toDouble(), orderModel.value.senderLatLong?.longitude?.toDouble(),
          "Pickup", pickupIcon!);
    } else {
      _addGoogleMarker(orderModel.value.receiverLatLong?.latitude?.toDouble(), orderModel.value.receiverLatLong?.longitude?.toDouble(),
          "Dropoff", dropoffIcon!);
    }

    // Add polyline
    if (routeCoords.isNotEmpty) {
      PolylineId id = const PolylineId("route");
      Polyline polyline = Polyline(
        polylineId: id,
        color: AppThemeData.primary300,
        width: 6,
        points: routeCoords,
      );
      polyLines[id] = polyline;
    }

    if (routeCoords.length >= 2) {
      await _animateCameraBounds(routeCoords.first, routeCoords.last);
    }

    update();
  }

  void _addGoogleMarker(double? lat, double? lng, String id, BitmapDescriptor icon) {
    if (lat == null || lng == null) return;
    markers[MarkerId(id)] = Marker(
      markerId: MarkerId(id),
      position: LatLng(lat, lng),
      icon: icon,
    );
  }

  Future<void> _animateCameraBounds(LatLng src, LatLng dest) async {
    if (mapController == null) return;

    LatLngBounds bounds;
    if (src.latitude > dest.latitude && src.longitude > dest.longitude) {
      bounds = LatLngBounds(southwest: dest, northeast: src);
    } else if (src.longitude > dest.longitude) {
      bounds = LatLngBounds(southwest: LatLng(src.latitude, dest.longitude), northeast: LatLng(dest.latitude, src.longitude));
    } else if (src.latitude > dest.latitude) {
      bounds = LatLngBounds(southwest: LatLng(dest.latitude, src.longitude), northeast: LatLng(src.latitude, dest.longitude));
    } else {
      bounds = LatLngBounds(southwest: src, northeast: dest);
    }

    CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 60);
    await mapController?.animateCamera(cameraUpdate);
  }

  void _updateOsmMap() async {
    final driverLat = driverUserModel.value.location?.latitude?.toDouble() ?? 0.0;
    final driverLng = driverUserModel.value.location?.longitude?.toDouble() ?? 0.0;

    double? dstLat;
    double? dstLng;

    if (orderModel.value.status == Constant.driverAccepted) {
      dstLat = orderModel.value.senderLatLong?.latitude?.toDouble();
      dstLng = orderModel.value.senderLatLong?.longitude?.toDouble();
    } else if ([Constant.orderInTransit].contains(orderModel.value.status)) {
      dstLat = orderModel.value.receiverLatLong?.latitude?.toDouble();
      dstLng = orderModel.value.receiverLatLong?.longitude?.toDouble();
    } else {
      return;
    }

    if (dstLat == null || dstLng == null) return;

    source.value = location.LatLng(driverLat, driverLng);
    destination.value = location.LatLng(dstLat, dstLng);

    await _fetchOsmRoute(source.value, destination.value);

    // Update OSM markers
    osmMarkers.clear();
    osmMarkers.add(
      flutterMap.Marker(
        point: source.value,
        width: 40,
        height: 40,
        child: CachedNetworkImage(
          width: 50,
          height: 50,
          imageUrl: Constant.sectionModelFor(orderModel.value.sectionId)!.markerIcon.toString(),
          placeholder: (context, url) => Constant.loader(),
          errorWidget: (context, url, error) => SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );

    if (orderModel.value.status == Constant.driverAccepted) {
      osmMarkers.add(
        flutterMap.Marker(
          point: location.LatLng(
            orderModel.value.senderLatLong?.latitude?.toDouble() ?? 0.0,
            orderModel.value.senderLatLong?.longitude?.toDouble() ?? 0.0,
          ),
          width: 40,
          height: 40,
          child: Image.asset('assets/images/pickup.png', width: 40),
        ),
      );
    } else {
      osmMarkers.add(
        flutterMap.Marker(
          point: location.LatLng(
            orderModel.value.receiverLatLong?.latitude?.toDouble() ?? 0.0,
            orderModel.value.receiverLatLong?.longitude?.toDouble() ?? 0.0,
          ),
          width: 40,
          height: 40,
          child: Image.asset('assets/images/dropoff.png', width: 40),
        ),
      );
    }

    osmMapController.move(source.value, 14);
    update();
  }

  Future<void> _fetchOsmRoute(location.LatLng src, location.LatLng dest) async {
    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${src.longitude},${src.latitude};${dest.longitude},${dest.latitude}?overview=full&geometries=geojson');
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
      }
    } catch (e) {
      log("Error fetching OSM route: $e");
    }
  }

  Future<void> _loadIcons() async {
    if (Constant.selectedMapType == 'google') {
      pickupIcon = BitmapDescriptor.fromBytes(await Constant().getBytesFromAsset('assets/images/pickup.png', 100));
      dropoffIcon = BitmapDescriptor.fromBytes(await Constant().getBytesFromAsset('assets/images/dropoff.png', 100));
      driverIcon = BitmapDescriptor.fromBytes(Constant.sectionModelFor(orderModel.value.sectionId)?.markerIcon == null || Constant.sectionModelFor(orderModel.value.sectionId)?.markerIcon?.isEmpty == true
          ? await Constant().getBytesFromAsset('assets/images/ic_cab.png', 50)
          : await Constant().getBytesFromUrl(Constant.sectionModelFor(orderModel.value.sectionId)!.markerIcon.toString(), width: 120));
    }
  }
}

// import 'dart:async';
// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:driver/constant/collection_name.dart';
// import 'package:driver/constant/constant.dart';
// import 'package:driver/constant/show_toast_dialog.dart';
// import 'package:driver/themes/app_them_data.dart';
// import 'package:driver/utils/fire_store_utils.dart';
// import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:latlong2/latlong.dart' as location;
// import 'package:flutter_map/flutter_map.dart' as flutterMap;
// import 'package:http/http.dart' as http;
// import '../models/parcel_order_model.dart';
// import '../models/user_model.dart';
//
// class ParcelTrackingController extends GetxController {
//   GoogleMapController? mapController;
//
//   Rx<UserModel> driverUserModel = UserModel().obs;
//   Rx<ParcelOrderModel> orderModel = ParcelOrderModel().obs;
//
//   RxBool isLoading = true.obs;
//   RxString type = "".obs;
//
//   StreamSubscription? orderSubscription;
//   StreamSubscription? driverSubscription;
//
//   RxMap<MarkerId, Marker> markers = <MarkerId, Marker>{}.obs;
//   RxMap<PolylineId, Polyline> polyLines = <PolylineId, Polyline>{}.obs;
//
//   BitmapDescriptor? departureIcon;
//   BitmapDescriptor? destinationIcon;
//   BitmapDescriptor? driverIcon;
//
//   PolylinePoints polylinePoints = PolylinePoints(apiKey: Constant.mapAPIKey);
//
//   // OSM
//   final flutterMap.MapController osmMapController = flutterMap.MapController();
//   Rx<location.LatLng> source = location.LatLng(0.0, 0.0).obs;
//   Rx<location.LatLng> destination = location.LatLng(0.0, 0.0).obs;
//   RxList<location.LatLng> routePoints = <location.LatLng>[].obs;
//
//   @override
//   void onInit() {
//     addMarkerSetup();
//     getArgument();
//     super.onInit();
//   }
//
//   @override
//   void onClose() {
//     orderSubscription?.cancel();
//     driverSubscription?.cancel();
//     ShowToastDialog.closeLoader();
//     super.onClose();
//   }
//
//   Future<void> getArgument() async {
//     dynamic argumentData = Get.arguments;
//     if (argumentData != null) {
//       type.value = argumentData['type'] ?? "parcelOrder";
//       if (type.value == "parcelOrder") {
//         ParcelOrderModel argumentOrderModel = argumentData['parcelOrder'];
//
//         /// Listen to Order
//         orderSubscription = FireStoreUtils.fireStore.collection(CollectionName.parcelOrders).doc(argumentOrderModel.id).snapshots().listen((event) {
//           if (event.data() != null) {
//             orderModel.value = ParcelOrderModel.fromJson(event.data()!);
//
//             /// Listen to Driver Live Location
//             driverSubscription = FireStoreUtils.fireStore.collection(CollectionName.users).doc(orderModel.value.driverId).snapshots().listen((event) {
//               if (event.data() != null) {
//                 driverUserModel.value = UserModel.fromJson(event.data()!);
//
//                 /// Update Map (Google or OSM)
//                 _updateTracking();
//               }
//             });
//
//             if (orderModel.value.status == Constant.orderCompleted) {
//               Get.back();
//             }
//           }
//         });
//       }
//     }
//     isLoading.value = false;
//     update();
//   }
//
//   /// Update Tracking depending on order status
//   void _updateTracking() {
//     if (Constant.selectedMapType == 'google') {
//       _updateGoogleMap();
//     } else {
//       _updateOsmMap();
//     }
//   }
//
//   ///Google Map Route
//   void _updateGoogleMap() async {
//     double? srcLat = driverUserModel.value.location?.latitude?.toDouble();
//     double? srcLng = driverUserModel.value.location?.longitude?.toDouble();
//
//     double? dstLat;
//     double? dstLng;
//
//     if (orderModel.value.status == Constant.driverAccepted) {
//       // Driver → Pickup
//       dstLat = orderModel.value.senderLatLong?.latitude?.toDouble();
//       dstLng = orderModel.value.senderLatLong?.longitude?.toDouble();
//     } else {
//       // Pickup → Destination
//       dstLat = orderModel.value.receiverLatLong?.latitude?.toDouble();
//       dstLng = orderModel.value.receiverLatLong?.longitude?.toDouble();
//     }
//
//     if (srcLat == null || srcLng == null || dstLat == null || dstLng == null) return;
//
//     // Get Polyline
//     List<LatLng> polylineCoordinates = [];
//     PolylineRequest polylineRequest = PolylineRequest(
//       origin: PointLatLng(srcLat, srcLng),
//       destination: PointLatLng(dstLat, dstLng),
//       mode: TravelMode.driving,
//     );
//
//     PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
//       request: polylineRequest,
//     );
//
//     polylineCoordinates.clear();
//     if (result.points.isNotEmpty) {
//       for (var point in result.points) {
//         polylineCoordinates.add(LatLng(point.latitude, point.longitude));
//       }
//     }
//
//     // Add Markers
//     markers.clear();
//     addMarker(
//       latitude: orderModel.value.senderLatLong?.latitude?.toDouble(),
//       longitude: orderModel.value.senderLatLong?.longitude?.toDouble(),
//       id: "Pickup",
//       descriptor: departureIcon!,
//       rotation: 0.0,
//     );
//     addMarker(
//       latitude: orderModel.value.receiverLatLong?.latitude?.toDouble(),
//       longitude: orderModel.value.receiverLatLong?.longitude?.toDouble(),
//       id: "Dropoff",
//       descriptor: destinationIcon!,
//       rotation: 0.0,
//     );
//     addMarker(
//       latitude: srcLat,
//       longitude: srcLng,
//       id: "Driver",
//       descriptor: driverIcon!,
//       rotation: driverUserModel.value.rotation?.toDouble() ?? 0.0,
//     );
//
//     // Add Polyline
//     polyLines.clear();
//     _addPolyLine(polylineCoordinates);
//   }
//
//   ///OSM Route
//   void _updateOsmMap() async {
//     source.value = location.LatLng(
//       driverUserModel.value.location?.latitude?.toDouble() ?? 0.0,
//       driverUserModel.value.location?.longitude?.toDouble() ?? 0.0,
//     );
//
//     if (orderModel.value.status == Constant.driverAccepted) {
//       destination.value = location.LatLng(
//         orderModel.value.senderLatLong?.latitude?.toDouble() ?? 0.0,
//         orderModel.value.senderLatLong?.longitude?.toDouble() ?? 0.0,
//       );
//     } else {
//       destination.value = location.LatLng(
//         orderModel.value.receiverLatLong?.latitude?.toDouble() ?? 0.0,
//         orderModel.value.receiverLatLong?.longitude?.toDouble() ?? 0.0,
//       );
//     }
//
//     await fetchRoute(source.value, destination.value);
//     animateToSource();
//   }
//
//   /// Google Add Marker
//   void addMarker({
//     required double? latitude,
//     required double? longitude,
//     required String id,
//     required BitmapDescriptor descriptor,
//     required double? rotation,
//   }) {
//     MarkerId markerId = MarkerId(id);
//     Marker marker = Marker(
//       markerId: markerId,
//       icon: descriptor,
//       position: LatLng(latitude ?? 0.0, longitude ?? 0.0),
//       rotation: rotation ?? 0.0,
//     );
//     markers[markerId] = marker;
//   }
//
//   /// Setup Marker Icons
//   Future<void> addMarkerSetup() async {
//     if (Constant.selectedMapType == 'google') {
//       final Uint8List pickup = await Constant().getBytesFromAsset('assets/images/pickup.png', 100);
//       final Uint8List dropoff = await Constant().getBytesFromAsset('assets/images/dropoff.png', 100);
//       final Uint8List driver = await Constant().getBytesFromAsset('assets/images/food_delivery.png', 60);
//       departureIcon = BitmapDescriptor.fromBytes(pickup);
//       destinationIcon = BitmapDescriptor.fromBytes(dropoff);
//       driverIcon = BitmapDescriptor.fromBytes(driver);
//     }
//   }
//
//   /// Google Add Polyline
//   void _addPolyLine(List<LatLng> polylineCoordinates) {
//     if (polylineCoordinates.isEmpty) return;
//     PolylineId id = const PolylineId("poly");
//     Polyline polyline = Polyline(
//       polylineId: id,
//       points: polylineCoordinates,
//       width: 6,
//       color: AppThemeData.primary300,
//     );
//     polyLines[id] = polyline;
//     updateCameraLocation(polylineCoordinates.first, polylineCoordinates.last, mapController);
//   }
//
//   Future<void> updateCameraLocation(
//     LatLng source,
//     LatLng destination,
//     GoogleMapController? mapController,
//   ) async {
//     if (mapController == null) return;
//
//     LatLngBounds bounds;
//     if (source.latitude > destination.latitude && source.longitude > destination.longitude) {
//       bounds = LatLngBounds(southwest: destination, northeast: source);
//     } else if (source.longitude > destination.longitude) {
//       bounds = LatLngBounds(southwest: LatLng(source.latitude, destination.longitude), northeast: LatLng(destination.latitude, source.longitude));
//     } else if (source.latitude > destination.latitude) {
//       bounds = LatLngBounds(southwest: LatLng(destination.latitude, source.longitude), northeast: LatLng(source.latitude, destination.longitude));
//     } else {
//       bounds = LatLngBounds(southwest: source, northeast: destination);
//     }
//
//     CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 50);
//     await mapController.animateCamera(cameraUpdate);
//   }
//
//   /// OSM Fetch Route
//   Future<void> fetchRoute(location.LatLng source, location.LatLng destination) async {
//     final url = Uri.parse(
//       'https://router.project-osrm.org/route/v1/driving/${source.longitude},${source.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson',
//     );
//     final response = await http.get(url);
//     if (response.statusCode == 200) {
//       final decoded = json.decode(response.body);
//       final geometry = decoded['routes'][0]['geometry']['coordinates'];
//       routePoints.clear();
//       for (var coord in geometry) {
//         final lon = coord[0];
//         final lat = coord[1];
//         routePoints.add(location.LatLng(lat, lon));
//       }
//     }
//   }
//
//   void animateToSource() {
//     osmMapController.move(source.value, 16);
//   }
// }

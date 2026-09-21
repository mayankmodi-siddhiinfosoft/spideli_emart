import 'dart:async';
import 'package:driver/app/owner_screen/driver_order_list.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/round_button_fill.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:latlong2/latlong.dart' as latLng2;

class DriverLocationController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<UserModel> driverList = <UserModel>[].obs;
  RxSet<Marker> markers = <Marker>{}.obs;

  /// OSM map data
  final flutterMap.MapController osmMapController = flutterMap.MapController();
  RxList<flutterMap.Marker> osmMarkers = <flutterMap.Marker>[].obs;
  Rx<latLng2.LatLng> current = const latLng2.LatLng(12.9716, 77.5946).obs;

  BitmapDescriptor? driverIcon;
  final Completer<GoogleMapController> mapController = Completer();

  @override
  void onInit() {
    super.onInit();
    getDriverList();
  }

  Future<void> getDriverList() async {
    isLoading.value = true;
    await _loadDriverIcon();

    FireStoreUtils.fireStore.collection(CollectionName.users).where("ownerId", isEqualTo: FireStoreUtils.getCurrentUid()).where("isOwner", isEqualTo: false).snapshots().listen((event) {
      driverList.value = event.docs.map((e) => UserModel.fromJson(e.data())).toList();
      updateMarkers();
    });

    isLoading.value = false;
  }

  Future<void> _loadDriverIcon() async {
    final Uint8List driverBytes = await Constant().getBytesFromAsset('assets/images/ic_cab.png', 70);
    driverIcon = BitmapDescriptor.fromBytes(driverBytes);
  }

  /// Update both Google Map + OSM markers
  void updateMarkers() {
    final newMarkers = <Marker>{};
    final newOsmMarkers = <flutterMap.Marker>[];

    for (var driver in driverList) {
      final lat = driver.location?.latitude;
      final lng = driver.location?.longitude;
      if (lat != null && lng != null) {
        // Google Map Marker
        newMarkers.add(
          Marker(
            markerId: MarkerId(driver.id ?? ''),
            position: LatLng(lat, lng),
            rotation: double.tryParse(driver.rotation.toString()) ?? 0,
            anchor: const Offset(0.5, 0.5),
            flat: true,
            icon: driverIcon ?? BitmapDescriptor.defaultMarker,
            onTap: () => _showDriverBottomSheet(Get.context!, driver),
          ),
        );

        // OSM Marker
        newOsmMarkers.add(flutterMap.Marker(
          point: latLng2.LatLng(lat, lng),
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () => _showDriverBottomSheet(Get.context!, driver),
            child: Image.asset('assets/images/ic_cab.png', width: 45),
          ),
        ));
      }
    }

    // ignore: invalid_use_of_protected_member
    markers.value = newMarkers;
    osmMarkers.value = newOsmMarkers;

    if (driverList.isNotEmpty) {
      final first = driverList.first;
      if (first.location != null) {
        current.value = latLng2.LatLng(first.location!.latitude!, first.location!.longitude!);
      }
    }
  }

  /// Show driver bottom sheet
  void _showDriverBottomSheet(BuildContext context, UserModel driver) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  ClipOval(
                    child: NetworkImageWidget(
                      imageUrl: driver.profilePictureURL ?? "",
                      height: 55,
                      width: 55,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(driver.fullName(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("Email: ${driver.email ?? '-'}"),
                        Text("Phone: ${driver.countryCode ?? ''} ${driver.phoneNumber ?? ''}"),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: RoundedButtonFill(
                      title: "Call".tr,
                      height: 5,
                      width: 100,
                      borderRadius: 10,
                      color: AppThemeData.primary300,
                      textColor: AppThemeData.grey50,
                      onPress: () async {
                        Constant.makePhoneCall(driver.phoneNumber.toString());
                      },
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: RoundedButtonFill(
                      title: "View Booking".tr,
                      height: 5,
                      width: 100,
                      borderRadius: 10,
                      color: AppThemeData.driverApp300,
                      textColor: AppThemeData.grey50,
                      onPress: () async {
                        Get.to(DriverOrderList(), arguments: {
                          "driverId": driver.id,
                          "serviceType": driver.serviceTypes?.first,
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  /// Move camera for Google Map
  Future<void> moveCameraToFirstDriver(GoogleMapController mapController) async {
    if (driverList.isNotEmpty) {
      final firstDriver = driverList.first;
      if (firstDriver.location?.latitude != null && firstDriver.location?.longitude != null) {
        final position = CameraPosition(
          target: LatLng(firstDriver.location!.latitude!, firstDriver.location!.longitude!),
          zoom: 15,
        );
        await mapController.animateCamera(CameraUpdate.newCameraPosition(position));
      }
    }
  }

  /// Animate OSM map
  void animateToSource() {
    if (driverList.isNotEmpty && driverList.first.location != null) {
      osmMapController.move(
        latLng2.LatLng(driverList.first.location!.latitude!, driverList.first.location!.longitude!),
        14.5,
      );
    }
  }
}

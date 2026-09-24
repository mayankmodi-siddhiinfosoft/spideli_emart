import 'dart:io';
import 'package:driver/constant/constant.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as location;
import '../../controllers/parcel_tracking_controller.dart';
import '../../themes/app_them_data.dart';

/// Live parcel map (archetype C, map only): the map stays edge-to-edge under a
/// transparent DS app bar; markers, polylines and the controller are untouched.
class ParcelTrackingScreen extends StatelessWidget {
  const ParcelTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<ParcelTrackingController>(
      init: ParcelTrackingController(),
      builder: (controller) {
        final c = context.dsColors;
        return DsScaffold(
          backgroundColor: c.background,
          maxContentWidth: null,
          appBar: DsAppBar(
            title: "Map view".tr,
            onBack: () {
              Get.back();
            },
          ),
          body: controller.isLoading.value
              ? Constant.loader()
              : Constant.selectedMapType == 'osm'
                  ? flutterMap.FlutterMap(
                      mapController: controller.osmMapController,
                      options: flutterMap.MapOptions(
                        initialCenter: location.LatLng(Constant.userModel?.location?.latitude ?? 45.521563, Constant.userModel?.location?.longitude ?? -122.677433),
                        initialZoom: 10,
                      ),
                      children: [
                        flutterMap.TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: Platform.isAndroid ? 'com.spideli.driver' : 'com.spideli.driver',
                        ),
                        flutterMap.MarkerLayer(markers: controller.osmMarkers),
                        if (controller.routePoints.isNotEmpty)
                          flutterMap.PolylineLayer(
                            polylines: [
                              flutterMap.Polyline(
                                points: controller.routePoints,
                                strokeWidth: 5.0,
                                color: AppThemeData.primary300,
                              ),
                            ],
                          ),
                      ],
                    )
                  : Obx(
                      () => GoogleMap(
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        mapType: MapType.terrain,
                        zoomControlsEnabled: false,
                        polylines: Set<Polyline>.of(controller.polyLines.values),
                        padding: const EdgeInsets.only(
                          top: 22.0,
                        ),
                        markers: Set<Marker>.of(controller.markers.values),
                        onMapCreated: (GoogleMapController mapController) {
                          controller.mapController = mapController;
                        },
                        initialCameraPosition: CameraPosition(
                          zoom: 15,
                          target: LatLng(
                            Constant.userModel?.location?.latitude ?? 45.521563,
                            Constant.userModel?.location?.longitude ?? -122.677433,
                          ),
                        ),
                      ),
                    ),
        );
      },
    );
  }
}

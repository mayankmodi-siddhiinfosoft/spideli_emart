import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/driver_location_controller.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Map screen (archetype A): edge-to-edge map, DS app bar only. The map,
/// its controllers and markers are untouched.
class DriverLocationScreen extends StatelessWidget {
  const DriverLocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
        init: DriverLocationController(),
        builder: (controller) {
          final c = context.dsColors;
          return Scaffold(
            backgroundColor: c.background,
            appBar: DsAppBar(
              title: "Driver Locations",
              subtitle: controller.driverList.isEmpty ? null : '${controller.driverList.length} ${'Drivers'.tr}',
            ),
            body: controller.isLoading.value
                ? Constant.loader()
                : Constant.selectedMapType == "osm"
                    ? Obx(() {
                        // Schedule a post-frame callback to ensure the FlutterMap has been built
                        // before we attempt to move the map to the driver's location.
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          try {
                            controller.animateToSource();
                          } catch (_) {}
                        });

                        return flutterMap.FlutterMap(
                          mapController: controller.osmMapController,
                          options: flutterMap.MapOptions(
                            // center the OSM map on the controller's current position (updated by controller)
                            initialCenter: controller.current.value,
                            initialZoom: 12,
                          ),
                          children: [
                            flutterMap.TileLayer(
                              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                              subdomains: const ['a', 'b', 'c'],
                              userAgentPackageName: 'com.spideli.app',
                            ),
                            flutterMap.MarkerLayer(markers: controller.osmMarkers),
                          ],
                        );
                      })
                    : GoogleMap(
                        initialCameraPosition: controller.driverList.isNotEmpty
                            ? CameraPosition(
                                target: LatLng(controller.driverList.first.location == null ? 12.9716 : controller.driverList.first.location!.latitude!,
                                    controller.driverList.first.location == null ? 77.5946 : controller.driverList.first.location!.longitude!),
                                zoom: 14,
                              )
                            : CameraPosition(
                                target: LatLng(12.9716, 77.5946),
                                zoom: 14,
                              ),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        markers: controller.markers.toSet(),
                        onMapCreated: (GoogleMapController mapController) {
                          controller.mapController.complete(mapController);
                          // Wait for markers to load
                          Future.delayed(const Duration(milliseconds: 500), () async {
                            await controller.moveCameraToFirstDriver(mapController);
                          });
                        },
                      ),
          );
        });
  }
}

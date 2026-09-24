import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/live_tracking_controller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;

/// Archetype D — live map. The map stays edge to edge and untouched; the
/// chrome floats above it as a glass header instead of an opaque app bar.
class LiveTrackingScreen extends StatelessWidget {
  const LiveTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<LiveTrackingController>(
      init: LiveTrackingController(),
      builder: (controller) {
        if (controller.isLoading.value) {
          return DsScaffold(body: Constant.loader());
        }

        final c = context.dsColors;
        final t = context.dsText;

        return DsScaffold(
          maxContentWidth: null,
          backgroundColor: c.surface,
          body: Stack(
            children: [
              Positioned.fill(
                child: Constant.selectedMapType == 'osm'
                    ? flutterMap.FlutterMap(
                        mapController: controller.osmMapController,
                        options: flutterMap.MapOptions(initialCenter: controller.driverCurrent.value, initialZoom: 14),
                        children: [
                          flutterMap.TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.spideli.customer'),
                          if (controller.routePoints.isNotEmpty) flutterMap.PolylineLayer(polylines: [flutterMap.Polyline(points: controller.routePoints, strokeWidth: 5.0, color: Colors.blue)]),
                          flutterMap.MarkerLayer(markers: controller.orderModel.value.id == null ? [] : controller.osmMarkers),
                        ],
                      )
                    : gmap.GoogleMap(
                        onMapCreated: (gmap.GoogleMapController mapController) {
                          controller.mapController = mapController;
                        },
                        myLocationEnabled: true,
                        zoomControlsEnabled: false,
                        polylines: Set<gmap.Polyline>.of(controller.polyLines.values),
                        markers: Set<gmap.Marker>.of(controller.markers.values),
                        initialCameraPosition: gmap.CameraPosition(
                          zoom: 14,
                          target: gmap.LatLng(controller.driverUserModel.value.location?.latitude ?? 0.0, controller.driverUserModel.value.location?.longitude ?? 0.0),
                        ),
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(DsSpace.md),
                  child: Row(
                    children: [
                      const DsBackButton(variant: DsIconButtonVariant.filled),
                      const DsGap(DsSpace.md),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
                          decoration: BoxDecoration(color: c.surface, borderRadius: DsRadius.brPill, boxShadow: DsShadows.md(context)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.near_me_rounded, size: 18, color: c.brandStrong),
                              const DsGap(DsSpace.sm),
                              Flexible(child: Text("Live Tracking".tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

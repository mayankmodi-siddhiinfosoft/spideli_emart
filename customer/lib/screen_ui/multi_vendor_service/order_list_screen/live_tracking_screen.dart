import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/live_tracking_controller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;

import '../../widgets/order_ui.dart';

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
                // The map opens on the first point we actually have (driver,
                // then store, then the delivery address) instead of lat/lng
                // 0,0, and the camera is only driven once the map says it is
                // ready — see LiveTrackingController for bug #4.
                child: controller.isOsm
                    ? flutterMap.FlutterMap(
                        mapController: controller.osmMapController,
                        options: flutterMap.MapOptions(
                          initialCenter: controller.initialTarget,
                          initialZoom: 14,
                          onMapReady: controller.onOsmMapReady,
                        ),
                        children: [
                          flutterMap.TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.spideli.customer'),
                          if (controller.routePoints.isNotEmpty)
                            flutterMap.PolylineLayer(polylines: [flutterMap.Polyline(points: controller.routePoints.toList(), strokeWidth: 5.0, color: Colors.blue)]),
                          // Read through toList() so this GetX observer is
                          // subscribed to the marker list itself.
                          flutterMap.MarkerLayer(markers: controller.osmMarkers.toList()),
                        ],
                      )
                    : gmap.GoogleMap(
                        onMapCreated: controller.onGoogleMapCreated,
                        myLocationEnabled: true,
                        zoomControlsEnabled: false,
                        polylines: Set<gmap.Polyline>.of(controller.polyLines.values),
                        markers: Set<gmap.Marker>.of(controller.markers.values),
                        initialCameraPosition: gmap.CameraPosition(
                          zoom: 14,
                          target: gmap.LatLng(controller.initialTarget.latitude, controller.initialTarget.longitude),
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
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Live Tracking".tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                                    // Same short, never-wrapping id as the list
                                    // and the detail screen.
                                    OrderIdLine(id: controller.orderModel.value.id.toString(), compact: true, copyable: false),
                                  ],
                                ),
                              ),
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

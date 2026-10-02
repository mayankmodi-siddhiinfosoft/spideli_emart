import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as osm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as ll;
import 'package:vendor/constant/constant.dart';
import 'package:vendor/themes/ds/ds.dart';

/// A small, non-interactive map with a pin on the store's picked position, so
/// the vendor can see where the store will be placed (report 02#2). Uses the
/// map provider the app is configured for (`Constant.selectedMapType`); the
/// address and coordinates are shown as text next to it either way, so a map
/// that cannot draw (key restrictions, offline) never hides the position.
class StoreLocationPreview extends StatelessWidget {
  final double latitude;
  final double longitude;
  final double height;

  const StoreLocationPreview({super.key, required this.latitude, required this.longitude, this.height = 140});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return ClipRRect(
      borderRadius: DsRadius.brMd,
      child: SizedBox(
        height: height,
        width: double.infinity,
        // Taps and drags go to the form's scroll view, not the map: this is a
        // preview; the picker is where the position is changed.
        child: IgnorePointer(
          child: Constant.selectedMapType == 'osm' ? _osm(c.brand) : _google(),
        ),
      ),
    );
  }

  Widget _google() {
    final gmaps.LatLng point = gmaps.LatLng(latitude, longitude);
    return gmaps.GoogleMap(
      // A new key per point: initialCameraPosition is only read once.
      key: ValueKey('store-preview-$latitude,$longitude'),
      initialCameraPosition: gmaps.CameraPosition(target: point, zoom: 15),
      liteModeEnabled: true,
      markers: {gmaps.Marker(markerId: const gmaps.MarkerId('store'), position: point)},
      zoomControlsEnabled: false,
      zoomGesturesEnabled: false,
      scrollGesturesEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
    );
  }

  Widget _osm(Color pin) {
    final ll.LatLng point = ll.LatLng(latitude, longitude);
    return osm.FlutterMap(
      key: ValueKey('store-preview-osm-$latitude,$longitude'),
      options: osm.MapOptions(initialCenter: point, initialZoom: 15, interactionOptions: const osm.InteractionOptions(flags: osm.InteractiveFlag.none)),
      children: [
        osm.TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: 'com.spideli.store'),
        osm.MarkerLayer(
          markers: [
            osm.Marker(point: point, width: 40, height: 40, alignment: Alignment.topCenter, child: Icon(Icons.location_on_rounded, size: 40, color: pin)),
          ],
        ),
      ],
    );
  }
}

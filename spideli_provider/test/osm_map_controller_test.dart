import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:spideliprovider/widgets/osm_map/map_controller.dart';
import 'package:spideliprovider/widgets/osm_map/place_model.dart';

/// Report 02#27: the OSM picker applies network / GPS answers only while they
/// still match the user's last action, so "Confirm Location" returns the
/// point on the map.
void main() {
  const LatLng device = LatLng(3.80, 11.50);
  const LatLng tsinga = LatLng(3.88, 11.50);
  const LatLng pointB = LatLng(3.85, 11.52);

  final Map<LatLng, Completer<String>> geocodes = {};
  final Map<String, Completer<List<PlaceModel>?>> searches = {};
  late Completer<LatLng?> gps;

  OSMMapController controller() {
    geocodes.clear();
    searches.clear();
    gps = Completer<LatLng?>();
    return OSMMapController(
      reverseGeocode: (c) => (geocodes[c] = Completer<String>()).future,
      search: (q) => (searches[q] = Completer<List<PlaceModel>?>()).future,
      locate: () => gps.future,
    );
  }

  test('a late GPS fix does not replace a selected search result', () async {
    final c = controller();
    final Future<void> locating = c.getCurrentLocation();
    c.selectSearchResult(PlaceModel(coordinates: tsinga, address: 'Tsinga'));
    gps.complete(device);
    await locating;
    expect(c.pickedPlace.value?.coordinates, tsinga);
    expect(c.pickedPlace.value?.address, 'Tsinga');
    expect(geocodes, isEmpty);
  });

  test('a late GPS fix does not replace a tapped point', () async {
    final c = controller();
    final Future<void> locating = c.getCurrentLocation();
    c.addLatLngOnly(pointB);
    gps.complete(device);
    await locating;
    expect(c.pickedPlace.value?.coordinates, pointB);
  });

  test('without any user action the GPS fix picks the device', () async {
    final c = controller();
    final Future<void> locating = c.getCurrentLocation();
    gps.complete(device);
    await locating;
    expect(c.pickedPlace.value?.coordinates, device);
    geocodes[device]!.complete('Mvog-Ada, Yaoundé');
    await pumpEventQueue();
    expect(c.pickedPlace.value?.address, 'Mvog-Ada, Yaoundé');
  });

  test('a tapped point is picked at once, before its address arrives', () async {
    final c = controller();
    c.addLatLngOnly(device);
    geocodes[device]!.complete('A');
    await pumpEventQueue();
    c.addLatLngOnly(pointB);
    expect(c.pickedPlace.value?.coordinates, pointB);
    expect(c.pickedPlace.value?.address, '');
  });

  test('an address that arrives after the user moved on is dropped', () async {
    final c = controller();
    c.addLatLngOnly(device);
    c.addLatLngOnly(pointB);
    geocodes[device]!.complete('Address of A');
    await pumpEventQueue();
    expect(c.pickedPlace.value?.coordinates, pointB);
    expect(c.pickedPlace.value?.address, '');
    geocodes[pointB]!.complete('Address of B');
    await pumpEventQueue();
    expect(c.pickedPlace.value?.coordinates, pointB);
    expect(c.pickedPlace.value?.address, 'Address of B');
  });

  test('an address that arrives after Clear is dropped', () async {
    final c = controller();
    c.addLatLngOnly(pointB);
    c.clearAll();
    geocodes[pointB]!.complete('Address of B');
    await pumpEventQueue();
    expect(c.pickedPlace.value, isNull);
  });

  test('only the latest query fills the result list', () async {
    final c = controller();
    final Future<void> first = c.searchPlace('Tsi');
    final Future<void> second = c.searchPlace('Tsinga');
    searches['Tsinga']!.complete([PlaceModel(coordinates: tsinga, address: 'Tsinga')]);
    await second;
    searches['Tsi']!.complete([PlaceModel(coordinates: device, address: 'Tsi...')]);
    await first;
    expect(c.searchResults.map((p) => p.address), ['Tsinga']);
  });

  test('a late answer never re-opens the list after a result was selected', () async {
    final c = controller();
    final Future<void> pending = c.searchPlace('Tsinga');
    c.selectSearchResult(PlaceModel(coordinates: tsinga, address: 'Tsinga'));
    searches['Tsinga']!.complete([PlaceModel(coordinates: tsinga, address: 'Tsinga')]);
    await pending;
    expect(c.searchResults, isEmpty);
    expect(c.pickedPlace.value?.address, 'Tsinga');
  });

  test('a short query clears the list and drops older answers', () async {
    final c = controller();
    final Future<void> pending = c.searchPlace('Tsinga');
    await c.searchPlace('Ts');
    searches['Tsinga']!.complete([PlaceModel(coordinates: tsinga, address: 'Tsinga')]);
    await pending;
    expect(c.searchResults, isEmpty);
  });

  test('a failed search keeps the list as it is', () async {
    final c = controller();
    final Future<void> pending = c.searchPlace('Tsinga');
    searches['Tsinga']!.complete(null);
    await pending;
    expect(c.searchResults, isEmpty);
  });
}

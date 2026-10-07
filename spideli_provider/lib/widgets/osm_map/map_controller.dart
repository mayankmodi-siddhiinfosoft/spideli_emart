import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:spideliprovider/utils/address_format.dart';
import 'package:spideliprovider/utils/utils.dart';
import 'package:spideliprovider/widgets/osm_map/place_model.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// OSM location picker (worker / service forms, report 02#27).
///
/// Network and GPS answers arrive in any order, so each one is applied only
/// while it still matches what the user did last:
/// - a picked point is stored at once (address ''), and its reverse-geocoded
///   address is filled in only if that same pick is still the current one, so
///   "Confirm Location" always returns the point on the map;
/// - the start-up GPS fix centres the map and picks the device only if the
///   user has not tapped, searched or cleared yet;
/// - a search answer is shown only for the latest query, and never after a
///   result was selected.
class OSMMapController extends GetxController {
  OSMMapController({
    Future<String> Function(LatLng coords)? reverseGeocode,
    Future<List<PlaceModel>?> Function(String query)? search,
    Future<LatLng?> Function()? locate,
  })  : _reverseGeocode = reverseGeocode ?? _nominatimReverse,
        _search = search ?? _nominatimSearch,
        _locate = locate ?? _deviceLocation;

  final Future<String> Function(LatLng coords) _reverseGeocode;
  final Future<List<PlaceModel>?> Function(String query) _search;
  final Future<LatLng?> Function() _locate;

  final mapController = MapController();

  // Store only one picked place instead of multiple
  var pickedPlace = Rxn<PlaceModel>(); // Use Rxn to hold a nullable value
  RxList<PlaceModel> searchResults = <PlaceModel>[].obs;

  /// The user tapped, searched or cleared: the start-up GPS fix no longer
  /// moves the map or replaces their pick.
  bool _userInteracted = false;

  /// Incremented by every search and by a selection; an answer is applied
  /// only while its own number is still the latest.
  int _searchSeq = 0;

  Future<void> searchPlace(String query) async {
    final int seq = ++_searchSeq;
    if (query.trim().isNotEmpty) _userInteracted = true;
    if (query.trim().length < 3) {
      searchResults.clear();
      return;
    }
    List<PlaceModel>? results;
    try {
      results = await _search(query.trim());
    } catch (e) {
      log('OSM search failed: $e');
    }
    if (seq != _searchSeq || results == null) return;
    searchResults.value = results;
  }

  void selectSearchResult(PlaceModel place) {
    _userInteracted = true;
    // Drops the answers of searches still in flight.
    _searchSeq++;
    // Store only the selected place
    pickedPlace.value = place;
    searchResults.clear();
  }

  /// A point tapped on the map.
  void addLatLngOnly(LatLng coords) {
    _userInteracted = true;
    unawaited(_pickPoint(coords));
  }

  /// Stores [coords] at once (Confirm returns it even before the address
  /// arrives; the form then shows the coordinates), then fills in the address
  /// only if this pick is still the current one.
  Future<void> _pickPoint(LatLng coords) async {
    final PlaceModel pick = PlaceModel(coordinates: coords, address: '');
    pickedPlace.value = pick;
    try {
      final String address = await _reverseGeocode(coords);
      if (address.isEmpty || !identical(pickedPlace.value, pick)) return;
      pickedPlace.value = PlaceModel(coordinates: coords, address: address);
    } catch (e) {
      log('OSM reverse geocode failed: $e');
    }
  }

  void clearAll() {
    _userInteracted = true;
    pickedPlace.value = null; // Clear the selected place
  }

  @override
  void onInit() {
    super.onInit();
    getCurrentLocation();
  }

  /// Centres on the device and picks it, unless the user already tapped,
  /// searched or cleared while the fix was coming. A refused permission or a
  /// map not rendered yet used to throw out of onInit; the picker now simply
  /// keeps its default centre and lets the user tap a point.
  Future<void> getCurrentLocation() async {
    try {
      final LatLng? latlng = await _locate();
      if (latlng == null || _userInteracted) return;
      unawaited(_pickPoint(latlng));
      mapController.move(latlng, mapController.camera.zoom);
    } catch (e) {
      log('OSM picker: current location unavailable: $e');
    }
  }

  static const Map<String, String> _headers = {'User-Agent': 'FlutterMapApp/1.0 (menil.siddhiinfosoft@gmail.com)'};

  /// Nominatim search; null when the request failed (the shown list is then
  /// kept as it is).
  static Future<List<PlaceModel>?> _nominatimSearch(String query) async {
    // Query encoded as a parameter (an "&" or "#" in the text used to break
    // the request) and every failure contained: this runs on each keystroke.
    final url = Uri.https('nominatim.openstreetmap.org', '/search', {'q': query, 'format': 'json', 'addressdetails': '1', 'limit': '10'});
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body);
      return data is List ? data.map(PlaceModel.fromNominatim).whereType<PlaceModel>().toList() : <PlaceModel>[];
    } catch (e) {
      log('OSM search failed: $e');
      return null;
    }
  }

  /// Reverse geocode; '' when nothing usable came back (the picker then shows
  /// the coordinates only, and the form falls back to them).
  static Future<String> _nominatimReverse(LatLng coords) async {
    final url = Uri.https('nominatim.openstreetmap.org', '/reverse', {'lat': '${coords.latitude}', 'lon': '${coords.longitude}', 'format': 'json'});
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode != 200) return '';
      final data = json.decode(response.body);
      return data is Map ? formatAddressText(data['display_name']) : '';
    } catch (e) {
      log('OSM reverse geocode failed: $e');
      return '';
    }
  }

  static Future<LatLng?> _deviceLocation() async {
    final Position? location = await Utils.getCurrentLocation();
    return location == null ? null : LatLng(location.latitude, location.longitude);
  }
}

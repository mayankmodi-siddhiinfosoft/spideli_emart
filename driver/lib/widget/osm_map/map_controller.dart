import 'dart:convert';
import 'dart:developer';

import 'package:driver/utils/address_format.dart';
import 'package:driver/widget/osm_map/place_model.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../utils/utils.dart';
import 'package:latlong2/latlong.dart';

class OSMMapController extends GetxController {
  final mapController = MapController();
  // Store only one picked place instead of multiple
  var pickedPlace = Rxn<PlaceModel>(); // Use Rxn to hold a nullable value
  var searchResults = [].obs;

  Future<void> searchPlace(String query) async {
    if (query.length < 3) {
      searchResults.clear();
      return;
    }

    try {
      // The query is encoded as a parameter (a "#" or "&" in it broke the URL).
      final url = Uri.https('nominatim.openstreetmap.org', '/search', {'q': query, 'format': 'json', 'addressdetails': '1', 'limit': '10'});
      final response = await http.get(url, headers: {
        'User-Agent': 'FlutterMapApp/1.0 (menil.siddhiinfosoft@gmail.com)',
      });
      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        searchResults.value = data is List ? data : [];
      }
    } catch (e) {
      // Offline or a bad answer: the list stays as it was, nothing throws.
      log("OSMMapController search failed: $e");
    }
  }

  /// Picks a search result; null (nothing picked) when it has no usable
  /// coordinates.
  PlaceModel? selectSearchResult(dynamic place) {
    if (place is! Map) return null;
    // Nominatim sends the coordinates as text; a result without usable ones
    // is not picked rather than throwing in the tap handler.
    final double? lat = double.tryParse('${place['lat'] ?? ''}');
    final double? lon = double.tryParse('${place['lon'] ?? ''}');
    if (lat == null || lon == null || !lat.isFinite || !lon.isFinite) return null;
    // Client point 17 / 02#18: '' (never the word "null") when the result
    // has no name, and placeholder segments dropped.
    final String address = AddressFormat.clean(place['display_name']);

    // Store only the selected place
    final PlaceModel picked = PlaceModel(
      coordinates: LatLng(lat, lon),
      address: address,
    );
    pickedPlace.value = picked;
    searchResults.clear();
    return picked;
  }

  void addLatLngOnly(LatLng coords) async {
    final address = await _getAddressFromLatLng(coords);
    pickedPlace.value = PlaceModel(coordinates: coords, address: address);
  }

  /// The address of [coords], or `''` when there is none (report 02#27 /
  /// 02#18, as in the store and customer apps). It used to return the words
  /// "Unknown location", which the parcel search then used as the place's
  /// address, and a network failure escaped as an unhandled async error.
  Future<String> _getAddressFromLatLng(LatLng coords) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${coords.latitude}&lon=${coords.longitude}&format=json');
      final response = await http.get(url, headers: {
        'User-Agent': 'FlutterMapApp/1.0 (menil.siddhiinfosoft@gmail.com)',
      });
      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        if (data is Map) return AddressFormat.clean(data['display_name']);
      }
    } catch (e) {
      log("OSMMapController reverse geocoding failed: $e");
    }
    return '';
  }

  void clearAll() {
    pickedPlace.value = null; // Clear the selected place
  }

  @override
  void onInit() {
    // TODO: implement onInit
    super.onInit();
    getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
    Position? location = await Utils.getCurrentLocation();
    // No fix: nothing is pre-picked (it used to pick 0,0, a point in the Gulf
    // of Guinea the driver could confirm as a search location).
    if (location == null) return;
    final LatLng latlng = LatLng(location.latitude, location.longitude);
    addLatLngOnly(latlng);
    try {
      mapController.move(latlng, mapController.camera.zoom);
    } catch (e) {
      // The map is not laid out yet (or the page is gone): the pin is set.
      log("OSMMapController: could not move the map: $e");
    }
  }
}

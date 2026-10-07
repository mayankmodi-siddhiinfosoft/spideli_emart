import 'package:customer/constant/constant.dart';
import 'package:customer/utils/address_format.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';

class LocationController extends GetxController {
  GoogleMapController? mapController;
  var selectedLocation = Rxn<LatLng>();
  var selectedPlaceAddress = Rxn<Placemark>();
  var address = "Move the map to select a location".obs;
  TextEditingController searchController = TextEditingController();

  RxString zipCode = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // The map opens at once on the best position already known, so a
    // missing GPS fix or a refused location permission never leaves the
    // picker on an endless spinner (customers could not add an address).
    selectedLocation.value = _knownStartPosition();
    getArgument();
    getCurrentLocation();
  }

  /// Yaoundé: where the map opens when nothing better is known.
  static const LatLng fallbackCenter = LatLng(3.8480, 11.5021);

  LatLng _knownStartPosition() {
    final Position? device = Constant.currentLocation;
    if (device != null) return LatLng(device.latitude, device.longitude);
    final double? lat = Constant.selectedLocation.location?.latitude;
    final double? lng = Constant.selectedLocation.location?.longitude;
    if (lat != null && lng != null && !(lat == 0 && lng == 0)) return LatLng(lat, lng);
    return fallbackCenter;
  }

  void getArgument() {
    dynamic argumentData = Get.arguments;
    if (argumentData != null && argumentData is Map) {
      zipCode.value = argumentData['zipCode'] ?? '';
      if (zipCode.value.isNotEmpty) {
        getCoordinatesFromZipCode(zipCode.value);
      }
    }
    update();
  }

  /// Moves the map to the device's position when it can be had: the last
  /// known fix first (instant), then a fresh one within 10 s. Without
  /// permission or a fix the map simply stays where it opened; the customer
  /// can search or move the map.
  Future<void> getCurrentLocation() async {
    try {
      final LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        await getAddressFromLatLng(selectedLocation.value!);
        return;
      }
      final Position? last = await Geolocator.getLastKnownPosition();
      if (last != null) _moveTo(LatLng(last.latitude, last.longitude));
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      _moveTo(LatLng(position.latitude, position.longitude));
    } catch (e) {
      debugPrint("Current location unavailable: $e");
    }
    if (selectedLocation.value != null) await getAddressFromLatLng(selectedLocation.value!);
  }

  void _moveTo(LatLng position) {
    selectedLocation.value = position;
    mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
  }

  Future<void> getAddressFromLatLng(LatLng latLng) async {
    try {
      List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        selectedPlaceAddress.value = place;
        // Built from Placemark fields, any of which can be null — interpolating
        // them straight in is where the raw "null" in displayed addresses came
        // from (bug #17).
        address.value = formatAddressLine([place.street, place.locality, place.administrativeArea, place.country]);
      } else {
        address.value = "Address not found";
      }
    } catch (e) {
      print("Error getting address: $e");
      address.value = "Error getting address";
    }
  }

  void onMapMoved(CameraPosition position) {
    selectedLocation.value = position.target;
  }

  Future<void> getCoordinatesFromZipCode(String zipCode) async {
    try {
      List<Location> locations = await Geocoding().locationFromAddress(zipCode);
      if (locations.isNotEmpty) {
        selectedLocation.value = LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      print("Error getting coordinates for ZIP code: $e");
    }
  }

  void confirmLocation() {
    if (selectedLocation.value != null) {
      SelectedLocationModel selectedLocationModel = SelectedLocationModel(address: selectedPlaceAddress.value, latLng: selectedLocation.value);
      Get.back(result: selectedLocationModel);
    }
  }
}

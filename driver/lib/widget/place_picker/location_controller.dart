import 'package:driver/utils/address_format.dart';
import 'package:driver/widget/place_picker/selected_location_model.dart';
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
    getArgument();
    getCurrentLocation();
  }

  void getArgument() {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      zipCode.value = argumentData['zipCode'] ?? '';
      if (zipCode.value.isNotEmpty) {
        getCoordinatesFromZipCode(zipCode.value);
      }
    }
    update();
  }

  Future<void> getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      selectedLocation.value = LatLng(position.latitude, position.longitude);

      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(selectedLocation.value!, 15),
        );
      }

      await getAddressFromLatLng(selectedLocation.value!);
    } catch (e) {
      print("Error fetching current location: $e");
    }
  }

  Future<void> getAddressFromLatLng(LatLng latLng) async {
    try {
      List<Placemark> placemarks =
      await Geocoding().placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        selectedPlaceAddress.value = place;
        // Client point 17 at its source: interpolating the placemark fields
        // printed the literal word "null" for every part the geocoder did not
        // return, and this string is what gets SAVED — which is how
        // "123 Yaounde St, null, Tsinga" ends up in Firestore in the first
        // place. AddressFormat drops the blank parts and the separator each
        // one would have left behind.
        final String formatted = AddressFormat.join([place.street, place.locality, place.administrativeArea, place.country]);
        address.value = formatted.isEmpty ? "Address not found" : formatted;
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
        selectedLocation.value =
            LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      print("Error getting coordinates for ZIP code: $e");
    }
  }

  void confirmLocation() {
    if (selectedLocation.value != null) {
      SelectedLocationModel selectedLocationModel = SelectedLocationModel(
        address: selectedPlaceAddress.value,
        latLng: selectedLocation.value,
      );
      Get.back(result: selectedLocationModel);
    }
  }
}
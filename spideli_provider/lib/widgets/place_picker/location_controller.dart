import 'dart:developer';

import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/widgets/place_picker/selected_location_model.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';
import 'package:spideliprovider/utils/address_format.dart';

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
      log("Error fetching current location: $e");
    }
  }

  /// The point [selectedPlaceAddress] was geocoded for: Confirm returns that
  /// placemark only with that same point, never another point's address.
  LatLng? _addressFor;

  /// Geocodes [latLng]; an answer that arrives after the user moved to
  /// another point is dropped (the move geocodes its own point).
  Future<void> getAddressFromLatLng(LatLng latLng) async {
    try {
      List<Placemark> placemarks =
      await Geocoding().placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (selectedLocation.value != latLng) return;
      _addressFor = latLng;
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        selectedPlaceAddress.value = place;
        // Interpolating the placemark fields directly printed the word "null"
        // for every part the geocoder did not return.
        final String formatted = formatAddressParts(<Object?>[place.street, place.locality, place.administrativeArea, place.country]);
        address.value = formatted.isEmpty ? "Address not found".tr : formatted;
      } else {
        selectedPlaceAddress.value = null;
        address.value = "Address not found".tr;
      }
    } catch (e) {
      log("Error getting address: $e");
      if (selectedLocation.value != latLng) return;
      _addressFor = latLng;
      selectedPlaceAddress.value = null;
      address.value = "Error getting address".tr;
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
      log("Error getting coordinates for ZIP code: $e");
    }
  }

  /// Pops with the picked point. Confirming before a point exists used to do
  /// nothing at all; it now says why.
  void confirmLocation() {
    if (selectedLocation.value == null) {
      ShowToastDialog.showToast("Please select a location on the map".tr);
      return;
    }
    SelectedLocationModel selectedLocationModel = SelectedLocationModel(
      address: _addressFor == selectedLocation.value ? selectedPlaceAddress.value : null,
      latLng: selectedLocation.value,
    );
    Get.back(result: selectedLocationModel);
  }
}
import 'package:customer/constant/constant.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:map_launcher/map_launcher.dart';
import '../themes/show_toast_dialog.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as loc;

class Utils {
  static Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      await loc.Location().requestService();
      return null;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }

  static Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = "${place.name ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.country ?? ''}";
        return address;
      }
      return "Unknown location";
    } catch (e) {
      return "Unknown location";
    }
  }

  // map_launcher 6: isMapAvailable/showDirections replaced by a DirectionsRequest.
  // getSupportedMaps also returns maps reachable via universal link, so check isInstalled to keep the old "installed only" behaviour.
  static Future<bool> _isMapInstalled(MapApp map, DirectionsRequest request) async {
    final maps = await request.getSupportedMaps([map]);
    return maps.any((m) => m.map.id == map.id && m.isInstalled);
  }

  static Future<void> redirectMap({required String name, required double latitude, required double longLatitude}) async {
    final directions = MapLauncher.directions(LocationCoords(latitude, longLatitude, title: name), mode: TravelMode.driving);
    if (Constant.mapType == "google") {
      bool? isAvailable = await _isMapInstalled(MapApp.google, directions);
      if (isAvailable == true) {
        await directions.show(map: MapApp.google);
      } else {
        ShowToastDialog.showToast("Google map is not installed".tr);
      }
    } else if (Constant.mapType == "googleGo") {
      bool? isAvailable = await _isMapInstalled(MapApp.googleGo, directions);
      if (isAvailable == true) {
        await directions.show(map: MapApp.googleGo);
      } else {
        ShowToastDialog.showToast("Google Go map is not installed".tr);
      }
    } else if (Constant.mapType == "waze") {
      bool? isAvailable = await _isMapInstalled(MapApp.waze, directions);
      if (isAvailable == true) {
        await directions.show(map: MapApp.waze);
      } else {
        ShowToastDialog.showToast("Waze is not installed".tr);
      }
    } else if (Constant.mapType == "mapswithme") {
      bool? isAvailable = await _isMapInstalled(MapApp.mapswithme, directions);
      if (isAvailable == true) {
        await directions.show(map: MapApp.mapswithme);
      } else {
        ShowToastDialog.showToast("Mapswithme is not installed".tr);
      }
    } else if (Constant.mapType == "yandexNavi") {
      bool? isAvailable = await _isMapInstalled(MapApp.yandexNavi, directions);
      if (isAvailable == true) {
        await directions.show(map: MapApp.yandexNavi);
      } else {
        ShowToastDialog.showToast("YandexNavi is not installed".tr);
      }
    } else if (Constant.mapType == "yandexMaps") {
      bool? isAvailable = await _isMapInstalled(MapApp.yandexMaps, directions);
      if (isAvailable == true) {
        await directions.show(map: MapApp.yandexMaps);
      } else {
        ShowToastDialog.showToast("yandexMaps map is not installed".tr);
      }
    }
  }

  static String formatAddress({required SelectedLocationModel selectedLocation}) {
    List<String> parts = [];

    if (selectedLocation.address!.name != null && selectedLocation.address!.name!.isNotEmpty) parts.add(selectedLocation.address!.name!);
    if (selectedLocation.address!.subThoroughfare != null && selectedLocation.address!.subThoroughfare!.isNotEmpty) parts.add(selectedLocation.address!.subThoroughfare!);
    if (selectedLocation.address!.thoroughfare != null && selectedLocation.address!.thoroughfare!.isNotEmpty) parts.add(selectedLocation.address!.thoroughfare!);
    if (selectedLocation.address!.subLocality != null && selectedLocation.address!.subLocality!.isNotEmpty) parts.add(selectedLocation.address!.subLocality!);
    if (selectedLocation.address!.locality != null && selectedLocation.address!.locality!.isNotEmpty) parts.add(selectedLocation.address!.locality!);
    if (selectedLocation.address!.subAdministrativeArea != null && selectedLocation.address!.subAdministrativeArea!.isNotEmpty) {
      parts.add(selectedLocation.address!.subAdministrativeArea!);
    }
    if (selectedLocation.address!.administrativeArea != null && selectedLocation.address!.administrativeArea!.isNotEmpty) parts.add(selectedLocation.address!.administrativeArea!);
    if (selectedLocation.address!.postalCode != null && selectedLocation.address!.postalCode!.isNotEmpty) parts.add(selectedLocation.address!.postalCode!);
    if (selectedLocation.address!.country != null && selectedLocation.address!.country!.isNotEmpty) parts.add(selectedLocation.address!.country!);
    if (selectedLocation.address!.isoCountryCode != null && selectedLocation.address!.isoCountryCode!.isNotEmpty) parts.add(selectedLocation.address!.isoCountryCode!);

    return parts.join(', ');
  }
}

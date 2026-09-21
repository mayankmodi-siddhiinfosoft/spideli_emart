import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart';
import 'package:map_launcher/map_launcher.dart' hide Location;

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
      await Location().requestService();
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

  static Future<void> redirectMap({required String name, required double latitude, required double longLatitude}) async {
    if (Constant.mapType == "google") {
      await _openDirectionsIfInstalled(MapApp.google, name, latitude, longLatitude, "Google map is not installed");
    } else if (Constant.mapType == "googleGo") {
      await _openDirectionsIfInstalled(MapApp.googleGo, name, latitude, longLatitude, "Google Go map is not installed");
    } else if (Constant.mapType == "waze") {
      await _openDirectionsIfInstalled(MapApp.waze, name, latitude, longLatitude, "Waze is not installed");
    } else if (Constant.mapType == "mapswithme") {
      await _openDirectionsIfInstalled(MapApp.mapswithme, name, latitude, longLatitude, "Mapswithme is not installed");
    } else if (Constant.mapType == "yandexNavi") {
      await _openDirectionsIfInstalled(MapApp.yandexNavi, name, latitude, longLatitude, "YandexNavi is not installed");
    } else if (Constant.mapType == "yandexMaps") {
      await _openDirectionsIfInstalled(MapApp.yandexMaps, name, latitude, longLatitude, "yandexMaps map is not installed");
    }
  }

  // map_launcher 6: `isMapAvailable`/`showDirections` were replaced by a directions request.
  // Only launch when the app is installed natively (matches the old isMapAvailable check).
  static Future<void> _openDirectionsIfInstalled(MapApp map, String name, double latitude, double longLatitude, String notInstalledMessage) async {
    final request = MapLauncher.directions(LocationCoords(latitude, longLatitude, title: name), mode: TravelMode.driving);
    final supportedMaps = await request.getSupportedMaps([map]);
    final bool isAvailable = supportedMaps.any((element) => element.isInstalled);
    if (isAvailable == true) {
      await request.show(map: map);
    } else {
      ShowToastDialog.showToast(notInstalledMessage);
    }
  }
}

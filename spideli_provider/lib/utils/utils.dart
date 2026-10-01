import 'package:geocoding/geocoding.dart' show Placemark;
import 'package:spideliprovider/widgets/place_picker/selected_location_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart';
import 'package:spideliprovider/utils/address_format.dart';

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

  /// Human-readable address of a picked location.
  ///
  /// `address` is null whenever reverse geocoding gave nothing back (no
  /// network, no placemark for the point, or the platform threw) — the old
  /// `selectedLocation.address!` then blew up with a null-check error inside
  /// the picker callback and killed the calling screen. A missing placemark now
  /// yields an empty string, and [formatAddressParts] drops the empty and
  /// "null" pieces so nothing renders as "..., null, ...".
  static String formatAddress({required SelectedLocationModel selectedLocation}) {
    final Placemark? place = selectedLocation.address;
    if (place == null) return '';
    return formatAddressParts(<Object?>[
      place.name,
      place.subThoroughfare,
      place.thoroughfare,
      place.subLocality,
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea,
      place.postalCode,
      place.country,
      place.isoCountryCode,
    ]);
  }
}

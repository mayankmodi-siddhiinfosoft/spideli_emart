import 'package:customer/models/user_model.dart';
import 'package:customer/utils/utils.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Bug #17, write side: every map pick turns a reverse-geocoded [Placemark]
/// into the one address line that is then stored and shown.
///
/// Two things used to go wrong here, and both reached the client:
///
/// * the placemark is null whenever the lookup found nothing or could not run,
///   and `selectedLocation.address!` crashed on returning from the picker;
/// * a field the geocoder did not return has to disappear, not print.
Placemark placemark({
  String? name,
  String? subThoroughfare,
  String? thoroughfare,
  String? subLocality,
  String? locality,
  String? subAdministrativeArea,
  String? administrativeArea,
  String? postalCode,
  String? country,
  String? isoCountryCode,
}) => Placemark(
  name: name,
  subThoroughfare: subThoroughfare,
  thoroughfare: thoroughfare,
  subLocality: subLocality,
  locality: locality,
  subAdministrativeArea: subAdministrativeArea,
  administrativeArea: administrativeArea,
  postalCode: postalCode,
  country: country,
  isoCountryCode: isoCountryCode,
);

void main() {
  group('Utils.formatAddress', () {
    test('a place with no reverse-geocoded address is empty, not a crash', () {
      final value = SelectedLocationModel(latLng: const LatLng(3.848, 11.502));
      expect(Utils.formatAddress(selectedLocation: value), '');
    });

    test('the fields that came back are joined in the app\'s own order', () {
      final value = SelectedLocationModel(
        latLng: const LatLng(3.848, 11.502),
        address: placemark(name: '123', thoroughfare: 'Yaounde St', locality: 'Tsinga', administrativeArea: 'Centre', country: 'Cameroon'),
      );
      expect(Utils.formatAddress(selectedLocation: value), '123, Yaounde St, Tsinga, Centre, Cameroon');
    });

    test('a field the geocoder did not return leaves no gap and no "null"', () {
      final value = SelectedLocationModel(
        latLng: const LatLng(3.848, 11.502),
        address: placemark(name: '123 Yaounde St', subLocality: null, locality: 'Tsinga', postalCode: '', country: 'Cameroon'),
      );
      final line = Utils.formatAddress(selectedLocation: value);
      expect(line, '123 Yaounde St, Tsinga, Cameroon');
      expect(line.contains('null'), isFalse);
      expect(line.contains(', ,'), isFalse);
    });
  });

  group('home header (ShippingAddress.getFullAddress)', () {
    // The client's screenshot of the multivendor home header, exactly as the
    // old "use current location" code stored it in `locality`.
    test('the screenshot\'s stored text renders without "null"', () {
      final address = ShippingAddress(locality: '18, null, Yaoundé, Région du Centre, null, Cameroun');
      expect(address.getFullAddress(), '18, Yaoundé, Région du Centre, Cameroun');
    });

    test('"null" in any component, and missing components, leave no gap', () {
      final address = ShippingAddress(address: 'null', locality: '18, Yaoundé', landmark: null);
      expect(address.getFullAddress(), '18, Yaoundé');
    });
  });
}

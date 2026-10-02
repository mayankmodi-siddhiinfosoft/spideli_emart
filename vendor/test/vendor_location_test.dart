import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/models/vendor_model.dart';

void main() {
  group('VendorModel coordinates (report 02#2)', () {
    test('"" coordinates load as "not set" instead of throwing', () {
      final v = VendorModel.fromJson({'id': 's1', 'location': 'Yaoundé', 'latitude': '', 'longitude': ''});
      expect(v.latitude, isNull);
      expect(v.longitude, isNull);
      expect(v.hasLocation, isFalse);
      // Unrelated saves leave the stored "" alone (merge-fields skip the key).
      expect(v.toJson().containsKey('latitude'), isFalse);
      expect(v.toJson().containsKey('longitude'), isFalse);
    });

    test('missing / "null" / garbage / 0,0 are not a position', () {
      expect(VendorModel.fromJson({'id': 's'}).hasLocation, isFalse);
      expect(VendorModel.fromJson({'latitude': 'null', 'longitude': 'null'}).hasLocation, isFalse);
      expect(VendorModel.fromJson({'latitude': 'abc', 'longitude': '9.7'}).hasLocation, isFalse);
      expect(VendorModel.fromJson({'latitude': 0, 'longitude': 0}).hasLocation, isFalse);
    });

    test('panel strings and app numbers both parse', () {
      final s = VendorModel.fromJson({'latitude': ' 3.8667 ', 'longitude': '11.5167'});
      expect(s.latitude, closeTo(3.8667, 1e-9));
      expect(s.longitude, closeTo(11.5167, 1e-9));
      final n = VendorModel.fromJson({'latitude': 23.02, 'longitude': 72});
      expect(n.hasLocation, isTrue);
      expect(n.toJson()['latitude'], 23.02);
      expect(n.toJson()['longitude'], 72.0);
    });
  });
}

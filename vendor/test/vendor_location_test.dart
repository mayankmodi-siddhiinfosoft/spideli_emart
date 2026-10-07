import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/models/zone_model.dart';

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
      // Written back as strings, as the panels store them (report 02#2).
      expect(n.toJson()['latitude'], '23.02');
      expect(n.toJson()['longitude'], '72.0');
      final back = VendorModel.fromJson(n.toJson());
      expect(back.latitude, 23.02);
      expect(back.longitude, 72.0);
    });
  });

  group('one place pick fills every position field (report 02#2)', () {
    test('location, latitude / longitude (strings), coordinates and g agree', () {
      final v = VendorModel.fromJson({'id': 's1', 'location': 'Old place', 'latitude': '', 'longitude': ''});
      v.setPosition(address: 'Yaoundé, Cameroun', latitude: 3.8667, longitude: 11.5167);
      final json = v.toJson();
      expect(json['location'], 'Yaoundé, Cameroun');
      expect(json['latitude'], '3.8667');
      expect(json['longitude'], '11.5167');
      expect(json['coordinates'], const GeoPoint(3.8667, 11.5167));
      expect((json['g'] as Map)['geopoint'], const GeoPoint(3.8667, 11.5167));
      expect((json['g'] as Map)['geohash'], startsWith('s2'));
    });
  });

  group('tolerant coordinates on other records', () {
    test('an order address location stored as strings or ints parses', () {
      expect(UserLocation.fromJson({'latitude': '3.8', 'longitude': 11}).latitude, 3.8);
      expect(UserLocation.fromJson({'latitude': '3.8', 'longitude': 11}).longitude, 11.0);
      expect(UserLocation.fromJson({'latitude': '', 'longitude': 'null'}).latitude, isNull);
    });

    test('a zone centre stored as strings parses', () {
      final z = ZoneModel.fromJson({'latitude': '3.8', 'longitude': ''});
      expect(z.latitude, 3.8);
      expect(z.longitude, isNull);
    });
  });
}

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Report 02#2: `vendors.latitude` / `longitude` are strings, and three live
/// stores hold "" for both. Parsing must not throw, and such a store has no
/// position (no pin, no distance) instead of one at 0,0.
void main() {
  group('VendorModel position', () {
    test('string coordinates parse', () {
      final v = VendorModel.fromJson({'id': 'a', 'latitude': '3.8480', 'longitude': ' 11.5021 '});
      expect(v.hasPosition, isTrue);
      expect(v.latitude, closeTo(3.848, 1e-9));
      expect(v.longitude, closeTo(11.5021, 1e-9));
    });

    test('"" for both does not throw and has no position', () {
      final v = VendorModel.fromJson({'id': 'b', 'title': 'No pin', 'latitude': '', 'longitude': ''});
      expect(v.hasPosition, isFalse);
      expect(v.latitude, isNull);
      expect(v.longitude, isNull);
      expect(v.title, 'No pin');
    });

    test('missing, "null", NaN, out of range and 0,0 have no position', () {
      for (final json in <Map<String, dynamic>>[
        {},
        {'latitude': 'null', 'longitude': 'null'},
        {'latitude': 'NaN', 'longitude': '1'},
        {'latitude': '95', 'longitude': '1'},
        {'latitude': 0, 'longitude': 0},
        {'latitude': '3.8', 'longitude': ''},
      ]) {
        expect(VendorModel.fromJson({'id': 'x', ...json}).hasPosition, isFalse, reason: '$json');
      }
    });

    test('falls back to coordinates, then g.geopoint', () {
      expect(VendorModel.fromJson({'latitude': '', 'longitude': '', 'coordinates': const GeoPoint(3.8, 11.5)}).latitude, 3.8);
      final v = VendorModel.fromJson({
        'latitude': '',
        'longitude': '',
        'g': {'geohash': 's0', 'geopoint': const GeoPoint(4.05, 9.7)},
      });
      expect(v.latitude, 4.05);
      expect(v.longitude, 9.7);
    });

    test('the address is `location`; missing or "null" shows as empty', () {
      expect(VendorModel.fromJson({'location': '18, null, Yaoundé'}).locationText, '18, Yaoundé');
      expect(VendorModel.fromJson({}).locationText, '');
    });
  });

  group('Constant.getDistance', () {
    test('never throws on unparseable input', () {
      expect(Constant.getDistance(lat1: 'null', lng1: 'null', lat2: '3.8', lng2: '11.5'), '');
      expect(Constant.getDistance(lat1: '', lng1: '', lat2: '3.8', lng2: '11.5'), '');
      expect(Constant.distanceOrNull(lat1: null, lng1: 1, lat2: 2, lng2: 3), isNull);
    });

    test('still measures real points', () {
      expect(double.parse(Constant.getDistance(lat1: '3.8480', lng1: '11.5021', lat2: '3.8480', lng2: '11.5021')), 0);
      expect(Constant.distanceOrNull(lat1: 3.848, lng1: 11.502, lat2: 4.05, lng2: 9.7), greaterThan(100));
    });

    test('a store without a position has no distance label', () {
      expect(Constant.vendorDistanceLabel(VendorModel.fromJson({'latitude': '', 'longitude': ''})), isNull);
    });
  });
}

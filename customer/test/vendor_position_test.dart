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

  // The radius query cannot return a store with no geohash; those stores are
  // read separately and must pass the list's own filters, then come last.
  group('stores without a position stay listed', () {
    VendorModel store(String id, {String lat = '', String lng = ''}) => VendorModel.fromJson({'id': id, 'latitude': lat, 'longitude': lng});

    test('appended after the nearby stores, without duplicates', () {
      final nearby = [store('near1', lat: '3.84', lng: '11.50'), store('near2', lat: '3.85', lng: '11.51')];
      final unplaced = [store('none1'), store('near1'), store('none1'), store('none2')];
      expect(VendorModel.withUnplacedLast(nearby, unplaced).map((v) => v.id), ['near1', 'near2', 'none1', 'none2']);
    });

    test('a store that does have a position is left to the radius query', () {
      expect(VendorModel.withUnplacedLast([], [store('far', lat: '48.85', lng: '2.35')]), isEmpty);
    });

    test('nothing nearby still lists the unplaced stores', () {
      expect(VendorModel.withUnplacedLast([], [store('none1')]).map((v) => v.id), ['none1']);
    });

    test('held to the list filters: section, zone, category, dine-in', () {
      final data = <String, dynamic>{
        'section_id': 's1',
        'zoneId': 'z1',
        'categoryID': ['c1', 'c2'],
        'enabledDiveInFuture': true,
      };
      expect(VendorModel.matchesListFilters(data, sectionId: 's1', zoneId: 'z1', categoryId: 'c2', dineInOnly: true), isTrue);
      expect(VendorModel.matchesListFilters(data), isTrue);
      expect(VendorModel.matchesListFilters(data, sectionId: 's2'), isFalse);
      expect(VendorModel.matchesListFilters(data, zoneId: 'z2'), isFalse);
      expect(VendorModel.matchesListFilters(data, zoneId: ''), isFalse);
      expect(VendorModel.matchesListFilters(data, categoryId: 'c3'), isFalse);
      expect(VendorModel.matchesListFilters({...data, 'enabledDiveInFuture': false}, dineInOnly: true), isFalse);
      expect(VendorModel.matchesListFilters({'categoryID': 'c1'}, categoryId: 'c1'), isTrue);
    });
  });
}

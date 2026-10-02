import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/vendor_model.dart';
import 'package:driver/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// Report 02#2: `vendors.latitude` / `longitude` are strings, and three live
/// stores hold "" for both. `double.parse("")` threw in `VendorModel.fromJson`,
/// taking down every order (and order listener) holding such a store. Such a
/// store now has no position: no pin, no route, no distance, no directions to
/// 0,0 — the maps app searches its address instead.
void main() {
  group('VendorModel position', () {
    test('string coordinates parse', () {
      final v = VendorModel.fromJson({'id': 'a', 'latitude': '3.8480', 'longitude': ' 11.5021 '});
      expect(v.hasPosition, isTrue);
      expect(v.latitude, closeTo(3.848, 1e-9));
      expect(v.longitude, closeTo(11.5021, 1e-9));
    });

    test('"" for both does not throw and has no position', () {
      final v = VendorModel.fromJson({'id': 'b', 'title': 'No pin', 'location': 'Tsinga, Yaoundé', 'latitude': '', 'longitude': ''});
      expect(v.hasPosition, isFalse);
      expect(v.latitude, isNull);
      expect(v.longitude, isNull);
      expect(v.title, 'No pin');
    });

    test('missing, "null", NaN, out of range, half and 0,0 have no position', () {
      for (final json in <Map<String, dynamic>>[
        {},
        {'latitude': null, 'longitude': null},
        {'latitude': 'null', 'longitude': 'null'},
        {'latitude': 'NaN', 'longitude': '1'},
        {'latitude': '95', 'longitude': '1'},
        {'latitude': 0, 'longitude': 0},
        {'latitude': '0', 'longitude': '0.0'},
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

    test('a non-GeoPoint coordinates value does not throw', () {
      final v = VendorModel.fromJson({'latitude': '', 'longitude': '', 'coordinates': {'lat': 1}, 'g': {'geopoint': 'x'}});
      expect(v.hasPosition, isFalse);
    });

    test('toJson never writes null or a derived position over the stored one', () {
      final blank = VendorModel.fromJson({'latitude': '', 'longitude': '', 'coordinates': const GeoPoint(3.8, 11.5)}).toJson();
      expect(blank.containsKey('latitude'), isFalse);
      expect(blank.containsKey('longitude'), isFalse);
      expect(blank['coordinates'], const GeoPoint(3.8, 11.5));
      final real = VendorModel.fromJson({'latitude': '3.8480', 'longitude': '11.5021'}).toJson();
      expect(real['latitude'], closeTo(3.848, 1e-9));
      expect(real['longitude'], closeTo(11.5021, 1e-9));
    });

    test('an order holding a store without a position still reads', () {
      final order = OrderModel.fromJson({
        'id': 'o1',
        'status': 'Order Placed',
        'vendor': {'id': 'v', 'title': 'No pin', 'latitude': '', 'longitude': ''},
      });
      expect(order.vendor?.title, 'No pin');
      expect(order.vendor?.hasPosition, isFalse);
    });
  });

  group('Utils routing guards', () {
    test('isRoutable rejects missing, 0,0, NaN and out of range', () {
      expect(Utils.isRoutable(3.8, 11.5), isTrue);
      expect(Utils.isRoutable(null, 11.5), isFalse);
      expect(Utils.isRoutable(0, 0), isFalse);
      expect(Utils.isRoutable(double.nan, 1), isFalse);
      expect(Utils.isRoutable(91, 1), isFalse);
    });

    test('no distance to or from a point without a position', () {
      expect(Utils.distanceKm(null, null, 3.8, 11.5), isNull);
      expect(Utils.distanceKm(0, 0, 3.8, 11.5), isNull);
      expect(Utils.distanceKm(3.848, 11.502, 4.05, 9.7), greaterThan(100));
    });

    test('directions without a position search the cleaned address', () {
      final google = Utils.addressSearchUri('18, null, Yaoundé, Cameroun', mapType: 'google')!;
      expect(google.host, 'www.google.com');
      expect(google.queryParameters['query'], '18, Yaoundé, Cameroun');
      final waze = Utils.addressSearchUri('Tsinga', mapType: 'waze')!;
      expect(waze.host, 'waze.com');
      expect(waze.queryParameters['q'], 'Tsinga');
      expect(Utils.addressSearchUri('null, ', mapType: 'google'), isNull);
      expect(Utils.addressSearchUri(null), isNull);
    });
  });
}

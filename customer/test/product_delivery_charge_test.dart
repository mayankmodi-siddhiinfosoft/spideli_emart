import 'package:customer/models/product_model.dart';
import 'package:customer/models/section_model.dart';
import 'package:customer/utils/product_delivery_charge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Doc 60: product-level delivery charges (tier choice, max rule, parsing).
void main() {
  ProductDeliveryTier tier(num perKm, num min, num within) => ProductDeliveryTier(perKm: perKm.toDouble(), minCharge: min.toDouble(), withinKm: within.toDouble());

  group('parse', () {
    test('numbers and numeric strings', () {
      final tiers = ProductDeliveryTier.parseList([
        {'delivery_charges_per_km': 150, 'minimum_delivery_charges': 1500, 'minimum_delivery_charges_within_km': 5},
        {'delivery_charges_per_km': '200', 'minimum_delivery_charges': ' 3000.5 ', 'minimum_delivery_charges_within_km': '15'},
      ]);
      expect(tiers, [tier(150, 1500, 5), tier(200, 3000.5, 15)]);
    });

    test('null / not a list / junk entries give no tiers', () {
      expect(ProductDeliveryTier.parseList(null), isEmpty);
      expect(ProductDeliveryTier.parseList('x'), isEmpty);
      expect(ProductDeliveryTier.parseList(const []), isEmpty);
      expect(ProductDeliveryTier.parseList([1, 'a', null, {}, {'other': 3}]), isEmpty);
    });

    test('missing, unreadable or negative fields count as 0', () {
      final tiers = ProductDeliveryTier.parseList([
        {'minimum_delivery_charges': 500},
        {'delivery_charges_per_km': -4, 'minimum_delivery_charges': 'abc', 'minimum_delivery_charges_within_km': 'NaN'},
      ]);
      expect(tiers, [tier(0, 500, 0), tier(0, 0, 0)]);
    });

    test('ProductModel reads delivery_charges; toJson never writes them', () {
      final p = ProductModel.fromJson({
        'id': 'p1',
        'delivery_charges': [
          {'delivery_charges_per_km': 100, 'minimum_delivery_charges': 500, 'minimum_delivery_charges_within_km': 5},
        ],
      });
      expect(p.deliveryChargeTiers, [tier(100, 500, 5)]);
      expect(p.toJson().containsKey('delivery_charges'), isFalse);
      expect(ProductModel.fromJson({'id': 'p2'}).deliveryChargeTiers, isEmpty);
    });

    test('section flag: only true / "true" turns it on', () {
      expect(ProductDeliveryCharge.isEnabled(true), isTrue);
      expect(ProductDeliveryCharge.isEnabled('true'), isTrue);
      expect(ProductDeliveryCharge.isEnabled(' TRUE '), isTrue);
      for (final v in [false, null, 'false', 1, 'yes', const <String>[]]) {
        expect(ProductDeliveryCharge.isEnabled(v), isFalse, reason: '$v');
      }
      expect(SectionModel.fromJson({'id': 's', 'is_delivery_charge_customization': true}).isDeliveryChargeCustomization, isTrue);
      expect(SectionModel.fromJson({'id': 's'}).isDeliveryChargeCustomization, isFalse);
    });
  });

  group('single tier = the spec formula', () {
    final tiers = [tier(150, 1500, 5)];
    test('within the minimum distance -> minimum', () {
      expect(ProductDeliveryCharge.itemCharge(0, tiers), 1500);
      expect(ProductDeliveryCharge.itemCharge(3.2, tiers), 1500);
      expect(ProductDeliveryCharge.itemCharge(5, tiers), 1500); // boundary is inclusive
    });
    test('beyond it -> min + (d - within) * perKm', () {
      expect(ProductDeliveryCharge.itemCharge(7, tiers), 1500 + 2 * 150);
      expect(ProductDeliveryCharge.itemCharge(5.333, tiers), closeTo(1549.95, 0.001)); // rounded to 2 decimals
    });
  });

  group('several tiers', () {
    // Deliberately unsorted: the rule sorts by withinKm.
    final tiers = [tier(200, 3000, 15), tier(150, 1500, 5), tier(180, 2200, 10)];
    test('first tier whose withinKm >= distance gives its minimum', () {
      expect(ProductDeliveryCharge.itemCharge(2, tiers), 1500);
      expect(ProductDeliveryCharge.itemCharge(5, tiers), 1500);
      expect(ProductDeliveryCharge.itemCharge(5.01, tiers), 2200);
      expect(ProductDeliveryCharge.itemCharge(10, tiers), 2200);
      expect(ProductDeliveryCharge.itemCharge(12, tiers), 3000);
      expect(ProductDeliveryCharge.itemCharge(15, tiers), 3000);
    });
    test('beyond every tier: the largest tier plus its per-km rate', () {
      expect(ProductDeliveryCharge.itemCharge(20, tiers), 3000 + 5 * 200);
    });
  });

  group('distance edge cases', () {
    final tiers = [tier(100, 500, 5)];
    test('negative / NaN / infinite distance counts as 0 km', () {
      expect(ProductDeliveryCharge.itemCharge(-3, tiers), 500);
      expect(ProductDeliveryCharge.itemCharge(double.nan, tiers), 500);
      expect(ProductDeliveryCharge.itemCharge(double.infinity, tiers), 500);
    });
    test('a 0 km tier charges per km from the store', () {
      expect(ProductDeliveryCharge.itemCharge(3, [tier(100, 0, 0)]), 300);
      expect(ProductDeliveryCharge.itemCharge(0, [tier(100, 0, 0)]), 0);
    });
    test('haversine km', () {
      expect(ProductDeliveryCharge.haversineKm(3.848, 11.5021, 3.848, 11.5021), 0);
      // Yaoundé -> Douala ~ 196 km great-circle.
      expect(ProductDeliveryCharge.haversineKm(3.8480, 11.5021, 4.0511, 9.7679), closeTo(196, 3));
      // One degree of latitude ~ 111.19 km.
      expect(ProductDeliveryCharge.haversineKm(0, 0, 1, 0), closeTo(111.19, 0.01));
      expect(ProductDeliveryCharge.haversineKm(null, 0, 1, 0), isNull);
      expect(ProductDeliveryCharge.haversineKm(0, double.nan, 1, 0), isNull);
    });
  });

  group('order charge = maximum item charge', () {
    test('max, not sum', () {
      final heavy = [tier(150, 1500, 5)];
      final light = [tier(50, 300, 5)];
      expect(ProductDeliveryCharge.orderCharge(7, [heavy, light, light]), 1800);
      expect(ProductDeliveryCharge.orderCharge(7, [light, heavy]), 1800);
    });
    test('items without tiers are 0 and do not lower the max', () {
      expect(ProductDeliveryCharge.orderCharge(3, [const [], [tier(50, 300, 5)]]), 300);
    });
    test('no tiers anywhere / empty cart -> 0 (Free Delivery)', () {
      expect(ProductDeliveryCharge.orderCharge(3, [const [], const []]), 0);
      expect(ProductDeliveryCharge.orderCharge(3, const []), 0);
    });
  });
}

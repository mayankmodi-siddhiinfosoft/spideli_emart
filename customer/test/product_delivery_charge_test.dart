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

  group('order charge = sum of (product charge x quantity) (client rule 9 Oct)', () {
    ProductDeliveryLine line(double d, List<ProductDeliveryTier> tiers, int qty, {double? store}) => ProductDeliveryCharge.line(d, tiers, quantity: qty, storeCharge: store);

    test('each line is its per-piece charge times its quantity, summed', () {
      final heavy = [tier(150, 1500, 5)];
      final light = [tier(50, 300, 5)];
      // 7 km: heavy = 1500 + 2 x 150 = 1800, light = 300 + 2 x 50 = 400.
      final lines = [line(7, heavy, 2), line(7, light, 3)];
      expect(lines[0].total, 3600);
      expect(lines[1].total, 1200);
      expect(ProductDeliveryCharge.orderCharge(lines), 4800);
    });
    test('the rule applied is reported per line', () {
      final tiers = [tier(150, 1500, 5), tier(180, 2200, 10)];
      final within = line(7, tiers, 1);
      expect(within.rule, ProductDeliveryRule.minimum);
      expect(within.tier, tier(180, 2200, 10));
      expect(within.unitCharge, 2200);
      final beyond = line(12, tiers, 1);
      expect(beyond.rule, ProductDeliveryRule.perKm);
      expect(beyond.extraKm, 2);
      expect(beyond.unitCharge, 2200 + 2 * 180);
    });
    test('a product without tiers costs the store charge per piece', () {
      final lines = [line(3, const [], 2, store: 100), line(3, [tier(50, 30, 5)], 1, store: 100)];
      expect(lines[0].rule, ProductDeliveryRule.store);
      expect(lines[0].total, 200);
      expect(ProductDeliveryCharge.orderCharge(lines), 230);
    });
    test('no store charge -> an untiered product costs 0', () {
      final l = line(3, const [], 4);
      expect(l.rule, ProductDeliveryRule.none);
      expect(l.total, 0);
    });
    test('unusable store charge counts as 0', () {
      expect(line(3, const [], 2, store: double.nan).total, 0);
      expect(line(3, const [], 2, store: -5).total, 0);
    });
    test('no lines / zero quantity -> 0 (Free Delivery)', () {
      expect(ProductDeliveryCharge.orderCharge(const []), 0);
      expect(ProductDeliveryCharge.orderCharge([line(3, [tier(50, 300, 5)], 0)]), 0);
      expect(line(3, [tier(50, 300, 5)], -2).quantity, 0);
    });
    test('totals are rounded to 2 decimals', () {
      final lines = [line(5.333, [tier(150, 1500, 5)], 3)];
      expect(lines.single.unitCharge, closeTo(1549.95, 0.001));
      expect(ProductDeliveryCharge.orderCharge(lines), closeTo(4649.85, 0.001));
    });
  });
}

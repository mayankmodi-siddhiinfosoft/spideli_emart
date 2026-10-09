import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/app/product_screens/product_delivery_charges_section.dart';
import 'package:vendor/lang/app_ar.dart';
import 'package:vendor/lang/app_de.dart';
import 'package:vendor/lang/app_en.dart';
import 'package:vendor/lang/app_fr.dart';
import 'package:vendor/lang/app_hi.dart';
import 'package:vendor/lang/app_ja.dart';
import 'package:vendor/lang/app_pt.dart';
import 'package:vendor/lang/app_ru.dart';
import 'package:vendor/lang/app_zh.dart';
import 'package:vendor/models/product_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/product_delivery_charges.dart';

/// Bug point 60: product custom delivery charges in the Store app
/// (APP-SPEC-PRODUCT-DELIVERY-CHARGES §2-3).
void main() {
  ({String perKm, String minimumCharge, String withinKm}) row(String a, String b, String c) => (perKm: a, minimumCharge: b, withinKm: c);

  group('section flag', () {
    test('only an explicit true shows the editor', () {
      expect(ProductDeliveryCharges.isEnabledForSection({'is_delivery_charge_customization': true}), isTrue);
      expect(ProductDeliveryCharges.isEnabledForSection({'is_delivery_charge_customization': 'true'}), isTrue);
      expect(ProductDeliveryCharges.isEnabledForSection({'is_delivery_charge_customization': false}), isFalse);
      expect(ProductDeliveryCharges.isEnabledForSection({'is_delivery_charge_customization': 1}), isFalse);
      expect(ProductDeliveryCharges.isEnabledForSection({'serviceTypeFlag': 'ecommerce-service'}), isFalse, reason: 'missing');
      expect(ProductDeliveryCharges.isEnabledForSection(null), isFalse, reason: 'unreadable / no document');
    });
  });

  group('DeliveryChargeTier parse / serialize', () {
    test('numbers and numeric strings are read', () {
      final tiers = DeliveryChargeTier.parseList([
        {'delivery_charges_per_km': 150, 'minimum_delivery_charges': 1500, 'minimum_delivery_charges_within_km': 5},
        {'delivery_charges_per_km': '200.5', 'minimum_delivery_charges': ' 3000 ', 'minimum_delivery_charges_within_km': '7,25'},
      ]);
      expect(tiers, [
        const DeliveryChargeTier(deliveryChargesPerKm: 150, minimumDeliveryCharges: 1500, minimumDeliveryChargesWithinKm: 5),
        const DeliveryChargeTier(deliveryChargesPerKm: 200.5, minimumDeliveryCharges: 3000, minimumDeliveryChargesWithinKm: 7.25),
      ]);
    });

    test('junk is tolerated: non-lists, non-maps and empty entries are skipped, missing values read 0', () {
      expect(DeliveryChargeTier.parseList(null), isEmpty);
      expect(DeliveryChargeTier.parseList('abc'), isEmpty);
      expect(DeliveryChargeTier.parseList({'a': 1}), isEmpty);
      final tiers = DeliveryChargeTier.parseList([
        'x',
        42,
        {'delivery_charges_per_km': '', 'minimum_delivery_charges': null, 'minimum_delivery_charges_within_km': 'abc'},
        {'minimum_delivery_charges': 500},
      ]);
      expect(tiers, [const DeliveryChargeTier(deliveryChargesPerKm: 0, minimumDeliveryCharges: 500, minimumDeliveryChargesWithinKm: 0)]);
    });

    test('toJson writes numbers, whole doubles as ints', () {
      final json = const DeliveryChargeTier(deliveryChargesPerKm: 150.0, minimumDeliveryCharges: 1500, minimumDeliveryChargesWithinKm: 2.5).toJson();
      expect(json, {'delivery_charges_per_km': 150, 'minimum_delivery_charges': 1500, 'minimum_delivery_charges_within_km': 2.5});
      expect(json['delivery_charges_per_km'], isA<int>());
      expect(json.values.every((v) => v is num), isTrue);
    });

    test('ProductModel reads the field; absent stays null', () {
      final withTiers = ProductModel.fromJson({
        'delivery_charges': [
          {'delivery_charges_per_km': '100', 'minimum_delivery_charges': 500, 'minimum_delivery_charges_within_km': 5},
        ],
      });
      expect(withTiers.deliveryCharges, [const DeliveryChargeTier(deliveryChargesPerKm: 100, minimumDeliveryCharges: 500, minimumDeliveryChargesWithinKm: 5)]);
      expect(ProductModel.fromJson({}).deliveryCharges, isNull);
      expect(ProductModel.fromJson({'delivery_charges': []}).deliveryCharges, isEmpty);
    });

    test('a save that did not edit them leaves delivery_charges out of the write (field-preserving)', () {
      final product = ProductModel.fromJson({
        'id': 'p1',
        'delivery_charges': [
          {'delivery_charges_per_km': '100', 'minimum_delivery_charges': '500', 'minimum_delivery_charges_within_km': '5'},
        ],
      });
      product.publish = false; // e.g. the publish switch in the product list
      expect(product.toJson().containsKey('delivery_charges'), isFalse);
    });

    test('an edited save writes one charge as numbers; null clears the field (section flag off)', () {
      final product = ProductModel.fromJson({'id': 'p1'});
      product.deliveryCharges = [const DeliveryChargeTier(deliveryChargesPerKm: 150, minimumDeliveryCharges: 1500, minimumDeliveryChargesWithinKm: 5)];
      product.writeDeliveryCharges = true;
      expect(product.toJson()['delivery_charges'], [
        {'delivery_charges_per_km': 150, 'minimum_delivery_charges': 1500, 'minimum_delivery_charges_within_km': 5},
      ]);
      product.deliveryCharges = null;
      final json = product.toJson();
      expect(json.containsKey('delivery_charges'), isTrue);
      expect(json['delivery_charges'], isNull);
    });

    test('only one charge is ever written: the one with the smallest within-km', () {
      final product = ProductModel()
        ..deliveryCharges = const [
          DeliveryChargeTier(deliveryChargesPerKm: 180, minimumDeliveryCharges: 2200, minimumDeliveryChargesWithinKm: 10),
          DeliveryChargeTier(deliveryChargesPerKm: 150, minimumDeliveryCharges: 1500, minimumDeliveryChargesWithinKm: 5),
          DeliveryChargeTier(deliveryChargesPerKm: 200, minimumDeliveryCharges: 3000, minimumDeliveryChargesWithinKm: 15),
        ]
        ..writeDeliveryCharges = true;
      expect(product.toJson()['delivery_charges'], [
        {'delivery_charges_per_km': 150, 'minimum_delivery_charges': 1500, 'minimum_delivery_charges_within_km': 5},
      ]);
      expect(DeliveryChargeTier.maxTiers, 1);
    });

    test('a stored charge fills the single row in place', () {
      final input = DeliveryChargeTierInput();
      input.fill(const DeliveryChargeTier(deliveryChargesPerKm: 150, minimumDeliveryCharges: 1500, minimumDeliveryChargesWithinKm: 5));
      expect(input.values, row('150', '1500', '5'));
      input.dispose();
    });

    test('editor round trip: stored tier -> text fields -> validated tier', () {
      const tier = DeliveryChargeTier(deliveryChargesPerKm: 150, minimumDeliveryCharges: 1500.5, minimumDeliveryChargesWithinKm: 0);
      final input = DeliveryChargeTierInput.fromTier(tier);
      expect(input.values, row('150', '1500.5', '0'));
      expect(ProductDeliveryCharges.validate([input.values]).tiers, [tier]);
      input.dispose();
    });
  });

  group('validation on save (one charge, required)', () {
    test('a complete charge is valid; 0 and two decimals are allowed', () {
      final result = ProductDeliveryCharges.validate([row('0', '0.5', '12,75')]);
      expect(result.error, isNull);
      expect(result.tiers, [const DeliveryChargeTier(deliveryChargesPerKm: 0, minimumDeliveryCharges: 0.5, minimumDeliveryChargesWithinKm: 12.75)]);
    });

    test('no charge, or more than one, blocks the save', () {
      expect(ProductDeliveryCharges.validate([]).error, ProductDeliveryCharges.required);
      expect(ProductDeliveryCharges.validate([row('1', '1', '1'), row('1', '1', '1')]).error, ProductDeliveryCharges.required);
    });

    test('a blank, non-numeric or negative field blocks the save', () {
      for (final bad in [row('', '1500', '5'), row('150', ' ', '5'), row('150', '1500', ''), row('', '', ''), row('abc', '1', '1'), row('-1', '1', '1'), row('.', '1', '1')]) {
        final result = ProductDeliveryCharges.validate([bad]);
        expect(result.error, ProductDeliveryCharges.required, reason: '$bad');
        expect(result.tiers, isNull);
      }
      expect(ProductDeliveryCharges.required, 'Please enter the delivery charge: all 3 fields are required.');
    });
  });

  group('labels', () {
    test('the minimum charge label carries the store currency', () {
      expect(ProductDeliveryCharges.minimumChargeLabelWithCurrency('Minimum Delivery Charges', symbol: 'FCFA', code: 'XAF'), 'Minimum Delivery Charges (FCFA)');
      expect(ProductDeliveryCharges.minimumChargeLabelWithCurrency('Minimum Delivery Charges', symbol: '', code: 'XAF'), 'Minimum Delivery Charges (XAF)');
      expect(ProductDeliveryCharges.minimumChargeLabelWithCurrency('Minimum Delivery Charges'), 'Minimum Delivery Charges');
    });

    test('the input allows digits with at most two decimals', () {
      TextEditingValue apply(String oldText, String newText) =>
          ProductDeliveryCharges.inputFormatter.formatEditUpdate(TextEditingValue(text: oldText), TextEditingValue(text: newText));
      expect(apply('', '12.5').text, '12.5');
      expect(apply('12.5', '12.55').text, '12.55');
      expect(apply('12.55', '12.555').text, '12.55');
      expect(apply('12', '12,3').text, '12,3');
      expect(apply('12', '-12').text, '12');
      expect(apply('12', '12a').text, '12');
      expect(apply('12.5', '12.5.').text, '12.5');
    });

    test('every label is translated in all 9 languages', () {
      final maps = {'en': enUS, 'ar': lnAr, 'de': deGR, 'fr': trFR, 'hi': hiIN, 'ja': jaJP, 'pt': ptPO, 'ru': ruRU, 'zh': zhCH};
      for (final entry in maps.entries) {
        expect(ProductDeliveryCharges.translationKeys.where((k) => (entry.value[k] ?? '').trim().isEmpty), isEmpty, reason: entry.key);
        if (entry.key != 'en') {
          expect(ProductDeliveryCharges.translationKeys.where((k) => entry.value[k] == k), isEmpty, reason: '${entry.key} is translated');
        }
      }
    });
  });

  group('section widget', () {
    Future<void> pump(WidgetTester tester, DeliveryChargeTierInput input) {
      return tester.pumpWidget(
        MaterialApp(
          theme: DsTheme.light(),
          home: Scaffold(body: SingleChildScrollView(child: ProductDeliveryChargesSection(row: input, currencySymbol: 'FCFA'))),
        ),
      );
    }

    testWidgets('one charge: three fields, no add or remove', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final input = DeliveryChargeTierInput();
      await pump(tester, input);

      expect(find.text('Delivery Charges'), findsOneWidget);
      expect(find.text(ProductDeliveryCharges.note), findsOneWidget);
      expect(find.text('Delivery Charges Per Km'), findsOneWidget);
      expect(find.text('Minimum Delivery Charges (FCFA)'), findsOneWidget);
      expect(find.text('Minimum Delivery Charge Within Km'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.byType(DsButton), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      input.dispose();
    });

    testWidgets('fields take a decimal keyboard and refuse letters', (tester) async {
      final input = DeliveryChargeTierInput();
      await pump(tester, input);
      final fields = find.byType(TextField);
      expect(tester.widget<TextField>(fields.first).keyboardType, const TextInputType.numberWithOptions(decimal: true));
      await tester.enterText(fields.first, '12.345');
      expect(input.perKmController.text, isNot('12.345'));
      await tester.enterText(fields.first, '12.34');
      expect(input.perKmController.text, '12.34');
    });
  });
}

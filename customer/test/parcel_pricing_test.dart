import 'package:customer/models/parcel_order_model.dart';
import 'package:customer/models/parcel_shipping_models.dart';
import 'package:customer/models/parcel_weight_model.dart';
import 'package:customer/utils/parcel_pricing.dart';
import 'package:customer/utils/parcel_receipt_pdf.dart' show ParcelAmounts;
import 'package:flutter_test/flutter_test.dart';

// app-spec-parcel-pricing.md (12 Oct 2026) and the brief's check cases A-E.
void main() {
  // The admin's Parcel Weight bands once saved with minKg / maxKg
  // (`delivery_charge` is a string on existing bands).
  final List<ParcelWeightModel> kgBands = [
    ParcelWeightModel.fromJson({'id': 'b1', 'title': '1 KG', 'delivery_charge': '20', 'minKg': 0, 'maxKg': 1}),
    ParcelWeightModel.fromJson({'id': 'b2', 'title': '3 KG', 'delivery_charge': '40', 'minKg': 1.01, 'maxKg': 3}),
    ParcelWeightModel.fromJson({'id': 'b3', 'title': '5 KG', 'delivery_charge': '50', 'minKg': 3.01, 'maxKg': 5}),
    ParcelWeightModel.fromJson({'id': 'b4', 'title': '7 KG', 'delivery_charge': '70', 'minKg': '5.01', 'maxKg': '7'}),
    ParcelWeightModel.fromJson({'id': 'b5', 'title': '+15 KG', 'delivery_charge': '100', 'minKg': 7.01, 'maxKg': null}),
  ];
  // The same bands before the admin saved them: titles only.
  final List<ParcelWeightModel> titleBands = [
    ParcelWeightModel.fromJson({'id': 't1', 'title': 'Upto 2 kg', 'delivery_charge': '30'}),
    ParcelWeightModel.fromJson({'id': 't2', 'title': 'Upto 5 kg', 'delivery_charge': '50'}),
    ParcelWeightModel.fromJson({'id': 't3', 'title': '5 - 10 kg', 'delivery_charge': '80'}),
  ];
  ParcelBand<ParcelWeightModel> band(ParcelWeightModel w) => ParcelBand(source: w, title: w.title, minKg: w.minKg, maxKg: w.maxKg, charge: parcelNumber(w.deliveryCharge) ?? 0);
  List<ParcelBand<ParcelWeightModel>> bands(List<ParcelWeightModel> l) => l.map(band).toList();

  // The Owner's carrier of cases B / C, as the admin saves it.
  Map<String, dynamic> carrierJson({dynamic homePickupCharge = 500, List<String>? deliveryScopes}) => {
    'name': 'Spideli Express',
    'publish': true,
    'regionIds': ['cm'],
    'deliveryScopes': ?deliveryScopes,
    // Flat fields: an older carrier, as strings.
    'baseCharge': '15', 'perKmCharge': '6', 'perKgCharge': '5', 'minimumCharge': '0',
    'regionPricing': {
      'cm': {
        'baseCharge': '20', 'perKmCharge': '15', 'perKgCharge': 8, 'minimumCharge': '25',
        'volumetricDivisor': null,
        'homePickupCharge': homePickupCharge,
        'pointDropoffCharge': null,
        'homeDeliveryCharge': 500,
        'pointCollectionCharge': '',
      },
    },
  };

  group('brief section 7 check cases', () {
    test('A. size counts (default source, city)', () {
      final region = RegionParcelPricing.fromJson({
        'volumetricDivisor': 5000, 'homePickupCharge': 0, 'pointDropoffCharge': 0, 'homeDeliveryCharge': 0, 'pointCollectionCharge': 0,
        'intercityFixedTax': 5000, 'intercountryFixedTax': 5000,
      });
      final q = ParcelPricing.defaultQuote<ParcelWeightModel>(
        scope: ParcelScope.city,
        distance: 10,
        actualKg: 2,
        lengthCm: 50,
        widthCm: 50,
        heightCm: 50,
        pickupMethod: ParcelMethod.pickupPoint,
        deliveryMethod: ParcelMethod.pickupPoint,
        bands: bands(kgBands),
        region: region,
      )!;
      expect(q.volumetricKg, 25);
      expect(q.chargeableKg, 25);
      expect(ParcelPricing.bandFor(bands(kgBands), 25)!.source.title, '+15 KG');
      expect(q.carrierPrice, 1000);
      expect(q.options, 0);
      expect(q.fixedTax, 0);
      expect(q.total, 1000);
      expect(q.source, 'default');
    });

    test('B. door service and inter-city (carrier) = 9,670', () {
      final carrier = DeliveryCarrierModel.fromJson('k1', carrierJson());
      const region = RegionParcelPricing(volumetricDivisor: 5000, homePickupCharge: 0, pointDropoffCharge: 0, homeDeliveryCharge: 0, pointCollectionCharge: 0, intercityFixedTax: 5000, intercountryFixedTax: 5000);
      final scope = ParcelPricing.scopeFor(origin: const ParcelPlace(city: 'Douala', countryCode: 'CM'), destination: const ParcelPlace(city: 'Yaoundé', countryCode: 'CM'));
      expect(scope, ParcelScope.intercity);
      final q = ParcelPricing.carrierQuote(
        scope: scope,
        card: carrier.rateCardFor('cm'),
        distanceKm: 230,
        actualKg: 2,
        lengthCm: 50,
        widthCm: 50,
        heightCm: 50,
        pickupMethod: ParcelMethod.home,
        deliveryMethod: ParcelMethod.home,
        region: region,
      )!;
      expect(q.volumetricDivisor, 5000); // carrier blank -> region
      expect(q.chargeableKg, 25);
      expect(q.carrierPrice, 3670); // 20 + 15 x 230 + 8 x 25, no conversion
      expect(q.options, 1000);
      expect(q.fixedTax, 5000);
      expect(q.total, 9670);
      expect(q.subTotal, 3670); // subTotal stays the base price
      expect(carrier.isEligible(originRegionId: 'cm', chargeableKg: 25, scope: scope), isTrue);
      expect(q.breakdown(currency: 'XAF'), {
        'source': 'rate_card', 'currency': 'XAF',
        'actualKg': 2.0, 'volumetricKg': 25.0, 'chargeableKg': 25.0,
        'volumetricDivisor': 5000.0,
        'carrierPrice': 3670.0, 'extraKgCharge': 0.0,
        'options': 1000.0, 'pickupCharge': 500.0, 'deliveryCharge': 500.0,
        'fixedTax': 5000.0, 'smsCharge': 0.0, 'commission': 0.0,
        'total': 9670.0,
      });
    });

    test('C. blank vs zero: the owner\'s 0 is free, blank takes the region\'s', () {
      const region = RegionParcelPricing(homePickupCharge: 300);
      ParcelQuote quote(dynamic home) => ParcelPricing.carrierQuote(
        scope: ParcelScope.intercity,
        card: DeliveryCarrierModel.fromJson('k1', carrierJson(homePickupCharge: home)).rateCardFor('cm'),
        distanceKm: 230,
        actualKg: 2,
        pickupMethod: ParcelMethod.home,
        deliveryMethod: ParcelMethod.pickupPoint,
        region: region,
      )!;
      expect(quote(0).pickupCharge, 0);
      expect(quote(null).pickupCharge, 300);
      expect(quote('').pickupCharge, 300);
      // pointCollectionCharge '' on the carrier, not set on the region -> 0.
      expect(quote(0).deliveryCharge, 0);
    });

    test('D. scope filter (deliveryScopes)', () {
      final cityOnly = DeliveryCarrierModel.fromJson('k1', carrierJson(deliveryScopes: ['city']));
      expect(cityOnly.isEligible(originRegionId: 'cm', chargeableKg: 2, scope: ParcelScope.intercity), isFalse);
      expect(cityOnly.isEligible(originRegionId: 'cm', chargeableKg: 2, scope: ParcelScope.city), isTrue);
      final all = DeliveryCarrierModel.fromJson('k2', carrierJson());
      final empty = DeliveryCarrierModel.fromJson('k3', carrierJson(deliveryScopes: []));
      for (final scope in ParcelScope.all) {
        expect(all.isEligible(originRegionId: 'cm', chargeableKg: 2, scope: scope), isTrue);
        expect(empty.isEligible(originRegionId: 'cm', chargeableKg: 2, scope: scope), isTrue);
      }
      expect(
        ParcelPricing.carrierQuote(
          scope: ParcelScope.intercity,
          card: cityOnly.rateCardFor('cm'),
          distanceKm: 10,
          actualKg: 2,
          pickupMethod: ParcelMethod.home,
          deliveryMethod: ParcelMethod.home,
          deliveryScopes: cityOnly.deliveryScopes,
        ),
        isNull,
      );
    });

    test('E. nothing configured: today\'s price, fixed charge 0', () {
      final region = RegionParcelPricing.fromJson(null); // no parcelPricing map
      expect(region.volumetricDivisor, isNull);
      expect(region.fixedTaxFor(ParcelScope.intercity), 0);
      expect(region.fixedTaxFor(ParcelScope.intercountry), 0);
      // Same city, title bands: the selected band, moved up by title as today.
      final ParcelBand<ParcelWeightModel> selected = band(titleBands.first);
      final q = ParcelPricing.defaultQuote<ParcelWeightModel>(
        scope: ParcelScope.city,
        distance: 7.5,
        actualKg: 4,
        lengthCm: 50,
        widthCm: 50,
        heightCm: 50, // no divisor: the size is not used
        pickupMethod: ParcelMethod.home,
        deliveryMethod: ParcelMethod.home,
        bands: bands(titleBands),
        selected: selected,
        region: region,
      )!;
      expect(q.volumetricKg, 0);
      expect(q.volumetricDivisor, isNull);
      expect(q.chargeableKg, 4);
      expect(q.carrierPrice, 7.5 * 50); // "Upto 5 kg", distance x charge
      expect(q.options, 0);
      expect(q.fixedTax, 0);
      expect(q.breakdown(currency: 'XAF')['volumetricDivisor'], isNull);
      expect(q.breakdown(currency: 'XAF')['volumetricKg'], 0);
      // A carrier on an inter-city route: the rate card, no fixed charge.
      final c = ParcelPricing.carrierQuote(
        scope: ParcelScope.intercity,
        card: const ParcelRateCard(baseCharge: 15, perKmCharge: 6, perKgCharge: 5),
        distanceKm: 100,
        actualKg: 2,
        lengthCm: 50,
        widthCm: 50,
        heightCm: 50,
        pickupMethod: ParcelMethod.home,
        deliveryMethod: ParcelMethod.home,
        region: region,
      )!;
      expect(c.carrierPrice, 625);
      expect(c.total, 625);
    });
  });

  group('step 1 - scope (spec section 5)', () {
    test('country, then accent-insensitive city', () {
      String scope(ParcelPlace a, ParcelPlace b, {String? za, String? zb}) => ParcelPricing.scopeFor(origin: a, destination: b, senderZoneId: za, receiverZoneId: zb);
      expect(scope(const ParcelPlace(city: 'Douala', countryCode: 'CM'), const ParcelPlace(city: 'Paris', countryCode: 'FR')), ParcelScope.intercountry);
      expect(scope(const ParcelPlace(city: ' Yaoundé ', countryCode: 'CM'), const ParcelPlace(city: 'YAOUNDE', countryCode: 'cm')), ParcelScope.city);
      expect(scope(const ParcelPlace(city: 'Douala', countryCode: 'CM'), const ParcelPlace(city: 'Yaoundé', countryCode: 'CM')), ParcelScope.intercity);
      // A city missing: same zone -> city, else intercity.
      expect(scope(const ParcelPlace(countryCode: 'CM'), const ParcelPlace(city: 'Douala', countryCode: 'CM'), za: 'z1', zb: 'z1'), ParcelScope.city);
      expect(scope(const ParcelPlace(countryCode: 'CM'), const ParcelPlace(city: 'Douala', countryCode: 'CM'), za: 'z1', zb: 'z2'), ParcelScope.intercity);
      expect(const ParcelPlace(city: 'Ebolowa').cityMatches('ÉBOLOWA'), isTrue);
    });
  });

  group('step 2 - chargeable weight', () {
    test('divisor: carrier if > 0, else region if > 0, else none', () {
      expect(ParcelPricing.resolveVolumetricDivisor(carrierCard: const ParcelRateCard(volumetricDivisor: 4000), regionPricing: const RegionParcelPricing(volumetricDivisor: 5000)), 4000);
      expect(ParcelPricing.resolveVolumetricDivisor(carrierCard: const ParcelRateCard(volumetricDivisor: 0), regionPricing: const RegionParcelPricing(volumetricDivisor: 5000)), 5000);
      expect(ParcelPricing.resolveVolumetricDivisor(carrierCard: null, regionPricing: const RegionParcelPricing(volumetricDivisor: 0)), isNull);
      expect(ParcelPricing.resolveVolumetricDivisor(), isNull); // never an assumed 5000
    });

    test('volumetric weight needs a divisor and all three sides, 2 decimals', () {
      expect(ParcelPricing.volumetricKg(lengthCm: 50, widthCm: 40, heightCm: 30, divisor: 5000), 12);
      expect(ParcelPricing.volumetricKg(lengthCm: 11, widthCm: 13, heightCm: 17, divisor: 5000), 0.49);
      expect(ParcelPricing.volumetricKg(lengthCm: 50, widthCm: 40, heightCm: null, divisor: 5000), isNull);
      expect(ParcelPricing.volumetricKg(lengthCm: 50, widthCm: 0, heightCm: 30, divisor: 5000), isNull);
      expect(ParcelPricing.volumetricKg(lengthCm: 50, widthCm: 40, heightCm: 30, divisor: null), isNull);
      expect(ParcelPricing.chargeableKg(actualKg: 1.5, volumetricKg: 12), 12);
      expect(ParcelPricing.chargeableKg(actualKg: 20.004, volumetricKg: 12), 20);
      expect(ParcelPricing.chargeableKg(), 0);
    });
  });

  group('step 3 - offered carriers', () {
    test('publish, region, maxWeight against the chargeable weight', () {
      final heavy = DeliveryCarrierModel.fromJson('k', {...carrierJson(), 'maxWeight': '20'});
      expect(heavy.isEligible(originRegionId: 'cm', chargeableKg: 20, scope: ParcelScope.city), isTrue);
      expect(heavy.isEligible(originRegionId: 'cm', chargeableKg: 25, scope: ParcelScope.city), isFalse);
      expect(heavy.isEligible(originRegionId: 'in', chargeableKg: 2, scope: ParcelScope.city), isFalse);
      expect(DeliveryCarrierModel.fromJson('k', {...carrierJson(), 'publish': false}).isEligible(originRegionId: 'cm', chargeableKg: 2, scope: ParcelScope.city), isFalse);
      // No regionIds: everywhere.
      expect(DeliveryCarrierModel.fromJson('k', {...carrierJson(), 'regionIds': []}).isEligible(originRegionId: 'in', chargeableKg: 2, scope: ParcelScope.city), isTrue);
    });
  });

  group('step 4 - base price', () {
    test('regionPricing[R] first, flat fields only without an entry for R', () {
      final carrier = DeliveryCarrierModel.fromJson('k1', carrierJson());
      expect(carrier.rateCardFor('cm').baseCharge, 20);
      final ParcelRateCard flat = carrier.rateCardFor('elsewhere');
      expect(flat.baseCharge, 15);
      // The flat card never carries the five owner values.
      final withRootOptions = DeliveryCarrierModel.fromJson('k', {...carrierJson(), 'regionPricing': null, 'homePickupCharge': 999, 'volumetricDivisor': 1});
      expect(withRootOptions.rateCardFor('cm').homePickupCharge, isNull);
      expect(withRootOptions.rateCardFor('cm').volumetricDivisor, isNull);
    });

    test('rate card: at least the minimum; no price -> not offered', () {
      expect(ParcelPricing.rateCardPrice(card: const ParcelRateCard(baseCharge: 500, perKgCharge: 100, minimumCharge: 2000), distanceKm: 250, chargeableKg: 3), 2000);
      expect(ParcelPricing.rateCardPrice(card: const ParcelRateCard(baseCharge: 15, perKmCharge: 6, perKgCharge: 5), distanceKm: 527.35, chargeableKg: 2), 3189.1);
      expect(ParcelPricing.rateCardPrice(card: const ParcelRateCard(homePickupCharge: 5), distanceKm: 5, chargeableKg: 1), isNull);
    });

    test('bands by minKg / maxKg (inclusive, open top, gaps go up)', () {
      String? title(double kg) => ParcelPricing.bandFor(bands(kgBands), kg)?.source.title;
      expect(title(0.5), '1 KG');
      expect(title(1), '1 KG');
      expect(title(1.005), '3 KG'); // gap between 1 and 1.01
      expect(title(3), '3 KG');
      expect(title(5.01), '7 KG');
      expect(title(7.01), '+15 KG');
      expect(title(500), '+15 KG');
    });

    test('without minKg / maxKg: today\'s title matching from the selected band', () {
      String? pick(int selected, double kg) => ParcelPricing.bandFor(bands(titleBands), kg, selected: band(titleBands[selected]))?.source.title;
      expect(pick(0, 1.5), 'Upto 2 kg');
      expect(pick(0, 4), 'Upto 5 kg');
      expect(pick(0, 50), '5 - 10 kg');
      expect(pick(2, 1), '5 - 10 kg'); // never lower than the pick
      expect(ParcelPricing.categoryMaxKg('500 g - 1 kg'), 1);
      expect(ParcelPricing.categoryMaxKg('Small parcel'), isNull);
    });
  });

  group('steps 5-7 - options, fixed charge, total', () {
    test('options by method from carrier, else region, else 0', () {
      const card = ParcelRateCard(pointDropoffCharge: 150);
      const region = RegionParcelPricing(homePickupCharge: 300, pointDropoffCharge: 200, homeDeliveryCharge: 400, pointCollectionCharge: 100);
      var c = ParcelPricing.resolveOptionCharges(pickupMethod: ParcelMethod.pickupPoint, deliveryMethod: ParcelMethod.home, carrierCard: card, regionPricing: region);
      expect((c.pickupCharge, c.deliveryCharge), (150, 400));
      c = ParcelPricing.resolveOptionCharges(pickupMethod: ParcelMethod.home, deliveryMethod: ParcelMethod.pickupPoint, regionPricing: region);
      expect((c.pickupCharge, c.deliveryCharge), (300, 100));
      c = ParcelPricing.resolveOptionCharges(pickupMethod: ParcelMethod.home, deliveryMethod: ParcelMethod.home);
      expect((c.pickupCharge, c.deliveryCharge), (0, 0));
    });

    test('fixed charge: the region\'s only, by scope, never assumed', () {
      final region = RegionParcelPricing.fromJson({'intercityFixedTax': '5000', 'intercountryFixedTax': 7500});
      expect(region.fixedTaxFor(ParcelScope.city), 0);
      expect(region.fixedTaxFor(ParcelScope.intercity), 5000);
      expect(region.fixedTaxFor(ParcelScope.intercountry), 7500);
      expect(RegionParcelPricing.fromJson({'intercityFixedTax': null}).fixedTaxFor(ParcelScope.intercity), 0);
    });

    test('numbers are parsed defensively', () {
      expect(parcelNumber('20'), 20);
      expect(parcelNumber(' 1,500 '), 1500);
      expect(parcelNumber(''), isNull);
      expect(parcelNumber(null), isNull);
      expect(parcelNumber('abc'), isNull);
      expect(parcelNumber(0), 0);
      expect(RegionParcelPricing.fromJson('not a map').homePickupCharge, isNull);
    });

    test('the order: subTotal = base price; checkout and receipt add options, fixed tax, SMS', () {
      final carrier = DeliveryCarrierModel.fromJson('k1', carrierJson());
      final q = ParcelPricing.carrierQuote(
        scope: ParcelScope.intercity,
        card: carrier.rateCardFor('cm'),
        distanceKm: 230,
        actualKg: 2,
        lengthCm: 50,
        widthCm: 50,
        heightCm: 50,
        pickupMethod: ParcelMethod.home,
        deliveryMethod: ParcelMethod.home,
        region: const RegionParcelPricing(volumetricDivisor: 5000, intercityFixedTax: 5000),
      )!;
      final order = ParcelOrderModel.fromJson({
        'id': 'p1',
        'subTotal': q.subTotal.toString(),
        'parcelScopeTax': q.fixedTax,
        'sendReceiverSms': true,
        'smsCharge': 50,
        'pickupMethod': 'home',
        'deliveryMethod': 'pickup_point',
        'destinationPickupPointId': 'pp2',
        'priceBreakdown': q.breakdown(currency: 'XAF', smsCharge: 50),
      });
      expect(order.optionsAmount, 1000);
      expect(order.pickupChargeAmount, 500);
      expect(order.deliveryChargeAmount, 500);
      expect(ParcelAmounts.of(order).total, 3670 + 1000 + 5000 + 50);
      expect(order.priceBreakdown!['total'], 9720);
      final saved = order.shippingJson();
      expect(saved['pickupPointId'], 'pp2');
      expect(saved.containsKey('dropoffPointId'), isFalse);
    });

    test('priceBreakdown keys', () {
      final b = const ParcelQuote(carrierPrice: 100, source: ParcelPriceSource.defaultSetting).breakdown(currency: 'INR');
      expect(b.keys.toSet(), {
        'source', 'currency', 'actualKg', 'volumetricKg', 'chargeableKg', 'volumetricDivisor', 'carrierPrice', 'extraKgCharge',
        'options', 'pickupCharge', 'deliveryCharge', 'fixedTax', 'smsCharge', 'commission', 'total',
      });
      expect(b['volumetricDivisor'], isNull);
      expect(b['volumetricKg'], 0);
      expect(b['extraKgCharge'], 0);
      expect(b.values.contains('route_table'), isFalse);
    });
  });

  group('pickup points (spec 3.5 / section 4)', () {
    test('only published points of the region are offered', () {
      PickupPointModel p(Map<String, dynamic> j) => PickupPointModel.fromJson('pp', {'name': 'Relay', ...j});
      expect(p({'publish': true, 'regionId': 'cm'}).offeredIn('cm'), isTrue);
      expect(p({'publish': true, 'regionId': 'in'}).offeredIn('cm'), isFalse);
      expect(p({'publish': false, 'regionId': 'cm'}).offeredIn('cm'), isFalse);
      expect(p({'regionId': 'cm'}).offeredIn('cm'), isFalse);
    });

    test('dropoffPointId = sender\'s point, pickupPointId = receiver\'s point', () {
      final order = ParcelOrderModel()
        ..pickupMethod = 'pickup_point'
        ..originPickupPointId = 'drop'
        ..deliveryMethod = 'pickup_point'
        ..destinationPickupPointId = 'collect';
      final saved = order.shippingJson();
      expect(saved['dropoffPointId'], 'drop');
      expect(saved['pickupPointId'], 'collect');
      final read = ParcelOrderModel.fromJson({'pickupMethod': 'pickup_point', 'dropoffPointId': 'drop', 'deliveryMethod': 'pickup_point', 'pickupPointId': 'collect'});
      expect(read.originPickupPointId, 'drop');
      expect(read.destinationPickupPointId, 'collect');
      // Before 12 Oct pickupPointId held the origin point: not the receiver's.
      final old = ParcelOrderModel.fromJson({'pickupMethod': 'pickup_point', 'originPickupPointId': 'o', 'deliveryMethod': 'pickup_point', 'pickupPointId': 'o'});
      expect(old.destinationPickupPointId, isNull);
    });
  });

  group('commission added as an extra (settings/ParcelPricing.commissionAsExtra)', () {
    const ParcelQuote quote = ParcelQuote(carrierPrice: 1000, fixedTax: 5000, pickupCharge: 500, deliveryCharge: 1000, source: ParcelPriceSource.rateCard);

    test('a percentage is taken on the delivery company\'s base price only', () {
      final ParcelQuote q = ParcelPricing.withExtraCommission(quote, type: 'Percentage', value: 10);
      expect(q.commission, 100);
      expect(q.subTotal, 1100);
      expect(q.total, 1000 + 100 + 1500 + 5000);
      expect(ParcelPricing.withExtraCommission(quote, type: 'percent', value: 12.5).commission, 125);
    });

    test('the section\'s type decides: a fixed commission is its value', () {
      expect(ParcelPricing.withExtraCommission(quote, type: 'Fixed', value: 150).commission, 150);
      expect(ParcelPricing.withExtraCommission(quote, type: 'Percentage', value: 0).commission, 0);
      expect(ParcelPricing.withExtraCommission(quote, type: 'Percentage', value: null).commission, 0);
    });

    test('the order taxes never apply to the commission', () {
      expect(ParcelPricing.taxableAmount(subTotal: 1100, discount: 0, commission: 100), 1000);
      expect(ParcelPricing.taxableAmount(subTotal: 1100, discount: 110, commission: 100), 890);
      expect(ParcelPricing.taxableAmount(subTotal: 1000, discount: 50), 950);
      expect(ParcelPricing.taxableAmount(subTotal: 100, discount: 100, commission: 50), 0);
      expect(ParcelPricing.taxableAmount(subTotal: 1000, discount: 0, commission: -5), 1000);

      final ParcelAmounts a = ParcelAmounts.of(ParcelOrderModel.fromJson({
        'id': 'c1',
        'subTotal': '1100',
        'discount': '0',
        'taxSetting': [
          {'title': 'VAT', 'type': 'percentage', 'tax': '10', 'enable': true},
        ],
        'priceBreakdown': {'carrierPrice': 1000, 'commission': 100},
      }));
      expect(a.orderTax, 100);
      expect(a.total, 1200);
      // Without a commission the whole subTotal is taxed, as before.
      final ParcelAmounts b = ParcelAmounts.of(ParcelOrderModel.fromJson({
        'id': 'c2',
        'subTotal': '1100',
        'discount': '0',
        'taxSetting': [
          {'title': 'VAT', 'type': 'percentage', 'tax': '10', 'enable': true},
        ],
        'priceBreakdown': {'carrierPrice': 1100, 'commission': 0},
      }));
      expect(b.orderTax, 110);
    });

    test('extraCommission reads priceBreakdown.commission tolerantly', () {
      expect(ParcelOrderModel.fromJson({'priceBreakdown': {'commission': '75.5'}}).extraCommission, 75.5);
      expect(ParcelOrderModel.fromJson({'priceBreakdown': {'commission': 'x'}}).extraCommission, 0);
      expect(ParcelOrderModel.fromJson({}).extraCommission, 0);
    });
  });
}

import 'package:customer/utils/parcel_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

// Spec 5.1 / 5.2 rate tables and the worked examples of spec 5.3.
void main() {
  final ParcelRateTable table = ParcelRateTable.fromJson({
    'intercity': [
      {'from': 'Douala', 'to': 'Bamenda', 'minKg': 0.0001, 'maxKg': 0.5, 'price': 1850},
      {'from': 'Bamenda', 'to': 'Douala', 'minKg': 0.0001, 'maxKg': 0.5, 'price': 2350},
      {'from': 'Douala', 'to': 'Yaounde', 'minKg': 0.501, 'maxKg': 2, 'price': 1550},
      {'from': 'Yaounde', 'to': 'Douala', 'minKg': 0.501, 'maxKg': 2, 'price': 2050},
      {'from': 'Bangangte', 'to': 'Bamenda', 'minKg': 2.1, 'maxKg': 5, 'price': 2050},
      {'from': 'Douala', 'to': 'Bangangte', 'minKg': 2.1, 'maxKg': 5, 'price': 2550},
      {'from': 'Bafoussam', 'to': 'Yaounde', 'minKg': 5.1, 'maxKg': 10, 'price': 2550},
      {'from': 'Douala', 'to': 'Bangangte', 'minKg': 5.1, 'maxKg': 10, 'price': 3050},
    ],
    'intercountry': [
      {'fromCountry': 'CM', 'toCountry': 'FR', 'minKg': 0.5, 'maxKg': 2, 'ratePerKg': 9500},
      {'fromCountry': 'CM', 'toCountry': 'FR', 'minKg': 2.5, 'maxKg': 10, 'ratePerKg': 8500},
      {'fromCountry': 'CM', 'toCountry': 'FR', 'minKg': 10.5, 'maxKg': 22.5, 'ratePerKg': 7000},
      {'fromCountry': 'CM', 'toCountry': 'FR', 'minKg': 23, 'maxKg': 69, 'ratePerKg': 5500},
      {'fromCountry': 'CM', 'toCountry': 'FR', 'minKg': 69.5, 'maxKg': 115, 'ratePerKg': 4500},
      {'fromCountry': 'CM', 'toCountry': 'FR', 'minKg': 115.5, 'maxKg': 199, 'ratePerKg': 4000},
      {'fromCountry': 'CM', 'toCountry': 'FR', 'minKg': 200, 'maxKg': null, 'ratePerKg': 3500},
    ],
  })!;

  const cameroon = ParcelPlace(city: 'Douala', country: 'Cameroon', countryCode: 'CM');
  const france = ParcelPlace(city: 'Paris', country: 'France', countryCode: 'FR');

  test('Douala > Yaounde 1.5 kg = 6,550', () {
    final q = ParcelPricing.intercity(table: table, origin: const ParcelPlace(city: 'douala'), destination: const ParcelPlace(city: 'Yaounde'), weightKg: 1.5)!;
    expect(q.carrierPrice, 1550);
    expect(q.fixedTax, 5000);
    expect(q.total, 6550);
  });

  test('Bafoussam > Yaounde 13.4 kg = 11,550', () {
    final q = ParcelPricing.intercity(table: table, origin: const ParcelPlace(city: 'Bafoussam'), destination: const ParcelPlace(city: 'Yaounde'), weightKg: 13.4)!;
    expect(q.carrierPrice, 2550);
    expect(q.extraKgCharge, 4000);
    expect(q.total, 11550);
  });

  test('Cameroon > France 3.2 kg = 34,750', () {
    final q = ParcelPricing.intercountry(table: table, origin: cameroon, destination: france, weightKg: 3.2)!;
    expect(q.chargeableKg, 3.5);
    expect(q.carrierPrice, 29750);
    expect(q.total, 34750);
  });

  test('Cameroon > France 22.5 kg = 162,500', () {
    expect(ParcelPricing.intercountry(table: table, origin: cameroon, destination: france, weightKg: 22.5)!.total, 162500);
  });

  test('Cameroon > France 23 kg = 131,500', () {
    expect(ParcelPricing.intercountry(table: table, origin: cameroon, destination: france, weightKg: 23)!.total, 131500);
  });

  test('routes are directional and unknown routes are not served', () {
    expect(ParcelPricing.intercity(table: table, origin: const ParcelPlace(city: 'Bamenda'), destination: const ParcelPlace(city: 'Douala'), weightKg: 0.3)!.carrierPrice, 2350);
    expect(ParcelPricing.intercity(table: table, origin: const ParcelPlace(city: 'Yaounde'), destination: const ParcelPlace(city: 'Bafoussam'), weightKg: 3), isNull);
    expect(ParcelPricing.intercountry(table: table, origin: france, destination: cameroon, weightKg: 3), isNull);
  });

  test('rate card fallback ignores unset fields and applies the minimum', () {
    final q = ParcelPricing.rateCard(card: const ParcelRateCard(baseCharge: 500, perKgCharge: 100, minimumCharge: 2000), scope: ParcelScope.intercity, distanceKm: 250, weightKg: 3)!;
    expect(q.carrierPrice, 2000);
    expect(q.total, 7000);
    expect(ParcelPricing.rateCard(card: const ParcelRateCard(), scope: ParcelScope.city, distanceKm: 5, weightKg: 1), isNull);
  });
  test('checkout base excludes the fixed scope tax: Douala > Yaounde 1.5 kg pays 6,550', () {
    final q = ParcelPricing.intercity(table: table, origin: const ParcelPlace(city: 'Douala'), destination: const ParcelPlace(city: 'Yaounde'), weightKg: 1.5)!;
    // Book: subTotal = quote.total - fixedTax; parcelScopeTax = fixedTax. Checkout (no VAT / coupon):
    // (subTotal - discount) + fee + taxes + parcelScopeTax.
    final double subTotal = q.total - q.fixedTax;
    expect(subTotal, 1550);
    expect(subTotal + q.fixedTax, 6550);
  });

  test('weight category upper limit', () {
    expect(ParcelPricing.categoryMaxKg('Upto 5 kg'), 5);
    expect(ParcelPricing.categoryMaxKg('1-5 kg'), 5);
    expect(ParcelPricing.categoryMaxKg('5kg - 10kg'), 10);
    expect(ParcelPricing.categoryMaxKg('500 g - 1 kg'), 1);
    expect(ParcelPricing.categoryMaxKg('Up to 500g'), 0.5);
    expect(ParcelPricing.categoryMaxKg('Above 20 KG'), 20);
    expect(ParcelPricing.categoryMaxKg('2,5 kg'), 2.5);
    expect(ParcelPricing.categoryMaxKg('Small parcel'), isNull);
    expect(ParcelPricing.categoryMaxKg(null), isNull);
  });

  // Client doc point 42: the price did not change whether or not dimensions
  // were given. A parcel is now charged on the greater of its weight and its
  // volumetric weight (L x W x H / settings/ParcelPricing.volumetricDivisor).
  group('dimensions move the price (doc 42)', () {
    test('volumetricDivisor: 5000 when absent, configurable, 0 switches it off', () {
      expect(const ParcelPricingSettings().volumetricDivisor, 5000);
      expect(ParcelPricingSettings.fromJson({}).volumetricDivisor, 5000);
      expect(ParcelPricingSettings.fromJson({'volumetricDivisor': '6000'}).volumetricDivisor, 6000);
      expect(ParcelPricingSettings.fromJson({'volumetricDivisor': 0}).usesVolumetricWeight, isFalse);
      expect(ParcelPricingSettings.fromJson({'volumetricDivisor': -1}).usesVolumetricWeight, isFalse);
    });

    test('volumetric weight needs all three sides', () {
      expect(ParcelPricing.volumetricKg(lengthCm: 50, widthCm: 40, heightCm: 30, divisor: 5000), 12);
      expect(ParcelPricing.volumetricKg(lengthCm: 10, widthCm: 10, heightCm: 10, divisor: 5000), 0.2);
      expect(ParcelPricing.volumetricKg(lengthCm: 50, widthCm: 40, heightCm: null, divisor: 5000), isNull);
      expect(ParcelPricing.volumetricKg(lengthCm: 50, widthCm: 0, heightCm: 30, divisor: 5000), isNull);
      expect(ParcelPricing.volumetricKg(lengthCm: 50, widthCm: 40, heightCm: 30, divisor: 0), isNull);
    });

    test('charged on the greater of actual and volumetric weight', () {
      expect(ParcelPricing.chargeableKg(actualKg: 1.5, volumetricKg: 12), 12);
      expect(ParcelPricing.chargeableKg(actualKg: 20, volumetricKg: 12), 20);
      expect(ParcelPricing.chargeableKg(actualKg: 1.5, volumetricKg: null), 1.5);
      expect(ParcelPricing.chargeableKg(actualKg: null, volumetricKg: null), 0);
    });

    test('the same 1.5 kg parcel costs more on a rate table once it is bulky', () {
      double priced({double? volumetricKg}) => ParcelPricing.intercity(
        table: table,
        origin: const ParcelPlace(city: 'Douala'),
        destination: const ParcelPlace(city: 'Bangangte'),
        weightKg: ParcelPricing.chargeableKg(actualKg: 1.5, volumetricKg: volumetricKg),
      )!.total;
      expect(priced(), 7550); // 2.1-5 kg band 2,550 + 5,000 tax
      // 40 x 30 x 30 cm = 7.2 kg volumetric: the 5.1-10 kg band.
      expect(priced(volumetricKg: ParcelPricing.volumetricKg(lengthCm: 40, widthCm: 30, heightCm: 30, divisor: 5000)), 8050);
      // 50 x 40 x 30 cm = 12 kg: the last band + 2 extra kg.
      expect(priced(volumetricKg: ParcelPricing.volumetricKg(lengthCm: 50, widthCm: 40, heightCm: 30, divisor: 5000)), 10050);
      // A small box changes nothing: the weight is the greater.
      expect(priced(volumetricKg: ParcelPricing.volumetricKg(lengthCm: 10, widthCm: 10, heightCm: 10, divisor: 5000)), 7550);
    });

    test('a per-kg rate card charges the volumetric weight', () {
      const card = ParcelRateCard(baseCharge: 500, perKgCharge: 100);
      final double kg = ParcelPricing.chargeableKg(actualKg: 2, volumetricKg: ParcelPricing.volumetricKg(lengthCm: 50, widthCm: 40, heightCm: 30, divisor: 5000));
      expect(ParcelPricing.rateCard(card: card, scope: ParcelScope.city, distanceKm: 0, weightKg: kg)!.carrierPrice, 1700);
    });

    test('same city: the weight category moves up to the one covering the charged weight', () {
      const List<String> categories = ['Upto 2 kg', 'Upto 5 kg', '5 - 10 kg', 'Above 20 kg'];
      String pick(String selected, double kg) => ParcelPricing.categoryFor<String>(categories: categories, selected: selected, kg: kg, titleOf: (t) => t);
      expect(pick('Upto 2 kg', 1.5), 'Upto 2 kg');
      expect(pick('Upto 2 kg', 4), 'Upto 5 kg');
      expect(pick('Upto 2 kg', 12), 'Above 20 kg');
      expect(pick('Upto 2 kg', 50), 'Above 20 kg');
      // Never lower than what the customer picked.
      expect(pick('5 - 10 kg', 1), '5 - 10 kg');
      // Nothing to compare against: the pick stands.
      expect(ParcelPricing.categoryFor<String>(categories: const ['Small parcel', 'Upto 5 kg'], selected: 'Small parcel', kg: 30, titleOf: (t) => t), 'Small parcel');
    });
  });

  // Client doc point 43: delivery_carriers.regionPricing is the source of
  // truth; the flat fields hold the FIRST region's price.
  group('carrier price per region (doc 43)', () {
    final Map<String, dynamic> carrier = {
      'baseCharge': 1000,
      'perKmCharge': 100,
      'regionPricing': {
        'centre': {'baseCharge': 1000, 'perKmCharge': 100},
        'littoral': {'baseCharge': 1500, 'perKmCharge': 200, 'minimumCharge': 5000},
        'broken': 'not a map',
      },
    };
    final ParcelRateCard flat = ParcelRateCard.fromJson(carrier);
    final Map<String, ParcelRateCard> regions = ParcelRateCard.parseRegionPricing(carrier['regionPricing']);

    test('the region of the order picks its own price', () {
      final ParcelRateCard card = ParcelRateCard.forRegion(flat: flat, regionPricing: regions, regionId: 'littoral');
      expect(card.baseCharge, 1500);
      expect(ParcelPricing.rateCard(card: card, scope: ParcelScope.city, distanceKm: 10, weightKg: 1)!.carrierPrice, 5000);
      expect(ParcelPricing.rateCard(card: card, scope: ParcelScope.city, distanceKm: 30, weightKg: 1)!.carrierPrice, 7500);
    });

    test('the flat fields only when the region has no entry, is unknown, or regionPricing is empty', () {
      expect(ParcelRateCard.forRegion(flat: flat, regionPricing: regions, regionId: 'nord').baseCharge, 1000);
      expect(ParcelRateCard.forRegion(flat: flat, regionPricing: regions, regionId: null).baseCharge, 1000);
      expect(ParcelRateCard.forRegion(flat: flat, regionPricing: const {}, regionId: 'littoral').baseCharge, 1000);
      expect(regions.containsKey('broken'), isFalse);
      expect(ParcelRateCard.parseRegionPricing(null), isEmpty);
    });
  });
}

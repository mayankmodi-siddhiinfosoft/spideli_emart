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
}

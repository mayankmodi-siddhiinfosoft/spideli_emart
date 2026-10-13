import 'package:customer/models/currency_model.dart';
import 'package:customer/models/parcel_shipping_models.dart';
import 'package:customer/models/region_model.dart';
import 'package:customer/utils/parcel_pricing.dart';
import 'package:customer/utils/region_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The carrier choice of the parcel flow, on the live zone / region / carrier
/// shapes of 13 Oct 2026. A zone serving a country region AND a city region
/// ("Yaounde": Cameroun + Yaounde-Cameroun) left the order's region
/// unresolved for every customer whose own region was neither, so every
/// carrier with `regionIds` was dropped and the selection screen skipped.
void main() {
  // Live region ids.
  const String cameroun = '0UJDCiTISC58T7WhEAjg';
  const String yaounde = 'RANln1qefPEoOuqlT0vy';
  const String douala = 'CVt7YJrgyGILT0nGgBxp';
  const String india = 'EBLZwaumlTp4N81ar85J';
  const String deleted = 'FTngBVrRNngciHsCzXnA'; // still listed by "Worldwide"
  const String xaf = '6aa7cecbca349';
  const String inr = '6ab127a406317';

  // Live zones (their regionIds).
  const List<String> yaoundeZone = [cameroun, yaounde];
  const List<String> doualaZone = [cameroun, douala];
  const List<String> worldwideZone = [deleted, india];
  const List<String> ahmedabadZone = [india];
  const List<String> junagadhZone = [india];
  const List<List<String>> allZones = [yaoundeZone, doualaZone, worldwideZone, ahmedabadZone, junagadhZone];

  // Live carriers.
  final List<DeliveryCarrierModel> carriers = [
    DeliveryCarrierModel.fromJson('afrilight', {
      'name': 'Afrilight',
      'regionIds': [yaounde],
      'baseCharge': 15,
      'perKmCharge': 6,
      'perKgCharge': 5,
      'minimumCharge': 30,
    }),
    DeliveryCarrierModel.fromJson('spideli', {
      'name': 'Spideli Express New',
      'regionIds': [yaounde],
      'baseCharge': 20,
      'perKmCharge': 5,
      'perKgCharge': 8,
      'minimumCharge': 25,
    }),
    DeliveryCarrierModel.fromJson('it', {
      'name': 'IT ADVISORY',
      'regionIds': [yaounde],
    }),
    DeliveryCarrierModel.fromJson('ln', {
      'name': 'LN Carrier',
      'regionIds': [india],
      'ownerId': 'owner-ln',
      'deliveryScopes': ParcelScope.all,
      'maxWeight': 50,
      'regionPricing': {
        india: {'baseCharge': 40, 'perKmCharge': 10, 'perKgCharge': 2, 'homePickupCharge': 7},
      },
    }),
    DeliveryCarrierModel.fromJson('maruti', {
      'name': 'Maruti Currier',
      'regionIds': [india],
      'ownerId': 'owner-maruti',
      'deliveryScopes': [ParcelScope.city, ParcelScope.intercity],
      'maxWeight': 100,
      'regionPricing': {
        india: {'baseCharge': 30, 'perKmCharge': 12, 'perKgCharge': 3},
      },
    }),
  ];

  setUp(() {
    RegionService.seedForTest(
      regions: [
        RegionModel(id: cameroun, name: 'Cameroun', countryCode: 'CM', currencyId: xaf),
        RegionModel(id: douala, name: 'Douala-Cameroun', countryCode: 'CM', currencyId: xaf),
        RegionModel(id: yaounde, name: 'Yaounde-Cameroun', countryCode: 'CM', currencyId: xaf),
        RegionModel(id: india, name: 'India', countryCode: 'IN', currencyId: inr),
      ],
      currencies: {xaf: CurrencyModel(id: xaf, code: 'XAF', symbol: 'FCFA'), inr: CurrencyModel(id: inr, code: 'INR', symbol: '₹')},
    );
  });
  tearDown(() => RegionService.seedForTest());

  bool exists(String id) => RegionService.regionById(id) != null;

  List<String> candidatesAt(List<List<String>> senderZones, {String? customerRegion}) =>
      ParcelPricing.orderRegionCandidates(senderZones: senderZones, allZones: allZones, exists: exists, customerRegion: customerRegion);

  List<ParcelCarrierOption> offers(List<String> candidates, {String scope = ParcelScope.city, Map<String, RegionParcelPricing> regionPricing = const {}}) =>
      ParcelCarrierOption.carrierOffers(
        carriers: carriers,
        candidates: candidates,
        regionPricing: regionPricing,
        scope: scope,
        distanceKm: 6.27,
        actualKg: 0.5,
        pickupMethod: ParcelMethod.home,
        deliveryMethod: ParcelMethod.home,
      );

  group('Yaounde sender (zone "Yaounde": Cameroun + Yaounde-Cameroun)', () {
    for (final String? customer in [india, null]) {
      test('customer region ${customer ?? 'none'}: both regions, the city one first', () {
        expect(candidatesAt([yaoundeZone], customerRegion: customer), [yaounde, cameroun]);
      });

      test('customer region ${customer ?? 'none'}: Afrilight and Spideli Express offered on their flat prices, in XAF', () {
        final List<ParcelCarrierOption> list = offers(candidatesAt([yaoundeZone], customerRegion: customer));
        expect(list.map((o) => o.carrier!.name), ['Afrilight', 'Spideli Express New']);
        // 15 + 6 x 6.27 + 5 x 0.5 and 20 + 5 x 6.27 + 8 x 0.5.
        expect(list.map((o) => o.quote.carrierPrice), [55.12, 55.35]);
        for (final o in list) {
          expect(o.regionId, yaounde);
          expect(RegionService.currencyForRecord(o.regionId)?.code, 'XAF');
        }
      });
    }

    test('IT ADVISORY (no price at all) and the India carriers are not offered', () {
      final List<String> ids = offers(candidatesAt([yaoundeZone])).map((o) => o.carrier!.id).toList();
      expect(ids, isNot(contains('it')));
      expect(ids, isNot(contains('ln')));
      expect(ids, isNot(contains('maruti')));
    });

    test('the platform option uses the first candidate (Yaounde-Cameroun)', () {
      expect(candidatesAt([yaoundeZone]).first, yaounde);
    });

    test('a carrier serving only the country region is priced in that region', () {
      final DeliveryCarrierModel national = DeliveryCarrierModel.fromJson('cm', {
        'name': 'National',
        'regionIds': [cameroun],
        'baseCharge': 1,
        'regionPricing': {
          cameroun: {'baseCharge': 100},
        },
      });
      final List<ParcelCarrierOption> list = ParcelCarrierOption.carrierOffers(
        carriers: [national],
        candidates: candidatesAt([yaoundeZone]),
        regionPricing: {cameroun: const RegionParcelPricing(intercityFixedTax: 500)},
        scope: ParcelScope.intercity,
        distanceKm: 200,
        actualKg: 1,
        pickupMethod: ParcelMethod.home,
        deliveryMethod: ParcelMethod.home,
      );
      expect(list.single.regionId, cameroun);
      expect(list.single.quote.carrierPrice, 100);
      expect(list.single.quote.fixedTax, 500);
    });

    test('the customer\'s own region, when it is a candidate, comes first', () {
      expect(candidatesAt([yaoundeZone], customerRegion: cameroun), [cameroun, yaounde]);
    });
  });

  group('India sender (zones "Worldwide" + "Ahmedabad-GJ")', () {
    test('the deleted region of "Worldwide" is ignored: R = India', () {
      expect(candidatesAt([worldwideZone, ahmedabadZone]), [india]);
      expect(candidatesAt([worldwideZone, ahmedabadZone], customerRegion: yaounde), [india]);
    });

    test('LN Carrier and Maruti Currier offered, priced on regionPricing[India], in INR', () {
      final List<ParcelCarrierOption> list = offers(candidatesAt([worldwideZone, ahmedabadZone]));
      expect(list.map((o) => o.carrier!.name).toSet(), {'LN Carrier', 'Maruti Currier'});
      for (final o in list) {
        expect(o.regionId, india);
        expect(RegionService.currencyForRecord(o.regionId)?.code, 'INR');
      }
      final ParcelCarrierOption ln = list.firstWhere((o) => o.carrier!.id == 'ln');
      expect(ln.quote.carrierPrice, 103.7); // 40 + 10 x 6.27 + 2 x 0.5
      expect(ln.quote.pickupCharge, 7);
    });

    test('the region\'s fixed charge and options apply to the carrier', () {
      final List<ParcelCarrierOption> list = offers(
        candidatesAt([worldwideZone, ahmedabadZone]),
        scope: ParcelScope.intercity,
        regionPricing: {india: const RegionParcelPricing(intercityFixedTax: 100, homeDeliveryCharge: 9, homePickupCharge: 3)},
      );
      final ParcelCarrierOption maruti = list.firstWhere((o) => o.carrier!.id == 'maruti');
      expect(maruti.quote.fixedTax, 100);
      expect(maruti.quote.pickupCharge, 3); // Maruti sets none: the region's
      expect(maruti.quote.deliveryCharge, 9);
      expect(list.firstWhere((o) => o.carrier!.id == 'ln').quote.pickupCharge, 7); // LN's own
    });

    test('Maruti does not take intercountry parcels', () {
      final List<ParcelCarrierOption> list = offers(candidatesAt([worldwideZone, ahmedabadZone]), scope: ParcelScope.intercountry);
      expect(list.map((o) => o.carrier!.id), ['ln']);
    });
  });

  test('Douala sender: the Yaounde-only carriers are not offered', () {
    final List<String> candidates = candidatesAt([doualaZone], customerRegion: india);
    expect(candidates, [douala, cameroun]);
    expect(offers(candidates), isEmpty);
  });

  test('no candidate at all: only carriers without regionIds', () {
    final DeliveryCarrierModel anywhere = DeliveryCarrierModel.fromJson('any', {'name': 'Any', 'baseCharge': 50});
    final List<ParcelCarrierOption> list = ParcelCarrierOption.carrierOffers(
      carriers: [...carriers, anywhere],
      candidates: candidatesAt(const []),
      scope: ParcelScope.city,
      distanceKm: 5,
      actualKg: 1,
      pickupMethod: ParcelMethod.home,
      deliveryMethod: ParcelMethod.home,
    );
    expect(list.map((o) => o.carrier!.id), ['any']);
    expect(list.single.regionId, isNull);
  });

  test('a carrier without regionIds uses the primary region', () {
    final DeliveryCarrierModel anywhere = DeliveryCarrierModel.fromJson('any', {'name': 'Any', 'baseCharge': 50});
    expect(anywhere.servedRegion(candidatesAt([yaoundeZone])), yaounde);
  });

  test('no region data loaded: nothing is dropped', () {
    expect(ParcelPricing.orderRegionCandidates(senderZones: [worldwideZone], allZones: allZones), [deleted, india]);
  });
}

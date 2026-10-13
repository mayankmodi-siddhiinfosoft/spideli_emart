import 'package:customer/constant/constant.dart';
import 'package:customer/lang/app_ar.dart';
import 'package:customer/lang/app_en.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/models/parcel_order_model.dart';
import 'package:customer/models/parcel_shipping_models.dart';
import 'package:customer/models/region_model.dart';
import 'package:customer/utils/booking_status_tabs.dart';
import 'package:customer/utils/parcel_pricing.dart';
import 'package:customer/utils/region_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parcel end-to-end check of 12 Oct 2026 (customer side): the carriers and
/// the currency of the ORDER's region, the weight band that only moves up,
/// and the status line of the order screen.
void main() {
  DeliveryCarrierModel carrier(String id, List<String> regions, {Map<String, dynamic> extra = const {}}) => DeliveryCarrierModel.fromJson(id, {
        'name': id,
        'publish': true,
        'regionIds': regions,
        'regionPricing': {for (final r in regions) r: {'baseCharge': 100, 'perKmCharge': 10, 'perKgCharge': 5}},
        ...extra,
      });

  group('brief 12 Oct section 9 bug 1 - only the order region\'s carriers', () {
    final yaounde = [carrier('y1', ['yde']), carrier('y2', ['yde']), carrier('y3', ['yde'])];
    final maruti = carrier('maruti', ['in']);
    final everywhere = DeliveryCarrierModel.fromJson('any', {'name': 'Any', 'publish': true, 'baseCharge': 50});

    List<String> offered(String? region) => [...yaounde, maruti, everywhere]
        .where((c) => c.isEligible(originRegionId: region, chargeableKg: 0.5, scope: ParcelScope.city))
        .map((c) => c.id)
        .toList();

    test('an India order is offered Maruti (and a carrier with no regionIds), never the Yaounde ones', () {
      expect(offered('in'), ['maruti', 'any']);
      expect(offered('yde'), ['y1', 'y2', 'y3', 'any']);
    });

    test('an unresolved region no longer offers every carrier', () {
      expect(offered(null), ['any']);
      expect(offered(''), ['any']);
    });

    test('a carrier with no price at all for R is not offered (no quote)', () {
      final DeliveryCarrierModel noPrice = DeliveryCarrierModel.fromJson('it', {'name': 'IT ADVISORY', 'publish': true, 'regionIds': ['in']});
      expect(
        ParcelPricing.carrierQuote(
          scope: ParcelScope.city,
          card: noPrice.rateCardFor('in'),
          distanceKm: 6.27,
          actualKg: 0.5,
          pickupMethod: ParcelMethod.home,
          deliveryMethod: ParcelMethod.home,
        ),
        isNull,
      );
    });
  });

  group('the order\'s candidate regions (orderRegionCandidates)', () {
    test('the sender\'s zone regions win over the country and the customer', () {
      expect(ParcelPricing.orderRegionCandidates(senderZones: [['dla']], countryRegions: ['dla', 'yde'], customerRegion: 'yde'), ['dla']);
    });
    test('outside every zone: the sender country\'s regions', () {
      expect(ParcelPricing.orderRegionCandidates(countryRegions: ['in'], customerRegion: 'yde'), ['in']);
    });
    test('several regions: all kept (never none), the customer\'s own one first', () {
      expect(ParcelPricing.orderRegionCandidates(senderZones: [['dla', 'yde']], customerRegion: 'yde'), ['yde', 'dla']);
      expect(ParcelPricing.orderRegionCandidates(countryRegions: ['dla', 'yde'], customerRegion: 'in'), ['dla', 'yde']);
    });
    test('country unknown: the customer\'s region', () {
      expect(ParcelPricing.orderRegionCandidates(customerRegion: 'in'), ['in']);
      expect(ParcelPricing.orderRegionCandidates(), isEmpty);
    });
  });

  test('bug 2 - amounts in the order region\'s currency, never the default one', () {
    Constant.currencyModel = CurrencyModel(id: 'xaf', code: 'XAF', symbol: 'FCFA');
    RegionService.seedForTest(
      regions: [
        RegionModel(id: 'yde', name: 'Yaounde', countryCode: 'CM', currencyId: 'xaf'),
        RegionModel(id: 'in', name: 'India', countryCode: 'IN', currencyId: 'inr'),
      ],
      currencies: {'xaf': CurrencyModel(id: 'xaf', code: 'XAF', symbol: 'FCFA'), 'inr': CurrencyModel(id: 'inr', code: 'INR', symbol: '₹')},
    );
    final String? r = ParcelPricing.orderRegionCandidates(countryRegions: RegionService.regionIdsForCountry('in'), customerRegion: 'yde').firstOrNull;
    expect(r, 'in');
    expect(RegionService.currencyForRecord(r)?.code, 'INR');
    final ParcelQuote q = ParcelQuote(carrierPrice: 118, source: ParcelPriceSource.rateCard);
    expect(q.breakdown(currency: RegionService.currencyForRecord(r)?.code ?? '')['currency'], 'INR');
    RegionService.seedForTest();
  });

  group('bug 3 - the weight band moves up, never down', () {
    final List<ParcelBand<String>> bands = [
      const ParcelBand(source: 'b1', title: '1 KG', minKg: 0, maxKg: 1, charge: 20),
      const ParcelBand(source: 'b2', title: '3 KG', minKg: 1.01, maxKg: 3, charge: 40),
      const ParcelBand(source: 'b3', title: '5 KG', minKg: 3.01, maxKg: 5, charge: 50),
      const ParcelBand(source: 'b5', title: '+15 KG', minKg: 5.01, maxKg: null, charge: 100),
    ];
    test('a lighter weight keeps the band the customer chose', () {
      expect(ParcelPricing.bandFor(bands, 0.5, selected: bands[2])?.source, 'b3');
    });
    test('a heavier chargeable weight moves it up', () {
      expect(ParcelPricing.bandFor(bands, 4, selected: bands[0])?.source, 'b3');
      expect(ParcelPricing.bandFor(bands, 25, selected: bands[1])?.source, 'b5');
    });
    test('no band chosen: the band of the weight', () {
      expect(ParcelPricing.bandFor(bands, 2)?.source, 'b2');
    });
  });

  group('order screen status line', () {
    ParcelOrderModel order(String status, {String? parcelStatus, bool quote = false, num? price}) =>
        ParcelOrderModel.fromJson({'id': 'o', 'status': status, 'parcelStatus': ?parcelStatus, 'quoteRequested': quote, 'manualPrice': ?price});

    test('while the dispatch looks for a driver: "Looking for a driver", never "Driver Rejected"', () {
      expect(BookingStatusTabs.parcelLabel(order(Constant.driverRejected)), 'Looking for a driver');
      expect(BookingStatusTabs.parcelLabel(order(Constant.driverPending, parcelStatus: 'Paid')), 'Looking for a driver');
    });
    test('a driver accepted: the order status, not the stale "Paid"', () {
      expect(BookingStatusTabs.parcelLabel(order(Constant.driverAccepted, parcelStatus: 'Paid')), Constant.driverAccepted);
    });
    test('once the parcel moved: its tracking status', () {
      expect(BookingStatusTabs.parcelLabel(order(Constant.orderInTransit, parcelStatus: 'Collected')), 'Collected');
      expect(BookingStatusTabs.parcelLabel(order(Constant.orderCancelled, parcelStatus: 'Cancelled')), 'Cancelled');
    });
    test('quotes', () {
      expect(BookingStatusTabs.parcelLabel(order('Quote Requested', quote: true)), 'Waiting for a quote');
      expect(BookingStatusTabs.parcelLabel(order('Quote Requested', quote: true, price: 5000)), 'Quote ready - pay to confirm');
    });
  });

  test('every parcel status and the quote labels are translated (en + ar)', () {
    const keys = [
      'Created', 'Paid', 'Waiting drop-off', 'Collected', 'At origin pickup point', 'In transit', 'Arrived destination',
      'At destination pickup point', 'Out for delivery', 'Delivered', 'Returned', 'Cancelled', 'Quote Requested',
      'Waiting for a quote', 'Quote ready - pay to confirm', 'Looking for a driver', 'Tracking status', 'Platform fee',
      'Choose a carrier', 'Spideli drivers', 'Request a quote', 'Pay the quote',
    ];
    for (final String k in keys) {
      expect(enUS.containsKey(k), isTrue, reason: 'en: $k');
      expect(arAR.containsKey(k), isTrue, reason: 'ar: $k');
    }
  });
}

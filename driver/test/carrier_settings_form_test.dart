import 'package:driver/models/delivery_carrier_model.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/utils/carrier_settings_form.dart';
import 'package:driver/utils/parcel_amounts.dart';
import 'package:flutter_test/flutter_test.dart';

/// The owner's "Carrier settings" (APP-DEV-BRIEF 12 Oct 2026 section 6):
/// field-path updates of the changed keys only, blank = null, numbers as
/// numbers, never a forbidden field.
void main() {
  final DeliveryCarrierModel carrier = DeliveryCarrierModel(id: 'k1', raw: {
    'name': 'Spideli Express',
    'phone': '677123456',
    'countryCode': '+237',
    'code': 'SPX',
    'ownerId': 'owner-1',
    'publish': true,
    'isVerified': true,
    'regionIds': ['cm', 'ng'],
    'maxWeight': 30,
    'minDeliveryTime': 1,
    'maxDeliveryTime': 3,
    'deliveryTimeUnit': 'days',
    'conditions': 'Fragile: wooden crate',
    // Older carriers store the prices as strings.
    'baseCharge': '20', 'perKmCharge': '15', 'perKgCharge': '8', 'minimumCharge': '25',
    'regionPricing': {
      'cm': {'baseCharge': '20', 'perKmCharge': '15', 'perKgCharge': '8', 'minimumCharge': '25', 'homePickupCharge': 500},
    },
  });

  Map<String, Map<String, String>> regionTexts(Map<String, Map<String, String>> edits) => {
    for (final r in carrier.regionIds)
      r: {
        for (final f in DeliveryCarrierModel.chargeFields) f: DeliveryCarrierModel.formatNumber(carrier.regionCharge(r, f)),
        ...?edits[r],
      },
  };

  Map<String, String> texts([Map<String, String> edits = const {}]) => {
    'name': carrier.text('name'),
    'phone': carrier.text('phone'),
    'email': '',
    'conditions': carrier.text('conditions'),
    'maxWeight': '30',
    'minDeliveryTime': '1',
    'maxDeliveryTime': '3',
    ...edits,
  };

  ({Map<String, dynamic> changes, Map<String, Map<String, num?>> regionChanges, Map<String, String> errors}) diff({
    Map<String, String> edits = const {},
    Map<String, Map<String, String>> regionEdits = const {},
    List<String> scopes = const ['city', 'intercity', 'intercountry'],
    String unit = 'days',
  }) => CarrierSettingsForm.diff(
    carrier: carrier,
    texts: texts(edits),
    regionTexts: regionTexts(regionEdits),
    deliveryScopes: scopes,
    deliveryTimeUnit: unit,
    countryCode: '+237',
  );

  Map<String, dynamic> payload(({Map<String, dynamic> changes, Map<String, Map<String, num?>> regionChanges, Map<String, String> errors}) r) => {
    for (final e in carrier.updatePaths(r.changes, regionChanges: r.regionChanges)) e.key.join('.'): e.value,
  };

  test('nothing edited: nothing written (a stored "20" stays as it is)', () {
    final r = diff();
    expect(r.errors, isEmpty);
    expect(payload(r), isEmpty);
  });

  test('field paths only, numbers as numbers, blank = null, first region mirrored (prices only)', () {
    final r = diff(regionEdits: {
      'cm': {'homePickupCharge': '', 'pointDropoffCharge': '0', 'volumetricDivisor': '6000', 'perKmCharge': '17.5'},
      'ng': {'homeDeliveryCharge': '1500'},
    });
    expect(r.errors, isEmpty);
    expect(payload(r), {
      'regionPricing.cm.homePickupCharge': null, // blank = region default
      'regionPricing.cm.pointDropoffCharge': 0, // 0 = free
      'regionPricing.cm.volumetricDivisor': 6000,
      'regionPricing.cm.perKmCharge': 17.5,
      'perKmCharge': 17.5, // cm is the first region: its price mirrored flat
      'regionPricing.ng.homeDeliveryCharge': 1500,
    });
    expect(payload(r)['regionPricing.cm.volumetricDivisor'], isA<num>());
  });

  test('never negative, never text', () {
    final r = diff(regionEdits: {
      'cm': {'homeDeliveryCharge': '-5', 'baseCharge': 'abc'},
    }, edits: {'maxWeight': '-1'});
    expect(r.errors[CarrierSettingsForm.regionKey('cm', 'homeDeliveryCharge')], CarrierSettingsForm.errNegative);
    expect(r.errors[CarrierSettingsForm.regionKey('cm', 'baseCharge')], CarrierSettingsForm.errNumber);
    expect(r.errors['maxWeight'], CarrierSettingsForm.errNegative);
    // Even if called with a negative value, the payload drops it.
    expect(carrier.updatePaths(const {}, regionChanges: {'cm': {'homePickupCharge': -1}}), isEmpty);
  });

  test('deliveryScopes: at least one; all three = unchanged for a carrier without the field', () {
    expect(diff(scopes: const []).errors.containsKey('deliveryScopes'), isTrue);
    expect(payload(diff(scopes: const ['intercity', 'city'])), {'deliveryScopes': ['city', 'intercity']});
  });

  test('service parameters and times', () {
    final r = diff(edits: {'maxWeight': '', 'minDeliveryTime': '2', 'conditions': 'Mon-Fri'}, unit: 'hours');
    expect(payload(r), {'maxWeight': null, 'minDeliveryTime': 2, 'conditions': 'Mon-Fri', 'deliveryTimeUnit': 'hours'});
    expect(diff(edits: {'minDeliveryTime': '5', 'maxDeliveryTime': '2'}).errors['maxDeliveryTime'], CarrierSettingsForm.errTimes);
  });

  test('forbidden fields are never written, whatever is passed', () {
    final paths = carrier.updatePaths({
      'isVerified': false, 'publish': false, 'ownerId': 'x', 'code': 'X', 'regionIds': ['zz'],
      'operatingLicence': 'x', 'commercialRegisterFile': 'x', 'intercityFixedTax': 0, 'intercountryFixedTax': 0,
      'id': 'x', 'logo': 'x',
    }, regionChanges: {
      'cm': {'intercityFixedTax': 0},
      'zz': {'baseCharge': 1}, // a region the carrier does not serve
    });
    expect(paths, isEmpty);
    for (final f in const ['isVerified', 'publish', 'ownerId', 'code', 'regionIds', 'intercityFixedTax', 'intercountryFixedTax']) {
      expect(DeliveryCarrierModel.editableFields.contains(f), isFalse, reason: f);
    }
  });

  test('a carrier with no regionIds: the four flat prices only, never the five values', () {
    final flat = DeliveryCarrierModel(id: 'f', raw: {'name': 'Flat', 'baseCharge': 300});
    expect(CarrierSettingsForm.numberFieldsFor(flat), containsAll(DeliveryCarrierModel.standardChargeFields));
    expect(CarrierSettingsForm.numberFieldsFor(carrier), isNot(contains('baseCharge')));
    final r = CarrierSettingsForm.diff(
      carrier: flat,
      texts: {'name': 'Flat', 'baseCharge': '350', 'homePickupCharge': '9'},
      regionTexts: const {},
      deliveryScopes: const ['city', 'intercity', 'intercountry'],
      deliveryTimeUnit: '',
      countryCode: '',
    );
    // homePickupCharge is not a flat field: ignored.
    expect({for (final e in flat.updatePaths(r.changes, regionChanges: r.regionChanges)) e.key.join('.'): e.value}, {'baseCharge': 350});
  });

  group('parcel totals match the customer checkout (app-spec-parcel-pricing step 7)', () {
    test('case B: base 3,670 + options 1,000 + fixed 5,000 (+ SMS 50) = 9,720', () {
      final ParcelAmounts a = ParcelAmounts.of(ParcelOrderModel.fromJson({
        'id': 'p1',
        'subTotal': '3670.0',
        'parcelScopeTax': 5000,
        'sendReceiverSms': true,
        'smsCharge': 50,
        'paymentMethod': 'cod',
        'priceBreakdown': {
          'source': 'rate_card', 'currency': 'XAF', 'carrierPrice': 3670, 'extraKgCharge': 0,
          'options': 1000, 'pickupCharge': 500, 'deliveryCharge': 500, 'fixedTax': 5000, 'smsCharge': 50, 'commission': 0,
          'total': 9720,
        },
      }));
      expect(a.subTotal, 3670);
      expect(a.options, 1000);
      expect(a.total, 9720);
      // In cash the options stay with the courier; the platform's share is
      // the fixed charge and the SMS fee.
      expect(a.platformShareOfCash, 5050);
    });

    test('an order without options is unchanged', () {
      final ParcelAmounts a = ParcelAmounts.of(ParcelOrderModel.fromJson({'id': 'p2', 'subTotal': '1000', 'priceBreakdown': {'total': 1000}}));
      expect(a.options, 0);
      expect(a.total, 1000);
    });
  });
}

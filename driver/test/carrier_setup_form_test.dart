import 'package:driver/utils/carrier_setup_form.dart';
import 'package:driver/utils/carrier_settings_form.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Set up your carrier": what the owner's own carrier is created with.
void main() {
  const price = {'baseCharge': '500', 'perKmCharge': '75', 'perKgCharge': '200', 'minimumCharge': '1000'};
  Map<String, String> texts({String name = 'MK Carrier', String phone = '670000000', String email = '', Map<String, String> extra = const {}}) =>
      {'name': name, 'phone': phone, 'email': email, ...extra};

  ({Map<String, dynamic> data, Map<String, String> errors}) build({
    Map<String, String>? t,
    List<String> regions = const ['R1'],
    List<String> scopes = const ['city', 'intercity'],
    Map<String, Map<String, String>>? prices,
    String logoUrl = '',
  }) =>
      CarrierSetupForm.build(
        ownerId: 'owner1',
        texts: t ?? texts(),
        countryCode: '+237',
        regionIds: regions,
        deliveryScopes: scopes,
        deliveryTimeUnit: 'hours',
        regionTexts: prices ?? {for (final r in regions) r: price},
        logoUrl: logoUrl,
      );

  test('a new carrier waits for the administrator and is bound to its owner', () {
    final r = build();
    expect(r.errors, isEmpty);
    expect(r.data['ownerId'], 'owner1');
    expect(r.data['isVerified'], isFalse);
    expect(r.data['publish'], isFalse);
    expect(r.data['regionIds'], ['R1']);
    expect(r.data['deliveryScopes'], ['city', 'intercity']);
    expect(r.data['countryCode'], '+237');
    expect(r.data['name'], 'MK Carrier');
  });

  test('name, phone, a region and a scope are required', () {
    final r = build(t: texts(name: ' ', phone: ''), regions: const [], scopes: const []);
    expect(r.data, isEmpty);
    expect(r.errors, {
      'name': CarrierSettingsForm.errRequiredName,
      'phone': CarrierSetupForm.errPhone,
      'regionIds': CarrierSetupForm.errRegions,
      'deliveryScopes': CarrierSettingsForm.errScopes,
    });
  });

  test('email is optional but must be valid', () {
    expect(build(t: texts(email: 'not-an-email')).errors, {'email': CarrierSetupForm.errEmail});
    expect(build(t: texts(email: 'ops@carrier.cm')).data['email'], 'ops@carrier.cm');
  });

  test('numbers: blank left out, invalid / negative refused, max time not below min', () {
    expect(build().data.containsKey('maxWeight'), isFalse);
    expect(build(t: texts(extra: {'maxWeight': '30,5'})).data['maxWeight'], 30.5);
    expect(build(t: texts(extra: {'maxWeight': 'abc'})).errors['maxWeight'], CarrierSettingsForm.errNumber);
    expect(build(t: texts(extra: {'maxWeight': '-1'})).errors['maxWeight'], CarrierSettingsForm.errNegative);
    expect(build(t: texts(extra: {'minDeliveryTime': '5', 'maxDeliveryTime': '2'})).errors['maxDeliveryTime'], CarrierSettingsForm.errTimes);
  });

  test('regions are de-duplicated; unknown scopes dropped', () {
    final r = build(regions: const ['R1', 'R1', ' ', 'R2'], scopes: const ['intercountry', 'moon']);
    expect(r.data['regionIds'], ['R1', 'R2']);
    expect(r.data['deliveryScopes'], ['intercountry']);
  });

  test('every selected region gets its prices; the first region is mirrored flat', () {
    final r = build(regions: const ['R1', 'R2'], prices: {
      'R1': price,
      'R2': {'baseCharge': '700', 'perKmCharge': '80', 'perKgCharge': '0', 'minimumCharge': '1200', 'homePickupCharge': '300', 'volumetricDivisor': ''},
    });
    expect(r.errors, isEmpty);
    expect(r.data['regionPricing'], {
      'R1': {'baseCharge': 500, 'perKmCharge': 75, 'perKgCharge': 200, 'minimumCharge': 1000},
      'R2': {'baseCharge': 700, 'perKmCharge': 80, 'perKgCharge': 0, 'minimumCharge': 1200, 'homePickupCharge': 300},
    });
    expect([r.data['baseCharge'], r.data['perKmCharge'], r.data['perKgCharge'], r.data['minimumCharge']], [500, 75, 200, 1000]);
  });

  test('the four prices are required per region; door values optional but valid', () {
    final r = build(prices: {
      'R1': {'baseCharge': '500', 'perKmCharge': '', 'perKgCharge': '-2', 'minimumCharge': '1000', 'homeDeliveryCharge': 'x'},
    });
    expect(r.data, isEmpty);
    expect(r.errors, {
      'R1|perKmCharge': CarrierSetupForm.errPrice,
      'R1|perKgCharge': CarrierSettingsForm.errNegative,
      'R1|homeDeliveryCharge': CarrierSettingsForm.errNumber,
    });
  });

  test('no documents are stored; the logo is optional', () {
    final r = build(logoUrl: 'https://x/logo.jpg');
    expect(r.data['photo'], 'https://x/logo.jpg');
    for (final k in const ['operatingLicence', 'commercialRegister', 'uniqueIdNumber', 'operatingLicenceFile']) {
      expect(r.data.containsKey(k), isFalse, reason: k);
    }
    expect(build().data.containsKey('photo'), isFalse);
  });
}

import 'package:customer/models/parcel_shipping_models.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/utils/address_format.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bug #17 — addresses rendered raw "null" ("123 Yaounde St, null, Tsinga").
void main() {
  group('formatAddressLine', () {
    test('drops a literal "null" component', () {
      expect(formatAddressLine(['123 Yaounde St', 'null', 'Tsinga']), '123 Yaounde St, Tsinga');
    });

    test('drops "null" that is baked into a stored component', () {
      // This is the real shape of the data: the whole line was stored as one
      // reverse-geocoded string in `locality`.
      expect(formatAddressLine(['123 Yaounde St, null, Tsinga']), '123 Yaounde St, Tsinga');
    });

    test('drops empty, whitespace-only and null parts and collapses separators', () {
      expect(formatAddressLine([null, '  ', 'Tsinga', '', 'Yaounde']), 'Tsinga, Yaounde');
      expect(formatAddressLine(['A,,B']), 'A, B');
    });

    test('trims each segment but leaves its inside alone, as the panels do', () {
      expect(formatAddressLine(['  123 Yaounde St  ,  Tsinga ']), '123 Yaounde St, Tsinga');
    });

    test('keeps words that merely contain "null"', () {
      expect(formatAddressLine(['Nullarbor Road']), 'Nullarbor Road');
    });

    test('is empty when nothing survives', () {
      expect(formatAddressLine(['null', ' ', null]), '');
    });

    test('the panel example: baked-in nulls in several fields', () {
      expect(formatAddressLine(['null', '18, null, Yaoundé, Région du Centre, null, Cameroun', 'null']), '18, Yaoundé, Région du Centre, Cameroun');
    });

    test('drops a field repeating an earlier field (case-insensitive, whole field)', () {
      expect(formatAddressLine(['Tsinga, Yaoundé', 'tsinga,  YAOUNDÉ', 'Near the market']), 'Tsinga, Yaoundé, Near the market');
      expect(formatAddressLine(['Tsinga', 'null, Tsinga']), 'Tsinga');
    });

    test('never de-duplicates single segments inside different fields', () {
      expect(formatAddressLine(['Tsinga', '18, Tsinga, Yaoundé']), 'Tsinga, 18, Tsinga, Yaoundé');
    });

    test('keeps Annullata Street', () {
      expect(formatAddressLine(['Annullata Street', 'nil']), 'Annullata Street');
    });
  });

  // BUG-REPORT-01-APP.md section 3 "02#18": the panels' spideliCleanAddressPart /
  // spideliFormatAddress, which this app must match exactly.
  group('cleanAddressPart (spideliCleanAddressPart)', () {
    test('null, empty and whitespace give an empty string', () {
      expect(cleanAddressPart(null), '');
      expect(cleanAddressPart(''), '');
      expect(cleanAddressPart('   '), '');
    });

    test('drops null / undefined / nil segments case-insensitively', () {
      expect(cleanAddressPart('18, NULL, Yaoundé, Undefined, NiL, Cameroun'), '18, Yaoundé, Cameroun');
      expect(cleanAddressPart('null'), '');
      expect(cleanAddressPart(' , null ,undefined, '), '');
    });

    test('keeps words that only contain the letters', () {
      expect(cleanAddressPart('Nullarbor Road, null'), 'Nullarbor Road');
      expect(cleanAddressPart('Annullata Street'), 'Annullata Street');
    });

    test('a non-string value is printed, as String(value) does', () {
      expect(cleanAddressPart(18), '18');
    });
  });

  group('formatAddressMap (spideliFormatAddress)', () {
    test("the report's before / after example", () {
      // before: "null,18, null, Yaoundé, Région du Centre, null, Cameroun null"
      // (address null + locality + landmark null, joined the old way).
      final Map<String, dynamic> address = {'address': null, 'locality': '18, null, Yaoundé, Région du Centre, null, Cameroun', 'landmark': null};
      expect(formatAddressMap(address), '18, Yaoundé, Région du Centre, Cameroun');
      expect(ShippingAddress.fromJson(address).getFullAddress(), '18, Yaoundé, Région du Centre, Cameroun');

      // The old join (`'${address},${locality} ${landmark}'`, the
      // hasOwnProperty guard passing on null) really does print the report's
      // "before" text for this record.
      final String before = '${address['address']},${address['locality']} ${address['landmark']}';
      expect(before, 'null,18, null, Yaoundé, Région du Centre, null, Cameroun null');
    });

    test('Nullarbor Road and Annullata Street survive a full address', () {
      expect(formatAddressMap({'address': 'Nullarbor Road', 'locality': 'null, Annullata Street', 'landmark': 'NULL'}), 'Nullarbor Road, Annullata Street');
    });

    test('the same text in two fields is shown once', () {
      expect(formatAddressMap({'address': 'Tsinga, Yaoundé', 'locality': 'TSINGA, yaoundé', 'landmark': 'Near the market'}), 'Tsinga, Yaoundé, Near the market');
    });

    test('nothing left, or not a map, gives an empty string so the row can be hidden', () {
      expect(formatAddressMap({'address': 'null', 'locality': ' ', 'landmark': 'undefined'}), '');
      expect(formatAddressMap(null), '');
      expect(formatAddressMap('18, Yaoundé'), '');
    });

    test('custom keys, in their order', () {
      expect(formatAddressMap({'street': 'Rue 1', 'city': 'Douala', 'address': 'x'}, keys: const ['city', 'street']), 'Douala, Rue 1');
    });
  });

  group('ShippingAddress.getFullAddress', () {
    test('formats the parts through the shared formatter', () {
      final address = ShippingAddress(address: '123 Yaounde St', locality: 'null, Tsinga', landmark: null);
      expect(address.getFullAddress(), '123 Yaounde St, Tsinga');
    });

    test('does not change what is stored', () {
      final address = ShippingAddress(address: '123 Yaounde St', locality: 'null, Tsinga');
      address.getFullAddress();
      expect(address.locality, 'null, Tsinga');
    });

    test('is empty when the address holds nothing usable', () {
      expect(ShippingAddress(locality: 'null').getFullAddress(), '');
    });
  });

  group('PickupPointModel.subtitle', () {
    test('quarter and town go through the same rule', () {
      expect(PickupPointModel(id: 'p', name: 'P', quarter: 'Akwa', town: 'Douala').subtitle, 'Akwa, Douala');
      expect(PickupPointModel(id: 'p', name: 'P', quarter: 'null', town: 'Douala').subtitle, 'Douala');
      expect(PickupPointModel.fromJson('p', {'name': 'P', 'quarter': null, 'town': 'undefined'}).subtitle, '');
    });
  });
}

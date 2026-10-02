import 'package:driver/models/user_model.dart';
import 'package:driver/utils/address_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AddressFormat.join', () {
    test('drops null and empty parts instead of printing "null"', () {
      expect(AddressFormat.join(['123 Yaounde St', null, 'Tsinga']), '123 Yaounde St, Tsinga');
      expect(AddressFormat.join(['123 Yaounde St', '', '  ', 'Tsinga']), '123 Yaounde St, Tsinga');
    });

    test('drops the literal string "null" a toString() produced', () {
      expect(AddressFormat.join(['123 Yaounde St', 'null', 'Tsinga']), '123 Yaounde St, Tsinga');
    });

    test('never leaves a dangling separator', () {
      expect(AddressFormat.join([null, null, 'Tsinga']), 'Tsinga');
      expect(AddressFormat.join(['Tsinga', null]), 'Tsinga');
      expect(AddressFormat.join([null, null]), '');
    });

    test('collapses a repeated part', () {
      expect(AddressFormat.join(['Tsinga', 'Tsinga', 'Yaounde']), 'Tsinga, Yaounde');
    });

    test('honours a custom separator', () {
      expect(AddressFormat.join(['A', null, 'B'], separator: ' → '), 'A → B');
    });
  });

  group('AddressFormat.clean', () {
    test('removes "null" segments from an already-built string', () {
      expect(AddressFormat.clean('123 Yaounde St, null, Tsinga'), '123 Yaounde St, Tsinga');
    });

    test('removes repeated and trailing separators', () {
      expect(AddressFormat.clean('123 Yaounde St,, Tsinga,'), '123 Yaounde St, Tsinga');
      expect(AddressFormat.clean(', Tsinga'), 'Tsinga');
    });

    test('returns an empty string for nothing worth showing', () {
      expect(AddressFormat.clean(null), '');
      expect(AddressFormat.clean('null'), '');
      expect(AddressFormat.clean('   '), '');
    });
  });

  test('isBlank recognises the values that used to render as text', () {
    expect(AddressFormat.isBlank(null), isTrue);
    expect(AddressFormat.isBlank('null'), isTrue);
    expect(AddressFormat.isBlank(' '), isTrue);
    expect(AddressFormat.isBlank('Tsinga'), isFalse);
  });

  group('02#18 — the panel rule (spideliFormatAddress)', () {
    test('part splits an already-joined value and drops baked-in nulls', () {
      expect(AddressFormat.part('18, null, Yaoundé, Région du Centre, null, Cameroun'), '18, Yaoundé, Région du Centre, Cameroun');
      expect(AddressFormat.part('null, , nil, undefined, -'), isNull);
      expect(AddressFormat.part('  '), isNull);
    });

    test('the panel example: baked-in nulls in several fields', () {
      expect(AddressFormat.join(['null', '18, null, Yaoundé, Région du Centre, null, Cameroun', 'null']), '18, Yaoundé, Région du Centre, Cameroun');
    });

    test('drops whole segments only: words containing "null" survive', () {
      expect(AddressFormat.join(['Nullarbor Road', 'null']), 'Nullarbor Road');
      expect(AddressFormat.join(['Annullata Street', 'nil']), 'Annullata Street');
      expect(AddressFormat.clean('Nullarbor Road, NULL, Annullata Street'), 'Nullarbor Road, Annullata Street');
    });

    test('drops "-" and "undefined" segments', () {
      expect(AddressFormat.join(['12 Rue A, -', 'undefined', 'Douala']), '12 Rue A, Douala');
    });

    test('drops a whole field repeating ANY earlier field, case-insensitively', () {
      expect(AddressFormat.join(['Tsinga, Yaoundé', 'Near the market', 'tsinga,  YAOUNDÉ']), 'Tsinga, Yaoundé, Near the market');
      expect(AddressFormat.join(['Tsinga', 'null, Tsinga']), 'Tsinga');
    });

    test('never de-duplicates single segments inside different fields', () {
      expect(AddressFormat.join(['Tsinga', '18, Tsinga, Yaoundé']), 'Tsinga, 18, Tsinga, Yaoundé');
    });

    test('a custom separator goes between parts only', () {
      expect(AddressFormat.join(['12 Rue A, Douala', '4 Av B, Yaoundé'], separator: ' → '), '12 Rue A, Douala → 4 Av B, Yaoundé');
    });

    test('empty when nothing is left, never ", , "', () {
      expect(AddressFormat.join(['null', ' , ', null, 'nil, undefined']), '');
      expect(AddressFormat.orPlaceholder('null, null'), '—');
    });

    test('ShippingAddress.getFullAddress goes through the rule', () {
      final address = ShippingAddress(address: null, locality: '18, null, Yaoundé, Région du Centre, null, Cameroun', landmark: 'null');
      expect(address.getFullAddress(), '18, Yaoundé, Région du Centre, Cameroun');
      expect(address.locality, '18, null, Yaoundé, Région du Centre, null, Cameroun', reason: 'stored data is untouched');
      expect(ShippingAddress(locality: 'null').getFullAddress(), '');
    });
  });

  group('placemark joins (client point 17 at the source)', () {
    // The driver's own place picker and the parcel search screen build the
    // string that then gets SAVED, which is where "123 Yaounde St, null,
    // Tsinga" comes from in the first place.
    test('a geocoder that returned only some fields produces no "null"', () {
      // street, locality, administrativeArea, country — as Placemark hands them
      // over when the point only resolves partially.
      const List<String?> placemark = <String?>['123 Yaounde St', null, 'Centre', null];
      final String line = AddressFormat.join(placemark);
      expect(line, '123 Yaounde St, Centre');
      expect(line.toLowerCase().contains('null'), isFalse);
    });

    test('a geocoder that returned nothing produces an empty line, not commas', () {
      expect(AddressFormat.join([null, null, null, null]), '');
      expect(AddressFormat.join(['', '', '', '']), '');
    });

    test('a Placemark field holding "null" text is dropped too', () {
      // name, street, subLocality, locality, administrativeArea, postalCode, country
      expect(AddressFormat.join(['18', '18', 'null', 'Yaoundé', 'Région du Centre', '', 'Cameroun']), '18, Yaoundé, Région du Centre, Cameroun');
    });

    test('empty-string placemark fields leave no ", ," run', () {
      expect(AddressFormat.join(['Shop 4', '', '', 'Tsinga', '', 'Cameroon']), 'Shop 4, Tsinga, Cameroon');
    });
  });
}

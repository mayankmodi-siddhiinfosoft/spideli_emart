import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/utils/address_format.dart';

void main() {
  group('spideliCleanAddressPart (mirrors the panels, report 02#18)', () {
    test('null, empty and blank are empty', () {
      expect(spideliCleanAddressPart(null), '');
      expect(spideliCleanAddressPart(''), '');
      expect(spideliCleanAddressPart('   '), '');
    });

    test('drops null / undefined / nil segments in any case', () {
      expect(spideliCleanAddressPart('18, null, Yaoundé, Région du Centre, null, Cameroun'), '18, Yaoundé, Région du Centre, Cameroun');
      expect(spideliCleanAddressPart('NULL, Undefined,NiL'), '');
      expect(spideliCleanAddressPart('A,,  , B'), 'A, B');
    });

    test('drops whole segments only: words containing "null" survive', () {
      expect(spideliCleanAddressPart('Nullarbor Road'), 'Nullarbor Road');
      expect(spideliCleanAddressPart('Annullata Street, null'), 'Annullata Street');
      expect(spideliCleanAddressPart('nil Avenue'), 'nil Avenue');
    });

    test('a number is text', () {
      expect(spideliCleanAddressPart(18), '18');
    });
  });

  group('spideliFormatAddress', () {
    test("the report's before / after example", () {
      // Shown before as "null,18, null, Yaoundé, Région du Centre, null,
      // Cameroun null": address null + "," + the baked-in locality + " " +
      // landmark null.
      final Map<String, dynamic> stored = {'address': null, 'locality': '18, null, Yaoundé, Région du Centre, null, Cameroun', 'landmark': null};
      expect(spideliFormatAddress(stored), '18, Yaoundé, Région du Centre, Cameroun');
    });

    test('the client example "123 Yaounde St, null, Tsinga"', () {
      expect(spideliFormatAddress({'address': '123 Yaounde St', 'locality': 'null', 'landmark': 'Tsinga'}), '123 Yaounde St, Tsinga');
      expect(spideliFormatAddress({'address': '123 Yaounde St, null, Tsinga'}), '123 Yaounde St, Tsinga');
    });

    test('the same text in two fields is shown once (case-insensitive)', () {
      expect(spideliFormatAddress({'address': 'Downtown', 'locality': 'downtown', 'landmark': 'Block 4'}), 'Downtown, Block 4');
    });

    test('returns empty, never ", , ", when nothing is left', () {
      expect(spideliFormatAddress({'address': null, 'locality': '', 'landmark': 'null'}), '');
      expect(spideliFormatAddress(null), '');
      expect(spideliFormatAddress('not a map'), '');
    });

    test('custom keys, in their order', () {
      expect(spideliFormatAddress({'a': 'One', 'b': 'Two'}, ['b', 'a']), 'Two, One');
    });

    test('keeps Nullarbor Road', () {
      expect(spideliFormatAddress({'address': 'Nullarbor Road', 'locality': 'null', 'landmark': 'Annullata Street'}), 'Nullarbor Road, Annullata Street');
    });
  });

  group('formatAddress (the same rule for parts in hand)', () {
    test('drops a missing middle part together with its separator', () {
      expect(formatAddress(['123 Yaounde St', null, 'Tsinga']), '123 Yaounde St, Tsinga');
    });

    test('trims stray leading and trailing separators', () {
      expect(formatAddress(['  , Downtown ,', 'null', 'Block 4']), 'Downtown, Block 4');
    });

    test('returns empty when nothing usable was stored', () {
      expect(formatAddress([null, '', '  ', 'null']), '');
    });
  });

  group('formatLatLng', () {
    test('formats a picked point', () {
      expect(formatLatLng(12.97, 77.5946), '12.97000, 77.59460');
    });

    test('is empty without a point', () {
      expect(formatLatLng(null, 1.0), '');
    });
  });
}

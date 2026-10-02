import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/utils/address_format.dart';

void main() {
  group('formatAddress', () {
    test('drops a missing middle part together with its separator', () {
      expect(formatAddress(['123 Yaounde St', null, 'Tsinga']), '123 Yaounde St, Tsinga');
    });

    test('drops a part stored as the string "null"', () {
      expect(formatAddress(['123 Yaounde St', 'null', 'Tsinga']), '123 Yaounde St, Tsinga');
    });

    test('cleans "null" written inside one stored string', () {
      expect(formatAddress(['123 Yaounde St, null, Tsinga']), '123 Yaounde St, Tsinga');
    });

    test("cleans the client's cancelled-order card address (2 Oct 2026)", () {
      expect(formatAddress(['18, null, Yaoundé, Région du Centre, null, Cameroun', null, 'null']), '18, Yaoundé, Région du Centre, Cameroun');
    });

    test('does not repeat a locality already inside the address line', () {
      expect(formatAddress(['18, Yaoundé, null', 'Yaoundé', 'null']), '18, Yaoundé');
    });

    test('returns empty when nothing usable was stored', () {
      expect(formatAddress([null, '', '  ', 'null']), '');
    });

    test('keeps a repeated part only once', () {
      expect(formatAddress(['Downtown', 'downtown', 'Block 4']), 'Downtown, Block 4');
    });

    test('trims stray leading and trailing separators', () {
      expect(formatAddress(['  , Downtown ,', 'null', 'Block 4']), 'Downtown, Block 4');
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

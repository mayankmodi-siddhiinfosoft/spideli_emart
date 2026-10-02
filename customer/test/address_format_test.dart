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

    test('collapses runs of whitespace inside a component', () {
      expect(formatAddressLine(['123   Yaounde\tSt']), '123 Yaounde St');
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
}

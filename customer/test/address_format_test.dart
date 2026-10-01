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

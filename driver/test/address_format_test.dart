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
}

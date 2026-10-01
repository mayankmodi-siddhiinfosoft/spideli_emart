import 'package:customer/widget/quantity_stepper.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bug #21 — a typed quantity (e.g. 80) replaces eighty taps on "+", and has
/// to land inside what the product allows.
void main() {
  group('clampQuantity', () {
    test('keeps a value inside the range', () {
      expect(clampQuantity(80, minQuantity: 15, maxQuantity: 200), 80);
    });

    test('raises a value below the wholesale pack floor', () {
      expect(clampQuantity(3, minQuantity: 15, maxQuantity: 200), 15);
    });

    test('caps a value above available stock', () {
      expect(clampQuantity(500, minQuantity: 1, maxQuantity: 120), 120);
    });

    test('treats -1 stock as unlimited', () {
      expect(clampQuantity(5000, minQuantity: 1, maxQuantity: -1), 5000);
    });

    test('never returns less than one when zero is not allowed', () {
      expect(clampQuantity(0, minQuantity: 1, maxQuantity: -1), 1);
      expect(clampQuantity(-4, minQuantity: 1, maxQuantity: -1), 1);
    });

    test('zero is kept on a cart line, where it removes the line', () {
      expect(clampQuantity(0, minQuantity: 15, maxQuantity: 200, allowZero: true), 0);
      expect(clampQuantity(-2, minQuantity: 15, maxQuantity: 200, allowZero: true), 0);
    });

    test('a minimum of zero still floors at one', () {
      expect(clampQuantity(1, minQuantity: 0, maxQuantity: -1), 1);
    });
  });
}

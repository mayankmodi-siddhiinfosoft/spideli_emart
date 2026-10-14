import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Amount entry (FinAmountField): what the user types, in major units, to
/// integer minor units, and the message shown under the field.
void main() {
  setUp(() => Get.testMode = true);

  test('parses major units into minor units per currency', () {
    expect(FinanceAmount.parse('1500', 'XAF'), 1500);
    expect(FinanceAmount.parse('1 500', 'XAF'), 1500);
    expect(FinanceAmount.parse('12.5', 'USD'), 1250);
    expect(FinanceAmount.parse('12,50', 'USD'), 1250);
    expect(FinanceAmount.parse('12.5', 'XAF'), isNull, reason: 'XAF has no decimals');
    expect(FinanceAmount.parse('1.234', 'USD'), isNull, reason: 'at most 2 decimals');
    expect(FinanceAmount.parse('0', 'XAF'), isNull);
    expect(FinanceAmount.parse('abc', 'XAF'), isNull);
  });

  test('input shows minor units back in major units', () {
    expect(FinanceAmount.input(1500, 'XAF'), '1500');
    expect(FinanceAmount.input(1250, 'USD'), '12.50');
    expect(FinanceAmount.input(null, 'USD'), '');
  });

  test('the message explains what is wrong', () {
    expect(FinanceAmount.problem('', 'XAF'), isNull, reason: 'nothing typed yet');
    expect(FinanceAmount.problem('0', 'XAF'), 'Enter an amount greater than zero.');
    expect(FinanceAmount.problem('0.00', 'USD'), 'Enter an amount greater than zero.');
    expect(FinanceAmount.problem('12.5', 'XAF'), 'Enter a whole amount, without decimals.');
    expect(FinanceAmount.problem('1.234', 'USD'), contains('2'));
    expect(FinanceAmount.problem('100', 'XAF', min: 500), startsWith('The minimum is'));
    expect(FinanceAmount.problem('900000', 'XAF', max: 500000), startsWith('The maximum is'));
    expect(FinanceAmount.problem('1000', 'XAF', min: 500, max: 500000), isNull);
  });
}

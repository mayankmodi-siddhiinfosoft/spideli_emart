import 'package:customer/models/platform_fee_model.dart';
import 'package:customer/models/tax_model.dart';
import 'package:customer/utils/platform_fee_charge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final List<TaxModel> taxes = [
    TaxModel(title: 'VAT', type: 'percentage', tax: '10', enable: true, scope: 'platform'),
    TaxModel(title: 'Stamp', type: 'fix', tax: '2', enable: true, scope: 'platform'),
  ];

  group('a new checkout (PlatformFeeCharge.of)', () {
    test('a disabled fee is never charged, nor its taxes', () {
      final charge = PlatformFeeCharge.of(PlatformFeeModel(fee: '50', enable: false), taxes);
      expect(charge.charged, isFalse);
      expect(charge.fee, 0);
      expect(charge.taxes, isEmpty);
      expect(charge.taxAmount(), 0);
      expect(charge.feeField, '0.0');
    });

    test('no setting, or enable missing, charges nothing', () {
      expect(PlatformFeeCharge.of(null, taxes).fee, 0);
      expect(PlatformFeeCharge.of(PlatformFeeModel(fee: '50'), taxes).fee, 0);
    });

    test('an enabled fee is charged with its taxes', () {
      final charge = PlatformFeeCharge.of(PlatformFeeModel(fee: '50', enable: true), taxes);
      expect(charge.fee, 50);
      expect(charge.feeField, '50.0');
      expect(charge.taxes.map((t) => t.title), ['VAT', 'Stamp']);
      expect(charge.taxAmount(), closeTo(5 + 2, 1e-9));
    });

    test('an enabled fee of 0, blank or negative charges nothing', () {
      for (final fee in ['0', '', '-5', 'abc', null]) {
        final charge = PlatformFeeCharge.of(PlatformFeeModel(fee: fee, enable: true), taxes);
        expect(charge.fee, 0, reason: '$fee');
        expect(charge.taxes, isEmpty, reason: '$fee');
      }
    });

    test('the taxes are a copy the order may keep and change', () {
      final charge = PlatformFeeCharge.of(PlatformFeeModel(fee: '10', enable: true), taxes);
      charge.taxes.add(TaxModel(title: 'x'));
      expect(taxes.length, 2);
    });
  });

  group('an existing order (PlatformFeeCharge.recorded)', () {
    test('pays and shows exactly what the order recorded', () {
      final charge = PlatformFeeCharge.recorded('20', taxes);
      expect(charge.fee, 20);
      expect(charge.taxAmount(), closeTo(2 + 2, 1e-9));
    });

    test('an order recorded without a fee (disabled) adds nothing, even with stale taxes', () {
      expect(PlatformFeeCharge.recorded('0.0', taxes).taxAmount(), 0);
      expect(PlatformFeeCharge.recorded(null, taxes).fee, 0);
      expect(PlatformFeeCharge.recorded('', taxes).taxes, isEmpty);
    });
  });

  test('amount / parse', () {
    expect(PlatformFeeCharge.amount(enabled: true, fee: 12), 12);
    expect(PlatformFeeCharge.amount(enabled: true, fee: '12.5'), 12.5);
    expect(PlatformFeeCharge.amount(enabled: false, fee: '12.5'), 0);
    expect(PlatformFeeCharge.amount(enabled: null, fee: '12.5'), 0);
    expect(PlatformFeeCharge.parse(' 7 '), 7);
    expect(PlatformFeeCharge.parse(double.infinity), 0);
  });
}

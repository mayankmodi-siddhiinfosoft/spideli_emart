import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/utils/parcel_amounts.dart';
import 'package:flutter_test/flutter_test.dart';

/// The driver's parcel total is the customer's (customer `ParcelAmounts`):
/// the cash a driver collects must reconcile with what the customer was
/// charged, platform fee and receiver-SMS fee included.
void main() {
  Map<String, dynamic> tax(String title, String type, String value, {bool enable = true}) => {'title': title, 'type': type, 'tax': value, 'enable': enable};

  test('every line the customer paid is in the total', () {
    final ParcelAmounts a = ParcelAmounts.of(ParcelOrderModel.fromJson({
      'id': 'p1',
      'subTotal': '1000',
      'discount': '100',
      'taxSetting': [tax('VAT', 'percentage', '10'), tax('Stamp', 'fix', '25')],
      'platformFee': '200',
      'platformTax': [tax('VAT', 'percentage', '5')],
      'parcelScopeTax': 300,
      'sendReceiverSms': true,
      'smsCharge': 50,
    }));
    expect(a.subTotal, 1000);
    expect(a.discount, 100);
    expect(a.orderTax, 115); // 10 % of 900 + 25
    expect(a.platformFee, 200);
    expect(a.platformTax, 10); // 5 % of the fee
    expect(a.scopeTax, 300);
    expect(a.smsCharge, 50);
    expect(a.taxes, 125);
    expect(a.total, 900 + 115 + 200 + 10 + 300 + 50);
    expect(a.platformShareOfCash, 200 + 10 + 300 + 50);
    expect(a.totalText(2), '1575.00');
  });

  test('no platform fee: its taxes are not charged either', () {
    final ParcelAmounts a = ParcelAmounts.of(ParcelOrderModel.fromJson({
      'id': 'p1',
      'subTotal': '500',
      'platformFee': '0.0',
      'platformTax': [tax('VAT', 'fix', '40')],
    }));
    expect(a.platformFee, 0);
    expect(a.platformTax, 0);
    expect(a.total, 500);
  });

  test('a disabled tax, an SMS fee not opted in: not counted', () {
    final ParcelAmounts a = ParcelAmounts.of(ParcelOrderModel.fromJson({
      'id': 'p1',
      'subTotal': '500',
      'taxSetting': [tax('VAT', 'percentage', '10', enable: false)],
      'sendReceiverSms': false,
      'smsCharge': 50,
    }));
    expect(a.orderTax, 0);
    expect(a.smsCharge, 0);
    expect(a.total, 500);
  });

  group('the charged total (priceBreakdown.total) settles whether the platform fee\'s taxes were charged', () {
    // Platform fee setting disabled at checkout: the customer app still
    // writes platformFee and platformTax, adds the fee, but not its taxes.
    Map<String, dynamic> order({Object? total}) => {
          'id': 'p1',
          'subTotal': '1000',
          'taxSetting': [tax('VAT', 'percentage', '10')],
          'platformFee': '20',
          'platformTax': [tax('VAT', 'percentage', '10')],
          'parcelScopeTax': 300,
          'sendReceiverSms': true,
          'smsCharge': 50,
          if (total != null) 'priceBreakdown': {'carrierPrice': 1000, 'total': total, 'smsCharge': 50},
        };

    test('charged without them: not counted — total, cash and the platform\'s share match the checkout', () {
      final ParcelAmounts a = ParcelAmounts.of(ParcelOrderModel.fromJson(order(total: 1000 + 100 + 20 + 300 + 50)));
      expect(a.platformTax, 0);
      expect(a.total, 1470);
      expect(a.platformShareOfCash, 20 + 300 + 50);
      // Stored as text, with the float noise of a double sum.
      expect(ParcelAmounts.of(ParcelOrderModel.fromJson(order(total: '1470.0000000001'))).platformTax, 0);
    });

    test('charged with them, any other total, or none: the lines as they are', () {
      for (final Object? total in [1472, 1500, 'n/a', null]) {
        final ParcelAmounts a = ParcelAmounts.of(ParcelOrderModel.fromJson(order(total: total)));
        expect(a.platformTax, 2, reason: '$total');
        expect(a.total, 1472, reason: '$total');
      }
    });
  });

  test('a record missing every amount prices at 0 instead of throwing', () {
    final ParcelAmounts a = ParcelAmounts.of(ParcelOrderModel.fromJson({'id': 'p1', 'discount': '', 'platformFee': 'abc'}));
    expect(a.total, 0);
    expect(a.platformShareOfCash, 0);
  });
}

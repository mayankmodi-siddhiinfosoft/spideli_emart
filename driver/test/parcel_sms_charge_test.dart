import 'package:driver/models/parcel_order_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Point 54 (BUG-REPORT-01-APP.md §4): the customer app adds `smsCharge` to
/// the parcel total when `sendReceiverSms` is true, so the driver's totals
/// (job card, search card, details) and cash collection must include it.
void main() {
  test('opted in: the fee counts, as a number or a numeric string', () {
    expect(ParcelOrderModel.fromJson({'id': 'p1', 'sendReceiverSms': true, 'smsCharge': 50}).smsChargeAmount, 50);
    expect(ParcelOrderModel.fromJson({'id': 'p1', 'sendReceiverSms': true, 'smsCharge': '75'}).smsChargeAmount, 75);
  });

  test('not opted in, or an order written before point 54: nothing is added', () {
    expect(ParcelOrderModel.fromJson({'id': 'p1', 'sendReceiverSms': false, 'smsCharge': 50}).smsChargeAmount, 0);
    expect(ParcelOrderModel.fromJson({'id': 'p1'}).smsChargeAmount, 0);
    expect(ParcelOrderModel.fromJson({'id': 'p1', 'sendReceiverSms': true}).smsChargeAmount, 0);
  });

  test('read-only here: the driver app never writes the fields back', () {
    final Map<String, dynamic> json = ParcelOrderModel.fromJson({'id': 'p1', 'sendReceiverSms': true, 'smsCharge': 50}).toJson();
    expect(json.containsKey('sendReceiverSms'), isFalse);
    expect(json.containsKey('smsCharge'), isFalse);
  });

  test('server-owned SMS fields and the flat receiver fields never reach toJson (D5)', () {
    final Map<String, dynamic> json = ParcelOrderModel.fromJson({
      'id': 'p1',
      'sendReceiverSms': true,
      'smsCharge': 50,
      'smsSent': {'placed': true},
      'smsOptOut': false,
      'receiverName': 'Awa Njoya',
      'receiverPhone': '677123456',
      'receiverCountryCode': '+237',
      'receiver': {'name': 'Awa', 'phone': '(+237) 677123456', 'address': 'Yaounde'},
    }).toJson();
    for (final String key in const ['smsSent', 'smsOptOut', 'receiverName', 'receiverPhone', 'receiverCountryCode', 'sendReceiverSms', 'smsCharge']) {
      expect(json.containsKey(key), isFalse, reason: key);
    }
    // The receiver map itself is unchanged.
    expect(json['receiver'], {'address': 'Yaounde', 'name': 'Awa', 'phone': '(+237) 677123456'});
  });

  group('receiver display (app-spec-parcel-sms.md)', () {
    test('flat fields first, the phone with its dialling code', () {
      final ParcelOrderModel o = ParcelOrderModel.fromJson({
        'id': 'p1',
        'receiverName': ' Awa Njoya ',
        'receiverPhone': '677123456',
        'receiverCountryCode': '+237',
        'receiver': {'name': 'Someone else', 'phone': '(+237) 600000000'},
      });
      expect(o.receiverNameDisplay, 'Awa Njoya');
      expect(o.receiverPhoneDisplay, '+237 677123456');
      expect(o.receiverDialNumber, '+237677123456');
    });

    test('an order with only the receiver map (older app build)', () {
      final ParcelOrderModel o = ParcelOrderModel.fromJson({
        'id': 'p1',
        'receiver': {'name': 'Awa', 'phone': '(+237) 677 12 34 56'},
      });
      expect(o.receiverNameDisplay, 'Awa');
      expect(o.receiverPhoneDisplay, '(+237) 677 12 34 56');
      expect(o.receiverDialNumber, '+237677123456');
    });

    test('a panel order with flat fields only, or a phone without its code', () {
      final ParcelOrderModel flatOnly = ParcelOrderModel.fromJson({'id': 'p1', 'receiverName': 'Awa', 'receiverPhone': '677123456', 'receiverCountryCode': '+237'});
      expect(flatOnly.receiverNameDisplay, 'Awa');
      expect(flatOnly.receiverPhoneDisplay, '+237 677123456');
      final ParcelOrderModel noCode = ParcelOrderModel.fromJson({'id': 'p1', 'receiverPhone': 677123456});
      expect(noCode.receiverPhoneDisplay, '677123456');
      expect(noCode.receiverDialNumber, '677123456');
    });

    test('nothing known: empty, so the row is hidden', () {
      final ParcelOrderModel o = ParcelOrderModel.fromJson({'id': 'p1'});
      expect(o.receiverNameDisplay, '');
      expect(o.receiverPhoneDisplay, '');
      expect(o.receiverDialNumber, '');
    });
  });
}

import 'package:customer/models/parcel_order_model.dart';
import 'package:customer/service/parcel_receiver_sms.dart';
import 'package:customer/utils/parcel_receipt_pdf.dart' show ParcelAmounts;
import 'package:flutter_test/flutter_test.dart';

/// Point 54 (BUG-REPORT-01-APP.md section 4 "Parcel receiver SMS",
/// app-spec-parcel-sms.md): the sender may pay `regions/{regionId}.parcelSmsFee`
/// of their region (50 when unset, 0 = free) for the receiver to be told by
/// SMS; checkout writes `sendReceiverSms` and `smsCharge` (0 when off), and
/// booking writes the receiver as flat fields. The app never composes the
/// message and never writes `smsSent` (the server-side trigger does).
void main() {
  group('regions/{regionId}.parcelSmsFee', () {
    test('50 when the field or the region document is missing', () {
      expect(ParcelReceiverSms.feeFrom(null), 50);
      expect(ParcelReceiverSms.feeFrom(const {}), 50);
      expect(ParcelReceiverSms.feeFrom(const {'parcelSmsFee': null}), 50);
    });

    test('a number or a numeric string', () {
      expect(ParcelReceiverSms.feeFrom(const {'parcelSmsFee': 75}), 75);
      expect(ParcelReceiverSms.feeFrom(const {'parcelSmsFee': '100'}), 100);
      expect(ParcelReceiverSms.feeFrom(const {'parcelSmsFee': '62,5'}), 62.5);
      expect(ParcelReceiverSms.feeFrom(const {'parcelSmsFee': 0}), 0);
    });

    test('unreadable or negative falls back to the default', () {
      expect(ParcelReceiverSms.feeFrom(const {'parcelSmsFee': 'abc'}), 50);
      expect(ParcelReceiverSms.feeFrom(const {'parcelSmsFee': -5}), 50);
    });
  });

  group('the order fields', () {
    test('opted in: both fields are written and the fee joins the total', () {
      final ParcelOrderModel order = ParcelOrderModel(subTotal: '1000', discount: '0', platformFee: '0')
        ..sendReceiverSms = true
        ..smsCharge = 50;
      final Map<String, dynamic> json = order.toJson();
      expect(json['sendReceiverSms'], isTrue);
      expect(json['smsCharge'], 50);
      expect(order.smsChargeAmount, 50);
      expect(ParcelAmounts.of(order).total, 1050);
    });

    test('not ticked: false and a charge of 0, nothing added', () {
      final ParcelOrderModel order = ParcelOrderModel(subTotal: '1000', discount: '0', platformFee: '0')
        ..sendReceiverSms = false
        ..smsCharge = 0;
      final Map<String, dynamic> json = order.toJson();
      expect(json['sendReceiverSms'], isFalse);
      expect(json['smsCharge'], 0);
      expect(ParcelAmounts.of(order).total, 1000);
    });

    test('read back from Firestore', () {
      final ParcelOrderModel order = ParcelOrderModel.fromJson({'id': 'p1', 'subTotal': '1000', 'sendReceiverSms': true, 'smsCharge': '50'});
      expect(order.sendReceiverSms, isTrue);
      expect(order.smsChargeAmount, 50);
    });

    test('an order written before point 54 neither shows nor rewrites the fields', () {
      final ParcelOrderModel order = ParcelOrderModel.fromJson({'id': 'p1', 'subTotal': '1000'});
      expect(order.smsChargeAmount, 0);
      final Map<String, dynamic> json = order.toJson();
      expect(json.containsKey('sendReceiverSms'), isFalse);
      expect(json.containsKey('smsCharge'), isFalse);
    });

    test('server-owned fields are never written back by the app', () {
      final ParcelOrderModel order = ParcelOrderModel.fromJson({
        'id': 'p1',
        'subTotal': '1000',
        'smsSent': {'placed': true},
        'smsOptOut': true,
        'rejectedByDrivers': ['d1'],
      });
      expect(order.smsOptOut, isTrue);
      expect(order.smsSent, {'placed': true}, reason: 'read, for the cancel refund');
      expect(order.receiverSmsWasSent, isTrue);
      final Map<String, dynamic> json = order.toJson();
      expect(json.containsKey('smsSent'), isFalse);
      expect(json.containsKey('smsOptOut'), isFalse, reason: 'written once, at creation, by ParcelShippingService.save');
      expect(json.containsKey('rejectedByDrivers'), isFalse, reason: "the dispatch's exclusion list");
      expect(order.shippingJson().containsKey('smsSent'), isFalse);
    });
  });

  group('flat receiver fields', () {
    test('written next to the receiver map when set', () {
      final ParcelOrderModel order = ParcelOrderModel(id: 'p1')
        ..receiver = LocationInformation(name: 'Awa Njoya', phone: '(+237) 677123456')
        ..receiverName = 'Awa Njoya'
        ..receiverPhone = '677123456'
        ..receiverCountryCode = '+237';
      final Map<String, dynamic> json = order.toJson();
      expect(json['receiverName'], 'Awa Njoya');
      expect(json['receiverPhone'], '677123456');
      expect(json['receiverCountryCode'], '+237');
      expect(json['receiver']['phone'], '(+237) 677123456');
    });

    test('absent ones are never written, so no update can clear them', () {
      final Map<String, dynamic> json = ParcelOrderModel.fromJson({'id': 'p1'}).toJson();
      expect(json.containsKey('receiverName'), isFalse);
      expect(json.containsKey('receiverPhone'), isFalse);
      expect(json.containsKey('receiverCountryCode'), isFalse);
    });

    test('display: the flat fields when both exist (website / panel orders), else the map', () {
      final ParcelOrderModel web = ParcelOrderModel.fromJson({
        'id': 'p1',
        'receiver': {'name': 'Awa', 'phone': '677123456'},
        'receiverName': 'Awa Njoya',
        'receiverPhone': '677123456',
        'receiverCountryCode': '+237',
      });
      expect(web.receiverPhoneDisplay, '+237 677123456');
      expect(web.receiverNameDisplay, 'Awa Njoya');

      final ParcelOrderModel old = ParcelOrderModel.fromJson({
        'id': 'p2',
        'receiver': {'name': 'Ben', 'phone': '(+237) 699000000'},
      });
      expect(old.receiverPhoneDisplay, '(+237) 699000000');
      expect(old.receiverNameDisplay, 'Ben');
    });
  });

  group("the receiver's number", () {
    test('dialling code from the country picker', () {
      expect(ParcelReceiverSms.dialCode('+237'), '+237');
      expect(ParcelReceiverSms.dialCode(' 237 '), '+237');
      expect(ParcelReceiverSms.dialCode('+1'), '+1');
      expect(ParcelReceiverSms.dialCode(''), isNull);
      expect(ParcelReceiverSms.dialCode(null), isNull);
      expect(ParcelReceiverSms.dialCode('CM'), isNull, reason: 'an ISO code is not a dialling code');
      expect(ParcelReceiverSms.dialCode('+2371'), isNull);
      expect(ParcelReceiverSms.dialCode('+12345'), isNull);
    });

    test("the picker's 4-digit North American codes are dialling codes", () {
      for (final String code in ['+1876', '+1242', '+1246', '+1787', '+1939', '+1868']) {
        expect(ParcelReceiverSms.dialCode(code), code);
      }
      expect(ParcelReceiverSms.validationError(countryCode: '+1876', mobile: '5551234'), isNull, reason: 'Jamaica');
      expect(ParcelReceiverSms.nationalNumber('555 1234', countryCode: '+1876'), '5551234');
    });

    test('national number: digits only, without a trunk zero', () {
      expect(ParcelReceiverSms.nationalNumber('677 12 34 56'), '677123456');
      expect(ParcelReceiverSms.nationalNumber('0677123456'), '677123456');
      expect(ParcelReceiverSms.nationalNumber('0677123456', countryCode: '+237'), '677123456');
      expect(ParcelReceiverSms.nationalNumber('07700 900123', countryCode: '+44'), '7700900123');
      expect(ParcelReceiverSms.nationalNumber(''), '');
    });

    test('national number: a leading 0 that belongs to the number is kept', () {
      expect(ParcelReceiverSms.nationalNumber('06 123 4567', countryCode: '+242'), '061234567', reason: 'Congo-Brazzaville');
      expect(ParcelReceiverSms.nationalNumber('06 12 34 56', countryCode: '+241'), '06123456', reason: 'Gabon');
      expect(ParcelReceiverSms.nationalNumber('07 12 34 56 78', countryCode: '+225'), '0712345678', reason: "Cote d'Ivoire");
      expect(ParcelReceiverSms.nationalNumber('06 1234 5678', countryCode: ' 39 '), '0612345678', reason: 'Italian landline');
      expect(ParcelReceiverSms.validationError(countryCode: '+242', mobile: '061234567'), isNull);
    });

    test('validation: present, with a country code, of a plausible length', () {
      expect(ParcelReceiverSms.validationError(countryCode: '+237', mobile: '677123456'), isNull);
      expect(ParcelReceiverSms.validationError(countryCode: '+237', mobile: ''), 'Please enter receiver mobile');
      expect(ParcelReceiverSms.validationError(countryCode: '', mobile: '677123456'), "Please select the receiver's country code");
      expect(ParcelReceiverSms.validationError(countryCode: 'CM', mobile: '677123456'), "Please select the receiver's country code");
      expect(ParcelReceiverSms.validationError(countryCode: '+237', mobile: '12345'), 'Please enter a valid receiver mobile number');
      expect(ParcelReceiverSms.validationError(countryCode: '+237', mobile: '1234567890123'), 'Please enter a valid receiver mobile number', reason: 'more than 15 digits with the country code');
    });
  });
}

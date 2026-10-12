import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/lang/app_ar.dart';
import 'package:driver/lang/app_de.dart';
import 'package:driver/lang/app_en.dart';
import 'package:driver/lang/app_fr.dart';
import 'package:driver/lang/app_hi.dart';
import 'package:driver/lang/app_ja.dart';
import 'package:driver/lang/app_pt.dart';
import 'package:driver/lang/app_ru.dart';
import 'package:driver/lang/app_zh.dart';
import 'package:driver/models/company_cash_model.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/services/carrier_parcel_rules.dart';
import 'package:driver/services/dispatch_offer_rules.dart';
import 'package:driver/services/parcel_flow_rules.dart';
import 'package:driver/utils/parcel_amounts.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parcel end-to-end check of 12 Oct 2026 (driver side).
void main() {
  group('Pickup Parcel only moves this driver\'s accepted job to In Transit', () {
    Map<String, dynamic> order(String status, {String driver = 'd1', String? parcelStatus}) =>
        {'status': status, 'driverId': driver, 'driverID': driver, 'parcelStatus': ?parcelStatus};

    test('accepted / shipped -> In Transit; already In Transit writes nothing', () {
      expect(ParcelPickupRules.pickupFields(order('Driver Accepted'), 'd1'), {'status': 'In Transit'});
      expect(ParcelPickupRules.pickupFields(order('Order Shipped'), 'd1'), {'status': 'In Transit'});
      expect(ParcelPickupRules.pickupFields(order('In Transit'), 'd1'), isEmpty);
    });

    test('never a cancelled, completed, pending, returned or someone else\'s parcel', () {
      expect(ParcelPickupRules.pickupFields(order('Order Cancelled'), 'd1'), isNull);
      expect(ParcelPickupRules.pickupFields(order('Order Completed'), 'd1'), isNull);
      expect(ParcelPickupRules.pickupFields(order('Driver Pending'), 'd1'), isNull);
      expect(ParcelPickupRules.pickupFields(order('Driver Accepted', parcelStatus: 'Cancelled'), 'd1'), isNull);
      expect(ParcelPickupRules.pickupFields(order('Driver Accepted', parcelStatus: 'Returned'), 'd1'), isNull);
      expect(ParcelPickupRules.pickupFields(order('Driver Accepted', driver: 'd2'), 'd1'), isNull);
      expect(ParcelPickupRules.pickupFields(null, 'd1'), isNull);
    });
  });

  group('parcel progress pushes are templates', () {
    test('customer templates by tracking step', () {
      expect(ParcelStatusPush.customerTemplate('Collected'), 'parcel_picked_up');
      expect(ParcelStatusPush.customerTemplate('In transit'), 'parcel_in_transit');
      expect(ParcelStatusPush.customerTemplate('Arrived destination'), 'parcel_arrived_destination');
      expect(ParcelStatusPush.customerTemplate('Delivered'), isNull); // parcel_completed, on completion
    });
    test('the owner: the carrier company, else the driver\'s company; a tap opens Orders', () {
      expect(ParcelStatusPush.ownerToNotify(carrierOwnerId: 'own', driverOwnerId: 'x'), 'own');
      expect(ParcelStatusPush.ownerToNotify(carrierOwnerId: '', driverOwnerId: 'fleet'), 'fleet');
      expect(ParcelStatusPush.ownerToNotify(), '');
      expect(CarrierParcelRules.ownerPushTypes, contains(ParcelStatusPush.ownerPushType));
    });
  });

  group('parcel search lists only open parcels for this driver', () {
    test('Order Placed naming nobody: listed', () {
      expect(DispatchOrderRules.listedInParcelSearch({'status': 'Order Placed'}, 'me'), isTrue);
    });
    test('never one naming another driver, passed on, pending, or a carrier parcel', () {
      expect(DispatchOrderRules.listedInParcelSearch({'status': 'Order Placed', 'driverId': 'other'}, 'me'), isFalse);
      expect(DispatchOrderRules.listedInParcelSearch({'status': 'Order Placed', 'rejectedByDrivers': ['me']}, 'me'), isFalse);
      expect(DispatchOrderRules.listedInParcelSearch({'status': 'Driver Pending', 'driverId': 'me'}, 'me'), isFalse);
      expect(DispatchOrderRules.listedInParcelSearch({'status': 'Order Placed', 'carrierId': 'c1'}, 'me'), isFalse);
      expect(DispatchOrderRules.listedInParcelSearch({'status': 'Order Placed', 'carrierOwnerId': 'own'}, 'me'), isFalse);
    });
  });

  group('company money', () {
    test('a company driver\'s parcel pays the company wallet, even without a driver snapshot', () {
      expect(ParcelAmounts.walletUserFor(snapshotOwnerId: 'own', myOwnerId: null, myUid: 'd1'), 'own');
      expect(ParcelAmounts.walletUserFor(snapshotOwnerId: null, myOwnerId: 'own', myUid: 'd1'), 'own');
      expect(ParcelAmounts.walletUserFor(snapshotOwnerId: '', myOwnerId: '', myUid: 'd1'), 'd1');
    });

    test('report net revenue deducts the SMS fee like the wallet does', () {
      final ParcelAmounts a = ParcelAmounts.of(ParcelOrderModel.fromJson({
        'id': 'p', 'subTotal': '1000', 'platformFee': '100', 'parcelScopeTax': 500, 'sendReceiverSms': true, 'smsCharge': 50,
      }));
      expect(a.total, 1650);
      expect(a.courierNet(100), 1000 - 100); // 1650 - (100 + 500 + 50) - 100
    });

    test('cash ledger lists are sorted on the device (no composite index)', () {
      CompanyCashTransactionModel tx(String id, int? ms) => CompanyCashTransactionModel(id: id, createdAt: ms == null ? null : Timestamp.fromMillisecondsSinceEpoch(ms));
      expect(CompanyCashTransactionModel.newestFirst([tx('a', 1000), tx('b', null), tx('c', 3000)]).map((t) => t.id), ['c', 'a', 'b']);
    });
  });

  test('order card date never needs a "!" (website / panel orders)', () {
    expect(ParcelOrderModel.fromJson({'id': 'x'}).orderDateStamp, isNull);
    final Timestamp t = Timestamp.fromMillisecondsSinceEpoch(5000);
    expect(ParcelOrderModel.fromJson({'id': 'x', 'createdAt': t}).orderDateStamp, t);
    expect(ParcelOrderModel.fromJson({'id': 'x', 'isSchedule': true, 'senderPickupDateTime': t}).orderDateStamp, t);
  });

  test('parcel order statuses and the pickup refusal are translated in all 9 languages', () {
    const keys = [
      'Order Placed', 'Driver Pending', 'Driver Rejected', 'Driver Accepted', 'Order Accepted', 'Order Shipped', 'In Transit',
      'Order Completed', 'Order Cancelled', 'Order Rejected', 'Quote Requested', 'This parcel can no longer be picked up.',
    ];
    final Map<String, Map<String, String>> langs = {'en': enUS, 'ar': lnAr, 'de': deGR, 'fr': trFR, 'hi': hiIN, 'ja': jaJP, 'pt': ptPO, 'ru': ruRU, 'zh': zhCH};
    langs.forEach((lang, map) {
      for (final String k in keys) {
        expect(map.containsKey(k), isTrue, reason: '$lang: $k');
      }
    });
  });
}

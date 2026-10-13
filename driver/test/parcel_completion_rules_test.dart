import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/services/parcel_flow_rules.dart';
import 'package:driver/services/wallet_once.dart';
import 'package:flutter_test/flutter_test.dart';

/// A parcel's completion and its earnings: claimed once, credited once per
/// movement, never lost (the order stays `creditPending` until credited).
void main() {
  const me = 'driver1';
  Map<String, dynamic> order({String status = 'In Transit', String? parcelStatus = 'Delivered', bool? credited, bool? pending, String driver = me}) => {
        'id': 'o1',
        'status': status,
        'parcelStatus': ?parcelStatus,
        'driverId': driver,
        'driverID': driver,
        'driverCredited': ?credited,
        'creditPending': ?pending,
      };

  group('claimDecision', () {
    test('an active parcel is claimed: Order Completed with creditPending, not yet credited', () {
      expect(ParcelCompletionRules.claimDecision(order(), me), ParcelCompletionClaim.claim);
      expect(ParcelCompletionRules.claimFields, {'status': 'Order Completed', 'creditPending': true});
      expect(ParcelCompletionRules.claimFields.containsKey('driverCredited'), isFalse);
    });

    test('completed with earnings still owed: resumed by the assigned driver only', () {
      expect(ParcelCompletionRules.claimDecision(order(status: 'Order Completed', pending: true), me), ParcelCompletionClaim.resume);
      expect(ParcelCompletionRules.claimDecision(order(status: 'Order Completed', pending: true), 'someone'), ParcelCompletionClaim.refused);
    });

    test('credited, or completed before this flow (no marker): never paid again', () {
      expect(ParcelCompletionRules.claimDecision(order(status: 'Order Completed', credited: true, pending: false), me), ParcelCompletionClaim.refused);
      expect(ParcelCompletionRules.claimDecision(order(status: 'Order Completed'), me), ParcelCompletionClaim.refused);
      expect(ParcelCompletionRules.claimDecision(order(credited: true), me), ParcelCompletionClaim.refused);
    });

    test('cancelled, rejected, returned or gone: refused', () {
      expect(ParcelCompletionRules.claimDecision(order(status: 'Order Cancelled'), me), ParcelCompletionClaim.refused);
      expect(ParcelCompletionRules.claimDecision(order(status: 'Order Rejected'), me), ParcelCompletionClaim.refused);
      expect(ParcelCompletionRules.claimDecision(order(parcelStatus: 'Cancelled'), me), ParcelCompletionClaim.refused);
      expect(ParcelCompletionRules.claimDecision(order(parcelStatus: 'Returned'), me), ParcelCompletionClaim.refused);
      expect(ParcelCompletionRules.claimDecision(null, me), ParcelCompletionClaim.refused);
    });

    test('credited marks the end of the owed earnings', () {
      expect(ParcelCompletionRules.creditedFields, {'driverCredited': true, 'creditPending': false});
    });
  });

  test('every wallet movement of an order has one fixed row id per purpose', () {
    final ids = [
      ParcelCompletionRules.credit,
      ParcelCompletionRules.commission,
      ParcelCompletionRules.fixedTax,
      ParcelCompletionRules.smsFee,
      ParcelCompletionRules.platformFee,
    ].map((p) => ParcelCompletionRules.walletRowId(p, 'o1')).toList();
    expect(ids, ['parcel_credit_o1', 'parcel_commission_o1', 'parcel_fixed_tax_o1', 'parcel_sms_fee_o1', 'parcel_platform_fee_o1']);
    expect(ids.toSet().length, ids.length);
    expect(ParcelCompletionRules.walletRowId(ParcelCompletionRules.credit, 'o1'), ParcelCompletionRules.walletRowId(ParcelCompletionRules.credit, 'o1'));
  });

  test('referral rows: one per order and kind, distinct from the delivery referral', () {
    expect(WalletOnce.referralRowIdFor('parcel', 'o1'), 'referral_parcel_o1');
    expect(WalletOnce.referralRowIdFor('cab', 'o1'), 'referral_cab_o1');
    expect(WalletOnce.referralRowIdFor('rental', 'o1'), 'referral_rental_o1');
    expect(WalletOnce.referralRowIdFor('parcel', 'o1'), isNot(WalletOnce.referralRowId('o1')));
  });

  test('the order model reads creditPending', () {
    expect(ParcelOrderModel.fromJson(order(status: 'Order Completed', pending: true)).creditPending, isTrue);
    expect(ParcelOrderModel.fromJson(order()).creditPending, isFalse);
  });
}

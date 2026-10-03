import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/utils/store_credit_once.dart';

/// The store is credited once per order, whichever of the Store and Driver
/// apps completes it - the rule both apps run inside their transaction.
void main() {
  Map<String, dynamic> row({String user = 'vendor', bool topUp = true, String method = 'Wallet'}) =>
      {'transactionUser': user, 'isTopUp': topUp, 'payment_method': method, 'order_id': 'o1'};

  group('row ids', () {
    test('are deterministic and the ones the Driver app already writes', () {
      expect(StoreCreditOnce.creditRowId('o1'), 'vendorcredit_o1');
      expect(StoreCreditOnce.taxRowId('o1'), 'vendortax_o1');
      expect(StoreCreditOnce.creditRowId('o1'), StoreCreditOnce.creditRowId('o1'));
      expect(StoreCreditOnce.creditRowId('o1'), isNot(StoreCreditOnce.taxRowId('o1')));
    });

    test('do not collide with the other once-per-order wallet rows', () {
      for (final String other in ['cashback_o1', 'driver_o1', 'referral_o1']) {
        expect(StoreCreditOnce.creditRowId('o1'), isNot(other));
        expect(StoreCreditOnce.taxRowId('o1'), isNot(other));
      }
    });
  });

  group('isCreditRow (orders credited by an older build, random row ids)', () {
    test('the order-amount credit row counts', () {
      expect(StoreCreditOnce.isCreditRow(row()), isTrue);
    });

    test('a tax row, a reversal, a customer row or nothing does not', () {
      expect(StoreCreditOnce.isCreditRow(row(method: 'tax')), isFalse);
      expect(StoreCreditOnce.isCreditRow(row(topUp: false)), isFalse);
      expect(StoreCreditOnce.isCreditRow(row(user: 'user')), isFalse);
      expect(StoreCreditOnce.isCreditRow(row(user: 'driver')), isFalse);
      expect(StoreCreditOnce.isCreditRow(null), isFalse);
      expect(StoreCreditOnce.isCreditRow(const {}), isFalse);
    });

    test('a credited then refunded order stays credited (not paid again)', () {
      expect(StoreCreditOnce.anyCreditRow([row(), row(method: 'tax'), row(topUp: false), row(method: 'tax', topUp: false)]), isTrue);
    });

    test('an order with only customer or driver rows is not credited', () {
      expect(StoreCreditOnce.anyCreditRow([row(user: 'user'), row(user: 'driver'), null]), isFalse);
      expect(StoreCreditOnce.anyCreditRow(const []), isFalse);
    });
  });

  group('alreadyCredited (inside the transaction)', () {
    test('pays when neither the credit row nor the flag is there', () {
      expect(StoreCreditOnce.alreadyCredited(creditRowExists: false, order: {'status': 'Order Completed'}), isFalse);
      expect(StoreCreditOnce.alreadyCredited(creditRowExists: false, order: {'vendorCredited': false}), isFalse);
      expect(StoreCreditOnce.alreadyCredited(creditRowExists: false, order: null), isFalse);
    });

    test('the credit row alone stops a second payment', () {
      expect(StoreCreditOnce.alreadyCredited(creditRowExists: true, order: {'status': 'Order Completed'}), isTrue);
      expect(StoreCreditOnce.alreadyCredited(creditRowExists: true, order: null), isTrue);
    });

    test('the order flag alone stops a second payment', () {
      expect(StoreCreditOnce.alreadyCredited(creditRowExists: false, order: {StoreCreditOnce.orderFlag: true}), isTrue);
      expect(StoreCreditOnce.orderFlag, 'vendorCredited');
    });

    test('store and driver racing: whichever transaction runs second pays nothing', () {
      // Firestore re-runs the losing transaction against what the winner
      // committed: the credit row and the flag.
      final Map<String, dynamic> order = {'status': 'Order Completed'};
      bool rowExists = false;
      int payments = 0;
      void run() {
        if (StoreCreditOnce.alreadyCredited(creditRowExists: rowExists, order: order)) return;
        payments++;
        rowExists = true;
        order[StoreCreditOnce.orderFlag] = true;
      }

      run(); // Store app
      run(); // Driver app, re-run after the conflict
      run(); // a retry after a crash
      expect(payments, 1);
    });
  });
}

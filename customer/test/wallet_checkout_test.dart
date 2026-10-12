import 'package:customer/lang/app_ar.dart';
import 'package:customer/lang/app_en.dart';
import 'package:customer/utils/wallet_checkout.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake of `FireStoreUtils.payFromWallet`: one atomic commit of the debit,
/// the wallet row and the order writes, refused as a whole.
class _FakeStore {
  _FakeStore(this.balance, {this.failCommit = false});

  num balance;
  final bool failCommit;
  final List<String> walletRows = [];
  final Map<String, Map<String, dynamic>> orders = {};
  final List<String> log = [];

  Future<WalletPayOutcome> payFromWallet({required num amount, required String rowId, required String orderId, required Map<String, dynamic> order}) async {
    log.add('commit');
    if (failCommit) throw StateError('offline');
    final num? next = WalletCheckout.debitedBalance(balance: balance, amount: amount);
    if (amount > 0 && next == null) return WalletPayOutcome.insufficient;
    // All or nothing, as in the Firestore transaction.
    if (amount > 0) {
      balance = next!;
      walletRows.add(rowId);
    }
    orders[orderId] = order;
    return WalletPayOutcome.paid;
  }
}

void main() {
  group('WalletCheckout.debitedBalance', () {
    test('debits a sufficient balance', () {
      expect(WalletCheckout.debitedBalance(balance: 100, amount: 30), 70);
      expect(WalletCheckout.debitedBalance(balance: '100', amount: 100), 0);
      expect(WalletCheckout.debitedBalance(balance: 50.5, amount: 0.5), 50);
    });

    test('refuses a shortfall, an unreadable balance or a non-positive amount', () {
      expect(WalletCheckout.debitedBalance(balance: 29.99, amount: 30), isNull);
      expect(WalletCheckout.debitedBalance(balance: null, amount: 1), isNull);
      expect(WalletCheckout.debitedBalance(balance: '', amount: 1), isNull);
      expect(WalletCheckout.debitedBalance(balance: 'abc', amount: 1), isNull);
      expect(WalletCheckout.debitedBalance(balance: 100, amount: 0), isNull);
      expect(WalletCheckout.debitedBalance(balance: 100, amount: -5), isNull);
      expect(WalletCheckout.debitedBalance(balance: 100, amount: double.nan), isNull);
    });

    test('float noise is not a shortfall and never leaves a negative balance', () {
      expect(WalletCheckout.debitedBalance(balance: 0.1 + 0.2, amount: 0.3), isNotNull);
      expect(WalletCheckout.debitedBalance(balance: 0.3, amount: 0.1 + 0.2), 0);
    });
  });

  group('WalletCheckout.pay sequencing', () {
    test('paid: the order and the debit are in, then the side effects run once', () async {
      final store = _FakeStore(100);
      final List<String> sideEffects = [];
      final outcome = await WalletCheckout.pay(
        commit: () => store.payFromWallet(amount: 40, rowId: 'w1', orderId: 'o1', order: {'status': 'Order Placed'}),
        afterPaid: () async {
          // Pushes / emails see the saved, paid order.
          expect(store.orders.containsKey('o1'), isTrue);
          expect(store.balance, 60);
          sideEffects.add('push');
        },
      );
      expect(outcome, WalletPayOutcome.paid);
      expect(sideEffects, ['push']);
      expect(store.walletRows, ['w1']);
    });

    test('insufficient: no money taken, no order, no push', () async {
      final store = _FakeStore(10);
      var pushed = false;
      final outcome = await WalletCheckout.pay(
        commit: () => store.payFromWallet(amount: 40, rowId: 'w1', orderId: 'o1', order: {}),
        afterPaid: () async => pushed = true,
      );
      expect(outcome, WalletPayOutcome.insufficient);
      expect(store.balance, 10);
      expect(store.walletRows, isEmpty);
      expect(store.orders, isEmpty);
      expect(pushed, isFalse);
    });

    test('a failed commit (offline, refused) takes nothing and sends nothing', () async {
      final store = _FakeStore(100, failCommit: true);
      var pushed = false;
      final outcome = await WalletCheckout.pay(
        commit: () => store.payFromWallet(amount: 40, rowId: 'w1', orderId: 'o1', order: {}),
        afterPaid: () async => pushed = true,
      );
      expect(outcome, WalletPayOutcome.failed);
      expect(store.balance, 100);
      expect(store.orders, isEmpty);
      expect(pushed, isFalse);
    });

    test('a side effect that throws never turns a paid order into a failure', () async {
      final store = _FakeStore(100);
      final outcome = await WalletCheckout.pay(
        commit: () => store.payFromWallet(amount: 40, rowId: 'w1', orderId: 'o1', order: {}),
        afterPaid: () async => throw StateError('push failed'),
      );
      expect(outcome, WalletPayOutcome.paid);
      expect(store.balance, 60);
      expect(store.orders.keys, ['o1']);
    });

    test('a fully discounted order (0) is saved without a debit or a wallet row', () async {
      final store = _FakeStore(5);
      final outcome = await WalletCheckout.pay(commit: () => store.payFromWallet(amount: 0, rowId: 'w1', orderId: 'o1', order: {}));
      expect(outcome, WalletPayOutcome.paid);
      expect(store.balance, 5);
      expect(store.walletRows, isEmpty);
      expect(store.orders.keys, ['o1']);
    });

    test('a retry after a refusal pays once', () async {
      final store = _FakeStore(30);
      final first = await WalletCheckout.pay(commit: () => store.payFromWallet(amount: 40, rowId: 'w1', orderId: 'o1', order: {}));
      expect(first, WalletPayOutcome.insufficient);
      store.balance = 50; // topped up
      final second = await WalletCheckout.pay(commit: () => store.payFromWallet(amount: 40, rowId: 'w2', orderId: 'o1', order: {}));
      expect(second, WalletPayOutcome.paid);
      expect(store.walletRows, ['w2']);
      expect(store.balance, 10);
    });
  });

  test('every failure message is translated', () {
    for (final outcome in [WalletPayOutcome.insufficient, WalletPayOutcome.failed]) {
      final String key = WalletCheckout.failureMessage(outcome);
      expect((enUS[key] ?? '').trim(), isNotEmpty, reason: key);
      expect((arAR[key] ?? '').trim(), isNotEmpty, reason: key);
    }
  });
}

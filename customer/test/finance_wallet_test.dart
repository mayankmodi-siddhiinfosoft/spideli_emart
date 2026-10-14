import 'package:customer/service/finance_ledger.dart';
import 'package:customer/utils/finance_payment_rules.dart';
import 'package:customer/utils/finance_wallet_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// The wallet operations the app writes (.claude/FINANCE-DIRECT-FIRESTORE.md
/// section 3.2): settings, fees, conversion figures and each batch.
void main() {
  final raw = {
    'currencies': ['XAF', 'EUR'],
    'deposit': {
      'enabled': true,
      'min': {'XAF': 500},
      'max': {'XAF': 1000000},
    },
    'withdraw': {
      'enabled': true,
      'methods': ['mobile_money', 'bank', 'crypto'],
      'min': {'XAF': 1000},
      'feePercent': 1,
      'feeFixed': {'XAF': 100},
      'feeMax': {'XAF': 2000},
      'delay': 'Within 24 hours',
    },
    'convert': {
      'enabled': true,
      'currencies': ['XAF', 'EUR'],
      'feePercent': 0.5,
    },
    'security': {
      'reauthAbove': {'XAF': 50000},
    },
  };

  Map<String, dynamic> doc(List<FinanceWrite> w, String prefix) => w.firstWhere((x) => x.path.startsWith(prefix)).data;
  List<FinanceWrite> all(List<FinanceWrite> w, String prefix) => w.where((x) => x.path.startsWith(prefix)).toList();

  group('platform_settings/wallet', () {
    test('parsed; unknown methods dropped; fails closed', () {
      final c = WalletConfig.parse(raw)!;
      expect(c.deposit.enabled, isTrue);
      expect(c.deposit.methods, ['mobile_money', 'wave', 'card', 'paypal'], reason: 'every gateway family by default');
      expect(c.withdraw.methods, ['mobile_money', 'bank']);
      expect(c.withdraw.delay, 'Within 24 hours');
      expect(c.convert.enabled, isTrue);
      expect(c.convert.maxRateAge, const Duration(hours: 48));
      expect(WalletConfig.parse(null), isNull);
      expect(WalletConfig.parse({'currencies': []}), isNull);
      expect(WalletConfig.parse({'currencies': ['XAF']})!.withdraw.enabled, isFalse);
      expect(WalletConfig.parse({...raw, 'convert': {'enabled': true, 'currencies': ['XAF']}})!.convert.enabled, isFalse, reason: 'two currencies to convert');
    });

    test('limits, fee and re-authentication', () {
      final c = WalletConfig.parse(raw)!;
      expect(c.deposit.limits.problem(400, 'XAF'), contains('minimum'));
      expect(c.deposit.limits.problem(2000000, 'XAF'), contains('maximum'));
      expect(c.deposit.limits.problem(5000, 'XAF'), isNull);
      expect(WalletRules.withdrawFee(c, 10000, 'XAF'), 200);
      expect(WalletRules.withdrawFee(c, 1000000, 'XAF'), 2000, reason: 'capped');
      expect(c.needsReauth(49999, 'XAF'), isFalse);
      expect(c.needsReauth(50000, 'XAF'), isTrue);
      expect(c.needsReauth(1, 'EUR'), isTrue, reason: 'no threshold: always');
    });
  });

  group('conversion', () {
    test('XAF -> EUR: fee in XAF, what arrives rounded down to the cent', () {
      // 1 XAF = 0.0015245 EUR; 100 000 XAF, 0.5 % fee = 500 XAF.
      final c = WalletRules.conversion(amount: 100000, from: 'XAF', to: 'EUR', rate: 0.0015245, feePercent: 0.5)!;
      expect(c.fee, 500);
      // 99 500 x 0.0015245 = 151.68775 EUR -> 15168 cents.
      expect(c.receive, 15168);
    });

    test('EUR -> XAF', () {
      final c = WalletRules.conversion(amount: 1000, from: 'EUR', to: 'XAF', rate: 655.957, feePercent: 0)!;
      expect(c.receive, 6559, reason: '10.00 EUR = 6 559.57 XAF, floored');
    });

    test('nothing arrives: refused', () {
      expect(WalletRules.conversion(amount: 1, from: 'XAF', to: 'EUR', rate: 0.0015, feePercent: 0), isNull);
      expect(WalletRules.conversion(amount: 100, from: 'XAF', to: 'XAF', rate: 1, feePercent: 0), isNull);
    });

    test('the latest fresh rate, direct or inverse', () {
      final now = DateTime(2026, 10, 14, 12);
      DateTime? d(dynamic v) => v as DateTime?;
      final snaps = [
        {'id': 'snap1', 'from': 'EUR', 'to': 'XAF', 'rate': 655.957, 'observedAt': DateTime(2026, 10, 14, 8), 'source': 'BEAC'},
        {'from': 'XAF', 'to': 'EUR', 'rate': 0.0015, 'observedAt': DateTime(2026, 10, 10), 'source': 'old'},
      ];
      final r = WalletRules.rateOf(snaps, 'XAF', 'EUR', now, const Duration(hours: 48), d)!;
      expect(r.source, 'BEAC');
      expect(r.id, 'snap1', reason: 'the conversion names the snapshot it used');
      expect(r.rate, closeTo(1 / 655.957, 1e-12));
      expect(WalletRules.rateOf(snaps.sublist(1), 'XAF', 'EUR', now, const Duration(hours: 48), d), isNull, reason: 'too old');
    });
  });

  group('batches', () {
    test('deposit: keyed by the gateway payment, platform -> wallet, receipt, wallet created', () {
      const funding = FinanceFunding.gateway('orange_money', 'OM123');
      final w = WalletRules.depositWrites(
        uid: 'u1',
        currency: 'XAF',
        amount: 5000,
        funding: funding,
        wallet: (id: 'wallet_u1_XAF', exists: false),
        purposeKind: 'money_transfers',
        purposeId: 't1',
      );
      final op = doc(w, 'wallet_operations/');
      expect(w.first.path, 'wallet_operations/orange_money_OM123');
      expect(op['type'], 'deposit');
      expect(op['status'], 'completed');
      expect(op['userId'], 'u1');
      expect(op['purpose'], {'kind': 'money_transfers', 'id': 't1'});
      final tx = doc(w, 'ledger_transactions/');
      expect(tx['lines'], [
        {'accountId': 'platform_XAF', 'direction': 'debit', 'amount': 5000},
        {'accountId': 'wallet_u1_XAF', 'direction': 'credit', 'amount': 5000},
      ]);
      expect(tx['funding'], 'gateway');
      expect(tx['source'], {'kind': 'wallet_operations', 'id': 'orange_money_OM123'});
      expect(op['txId'], tx['id']);
      expect(all(w, 'payment_receipts/').single.path, 'payment_receipts/orange_money_OM123');
      expect(w.singleWhere((x) => x.path == 'financial_accounts/wallet_u1_XAF').op, 'create');
    });

    test('withdrawal: pending, amount + fee from the wallet to the platform in two lines', () {
      final w = WalletRules.withdrawWrites(
        uid: 'u1',
        opId: 'k1',
        currency: 'XAF',
        amount: 10000,
        fee: 200,
        destination: FinanceDestination.mobileMoney('Orange Money', '+237699123456'),
        walletId: 'wallet_u1_XAF',
        txId: 'tx_1_abc',
      );
      final op = doc(w, 'wallet_operations/');
      expect(op['status'], 'pending');
      expect(op['total'], 10200);
      expect(op['destination']['number'], '+237699123456');
      final tx = doc(w, 'ledger_transactions/');
      expect(tx['id'], 'tx_1_abc');
      expect(tx['type'], 'withdrawal');
      expect(tx['lines'], [
        {'accountId': 'wallet_u1_XAF', 'direction': 'debit', 'amount': 10200},
        {'accountId': 'platform_XAF', 'direction': 'credit', 'amount': 10200},
      ]);
      expect(all(w, 'payment_receipts/'), isEmpty);
    });

    test('conversion: one batch, two postings, four different accounts', () {
      final c = WalletRules.conversion(amount: 100000, from: 'XAF', to: 'EUR', rate: 0.0015245, feePercent: 0.5)!;
      final w = WalletRules.convertWrites(
        uid: 'u1',
        opId: 'k2',
        c: c,
        fromWalletId: 'wallet_u1_XAF',
        toWallet: (id: 'wallet_u1_EUR', exists: false),
        txIdFrom: 'tx_1_a',
        txIdTo: 'tx_1_ab',
        rateSource: 'BEAC',
        rateObservedAt: DateTime(2026, 10, 14),
        rateSnapshotId: 'snap1',
      );
      final accounts = w.where((x) => x.path.startsWith('financial_accounts/')).map((x) => x.path).toList();
      expect(accounts, ['financial_accounts/wallet_u1_XAF', 'financial_accounts/platform_XAF', 'financial_accounts/platform_EUR', 'financial_accounts/wallet_u1_EUR']);
      expect(accounts.toSet().length, 4, reason: 'each account once per batch');
      final txs = all(w, 'ledger_transactions/').map((x) => x.data).toList();
      expect(txs.map((t) => t['type']), ['conversion', 'conversion']);
      expect(txs[0]['reference'], txs[1]['reference']);
      expect((txs[1]['lines'] as List)[1], {'accountId': 'wallet_u1_EUR', 'direction': 'credit', 'amount': 15168});
      final op = doc(w, 'wallet_operations/');
      expect(op['receiveAmount'], 15168);
      expect(op['txIds'], ['tx_1_a', 'tx_1_ab']);
      expect(op['toCurrency'], 'EUR');
      expect(op['rateSnapshotId'], 'snap1', reason: 'the rules cap receiveAmount with this snapshot\'s rate');
    });
  });
}

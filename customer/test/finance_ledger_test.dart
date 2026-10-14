import 'package:customer/service/finance_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

/// The postings the app writes (.claude/FINANCE-DIRECT-FIRESTORE.md section 2):
/// balanced lines, one balance change per account, receipts for gateways.
void main() {
  Map<String, dynamic> tx(FinancePosting p) => p.writes.firstWhere((w) => w.path.startsWith('ledger_transactions/')).data;
  List<Map<String, dynamic>> lines(FinancePosting p) => List<Map<String, dynamic>>.from(tx(p)['lines'] as List);

  test('a wallet transfer with a fee: 3 balanced lines and 3 balance changes', () {
    final p = FinanceLedger.plan(
      type: 'transfer',
      currency: 'XAF',
      from: 'wallet_a_XAF',
      to: 'wallet_b_XAF',
      amount: 10000,
      fee: 150,
      userIds: ['a', 'b'],
      sourceKind: 'money_transfers',
      sourceId: 't1',
      createdBy: 'a',
    );
    final l = lines(p);
    expect(l.length, 3);
    expect(l[0], {'accountId': 'wallet_a_XAF', 'direction': 'debit', 'amount': 10150});
    expect(l[1]['amount'] + l[2]['amount'], l[0]['amount'], reason: 'debits equal credits');
    expect(l[2]['accountId'], 'platform_XAF');
    final accounts = p.writes.where((w) => w.path.startsWith('financial_accounts/')).map((w) => w.path).toList();
    expect(accounts, ['financial_accounts/wallet_a_XAF', 'financial_accounts/wallet_b_XAF', 'financial_accounts/platform_XAF']);
    expect(p.writes.every((w) => !w.path.startsWith('payment_receipts/')), isTrue, reason: 'no receipt for a wallet payment');
    expect(tx(p)['accountIds'], ['wallet_a_XAF', 'wallet_b_XAF', 'platform_XAF']);
    expect(tx(p)['funding'], 'wallet');
  });

  test('a gateway payment debits the platform, has no fee line and one receipt', () {
    final p = FinanceLedger.plan(
      type: 'savings_contribution',
      currency: 'XAF',
      from: 'platform_XAF',
      to: 'goal_g1',
      amount: 5000,
      fee: 100,
      userIds: ['a'],
      sourceKind: 'savings_contributions',
      sourceId: 'c1',
      createdBy: 'a',
      funding: const FinanceFunding.gateway('stripe', 'pi_123'),
    );
    expect(lines(p).length, 2);
    expect(lines(p)[0]['amount'], 5000);
    final receipt = p.writes.singleWhere((w) => w.path.startsWith('payment_receipts/'));
    expect(receipt.path, 'payment_receipts/stripe_pi_123');
    expect(receipt.op, 'create');
    expect(receipt.data['amount'], 5100, reason: 'what the gateway charged');
    expect(tx(p)['gateway'], {'method': 'stripe', 'reference': 'pi_123'});
  });

  test('a credited account that does not exist yet is created by the posting', () {
    final p = FinanceLedger.plan(
      type: 'transfer',
      currency: 'XAF',
      from: 'wallet_a_XAF',
      to: 'wallet_b_XAF',
      amount: 2000,
      newAccounts: {'wallet_b_XAF': FinanceLedger.walletFields('b', 'XAF')},
      userIds: ['a', 'b'],
      sourceKind: 'money_transfers',
      sourceId: 't2',
      createdBy: 'a',
    );
    final created = p.writes.singleWhere((w) => w.path == 'financial_accounts/wallet_b_XAF');
    expect(created.op, 'create');
    expect(created.data['balance'], 2000);
    expect(created.data['userId'], 'b');
    expect(created.data['lastTxId'], p.txId);
    final debited = p.writes.singleWhere((w) => w.path == 'financial_accounts/wallet_a_XAF');
    expect(debited.op, 'update');
    expect(debited.data['lastTxId'], p.txId);
  });

  test('ids and references', () {
    expect(FinanceLedger.newTxId(DateTime(2026, 10, 14)), startsWith('tx_${DateTime(2026, 10, 14).millisecondsSinceEpoch}_'));
    expect(FinanceLedger.newReference(DateTime(2026, 10, 14)), matches(RegExp(r'^SPF-261014-[A-Z2-9]{6}$')));
    expect(FinanceLedger.walletId('u1', 'XAF'), 'wallet_u1_XAF');
    expect(const FinanceFunding.gateway('paypal', 'a/b').receiptId, 'paypal_a_b', reason: 'a document id has no slash');
  });
}

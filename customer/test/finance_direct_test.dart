import 'package:customer/service/finance_direct.dart';
import 'package:customer/service/finance_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paying the platform without a server (.claude/FINANCE-DIRECT-FIRESTORE.md
/// section 2.3): a gateway payment lands in the wallet first, then every
/// payment is a posting wallet -> platform.
void main() {
  Map<String, dynamic> txOf(List<FinanceWrite> w) => w.singleWhere((x) => x.path.startsWith('ledger_transactions/')).data;
  List<Map<String, dynamic>> linesOf(List<FinanceWrite> w) => List<Map<String, dynamic>>.from(txOf(w)['lines'] as List);

  test('a gateway payment is deposited into the wallet once, with its receipt', () {
    const funding = FinanceFunding.gateway('stripe', 'pi_1');
    final w = FinancePay.gatewayDeposit(
      uid: 'u1',
      currency: 'XAF',
      walletId: 'wallet_u1_XAF',
      walletExists: false,
      amount: 10150,
      funding: funding,
      purposeKind: 'card_funding_requests',
      purposeId: 'r1',
    );
    final op = w.firstWhere((x) => x.path.startsWith('wallet_operations/'));
    expect(op.path, 'wallet_operations/stripe_pi_1', reason: 'one deposit per gateway payment');
    expect(op.op, 'create');
    expect(op.data['type'], 'deposit');
    expect(op.data['status'], 'completed');
    expect(op.data['amount'], 10150);
    expect(op.data['gateway'], {'method': 'stripe', 'reference': 'pi_1'});
    expect(op.data['purpose'], {'kind': 'card_funding_requests', 'id': 'r1'});
    expect(op.data['txId'], txOf(w)['id']);
    expect(linesOf(w), [
      {'accountId': 'platform_XAF', 'direction': 'debit', 'amount': 10150},
      {'accountId': 'wallet_u1_XAF', 'direction': 'credit', 'amount': 10150},
    ]);
    expect(txOf(w)['type'], 'deposit');
    expect(txOf(w)['funding'], 'gateway');
    expect(txOf(w)['source'], {'kind': 'wallet_operations', 'id': 'stripe_pi_1'});
    final wallet = w.singleWhere((x) => x.path == 'financial_accounts/wallet_u1_XAF');
    expect(wallet.op, 'create', reason: 'a missing wallet is created by its first credit');
    expect(wallet.data['userId'], 'u1');
    expect(w.singleWhere((x) => x.path.startsWith('payment_receipts/')).path, 'payment_receipts/stripe_pi_1');
    final existing = FinancePay.gatewayDeposit(
      uid: 'u1',
      currency: 'XAF',
      walletId: 'wallet_u1_XAF',
      walletExists: true,
      amount: 500,
      funding: funding,
      purposeKind: 'x',
      purposeId: 'y',
    );
    expect(existing.singleWhere((x) => x.path == 'financial_accounts/wallet_u1_XAF').op, 'update');
  });

  test('a payment to the platform: wallet debited, platform credited, no receipt', () {
    final p = FinancePay.toPlatform(
      type: 'card_funding',
      uid: 'u1',
      currency: 'XAF',
      walletId: 'wallet_u1_XAF',
      amount: 10150,
      sourceKind: 'card_funding_requests',
      sourceId: 'r1',
    );
    expect(linesOf(p.writes), [
      {'accountId': 'wallet_u1_XAF', 'direction': 'debit', 'amount': 10150},
      {'accountId': 'platform_XAF', 'direction': 'credit', 'amount': 10150},
    ]);
    expect(txOf(p.writes)['funding'], 'wallet');
    expect(txOf(p.writes)['createdBy'], 'u1');
    expect(txOf(p.writes)['userIds'], ['u1']);
    expect(p.writes.where((x) => x.path.startsWith('payment_receipts/')), isEmpty);
    expect(p.writes.where((x) => x.path.startsWith('financial_accounts/')).map((x) => x.op).toSet(), {'update'});
  });
}

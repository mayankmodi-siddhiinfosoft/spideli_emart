import 'package:customer/service/finance_direct.dart';
import 'package:customer/utils/finance_investment_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// The writes of investment orders (.claude/FINANCE-DIRECT-FIRESTORE.md
/// section 3.9): a subscription is paid with the order, Spideli executes it
/// at the next unit price; a redemption is a request.
void main() {
  final fund = Fund.fromMap({
    'id': 'f1',
    'name': 'Money market',
    'assetClass': 'money_market',
    'currency': 'XAF',
    'minInvestment': 5000,
    'fees': {'subscriptionPercent': 2},
    'navPerUnit': 1000,
    'termsVersion': 3,
    'status': 'open',
  }, (_) => null);

  test('a subscription: paid, with the accepted terms, risks and signature, and its posting', () {
    final p = FinancePay.toPlatform(
      type: 'investment_subscription',
      uid: 'u1',
      currency: 'XAF',
      walletId: 'wallet_u1_XAF',
      amount: 50000,
      sourceKind: 'investment_subscriptions',
      sourceId: 's1',
    );
    final est = InvestmentCalculator.subscription(fund, 50000);
    final w = InvestmentWrites.subscribe(id: 's1', uid: 'u1', fund: fund, amount: 50000, fee: est.fee, signatureName: 'Jane Doe', posting: p, paidWith: const {'method': 'wallet'});
    final s = w.singleWhere((x) => x.path.startsWith('investment_subscriptions/'));
    expect(s.path, 'investment_subscriptions/s1');
    expect(s.op, 'create');
    expect(s.data['status'], 'paid');
    expect(s.data['userId'], 'u1');
    expect(s.data['fundId'], 'f1');
    expect(s.data['amount'], 50000);
    expect(s.data['fee'], 1000, reason: 'the estimate at the last price');
    expect(s.data['termsVersion'], 3);
    expect(s.data['riskAcknowledged'], isTrue);
    expect(s.data['signatureName'], 'Jane Doe');
    expect(s.data.containsKey('acceptedAt'), isTrue);
    expect(s.data['txId'], p.txId);
    expect(s.data['reference'], p.reference);
    expect(s.data.containsKey('units'), isFalse, reason: 'units are allocated by Spideli at the next price');
    final tx = w.singleWhere((x) => x.path.startsWith('ledger_transactions/')).data;
    expect(tx['type'], 'investment_subscription');
    expect((tx['lines'] as List).last, {'accountId': 'platform_XAF', 'direction': 'credit', 'amount': 50000});
  });

  test('a redemption: submitted, full (no amount) or partial, to a destination; no money moves', () {
    final full = InvestmentWrites.redeem(id: 'r1', uid: 'u1', fundId: 'f1', fundName: 'MM', currency: 'XAF', full: true, amount: 9999, destination: const {'method': 'wallet'}, reference: 'SPF-1');
    expect(full.single.path, 'investment_redemptions/r1');
    expect(full.single.data['status'], 'submitted');
    expect(full.single.data['full'], isTrue);
    expect(full.single.data['amount'], isNull);
    expect(full.single.data['destination'], {'method': 'wallet'});
    final part = InvestmentWrites.redeem(
      id: 'r2',
      uid: 'u1',
      fundId: 'f1',
      fundName: 'MM',
      currency: 'XAF',
      full: false,
      amount: 20000,
      destination: const {'method': 'mobile_money', 'operator': 'MTN Mobile Money', 'number': '699'},
      reference: 'SPF-2',
    );
    expect(part.single.data['amount'], 20000);
    expect(part.single.data['destination']['number'], '699');
    final cancel = InvestmentWrites.cancelRedemption('r2').single;
    expect(cancel.op, 'update');
    expect(cancel.data['status'], 'cancelled');
  });

  test('a subscription starts paid: the payment is made with the order', () {
    expect(InvestmentOrders.subscriptionSteps.first, 'paid');
    expect(InvestmentOrders.subscriptionSteps.last, 'completed');
  });
}

import 'package:customer/service/finance_direct.dart';
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/utils/finance_card_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// The writes of the virtual card requests (.claude/FINANCE-DIRECT-FIRESTORE.md
/// section 3.5): request documents the admin completes, money posted to the
/// platform in the same batch.
void main() {
  FinanceWrite one(List<FinanceWrite> w, String prefix) => w.singleWhere((x) => x.path.startsWith(prefix));
  List<Map<String, dynamic>> linesOf(List<FinanceWrite> w) => List<Map<String, dynamic>>.from(one(w, 'ledger_transactions/').data['lines'] as List);

  FinancePosting pay(int amount, String kind, String id, {String type = 'card_funding'}) =>
      FinancePay.toPlatform(type: type, uid: 'u1', currency: 'XAF', walletId: 'wallet_u1_XAF', amount: amount, sourceKind: kind, sourceId: id);

  VirtualCard card(String status, {String frozenBy = '', Object? renewalRequestedAt}) => VirtualCard.fromMap({
        'id': 'c1',
        'status': status,
        'frozenBy': frozenBy,
        'balance': 5000,
        'currency': 'XAF',
        'expiryMonth': 1,
        'expiryYear': 2026,
        'renewalRequestedAt': renewalRequestedAt,
      });

  test('a free card request: one requested card, no money', () {
    final w = CardWrites.request(cardId: 'k1', uid: 'u1', label: 'Shopping', currency: 'XAF', network: 'visa', termsVersion: 2, fee: 0, reference: 'SPF-1');
    expect(w.length, 1);
    final c = w.single;
    expect(c.path, 'virtual_cards/k1');
    expect(c.op, 'create');
    expect(c.data['status'], 'requested');
    expect(c.data['userId'], 'u1');
    expect(c.data['termsVersion'], 2);
    expect(c.data['balance'], 0);
    expect(c.data.containsKey('acceptedAt'), isTrue);
    expect(c.data.containsKey('cardholderName'), isFalse, reason: 'the name comes from the verified identity, set by the admin');
    expect(c.data.containsKey('last4'), isFalse);
  });

  test('a card request with a creation fee carries its card_fee posting', () {
    final p = pay(1000, 'virtual_cards', 'k1', type: 'card_fee');
    final w = CardWrites.request(cardId: 'k1', uid: 'u1', label: '', currency: 'XAF', network: 'visa', termsVersion: 1, fee: 1000, feePosting: p, paidWith: const {'method': 'wallet'});
    final c = one(w, 'virtual_cards/');
    expect(c.data['feeTxId'], p.txId);
    expect(c.data['reference'], p.reference);
    expect(c.data['issuanceFee'], 1000);
    expect(one(w, 'ledger_transactions/').data['type'], 'card_fee');
    expect(one(w, 'ledger_transactions/').data['source'], {'kind': 'virtual_cards', 'id': 'k1'});
    expect(linesOf(w).first, {'accountId': 'wallet_u1_XAF', 'direction': 'debit', 'amount': 1000});
  });

  test('a top-up: pending request with amount, fee and total; the posting moves the total to the platform', () {
    final q = FundingQuote.of(10000, 1.5);
    final p = pay(q.total, 'card_funding_requests', 'r1');
    final w = CardWrites.fund(requestId: 'r1', uid: 'u1', cardId: 'c1', currency: 'XAF', amount: q.amount, fee: q.fee, posting: p, paidWith: const {'method': 'wallet'});
    final r = one(w, 'card_funding_requests/');
    expect(r.path, 'card_funding_requests/r1');
    expect(r.op, 'create');
    expect(r.data['type'], 'fund');
    expect(r.data['status'], 'pending');
    expect(r.data['amount'], 10000);
    expect(r.data['fee'], 150);
    expect(r.data['total'], 10150);
    expect(r.data['txId'], p.txId);
    expect(linesOf(w), [
      {'accountId': 'wallet_u1_XAF', 'direction': 'debit', 'amount': 10150},
      {'accountId': 'platform_XAF', 'direction': 'credit', 'amount': 10150},
    ]);
  });

  test('withdrawal to the wallet and card to card: requests only, no money moves yet', () {
    final wd = CardWrites.withdraw(requestId: 'r2', uid: 'u1', cardId: 'c1', currency: 'XAF', amount: 3000, reference: 'SPF-2');
    expect(wd.single.data['type'], 'withdraw');
    expect(wd.single.data['status'], 'pending');
    expect(wd.single.data['destination'], {'method': 'wallet'});
    final tr = CardWrites.transfer(
      requestId: 'r3',
      uid: 'u1',
      cardId: 'c1',
      currency: 'XAF',
      amount: 2000,
      recipientId: 'u2',
      recipientName: 'Jane D.',
      recipientContact: 'jane@x.com',
      reference: 'SPF-3',
    );
    expect(tr.single.path, 'card_funding_requests/r3');
    expect(tr.single.data['type'], 'transfer');
    expect(tr.single.data['status'], 'pending');
    expect(tr.single.data['recipientId'], 'u2');
    expect(tr.single.data['recipient'], {'userId': 'u2', 'name': 'Jane D.', 'contact': 'jane@x.com'});
    for (final w in [...wd, ...tr]) {
      expect(w.path.startsWith('ledger_transactions/') || w.path.startsWith('financial_accounts/'), isFalse);
    }
  });

  test('freeze, unfreeze, limits, deletion and renewal', () {
    expect(CardWrites.freeze('c1').single.data, containsPair('status', 'frozen'));
    expect(CardWrites.freeze('c1').single.data, containsPair('frozenBy', 'user'));
    expect(CardWrites.unfreeze('c1').single.data, containsPair('status', 'active'));
    expect(CardWrites.unfreeze('c1').single.data['frozenBy'], isNull);
    final l = CardWrites.limits(cardId: 'c1', uid: 'u1', limits: const CardLimits(daily: 50000), allowOnline: false).single;
    expect(l.path, 'card_limit_settings/c1');
    expect(l.data['status'], 'pending');
    expect(l.data['perTransaction'], isNull, reason: 'null = the issuer maximum');
    expect(l.data['daily'], 50000);
    expect(l.data['allowOnline'], isFalse);
    expect(l.data.containsKey('allowInternational'), isFalse, reason: 'a toggle the issuer does not offer is not sent');
    final t = CardWrites.terminate(card('frozen', frozenBy: 'user')).single;
    expect(t.data['status'], 'termination_requested');
    expect(t.data['statusBefore'], 'frozen');
    final free = CardWrites.renew(cardId: 'c1', fee: 0);
    expect(free.single.data.containsKey('renewalRequestedAt'), isTrue);
    expect(free.single.data.containsKey('renewalTxId'), isFalse);
    final p = pay(500, 'virtual_cards', 'c1', type: 'card_fee');
    final paid = CardWrites.renew(cardId: 'c1', fee: 500, feePosting: p, paidWith: const {'method': 'wallet'});
    expect(one(paid, 'virtual_cards/').data['renewalTxId'], p.txId);
    expect(paid.where((w) => w.path.startsWith('ledger_transactions/')).length, 1);
  });

  test('card to card is offered only when the issuer supports it; a renewal is asked once', () {
    final base = {
      'currencies': ['XAF'],
      'fundingMethods': ['wallet'],
      'capabilities': {'renew': true},
      'terms': 'T',
      'termsVersion': 1,
    };
    final off = CardConfig.parse(base)!;
    final on = CardConfig.parse({
      ...base,
      'capabilities': {'renew': true, 'cardTransfer': true},
    })!;
    expect(off.canTransfer, isFalse);
    expect(CardActions.canTransfer(card('active'), off), isFalse);
    expect(CardActions.canTransfer(card('active'), on), isTrue);
    expect(CardActions.canTransfer(card('frozen', frozenBy: 'user'), on), isFalse);
    final now = DateTime(2026, 1, 10);
    expect(CardActions.canRenew(card('active'), on, now), isTrue);
    expect(CardActions.canRenew(card('active', renewalRequestedAt: 'x'), on, now), isFalse);
    expect(CardLabels.status('termination_requested'), 'Being deleted');
    expect(CardActions.canTerminate(card('termination_requested')), isFalse);
    expect(CardLabels.request('transfer'), 'Sent to a card');
  });

  test('pending withdrawals and transfers are taken from what the card can still send', () {
    expect(
      CardFunds.promised([
        {'type': 'withdraw', 'status': 'pending', 'amount': 1000},
        {'type': 'transfer', 'status': 'processing', 'amount': 500},
        {'type': 'transfer', 'status': 'succeeded', 'amount': 700},
        {'type': 'fund', 'status': 'pending', 'amount': 9000},
        {'type': 'withdraw', 'status': 'failed', 'amount': 300},
      ]),
      1500,
    );
  });

  test('a card recipient is found by e-mail or phone number', () {
    expect(CardRecipient.query(' Jane@X.com ')!.$1, 'email');
    expect(CardRecipient.query(' Jane@X.com ')!.$2, ['Jane@X.com', 'jane@x.com']);
    expect(CardRecipient.query('jane@x.com')!.$2, ['jane@x.com']);
    expect(CardRecipient.query('+237 699 12 34 56')!.$1, 'phoneNumber');
    expect(CardRecipient.query('+237 699 12 34 56')!.$2, ['237699123456', '+237699123456']);
    expect(CardRecipient.query('0699123456')!.$2, ['0699123456', '+0699123456', '699123456']);
    expect(CardRecipient.query('jane'), isNull);
    expect(CardRecipient.query('12'), isNull);
    expect(CardRecipient.query('abc@'), isNull);
    expect(CardRecipient.displayName('Jane', 'doe'), 'Jane D.');
    expect(CardRecipient.displayName('', 'Doe'), 'Doe');
  });
}

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:customer/service/finance_direct.dart';
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/utils/finance_insurance_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// The writes of online insurance (.claude/FINANCE-DIRECT-FIRESTORE.md
/// section 3.10): requests the admin completes with the insurer; premiums
/// posted to the platform in the same batch.
void main() {
  FinancePosting pay(int amount, String kind, String id) => FinancePay.toPlatform(
        type: 'insurance_premium',
        uid: 'u1',
        currency: 'XAF',
        walletId: 'wallet_u1_XAF',
        amount: amount,
        sourceKind: kind,
        sourceId: id,
      );
  FinanceWrite at(List<FinanceWrite> w, String path) => w.singleWhere((x) => x.path == path);

  test('a quote request: requested, the answers and the day the cover starts', () {
    final product = InsuranceProduct.fromMap({
      'id': 'p1',
      'name': 'Health',
      'partnerName': 'Insurer',
      'category': 'health',
      'currency': 'XAF',
      'termMonths': 12,
      'termsVersion': 1,
      'status': 'open',
    });
    final q = InsuranceWrites.requestQuote(id: 'q1', uid: 'u1', product: product, answers: const {'age': 30}, frequency: 'monthly', coverStart: DateTime(2026, 11, 2, 15, 30)).single;
    expect(q.path, 'insurance_quotes/q1');
    expect(q.op, 'create');
    expect(q.data['status'], 'requested');
    expect(q.data['userId'], 'u1');
    expect(q.data['productId'], 'p1');
    expect(q.data['answers'], {'age': 30});
    expect(q.data['coverStart'], Timestamp.fromDate(DateTime(2026, 11, 2)), reason: 'the day, without its time');
    expect(q.data.containsKey('premium'), isFalse, reason: 'priced by the insurer');
    expect(InsuranceWrites.declineQuote('q1').single.data['status'], 'declined');
  });

  test('accepting a quote: quote accepted, policy pending activation, first premium paid, posting', () {
    final quote = {
      'productId': 'p1',
      'productName': 'Health',
      'currency': 'XAF',
      'premium': 120000,
      'installmentAmount': 10500,
      'frequency': 'monthly',
      'coverStart': Timestamp.fromDate(DateTime(2026, 11, 2)),
      'termsVersion': 4,
      'deductible': null,
    };
    final p = pay(10500, 'insurance_premiums', 'q1_1');
    final w = InsuranceWrites.acceptQuote(quoteId: 'q1', quote: quote, uid: 'u1', signatureName: 'Jane Doe', posting: p, paidWith: const {'method': 'wallet'});
    final q = at(w, 'insurance_quotes/q1');
    expect(q.op, 'update');
    expect(q.data['status'], 'accepted');
    expect(q.data['policyId'], 'q1', reason: 'one policy per quote');
    final pol = at(w, 'insurance_policies/q1');
    expect(pol.op, 'create');
    expect(pol.data['status'], 'pending_activation');
    expect(pol.data['quoteId'], 'q1');
    expect(pol.data['installmentAmount'], 10500);
    expect(pol.data['termsVersion'], 4);
    expect(pol.data['autoRenew'], isFalse);
    expect(pol.data.containsKey('deductible'), isFalse, reason: 'nothing null is copied');
    expect(pol.data.containsKey('policyNumber'), isFalse, reason: 'set by the admin on activation');
    final pr = at(w, 'insurance_premiums/q1_1');
    expect(pr.op, 'create');
    expect(pr.data['status'], 'paid');
    expect(pr.data['amount'], 10500);
    expect(pr.data['txId'], p.txId);
    final tx = w.singleWhere((x) => x.path.startsWith('ledger_transactions/')).data;
    expect(tx['type'], 'insurance_premium');
    expect(tx['source'], {'kind': 'insurance_premiums', 'id': 'q1_1'});
  });

  test('premiums, renewal, automatic renewal and cancellation', () {
    final p = pay(10500, 'insurance_premiums', 'pr2');
    final paid = InsuranceWrites.payPremium(premiumId: 'pr2', posting: p, paidWith: const {'method': 'wallet'});
    expect(at(paid, 'insurance_premiums/pr2').data['status'], 'paid');
    expect(at(paid, 'insurance_premiums/pr2').data['reference'], p.reference);
    final r = pay(130000, 'insurance_policies', 'pol1');
    final renew = InsuranceWrites.renew(policyId: 'pol1', amount: 130000, posting: r, paidWith: const {'method': 'wallet'});
    final pol = at(renew, 'insurance_policies/pol1');
    expect(pol.data.containsKey('renewalRequestedAt'), isTrue);
    expect(pol.data['renewalPaidAmount'], 130000);
    expect(pol.data.containsKey('status'), isFalse, reason: 'the admin renews it');
    expect(InsuranceWrites.setAutoRenew('pol1', true).single.data['autoRenew'], isTrue);
    final c = InsuranceWrites.requestCancellation(policyId: 'pol1', status: 'renewal_due', reason: '').single;
    expect(c.data['status'], 'cancellation_requested');
    expect(c.data['statusBefore'], 'renewal_due');
    expect(c.data.containsKey('cancellationReason'), isFalse);
    expect(PolicyActions.canRenew('renewal_due', 130000), isTrue);
    expect(PolicyActions.canRenew('renewal_due', 130000, requested: true), isFalse, reason: 'paid once');
  });

  test('claims: submitted with the photos, an answer with its message event, a withdrawal', () {
    final docs = [
      {'name': 'Photo 1', 'storagePath': 'insurance_claims/u1/c1/1.jpg'},
    ];
    final c = InsuranceWrites.createClaim(
      id: 'c1',
      uid: 'u1',
      policy: const {'id': 'pol1', 'policyNumber': 'N-1', 'productName': 'Health', 'currency': 'XAF'},
      incidentDate: DateTime(2026, 10, 1, 9),
      description: 'Broken screen',
      amountClaimed: 45000,
      documents: docs,
    ).single;
    expect(c.path, 'insurance_claims/c1');
    expect(c.op, 'create');
    expect(c.data['status'], 'submitted');
    expect(c.data['policyId'], 'pol1');
    expect(c.data['incidentDate'], Timestamp.fromDate(DateTime(2026, 10, 1)));
    expect(c.data['documents'], docs);
    final answer = InsuranceWrites.respondToClaim(claimId: 'c1', eventId: 'e1', uid: 'u1', message: 'Here is the invoice', documents: docs);
    final claim = at(answer, 'insurance_claims/c1');
    expect(claim.data['status'], 'under_review');
    expect(claim.data.containsKey('documents'), isTrue);
    final event = at(answer, 'insurance_claims/c1/events/e1');
    expect(event.op, 'create');
    expect(event.data['message'], 'Here is the invoice');
    expect(event.data['authorId'], 'u1');
    final noPhoto = InsuranceWrites.respondToClaim(claimId: 'c1', eventId: 'e2', uid: 'u1', message: 'ok', documents: const []);
    expect(at(noPhoto, 'insurance_claims/c1').data.containsKey('documents'), isFalse);
    expect(InsuranceWrites.withdrawClaim('c1').single.data['status'], 'withdrawn');
  });
}

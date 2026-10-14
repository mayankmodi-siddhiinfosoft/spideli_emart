import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, Timestamp;
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/utils/finance_lending_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Member loans written directly to Firestore
/// (.claude/FINANCE-DIRECT-FIRESTORE.md section 3.8): every step is a pure
/// plan of writes; money moves only as balanced ledger postings.
void main() {
  DateTime? d(dynamic v) => v is DateTime ? v : null;

  final cfg = LendingConfig.parse({
    'currencies': ['XAF'],
    'minAmount': {'XAF': 10000},
    'maxAmount': {'XAF': 1000000},
    'durationsMonths': [3, 6],
    'repaymentFrequencies': ['monthly'],
    'purposes': ['business'],
    'interest': {'method': 'flat', 'annualPercent': 12},
    'feePercent': 2,
    'latePenaltyPercent': 5,
    'voting': {'quorumPercent': 50, 'approvalPercent': 60, 'durationHours': 48},
    'paymentMethods': ['wallet'],
    'agreementTerms': 'Repay on time.',
  })!;

  Loan loan(String status, {int amount = 100000, int funded = 0, int outstanding = 0, int repaid = 0, int yes = 0, int no = 0, List<String> voters = const ['m1', 'm2', 'm3'], List<String> lenders = const [], DateTime? ends}) =>
      Loan.fromMap({
        'id': 'l1',
        'borrowerId': 'b',
        'groupId': 't1',
        'groupName': 'Family',
        'status': status,
        'currency': 'XAF',
        'amount': amount,
        'fundedAmount': funded,
        'outstandingAmount': outstanding,
        'repaidAmount': repaid,
        'durationMonths': 3,
        'repaymentFrequency': 'monthly',
        'purpose': 'business',
        'eligibleVoterIds': voters,
        'lenderIds': lenders,
        'votes': {'yes': yes, 'no': no},
        'votingEndsAt': ends,
      }, d);

  FinanceWrite at(List<FinanceWrite> w, String path) => w.singleWhere((x) => x.path == path);
  Map<String, dynamic> tx(List<FinanceWrite> w) => w.singleWhere((x) => x.path.startsWith('ledger_transactions/')).data;
  List<Map<String, dynamic>> lines(List<FinanceWrite> w) => List<Map<String, dynamic>>.from(tx(w)['lines'] as List);

  /// Debits equal credits, every account of the lines is changed once, by its line.
  void balanced(List<FinanceWrite> w) {
    final l = lines(w);
    expect(l.where((x) => x['direction'] == 'debit'), hasLength(1));
    expect(l.first['direction'], 'debit');
    final int credits = l.skip(1).fold(0, (s, x) => s + (x['amount'] as int));
    expect(l.first['amount'], credits);
    for (final x in l) {
      expect(w.where((y) => y.path == 'financial_accounts/${x['accountId']}'), hasLength(1));
    }
  }

  group('apply', () {
    test('a submitted request: the group minus the borrower votes, nothing counted yet', () {
      final w = LoanPlans.apply(
        loanId: 'l1',
        uid: 'b',
        groupId: 't1',
        groupName: 'Family',
        memberIds: ['b', 'm1', 'm2', 'm1'],
        amount: 50000,
        currency: 'XAF',
        purpose: 'business',
        durationMonths: 3,
        repaymentFrequency: 'monthly',
        description: 'Stock',
      );
      expect(w, hasLength(1));
      expect(w.single.path, 'loan_applications/l1');
      expect(w.single.op, 'create');
      final m = w.single.data;
      expect(m['status'], 'submitted');
      expect(m['borrowerId'], 'b');
      expect(m['eligibleVoterIds'], ['m1', 'm2']);
      expect(m['votes'], {'yes': 0, 'no': 0});
      expect(m['fundedAmount'], 0);
      expect(m['outstandingAmount'], 0);
      expect(m['repaidAmount'], 0);
      expect(m['lenderIds'], isEmpty);
      expect(m['documents'], isEmpty);
    });

    test('checks: restricted, not a member, alone in the group, limits', () {
      String? check({bool restricted = false, List<String> members = const ['b', 'm1'], int amount = 50000, int months = 3}) => LoanChecks.apply(
            config: cfg,
            uid: 'b',
            memberIds: members,
            amount: amount,
            currency: 'XAF',
            durationMonths: months,
            frequency: 'monthly',
            restricted: restricted,
          );
      expect(check(), isNull);
      expect(check(restricted: true), 'finance_restricted');
      expect(check(members: ['m1', 'm2']), 'permission_denied');
      expect(check(members: ['b']), 'loan_no_voters');
      expect(check(amount: 5000), 'amount_out_of_range');
      expect(check(amount: 2000000), 'amount_out_of_range');
      expect(check(months: 12), 'state_changed');
    });

    test('a document is added once (arrayUnion)', () {
      final w = LoanPlans.addDocument('l1', name: 'Document 1', storagePath: 'loan_documents/b/l1/document-1.jpg');
      expect(w.single.op, 'update');
      expect(w.single.data['documents'], isA<FieldValue>());
    });
  });

  group('vote', () {
    final now = DateTime(2026, 10, 14, 12);

    test('one vote per member (create-only id) and its count', () {
      final w = LoanPlans.vote(loan('voting'), 'm1', approve: false, comment: 'Too much');
      final v = at(w, 'loan_votes/l1_m1');
      expect(v.op, 'create');
      expect(v.data['approve'], isFalse);
      expect(v.data['voterId'], 'm1');
      final count = at(w, 'loan_applications/l1');
      expect(count.data.containsKey('votes.no'), isTrue);
      expect(count.data.containsKey('votes.yes'), isFalse);
      expect(count.data['votes.no'], isA<FieldValue>());
    });

    test('checks: not after the end, never the borrower, restricted', () {
      expect(LoanChecks.vote(loan('voting', ends: DateTime(2026, 10, 15)), 'm1', now: now, restricted: false), isNull);
      expect(LoanChecks.vote(loan('voting', ends: DateTime(2026, 10, 13)), 'm1', now: now, restricted: false), 'state_changed');
      expect(LoanChecks.vote(loan('voting'), 'b', now: now, restricted: false), 'state_changed');
      expect(LoanChecks.vote(loan('voting'), 'm1', now: now, restricted: true), 'finance_restricted');
    });

    test('closing: any participant, after the end or once everyone voted', () {
      final open = loan('voting', yes: 1, ends: DateTime(2026, 10, 15));
      expect(LoanActions.canCloseVote(open, 'b', now: now), isFalse);
      final ended = loan('voting', yes: 1, ends: DateTime(2026, 10, 14));
      expect(LoanActions.canCloseVote(ended, 'b', now: now), isTrue);
      expect(LoanActions.canCloseVote(ended, 'm2', now: now), isTrue);
      expect(LoanActions.canCloseVote(ended, 'outsider', now: now), isFalse);
      final everyone = loan('voting', yes: 2, no: 1, ends: DateTime(2026, 10, 20));
      expect(LoanActions.canCloseVote(everyone, 'm1', now: now), isTrue);
      expect(LoanActions.canCloseVote(loan('voting', yes: 2, no: 1), 'm1', now: now), isTrue, reason: 'no end date: closes when everyone voted');
      expect(LoanActions.canCloseVote(loan('funding', yes: 3), 'm1', now: now), isFalse);
    });

    test('the outcome: funding with quorum and approval (whole numbers), else rejected for the vote', () {
      final approved = LoanPlans.closeVote(loan('voting', yes: 2), quorumPercent: 50, approvalPercent: 60);
      expect(approved.status, 'funding');
      expect(approved.writes.single.data['status'], 'funding');
      expect(approved.writes.single.data.containsKey('reason'), isFalse);
      // 1 of 3 voted: below the quorum (100 < 150).
      final noQuorum = LoanPlans.closeVote(loan('voting', yes: 1), quorumPercent: 50, approvalPercent: 60);
      expect(noQuorum.status, 'rejected');
      expect(noQuorum.writes.single.data['reason'], 'vote');
      // 1 yes of 2 cast: 100 < 120.
      expect(LoanPlans.closeVote(loan('voting', yes: 1, no: 1), quorumPercent: 50, approvalPercent: 60).status, 'rejected');
      // 3 yes of 5 cast at exactly 60 %.
      expect(LoanPlans.closeVote(loan('voting', yes: 3, no: 2, voters: const ['a', 'c', 'e', 'f', 'g']), quorumPercent: 100, approvalPercent: 60).status, 'funding');
    });
  });

  group('fund', () {
    test('the first funding creates the loan account; the funding is create-only per lender and number', () {
      final p = LoanPlans.fund(
        loan: loan('funding'),
        uid: 'm1',
        amount: 40000,
        n: 1,
        requestKey: 'k1',
        funding: const FinanceFunding.wallet(),
        walletId: 'wallet_m1_XAF',
        loanAccountExists: false,
      );
      balanced(p.writes);
      expect(lines(p.writes)[0], {'accountId': 'wallet_m1_XAF', 'direction': 'debit', 'amount': 40000});
      expect(lines(p.writes)[1]['accountId'], 'loan_l1');
      expect(tx(p.writes)['type'], 'loan_funding');
      expect(tx(p.writes)['source'], {'kind': 'loan_fundings', 'id': 'l1_m1_1'});
      final account = at(p.writes, 'financial_accounts/loan_l1');
      expect(account.op, 'create');
      expect(account.data['kind'], 'loan');
      expect(account.data['refId'], 'l1');
      final f = at(p.writes, 'loan_fundings/l1_m1_1');
      expect(f.op, 'create');
      expect(f.data['status'], 'succeeded');
      expect(f.data['collected'], 0);
      expect(f.data['requestKey'], 'k1');
      expect(f.data['txId'], p.txId);
      final l = at(p.writes, 'loan_applications/l1').data;
      expect(l['fundedAmount'], 40000);
      expect(l['lenderIds'], isA<FieldValue>());
      expect(l.containsKey('status'), isFalse);
      expect(p.writes.where((w) => w.path.startsWith('loan_agreements/')), isEmpty);
    });

    test('the last funder sets agreement_pending and issues version 1 of the agreement', () {
      final l0 = loan('funding', funded: 60000);
      final agreement = LoanPlans.agreement(l0, cfg, DateTime(2026, 10, 14));
      final p = LoanPlans.fund(
        loan: l0,
        uid: 'm2',
        amount: 40000,
        n: 1,
        requestKey: 'k2',
        funding: const FinanceFunding.gateway('stripe', 'pi_9'),
        walletId: 'wallet_m2_XAF',
        loanAccountExists: true,
        agreement: agreement,
      );
      balanced(p.writes);
      expect(lines(p.writes)[0]['accountId'], 'platform_XAF', reason: 'a gateway payment is posted from the platform');
      expect(at(p.writes, 'payment_receipts/stripe_pi_9').op, 'create');
      expect(at(p.writes, 'financial_accounts/loan_l1').op, 'update');
      final l = at(p.writes, 'loan_applications/l1').data;
      expect(l['fundedAmount'], 100000);
      expect(l['status'], 'agreement_pending');
      final a = at(p.writes, 'loan_agreements/l1');
      expect(a.op, 'create');
      expect(a.data['version'], 1);
      expect(a.data['principal'], 100000);
      expect(a.data['fee'], 2000);
      // Flat 12 % a year over 3 months: 3 000 interest.
      expect(a.data['totalRepayable'], 103000);
      expect(a.data['installments'], hasLength(3));
      expect(a.data['terms'], 'Repay on time.');
      expect(a.data['acceptedAt'], isNull);
    });

    test('checks: the remaining amount, never the borrower, the wallet balance, restricted', () {
      final l = loan('funding', funded: 70000);
      expect(LoanChecks.fund(l, 'm1', 30000, restricted: false, walletBalance: 30000), isNull);
      expect(LoanChecks.fund(l, 'm1', 30001, restricted: false), 'amount_out_of_range');
      expect(LoanChecks.fund(l, 'm1', 0, restricted: false), 'amount_out_of_range');
      expect(LoanChecks.fund(l, 'b', 1000, restricted: false), 'state_changed');
      expect(LoanChecks.fund(l, 'outsider', 1000, restricted: false), 'state_changed');
      expect(LoanChecks.fund(l, 'm1', 1000, restricted: false, walletBalance: 999), 'insufficient_funds');
      expect(LoanChecks.fund(l, 'm1', 1000, restricted: true), 'finance_restricted');
      expect(LoanChecks.fund(loan('voting'), 'm1', 1000, restricted: false), 'state_changed');
    });
  });

  group('accept and pay out', () {
    final now = DateTime(2026, 10, 14, 9);
    final l0 = loan('agreement_pending', funded: 100000, lenders: ['m1', 'm2']);
    final agreement = LoanPlans.agreement(l0, cfg, now);

    test('the whole funded amount leaves the loan account, the fee to the platform; active with the schedule', () {
      final p = LoanPlans.accept(loan: l0, agreement: agreement, uid: 'b', walletId: 'wallet_b_XAF', walletExists: false, now: now);
      balanced(p.writes);
      final l = lines(p.writes);
      expect(l[0], {'accountId': 'loan_l1', 'direction': 'debit', 'amount': 100000});
      expect(l[1], {'accountId': 'wallet_b_XAF', 'direction': 'credit', 'amount': 98000});
      expect(l[2], {'accountId': 'platform_XAF', 'direction': 'credit', 'amount': 2000});
      expect(tx(p.writes)['type'], 'loan_disbursement');
      expect(at(p.writes, 'financial_accounts/wallet_b_XAF').op, 'create', reason: 'the wallet is created by its first credit');
      expect(at(p.writes, 'loan_disbursements/l1').op, 'create', reason: 'one pay-out per loan');
      expect(at(p.writes, 'loan_agreements/l1').data.keys, ['acceptedAt']);
      final u = at(p.writes, 'loan_applications/l1').data;
      expect(u['status'], 'active');
      expect(u['agreementVersion'], 1);
      expect(u['outstandingAmount'], 103000);
      final s = at(p.writes, 'loan_schedules/l1');
      expect(s.op, 'create');
      final installments = List<Map<String, dynamic>>.from(s.data['installments'] as List);
      expect(installments, hasLength(3));
      expect((installments.first['dueDate'] as Timestamp).toDate(), DateTime(2026, 11, 14, 9), reason: 'one period after the pay-out');
      expect(installments.fold<int>(0, (s, i) => s + (i['amount'] as int)), 103000);
      expect(installments.every((i) => i['status'] == 'upcoming' && i['paidAmount'] == 0), isTrue);
    });

    test('checks: the version shown, the borrower, fully funded', () {
      expect(LoanChecks.accept(l0, 'b', agreement, 1, restricted: false, loanBalance: 100000), isNull);
      expect(LoanChecks.accept(l0, 'b', agreement, 2, restricted: false, loanBalance: 100000), 'agreement_outdated');
      expect(LoanChecks.accept(l0, 'm1', agreement, 1, restricted: false, loanBalance: 100000), 'state_changed');
      expect(LoanChecks.accept(l0, 'b', {...agreement, 'acceptedAt': DateTime(2026)}, 1, restricted: false, loanBalance: 100000), 'state_changed');
      expect(LoanChecks.accept(l0, 'b', agreement, 1, restricted: true, loanBalance: 100000), 'finance_restricted');
      expect(LoanChecks.accept(loan('agreement_pending', funded: 50000), 'b', agreement, 1, restricted: false, loanBalance: 50000), 'state_changed');
    });
  });

  group('repay', () {
    List<Map<String, dynamic>> schedule() => [
          {'number': 1, 'amount': 34333, 'amountDue': 34333, 'paidAmount': 0, 'status': 'upcoming'},
          {'number': 2, 'amount': 34333, 'amountDue': 34333, 'paidAmount': 0, 'status': 'upcoming'},
          {'number': 3, 'amount': 34334, 'amountDue': 34334, 'paidAmount': 0, 'status': 'upcoming'},
        ];

    test('to the loan account; outstanding down, repaid up, installments in order', () {
      final l0 = loan('active', funded: 100000, outstanding: 103000, lenders: ['m1']);
      final p = LoanPlans.repay(
        loan: l0,
        uid: 'b',
        amount: 40000,
        requestKey: 'r1',
        funding: const FinanceFunding.wallet(),
        walletId: 'wallet_b_XAF',
        installments: schedule(),
      );
      balanced(p.writes);
      expect(lines(p.writes)[1]['accountId'], 'loan_l1');
      expect(at(p.writes, 'loan_repayments/l1_r1').op, 'create');
      final u = at(p.writes, 'loan_applications/l1').data;
      expect(u['outstandingAmount'], 63000);
      expect(u['repaidAmount'], 40000);
      expect(u.containsKey('status'), isFalse);
      final i = List<Map<String, dynamic>>.from(at(p.writes, 'loan_schedules/l1').data['installments'] as List);
      expect(i[0]['status'], 'paid');
      expect(i[1]['status'], 'partially_paid');
      expect(i[1]['paidAmount'], 40000 - 34333);
      expect(i[2]['status'], 'upcoming');
      expect(installmentRemaining(i[1]), 34333 - 5667);
    });

    test('the last repayment: repaid, every installment paid', () {
      final l0 = loan('overdue', funded: 100000, outstanding: 2000, repaid: 101000);
      final p = LoanPlans.repay(
        loan: l0,
        uid: 'b',
        amount: 2000,
        requestKey: 'r9',
        funding: const FinanceFunding.wallet(),
        walletId: 'wallet_b_XAF',
        installments: schedule(),
      );
      final u = at(p.writes, 'loan_applications/l1').data;
      expect(u['outstandingAmount'], 0);
      expect(u['status'], 'repaid');
      expect(u['repaidAmount'], 103000);
      final i = List<Map<String, dynamic>>.from(at(p.writes, 'loan_schedules/l1').data['installments'] as List);
      expect(i.every((x) => x['status'] == 'paid'), isTrue);
    });

    test('a penalty the admin added is paid with its installment', () {
      final out = LoanPlans.allocate([
        {'number': 1, 'amount': 1000, 'penalty': 50, 'amountDue': 1050, 'paidAmount': 0, 'status': 'overdue'},
        {'number': 2, 'amount': 1000, 'status': 'upcoming'},
      ], 1050);
      expect(out[0]['status'], 'paid');
      expect(out[1]['status'], 'upcoming');
    });

    test('checks: never beyond what is outstanding, the borrower only, the wallet balance', () {
      final l0 = loan('active', outstanding: 5000);
      expect(LoanChecks.repay(l0, 'b', 5000, walletBalance: 5000), isNull);
      expect(LoanChecks.repay(l0, 'b', 5001), 'amount_out_of_range');
      expect(LoanChecks.repay(l0, 'm1', 100), 'state_changed');
      expect(LoanChecks.repay(l0, 'b', 100, walletBalance: 99), 'insufficient_funds');
      expect(LoanChecks.repay(loan('repaid'), 'b', 100), 'state_changed');
    });
  });

  group('lenders collect their share', () {
    test('floor(repaid x lent / amount) - collected', () {
      expect(LenderShare.due(repaid: 51500, lent: 40000, loanAmount: 100000, collected: 0), 20600);
      expect(LenderShare.due(repaid: 51500, lent: 40000, loanAmount: 100000, collected: 20000), 600);
      expect(LenderShare.due(repaid: 10, lent: 1, loanAmount: 3, collected: 0), 3, reason: 'rounded down');
      expect(LenderShare.due(repaid: 0, lent: 40000, loanAmount: 100000, collected: 0), 0);
      expect(LenderShare.due(repaid: 1000, lent: 40000, loanAmount: 100000, collected: 9999), 0);
      // Large amounts do not overflow.
      expect(LenderShare.due(repaid: 9000000000000, lent: 5000000000000, loanAmount: 10000000000000, collected: 0), 4500000000000);
    });

    test('the lenders together never collect more than was repaid', () {
      final r = Random(7);
      for (int k = 0; k < 200; k++) {
        final int n = 1 + r.nextInt(6);
        final lent = [for (int i = 0; i < n; i++) 1 + r.nextInt(100000)];
        final int amount = lent.fold(0, (s, x) => s + x);
        final int repaid = r.nextInt(amount * 2);
        final int total = lent.fold(0, (s, x) => s + LenderShare.due(repaid: repaid, lent: x, loanAmount: amount, collected: 0));
        expect(total, lessThanOrEqualTo(repaid));
      }
    });

    test('per funding: the posting from the loan account and collected', () {
      final l0 = loan('active', funded: 100000, outstanding: 51500, repaid: 51500, lenders: ['m1']);
      final fundings = [
        {'id': 'l1_m1_1', 'amount': 40000, 'collected': 20000, 'status': 'succeeded', 'lenderId': 'm1'},
        {'id': 'l1_m1_2', 'amount': 10000, 'collected': 0, 'status': 'succeeded', 'lenderId': 'm1'},
      ];
      expect(LenderShare.collectable(l0, fundings), [('l1_m1_1', 600), ('l1_m1_2', 5150)]);
      expect(LenderShare.available(l0, fundings), 5750);
      expect(LenderShare.lent(fundings), 50000);
      expect(LenderShare.collected(fundings), 20000);
      expect(LoanActions.canCollect(l0, 'm1', 5750), isTrue);
      expect(LoanActions.canCollect(l0, 'b', 5750), isFalse);
      expect(LoanActions.canCollect(l0, 'm1', 0), isFalse);
      final p = LoanPlans.collect(loan: l0, funding: fundings[0], uid: 'm1', amount: 600, walletId: 'wallet_m1_XAF', walletExists: true);
      balanced(p.writes);
      expect(lines(p.writes)[0], {'accountId': 'loan_l1', 'direction': 'debit', 'amount': 600});
      expect(lines(p.writes)[1]['accountId'], 'wallet_m1_XAF');
      expect(tx(p.writes)['type'], 'loan_lender_payout');
      expect(tx(p.writes)['source'], {'kind': 'loan_fundings', 'id': 'l1_m1_1'});
      final f = at(p.writes, 'loan_fundings/l1_m1_1');
      expect(f.op, 'update');
      expect(f.data['collected'], 20600);
    });
  });

  test('cancel: only before money is committed', () {
    expect(LoanChecks.cancel(loan('voting'), 'b'), isNull);
    expect(LoanChecks.cancel(loan('voting'), 'm1'), 'state_changed');
    expect(LoanChecks.cancel(loan('funding'), 'b'), 'state_changed');
    final w = LoanPlans.cancel(loan('submitted'));
    expect(w.single.data['status'], 'cancelled');
  });

  test('error messages for the new reasons', () {
    for (final k in ['permission_denied', 'finance_restricted', 'state_changed', 'loan_no_voters', 'agreement_outdated', 'nothing_to_collect']) {
      expect(LoanErrors.message(k), isNotNull);
    }
    expect(LoanErrors.message('insufficient_funds'), isNull, reason: 'the shared finance messages cover it');
  });
}

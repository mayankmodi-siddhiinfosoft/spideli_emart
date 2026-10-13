import 'package:customer/utils/finance_lending_rules.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime? _d(dynamic v) => v is DateTime ? v : null;

void main() {
  final raw = {
    'currencies': ['XAF'],
    'minAmount': {'XAF': 10000},
    'maxAmount': {'XAF': 1000000},
    'durationsMonths': [12, 3, 6],
    'repaymentFrequencies': ['monthly', 'weekly'],
    'purposes': ['business', 'education'],
    'interest': {'method': 'declining', 'annualPercent': 12},
    'feePercent': 2,
    'latePenaltyPercent': 5,
    'voting': {'quorumPercent': 50, 'approvalPercent': 60, 'durationHours': 48},
    'paymentMethods': ['wallet', 'mobile_money'],
  };

  test('configuration: parsed, durations sorted, fails closed when invalid', () {
    final c = LendingConfig.parse(raw)!;
    expect(c.durationsMonths, [3, 6, 12]);
    expect(c.minFor('XAF'), 10000);
    expect(c.maxFor('XAF'), 1000000);
    expect(c.maxFor('XOF'), isNull);
    expect(LendingConfig.parse(null), isNull);
    expect(LendingConfig.parse({...raw, 'interest': {'method': 'magic'}}), isNull);
    expect(LendingConfig.parse({...raw, 'voting': {'quorumPercent': 0, 'approvalPercent': 60, 'durationHours': 48}}), isNull);
    expect(LendingConfig.parse({...raw, 'paymentMethods': []}), isNull);
  });

  group('schedule estimate: whole minor units, principal adds up exactly', () {
    final first = DateTime(2026, 11, 15);
    test('declining balance (annuity)', () {
      final e = LoanCalculator.estimate(principal: 100000, months: 12, frequency: 'monthly', method: 'declining', annualPercent: 12, feePercent: 2, firstDue: first);
      expect(e.installments, hasLength(12));
      expect(e.installments.fold<int>(0, (s, i) => s + i.principal), 100000);
      // 1% a month on 100 000 over 12 months: about 8 885 per installment, 6 619 interest.
      expect(e.installmentAmount, closeTo(8885, 2));
      expect(e.totalInterest, closeTo(6619, 12));
      expect(e.fee, 2000);
      expect(e.installments.first.interest, 1000);
      expect(e.installments.last.dueDate, DateTime(2027, 10, 15));
    });
    test('flat interest', () {
      final e = LoanCalculator.estimate(principal: 100000, months: 3, frequency: 'monthly', method: 'flat', annualPercent: 12, firstDue: first);
      expect(e.installments.map((i) => i.principal), [33333, 33333, 33334]);
      expect(e.totalInterest, 3000);
      expect(e.totalRepaid, 103000);
    });
    test('zero interest and weekly periods', () {
      final e = LoanCalculator.estimate(principal: 52000, months: 3, frequency: 'weekly', method: 'declining', annualPercent: 0, firstDue: first);
      expect(e.installments, hasLength(13));
      expect(e.totalInterest, 0);
      expect(e.totalRepaid, 52000);
      expect(e.installments[1].dueDate, DateTime(2026, 11, 22));
    });
  });

  test('vote tally mirrors quorum and approval', () {
    const t = VoteTally(eligible: 10, yes: 3, no: 1, quorumPercent: 50, approvalPercent: 60);
    expect(t.needed, 5);
    expect(t.quorumReached, isFalse);
    expect(t.wouldApprove, isFalse);
    const t2 = VoteTally(eligible: 10, yes: 3, no: 2, quorumPercent: 50, approvalPercent: 60);
    expect(t2.quorumReached, isTrue);
    expect(t2.approvalShare, 0.6);
    expect(t2.wouldApprove, isTrue);
    expect(const VoteTally(eligible: 0, yes: 0, no: 0, quorumPercent: 50, approvalPercent: 60).quorumReached, isFalse);
  });

  group('actions', () {
    Loan loan(String status, {String borrower = 'b', List<String> voters = const ['m1', 'm2'], int funded = 0, int outstanding = 0, DateTime? ends}) => Loan.fromMap({
          'id': 'l',
          'borrowerId': borrower,
          'status': status,
          'currency': 'XAF',
          'amount': 50000,
          'fundedAmount': funded,
          'outstandingAmount': outstanding,
          'eligibleVoterIds': voters,
          'votingEndsAt': ends,
        }, _d);
    final now = DateTime(2026, 10, 13);

    test('the borrower never votes or funds their own loan; one vote each; voting closes', () {
      expect(LoanActions.canVote(loan('voting'), 'm1', alreadyVoted: false, now: now), isTrue);
      expect(LoanActions.canVote(loan('voting'), 'm1', alreadyVoted: true, now: now), isFalse);
      expect(LoanActions.canVote(loan('voting', voters: const ['b', 'm1']), 'b', alreadyVoted: false, now: now), isFalse);
      expect(LoanActions.canVote(loan('voting'), 'outsider', alreadyVoted: false, now: now), isFalse);
      expect(LoanActions.canVote(loan('voting', ends: DateTime(2026, 10, 12)), 'm1', alreadyVoted: false, now: now), isFalse);
      expect(LoanActions.canFund(loan('funding'), 'm1'), isTrue);
      expect(LoanActions.canFund(loan('funding', funded: 50000), 'm1'), isFalse);
      expect(LoanActions.canFund(loan('funding'), 'b'), isFalse);
    });
    test('borrower steps', () {
      expect(LoanActions.canAcceptAgreement(loan('agreement_pending'), 'b'), isTrue);
      expect(LoanActions.canAcceptAgreement(loan('agreement_pending'), 'm1'), isFalse);
      expect(LoanActions.canRepay(loan('active', outstanding: 1000), 'b'), isTrue);
      expect(LoanActions.canRepay(loan('overdue', outstanding: 1000), 'b'), isTrue);
      expect(LoanActions.canRepay(loan('active', outstanding: 0), 'b'), isFalse);
      expect(LoanActions.canCancel(loan('voting'), 'b'), isTrue);
      expect(LoanActions.canCancel(loan('funding'), 'b'), isFalse);
      expect(loan('funding', funded: 20000).fundingRemaining, 30000);
      expect(loan('funding', funded: 20000).fundingProgress, 0.4);
    });
  });

  test('next installment = first not paid', () {
    expect(nextInstallment([
      {'number': 1, 'status': 'paid'},
      {'number': 2, 'status': 'overdue'},
      {'number': 3, 'status': 'upcoming'},
    ])!['number'], 2);
    expect(nextInstallment([{'number': 1, 'status': 'paid'}]), isNull);
  });
}

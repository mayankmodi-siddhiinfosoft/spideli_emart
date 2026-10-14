import 'package:customer/utils/finance_rules.dart';
import 'package:customer/utils/finance_summary_builder.dart';
import 'package:flutter_test/flutter_test.dart';

/// The dashboard totals worked out on the device from the user's records.
void main() {
  final now = DateTime(2026, 10, 14, 12);
  DateTime? toDate(dynamic v) => v is DateTime ? v : null;
  FinanceSummary? summary(FinanceSummarySources s) => FinanceSummary.parse(FinanceSummaryBuilder.build(s, uid: 'u', now: now, toDate: toDate), toDate: toDate);

  test('nothing at all: no summary (the dashboard shows how to start)', () {
    expect(summary(const FinanceSummarySources()), isNull);
  });

  test('the currency is the largest wallet\'s; other currencies are left out', () {
    final s = summary(const FinanceSummarySources(
      accounts: [
        {'id': 'w1', 'kind': 'wallet', 'status': 'active', 'currency': 'USD', 'balance': 100},
        {'id': 'w2', 'kind': 'wallet', 'status': 'active', 'currency': 'XAF', 'balance': 50000},
      ],
      goals: [
        {'status': 'active', 'currency': 'XAF', 'savedAmount': 3000, 'targetAmount': 10000},
        {'status': 'active', 'currency': 'USD', 'savedAmount': 999, 'targetAmount': 999},
        {'status': 'cancelled', 'currency': 'XAF', 'savedAmount': 7, 'targetAmount': 7},
      ],
    ))!;
    expect(s.currency, 'XAF');
    expect(s.savings!['activeGoals'], 1);
    expect(s.savings!['savedAmount'], 3000);
    expect(s.savingsProgress, closeTo(0.3, 1e-9));
  });

  test('investments: totals, allocation and return', () {
    final s = summary(const FinanceSummarySources(holdings: [
      {'currency': 'XAF', 'units': 10, 'assetClass': 'bonds', 'investedAmount': 100000, 'currentValue': 110000, 'realizedGains': 2000, 'unrealizedGains': 10000},
      {'currency': 'XAF', 'units': 5, 'assetClass': 'equities', 'investedAmount': 50000, 'currentValue': 45000, 'realizedGains': 0, 'unrealizedGains': -5000},
    ]))!;
    expect(s.investments!['currentValuation'], 155000);
    expect(s.totalGains, 7000);
    expect(s.investmentReturnPercent, closeTo(7000 * 100 / 150000, 1e-9));
    expect(s.allocation, {'bonds': 110000, 'equities': 45000});
  });

  test('tontines: the next contribution skips a cycle already paid', () {
    final due = DateTime(2026, 10, 18);
    final s = summary(FinanceSummarySources(
      tontines: [
        {'id': 't1', 'status': 'active', 'currency': 'XAF', 'nextDueAt': due, 'frequency': 'monthly', 'contributionAmount': 10000, 'currentCycle': 2},
      ],
      paidCurrentCycle: const {'t1': true},
    ))!;
    expect(s.tontines!['active'], 1);
    expect(s.tontines!['nextContributionDate'], DateTime(2026, 11, 18));
    expect(s.tontines!['nextContributionAmount'], 10000);
  });

  test('loans: outstanding, overdue, next instalment and what is still due to a lender', () {
    final s = summary(FinanceSummarySources(
      borrowed: const [
        {'id': 'l1', 'status': 'overdue', 'currency': 'XAF', 'outstandingAmount': 40000},
      ],
      schedules: {
        'l1': [
          {'status': 'paid', 'dueDate': DateTime(2026, 9, 1), 'amountDue': 10000},
          {'status': 'partially_paid', 'dueDate': DateTime(2026, 10, 1), 'amountDue': 10500, 'paidAmount': 500},
        ],
      },
      lentLoans: const [
        {'id': 'l2', 'status': 'active'},
        {'id': 'l3', 'status': 'repaid'},
      ],
      fundings: const [
        {'loanId': 'l2', 'status': 'succeeded', 'currency': 'XAF', 'amount': 20000, 'collected': 5000},
        {'loanId': 'l3', 'status': 'succeeded', 'currency': 'XAF', 'amount': 9000},
        {'loanId': 'l2', 'status': 'failed', 'currency': 'XAF', 'amount': 7000},
      ],
    ))!;
    expect(s.loans!['borrowedOutstanding'], 40000);
    expect(s.loans!['overdueCount'], 1);
    expect(s.loans!['nextRepaymentDate'], DateTime(2026, 10, 1));
    expect(s.loans!['nextRepaymentAmount'], 10000, reason: 'what is still due on a partly paid instalment');
    expect(s.loans!['lentOutstanding'], 15000);
  });

  test('cash flow: money in and out of the user\'s accounts, last 30 days by kind', () {
    final s = summary(FinanceSummarySources(
      accounts: const [
        {'id': 'w', 'kind': 'wallet', 'status': 'active', 'currency': 'XAF', 'balance': 1, 'normalSide': 'credit'},
      ],
      ledger: [
        {'type': 'deposit', 'currency': 'XAF', 'createdAt': DateTime(2026, 10, 10), 'lines': [{'accountId': 'platform_XAF', 'direction': 'debit', 'amount': 50000}, {'accountId': 'w', 'direction': 'credit', 'amount': 50000}]},
        {'type': 'bill_payment', 'currency': 'XAF', 'createdAt': DateTime(2026, 10, 12), 'lines': [{'accountId': 'w', 'direction': 'debit', 'amount': 8000}, {'accountId': 'platform_XAF', 'direction': 'credit', 'amount': 8000}]},
        {'type': 'transfer', 'currency': 'XAF', 'createdAt': DateTime(2026, 8, 3), 'lines': [{'accountId': 'w', 'direction': 'debit', 'amount': 1000}, {'accountId': 'x', 'direction': 'credit', 'amount': 1000}]},
        {'type': 'deposit', 'status': 'reversed', 'currency': 'XAF', 'createdAt': DateTime(2026, 10, 11), 'lines': [{'accountId': 'w', 'direction': 'credit', 'amount': 777}]},
      ],
    ))!;
    expect(s.last30Days['deposits'], 50000);
    expect(s.last30Days['billPayments'], 8000);
    expect(s.last30Days['transfers'], 0, reason: 'older than 30 days');
    expect(s.monthly.map((m) => m.month), ['2026-08', '2026-10']);
    expect(s.monthly.last.moneyIn, 50000);
    expect(s.monthly.last.moneyOut, 8000);
  });
}

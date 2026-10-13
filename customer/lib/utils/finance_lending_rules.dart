/// Spideli Finance: member-to-member lending, the pure rules the screens use
/// (.claude/FINANCE-APP-CONTRACT.md section 11). Unit tested in
/// test/finance_lending_rules_test.dart.
///
/// The SERVER decides eligibility, credit, votes, funding, the agreed
/// schedule, repayments, penalties and defaults. The schedule computed here
/// is an ESTIMATE shown before applying; the binding schedule is the one in
/// the loan agreement the server issues.
library;

import 'dart:math' as math;

import 'package:customer/utils/finance_group_rules.dart';

int _int(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [];

/// `platform_settings/lending` (admin). Null when missing or invalid.
class LendingConfig {
  final List<String> currencies;
  final Map<String, int> minAmount;
  final Map<String, int> maxAmount;
  final List<int> durationsMonths;
  final List<String> repaymentFrequencies;
  final List<String> purposes;

  /// `flat` (interest on the original principal) or `declining` (on the
  /// remaining balance, equal installments).
  final String interestMethod;
  final double annualInterestPercent;
  final double feePercent;
  final double latePenaltyPercent;
  final int quorumPercent;
  final int approvalPercent;
  final int votingHours;
  final List<String> paymentMethods;

  const LendingConfig({
    required this.currencies,
    required this.minAmount,
    required this.maxAmount,
    required this.durationsMonths,
    required this.repaymentFrequencies,
    required this.purposes,
    required this.interestMethod,
    required this.annualInterestPercent,
    required this.feePercent,
    required this.latePenaltyPercent,
    required this.quorumPercent,
    required this.approvalPercent,
    required this.votingHours,
    required this.paymentMethods,
  });

  static Map<String, int> _amounts(dynamic v) => v is Map ? {for (final e in v.entries) e.key.toString(): _int(e.value)} : const {};

  static LendingConfig? parse(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final currencies = _strings(raw['currencies']).where((c) => RegExp(r'^[A-Z]{3}$').hasMatch(c)).toList();
    final durations = (raw['durationsMonths'] is List ? (raw['durationsMonths'] as List).map(_int).where((d) => d > 0).toList() : <int>[])..sort();
    final freqs = _strings(raw['repaymentFrequencies']).where(Frequency.all.contains).toList();
    final methods = _strings(raw['paymentMethods']);
    final interest = raw['interest'] is Map ? Map<String, dynamic>.from(raw['interest'] as Map) : const <String, dynamic>{};
    final voting = raw['voting'] is Map ? Map<String, dynamic>.from(raw['voting'] as Map) : const <String, dynamic>{};
    final method = interest['method']?.toString();
    final quorum = _int(voting['quorumPercent']);
    final approval = _int(voting['approvalPercent']);
    if (currencies.isEmpty || durations.isEmpty || freqs.isEmpty || methods.isEmpty) return null;
    if (method != 'flat' && method != 'declining') return null;
    if (quorum < 1 || quorum > 100 || approval < 1 || approval > 100 || _int(voting['durationHours']) < 1) return null;
    return LendingConfig(
      currencies: currencies,
      minAmount: _amounts(raw['minAmount']),
      maxAmount: _amounts(raw['maxAmount']),
      durationsMonths: durations,
      repaymentFrequencies: freqs,
      purposes: _strings(raw['purposes']).isEmpty ? const ['other'] : _strings(raw['purposes']),
      interestMethod: method!,
      annualInterestPercent: _num(interest['annualPercent']).clamp(0, 1000).toDouble(),
      feePercent: _num(raw['feePercent']).clamp(0, 100).toDouble(),
      latePenaltyPercent: _num(raw['latePenaltyPercent']).clamp(0, 100).toDouble(),
      quorumPercent: quorum,
      approvalPercent: approval,
      votingHours: _int(voting['durationHours']),
      paymentMethods: methods,
    );
  }

  int minFor(String c) => minAmount[c] ?? 1;
  int? maxFor(String c) => maxAmount[c];
}

/// One installment of a schedule.
class Installment {
  final int number;
  final DateTime dueDate;
  final int principal;
  final int interest;

  const Installment(this.number, this.dueDate, this.principal, this.interest);

  int get total => principal + interest;
}

class LoanEstimate {
  final List<Installment> installments;
  final int fee;

  const LoanEstimate(this.installments, this.fee);

  int get totalInterest => installments.fold(0, (s, i) => s + i.interest);
  int get totalRepaid => installments.fold(0, (s, i) => s + i.total);
  int get installmentAmount => installments.isEmpty ? 0 : installments.first.total;
}

abstract final class LoanCalculator {
  /// Number of installments for [months] at [frequency].
  static int periods(int months, String frequency) => switch (frequency) {
        Frequency.weekly => math.max(1, (months * 52 / 12).round()),
        Frequency.biweekly => math.max(1, (months * 26 / 12).round()),
        _ => math.max(1, months),
      };

  static int periodsPerYear(String frequency) => switch (frequency) {
        Frequency.weekly => 52,
        Frequency.biweekly => 26,
        _ => 12,
      };

  /// The estimated schedule of [principal] (minor units). Amounts are whole
  /// minor units; rounding differences go to the LAST installment, so the
  /// principal parts always add up to exactly [principal].
  static LoanEstimate estimate({
    required int principal,
    required int months,
    required String frequency,
    required String method,
    required double annualPercent,
    double feePercent = 0,
    required DateTime firstDue,
  }) {
    final int n = periods(months, frequency);
    final double r = annualPercent / 100 / periodsPerYear(frequency);
    final dates = <DateTime>[firstDue];
    while (dates.length < n) {
      dates.add(Frequency.next(dates.last, frequency));
    }
    final List<Installment> out = [];
    if (method == 'flat') {
      final int totalInterest = (principal * r * n).round();
      final int p = principal ~/ n;
      final int i = totalInterest ~/ n;
      for (int k = 1; k <= n; k++) {
        final bool last = k == n;
        out.add(Installment(k, dates[k - 1], last ? principal - p * (n - 1) : p, last ? totalInterest - i * (n - 1) : i));
      }
    } else {
      // Declining balance, equal installments (annuity).
      final double payment = r == 0 ? principal / n : principal * r / (1 - math.pow(1 + r, -n));
      int balance = principal;
      for (int k = 1; k <= n; k++) {
        final int interest = (balance * r).round();
        int p = (payment - interest).round();
        if (k == n || p > balance) p = balance;
        balance -= p;
        out.add(Installment(k, dates[k - 1], p, interest));
      }
    }
    return LoanEstimate(out, (principal * feePercent / 100).round());
  }
}

/// A loan application as the server stores it (`loan_applications/{id}`).
class Loan {
  final String id;
  final String borrowerId;
  final String groupId;
  final String groupName;
  final String status;
  final String currency;
  final int amount;
  final int fundedAmount;
  final int outstandingAmount;
  final int durationMonths;
  final String frequency;
  final String purpose;
  final String description;
  final List<String> eligibleVoterIds;
  final List<String> lenderIds;
  final int votesYes;
  final int votesNo;
  final DateTime? votingEndsAt;
  final String? reason;

  const Loan({
    required this.id,
    required this.borrowerId,
    required this.groupId,
    required this.groupName,
    required this.status,
    required this.currency,
    required this.amount,
    required this.fundedAmount,
    required this.outstandingAmount,
    required this.durationMonths,
    required this.frequency,
    required this.purpose,
    required this.description,
    required this.eligibleVoterIds,
    required this.lenderIds,
    required this.votesYes,
    required this.votesNo,
    required this.votingEndsAt,
    required this.reason,
  });

  static Loan fromMap(Map<String, dynamic> m, DateTime? Function(dynamic) toDate) {
    final votes = m['votes'] is Map ? Map<String, dynamic>.from(m['votes'] as Map) : const <String, dynamic>{};
    return Loan(
      id: m['id']?.toString() ?? '',
      borrowerId: m['borrowerId']?.toString() ?? '',
      groupId: m['groupId']?.toString() ?? '',
      groupName: m['groupName']?.toString() ?? '',
      status: m['status']?.toString() ?? 'submitted',
      currency: m['currency']?.toString() ?? '',
      amount: _int(m['amount']),
      fundedAmount: _int(m['fundedAmount']),
      outstandingAmount: _int(m['outstandingAmount']),
      durationMonths: _int(m['durationMonths']),
      frequency: m['repaymentFrequency']?.toString() ?? Frequency.monthly,
      purpose: m['purpose']?.toString() ?? 'other',
      description: m['description']?.toString() ?? '',
      eligibleVoterIds: _strings(m['eligibleVoterIds']),
      lenderIds: _strings(m['lenderIds']),
      votesYes: _int(votes['yes']),
      votesNo: _int(votes['no']),
      votingEndsAt: toDate(m['votingEndsAt']),
      reason: m['reason']?.toString(),
    );
  }

  int get fundingRemaining => amount - fundedAmount > 0 ? amount - fundedAmount : 0;
  double get fundingProgress => amount <= 0 ? 0 : (fundedAmount / amount).clamp(0, 1).toDouble();
}

/// The vote as the server will count it (shown while voting is open).
class VoteTally {
  final int eligible;
  final int yes;
  final int no;
  final int quorumPercent;
  final int approvalPercent;

  const VoteTally({required this.eligible, required this.yes, required this.no, required this.quorumPercent, required this.approvalPercent});

  int get cast => yes + no;
  int get needed => (eligible * quorumPercent / 100).ceil();
  bool get quorumReached => eligible > 0 && cast >= needed;
  double get approvalShare => cast == 0 ? 0 : yes / cast;
  bool get wouldApprove => quorumReached && approvalShare * 100 >= approvalPercent;
}

/// What the app offers (the server re-checks every one).
abstract final class LoanActions {
  static bool canVote(Loan l, String uid, {required bool alreadyVoted, required DateTime now}) =>
      l.status == 'voting' &&
      uid != l.borrowerId &&
      l.eligibleVoterIds.contains(uid) &&
      !alreadyVoted &&
      (l.votingEndsAt == null || now.isBefore(l.votingEndsAt!));

  static bool canFund(Loan l, String uid) => l.status == 'funding' && uid != l.borrowerId && l.eligibleVoterIds.contains(uid) && l.fundingRemaining > 0;

  static bool canAcceptAgreement(Loan l, String uid) => l.status == 'agreement_pending' && uid == l.borrowerId;

  static bool canRepay(Loan l, String uid) => (l.status == 'active' || l.status == 'overdue') && uid == l.borrowerId && l.outstandingAmount > 0;

  /// The borrower may withdraw the request until money is committed.
  static bool canCancel(Loan l, String uid) => uid == l.borrowerId && const ['submitted', 'under_review', 'voting'].contains(l.status);

  static String statusLabel(String? s) => const {
        'submitted': 'Submitted',
        'under_review': 'Under review',
        'voting': 'Members are voting',
        'funding': 'Being funded',
        'agreement_pending': 'Agreement to accept',
        'disbursing': 'Being paid out',
        'active': 'Active',
        'overdue': 'Overdue',
        'repaid': 'Repaid',
        'rejected': 'Not approved',
        'cancelled': 'Cancelled',
        'defaulted': 'In default',
      }[s] ??
      (s ?? '-');

  /// The steps of a loan, for the timeline (rejected / cancelled end it early).
  static const List<String> steps = ['submitted', 'under_review', 'voting', 'funding', 'agreement_pending', 'disbursing', 'active', 'repaid'];

  static String installmentLabel(String? s) => const {
        'upcoming': 'Upcoming',
        'due': 'Due',
        'paid': 'Paid',
        'partially_paid': 'Partly paid',
        'overdue': 'Overdue',
      }[s] ??
      (s ?? '-');
}

/// The next unpaid installment of a server schedule (`loan_schedules/{loanId}.installments`).
Map<String, dynamic>? nextInstallment(List<Map<String, dynamic>> installments) {
  for (final i in installments) {
    if (i['status'] != 'paid') return i;
  }
  return null;
}

/// Spideli Finance: member-to-member lending, the pure rules and the write
/// plans the screens use (.claude/FINANCE-DIRECT-FIRESTORE.md section 3.8,
/// .claude/FINANCE-APP-CONTRACT.md section 11). Unit tested in
/// test/finance_lending_rules_test.dart and test/finance_loan_direct_test.dart.
///
/// The customer app writes every member step directly to Firestore (checked
/// by the security rules); money moves only as ledger postings
/// ([FinanceLedger]). The ADMIN reviews the request (`under_review`), writes
/// the credit assessment, opens the vote (`voting` with `votingEndsAt`) or
/// rejects it, applies penalties, decides defaults and restrictions.
///
/// The schedule estimated before applying is labelled an estimate; the
/// binding amounts are the agreement's (written by the last funder from
/// `finance_settings/{regionId}_lending`), the binding dates are set at the pay-out.
library;

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, Timestamp;
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/utils/finance_group_rules.dart';

int _int(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [];

/// `finance_settings/{regionId}_lending` (admin). Null when missing or invalid.
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

  /// The admin's agreement text (`agreementTerms`, optional), copied into
  /// each loan agreement.
  final String agreementTerms;

  /// Loan Centre settings (`loanCentre`: enabled, guarantorRequired, maxAmount).
  final bool loanCentreEnabled;
  final bool loanCentreGuarantorRequired;
  final Map<String, int> loanCentreMaxAmount;

  /// Deadline extension settings (`extension`: enabled, extraInterestPercent, maxDays, maxPerLoan).
  final bool extensionEnabled;
  final double extensionExtraInterestPercent;
  final int extensionMaxDays;
  final int extensionMaxPerLoan;

  /// Blacklist settings (`blacklist`: afterDays, automatic).
  final int blacklistAfterDays;
  final bool blacklistAutomatic;

  /// Commission settings (`commission`: disbursementPercent).
  final double disbursementCommissionPercent;

  /// Whether group tontine loans require a guarantor (spec section 1 & 9).
  final bool groupGuarantorRequired;

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
    this.agreementTerms = '',
    this.loanCentreEnabled = true,
    this.loanCentreGuarantorRequired = true,
    this.loanCentreMaxAmount = const {},
    this.groupGuarantorRequired = true,
    this.extensionEnabled = true,
    this.extensionExtraInterestPercent = 0.0,
    this.extensionMaxDays = 30,
    this.extensionMaxPerLoan = 2,
    this.blacklistAfterDays = 30,
    this.blacklistAutomatic = true,
    this.disbursementCommissionPercent = 0.0,
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
    final lc = raw['loanCentre'] is Map ? Map<String, dynamic>.from(raw['loanCentre'] as Map) : const <String, dynamic>{};
    final ext = raw['extension'] is Map ? Map<String, dynamic>.from(raw['extension'] as Map) : const <String, dynamic>{};
    final bl = raw['blacklist'] is Map ? Map<String, dynamic>.from(raw['blacklist'] as Map) : const <String, dynamic>{};
    final com = raw['commission'] is Map ? Map<String, dynamic>.from(raw['commission'] as Map) : const <String, dynamic>{};
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
      agreementTerms: raw['agreementTerms']?.toString().trim() ?? '',
      loanCentreEnabled: lc['enabled'] != false,
      loanCentreGuarantorRequired: lc['guarantorRequired'] != false,
      loanCentreMaxAmount: _amounts(lc['maxAmount']),
      extensionEnabled: ext['enabled'] != false,
      extensionExtraInterestPercent: _num(ext['extraInterestPercent']),
      extensionMaxDays: _int(ext['maxDays']) > 0 ? _int(ext['maxDays']) : 30,
      extensionMaxPerLoan: _int(ext['maxPerLoan']) > 0 ? _int(ext['maxPerLoan']) : 2,
      blacklistAfterDays: _int(bl['afterDays']) > 0 ? _int(bl['afterDays']) : 30,
      blacklistAutomatic: bl['automatic'] != false,
      disbursementCommissionPercent: _num(com['disbursementPercent']),
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
    final dates = dueDates(firstDue, frequency, n);
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

  /// [n] due dates from [first], one period apart.
  static List<DateTime> dueDates(DateTime first, String frequency, int n) {
    final dates = <DateTime>[first];
    while (dates.length < n) {
      dates.add(Frequency.next(dates.last, frequency));
    }
    return dates;
  }
}

/// A loan application (`loan_applications/{id}`).
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

  /// What the borrower has repaid so far (the lenders' shares are worked
  /// out from it).
  final int repaidAmount;
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

  /// Visibility: "group" (within a tontine) | "public" (Loan Centre, spec section 4).
  final String visibility;

  /// Anonymity: true for tontine loans (lenders see loan_offers, not borrower uid).
  final bool anonymous;

  /// Offered / agreed interest rate percent.
  final double interestPercent;

  /// Professional tontine: 1/3 of confirmed salary cap at request time.
  final int? salaryCap;

  /// Guarantor details: { userId, status: "invited" | "accepted" | "declined", acceptedAt }.
  final Map<String, dynamic>? guarantor;

  /// Who pays an unpaid debt: the sponsor (professional / association) or guarantor.
  final String? liablePartyId;

  /// The member's credit score band ("good" | "fair" | "poor").
  final String? scoreBand;

  final DateTime? createdAt;

  const Loan({
    required this.id,
    required this.borrowerId,
    required this.groupId,
    required this.groupName,
    required this.status,
    required this.currency,
    required this.amount,
    this.fundedAmount = 0,
    this.outstandingAmount = 0,
    this.repaidAmount = 0,
    required this.durationMonths,
    required this.frequency,
    required this.purpose,
    this.description = '',
    this.eligibleVoterIds = const [],
    this.lenderIds = const [],
    this.votesYes = 0,
    this.votesNo = 0,
    this.votingEndsAt,
    this.reason,
    this.regionId = '',
    this.visibility = 'group',
    this.anonymous = true,
    this.interestPercent = 0.0,
    this.salaryCap,
    this.guarantor,
    this.liablePartyId,
    this.scoreBand,
    this.createdAt,
  });

  /// The region it was requested in (`regionId`): its lending settings apply.
  final String regionId;

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
      repaidAmount: _int(m['repaidAmount']),
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
      regionId: m['regionId']?.toString() ?? '',
      visibility: m['visibility']?.toString() ?? 'group',
      anonymous: m['anonymous'] != false,
      interestPercent: _num(m['interestPercent']),
      salaryCap: m['salaryCap'] != null ? _int(m['salaryCap']) : null,
      guarantor: m['guarantor'] is Map ? Map<String, dynamic>.from(m['guarantor'] as Map) : null,
      liablePartyId: m['liablePartyId']?.toString(),
      scoreBand: m['scoreBand']?.toString(),
      createdAt: toDate(m['createdAt']),
    );
  }

  bool get isPublic => visibility == 'public';
  bool get isGroup => visibility == 'group';
  String? get guarantorUserId => guarantor?['userId']?.toString();
  String? get guarantorStatus => guarantor?['status']?.toString();
  bool get hasGuarantor => guarantorUserId != null && guarantorUserId!.isNotEmpty;
  bool get isGuarantorAccepted => guarantorStatus == 'accepted';
  bool get isGuarantorPending => guarantorStatus == 'invited';

  int get fundingRemaining => amount - fundedAmount > 0 ? amount - fundedAmount : 0;
  double get fundingProgress => amount <= 0 ? 0 : (fundedAmount / amount).clamp(0, 1).toDouble();
}

/// The anonymous copy members see (`loan_offers/{loanId}`, spec section 4):
/// contains no borrower uid or name.
class LoanOffer {
  final String loanId;
  final String groupId;
  final String visibility;
  final int amount;
  final String currency;
  final int durationMonths;
  final String repaymentFrequency;
  final double interestPercent;
  final String purpose;
  final String scoreBand;
  final String status;
  final int fundedAmount;
  final int votesYes;
  final int votesNo;
  final DateTime? votingEndsAt;
  final DateTime? createdAt;

  const LoanOffer({
    required this.loanId,
    required this.groupId,
    required this.visibility,
    required this.amount,
    required this.currency,
    required this.durationMonths,
    required this.repaymentFrequency,
    required this.interestPercent,
    required this.purpose,
    required this.scoreBand,
    required this.status,
    required this.fundedAmount,
    required this.votesYes,
    required this.votesNo,
    required this.votingEndsAt,
    required this.createdAt,
  });

  int get fundingRemaining => amount - fundedAmount > 0 ? amount - fundedAmount : 0;
  double get fundingProgress => amount <= 0 ? 0 : (fundedAmount / amount).clamp(0, 1).toDouble();

  static LoanOffer fromMap(Map<String, dynamic> m, DateTime? Function(dynamic) toDate) {
    final votes = m['votes'] is Map ? Map<String, dynamic>.from(m['votes'] as Map) : const <String, dynamic>{};
    return LoanOffer(
      loanId: m['loanId']?.toString() ?? m['id']?.toString() ?? '',
      groupId: m['groupId']?.toString() ?? '',
      visibility: m['visibility']?.toString() ?? 'group',
      amount: _int(m['amount']),
      currency: m['currency']?.toString() ?? '',
      durationMonths: _int(m['durationMonths']),
      repaymentFrequency: m['repaymentFrequency']?.toString() ?? Frequency.monthly,
      interestPercent: _num(m['interestPercent']),
      purpose: m['purpose']?.toString() ?? 'other',
      scoreBand: m['scoreBand']?.toString() ?? 'fair',
      status: m['status']?.toString() ?? 'submitted',
      fundedAmount: _int(m['fundedAmount']),
      votesYes: _int(votes['yes']),
      votesNo: _int(votes['no']),
      votingEndsAt: toDate(m['votingEndsAt']),
      createdAt: toDate(m['createdAt']),
    );
  }

  Loan toLoan({String groupName = ''}) => Loan(
        id: loanId,
        borrowerId: '',
        groupId: groupId,
        groupName: groupName.isNotEmpty ? groupName : (visibility == 'public' ? 'Loan Centre' : ''),
        amount: amount,
        currency: currency,
        purpose: purpose,
        durationMonths: durationMonths,
        frequency: repaymentFrequency,
        status: status,
        fundedAmount: fundedAmount,
        visibility: visibility,
        anonymous: true,
        scoreBand: scoreBand,
        interestPercent: interestPercent,
        createdAt: createdAt,
      );
}


/// A member's credit score (`credit_scores/{uid}`, spec section 5).
class CreditScore {
  final String userId;
  final int score;
  final String band; // "good" | "fair" | "poor"
  final List<CreditFactor> factors;
  final DateTime? updatedAt;

  const CreditScore({
    required this.userId,
    required this.score,
    required this.band,
    required this.factors,
    this.updatedAt,
  });

  static CreditScore fromMap(Map<String, dynamic> m, DateTime? Function(dynamic) toDate) => CreditScore(
        userId: m['userId']?.toString() ?? '',
        score: _int(m['score']),
        band: m['band']?.toString() ?? 'fair',
        factors: m['factors'] is List ? (m['factors'] as List).whereType<Map>().map((x) => CreditFactor.fromMap(Map<String, dynamic>.from(x))).toList() : const [],
        updatedAt: toDate(m['updatedAt']),
      );
}

class CreditFactor {
  final String label;
  final String impact; // "positive" | "negative" | "neutral"
  final String detail;

  const CreditFactor({required this.label, required this.impact, required this.detail});

  static CreditFactor fromMap(Map<String, dynamic> m) => CreditFactor(
        label: m['label']?.toString() ?? '',
        impact: m['impact']?.toString() ?? 'neutral',
        detail: m['detail']?.toString() ?? '',
      );
}

/// A request to extend an installment's due date (`loan_extension_requests/{id}`, spec section 8).
class LoanExtensionRequest {
  final String id;
  final String loanId;
  final String borrowerId;
  final int installmentNumber;
  final int requestedDays;
  final String reason;
  final String status; // "requested" | "approved" | "rejected"
  final double extraInterestPercent;
  final DateTime? newDueDate;
  final String? decidedBy;
  final DateTime? decidedAt;
  final DateTime? createdAt;

  const LoanExtensionRequest({
    required this.id,
    required this.loanId,
    required this.borrowerId,
    required this.installmentNumber,
    required this.requestedDays,
    required this.reason,
    required this.status,
    required this.extraInterestPercent,
    required this.newDueDate,
    required this.decidedBy,
    required this.decidedAt,
    required this.createdAt,
  });

  static LoanExtensionRequest fromMap(Map<String, dynamic> m, DateTime? Function(dynamic) toDate) => LoanExtensionRequest(
        id: m['id']?.toString() ?? '',
        loanId: m['loanId']?.toString() ?? '',
        borrowerId: m['borrowerId']?.toString() ?? '',
        installmentNumber: _int(m['installmentNumber']),
        requestedDays: _int(m['requestedDays']),
        reason: m['reason']?.toString() ?? '',
        status: m['status']?.toString() ?? 'requested',
        extraInterestPercent: _num(m['extraInterestPercent']),
        newDueDate: toDate(m['newDueDate']),
        decidedBy: m['decidedBy']?.toString(),
        decidedAt: toDate(m['decidedAt']),
        createdAt: toDate(m['createdAt']),
      );
}

/// The vote as it is counted when it closes (and shown while it is open),
/// in whole numbers as the security rules count it: quorum when
/// `cast × 100 ≥ eligible × quorumPercent`, approved when
/// `yes × 100 ≥ cast × approvalPercent`.
class VoteTally {
  final int eligible;
  final int yes;
  final int no;
  final int quorumPercent;
  final int approvalPercent;

  const VoteTally({required this.eligible, required this.yes, required this.no, required this.quorumPercent, required this.approvalPercent});

  int get cast => yes + no;
  int get needed => (eligible * quorumPercent / 100).ceil();
  bool get quorumReached => eligible > 0 && cast * 100 >= eligible * quorumPercent;
  double get approvalShare => cast == 0 ? 0 : yes / cast;
  bool get wouldApprove => quorumReached && yes * 100 >= cast * approvalPercent;

  /// Every eligible member has voted: the vote can close before its end.
  bool get everyoneVoted => eligible > 0 && cast >= eligible;
}

/// What the app offers (the security rules check every one again).
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

  /// The voting period is over (a vote without an end date closes when
  /// every eligible member has voted).
  static bool votingEnded(Loan l, DateTime now) => l.votingEndsAt != null && !now.isBefore(l.votingEndsAt!);

  /// Any participant (the borrower or an eligible voter) may close the vote
  /// once it ended or everyone voted: funding or rejected per [VoteTally].
  static bool canCloseVote(Loan l, String uid, {required DateTime now}) {
    if (l.status != 'voting' || uid.isEmpty) return false;
    if (uid != l.borrowerId && !l.eligibleVoterIds.contains(uid)) return false;
    final bool all = l.eligibleVoterIds.isNotEmpty && l.votesYes + l.votesNo >= l.eligibleVoterIds.length;
    return votingEnded(l, now) || all;
  }

  /// A lender with a share of the repayments still to collect.
  static bool canCollect(Loan l, String uid, int available) => uid.isNotEmpty && uid != l.borrowerId && l.lenderIds.contains(uid) && available > 0;

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

/// The next unpaid installment of the schedule (`loan_schedules/{loanId}.installments`).
Map<String, dynamic>? nextInstallment(List<Map<String, dynamic>> installments) {
  for (final i in installments) {
    if (i['status'] != 'paid') return i;
  }
  return null;
}

/// What is left to pay on an installment: its amount due (with any
/// penalty the admin added) less what was already paid on it.
int installmentRemaining(Map<String, dynamic> i) {
  final int due = i['amountDue'] != null ? _int(i['amountDue']) : _int(i['amount']) + _int(i['penalty']);
  return math.max(0, due - _int(i['paidAmount']));
}

// --------------------------------------------------------------- lenders

/// A lender's share of the repayments: each of their fundings
/// (`loan_fundings/{loanId}_{uid}_{n}`) entitles them to
/// `floor(repaid × lent / amount) − collected`, collected by the lender
/// into their wallet (`loan_lender_payout`).
abstract final class LenderShare {
  /// What one funding of [lent] can collect now. Integer arithmetic on big
  /// numbers, rounded down: the loan account never pays out more than it
  /// received.
  static int due({required int repaid, required int lent, required int loanAmount, required int collected}) {
    if (loanAmount <= 0 || lent <= 0 || repaid <= 0) return 0;
    final int share = (BigInt.from(repaid) * BigInt.from(lent) ~/ BigInt.from(loanAmount)).toInt();
    return math.max(0, share - math.max(0, collected));
  }

  static bool _counts(Map<String, dynamic> f) => (f['status'] ?? 'succeeded') == 'succeeded';

  /// (funding id, amount) of each funding with something to collect.
  static List<(String, int)> collectable(Loan l, List<Map<String, dynamic>> fundings) => [
        for (final f in fundings)
          if (_counts(f) && (f['id'] ?? '').toString().isNotEmpty)
            if (due(repaid: l.repaidAmount, lent: _int(f['amount']), loanAmount: l.amount, collected: _int(f['collected'])) case final int d when d > 0) (f['id'].toString(), d),
      ];

  static int available(Loan l, List<Map<String, dynamic>> fundings) => collectable(l, fundings).fold(0, (s, c) => s + c.$2);

  static int lent(List<Map<String, dynamic>> fundings) => fundings.where(_counts).fold(0, (s, f) => s + _int(f['amount']));

  static int collected(List<Map<String, dynamic>> fundings) => fundings.where(_counts).fold(0, (s, f) => s + _int(f['collected']));
}

// ---------------------------------------------------------------- checks

/// Why a step cannot be written, as a `FinanceException` reason (null when
/// it can). Mirrors the security rules so the user hears why.
abstract final class LoanChecks {
  static String? apply({
    required LendingConfig config,
    required String uid,
    required List<String> memberIds,
    required int amount,
    required String currency,
    required int durationMonths,
    required String frequency,
    required bool restricted,
    int? salaryCap,
    bool guarantorRequired = false,
    String? guarantorUserId,
    bool isPublic = false,
  }) {
    if (restricted) return 'finance_restricted';
    if (!isPublic) {
      if (uid.isEmpty || !memberIds.contains(uid)) return 'permission_denied';
      if (LoanPlans.voters(memberIds, uid).isEmpty) return 'loan_no_voters';
    }
    if (!config.currencies.contains(currency) || !config.durationsMonths.contains(durationMonths) || !config.repaymentFrequencies.contains(frequency)) {
      return 'state_changed';
    }
    final int? max = isPublic && config.loanCentreMaxAmount.containsKey(currency) ? config.loanCentreMaxAmount[currency] : config.maxFor(currency);
    if (amount < config.minFor(currency) || (max != null && amount > max)) return 'amount_out_of_range';
    if (salaryCap != null && salaryCap > 0 && amount > salaryCap) return 'salary_cap_exceeded';
    if (guarantorRequired && (guarantorUserId == null || guarantorUserId.trim().isEmpty)) return 'guarantor_required';
    if (guarantorUserId != null && guarantorUserId == uid) return 'invite_self';
    return null;
  }

  static String? vote(Loan l, String uid, {required DateTime now, required bool restricted}) {
    if (restricted) return 'finance_restricted';
    return LoanActions.canVote(l, uid, alreadyVoted: false, now: now) ? null : 'state_changed';
  }

  static String? closeVote(Loan l, String uid, {required DateTime now}) => LoanActions.canCloseVote(l, uid, now: now) ? null : 'state_changed';

  /// [walletBalance] is null for a gateway payment.
  static String? fund(Loan l, String uid, int amount, {required bool restricted, int? walletBalance}) {
    if (restricted) return 'finance_restricted';
    if (!LoanActions.canFund(l, uid)) return 'state_changed';
    if (amount <= 0 || amount > l.fundingRemaining) return 'amount_out_of_range';
    if (walletBalance != null && walletBalance < amount) return 'insufficient_funds';
    return null;
  }

  static String? accept(Loan l, String uid, Map<String, dynamic>? agreement, int version, {required bool restricted, required int loanBalance}) {
    if (restricted) return 'finance_restricted';
    if (!LoanActions.canAcceptAgreement(l, uid) || agreement == null || agreement['acceptedAt'] != null) return 'state_changed';
    if (_int(agreement['version']) != version) return 'agreement_outdated';
    if (l.fundedAmount <= 0 || l.fundedAmount < l.amount || loanBalance < l.fundedAmount) return 'state_changed';
    return null;
  }

  /// [walletBalance] is null for a gateway payment.
  static String? repay(Loan l, String uid, int amount, {int? walletBalance}) {
    if (!LoanActions.canRepay(l, uid)) return 'state_changed';
    if (amount <= 0 || amount > l.outstandingAmount) return 'amount_out_of_range';
    if (walletBalance != null && walletBalance < amount) return 'insufficient_funds';
    return null;
  }

  static String? cancel(Loan l, String uid) => LoanActions.canCancel(l, uid) ? null : 'state_changed';
}

// ----------------------------------------------------------------- plans

/// The writes of each member step, as data (pure; applied in one batch or
/// transaction by FinanceLendingService). Ids are deterministic so a retry
/// can never write twice: `loan_votes/{loanId}_{uid}`,
/// `loan_fundings/{loanId}_{uid}_{n}`, `loan_repayments/{loanId}_{requestKey}`,
/// `loan_disbursements/{loanId}`, `loan_agreements/{loanId}`,
/// `loan_schedules/{loanId}`, `loan_offers/{loanId}`,
/// `loan_extension_requests/{id}`; the loan's money sits in `loan_{loanId}`.
abstract final class LoanPlans {
  static Object get _now => FieldValue.serverTimestamp();

  static String _loan(String id) => 'loan_applications/$id';

  /// Who votes on (and may fund) a request: the group's members but the borrower.
  static List<String> voters(List<String> memberIds, String borrowerId) => [
        for (final m in memberIds.toSet())
          if (m.isNotEmpty && m != borrowerId) m,
      ];

  static String voteId(String loanId, String uid) => '${loanId}_$uid';

  static String fundingId(String loanId, String uid, int n) => '${loanId}_${uid}_$n';

  static String repaymentId(String loanId, String requestKey) => '${loanId}_$requestKey';

  static String extensionId(String loanId, int installmentNumber) => '${loanId}_$installmentNumber';

  /// A new request in [groupId] (a tontine the borrower belongs to) or Loan Centre (visibility: "public").
  /// Writes BOTH `loan_applications/$loanId` AND the anonymous copy `loan_offers/$loanId` (spec section 4).
  static List<FinanceWrite> apply({
    required String loanId,
    required String uid,
    required String groupId,
    required String groupName,
    required List<String> memberIds,
    required int amount,
    required String currency,
    required String purpose,
    required int durationMonths,
    required String repaymentFrequency,
    required String description,
    String visibility = 'group',
    bool anonymous = true,
    double interestPercent = 0.0,
    int? salaryCap,
    String? guarantorUserId,
    String? liablePartyId,
    String? scoreBand,
  }) {
    final bool hasGuarantor = guarantorUserId != null && guarantorUserId.isNotEmpty;
    final String initialStatus = hasGuarantor ? 'guarantor_pending' : 'submitted';
    return [
      FinanceWrite(_loan(loanId), 'create', {
        'id': loanId,
        'borrowerId': uid,
        'groupId': groupId,
        'groupName': groupName,
        'visibility': visibility,
        'anonymous': anonymous,
        'interestPercent': interestPercent,
        if (salaryCap != null) 'salaryCap': salaryCap,
        if (hasGuarantor)
          'guarantor': {
            'userId': guarantorUserId,
            'status': 'invited',
            'invitedAt': _now,
          },
        if (liablePartyId != null && liablePartyId.isNotEmpty) 'liablePartyId': liablePartyId,
        if (scoreBand != null && scoreBand.isNotEmpty) 'scoreBand': scoreBand,
        'status': initialStatus,
        'currency': currency,
        'amount': amount,
        'fundedAmount': 0,
        'outstandingAmount': 0,
        'repaidAmount': 0,
        'durationMonths': durationMonths,
        'repaymentFrequency': repaymentFrequency,
        'purpose': purpose,
        'description': description,
        'eligibleVoterIds': voters(memberIds, uid),
        'lenderIds': <String>[],
        'votes': {'yes': 0, 'no': 0},
        'documents': <Map<String, dynamic>>[],
        'createdAt': _now,
        'updatedAt': _now,
      }),
      FinanceWrite('loan_offers/$loanId', 'create', {
        'loanId': loanId,
        'groupId': groupId,
        'visibility': visibility,
        'amount': amount,
        'currency': currency,
        'durationMonths': durationMonths,
        'repaymentFrequency': repaymentFrequency,
        'interestPercent': interestPercent,
        'purpose': purpose,
        'scoreBand': scoreBand ?? 'fair',
        'status': initialStatus,
        'fundedAmount': 0,
        'votes': {'yes': 0, 'no': 0},
        'votingEndsAt': null,
        'createdAt': _now,
        'updatedAt': _now,
      }),
    ];
  }

  /// A supporting document already uploaded to [storagePath]
  /// (`loan_documents/{uid}/{loanId}/…`).
  static List<FinanceWrite> addDocument(String loanId, {required String name, required String storagePath}) => [
        FinanceWrite(_loan(loanId), 'update', {
          'documents': FieldValue.arrayUnion([
            {'name': name, 'storagePath': storagePath},
          ]),
          'updatedAt': _now,
        }),
      ];

  /// One vote (create-only) and its count in both application and anonymous offer.
  static List<FinanceWrite> vote(Loan l, String uid, {required bool approve, String comment = ''}) => [
        FinanceWrite('loan_votes/${voteId(l.id, uid)}', 'create', {
          'loanId': l.id,
          'voterId': uid,
          'approve': approve,
          'comment': comment,
          'at': _now,
        }),
        FinanceWrite(_loan(l.id), 'update', {
          approve ? 'votes.yes' : 'votes.no': FieldValue.increment(1),
          'updatedAt': _now,
        }),
        FinanceWrite('loan_offers/${l.id}', 'update', {
          approve ? 'votes.yes' : 'votes.no': FieldValue.increment(1),
          'updatedAt': _now,
        }),
      ];

  /// Closes the vote: `funding` with the quorum and the approval, else
  /// `rejected` (`reason: "vote"`). Updates both application and anonymous offer.
  static ({String status, List<FinanceWrite> writes}) closeVote(Loan l, {required int quorumPercent, required int approvalPercent}) {
    final tally = VoteTally(eligible: l.eligibleVoterIds.length, yes: l.votesYes, no: l.votesNo, quorumPercent: quorumPercent, approvalPercent: approvalPercent);
    final String status = tally.wouldApprove ? 'funding' : 'rejected';
    return (
      status: status,
      writes: [
        FinanceWrite(_loan(l.id), 'update', {
          'status': status,
          if (status == 'rejected') 'reason': 'vote',
          'votingClosedAt': _now,
          'updatedAt': _now,
        }),
        FinanceWrite('loan_offers/${l.id}', 'update', {
          'status': status,
          'updatedAt': _now,
        }),
      ],
    );
  }

  /// Guarantor accepts or declines being a guarantor for a loan (spec section 4).
  static List<FinanceWrite> respondGuarantor(String loanId, String uid, bool accept) => [
        FinanceWrite(_loan(loanId), 'update', {
          'guarantor.status': accept ? 'accepted' : 'declined',
          if (accept) 'guarantor.acceptedAt': _now,
          'status': accept ? 'submitted' : 'rejected',
          if (!accept) 'reason': 'guarantor_declined',
          'updatedAt': _now,
        }),
        FinanceWrite('loan_offers/$loanId', 'update', {
          'status': accept ? 'submitted' : 'rejected',
          'updatedAt': _now,
        }),
      ];

  /// Borrower requests a deadline extension for an installment (spec section 8).
  static List<FinanceWrite> requestExtension({
    required String extensionId,
    required String loanId,
    required String borrowerId,
    required int installmentNumber,
    required int requestedDays,
    required String reason,
    double extraInterestPercent = 0.0,
  }) =>
      [
        FinanceWrite('loan_extension_requests/$extensionId', 'create', {
          'id': extensionId,
          'loanId': loanId,
          'borrowerId': borrowerId,
          'installmentNumber': installmentNumber,
          'requestedDays': requestedDays,
          'reason': reason,
          'status': 'requested',
          'extraInterestPercent': extraInterestPercent,
          'newDueDate': null,
          'decidedBy': null,
          'decidedAt': null,
          'createdAt': _now,
        }),
      ];

  /// The agreement the last funder issues (version 1): the terms of
  /// `finance_settings/{regionId}_lending` and the installments of [LoanCalculator]
  /// (amounts only: the dates are set at the pay-out).
  static Map<String, dynamic> agreement(Loan l, LendingConfig cfg, DateTime now) {
    final e = LoanCalculator.estimate(
      principal: l.amount,
      months: l.durationMonths,
      frequency: l.frequency,
      method: cfg.interestMethod,
      annualPercent: cfg.annualInterestPercent,
      feePercent: cfg.feePercent,
      firstDue: Frequency.next(now, l.frequency),
    );
    // The fee is taken from the pay-out: never all of it.
    final int fee = math.min(e.fee, math.max(0, l.amount - 1));
    return {
      'loanId': l.id,
      'borrowerId': l.borrowerId,
      'version': 1,
      'principal': l.amount,
      'currency': l.currency,
      'interestMethod': cfg.interestMethod,
      'annualInterestPercent': cfg.annualInterestPercent,
      'fee': fee,
      'totalRepayable': e.totalRepaid,
      'latePenaltyPercent': cfg.latePenaltyPercent,
      'durationMonths': l.durationMonths,
      'repaymentFrequency': l.frequency,
      'terms': cfg.agreementTerms,
      'installments': [
        for (final i in e.installments) {'number': i.number, 'amount': i.total, 'principal': i.principal, 'interest': i.interest},
      ],
      'createdAt': _now,
      'acceptedAt': null,
    };
  }

  /// A lender funds [amount]: posting `wallet | platform → loan_{loanId}`
  /// (`loan_funding`), `loan_fundings/{loanId}_{uid}_{n}`, `fundedAmount`
  /// and `lenderIds`. The last funder also sets `agreement_pending` and
  /// creates the agreement ([agreement], required then).
  static FinancePosting fund({
    required Loan loan,
    required String uid,
    required int amount,
    required int n,
    required String requestKey,
    required FinanceFunding funding,
    required String walletId,
    required bool loanAccountExists,
    Map<String, dynamic>? agreement,
    String? txId,
    String? reference,
  }) {
    final String id = fundingId(loan.id, uid, n);
    final String account = FinanceLedger.loanAccountId(loan.id);
    final bool last = loan.fundedAmount + amount >= loan.amount;
    assert(!last || agreement != null, 'the last funder issues the agreement');
    final posting = FinanceLedger.plan(
      type: 'loan_funding',
      currency: loan.currency,
      from: funding.isWallet ? walletId : FinanceLedger.platformId(loan.currency),
      to: account,
      amount: amount,
      newAccounts: loanAccountExists ? const {} : {account: FinanceLedger.poolFields('loan', loan.id, loan.currency)},
      userIds: [uid],
      sourceKind: 'loan_fundings',
      sourceId: id,
      createdBy: uid,
      funding: funding,
      description: 'Loan funding',
      txId: txId,
      reference: reference,
    );
    return FinancePosting(posting.txId, posting.reference, [
      ...posting.writes,
      FinanceWrite('loan_fundings/$id', 'create', {
        'id': id,
        'loanId': loan.id,
        'lenderId': uid,
        'borrowerId': loan.borrowerId,
        'amount': amount,
        'currency': loan.currency,
        'status': 'succeeded',
        'funding': funding.isWallet ? 'wallet' : 'gateway',
        'reference': posting.reference,
        'txId': posting.txId,
        'requestKey': requestKey,
        'collected': 0,
        'createdAt': _now,
      }),
      FinanceWrite(_loan(loan.id), 'update', {
        'fundedAmount': loan.fundedAmount + amount,
        'lenderIds': FieldValue.arrayUnion([uid]),
        if (last) 'status': 'agreement_pending',
        if (last) 'fundedAt': _now,
        'updatedAt': _now,
      }),
      FinanceWrite('loan_offers/${loan.id}', 'update', {
        'fundedAmount': loan.fundedAmount + amount,
        if (last) 'status': 'agreement_pending',
        'updatedAt': _now,
      }),
      if (last && agreement != null) FinanceWrite('loan_agreements/${loan.id}', 'create', agreement),
    ]);
  }

  /// The binding schedule from the agreement's installments, the first due
  /// one period after [disbursedAt].
  static List<Map<String, dynamic>> schedule(Map<String, dynamic> agreement, String frequency, DateTime disbursedAt) {
    var list = agreement['installments'] is List ? (agreement['installments'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : <Map<String, dynamic>>[];
    if (list.isEmpty) {
      final String method = agreement['interestMethod']?.toString() == 'flat' ? 'flat' : 'declining';
      final e = LoanCalculator.estimate(
        principal: _int(agreement['principal']),
        months: _int(agreement['durationMonths']),
        frequency: frequency,
        method: method,
        annualPercent: _num(agreement['annualInterestPercent']),
        firstDue: Frequency.next(disbursedAt, frequency),
      );
      list = [for (final i in e.installments) {'number': i.number, 'amount': i.total, 'principal': i.principal, 'interest': i.interest}];
    }
    final dates = LoanCalculator.dueDates(Frequency.next(disbursedAt, frequency), frequency, list.length);
    return [
      for (final (k, i) in list.indexed)
        {
          'number': i['number'] is num ? _int(i['number']) : k + 1,
          'dueDate': Timestamp.fromDate(dates[k]),
          'amount': _int(i['amount']),
          'principal': _int(i['principal']),
          'interest': _int(i['interest']),
          'penalty': 0,
          'amountDue': _int(i['amount']),
          'paidAmount': 0,
          'status': 'upcoming',
        },
    ];
  }

  /// The borrower accepts the agreement [agreement]: `acceptedAt` and the
  /// version, the pay-out (posting `loan_{loanId} → borrower wallet`,
  /// `loan_disbursement`: the whole funded amount leaves the loan account,
  /// the fee going to the platform), `loan_disbursements/{loanId}`, the
  /// loan `active` with `outstandingAmount = totalRepayable`, and
  /// `loan_schedules/{loanId}`.
  static FinancePosting accept({
    required Loan loan,
    required Map<String, dynamic> agreement,
    required String uid,
    required String walletId,
    required bool walletExists,
    required DateTime now,
    String? txId,
    String? reference,
  }) {
    final int funded = loan.fundedAmount;
    final int fee = math.min(math.max(0, _int(agreement['fee'])), math.max(0, funded - 1));
    final int version = _int(agreement['version']);
    final posting = FinanceLedger.plan(
      type: 'loan_disbursement',
      currency: loan.currency,
      from: FinanceLedger.loanAccountId(loan.id),
      to: walletId,
      amount: funded - fee,
      fee: fee,
      newAccounts: walletExists ? const {} : {walletId: FinanceLedger.walletFields(uid, loan.currency)},
      userIds: [uid],
      sourceKind: 'loan_disbursements',
      sourceId: loan.id,
      createdBy: uid,
      description: 'Loan pay-out',
      txId: txId,
      reference: reference,
    );
    return FinancePosting(posting.txId, posting.reference, [
      ...posting.writes,
      FinanceWrite('loan_disbursements/${loan.id}', 'create', {
        'id': loan.id,
        'loanId': loan.id,
        'borrowerId': uid,
        'amount': funded - fee,
        'fee': fee,
        'currency': loan.currency,
        'status': 'succeeded',
        'reference': posting.reference,
        'txId': posting.txId,
        'paidAt': _now,
      }),
      FinanceWrite('loan_agreements/${loan.id}', 'update', {'acceptedAt': _now}),
      FinanceWrite(_loan(loan.id), 'update', {
        'status': 'active',
        'acceptedAt': _now,
        'agreementVersion': version,
        'disbursedAt': _now,
        'outstandingAmount': _int(agreement['totalRepayable']),
        'repaidAmount': 0,
        'updatedAt': _now,
      }),
      FinanceWrite('loan_offers/${loan.id}', 'update', {
        'status': 'active',
        'updatedAt': _now,
      }),
      FinanceWrite('loan_schedules/${loan.id}', 'create', {
        'loanId': loan.id,
        'borrowerId': uid,
        'currency': loan.currency,
        'installments': schedule(agreement, loan.frequency, now),
        'createdAt': _now,
        'updatedAt': _now,
      }),
    ]);
  }

  /// [amount] allocated to the oldest installments first; a settled loan
  /// ([settled]: nothing outstanding any more) has every installment paid.
  static List<Map<String, dynamic>> allocate(List<Map<String, dynamic>> installments, int amount, {bool settled = false}) {
    int left = amount;
    final out = <Map<String, dynamic>>[];
    for (final i in installments) {
      final m = Map<String, dynamic>.from(i);
      if (m['status'] != 'paid') {
        final int pay = math.min(left, installmentRemaining(m));
        left -= pay;
        if (pay > 0) m['paidAmount'] = _int(m['paidAmount']) + pay;
        if (settled || installmentRemaining(m) <= 0) {
          m['status'] = 'paid';
        } else if (pay > 0) {
          m['status'] = 'partially_paid';
        }
      }
      out.add(m);
    }
    return out;
  }

  /// The borrower repays [amount]: posting `wallet | platform → loan_{loanId}`
  /// (`loan_repayment`), `loan_repayments/{loanId}_{requestKey}`,
  /// `outstandingAmount` − amount (0: `repaid`), `repaidAmount` + amount,
  /// and the installments paid in order ([installments]: the schedule).
  static FinancePosting repay({
    required Loan loan,
    required String uid,
    required int amount,
    required String requestKey,
    required FinanceFunding funding,
    required String walletId,
    List<Map<String, dynamic>>? installments,
    String? txId,
    String? reference,
  }) {
    final String id = repaymentId(loan.id, requestKey);
    final int outstanding = math.max(0, loan.outstandingAmount - amount);
    final posting = FinanceLedger.plan(
      type: 'loan_repayment',
      currency: loan.currency,
      from: funding.isWallet ? walletId : FinanceLedger.platformId(loan.currency),
      to: FinanceLedger.loanAccountId(loan.id),
      amount: amount,
      userIds: [uid],
      sourceKind: 'loan_repayments',
      sourceId: id,
      createdBy: uid,
      funding: funding,
      description: 'Loan repayment',
      txId: txId,
      reference: reference,
    );
    return FinancePosting(posting.txId, posting.reference, [
      ...posting.writes,
      FinanceWrite('loan_repayments/$id', 'create', {
        'id': id,
        'loanId': loan.id,
        'borrowerId': uid,
        'amount': amount,
        'currency': loan.currency,
        'status': 'succeeded',
        'funding': funding.isWallet ? 'wallet' : 'gateway',
        'reference': posting.reference,
        'txId': posting.txId,
        'requestKey': requestKey,
        'createdAt': _now,
      }),
      FinanceWrite(_loan(loan.id), 'update', {
        'outstandingAmount': outstanding,
        'repaidAmount': loan.repaidAmount + amount,
        if (outstanding == 0) 'status': 'repaid',
        if (outstanding == 0) 'repaidAt': _now,
        'updatedAt': _now,
      }),
      if (outstanding == 0)
        FinanceWrite('loan_offers/${loan.id}', 'update', {
          'status': 'repaid',
          'updatedAt': _now,
        }),
      if (installments != null && installments.isNotEmpty)
        FinanceWrite('loan_schedules/${loan.id}', 'update', {
          'installments': allocate(installments, amount, settled: outstanding == 0),
          'updatedAt': _now,
        }),
    ]);
  }

  /// A lender collects [amount] of their share on the funding [funding]
  /// (a `loan_fundings` document with its `id`): posting
  /// `loan_{loanId} → lender wallet` (`loan_lender_payout`) and `collected`.
  static FinancePosting collect({
    required Loan loan,
    required Map<String, dynamic> funding,
    required String uid,
    required int amount,
    required String walletId,
    required bool walletExists,
    String? txId,
    String? reference,
  }) {
    final String id = funding['id'].toString();
    final posting = FinanceLedger.plan(
      type: 'loan_lender_payout',
      currency: loan.currency,
      from: FinanceLedger.loanAccountId(loan.id),
      to: walletId,
      amount: amount,
      newAccounts: walletExists ? const {} : {walletId: FinanceLedger.walletFields(uid, loan.currency)},
      userIds: [uid],
      sourceKind: 'loan_fundings',
      sourceId: id,
      createdBy: uid,
      description: 'Loan repayment share',
      txId: txId,
      reference: reference,
    );
    return FinancePosting(posting.txId, posting.reference, [
      ...posting.writes,
      FinanceWrite('loan_fundings/$id', 'update', {
        'collected': _int(funding['collected']) + amount,
        'updatedAt': _now,
      }),
    ]);
  }

  /// The borrower withdraws the request (no money is committed yet).
  static List<FinanceWrite> cancel(Loan l) => [
        FinanceWrite(_loan(l.id), 'update', {'status': 'cancelled', 'cancelledAt': _now, 'updatedAt': _now}),
        FinanceWrite('loan_offers/${l.id}', 'update', {'status': 'cancelled', 'updatedAt': _now}),
      ];
}

/// The message (translation key) of a loan step's refusal; other reasons
/// fall back to the shared finance messages.
abstract final class LoanErrors {
  static const Map<String, String> messages = {
    'permission_denied': 'You are not allowed to do this.',
    'finance_restricted': 'Your access to loans is restricted. Contact support.',
    'state_changed': 'This action is no longer possible. Please refresh.',
    'loan_no_voters': 'Your group has no other member to vote on your request.',
    'agreement_outdated': 'The agreement changed. Please read the new version.',
    'nothing_to_collect': 'There is nothing to collect yet.',
    'salary_cap_exceeded': 'The requested amount exceeds your salary cap (1/3 of confirmed salary).',
    'guarantor_required': 'A guarantor is required for this loan request.',
    'invite_self': 'You cannot select yourself as a guarantor.',
  };

  static String? message(String? reason) => messages[reason];
}

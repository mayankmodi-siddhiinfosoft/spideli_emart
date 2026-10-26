/// Spideli Finance: savings goals and tontines, the pure rules the screens
/// use (.claude/FINANCE-APP-CONTRACT.md sections 8-9) and the writes the app
/// makes itself (.claude/FINANCE-DIRECT-FIRESTORE.md 3.6, 3.7): every write
/// is planned here as data ([SavingsWrites], [TontineWrites]) and checked by
/// the security rules; money moves only as ledger postings
/// ([FinanceLedger.plan]). The admin panel does the steps that need a person
/// (group withdrawals and cancellations, disputes, restrictions). Unit tested
/// in test/finance_group_rules_test.dart, test/finance_savings_direct_test.dart
/// and test/finance_tontine_direct_test.dart.
library;

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/utils/finance_security_rules.dart';

int _int(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [];

/// Contribution frequencies (savings schedules and tontines).
abstract final class Frequency {
  static const String weekly = 'weekly';
  static const String biweekly = 'biweekly';
  static const String monthly = 'monthly';
  static const List<String> all = [weekly, biweekly, monthly];

  /// How many times a frequency occurs per month, on average.
  static double perMonth(String? f) => switch (f) {
        weekly => 52 / 12,
        biweekly => 26 / 12,
        monthly => 1,
        _ => 0,
      };

  /// The date after [from] for [f]; monthly keeps the day (clamped to the month end).
  static DateTime next(DateTime from, String f) {
    switch (f) {
      case weekly:
        return from.add(const Duration(days: 7));
      case biweekly:
        return from.add(const Duration(days: 14));
      default:
        final int y = from.month == 12 ? from.year + 1 : from.year;
        final int m = from.month == 12 ? 1 : from.month + 1;
        final int lastDay = DateTime(y, m + 1, 0).day;
        return DateTime(y, m, from.day > lastDay ? lastDay : from.day, from.hour, from.minute);
    }
  }

  static String label(String? f) => switch (f) {
        weekly => 'Every week',
        biweekly => 'Every two weeks',
        monthly => 'Every month',
        _ => 'No schedule',
      };
}

/// The savings settings of a region (`finance_settings/{regionId}_savings`, admin). Null when missing or malformed: the
/// app then says savings goals are not available.
class SavingsConfig {
  final List<String> purposes;
  final List<String> currencies;
  final List<String> frequencies;
  final bool groupGoals;
  final int maxMembers;
  final bool earlyWithdrawal;
  final List<String> paymentMethods;

  const SavingsConfig({
    required this.purposes,
    required this.currencies,
    required this.frequencies,
    required this.groupGoals,
    required this.maxMembers,
    required this.earlyWithdrawal,
    required this.paymentMethods,
  });

  static SavingsConfig? parse(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final purposes = _strings(raw['purposes']);
    final currencies = _strings(raw['currencies']).where((c) => RegExp(r'^[A-Z]{3}$').hasMatch(c)).toList();
    final methods = _strings(raw['paymentMethods']);
    if (purposes.isEmpty || currencies.isEmpty || methods.isEmpty) return null;
    final ew = raw['earlyWithdrawal'];
    return SavingsConfig(
      purposes: purposes,
      currencies: currencies,
      frequencies: _strings(raw['frequencies']).where(Frequency.all.contains).toList(),
      groupGoals: raw['groupGoals'] == true,
      maxMembers: _int(raw['maxMembers']) < 2 ? 2 : _int(raw['maxMembers']),
      earlyWithdrawal: ew is Map ? ew['allowed'] == true : ew == true,
      paymentMethods: methods,
    );
  }
}

/// The tontine settings of a region (`finance_settings/{regionId}_tontines`, admin).
class TontineConfig {
  final List<String> currencies;
  final List<String> frequencies;
  final int minMembers;
  final int maxMembers;
  final List<String> payoutOrderMethods;
  final List<String> paymentMethods;
  final List<String> types;
  final double salaryCapFraction;
  final bool groupGuarantorRequired;
  final double commissionContributionPercent;
  final double commissionPayoutPercent;

  /// Minimum contribution per currency, minor units.
  final Map<String, int> minContribution;

  const TontineConfig({
    required this.currencies,
    required this.frequencies,
    required this.minMembers,
    required this.maxMembers,
    required this.payoutOrderMethods,
    required this.paymentMethods,
    required this.minContribution,
    this.types = const ['group', 'professional', 'association'],
    this.salaryCapFraction = 0.3333,
    this.groupGuarantorRequired = true,
    this.commissionContributionPercent = 0.0,
    this.commissionPayoutPercent = 0.0,
  });

  static TontineConfig? parse(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final currencies = _strings(raw['currencies']).where((c) => RegExp(r'^[A-Z]{3}$').hasMatch(c)).toList();
    final frequencies = _strings(raw['frequencies']).where(Frequency.all.contains).toList();
    final methods = _strings(raw['paymentMethods']);
    final int min = _int(raw['minMembers']);
    final int max = _int(raw['maxMembers']);
    if (currencies.isEmpty || frequencies.isEmpty || methods.isEmpty || min < 2 || max < min) return null;
    final mc = raw['minContribution'];
    final types = _strings(raw['types']).isEmpty ? const ['group', 'professional', 'association'] : _strings(raw['types']);
    final pro = raw['professional'] is Map ? Map<String, dynamic>.from(raw['professional'] as Map) : const <String, dynamic>{};
    final grp = raw['group'] is Map ? Map<String, dynamic>.from(raw['group'] as Map) : const <String, dynamic>{};
    final com = raw['commission'] is Map ? Map<String, dynamic>.from(raw['commission'] as Map) : const <String, dynamic>{};
    final double cap = pro['salaryCapFraction'] is num ? (pro['salaryCapFraction'] as num).toDouble() : 0.3333;
    final bool grpGuarantor = grp['guarantorRequired'] != false;
    final double comContrib = com['contributionPercent'] is num ? (com['contributionPercent'] as num).toDouble() : 0.0;
    final double comPayout = com['payoutPercent'] is num ? (com['payoutPercent'] as num).toDouble() : 0.0;
    return TontineConfig(
      currencies: currencies,
      frequencies: frequencies,
      minMembers: min,
      maxMembers: max,
      payoutOrderMethods: _strings(raw['payoutOrderMethods']).isEmpty ? const ['fixed'] : _strings(raw['payoutOrderMethods']),
      paymentMethods: methods,
      minContribution: mc is Map ? {for (final e in mc.entries) e.key.toString(): _int(e.value)} : const {},
      types: types,
      salaryCapFraction: cap,
      groupGuarantorRequired: grpGuarantor,
      commissionContributionPercent: comContrib,
      commissionPayoutPercent: comPayout,
    );
  }

  int minFor(String currency) => minContribution[currency] ?? 1;
}

/// A savings goal as the server stores it (`savings_goals/{id}`).
class SavingsGoal {
  final String id;
  final String name;
  final String purpose;
  final String description;
  final String ownerId;
  final List<String> memberIds;
  final List<String> invitedIds;
  final String currency;
  final int targetAmount;

  /// Funds ACTUALLY deposited (the goal account's balance), never the target.
  final int savedAmount;
  final DateTime? deadline;
  final String status;
  final String? frequency;
  final int scheduleAmount;

  /// The region it was created in (`regionId`): its savings settings apply.
  final String regionId;

  const SavingsGoal({
    required this.id,
    required this.name,
    required this.purpose,
    required this.description,
    required this.ownerId,
    required this.memberIds,
    required this.invitedIds,
    required this.currency,
    required this.targetAmount,
    required this.savedAmount,
    required this.deadline,
    required this.status,
    required this.frequency,
    required this.scheduleAmount,
    this.regionId = '',
  });

  static SavingsGoal fromMap(Map<String, dynamic> m, DateTime? Function(dynamic) toDate) {
    final schedule = m['schedule'] is Map ? Map<String, dynamic>.from(m['schedule'] as Map) : const <String, dynamic>{};
    return SavingsGoal(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      purpose: m['purpose']?.toString() ?? 'other',
      description: m['description']?.toString() ?? '',
      ownerId: m['ownerId']?.toString() ?? '',
      memberIds: _strings(m['memberIds']),
      invitedIds: _strings(m['invitedIds']),
      currency: m['currency']?.toString() ?? '',
      targetAmount: _int(m['targetAmount']),
      savedAmount: _int(m['savedAmount']),
      deadline: toDate(m['deadline']),
      status: m['status']?.toString() ?? 'active',
      frequency: Frequency.all.contains(schedule['frequency']) ? schedule['frequency'].toString() : null,
      scheduleAmount: _int(schedule['amount']),
      regionId: m['regionId']?.toString() ?? '',
    );
  }

  bool get isGroup => memberIds.length > 1 || invitedIds.isNotEmpty;

  /// The owner alone holds money in it (pending invitations do not count):
  /// the owner withdraws and cancels directly. A group goal's withdrawals
  /// and cancellation are decided by the admin.
  bool get isSolo => memberIds.length <= 1;
  bool get isActive => status == 'active';

  /// The goal's ledger account (`financial_accounts/goal_{id}`).
  String get accountId => FinanceLedger.goalAccountId(id);
  int get remaining => targetAmount - savedAmount > 0 ? targetAmount - savedAmount : 0;
  double get progress => targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0, 1).toDouble();
}

class DatedAmount {
  final DateTime at;
  final int amount;
  const DatedAmount(this.at, this.amount);
}

abstract final class SavingsProjection {
  /// Expected monthly saving: the schedule when there is one, else the
  /// average of the SUCCEEDED contributions since the first one (at least a
  /// one-month window, so one early deposit does not look like a monthly rate).
  static double monthlyRate(SavingsGoal goal, List<DatedAmount> contributions, DateTime now) {
    if (goal.frequency != null && goal.scheduleAmount > 0) return goal.scheduleAmount * Frequency.perMonth(goal.frequency);
    if (contributions.isEmpty) return 0;
    final first = contributions.map((c) => c.at).reduce((a, b) => a.isBefore(b) ? a : b);
    final double months = now.difference(first).inDays / 30.44;
    final int total = contributions.fold(0, (s, c) => s + c.amount);
    return total / (months < 1 ? 1 : months);
  }

  /// When the target would be reached at [monthlyRate]; now when already
  /// reached; null when nothing is being saved.
  static DateTime? projectedCompletion(SavingsGoal goal, double monthlyRate, DateTime now) {
    if (goal.remaining == 0) return now;
    if (monthlyRate <= 0) return null;
    return now.add(Duration(days: (goal.remaining / monthlyRate * 30.44).ceil()));
  }

  /// The monthly amount still needed to reach the target by the deadline
  /// (null without a deadline; the whole remainder when it is this month or past).
  static int? neededMonthly(SavingsGoal goal, DateTime now) {
    final d = goal.deadline;
    if (d == null) return null;
    if (goal.remaining == 0) return 0;
    final int months = (d.year - now.year) * 12 + d.month - now.month;
    return months <= 0 ? goal.remaining : (goal.remaining / months).ceil();
  }

  static bool? onTrack(SavingsGoal goal, DateTime? projected) {
    if (goal.deadline == null || projected == null) return null;
    return !projected.isAfter(goal.deadline!);
  }
}

/// A tontine as the server stores it (`tontines/{id}`).
class Tontine {
  final String id;
  final String name;
  final String description;
  final String rules;
  final String currency;
  final int contributionAmount;
  final String frequency;
  final int membersLimit;
  final String payoutOrderMethod;
  final String status;
  final List<String> adminIds;
  final List<String> memberIds;
  final int currentCycle;
  final DateTime? startDate;
  final DateTime? nextDueAt;

  /// The region it was created in (`regionId`): its tontine settings apply.
  final String regionId;

  /// The type of tontine: "professional" | "association" | "group" (missing/default = "group").
  final String type;

  /// The company / association uid sponsoring this tontine (professional and association only).
  final String? sponsorId;

  const Tontine({
    required this.id,
    required this.name,
    required this.description,
    required this.rules,
    required this.currency,
    required this.contributionAmount,
    required this.frequency,
    required this.membersLimit,
    required this.payoutOrderMethod,
    required this.status,
    required this.adminIds,
    required this.memberIds,
    required this.currentCycle,
    required this.startDate,
    required this.nextDueAt,
    this.regionId = '',
    this.type = 'group',
    this.sponsorId,
  });

  static Tontine fromMap(Map<String, dynamic> m, DateTime? Function(dynamic) toDate) => Tontine(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        description: m['description']?.toString() ?? '',
        rules: m['rules']?.toString() ?? '',
        currency: m['currency']?.toString() ?? '',
        contributionAmount: _int(m['contributionAmount']),
        frequency: m['frequency']?.toString() ?? Frequency.monthly,
        membersLimit: _int(m['membersLimit']),
        payoutOrderMethod: m['payoutOrderMethod']?.toString() ?? 'fixed',
        status: m['status']?.toString() ?? 'forming',
        adminIds: _strings(m['adminIds']),
        memberIds: _strings(m['memberIds']),
        currentCycle: _int(m['currentCycle']),
        startDate: toDate(m['startDate']),
        nextDueAt: toDate(m['nextDueAt']),
        regionId: m['regionId']?.toString() ?? '',
        type: m['type']?.toString().isNotEmpty == true ? m['type']!.toString() : 'group',
        sponsorId: m['sponsorId']?.toString(),
      );

  bool isAdmin(String uid) => adminIds.contains(uid);

  /// In a professional tontine, the HR administrator is in adminIds but NOT in memberIds (does not contribute).
  bool isHrAdmin(String uid) => isProfessional && adminIds.contains(uid) && !memberIds.contains(uid);

  bool get isProfessional => type == 'professional';
  bool get isAssociation => type == 'association';
  bool get isGroup => type == 'group' || type.isEmpty;

  /// The pot's ledger account (`financial_accounts/tontine_{id}`).
  String get potAccountId => FinanceLedger.tontineAccountId(id);

  /// What each beneficiary receives per cycle.
  int get potPerCycle => contributionAmount * memberIds.length;

  bool get isForming => status == 'forming';
  bool get isActive => status == 'active';

  /// The full schedule: one cycle per member, from [startDate].
  List<DateTime> schedule() {
    final start = startDate;
    if (start == null || memberIds.isEmpty) return const [];
    final out = <DateTime>[start];
    while (out.length < memberIds.length) {
      out.add(Frequency.next(out.last, frequency));
    }
    return out;
  }

  static String statusLabel(String? s) => const {
        'forming': 'Forming',
        'active': 'Active',
        'completed': 'Completed',
        'suspended': 'Suspended',
      }[s] ??
      (s ?? '-');

  static String typeLabel(String? t) => switch (t) {
        'professional' => 'Professional',
        'association' => 'Association',
        _ => 'Group',
      };
}

/// Admin actions the app offers (the security rules re-check every one).
abstract final class TontineActions {
  /// Inviting: an admin, while the tontine is forming (the members, amount
  /// and order are fixed once it starts), below its size.
  static bool canInvite(Tontine t, String uid, int activeAndInvited) => t.isAdmin(uid) && t.isForming && activeAndInvited < t.membersLimit;

  /// Start: an admin, while forming, with enough members and a complete payout order.
  static String? startBlocker(Tontine t, String uid, TontineConfig cfg, List<String> payoutOrder) {
    if (!t.isAdmin(uid)) return 'Only an administrator of the tontine can start it.';
    if (!t.isForming) return 'This tontine has already started.';
    if (t.memberIds.length < cfg.minMembers) return 'More members are needed to start.';
    if (t.payoutOrderMethod == 'fixed' && (payoutOrder.length != t.memberIds.length || !t.memberIds.every(payoutOrder.contains))) {
      return 'Set the payout order for every member first.';
    }
    return null;
  }
}

/// One cycle's contributions, for the group view (who paid, who has not).
class CycleSummary {
  final int paid;
  final int pending;
  final int overdue;
  final int collected;
  final int expected;
  final Map<String, String> statusByMember;

  const CycleSummary({required this.paid, required this.pending, required this.overdue, required this.collected, required this.expected, required this.statusByMember});

  /// [contributions]: `tontine_contributions` of the cycle; a member with
  /// none is pending (overdue once [dueDate] has passed).
  static CycleSummary of(List<Map<String, dynamic>> contributions, List<String> memberIds, int contributionAmount, DateTime? dueDate, DateTime now) {
    final Map<String, String> byMember = {};
    int collected = 0;
    for (final c in contributions) {
      final String uid = c['userId']?.toString() ?? '';
      final String status = c['status']?.toString() ?? 'pending';
      if (!memberIds.contains(uid)) continue;
      if (status == 'paid') collected += _int(c['amount']);
      // A paid contribution wins over an older failed / pending one.
      if (byMember[uid] != 'paid') byMember[uid] = status;
    }
    final bool late = dueDate != null && now.isAfter(dueDate);
    for (final uid in memberIds) {
      final s = byMember[uid];
      if (s == null || s == 'pending' || s == 'failed') byMember[uid] = late ? 'overdue' : (s ?? 'pending');
    }
    int count(String s) => byMember.values.where((v) => v == s).length;
    return CycleSummary(
      paid: count('paid'),
      pending: count('pending') + count('failed'),
      overdue: count('overdue'),
      collected: collected,
      expected: contributionAmount * memberIds.length,
      statusByMember: byMember,
    );
  }
}

/// Labels (translation keys) of the server's statuses.
abstract final class GroupLabels {
  static String purpose(String? p) => const {
        'real_estate': 'Real estate',
        'education': 'Education',
        'travel': 'Travel',
        'healthcare': 'Healthcare',
        'business': 'Business project',
        'other': 'Other',
      }[p] ??
      _humanize(p);

  static String contribution(String? s) => const {
        'pending': 'Awaiting payment',
        'processing': 'Processing',
        'succeeded': 'Received',
        'paid': 'Paid',
        'failed': 'Failed',
        'overdue': 'Overdue',
        'refunded': 'Refunded',
      }[s] ??
      _humanize(s);

  static String withdrawal(String? s) => const {
        'requested': 'Requested',
        'processing': 'Processing',
        'completed': 'Completed',
        'rejected': 'Rejected',
      }[s] ??
      _humanize(s);

  static String member(String? s) => const {
        'invited': 'Invited',
        'active': 'Member',
        'declined': 'Declined',
        'removed': 'Removed',
        'restricted': 'Restricted',
      }[s] ??
      _humanize(s);

  static String cycle(String? s) => const {
        'upcoming': 'Upcoming',
        'collecting': 'Collecting',
        'payout_pending': 'Payout pending',
        'paid': 'Paid out',
        'closed': 'Closed',
      }[s] ??
      _humanize(s);

  static String payout(String? s) => const {
        'pending_approval': 'Awaiting approval',
        'approved': 'Approved',
        'paid': 'Paid',
        'failed': 'Failed',
      }[s] ??
      _humanize(s);

  static String dispute(String? s) => const {
        'open': 'Open',
        'under_review': 'Under review',
        'resolved': 'Resolved',
        'rejected': 'Rejected',
      }[s] ??
      _humanize(s);

  static String method(String? m) => const {
        'wallet': 'Spideli Finance wallet',
        'mobile_money': 'Mobile Money',
        'wave': 'Wave',
      }[m] ??
      _humanize(m);

  static String _humanize(String? id) {
    final s = (id ?? '').replaceAll('_', ' ').trim();
    return s.isEmpty ? '-' : s[0].toUpperCase() + s.substring(1);
  }
}

/// One month of a savings goal: added, withdrawn, and saved at its end.
class SavingsMonth {
  final DateTime month;
  final int added;
  final int withdrawn;
  final int savedAtEnd;

  const SavingsMonth(this.month, this.added, this.withdrawn, this.savedAtEnd);
}

/// The goal's progress over time (the chart of the goal screen).
abstract final class SavingsProgress {
  /// Month by month, from the first movement in [added] / [withdrawn] (at
  /// most the last [months]) to [now]: what was added and withdrawn, and
  /// what was saved at the end of each month. The balance is anchored on
  /// [savedAmount] (the goal's balance now) and walked back, so it stays
  /// right when the oldest movements are not loaded. Empty without any
  /// movement.
  static List<SavingsMonth> monthly(List<DatedAmount> added, List<DatedAmount> withdrawn, int savedAmount, DateTime now, {int months = 12}) {
    if (added.isEmpty && withdrawn.isEmpty) return const [];
    int key(DateTime d) => d.year * 12 + d.month - 1;
    final int last = key(now);
    final int first = [...added, ...withdrawn].map((x) => key(x.at)).reduce(min);
    final int start = max(first, last - months + 1);
    final Map<int, int> inBy = {};
    final Map<int, int> outBy = {};
    for (final x in added) {
      final k = key(x.at);
      if (k <= last) inBy[k] = (inBy[k] ?? 0) + x.amount;
    }
    for (final x in withdrawn) {
      final k = key(x.at);
      if (k <= last) outBy[k] = (outBy[k] ?? 0) + x.amount;
    }
    final out = <SavingsMonth>[];
    int balance = savedAmount;
    for (int k = last; k >= start; k--) {
      out.add(SavingsMonth(DateTime(k ~/ 12, k % 12 + 1), inBy[k] ?? 0, outBy[k] ?? 0, balance < 0 ? 0 : balance));
      balance = balance - (inBy[k] ?? 0) + (outBy[k] ?? 0);
    }
    return out.reversed.toList();
  }
}

/// What the app writes for savings goals (.claude/FINANCE-DIRECT-FIRESTORE.md
/// 3.6). Each plan is the whole batch; each blocker is the `FinanceErrors`
/// key of why the user cannot do it now (null when they can).
abstract final class SavingsWrites {
  static Timestamp _ts(DateTime d) => Timestamp.fromDate(_day(d));

  // ── Checks ────────────────────────────────────────────────────────────

  static String? inviteBlocker(SavingsGoal g, SavingsConfig cfg, String uid, String inviteeUid) {
    if (g.ownerId != uid) return 'permission_denied';
    if (!g.isActive) return 'invalid_state';
    if (!cfg.groupGoals) return 'invalid_state';
    if (inviteeUid == uid) return 'invite_self';
    if (g.memberIds.contains(inviteeUid) || g.invitedIds.contains(inviteeUid)) return 'already_member';
    if (g.memberIds.length + g.invitedIds.length >= cfg.maxMembers) return 'group_full';
    return null;
  }

  static String? respondBlocker(SavingsGoal g, SavingsConfig? cfg, String uid, bool accept) {
    if (!g.invitedIds.contains(uid)) return 'invalid_state';
    if (accept && !g.isActive) return 'invalid_state';
    if (accept && cfg != null && g.memberIds.length >= cfg.maxMembers) return 'group_full';
    return null;
  }

  static String? contributeBlocker(SavingsGoal g, String uid, int amount) {
    if (!g.memberIds.contains(uid)) return 'permission_denied';
    if (!g.isActive) return 'invalid_state';
    if (amount <= 0) return 'amount_out_of_range';
    return null;
  }

  /// A solo goal's owner withdraws directly; a group goal's member asks.
  /// Early (before the target) only when the configuration allows it.
  static String? withdrawBlocker(SavingsGoal g, SavingsConfig? cfg, String uid, int amount) {
    if (!g.memberIds.contains(uid)) return 'permission_denied';
    if (g.isSolo && g.ownerId != uid) return 'permission_denied';
    if (!g.isActive) return 'invalid_state';
    if (amount <= 0) return 'amount_out_of_range';
    if (amount > g.savedAmount) return 'insufficient_funds';
    if (g.remaining > 0 && cfg?.earlyWithdrawal != true) return 'withdrawal_not_allowed';
    return null;
  }

  static String? cancelBlocker(SavingsGoal g, String uid) {
    if (g.ownerId != uid) return 'permission_denied';
    if (!g.isActive) return 'invalid_state';
    return null;
  }

  // ── Plans ─────────────────────────────────────────────────────────────

  /// The goal (`active`, nothing saved; the creator is owner and only
  /// member; [invitedIds] are the accounts found by email) and its empty
  /// ledger account `goal_{goalId}`.
  static List<FinanceWrite> create({
    required String goalId,
    required String uid,
    required String name,
    required String purpose,
    required String description,
    required int targetAmount,
    required String currency,
    DateTime? deadline,
    String? frequency,
    int? scheduleAmount,
    List<String> invitedIds = const [],
  }) {
    final String account = FinanceLedger.goalAccountId(goalId);
    return [
      FinanceWrite('savings_goals/$goalId', 'create', {
        'id': goalId,
        'ownerId': uid,
        'memberIds': [uid],
        'invitedIds': invitedIds.where((i) => i != uid).toSet().toList(),
        'name': name,
        'purpose': purpose,
        'description': description,
        'currency': currency,
        'targetAmount': targetAmount,
        'savedAmount': 0,
        if (deadline != null) 'deadline': _ts(deadline),
        if (frequency != null && (scheduleAmount ?? 0) > 0) 'schedule': {'frequency': frequency, 'amount': scheduleAmount},
        'status': 'active',
        'accountId': account,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      FinanceWrite('financial_accounts/$account', 'create', {
        ...FinanceLedger.poolFields('savings_goal', goalId, currency, memberIds: [uid]),
        'id': account,
        'balance': 0,
        'normalSide': 'credit',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    ];
  }

  /// The owner's changes: name, description, deadline, schedule (cleared with [clearSchedule]).
  static List<FinanceWrite> update(String goalId, {String? name, String? description, DateTime? deadline, String? frequency, int? scheduleAmount, bool clearSchedule = false}) => [
        FinanceWrite('savings_goals/$goalId', 'update', {
          'name': ?name,
          'description': ?description,
          if (deadline != null) 'deadline': _ts(deadline),
          if (clearSchedule) 'schedule': FieldValue.delete(),
          if (!clearSchedule && frequency != null && (scheduleAmount ?? 0) > 0) 'schedule': {'frequency': frequency, 'amount': scheduleAmount},
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      ];

  static List<FinanceWrite> invite(String goalId, String inviteeUid) => [
        FinanceWrite('savings_goals/$goalId', 'update', {
          'invitedIds': FieldValue.arrayUnion([inviteeUid]),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      ];

  /// The invitee leaves `invitedIds`, and joins `memberIds` on [accept].
  static List<FinanceWrite> respond(String goalId, String uid, bool accept) => [
        FinanceWrite('savings_goals/$goalId', 'update', {
          'invitedIds': FieldValue.arrayRemove([uid]),
          if (accept) 'memberIds': FieldValue.arrayUnion([uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      ];

  /// A member's contribution: `savings_contributions/{contributionId}`
  /// (`succeeded`, create-only: a retry finds it), the posting
  /// `wallet or platform (gateway) -> goal_{id}` (`savings_contribution`),
  /// and `savedAmount` += amount (with `lastTxId`, the posting that moved it).
  static FinancePosting contribute({
    required SavingsGoal goal,
    required String contributionId,
    required String uid,
    required int amount,
    required String walletId,
    required FinanceFunding funding,
    String? txId,
    String? reference,
  }) {
    final p = FinanceLedger.plan(
      type: 'savings_contribution',
      currency: goal.currency,
      from: funding.isWallet ? walletId : FinanceLedger.platformId(goal.currency),
      to: goal.accountId,
      amount: amount,
      userIds: [uid],
      sourceKind: 'savings_contributions',
      sourceId: contributionId,
      createdBy: uid,
      funding: funding,
      description: goal.name,
      txId: txId,
      reference: reference,
    );
    return FinancePosting(p.txId, p.reference, [
      FinanceWrite('savings_contributions/$contributionId', 'create', {
        'id': contributionId,
        'goalId': goal.id,
        'userId': uid,
        'amount': amount,
        'currency': goal.currency,
        'status': 'succeeded',
        'reference': p.reference,
        'txId': p.txId,
        'funding': funding.isWallet ? 'wallet' : 'gateway',
        if (!funding.isWallet) 'gateway': funding.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      }),
      ...p.writes,
      FinanceWrite('savings_goals/${goal.id}', 'update', {
        'savedAmount': FieldValue.increment(amount),
        'lastTxId': p.txId,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    ]);
  }

  /// A withdrawal of [amount]. Solo goal: `completed` at once, with the
  /// posting `goal_{id} -> the owner's wallet` (`savings_withdrawal`; the
  /// wallet is created when [walletExists] is false) and `savedAmount` -=
  /// amount. Group goal: `requested`, no money moves: the admin decides by
  /// the group's rules and posts it (`completed`) or refuses (`rejected`).
  static FinancePosting withdraw({
    required SavingsGoal goal,
    required String withdrawalId,
    required String uid,
    required int amount,
    required String walletId,
    required bool walletExists,
    String reason = '',
    String? txId,
    String? reference,
  }) {
    final record = <String, dynamic>{
      'id': withdrawalId,
      'goalId': goal.id,
      'userId': uid,
      'amount': amount,
      'currency': goal.currency,
      'destination': {'method': 'wallet', 'accountId': walletId},
      if (reason.trim().isNotEmpty) 'reason': reason.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (!goal.isSolo) {
      return FinancePosting('', '', [
        FinanceWrite('savings_withdrawals/$withdrawalId', 'create', {...record, 'status': 'requested'}),
      ]);
    }
    final p = FinanceLedger.plan(
      type: 'savings_withdrawal',
      currency: goal.currency,
      from: goal.accountId,
      to: walletId,
      amount: amount,
      newAccounts: walletExists ? const {} : {walletId: FinanceLedger.walletFields(uid, goal.currency)},
      userIds: [uid],
      sourceKind: 'savings_withdrawals',
      sourceId: withdrawalId,
      createdBy: uid,
      description: goal.name,
      txId: txId,
      reference: reference,
    );
    return FinancePosting(p.txId, p.reference, [
      FinanceWrite('savings_withdrawals/$withdrawalId', 'create', {
        ...record,
        'status': 'completed',
        'reference': p.reference,
        'txId': p.txId,
        'completedAt': FieldValue.serverTimestamp(),
      }),
      ...p.writes,
      FinanceWrite('savings_goals/${goal.id}', 'update', {
        'savedAmount': FieldValue.increment(-amount),
        'lastTxId': p.txId,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    ]);
  }

  /// The owner cancels. Solo goal: the whole balance ([goal.savedAmount])
  /// goes back to the owner's wallet (`savings_withdrawal`, source the goal)
  /// and the goal is `cancelled`. Group goal: `cancellation_requested`; the
  /// admin returns the funds and closes it.
  static FinancePosting cancel({required SavingsGoal goal, required String uid, required String walletId, required bool walletExists, String? txId, String? reference}) {
    if (!goal.isSolo) {
      return FinancePosting('', '', [
        FinanceWrite('savings_goals/${goal.id}', 'update', {
          'status': 'cancellation_requested',
          'cancellationRequestedBy': uid,
          'cancellationRequestedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      ]);
    }
    final int balance = goal.savedAmount;
    if (balance <= 0) {
      return FinancePosting('', '', [
        FinanceWrite('savings_goals/${goal.id}', 'update', {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      ]);
    }
    final p = FinanceLedger.plan(
      type: 'savings_withdrawal',
      currency: goal.currency,
      from: goal.accountId,
      to: walletId,
      amount: balance,
      newAccounts: walletExists ? const {} : {walletId: FinanceLedger.walletFields(uid, goal.currency)},
      userIds: [uid],
      sourceKind: 'savings_goals',
      sourceId: goal.id,
      createdBy: uid,
      description: goal.name,
      txId: txId,
      reference: reference,
    );
    return FinancePosting(p.txId, p.reference, [
      ...p.writes,
      FinanceWrite('savings_goals/${goal.id}', 'update', {
        'status': 'cancelled',
        'savedAmount': FieldValue.increment(-balance),
        'lastTxId': p.txId,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    ]);
  }
}

/// What the app writes for tontines (.claude/FINANCE-DIRECT-FIRESTORE.md
/// 3.7). Ids are deterministic where a document must exist once: member
/// `{tontineId}_{uid}`, cycle `{tontineId}_{n}`, contribution
/// `{cycleId}_{uid}`, payout `{cycleId}`.
abstract final class TontineWrites {
  static String memberId(String tontineId, String uid) => '${tontineId}_$uid';
  static String cycleId(String tontineId, int number) => '${tontineId}_$number';
  static String contributionId(String cycleId, String uid) => '${cycleId}_$uid';
  static String payoutId(String cycleId) => cycleId;

  static Timestamp _ts(DateTime d) => Timestamp.fromDate(_day(d));

  // ── Checks ────────────────────────────────────────────────────────────

  /// Joining or creating: refused while the user is restricted for tontines.
  static String? restrictionBlocker(Map<String, dynamic>? user) => FinanceRestriction.blocks(user, FinanceRestriction.tontines) ? 'finance_restricted' : null;

  /// [members]: the tontine's member documents.
  static String? inviteBlocker(Tontine t, String uid, String inviteeUid, List<Map<String, dynamic>> members) {
    if (!t.isAdmin(uid)) return 'permission_denied';
    if (!t.isForming) return 'invalid_state';
    if (inviteeUid == uid) return 'invite_self';
    final existing = members.where((m) => m['userId'] == inviteeUid).firstOrNull;
    final String status = existing?['status']?.toString() ?? '';
    if (status == 'active' || status == 'invited') return 'already_member';
    if (status == 'restricted' || status == 'removed') return 'permission_denied';
    final int taken = members.where((m) => m['status'] == 'active' || m['status'] == 'invited').length;
    if (taken >= t.membersLimit) return 'group_full';
    return null;
  }

  /// Paying [cycle] (the cycle document): an active member of an active
  /// tontine, while the cycle collects.
  static String? contributeBlocker(Tontine t, Map<String, dynamic> cycle, String uid) {
    if (!t.memberIds.contains(uid)) return 'permission_denied';
    if (!t.isActive || cycle['status'] != 'collecting' || cycle['tontineId'] != t.id) return 'invalid_state';
    return null;
  }

  /// Who may approve [payout]: an admin, while it awaits approval, never
  /// the beneficiary for their own payout (another admin approves it; when
  /// they are the only admin, Spideli does: `payout_self_approval`).
  static String? approveBlocker(Tontine t, Map<String, dynamic> payout, String uid) {
    if (!t.isAdmin(uid)) return 'permission_denied';
    if (payout['status'] != 'pending_approval' || payout['tontineId'] != t.id) return 'invalid_state';
    if (payout['beneficiaryUserId'] == uid) return 'payout_self_approval';
    return null;
  }

  /// Whether the beneficiary of [payout] is the tontine's only admin (the
  /// payout then waits for Spideli's approval).
  static bool waitsForSpideli(Tontine t, Map<String, dynamic> payout) => t.adminIds.length <= 1 && t.adminIds.contains(payout['beneficiaryUserId']);

  // ── Plans ─────────────────────────────────────────────────────────────

  /// The tontine (`forming`; the creator is its admin; in a professional tontine,
  /// the HR admin is in adminIds but not in memberIds; otherwise admin and first member),
  /// the creator's member document and the empty pot account `tontine_{tontineId}`.
  static List<FinanceWrite> create({
    required String tontineId,
    required String uid,
    required String displayName,
    required String email,
    required String name,
    required String description,
    required String rules,
    required int contributionAmount,
    required String currency,
    required String frequency,
    required int membersLimit,
    required String payoutOrderMethod,
    required DateTime startDate,
    String type = 'group',
    String? sponsorId,
  }) {
    final String pot = FinanceLedger.tontineAccountId(tontineId);
    final bool isProfessional = type == 'professional';
    return [
      FinanceWrite('tontines/$tontineId', 'create', {
        'id': tontineId,
        'name': name,
        'description': description,
        'rules': rules,
        'currency': currency,
        'contributionAmount': contributionAmount,
        'frequency': frequency,
        'membersLimit': membersLimit,
        'payoutOrderMethod': payoutOrderMethod,
        'startDate': _ts(startDate),
        'status': 'forming',
        'type': type,
        if (sponsorId != null && sponsorId.isNotEmpty) 'sponsorId': sponsorId,
        'adminIds': [uid],
        'memberIds': isProfessional ? <String>[] : [uid],
        'currentCycle': 0,
        'potAccountId': pot,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      FinanceWrite('tontine_members/${memberId(tontineId, uid)}', 'create', {
        'id': memberId(tontineId, uid),
        'tontineId': tontineId,
        'tontineName': name,
        'userId': uid,
        'displayName': displayName,
        'email': email,
        'role': 'admin',
        'status': 'active',
        if (!isProfessional) 'payoutPosition': 1,
        if (sponsorId != null && sponsorId.isNotEmpty) 'sponsoredBy': sponsorId,
        'joinedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }),
      FinanceWrite('financial_accounts/$pot', 'create', {
        ...FinanceLedger.poolFields('tontine_pot', tontineId, currency),
        'id': pot,
        'balance': 0,
        'normalSide': 'credit',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    ];
  }

  /// The invitee's member document, `invited`, carrying the terms so the
  /// invitee can read them before joining (they cannot read the tontine).
  /// [again]: the document exists (a declined invitation): it is updated.
  static List<FinanceWrite> invite({
    required Tontine t,
    required String inviterUid,
    required String inviterName,
    required String inviteeUid,
    required String inviteeName,
    required String inviteeEmail,
    bool again = false,
    String? sponsorId,
  }) {
    final String? effectiveSponsor = sponsorId ?? t.sponsorId;
    return [
      FinanceWrite('tontine_members/${memberId(t.id, inviteeUid)}', again ? 'update' : 'create', {
        'id': memberId(t.id, inviteeUid),
        'tontineId': t.id,
        'tontineName': t.name,
        'userId': inviteeUid,
        'displayName': inviteeName,
        'email': inviteeEmail,
        'role': 'member',
        'status': 'invited',
        'invitedBy': inviterUid,
        'invitedByName': inviterName,
        if (effectiveSponsor != null && effectiveSponsor.isNotEmpty) 'sponsoredBy': effectiveSponsor,
        'contributionAmount': t.contributionAmount,
        'currency': t.currency,
        'frequency': t.frequency,
        'membersLimit': t.membersLimit,
        if (t.startDate != null) 'startDate': _ts(t.startDate!),
        'rules': t.rules,
        'payoutOrderMethod': t.payoutOrderMethod,
        'invitedAt': FieldValue.serverTimestamp(),
        if (!again) 'createdAt': FieldValue.serverTimestamp(),
      }),
    ];
  }

  /// The invitee's answer: own member document `active` (and `memberIds`
  /// += self) or `declined`.
  static List<FinanceWrite> respond(String tontineId, String uid, bool accept) => [
        FinanceWrite('tontine_members/${memberId(tontineId, uid)}', 'update', {
          'status': accept ? 'active' : 'declined',
          'respondedAt': FieldValue.serverTimestamp(),
          if (accept) 'joinedAt': FieldValue.serverTimestamp(),
        }),
        if (accept)
          FinanceWrite('tontines/$tontineId', 'update', {
            'memberIds': FieldValue.arrayUnion([uid]),
            'updatedAt': FieldValue.serverTimestamp(),
          }),
      ];

  /// The payout order (fixed): each active member's `payoutPosition`.
  static List<FinanceWrite> payoutOrder(String tontineId, List<String> order) => [
        for (final (i, uid) in order.indexed)
          FinanceWrite('tontine_members/${memberId(tontineId, uid)}', 'update', {
            'payoutPosition': i + 1,
          }),
      ];

  /// A random payout order (drawn on the device when a `random` tontine starts).
  static List<String> draw(List<String> memberIds, [Random? random]) => [...memberIds]..shuffle(random ?? Random.secure());

  /// The first due date: the agreed start date, or today when it has passed.
  static DateTime firstDue(Tontine t, DateTime now) {
    final DateTime today = _day(now);
    final DateTime? start = t.startDate == null ? null : _day(t.startDate!);
    return start == null || start.isBefore(today) ? today : start;
  }

  /// Start: `active`, cycle 1, and one cycle per member in [order] (the
  /// beneficiaries, first to last): `{tontineId}_{n}` with its due date,
  /// beneficiary, expected pot (`contributionAmount` × members) and nothing
  /// collected; the first `collecting`, the others `upcoming`. [drawn]: the
  /// order was drawn on the device and is saved on the member documents.
  static List<FinanceWrite> start({required Tontine t, required List<String> order, required DateTime now, bool drawn = false}) {
    final DateTime first = firstDue(t, now);
    final bool moved = t.startDate == null || !_day(t.startDate!).isAtSameMomentAs(first);
    final dates = <DateTime>[first];
    while (dates.length < order.length) {
      dates.add(Frequency.next(dates.last, t.frequency));
    }
    final int expected = t.contributionAmount * order.length;
    return [
      if (drawn) ...payoutOrder(t.id, order),
      FinanceWrite('tontines/${t.id}', 'update', {
        'status': 'active',
        'currentCycle': 1,
        'nextDueAt': _ts(first),
        if (moved) 'startDate': _ts(first),
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      for (final (i, uid) in order.indexed)
        FinanceWrite('tontine_cycles/${cycleId(t.id, i + 1)}', 'create', {
          'id': cycleId(t.id, i + 1),
          'tontineId': t.id,
          'number': i + 1,
          'dueDate': _ts(dates[i]),
          'beneficiaryUserId': uid,
          'expectedAmount': expected,
          'collectedAmount': 0,
          'currency': t.currency,
          'status': i == 0 ? 'collecting' : 'upcoming',
          'createdAt': FieldValue.serverTimestamp(),
        }),
    ];
  }

  /// A member's contribution to the collecting [cycle]: the contribution
  /// `{cycleId}_{uid}` (`paid`, create-only: once per cycle and member), the
  /// posting `wallet or platform (gateway) -> tontine_{id}`
  /// (`tontine_contribution`) and `collectedAmount` += amount. The
  /// contribution that completes the pot also sets the cycle
  /// `payout_pending` and creates its payout `{cycleId}` (`pending_approval`).
  static FinancePosting contribute({
    required Tontine t,
    required Map<String, dynamic> cycle,
    required String uid,
    required String walletId,
    required FinanceFunding funding,
    String? txId,
    String? reference,
  }) {
    final String cid = cycle['id'].toString();
    final int number = _int(cycle['number']);
    final int amount = t.contributionAmount;
    final int expected = _int(cycle['expectedAmount']);
    final bool completes = expected > 0 && _int(cycle['collectedAmount']) + amount >= expected;
    final String id = contributionId(cid, uid);
    final p = FinanceLedger.plan(
      type: 'tontine_contribution',
      currency: t.currency,
      from: funding.isWallet ? walletId : FinanceLedger.platformId(t.currency),
      to: t.potAccountId,
      amount: amount,
      userIds: [uid],
      sourceKind: 'tontine_contributions',
      sourceId: id,
      createdBy: uid,
      funding: funding,
      description: t.name,
      txId: txId,
      reference: reference,
    );
    return FinancePosting(p.txId, p.reference, [
      FinanceWrite('tontine_contributions/$id', 'create', {
        'id': id,
        'tontineId': t.id,
        'cycleId': cid,
        'cycleNumber': number,
        'userId': uid,
        'amount': amount,
        'currency': t.currency,
        'status': 'paid',
        'reference': p.reference,
        'txId': p.txId,
        'funding': funding.isWallet ? 'wallet' : 'gateway',
        if (!funding.isWallet) 'gateway': funding.toMap(),
        'paidAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }),
      ...p.writes,
      FinanceWrite('tontine_cycles/$cid', 'update', {
        'collectedAmount': FieldValue.increment(amount),
        if (completes) 'status': 'payout_pending',
        'lastTxId': p.txId,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      if (completes)
        FinanceWrite('tontine_payouts/${payoutId(cid)}', 'create', {
          'id': payoutId(cid),
          'tontineId': t.id,
          'cycleId': cid,
          'cycleNumber': number,
          'beneficiaryUserId': cycle['beneficiaryUserId'],
          'amount': expected,
          'currency': t.currency,
          'status': 'pending_approval',
          'createdAt': FieldValue.serverTimestamp(),
        }),
    ]);
  }

  /// An admin approves [payout]: the posting `tontine_{id} -> the
  /// beneficiary's wallet` (`tontine_payout`; the wallet is created when
  /// [walletExists] is false), the payout `paid`, its cycle `paid`, and the
  /// next cycle `collecting` with `currentCycle` + 1 — or, after the last
  /// cycle, the tontine `completed`.
  static FinancePosting approvePayout({
    required Tontine t,
    required Map<String, dynamic> payout,
    required Map<String, dynamic>? nextCycle,
    required String approverUid,
    required String walletId,
    required bool walletExists,
    String? txId,
    String? reference,
  }) {
    final String pid = payout['id'].toString();
    final String cid = (payout['cycleId'] ?? pid).toString();
    final String beneficiary = payout['beneficiaryUserId'].toString();
    final int number = _int(payout['cycleNumber']);
    final p = FinanceLedger.plan(
      type: 'tontine_payout',
      currency: t.currency,
      from: t.potAccountId,
      to: walletId,
      amount: _int(payout['amount']),
      newAccounts: walletExists ? const {} : {walletId: FinanceLedger.walletFields(beneficiary, t.currency)},
      userIds: [beneficiary],
      sourceKind: 'tontine_payouts',
      sourceId: pid,
      createdBy: approverUid,
      description: t.name,
      txId: txId,
      reference: reference,
    );
    return FinancePosting(p.txId, p.reference, [
      ...p.writes,
      FinanceWrite('tontine_payouts/$pid', 'update', {
        'status': 'paid',
        'txId': p.txId,
        'reference': p.reference,
        'approvedBy': approverUid,
        'approvedAt': FieldValue.serverTimestamp(),
        'paidAt': FieldValue.serverTimestamp(),
      }),
      FinanceWrite('tontine_cycles/$cid', 'update', {
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      if (nextCycle != null) ...[
        FinanceWrite('tontine_cycles/${nextCycle['id']}', 'update', {
          'status': 'collecting',
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        FinanceWrite('tontines/${t.id}', 'update', {
          'currentCycle': number + 1,
          if (nextCycle['dueDate'] != null) 'nextDueAt': nextCycle['dueDate'],
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      ] else
        FinanceWrite('tontines/${t.id}', 'update', {
          'status': 'completed',
          'nextDueAt': FieldValue.delete(),
          'completedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
    ]);
  }

  /// An association administrator removes a member (`removed`).
  static List<FinanceWrite> removeMember(String tontineId, String uid) => [
        FinanceWrite('tontine_members/${memberId(tontineId, uid)}', 'update', {
          'status': 'removed',
          'removedAt': FieldValue.serverTimestamp(),
        }),
        FinanceWrite('tontines/$tontineId', 'update', {
          'memberIds': FieldValue.arrayRemove([uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      ];

  /// A dispute raised by an active member (`open`), for the admins.
  static List<FinanceWrite> dispute({
    required String disputeId,
    required String tontineId,
    required String uid,
    required String subject,
    required String description,
    String? againstUserId,
  }) =>
      [
        FinanceWrite('tontine_disputes/$disputeId', 'create', {
          'id': disputeId,
          'tontineId': tontineId,
          'raisedBy': uid,
          if (againstUserId != null && againstUserId.isNotEmpty) 'againstUserId': againstUserId,
          'subject': subject,
          'description': description,
          'status': 'open',
          'createdAt': FieldValue.serverTimestamp(),
        }),
      ];
}

/// Salary declared and confirmed for professional tontines (`member_salaries/{tontineId}_{uid}`).
class MemberSalary {
  final String tontineId;
  final String userId;
  final int monthlySalary;
  final String currency;
  final DateTime? declaredAt;
  final String? confirmedBy;
  final DateTime? confirmedAt;

  const MemberSalary({
    required this.tontineId,
    required this.userId,
    required this.monthlySalary,
    required this.currency,
    required this.declaredAt,
    this.confirmedBy,
    this.confirmedAt,
  });

  bool get isConfirmed => confirmedBy != null && confirmedAt != null;
  int get salaryCap => (monthlySalary / 3).floor();
  int get loanCap => salaryCap;

  static MemberSalary fromMap(Map<String, dynamic> m, DateTime? Function(dynamic) toDate) => MemberSalary(
        tontineId: m['tontineId']?.toString() ?? '',
        userId: m['userId']?.toString() ?? '',
        monthlySalary: _int(m['monthlySalary']),
        currency: m['currency']?.toString() ?? '',
        declaredAt: toDate(m['declaredAt']),
        confirmedBy: m['confirmedBy']?.toString(),
        confirmedAt: toDate(m['confirmedAt']),
      );
}

abstract final class SalaryWrites {
  static String salaryId(String tontineId, String uid) => '${tontineId}_$uid';

  static List<FinanceWrite> declare({
    required String tontineId,
    required String uid,
    required int monthlySalary,
    required String currency,
  }) =>
      [
        FinanceWrite('member_salaries/${salaryId(tontineId, uid)}', 'set', {
          'tontineId': tontineId,
          'userId': uid,
          'monthlySalary': monthlySalary,
          'currency': currency,
          'declaredAt': FieldValue.serverTimestamp(),
          'confirmedBy': null,
          'confirmedAt': null,
        }),
      ];

  static List<FinanceWrite> confirm({
    required String tontineId,
    required String uid,
    required String adminUid,
  }) =>
      [
        FinanceWrite('member_salaries/${salaryId(tontineId, uid)}', 'update', {
          'confirmedBy': adminUid,
          'confirmedAt': FieldValue.serverTimestamp(),
        }),
      ];
}

/// A member blacklisted in a tontine due to unpaid debt (`tontine_blacklist/{tontineId}_{uid}`).
class TontineBlacklistEntry {
  final String tontineId;
  final String userId;
  final String displayName;
  final String loanId;
  final DateTime? since;

  const TontineBlacklistEntry({
    required this.tontineId,
    required this.userId,
    required this.displayName,
    required this.loanId,
    required this.since,
  });

  static TontineBlacklistEntry fromMap(Map<String, dynamic> m, DateTime? Function(dynamic) toDate) => TontineBlacklistEntry(
        tontineId: m['tontineId']?.toString() ?? '',
        userId: m['userId']?.toString() ?? '',
        displayName: m['displayName']?.toString() ?? '',
        loanId: m['loanId']?.toString() ?? '',
        since: toDate(m['since']),
      );
}


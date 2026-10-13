/// Spideli Finance: savings goals and tontines, the pure rules the screens
/// use (.claude/FINANCE-APP-CONTRACT.md sections 8-9). Unit tested in
/// test/finance_group_rules_test.dart.
///
/// The SERVER owns every amount, status and payout; these rules only read
/// what it stored, project from it, and mirror its checks so the app can
/// explain what is possible before asking.
library;

int _int(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

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

/// `platform_settings/savings` (admin). Null when missing or malformed: the
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

/// `platform_settings/tontines` (admin).
class TontineConfig {
  final List<String> currencies;
  final List<String> frequencies;
  final int minMembers;
  final int maxMembers;
  final List<String> payoutOrderMethods;
  final List<String> paymentMethods;

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
    return TontineConfig(
      currencies: currencies,
      frequencies: frequencies,
      minMembers: min,
      maxMembers: max,
      payoutOrderMethods: _strings(raw['payoutOrderMethods']).isEmpty ? const ['fixed'] : _strings(raw['payoutOrderMethods']),
      paymentMethods: methods,
      minContribution: mc is Map ? {for (final e in mc.entries) e.key.toString(): _int(e.value)} : const {},
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
    );
  }

  bool get isGroup => memberIds.length > 1 || invitedIds.isNotEmpty;
  bool get isActive => status == 'active';
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
      );

  bool isAdmin(String uid) => adminIds.contains(uid);

  /// What each beneficiary receives per cycle (before any fee the server applies).
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
}

/// Admin actions the app offers (the server re-checks every one).
abstract final class TontineActions {
  static bool canInvite(Tontine t, String uid, int activeAndInvited) =>
      t.isAdmin(uid) && (t.isForming || t.isActive) && activeAndInvited < t.membersLimit;

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

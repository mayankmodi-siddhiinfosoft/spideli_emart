import 'package:customer/utils/finance_group_rules.dart';
import 'package:customer/utils/finance_rules.dart';

/// The user's records the dashboard totals are made of (each list as read
/// from Firestore, documents as maps).
class FinanceSummarySources {
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> holdings;
  final List<Map<String, dynamic>> goals;
  final List<Map<String, dynamic>> tontines;

  /// tontine id -> whether the user already paid its current cycle.
  final Map<String, bool> paidCurrentCycle;
  final List<Map<String, dynamic>> borrowed;

  /// loan id -> the installments of its schedule.
  final Map<String, List<Map<String, dynamic>>> schedules;
  final List<Map<String, dynamic>> lentLoans;
  final List<Map<String, dynamic>> fundings;
  final List<Map<String, dynamic>> policies;
  final List<Map<String, dynamic>> claims;
  final List<Map<String, dynamic>> ledger;

  const FinanceSummarySources({
    this.accounts = const [],
    this.holdings = const [],
    this.goals = const [],
    this.tontines = const [],
    this.paidCurrentCycle = const {},
    this.borrowed = const [],
    this.schedules = const {},
    this.lentLoans = const [],
    this.fundings = const [],
    this.policies = const [],
    this.claims = const [],
    this.ledger = const [],
  });
}

/// The dashboard totals, worked out on the device from the user's own
/// records (.claude/FINANCE-DIRECT-FIRESTORE.md section 4): no server keeps
/// `finance_summaries` any more. Pure and tested
/// (test/finance_summary_builder_test.dart). Amounts in one currency only
/// (the main wallet's): records in another currency are left out rather
/// than mixed.
abstract final class FinanceSummaryBuilder {
  static int _i(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

  /// The currency of the totals: the user's largest active wallet, else the
  /// most common currency of their records, else [fallback].
  static String currencyOf(FinanceSummarySources s, {String fallback = 'XAF'}) {
    final wallets = s.accounts.where((a) => a['status'] == 'active' && (a['kind'] ?? 'wallet') == 'wallet' && '${a['currency'] ?? ''}'.length == 3).toList()
      ..sort((a, b) => _i(b['balance']).compareTo(_i(a['balance'])));
    if (wallets.isNotEmpty) return wallets.first['currency'].toString();
    final counts = <String, int>{};
    for (final r in [...s.goals, ...s.tontines, ...s.borrowed, ...s.holdings, ...s.policies]) {
      final c = '${r['currency'] ?? ''}';
      if (RegExp(r'^[A-Z]{3}$').hasMatch(c)) counts[c] = (counts[c] ?? 0) + 1;
    }
    if (counts.isEmpty) return fallback;
    return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
  }

  /// The raw summary (the shape of `FinanceSummary.parse`), or null when the
  /// user has no Spideli Finance account or record at all.
  static Map<String, dynamic>? build(
    FinanceSummarySources s, {
    required String uid,
    required DateTime now,
    required DateTime? Function(dynamic) toDate,
    String fallbackCurrency = 'XAF',
  }) {
    final bool anything = [s.accounts, s.holdings, s.goals, s.tontines, s.borrowed, s.lentLoans, s.policies, s.claims].any((l) => l.isNotEmpty);
    if (!anything) return null;
    final String cur = currencyOf(s, fallback: fallbackCurrency);
    bool inCur(Map<String, dynamic> r) => (r['currency'] ?? cur) == cur;
    final raw = <String, dynamic>{'currency': cur, 'updatedAt': now};

    // Investments: the holdings (valued by Spideli at the latest price).
    final holdings = s.holdings.where(inCur).where((h) => _i(h['units']) > 0 || _i(h['currentValue']) > 0).toList();
    if (holdings.isNotEmpty) {
      final allocation = <String, int>{};
      for (final h in holdings) {
        final String cls = '${h['assetClass'] ?? 'other'}';
        allocation[cls] = (allocation[cls] ?? 0) + _i(h['currentValue']);
      }
      raw['investments'] = {
        'investedCapital': holdings.fold<int>(0, (t, h) => t + _i(h['investedAmount'])),
        'currentValuation': holdings.fold<int>(0, (t, h) => t + _i(h['currentValue'])),
        'realizedGains': holdings.fold<int>(0, (t, h) => t + _i(h['realizedGains'])),
        'unrealizedGains': holdings.fold<int>(0, (t, h) => t + _i(h['unrealizedGains'])),
        'allocation': allocation,
      };
    }

    // Savings: the active goals the user is a member of.
    final goals = s.goals.where((g) => g['status'] == 'active' && inCur(g)).toList();
    if (goals.isNotEmpty) {
      raw['savings'] = {
        'activeGoals': goals.length,
        'savedAmount': goals.fold<int>(0, (t, g) => t + _i(g['savedAmount'])),
        'targetAmount': goals.fold<int>(0, (t, g) => t + _i(g['targetAmount'])),
      };
    }

    // Tontines: the next contribution the user still owes.
    final active = s.tontines.where((t) => t['status'] == 'active' && inCur(t)).toList();
    if (active.isNotEmpty || s.tontines.any((t) => t['status'] == 'forming')) {
      DateTime? nextDate;
      int? nextAmount;
      for (final t in active) {
        DateTime? due = toDate(t['nextDueAt']);
        if (due == null) continue;
        if (s.paidCurrentCycle[t['id']] == true) due = Frequency.next(due, t['frequency']?.toString() ?? 'monthly');
        if (nextDate == null || due.isBefore(nextDate)) {
          nextDate = due;
          nextAmount = _i(t['contributionAmount']);
        }
      }
      raw['tontines'] = {
        'active': active.length,
        'nextContributionDate': ?nextDate,
        'nextContributionAmount': ?nextAmount,
      };
    }

    // Loans: what the user owes, and what is still due to them as a lender.
    const open = {'active', 'overdue'};
    final owed = s.borrowed.where((l) => open.contains(l['status']) && inCur(l)).toList();
    final lentOpen = {for (final l in s.lentLoans) if (open.contains(l['status']) || l['status'] == 'disbursing' || l['status'] == 'agreement_pending' || l['status'] == 'funding') l['id']};
    final int lent = s.fundings
        .where((f) => f['status'] == 'succeeded' && lentOpen.contains(f['loanId']) && inCur(f))
        .fold<int>(0, (t, f) => t + (_i(f['amount']) - _i(f['collected'])).clamp(0, 1 << 52));
    if (owed.isNotEmpty || lent > 0 || s.borrowed.isNotEmpty) {
      DateTime? nextDate;
      int? nextAmount;
      for (final l in owed) {
        for (final i in s.schedules[l['id']] ?? const <Map<String, dynamic>>[]) {
          if (i['status'] == 'paid') continue;
          final DateTime? due = toDate(i['dueDate']);
          if (due == null) continue;
          if (nextDate == null || due.isBefore(nextDate)) {
            nextDate = due;
            // What is still due on it (a partly paid instalment shows the rest).
            nextAmount = (_i(i['amountDue'] ?? i['amount']) - _i(i['paidAmount'])).clamp(0, 1 << 52);
          }
          break;
        }
      }
      raw['loans'] = {
        'borrowedOutstanding': owed.fold<int>(0, (t, l) => t + _i(l['outstandingAmount'])),
        'lentOutstanding': lent,
        'overdueCount': owed.where((l) => l['status'] == 'overdue').length,
        'nextRepaymentDate': ?nextDate,
        'nextRepaymentAmount': ?nextAmount,
      };
    }

    // Insurance: active policies, the next renewal, open claims.
    const covered = {'active', 'renewal_due'};
    const openClaims = {'submitted', 'under_review', 'info_requested', 'approved'};
    if (s.policies.isNotEmpty || s.claims.isNotEmpty) {
      DateTime? renewal;
      for (final p in s.policies.where((p) => covered.contains(p['status']))) {
        final DateTime? d = toDate(p['renewalDate']) ?? toDate(p['coverEnd']);
        if (d != null && (renewal == null || d.isBefore(renewal))) renewal = d;
      }
      raw['insurance'] = {
        'activePolicies': s.policies.where((p) => covered.contains(p['status'])).length,
        'openClaims': s.claims.where((c) => openClaims.contains(c['status'])).length,
        'nextRenewalDate': ?renewal,
      };
    }

    // Cash flow: money in and out of the user's own accounts.
    final sides = {for (final a in s.accounts) if (a['id'] != null) a['id'].toString(): (a['normalSide'] ?? 'credit').toString()};
    final last30 = <String, int>{'deposits': 0, 'withdrawals': 0, 'transfers': 0, 'cardPayments': 0, 'billPayments': 0};
    final months = <String, ({int moneyIn, int moneyOut})>{};
    final DateTime from30 = now.subtract(const Duration(days: 30));
    final DateTime from12 = DateTime(now.year - 1, now.month + 1);
    for (final t in s.ledger) {
      // A reversed posting and the reversal that undid it cancel out: count
      // neither, so the month's net is the balance's real change (a refunded
      // withdrawal is neither money out nor money in).
      if (t['status'] == 'reversed' || (t['type'] == 'reversal' && t['reversalOf'] != null) || (t['currency'] ?? cur) != cur) continue;
      final DateTime? at = toDate(t['createdAt']);
      if (at == null) continue;
      final lines = ((t['lines'] as List?) ?? const []).whereType<Map>().map((l) => Map<String, dynamic>.from(l)).toList();
      final int signed = LedgerView.signedAmount(lines, sides);
      if (signed == 0) continue;
      if (!at.isBefore(from12)) {
        final String key = '${at.year}-${at.month.toString().padLeft(2, '0')}';
        final m = months[key] ?? (moneyIn: 0, moneyOut: 0);
        months[key] = signed > 0 ? (moneyIn: m.moneyIn + signed, moneyOut: m.moneyOut) : (moneyIn: m.moneyIn, moneyOut: m.moneyOut - signed);
      }
      if (at.isAfter(from30)) {
        final String? kind = switch (t['type']) {
          'deposit' => 'deposits',
          'withdrawal' => 'withdrawals',
          'transfer' || 'transfer_out' => 'transfers',
          'card_funding' || 'card_fee' => 'cardPayments',
          'bill_payment' => 'billPayments',
          _ => null,
        };
        if (kind != null) last30[kind] = last30[kind]! + signed.abs();
      }
    }
    raw['payments'] = {'last30Days': last30};
    raw['monthly'] = [
      for (final e in (months.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) {'month': e.key, 'moneyIn': e.value.moneyIn, 'moneyOut': e.value.moneyOut},
    ];
    return raw;
  }
}

/// Spideli Finance: investments, the pure rules the screens use
/// (.claude/FINANCE-APP-CONTRACT.md section 12). Unit tested in
/// test/finance_investment_rules_test.dart.
///
/// The SERVER decides eligibility, unit prices (NAV), units allocated,
/// valuations, gains, fees charged and settlements. The fee and unit figures
/// computed here are ESTIMATES at the last published unit price; the return
/// simulator is an illustration, never a promise.
library;

import 'dart:math' as math;

import 'package:customer/utils/finance_rules.dart' show ltr;

int _int(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

double? _numOrNull(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [];

Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

/// `platform_settings/investments` (admin). Null when missing or invalid.
class InvestmentConfig {
  final List<String> currencies;
  final List<String> assetClasses;
  final List<String> paymentMethods;

  /// The general risk warning every investor accepts before subscribing.
  final String riskDisclosure;
  final int simulatorMaxYears;

  const InvestmentConfig({
    required this.currencies,
    required this.assetClasses,
    required this.paymentMethods,
    required this.riskDisclosure,
    required this.simulatorMaxYears,
  });

  static InvestmentConfig? parse(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final currencies = _strings(raw['currencies']).where((c) => RegExp(r'^[A-Z]{3}$').hasMatch(c)).toList();
    final methods = _strings(raw['paymentMethods']);
    final disclosure = raw['riskDisclosure']?.toString().trim() ?? '';
    if (currencies.isEmpty || methods.isEmpty || disclosure.isEmpty) return null;
    final int years = _int(_map(raw['simulator'])['maxYears']);
    return InvestmentConfig(
      currencies: currencies,
      assetClasses: _strings(raw['assetClasses']),
      paymentMethods: methods,
      riskDisclosure: disclosure,
      simulatorMaxYears: years < 1 ? 30 : math.min(years, 50),
    );
  }
}

/// A fund document (prospectus, factsheet...): a Storage path or an https link.
class FundDocument {
  final String name;
  final String? storagePath;
  final String? url;

  const FundDocument(this.name, {this.storagePath, this.url});

  static FundDocument? fromMap(dynamic m) {
    if (m is! Map) return null;
    final String name = m['name']?.toString() ?? '';
    final String path = m['storagePath']?.toString() ?? '';
    final String url = m['url']?.toString() ?? '';
    if (name.isEmpty || (path.isEmpty && !url.startsWith('https://'))) return null;
    return FundDocument(name, storagePath: path.isEmpty ? null : path, url: url.startsWith('https://') ? url : null);
  }
}

/// `investment_funds/{fundId}`, published by the fund manager / admin.
class Fund {
  final String id;
  final String name;
  final String manager;
  final String description;
  final String objective;
  final String assetClass;

  /// 1 (lowest) to 7 (highest), the usual synthetic risk scale.
  final int riskLevel;
  final String currency;
  final int minInvestment;

  /// Minimum for a further investment once the user holds units (defaults to [minInvestment]).
  final int minAdditional;
  final double subscriptionFeePercent;
  final double managementFeePercent;
  final double redemptionFeePercent;
  final double performanceFeePercent;

  /// Unit price in minor units (may have decimals), and when it was set.
  final double? navPerUnit;
  final DateTime? navDate;
  final int lockUpDays;
  final int settlementDays;
  final bool redemptionAllowed;
  final bool partialRedemption;
  final String terms;
  final int termsVersion;
  final List<FundDocument> documents;

  /// Period returns in percent: `ytd`, `oneYear`, `threeYears`, `fiveYears`, `sinceInception`.
  final Map<String, double> performance;
  final String eligibility;

  /// `open`, `closed` (no new subscriptions) or `suspended` (no orders at all).
  final String status;

  const Fund({
    required this.id,
    required this.name,
    required this.manager,
    required this.description,
    required this.objective,
    required this.assetClass,
    required this.riskLevel,
    required this.currency,
    required this.minInvestment,
    required this.minAdditional,
    required this.subscriptionFeePercent,
    required this.managementFeePercent,
    required this.redemptionFeePercent,
    required this.performanceFeePercent,
    required this.navPerUnit,
    required this.navDate,
    required this.lockUpDays,
    required this.settlementDays,
    required this.redemptionAllowed,
    required this.partialRedemption,
    required this.terms,
    required this.termsVersion,
    required this.documents,
    required this.performance,
    required this.eligibility,
    required this.status,
  });

  static Fund fromMap(Map<String, dynamic> m, DateTime? Function(dynamic) toDate) {
    final fees = _map(m['fees']);
    final redemption = _map(m['redemption']);
    final perf = _map(m['performance']);
    final double? nav = _numOrNull(m['navPerUnit']);
    final int min = math.max(1, _int(m['minInvestment']));
    return Fund(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      manager: m['manager']?.toString() ?? '',
      description: m['description']?.toString() ?? '',
      objective: m['objective']?.toString() ?? '',
      assetClass: m['assetClass']?.toString() ?? 'mixed',
      riskLevel: _int(m['riskLevel']).clamp(1, 7),
      currency: m['currency']?.toString() ?? '',
      minInvestment: min,
      minAdditional: m['minAdditional'] == null ? min : math.max(1, _int(m['minAdditional'])),
      subscriptionFeePercent: _num(fees['subscriptionPercent']).clamp(0, 100).toDouble(),
      managementFeePercent: _num(fees['managementPercent']).clamp(0, 100).toDouble(),
      redemptionFeePercent: _num(fees['redemptionPercent']).clamp(0, 100).toDouble(),
      performanceFeePercent: _num(fees['performancePercent']).clamp(0, 100).toDouble(),
      navPerUnit: nav != null && nav > 0 ? nav : null,
      navDate: toDate(m['navDate']),
      lockUpDays: math.max(0, _int(m['lockUpDays'])),
      settlementDays: math.max(0, _int(m['settlementDays'])),
      redemptionAllowed: redemption['allowed'] != false,
      partialRedemption: redemption['partial'] != false,
      terms: m['terms']?.toString() ?? '',
      termsVersion: _int(m['termsVersion']),
      documents: (m['documents'] is List ? m['documents'] as List : const []).map(FundDocument.fromMap).whereType<FundDocument>().toList(),
      performance: {for (final e in perf.entries) if (_numOrNull(e.value) != null) e.key: _numOrNull(e.value)!},
      eligibility: m['eligibility']?.toString() ?? '',
      status: m['status']?.toString() ?? 'closed',
    );
  }

  /// New money is accepted only by an open fund with a unit price and current terms.
  bool get acceptsSubscriptions => status == 'open' && navPerUnit != null && termsVersion > 0;

  /// The minimum for this user: [minAdditional] once they hold units.
  int minimumFor({required bool holder}) => holder ? minAdditional : minInvestment;
}

/// Risk scale 1-7 grouped for labels and filters.
abstract final class RiskScale {
  static String band(int level) => level <= 2 ? 'low' : (level <= 4 ? 'medium' : 'high');

  static String label(int level) => const {'low': 'Low risk', 'medium': 'Medium risk', 'high': 'High risk'}[band(level)]!;

  static const List<String> bands = ['low', 'medium', 'high'];

  static String bandLabel(String band) => const {'low': 'Low risk', 'medium': 'Medium risk', 'high': 'High risk'}[band] ?? band;
}

abstract final class InvestmentLabels {
  static String assetClass(String? c) => const {
        'money_market': 'Money market',
        'bonds': 'Bonds',
        'equities': 'Equities',
        'real_estate': 'Real estate',
        'agriculture': 'Agriculture',
        'infrastructure': 'Infrastructure',
        'mixed': 'Diversified',
        'other': 'Other',
      }[c] ??
      (c ?? '-');

  static String period(String p) => const {
        'ytd': 'This year',
        'oneYear': '1 year',
        'threeYears': '3 years',
        'fiveYears': '5 years',
        'sinceInception': 'Since launch',
      }[p] ??
      p;

  static const List<String> periods = ['ytd', 'oneYear', 'threeYears', 'fiveYears', 'sinceInception'];

  static String transaction(String? t) => const {
        'subscription': 'Investment',
        'redemption': 'Redemption',
        'fee': 'Fee',
        'distribution': 'Distribution',
        'adjustment': 'Adjustment',
      }[t] ??
      (t ?? '-');

  /// "12.5 %" with a sign for gains, "-" when unknown.
  static String percent(double? p, {bool signed = false}) {
    if (p == null) return '-';
    final String fixed = p.toStringAsFixed(p.abs() >= 100 ? 0 : 2);
    // Trailing zeros only after a decimal point ("100" stays "100", "4.50" becomes "4.5").
    final String s = fixed.contains('.') ? fixed.replaceFirst(RegExp(r'\.?0+$'), '') : fixed;
    return ltr('${signed && p > 0 ? '+' : ''}$s %');
  }

  /// Units with up to 4 decimals: "12.3456", "100".
  static String units(double u) => u.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Subscription and redemption statuses (`investment_subscriptions` / `investment_redemptions`).
abstract final class InvestmentOrders {
  static const List<String> subscriptionSteps = ['pending_payment', 'paid', 'processing', 'completed'];
  static const List<String> redemptionSteps = ['submitted', 'processing', 'settling', 'settled'];

  static String label(String? s) => const {
        'pending_payment': 'Waiting for payment',
        'paid': 'Payment confirmed',
        'processing': 'Processing',
        'completed': 'Units allocated',
        'payment_failed': 'Payment failed',
        'submitted': 'Submitted',
        'settling': 'Being paid out',
        'settled': 'Paid out',
        'rejected': 'Not accepted',
        'cancelled': 'Cancelled',
      }[s] ??
      (s ?? '-');

  static bool ended(String? s) => const ['payment_failed', 'rejected', 'cancelled'].contains(s);

  static bool open(String? s) => !ended(s) && s != 'completed' && s != 'settled';

  /// A redemption can be withdrawn until the manager starts processing it.
  static bool canCancelRedemption(String? s) => s == 'submitted';
}

/// Fee, net amount and units, ESTIMATED at the last published unit price.
class OrderEstimate {
  final int gross;
  final int fee;
  final double? units;

  const OrderEstimate(this.gross, this.fee, this.units);

  int get net => gross - fee;
}

abstract final class InvestmentCalculator {
  /// Investing [amount]: the fee is taken first, the rest buys units.
  static OrderEstimate subscription(Fund f, int amount) {
    final int fee = (amount * f.subscriptionFeePercent / 100).round();
    final double? units = f.navPerUnit == null ? null : _floor4((amount - fee) / f.navPerUnit!);
    return OrderEstimate(amount, fee, units);
  }

  /// Redeeming [amount] of value (or the whole position): the fee is taken from it.
  static OrderEstimate redemption(Fund f, int amount) {
    final int fee = (amount * f.redemptionFeePercent / 100).round();
    final double? units = f.navPerUnit == null ? null : _floor4(amount / f.navPerUnit!);
    return OrderEstimate(amount, fee, units);
  }

  static double _floor4(double v) => (v * 10000).floorToDouble() / 10000;
}

/// One fund in the user's portfolio (`investment_holdings/{uid}_{fundId}`), all server values.
class Holding {
  final String fundId;
  final String fundName;
  final String assetClass;
  final String currency;
  final double units;
  final double redeemableUnits;
  final int investedAmount;
  final int currentValue;
  final int redeemableValue;
  final int realizedGains;
  final int unrealizedGains;
  final DateTime? lockedUntil;
  final DateTime? valuedAt;

  const Holding({
    required this.fundId,
    required this.fundName,
    required this.assetClass,
    required this.currency,
    required this.units,
    required this.redeemableUnits,
    required this.investedAmount,
    required this.currentValue,
    required this.redeemableValue,
    required this.realizedGains,
    required this.unrealizedGains,
    required this.lockedUntil,
    required this.valuedAt,
  });

  static Holding fromMap(Map<String, dynamic> m, DateTime? Function(dynamic) toDate) => Holding(
        fundId: m['fundId']?.toString() ?? '',
        fundName: m['fundName']?.toString() ?? '',
        assetClass: m['assetClass']?.toString() ?? 'mixed',
        currency: m['currency']?.toString() ?? '',
        units: _num(m['units']),
        redeemableUnits: _num(m['redeemableUnits']),
        investedAmount: _int(m['investedAmount']),
        currentValue: _int(m['currentValue']),
        redeemableValue: _int(m['redeemableValue']),
        realizedGains: _int(m['realizedGains']),
        unrealizedGains: _int(m['unrealizedGains']),
        lockedUntil: toDate(m['lockedUntil']),
        valuedAt: toDate(m['valuedAt']),
      );

  /// Unrealized gain as a percentage of the money still invested.
  double? get unrealizedPercent => investedAmount <= 0 ? null : unrealizedGains * 100 / investedAmount;

  bool get hasUnits => units > 0;

  /// Part of the position is still in its lock-up period.
  bool get partlyLocked => redeemableUnits < units;
}

/// One asset class of the allocation, with its share for display.
class AllocationShare {
  final String assetClass;
  final int value;
  final int percent;

  const AllocationShare(this.assetClass, this.value, this.percent);
}

abstract final class Allocation {
  /// Whole percentages that add up to exactly 100 (largest remainder),
  /// largest first. Server values; only the display shares are computed.
  static List<AllocationShare> shares(Map<String, dynamic>? raw) {
    final entries = <MapEntry<String, int>>[
      for (final e in (raw ?? const <String, dynamic>{}).entries)
        if (_int(e.value) > 0) MapEntry(e.key, _int(e.value)),
    ]..sort((a, b) => b.value.compareTo(a.value));
    final int total = entries.fold(0, (s, e) => s + e.value);
    if (total == 0) return const [];
    final floors = [for (final e in entries) e.value * 100 ~/ total];
    int left = 100 - floors.fold(0, (s, p) => s + p);
    final order = List.generate(entries.length, (i) => i)
      ..sort((a, b) => ((entries[b].value * 100) % total).compareTo((entries[a].value * 100) % total));
    for (final i in order) {
      if (left == 0) break;
      floors[i]++;
      left--;
    }
    return [for (int i = 0; i < entries.length; i++) AllocationShare(entries[i].key, entries[i].value, floors[i])];
  }
}

/// A point of the unit price history (`investment_valuations`).
class NavPoint {
  final DateTime date;
  final double nav;

  const NavPoint(this.date, this.nav);
}

/// The change between the first and the last price of a history, in percent.
double? navChangePercent(List<NavPoint> points) {
  if (points.length < 2 || points.first.nav <= 0) return null;
  return (points.last.nav - points.first.nav) * 100 / points.first.nav;
}

/// One year of a simulation.
class SimulationYear {
  final int year;
  final int contributed;
  final int value;

  const SimulationYear(this.year, this.contributed, this.value);

  int get gains => value - contributed;
}

/// Compound growth of a starting amount plus monthly additions, at a constant
/// yearly return compounded monthly. An ILLUSTRATION: real returns vary and
/// can be negative.
abstract final class ReturnSimulator {
  static List<SimulationYear> project({required int initial, required int monthly, required double annualPercent, required int years}) {
    final double r = math.pow(1 + annualPercent / 100, 1 / 12).toDouble() - 1;
    double value = initial.toDouble();
    int contributed = initial;
    final out = <SimulationYear>[];
    for (int y = 1; y <= years; y++) {
      for (int m = 0; m < 12; m++) {
        value = value * (1 + r) + monthly;
        contributed += monthly;
      }
      out.add(SimulationYear(y, contributed, value.round()));
    }
    return out;
  }
}

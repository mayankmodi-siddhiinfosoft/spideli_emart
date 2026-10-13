/// Spideli Finance: economic intelligence, investor matching and the AI
/// financial coach, the pure rules the screens use
/// (.claude/FINANCE-APP-CONTRACT.md section 17). Unit tested in
/// test/finance_intel_rules_test.dart.
///
/// Indicators and exchange rates come only from approved sources through
/// the server; the app never shows a figure without its source, period and
/// update time. The AI coach runs on the server; it informs and explains,
/// and never moves money.
library;

import 'dart:math' as math;

int _int(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

double? _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [];

Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

bool _iso3(String c) => RegExp(r'^[A-Z]{3}$').hasMatch(c);

// ------------------------------------------------------------------- config

class IndicatorsConfig {
  /// ISO 3166-1 alpha-2 country codes, in display order.
  final List<String> countries;

  const IndicatorsConfig(this.countries);
}

class FxConfig {
  /// The currency every rate is expressed in (1 quote = rate × base).
  final String base;
  final List<String> quotes;

  const FxConfig(this.base, this.quotes);
}

class MatchingConfig {
  /// Currencies investors can state their tickets in.
  final List<String> currencies;
  final List<String> sectors;
  final List<String> types;
  final List<String> countries;

  /// Relative weight of each preference in the match score.
  final Map<String, double> weights;

  /// Matches below this score (0-100) are not suggested.
  final int minScore;
  final String eligibility;

  const MatchingConfig({this.currencies = const ['XAF'], required this.sectors, required this.types, required this.countries, required this.weights, required this.minScore, required this.eligibility});
}

class CoachConfig {
  final int consentVersion;
  final String consentText;
  final List<String> topics;
  final int maxMessageLength;

  const CoachConfig({required this.consentVersion, required this.consentText, required this.topics, required this.maxMessageLength});
}

/// `platform_settings/intelligence` (admin). Each part is offered only when
/// enabled and valid; null when nothing is.
class IntelligenceConfig {
  final IndicatorsConfig? indicators;
  final FxConfig? fx;
  final MatchingConfig? matching;
  final CoachConfig? coach;

  const IntelligenceConfig({this.indicators, this.fx, this.matching, this.coach});

  static const List<String> matchKeys = ['sector', 'country', 'type', 'ticket', 'horizon'];

  static IntelligenceConfig? parse(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final ind = _map(raw['indicators']);
    final fx = _map(raw['exchangeRates']);
    final mt = _map(raw['matching']);
    final co = _map(raw['coach']);

    IndicatorsConfig? indicators;
    final countries = _strings(ind['countries']).where((c) => RegExp(r'^[A-Z]{2}$').hasMatch(c)).toList();
    if (ind['enabled'] == true && countries.isNotEmpty) indicators = IndicatorsConfig(countries);

    FxConfig? fxc;
    final String base = fx['base']?.toString() ?? '';
    final quotes = _strings(fx['quotes']).where((q) => _iso3(q) && q != base).toList();
    if (fx['enabled'] == true && _iso3(base) && quotes.isNotEmpty) fxc = FxConfig(base, quotes);

    MatchingConfig? matching;
    if (mt['enabled'] == true) {
      final w = _map(mt['weights']);
      final currencies = _strings(mt['currencies']).where(_iso3).toList();
      matching = MatchingConfig(
        currencies: currencies.isEmpty ? (fxc != null ? [fxc.base] : const ['XAF']) : currencies,
        sectors: _strings(mt['sectors']),
        types: _strings(mt['types']),
        countries: _strings(mt['countries']),
        weights: {for (final k in matchKeys) k: math.max(0, _num(w[k]) ?? 1).toDouble()},
        minScore: _int(mt['minScore']).clamp(0, 100),
        eligibility: mt['eligibility']?.toString() ?? '',
      );
    }

    CoachConfig? coach;
    final int version = _int(co['consentVersion']);
    final String consent = co['consentText']?.toString().trim() ?? '';
    if (co['enabled'] == true && version >= 1 && consent.isNotEmpty) {
      final int max = _int(co['maxMessageLength']);
      final topics = _strings(co['topics']).where(CoachRules.topics.contains).toList();
      coach = CoachConfig(
        consentVersion: version,
        consentText: consent,
        topics: topics.isEmpty ? const ['general'] : topics,
        maxMessageLength: max <= 0 ? 1000 : math.min(max, 4000),
      );
    }
    if (indicators == null && fxc == null && matching == null && coach == null) return null;
    return IntelligenceConfig(indicators: indicators, fx: fxc, matching: matching, coach: coach);
  }
}

// --------------------------------------------------------------- indicators

/// `economic_indicators/{id}`: one figure, with where it comes from.
class Indicator {
  final String id;
  final String country;
  final String code;
  final String name;
  final double? value;
  final double? previousValue;
  final String unit;
  final String currency;
  final String period;
  final String source;
  final String sourceUrl;
  final DateTime? updatedAt;

  const Indicator({
    required this.id,
    required this.country,
    required this.code,
    required this.name,
    required this.value,
    required this.previousValue,
    required this.unit,
    required this.currency,
    required this.period,
    required this.source,
    required this.sourceUrl,
    required this.updatedAt,
  });

  static Indicator fromMap(Map<String, dynamic> m, DateTime? Function(dynamic) toDate) => Indicator(
        id: m['id']?.toString() ?? '',
        country: m['country']?.toString() ?? '',
        code: m['code']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        value: _num(m['value']),
        previousValue: _num(m['previousValue']),
        unit: m['unit']?.toString() ?? '',
        currency: m['currency']?.toString() ?? '',
        period: m['period']?.toString() ?? '',
        source: m['source']?.toString() ?? '',
        sourceUrl: '${m['sourceUrl'] ?? ''}'.startsWith('https://') ? m['sourceUrl'].toString() : '',
        updatedAt: toDate(m['updatedAt']),
      );

  /// Shown only with a value, a source, a reporting period and an update time.
  bool get complete => value != null && name.isNotEmpty && source.isNotEmpty && period.isNotEmpty && updatedAt != null;

  double? get change => value == null || previousValue == null ? null : value! - previousValue!;

  /// `up`, `down`, `flat`, or null without a previous value.
  String? get direction {
    final c = change;
    if (c == null) return null;
    if (c.abs() < 1e-9) return 'flat';
    return c > 0 ? 'up' : 'down';
  }

  /// "4.2 %", "1 234.5 billion XAF".
  String get display => '${formatNumber(value ?? 0)}${unit.isEmpty ? '' : (unit == '%' ? ' %' : ' $unit')}${currency.isEmpty ? '' : ' $currency'}';
}

/// Up to 2 decimals, thousands separated by spaces, no trailing zeros.
String formatNumber(double v, {int decimals = 2}) {
  final bool negative = v < 0;
  final String fixed = v.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final String whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
  String frac = parts.length > 1 ? parts[1].replaceFirst(RegExp(r'0+$'), '') : '';
  return '${negative ? '-' : ''}$whole${frac.isEmpty ? '' : '.$frac'}';
}

// ------------------------------------------------------------ exchange rates

/// `exchange_rate_snapshots/{id}`: 1 [from] = [rate] [to].
class FxRate {
  final String from;
  final String to;
  final double rate;
  final String source;
  final String kind;
  final DateTime? observedAt;

  const FxRate({required this.from, required this.to, required this.rate, required this.source, required this.kind, required this.observedAt});

  static FxRate? fromMap(Map<String, dynamic> m, DateTime? Function(dynamic) toDate) {
    final String from = m['from']?.toString() ?? '';
    final String to = m['to']?.toString() ?? '';
    final double? rate = _num(m['rate']);
    final String source = m['source']?.toString() ?? '';
    final DateTime? at = toDate(m['observedAt']);
    if (!_iso3(from) || !_iso3(to) || rate == null || rate <= 0 || source.isEmpty || at == null) return null;
    return FxRate(from: from, to: to, rate: rate, source: source, kind: m['kind']?.toString() ?? 'indicative', observedAt: at);
  }
}

abstract final class FxConverter {
  /// The newest rate per `from` currency into [base] (snapshots in any order).
  static Map<String, FxRate> latest(List<FxRate> snapshots, String base) {
    final out = <String, FxRate>{};
    for (final r in snapshots) {
      if (r.to != base) continue;
      final cur = out[r.from];
      if (cur == null || r.observedAt!.isAfter(cur.observedAt!)) out[r.from] = r;
    }
    return out;
  }

  /// [amount] of [from] in [to], through [base]; null without the rates.
  static double? convert(double amount, String from, String to, String base, Map<String, FxRate> toBase) {
    final double? inBase = from == base ? amount : (toBase[from] == null ? null : amount * toBase[from]!.rate);
    if (inBase == null) return null;
    if (to == base) return inBase;
    final r = toBase[to];
    return r == null ? null : inBase / r.rate;
  }
}

// ----------------------------------------------------------------- matching

/// `investor_profiles/{uid}`: what the investor is looking for.
class InvestorProfile {
  final List<String> sectors;
  final List<String> countries;
  final List<String> types;
  final String currency;
  final int minTicket;
  final int maxTicket;
  final int maxRisk;
  final int maxHorizonMonths;

  const InvestorProfile({
    required this.sectors,
    required this.countries,
    required this.types,
    required this.currency,
    required this.minTicket,
    required this.maxTicket,
    required this.maxRisk,
    required this.maxHorizonMonths,
  });

  static InvestorProfile? fromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final String currency = m['currency']?.toString() ?? '';
    final int max = _int(m['maxTicket']);
    if (!_iso3(currency) || max <= 0) return null;
    return InvestorProfile(
      sectors: _strings(m['sectors']),
      countries: _strings(m['countries']),
      types: _strings(m['types']),
      currency: currency,
      minTicket: math.max(0, _int(m['minTicket'])),
      maxTicket: max,
      maxRisk: _int(m['maxRisk']).clamp(1, 7),
      maxHorizonMonths: math.max(0, _int(m['maxHorizonMonths'])),
    );
  }
}

/// `investment_opportunities/{id}`, published after review.
class Opportunity {
  final String id;
  final String title;
  final String summary;
  final String sector;
  final String country;
  final String type;
  final String currency;
  final int minTicket;
  final int targetAmount;
  final int raisedAmount;
  final int horizonMonths;
  final int riskLevel;

  /// A target set by the project owner: never a promise.
  final double? targetReturnPercent;
  final String ownerName;
  final DateTime? closingDate;
  final String status;

  const Opportunity({
    required this.id,
    required this.title,
    required this.summary,
    required this.sector,
    required this.country,
    required this.type,
    required this.currency,
    required this.minTicket,
    required this.targetAmount,
    required this.raisedAmount,
    required this.horizonMonths,
    required this.riskLevel,
    required this.targetReturnPercent,
    required this.ownerName,
    required this.closingDate,
    required this.status,
  });

  static Opportunity fromMap(Map<String, dynamic> m, DateTime? Function(dynamic) toDate) => Opportunity(
        id: m['id']?.toString() ?? '',
        title: m['title']?.toString() ?? '',
        summary: m['summary']?.toString() ?? '',
        sector: m['sector']?.toString() ?? 'other',
        country: m['country']?.toString() ?? '',
        type: m['type']?.toString() ?? '',
        currency: m['currency']?.toString() ?? '',
        minTicket: math.max(0, _int(m['minTicket'])),
        targetAmount: math.max(0, _int(m['targetAmount'])),
        raisedAmount: math.max(0, _int(m['raisedAmount'])),
        horizonMonths: math.max(0, _int(m['horizonMonths'])),
        riskLevel: _int(m['riskLevel']).clamp(1, 7),
        targetReturnPercent: _num(m['targetReturnPercent']),
        ownerName: m['ownerName']?.toString() ?? '',
        closingDate: toDate(m['closingDate']),
        status: m['status']?.toString() ?? 'closed',
      );

  bool isOpen(DateTime now) => status == 'open' && (closingDate == null || now.isBefore(closingDate!));

  double get progress => targetAmount <= 0 ? 0 : (raisedAmount / targetAmount).clamp(0, 1).toDouble();
}

class MatchResult {
  final int score;

  /// The preferences met (keys of [IntelligenceConfig.matchKeys]).
  final List<String> reasons;

  const MatchResult(this.score, this.reasons);
}

/// The same rules the server uses to suggest matches (it stores them in `investor_matches`).
abstract final class MatchRules {
  /// Hard conditions: open, same currency, a ticket the investor can afford, a risk they accept.
  static bool eligible(InvestorProfile p, Opportunity o, DateTime now) =>
      o.isOpen(now) && o.currency == p.currency && o.minTicket <= p.maxTicket && o.riskLevel <= p.maxRisk;

  static MatchResult score(InvestorProfile p, Opportunity o, Map<String, double> weights) {
    final met = <String, bool>{
      'sector': p.sectors.isEmpty || p.sectors.contains(o.sector),
      'country': p.countries.isEmpty || p.countries.contains(o.country),
      'type': p.types.isEmpty || p.types.contains(o.type),
      'ticket': o.minTicket >= p.minTicket && o.minTicket <= p.maxTicket,
      'horizon': p.maxHorizonMonths == 0 || (o.horizonMonths > 0 && o.horizonMonths <= p.maxHorizonMonths),
    };
    double total = 0, got = 0;
    for (final k in IntelligenceConfig.matchKeys) {
      final double w = weights[k] ?? 1;
      total += w;
      if (met[k]!) got += w;
    }
    return MatchResult(total == 0 ? 0 : (got * 100 / total).round(), [for (final k in IntelligenceConfig.matchKeys) if (met[k]!) k]);
  }
}

// -------------------------------------------------------------------- coach

/// `coach_consents/{uid}`.
class CoachConsent {
  final int version;
  final bool withdrawn;
  final bool shareSummary;

  const CoachConsent(this.version, this.withdrawn, this.shareSummary);

  static CoachConsent? fromMap(Map<String, dynamic>? m) => m == null ? null : CoachConsent(_int(m['version']), m['withdrawn'] == true, m['shareSummary'] == true);

  /// Accepted, not withdrawn, and for the current text.
  bool validFor(CoachConfig c) => !withdrawn && version >= c.consentVersion;
}

/// A button under a coach answer: it only OPENS a screen; the user then
/// goes through that screen's own confirmation. The coach never acts.
class CoachAction {
  final String target;
  final String label;

  const CoachAction(this.target, this.label);
}

abstract final class CoachRules {
  static const List<String> topics = ['general', 'budget', 'savings', 'investing', 'loans', 'insurance', 'project_financing'];

  static const List<String> targets = ['savings', 'tontines', 'loans', 'investments', 'simulator', 'insurance', 'cards', 'transfers', 'bills', 'financing', 'kyc', 'indicators'];

  static String topic(String t) => const {
        'general': 'Any question',
        'budget': 'Budget',
        'savings': 'Saving',
        'investing': 'Investing',
        'loans': 'Borrowing',
        'insurance': 'Insurance',
        'project_financing': 'Financing a project',
      }[t] ??
      t;

  /// Translation key of the problem with a message, or null.
  static String? messageProblem(String text, int max) {
    final t = text.trim();
    if (t.isEmpty) return 'Write a message.';
    if (t.length > max) return 'Your message is too long.';
    return null;
  }

  /// The server's suggested actions, restricted to known screens.
  static List<CoachAction> actions(dynamic raw) => [
        for (final a in (raw is List ? raw : const []).whereType<Map>())
          if (targets.contains(a['target']) && '${a['label'] ?? ''}'.trim().isNotEmpty) CoachAction(a['target'].toString(), a['label'].toString().trim()),
      ].take(3).toList();
}

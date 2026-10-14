/// Spideli Finance: economic intelligence, markets, investor matching and
/// the AI financial coach, the pure rules and write plans the screens use
/// (.claude/FINANCE-APP-CONTRACT.md section 17,
/// .claude/FINANCE-DIRECT-FIRESTORE.md section 3.11). Unit tested in
/// test/finance_intel_rules_test.dart and test/finance_markets_test.dart.
///
/// Indicators, exchange rates and market data (securities, prices, IPOs,
/// collections, news) are published by the ADMIN from approved, licensed
/// sources; the app never shows a figure without its source and update
/// time. The customer writes only their own investor profile, watchlist and
/// responses to opportunities. The AI coach runs on a server; it informs and
/// explains, and never moves money.
library;

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:customer/service/finance_ledger.dart' show FinanceWrite;

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

/// The market parts of `platform_settings/intelligence.markets`
/// (`{enabled, stocks, bonds, ipos, collections, news}`): each one offered
/// only when `true` (the admin publishes its data from a licensed feed).
class MarketsConfig {
  final bool stocks;
  final bool bonds;
  final bool ipos;
  final bool collections;
  final bool news;

  const MarketsConfig({this.stocks = false, this.bonds = false, this.ipos = false, this.collections = false, this.news = false});

  bool get any => stocks || bonds || ipos || collections || news;

  /// Null when `enabled` is not true or no part is on.
  static MarketsConfig? parse(dynamic raw) {
    final m = _map(raw);
    if (m['enabled'] != true) return null;
    final c = MarketsConfig(stocks: m['stocks'] == true, bonds: m['bonds'] == true, ipos: m['ipos'] == true, collections: m['collections'] == true, news: m['news'] == true);
    return c.any ? c : null;
  }
}

/// `platform_settings/intelligence` (admin). Each part is offered only when
/// enabled and valid; null when nothing is.
class IntelligenceConfig {
  final IndicatorsConfig? indicators;
  final FxConfig? fx;
  final MatchingConfig? matching;
  final CoachConfig? coach;
  final MarketsConfig? markets;

  const IntelligenceConfig({this.indicators, this.fx, this.matching, this.coach, this.markets});

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
    final markets = MarketsConfig.parse(raw['markets']);
    if (indicators == null && fxc == null && matching == null && coach == null && markets == null) return null;
    return IntelligenceConfig(indicators: indicators, fx: fxc, matching: matching, coach: coach, markets: markets);
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

/// The customer's own writes of the matching part (pure).
abstract final class IntelPlans {
  /// Why the profile cannot be saved, as a `FinanceException` reason.
  static String? profileProblem(MatchingConfig cfg, {required String currency, required int minTicket, required int maxTicket}) {
    if (!cfg.currencies.contains(currency)) return 'state_changed';
    if (minTicket < 0 || maxTicket <= 0 || minTicket > maxTicket) return 'amount_out_of_range';
    return null;
  }

  /// `investor_profiles/{uid}` (the owner's document, replaced as a whole):
  /// only the values the admin offers.
  static List<FinanceWrite> investorProfile(
    String uid,
    MatchingConfig cfg, {
    required String currency,
    required List<String> sectors,
    required List<String> countries,
    required List<String> types,
    required int minTicket,
    required int maxTicket,
    required int maxRisk,
    required int maxHorizonMonths,
  }) =>
      [
        FinanceWrite('investor_profiles/$uid', 'merge', {
          'currency': currency,
          'sectors': [for (final x in sectors.toSet()) if (cfg.sectors.contains(x)) x],
          'countries': [for (final x in countries.toSet()) if (cfg.countries.contains(x)) x],
          'types': [for (final x in types.toSet()) if (cfg.types.contains(x)) x],
          'minTicket': minTicket,
          'maxTicket': maxTicket,
          'maxRisk': maxRisk.clamp(1, 7),
          'maxHorizonMonths': math.max(0, maxHorizonMonths),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      ];

  /// The longest message sent with a response.
  static const int maxMessage = 500;

  /// `opportunity_interests/{opportunityId}_{uid}`: the user's response. Their
  /// name and email are shared with the owner only when [interested] (and
  /// removed when they say "not for me" afterwards). No money moves.
  static List<FinanceWrite> respond({
    required String opportunityId,
    required String uid,
    required bool interested,
    String message = '',
    String name = '',
    String email = '',
  }) {
    final String text = message.trim();
    return [
      FinanceWrite('opportunity_interests/${opportunityId}_$uid', 'merge', {
        'opportunityId': opportunityId,
        'userId': uid,
        'interested': interested,
        'message': text.length > maxMessage ? text.substring(0, maxMessage) : text,
        'name': interested ? name.trim() : FieldValue.delete(),
        'email': interested ? email.trim() : FieldValue.delete(),
        'createdAt': FieldValue.serverTimestamp(),
      }),
    ];
  }
}

// ------------------------------------------------------------------ markets

/// The direction of a change: `up`, `down`, `flat`, or null without one.
String? _direction(double? change) {
  if (change == null) return null;
  if (change.abs() < 1e-9) return 'flat';
  return change > 0 ? 'up' : 'down';
}

String _https(dynamic v) => '${v ?? ''}'.startsWith('https://') ? v.toString() : '';

/// `market_securities/{id}`, published by the admin from a licensed feed:
/// a stock, an ETF, a bond, or a market index (prices in major units of
/// [currency]; an index is in points). Shown only with a source, an update
/// time and a price (a bond: a price or a yield).
class MarketSecurity {
  static const List<String> types = ['stock', 'etf', 'bond', 'index'];

  final String id;
  final String type;
  final String symbol;
  final String name;
  final String exchange;
  final String country;
  final String currency;
  final String sector;
  final double? price;
  final double? change;
  final double? changePercent;
  final double? open;
  final double? high;
  final double? low;
  final double? volume;
  final double? couponPercent;
  final double? yieldPercent;
  final DateTime? maturityDate;
  final String source;
  final DateTime? updatedAt;

  /// The feed delays the prices (e.g. 15 minutes): said next to them.
  final bool delayed;

  const MarketSecurity({
    required this.id,
    required this.type,
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.country,
    required this.currency,
    required this.sector,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.open,
    required this.high,
    required this.low,
    required this.volume,
    required this.couponPercent,
    required this.yieldPercent,
    required this.maturityDate,
    required this.source,
    required this.updatedAt,
    required this.delayed,
  });

  /// Null when it is not published or incomplete.
  static MarketSecurity? fromMap(Map<String, dynamic> m, DateTime? Function(dynamic) toDate) {
    final String type = m['type']?.toString() ?? '';
    final s = MarketSecurity(
      id: m['id']?.toString() ?? '',
      type: type,
      symbol: m['symbol']?.toString().trim() ?? '',
      name: m['name']?.toString().trim() ?? '',
      exchange: m['exchange']?.toString().trim() ?? '',
      country: m['country']?.toString().trim() ?? '',
      currency: m['currency']?.toString().trim() ?? '',
      sector: m['sector']?.toString().trim() ?? '',
      price: _num(m['price']),
      change: _num(m['change']),
      changePercent: _num(m['changePercent']),
      open: _num(m['open']),
      high: _num(m['high']),
      low: _num(m['low']),
      volume: _num(m['volume']),
      couponPercent: _num(m['couponPercent']),
      yieldPercent: _num(m['yieldPercent']),
      maturityDate: toDate(m['maturityDate']),
      source: m['source']?.toString().trim() ?? '',
      updatedAt: toDate(m['updatedAt']),
      delayed: m['delayed'] == true,
    );
    if (m['published'] != true || !types.contains(type) || s.id.isEmpty || (s.name.isEmpty && s.symbol.isEmpty)) return null;
    if (s.source.isEmpty || s.updatedAt == null) return null;
    if (s.price == null && !(type == 'bond' && s.yieldPercent != null)) return null;
    return s;
  }

  bool get isBond => type == 'bond';
  bool get isIndex => type == 'index';

  /// The name, else the symbol.
  String get title => name.isNotEmpty ? name : symbol;

  /// `up`, `down`, `flat`, or null without a change.
  String? get direction => _direction(changePercent ?? change);

  /// Updated by the feed within [freshFor] and not delayed: "live".
  bool isLive(DateTime now, {Duration freshFor = const Duration(minutes: 15)}) => !delayed && updatedAt != null && now.difference(updatedAt!) <= freshFor;

  /// "1 234.5 XAF" ("1 234.5" for an index).
  String get priceDisplay => price == null ? '-' : '${formatNumber(price!)}${isIndex || currency.isEmpty ? '' : ' $currency'}';

  /// "+1.25 %" (null without a change).
  String? get changeDisplay {
    final double? p = changePercent;
    if (p != null) return '${p > 0 ? '+' : ''}${formatNumber(p)} %';
    final double? c = change;
    return c == null ? null : '${c > 0 ? '+' : ''}${formatNumber(c)}';
  }

  /// Sorted by name for a list.
  static int byName(MarketSecurity a, MarketSecurity b) => a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

/// `market_price_history/{id}`: `{securityId, date, close}`; the closes of
/// [rows] with a date and a value, oldest first.
List<(DateTime, double)> closingPrices(List<Map<String, dynamic>> rows, DateTime? Function(dynamic) toDate) {
  final out = <(DateTime, double)>[
    for (final r in rows)
      if (toDate(r['date']) != null && _num(r['close']) != null) (toDate(r['date'])!, _num(r['close'])!),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return out;
}

/// `ipo_listings/{id}`, published by the admin: an initial public offering
/// to follow (Spideli does not take subscriptions: that needs a broker).
class IpoListing {
  static const List<String> statuses = ['upcoming', 'open', 'closed', 'listed', 'withdrawn'];

  final String id;
  final String company;
  final String symbol;
  final String exchange;
  final String country;
  final String sector;
  final String currency;
  final double? priceLow;
  final double? priceHigh;
  final double? offerPrice;
  final DateTime? openDate;
  final DateTime? closeDate;
  final DateTime? listingDate;
  final String status;

  /// The prospectus (https only).
  final String prospectusUrl;
  final String source;
  final DateTime? updatedAt;

  const IpoListing({
    required this.id,
    required this.company,
    required this.symbol,
    required this.exchange,
    required this.country,
    required this.sector,
    required this.currency,
    required this.priceLow,
    required this.priceHigh,
    required this.offerPrice,
    required this.openDate,
    required this.closeDate,
    required this.listingDate,
    required this.status,
    required this.prospectusUrl,
    required this.source,
    required this.updatedAt,
  });

  /// Null when it is not published or incomplete (company, a known status,
  /// a source and an update time).
  static IpoListing? fromMap(Map<String, dynamic> m, DateTime? Function(dynamic) toDate) {
    final i = IpoListing(
      id: m['id']?.toString() ?? '',
      company: m['company']?.toString().trim() ?? '',
      symbol: m['symbol']?.toString().trim() ?? '',
      exchange: m['exchange']?.toString().trim() ?? '',
      country: m['country']?.toString().trim() ?? '',
      sector: m['sector']?.toString().trim() ?? '',
      currency: m['currency']?.toString().trim() ?? '',
      priceLow: _num(m['priceLow']),
      priceHigh: _num(m['priceHigh']),
      offerPrice: _num(m['offerPrice']),
      openDate: toDate(m['openDate']),
      closeDate: toDate(m['closeDate']),
      listingDate: toDate(m['listingDate']),
      status: m['status']?.toString() ?? '',
      prospectusUrl: _https(m['prospectusUrl']),
      source: m['source']?.toString().trim() ?? '',
      updatedAt: toDate(m['updatedAt']),
    );
    if (m['published'] != true || i.id.isEmpty || i.company.isEmpty || !statuses.contains(i.status) || i.source.isEmpty || i.updatedAt == null) return null;
    return i;
  }

  /// The offer price, else the range ("1 000 - 1 200 XAF"), else null.
  String? get priceDisplay {
    final String cur = currency.isEmpty ? '' : ' $currency';
    if (offerPrice != null) return '${formatNumber(offerPrice!)}$cur';
    if (priceLow != null && priceHigh != null) return '${formatNumber(priceLow!)} - ${formatNumber(priceHigh!)}$cur';
    final double? one = priceLow ?? priceHigh;
    return one == null ? null : '${formatNumber(one)}$cur';
  }

  /// The order of the IPO list: open, upcoming, then the others.
  int get rank => switch (status) { 'open' => 0, 'upcoming' => 1, 'listed' => 2, 'closed' => 3, _ => 4 };

  /// Open first, then upcoming (soonest first), then the most recent others.
  static int compare(IpoListing a, IpoListing b) {
    if (a.rank != b.rank) return a.rank.compareTo(b.rank);
    final DateTime far = DateTime(9999);
    if (a.rank <= 1) return (a.closeDate ?? a.openDate ?? far).compareTo(b.closeDate ?? b.openDate ?? far);
    return (b.listingDate ?? b.closeDate ?? DateTime(0)).compareTo(a.listingDate ?? a.closeDate ?? DateTime(0));
  }
}

/// `stock_collections/{id}`, published by the admin: a themed list of
/// securities (for information, not a recommendation).
class StockCollection {
  final String id;
  final String title;
  final String summary;
  final String theme;
  final List<String> securityIds;

  /// 1 (low) to 7 (high), or null when not given.
  final int? riskLevel;
  final int order;

  const StockCollection({required this.id, required this.title, required this.summary, required this.theme, required this.securityIds, required this.riskLevel, required this.order});

  static StockCollection? fromMap(Map<String, dynamic> m) {
    final ids = _strings(m['securityIds']);
    final c = StockCollection(
      id: m['id']?.toString() ?? '',
      title: m['title']?.toString().trim() ?? '',
      summary: m['summary']?.toString().trim() ?? '',
      theme: m['theme']?.toString().trim() ?? '',
      securityIds: ids.toSet().toList(),
      riskLevel: m['riskLevel'] is num ? _int(m['riskLevel']).clamp(1, 7) : null,
      order: m['order'] is num ? _int(m['order']) : 1 << 30,
    );
    if (m['published'] != true || c.id.isEmpty || c.title.isEmpty || ids.isEmpty) return null;
    return c;
  }

  /// The collection's securities that are published, in its order.
  List<MarketSecurity> of(List<MarketSecurity> all) {
    final byId = {for (final s in all) s.id: s};
    return [for (final id in securityIds) ?byId[id]];
  }
}

/// `finance_news/{id}`, published by the admin: a news item or an analysis
/// (`category`), with its source; the full text is at [url] (https).
class FinanceNews {
  final String id;
  final String title;
  final String summary;
  final String source;
  final String url;
  final String category;
  final String country;
  final DateTime? publishedAt;

  const FinanceNews({required this.id, required this.title, required this.summary, required this.source, required this.url, required this.category, required this.country, required this.publishedAt});

  static FinanceNews? fromMap(Map<String, dynamic> m, DateTime? Function(dynamic) toDate) {
    final n = FinanceNews(
      id: m['id']?.toString() ?? '',
      title: m['title']?.toString().trim() ?? '',
      summary: m['summary']?.toString().trim() ?? '',
      source: m['source']?.toString().trim() ?? '',
      url: _https(m['url']),
      category: (m['category']?.toString().trim() ?? '').isEmpty ? 'news' : m['category'].toString().trim(),
      country: m['country']?.toString().trim() ?? '',
      publishedAt: toDate(m['publishedAt']),
    );
    if (m['published'] != true || n.id.isEmpty || n.title.isEmpty || n.source.isEmpty || n.publishedAt == null) return null;
    return n;
  }
}

/// The user's watchlist (`investor_watchlists/{uid}`: `{securityIds, updatedAt}`).
abstract final class MarketPlans {
  static const int watchlistMax = 50;

  /// The ids of [raw] (a watchlist document), at most [watchlistMax].
  static List<String> watchlist(Map<String, dynamic>? raw) => _strings(raw?['securityIds']).toSet().take(watchlistMax).toList();

  /// Why [id] cannot be added: the list is full.
  static String? watchProblem(List<String> current, String id, bool watch) => watch && !current.contains(id) && current.length >= watchlistMax ? 'watchlist_full' : null;

  /// [current] with [id] added ([watch]) or removed.
  static List<String> toggled(List<String> current, String id, bool watch) => watch ? [...current.where((x) => x != id), id] : [...current.where((x) => x != id)];

  /// The owner's whole watchlist document.
  static List<FinanceWrite> save(String uid, List<String> ids) => [
        FinanceWrite('investor_watchlists/$uid', 'merge', {
          'securityIds': ids.toSet().take(watchlistMax).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      ];
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

import 'package:customer/utils/finance_intel_rules.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime? _d(dynamic v) => v is DateTime ? v : null;

void main() {
  test('configuration: each part only when enabled and valid; null when none', () {
    final c = IntelligenceConfig.parse({
      'indicators': {'enabled': true, 'countries': ['CM', 'cm', 'GAB']},
      'exchangeRates': {'enabled': true, 'base': 'XAF', 'quotes': ['EUR', 'XAF', 'usd']},
      'matching': {'enabled': true, 'weights': {'sector': 3, 'ticket': -1}, 'minScore': 150},
      'coach': {'enabled': true, 'consentVersion': 1, 'consentText': 'I agree', 'topics': ['budget', 'astrology']},
    })!;
    expect(c.indicators!.countries, ['CM']);
    expect(c.fx!.quotes, ['EUR']);
    expect(c.matching!.weights['sector'], 3);
    expect(c.matching!.weights['ticket'], 0);
    expect(c.matching!.weights['country'], 1);
    expect(c.matching!.minScore, 100);
    expect(c.matching!.currencies, ['XAF']);
    expect(c.coach!.topics, ['budget']);
    expect(c.coach!.maxMessageLength, 1000);
    final noCoach = IntelligenceConfig.parse({
      'indicators': {'enabled': true, 'countries': ['CM']},
      'coach': {'enabled': true, 'consentVersion': 1, 'consentText': ''},
    })!;
    expect(noCoach.coach, isNull);
    expect(IntelligenceConfig.parse({'coach': {'enabled': false, 'consentVersion': 1, 'consentText': 'x'}}), isNull);
    expect(IntelligenceConfig.parse(null), isNull);
  });

  test('indicators: shown only with value, source, period and update time', () {
    final i = Indicator.fromMap({
      'name': 'Inflation',
      'value': 4.2,
      'previousValue': 4.5,
      'unit': '%',
      'period': '2026-08',
      'source': 'INS',
      'sourceUrl': 'http://insecure',
      'updatedAt': DateTime(2026, 10, 1),
    }, _d);
    expect(i.complete, isTrue);
    expect(i.direction, 'down');
    expect(i.change, closeTo(-0.3, 1e-9));
    expect(i.display, '4.2 %');
    expect(i.sourceUrl, isEmpty);
    expect(Indicator.fromMap({'name': 'GDP', 'value': 1, 'period': '2025', 'updatedAt': DateTime(2026)}, _d).complete, isFalse);
    expect(Indicator.fromMap({'name': 'GDP', 'value': 1, 'source': 'IMF', 'updatedAt': DateTime(2026)}, _d).complete, isFalse);
    expect(formatNumber(1234567.891), '1 234 567.89');
    expect(formatNumber(-2.50), '-2.5');
  });

  test('exchange rates: newest per currency; cross rates through the base', () {
    FxRate r(String from, double rate, int day) => FxRate.fromMap({'from': from, 'to': 'XAF', 'rate': rate, 'source': 'BEAC', 'observedAt': DateTime(2026, 10, day)}, _d)!;
    final latest = FxConverter.latest([r('EUR', 655.957, 1), r('USD', 600, 1), r('USD', 610, 3)], 'XAF');
    expect(latest['USD']!.rate, 610);
    expect(FxConverter.convert(10, 'EUR', 'XAF', 'XAF', latest), closeTo(6559.57, 1e-6));
    expect(FxConverter.convert(6100, 'XAF', 'USD', 'XAF', latest), closeTo(10, 1e-9));
    expect(FxConverter.convert(1, 'EUR', 'USD', 'XAF', latest), closeTo(655.957 / 610, 1e-9));
    expect(FxConverter.convert(1, 'GBP', 'XAF', 'XAF', latest), isNull);
    expect(FxRate.fromMap({'from': 'EUR', 'to': 'XAF', 'rate': 655.957, 'observedAt': DateTime(2026)}, _d), isNull);
  });

  group('matching', () {
    final now = DateTime(2026, 10, 13);
    final p = InvestorProfile.fromMap({
      'currency': 'XAF',
      'sectors': ['agriculture'],
      'countries': ['CM'],
      'types': [],
      'minTicket': 100000,
      'maxTicket': 1000000,
      'maxRisk': 5,
      'maxHorizonMonths': 36,
    })!;
    Opportunity o([Map<String, dynamic> extra = const {}]) => Opportunity.fromMap({
          'status': 'open',
          'currency': 'XAF',
          'sector': 'agriculture',
          'country': 'CM',
          'type': 'equity',
          'minTicket': 250000,
          'horizonMonths': 24,
          'riskLevel': 4,
          ...extra,
        }, _d);

    test('eligibility', () {
      expect(MatchRules.eligible(p, o(), now), isTrue);
      expect(MatchRules.eligible(p, o({'riskLevel': 6}), now), isFalse);
      expect(MatchRules.eligible(p, o({'minTicket': 2000000}), now), isFalse);
      expect(MatchRules.eligible(p, o({'currency': 'EUR'}), now), isFalse);
      expect(MatchRules.eligible(p, o({'closingDate': DateTime(2026, 10, 1)}), now), isFalse);
      expect(InvestorProfile.fromMap({'currency': 'XAF'}), isNull);
    });

    test('weighted score and reasons', () {
      final even = {for (final k in IntelligenceConfig.matchKeys) k: 1.0};
      expect(MatchRules.score(p, o(), even).score, 100);
      final r = MatchRules.score(p, o({'sector': 'technology', 'horizonMonths': 60}), even);
      expect(r.score, 60);
      expect(r.reasons, ['country', 'type', 'ticket']);
      final heavy = {...even, 'sector': 6.0};
      expect(MatchRules.score(p, o({'sector': 'technology'}), heavy).score, 40);
    });
  });

  test('coach: consent version, message checks, actions restricted to screens', () {
    const cfg = CoachConfig(consentVersion: 2, consentText: 'x', topics: ['general'], maxMessageLength: 10);
    expect(CoachConsent.fromMap({'version': 2})!.validFor(cfg), isTrue);
    expect(CoachConsent.fromMap({'version': 1})!.validFor(cfg), isFalse);
    expect(CoachConsent.fromMap({'version': 2, 'withdrawn': true})!.validFor(cfg), isFalse);
    expect(CoachRules.messageProblem('  ', 10), isNotNull);
    expect(CoachRules.messageProblem('hello there friend', 10), contains('too long'));
    expect(CoachRules.messageProblem('hello', 10), isNull);
    final actions = CoachRules.actions([
      {'target': 'savings', 'label': 'Open savings'},
      {'target': 'transfer_now', 'label': 'Send 10 000 XAF'},
      {'target': 'loans', 'label': ' '},
      {'target': 'bills', 'label': 'Pay a bill'},
    ]);
    expect(actions.map((a) => a.target), ['savings', 'bills']);
  });
}

import 'package:customer/utils/finance_insurance_rules.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime? _d(dynamic v) => v is DateTime ? v : null;

void main() {
  test('configuration: parsed, fails closed without currency, category or payment method', () {
    final raw = {
      'currencies': ['XAF'],
      'categories': ['health', 'auto'],
      'paymentMethods': ['wallet'],
    };
    expect(InsuranceConfig.parse(raw)!.maxClaimFiles, 5);
    expect(InsuranceConfig.parse({...raw, 'claims': {'maxFiles': 50}})!.maxClaimFiles, 20);
    expect(InsuranceConfig.parse(null), isNull);
    expect(InsuranceConfig.parse({...raw, 'categories': []}), isNull);
    expect(InsuranceConfig.parse({...raw, 'paymentMethods': []}), isNull);
    expect(InsuranceConfig.parse({...raw, 'currencies': ['xaf']}), isNull);
  });

  InsuranceProduct product([Map<String, dynamic> extra = const {}]) => InsuranceProduct.fromMap({
        'id': 'p1',
        'name': 'Health Essentials',
        'currency': 'XAF',
        'category': 'health',
        'status': 'open',
        'termsVersion': 2,
        'coverages': [
          {'name': 'Hospital', 'limit': 2000000},
          {'description': 'no name'},
        ],
        'rating': {
          'basePremium': 60000,
          'frequencies': {'annual': 0, 'monthly': 5, 'weekly': 1},
          'factors': [
            {
              'key': 'age',
              'label': 'Age',
              'type': 'number',
              'min': 18,
              'max': 75,
              'bands': [
                {'upTo': 50, 'multiplier': 1.3},
                {'upTo': 30, 'multiplier': 1},
                {'upTo': 75, 'multiplier': 1.8},
              ],
            },
            {
              'key': 'level',
              'label': 'Cover level',
              'type': 'select',
              'options': [
                {'value': 'basic', 'label': 'Basic', 'multiplier': 1},
                {'value': 'plus', 'label': 'Plus', 'multiplier': 1.5},
              ],
            },
            {'key': 'bad', 'type': 'select', 'options': []},
          ],
        },
        ...extra,
      });

  test('product: parsed defensively', () {
    final p = product();
    expect(p.coverages.map((c) => c.name), ['Hospital']);
    expect(p.frequencies, {'annual': 0, 'monthly': 5});
    expect(p.factors.map((f) => f.key), ['age', 'level']);
    expect(p.factors.first.bands.map((b) => b.upTo), [30, 50, 75]);
    expect(p.termMonths, 12);
    expect(p.acceptsQuotes && p.canSimulate, isTrue);
    expect(product({'termsVersion': 0}).acceptsQuotes, isFalse);
    expect(product({'rating': null}).canSimulate, isFalse);
    expect(product({'rating': null}).frequencies, {'annual': 0});
  });

  test('rate simulation: factors multiply, the frequency loading spreads over the year', () {
    final p = product();
    final a = RateSimulator.estimate(p, {'age': 25, 'level': 'basic'}, 'annual')!;
    expect(a.yearly, 60000);
    expect(a.installment, 60000);
    final m = RateSimulator.estimate(p, {'age': '40', 'level': 'plus'}, 'monthly')!;
    expect(m.yearly, 117000); // 60 000 x 1.3 x 1.5
    expect(m.installment, 10238); // 117 000 x 1.05 / 12
    expect(m.installmentsPerYear, 12);
    expect(RateSimulator.estimate(p, {'age': 80, 'level': 'basic'}, 'annual'), isNull);
    expect(RateSimulator.estimate(p, {'age': 25}, 'annual'), isNull);
    expect(RateSimulator.estimate(p, {'age': 25, 'level': 'gold'}, 'annual'), isNull);
    expect(RateSimulator.estimate(p, {'age': 25, 'level': 'basic'}, 'quarterly'), isNull);
  });

  test('quote acceptance only while quoted and valid', () {
    final now = DateTime(2026, 10, 13);
    expect(Quote.fromMap({'status': 'quoted', 'premium': 1000, 'validUntil': DateTime(2026, 10, 20)}, _d).canAccept(now), isTrue);
    expect(Quote.fromMap({'status': 'quoted', 'premium': 1000, 'validUntil': DateTime(2026, 10, 1)}, _d).canAccept(now), isFalse);
    expect(Quote.fromMap({'status': 'quoted'}, _d).canAccept(now), isFalse);
    expect(Quote.fromMap({'status': 'requested', 'premium': 1000}, _d).canAccept(now), isFalse);
  });

  test('policy and claim actions', () {
    expect(PolicyActions.canClaim('active'), isTrue);
    expect(PolicyActions.canClaim('pending_activation'), isFalse);
    expect(PolicyActions.canClaim('lapsed'), isFalse);
    expect(PolicyActions.canRenew('renewal_due', 5000), isTrue);
    expect(PolicyActions.canRenew('active', 5000), isFalse);
    expect(PolicyActions.premiumPayable('overdue'), isTrue);
    expect(PolicyActions.premiumPayable('paid'), isFalse);
    expect(PolicyActions.canWithdrawClaim('info_requested'), isTrue);
    expect(PolicyActions.canWithdrawClaim('approved'), isFalse);
  });
}

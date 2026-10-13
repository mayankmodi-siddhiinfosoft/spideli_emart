import 'package:customer/utils/finance_investment_rules.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime? _d(dynamic v) => v is DateTime ? v : null;

void main() {
  final rawConfig = {
    'currencies': ['XAF', 'bad'],
    'assetClasses': ['money_market', 'bonds'],
    'paymentMethods': ['wallet'],
    'riskDisclosure': 'Investing carries risks, including the loss of capital.',
  };

  test('configuration: parsed, fails closed without currency, payment method or risk disclosure', () {
    final c = InvestmentConfig.parse(rawConfig)!;
    expect(c.currencies, ['XAF']);
    expect(c.simulatorMaxYears, 30);
    expect(InvestmentConfig.parse({...rawConfig, 'simulator': {'maxYears': 99}})!.simulatorMaxYears, 50);
    expect(InvestmentConfig.parse(null), isNull);
    expect(InvestmentConfig.parse({...rawConfig, 'currencies': ['xx']}), isNull);
    expect(InvestmentConfig.parse({...rawConfig, 'paymentMethods': []}), isNull);
    expect(InvestmentConfig.parse({...rawConfig, 'riskDisclosure': '  '}), isNull);
  });

  Fund fund([Map<String, dynamic> extra = const {}]) => Fund.fromMap({
        'id': 'f1',
        'name': 'Spideli Money Market',
        'currency': 'XAF',
        'riskLevel': 9,
        'minInvestment': 10000,
        'navPerUnit': 1250,
        'fees': {'subscriptionPercent': 2, 'redemptionPercent': 1},
        'termsVersion': 3,
        'status': 'open',
        'documents': [
          {'name': 'Prospectus', 'storagePath': 'investment_funds/f1/prospectus.pdf'},
          {'name': 'Unsafe', 'url': 'http://example.com/x.pdf'},
          {'name': 'Factsheet', 'url': 'https://example.com/f.pdf'},
        ],
        'performance': {'ytd': 3.2, 'oneYear': '5.1', 'bad': 'x'},
        ...extra,
      }, _d);

  test('fund: parsed defensively; subscriptions need an open fund, a price and current terms', () {
    final f = fund();
    expect(f.riskLevel, 7);
    expect(f.minimumFor(holder: true), 10000);
    expect(fund({'minAdditional': 5000}).minimumFor(holder: true), 5000);
    expect(f.documents.map((d) => d.name), ['Prospectus', 'Factsheet']);
    expect(f.performance, {'ytd': 3.2, 'oneYear': 5.1});
    expect(f.redemptionAllowed && f.partialRedemption, isTrue);
    expect(f.acceptsSubscriptions, isTrue);
    expect(fund({'status': 'closed'}).acceptsSubscriptions, isFalse);
    expect(fund({'navPerUnit': 0}).acceptsSubscriptions, isFalse);
    expect(fund({'termsVersion': 0}).acceptsSubscriptions, isFalse);
    expect(fund({'status': null}).status, 'closed');
  });

  test('risk bands', () {
    expect([1, 2, 3, 4, 5, 7].map(RiskScale.band), ['low', 'low', 'medium', 'medium', 'high', 'high']);
  });

  test('order estimates: fee first, then units at the last price (floored to 4 decimals)', () {
    final s = InvestmentCalculator.subscription(fund(), 100000);
    expect(s.fee, 2000);
    expect(s.net, 98000);
    expect(s.units, 78.4);
    final r = InvestmentCalculator.redemption(fund({'navPerUnit': 3}), 10000);
    expect(r.fee, 100);
    expect(r.net, 9900);
    expect(r.units, 3333.3333);
    expect(InvestmentCalculator.subscription(fund({'navPerUnit': null}), 1000).units, isNull);
  });

  test('allocation shares add up to exactly 100, largest first', () {
    final s = Allocation.shares({'bonds': 1, 'equities': 1, 'money_market': 1, 'empty': 0});
    expect(s.map((e) => e.percent).reduce((a, b) => a + b), 100);
    expect(s, hasLength(3));
    final t = Allocation.shares({'bonds': 25000, 'equities': 75000});
    expect(t.map((e) => (e.assetClass, e.percent)), [('equities', 75), ('bonds', 25)]);
    expect(Allocation.shares(null), isEmpty);
  });

  test('holding gains percent and lock-up', () {
    final h = Holding.fromMap({'units': 10.5, 'redeemableUnits': 4, 'investedAmount': 100000, 'unrealizedGains': 12000}, _d);
    expect(h.unrealizedPercent, 12);
    expect(h.partlyLocked, isTrue);
    expect(Holding.fromMap({'units': 0}, _d).unrealizedPercent, isNull);
  });

  test('order statuses', () {
    expect(InvestmentOrders.open('processing'), isTrue);
    expect(InvestmentOrders.open('settled'), isFalse);
    expect(InvestmentOrders.open('rejected'), isFalse);
    expect(InvestmentOrders.canCancelRedemption('submitted'), isTrue);
    expect(InvestmentOrders.canCancelRedemption('processing'), isFalse);
  });

  test('unit price change over a history', () {
    expect(navChangePercent([NavPoint(DateTime(2026), 1000), NavPoint(DateTime(2026, 6), 1050)]), closeTo(5, 1e-9));
    expect(navChangePercent([NavPoint(DateTime(2026), 1000)]), isNull);
  });

  test('return simulator: yearly compounding equivalent, monthly additions', () {
    final one = ReturnSimulator.project(initial: 100000, monthly: 0, annualPercent: 10, years: 2);
    expect(one.map((y) => y.value), [110000, 121000]);
    expect(one.last.gains, 21000);
    final flat = ReturnSimulator.project(initial: 0, monthly: 1000, annualPercent: 0, years: 3);
    expect(flat.last.contributed, 36000);
    expect(flat.last.value, 36000);
    final loss = ReturnSimulator.project(initial: 100000, monthly: 0, annualPercent: -10, years: 1);
    expect(loss.single.value, 90000);
  });

  test('display formats', () {
    expect(InvestmentLabels.percent(5.1, signed: true), '+5.1 %');
    expect(InvestmentLabels.percent(-2), '-2 %');
    expect(InvestmentLabels.percent(null), '-');
    expect(InvestmentLabels.units(78.4), '78.4');
    expect(InvestmentLabels.units(100), '100');
  });
}

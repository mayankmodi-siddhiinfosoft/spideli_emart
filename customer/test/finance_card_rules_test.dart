import 'package:customer/utils/finance_card_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = {
    'currencies': ['XAF'],
    'issuerName': 'Issuer',
    'maxCardsPerUser': 2,
    'issuanceFee': {'XAF': 1000},
    'fundingMethods': ['wallet', 'mobile_money'],
    'minFunding': {'XAF': 1000},
    'fundingFeePercent': 1.5,
    'limits': {
      'maxPerTransaction': {'XAF': 300000},
      'maxDaily': {'XAF': 500000},
      'maxMonthly': {'XAF': 2000000},
    },
    'capabilities': {'withdraw': true, 'renew': true, 'secureDetails': 'hosted'},
    'terms': 'Card terms',
    'termsVersion': 1,
  };

  test('configuration: parsed; capabilities never assumed; fails closed', () {
    final c = CardConfig.parse(raw)!;
    expect(c.maxCardsPerUser, 2);
    expect(c.feeFor(c.issuanceFee, 'XAF'), 1000);
    expect(c.feeFor(c.monthlyFee, 'XAF'), 0);
    expect(c.secureDetails, SecureDetailsMode.hosted);
    expect(c.canToggleOnline, isFalse);
    final bare = CardConfig.parse({...raw, 'capabilities': null})!;
    expect(bare.canWithdraw || bare.canRenew, isFalse);
    expect(bare.secureDetails, SecureDetailsMode.none);
    expect(CardConfig.parse({...raw, 'capabilities': {'secureDetails': 'plain'}})!.secureDetails, SecureDetailsMode.none);
    expect(CardConfig.parse(null), isNull);
    expect(CardConfig.parse({...raw, 'fundingMethods': []}), isNull);
    expect(CardConfig.parse({...raw, 'termsVersion': 0}), isNull);
    expect(CardConfig.parse({...raw, 'terms': ' '}), isNull);
  });

  VirtualCard card(String status, {String frozenBy = '', int balance = 5000, int month = 12, int year = 2028, String replacedBy = ''}) => VirtualCard.fromMap({
        'id': 'c',
        'status': status,
        'frozenBy': frozenBy,
        'balance': balance,
        'last4': '4242',
        'expiryMonth': month,
        'expiryYear': year,
        'replacedBy': replacedBy,
      });

  test('display: masked number and expiry only', () {
    expect(card('active').masked, '•••• •••• •••• 4242');
    expect(card('active').expiry, '12/28');
    expect(VirtualCard.fromMap({'last4': '42424242'}).masked, '•••• •••• •••• ••••');
    expect(VirtualCard.fromMap({}).expiry, '--/--');
    expect(card('active', month: 2, year: 2027).validUntil, DateTime(2027, 2, 28));
    expect(groupCardNumber('4111-1111 1111 1111'), '4111 1111 1111 1111');
  });

  test('actions', () {
    final cfg = CardConfig.parse(raw)!;
    final now = DateTime(2026, 10, 13);
    expect(CardActions.canCreate([card('active'), card('terminated')], cfg), isTrue);
    expect(CardActions.canCreate([card('active'), card('frozen')], cfg), isFalse);
    expect(CardActions.canUnfreeze(card('frozen', frozenBy: 'user')), isTrue);
    expect(CardActions.canUnfreeze(card('frozen', frozenBy: 'issuer')), isFalse);
    expect(CardActions.canTerminate(card('frozen', frozenBy: 'admin')), isFalse);
    expect(CardActions.canWithdraw(card('active', balance: 0), cfg), isFalse);
    expect(CardActions.canWithdraw(card('active'), CardConfig.parse({...raw, 'capabilities': null})!), isFalse);
    expect(CardActions.canRevealDetails(card('frozen'), cfg), isFalse);
    expect(CardActions.canRenew(card('active', month: 10, year: 2026), cfg, now), isTrue);
    expect(CardActions.canRenew(card('active'), cfg, now), isFalse);
    expect(CardActions.canRenew(card('expired', replacedBy: 'c2'), cfg, now), isFalse);
  });

  test('funding fee is added on top', () {
    final q = FundingQuote.of(10000, 1.5);
    expect(q.fee, 150);
    expect(q.total, 10150);
  });

  test('limits within the maxima and consistent', () {
    final cfg = CardConfig.parse(raw)!;
    expect(const CardLimits(perTransaction: 100000, daily: 200000, monthly: 1000000).problem(cfg, 'XAF'), isNull);
    expect(const CardLimits().problem(cfg, 'XAF'), isNull);
    expect(const CardLimits(perTransaction: 400000).problem(cfg, 'XAF'), contains('per payment'));
    expect(const CardLimits(perTransaction: 200000, daily: 100000).problem(cfg, 'XAF'), contains('cannot be above the daily'));
    expect(const CardLimits(daily: 600000, monthly: 1000000).problem(cfg, 'XAF'), contains('daily limit is above'));
    expect(const CardLimits(monthly: 0).problem(cfg, 'XAF'), contains('more than zero'));
  });
}

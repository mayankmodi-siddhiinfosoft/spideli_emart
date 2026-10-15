import 'package:customer/utils/finance_transfer_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = {
    'currencies': ['XAF'],
    'sourceMethods': ['wallet', 'mobile_money'],
    'security': {
      'reauthAbove': {'XAF': 50000},
    },
    'channels': {
      'internal': {'enabled': true, 'min': {'XAF': 100}},
      'mobile_money': {
        'enabled': true,
        'operators': ['MTN Mobile Money', 'Orange Money'],
        'feePercent': 1,
        'feeFixed': {'XAF': 50},
        'feeMax': {'XAF': 2000},
        'max': {'XAF': 500000},
      },
      'wave': {'enabled': false},
      'bank': {'enabled': true, 'banks': []},
    },
  };

  test('configuration: only enabled, usable channels; fails closed', () {
    final c = TransferConfig.parse(raw)!;
    expect(c.channels.keys, ['internal', 'mobile_money']);
    expect(c.channels['internal']!.minFor('XAF'), 100);
    expect(c.channels['mobile_money']!.maxFor('XAF'), 500000);
    expect(TransferConfig.parse(null), isNull);
    expect(TransferConfig.parse({...raw, 'sourceMethods': []}), isNull);
    expect(TransferConfig.parse({...raw, 'channels': {'wave': {'enabled': false}}}), isNull);
    expect(TransferConfig.parse({...raw, 'channels': {'mobile_money': {'enabled': true}}}), isNull);
  });

  test('fees: percent + fixed, capped', () {
    final fee = TransferConfig.parse(raw)!.channels['mobile_money']!.fee;
    expect(fee.feeFor(10000, 'XAF'), 150);
    expect(fee.feeFor(1000000, 'XAF'), 2000);
    expect(const FeeRule().feeFor(10000, 'XAF'), 0);
  });

  test('re-authentication threshold', () {
    final c = TransferConfig.parse(raw)!;
    expect(c.needsReauth(49999, 'XAF'), isFalse);
    expect(c.needsReauth(50000, 'XAF'), isTrue);
    expect(c.needsReauth(1, 'EUR'), isTrue);
  });

  test('recipient checks', () {
    expect(RecipientCheck.email('a.b@spideli.com'), isTrue);
    expect(RecipientCheck.email('a.b@spideli'), isFalse);
    expect(RecipientCheck.phone('+237 6 99 12 34 56'), isTrue);
    expect(RecipientCheck.phone('12345'), isFalse);
    expect(RecipientCheck.normalizePhone('+237 699-12 34 56'), '+237699123456');
    expect(RecipientCheck.iban('GB82 WEST 1234 5698 7654 32'), isTrue);
    expect(RecipientCheck.iban('GB82 WEST 1234 5698 7654 33'), isFalse);
    expect(RecipientCheck.bankAccount('GB82WEST12345698765433'), isFalse);
    expect(RecipientCheck.bankAccount('10005 00001 12345678901'), isTrue);
    expect(RecipientCheck.bankAccount('12-34'), isFalse);
    expect(RecipientCheck.holderName('Jo'), isFalse);
  });

  test('payment flow', () {
    final now = DateTime(2026, 10, 13, 12);
    expect(PaymentFlow.canConfirm('awaiting_confirmation', DateTime(2026, 10, 13, 12, 5), now), isTrue);
    expect(PaymentFlow.canConfirm('awaiting_confirmation', DateTime(2026, 10, 13, 11), now), isFalse);
    expect(PaymentFlow.canConfirm('pending', null, now), isFalse);
    expect(PaymentFlow.canCancel('pending'), isTrue);
    expect(PaymentFlow.canCancel('processing'), isFalse);
    expect(PaymentFlow.ended('reversed'), isTrue);
  });

  group('bills', () {
    test('configuration fails closed', () {
      expect(BillsConfig.parse({'currencies': ['XAF'], 'categories': ['electricity'], 'paymentMethods': ['wallet']}), isNotNull);
      expect(BillsConfig.parse({'currencies': ['XAF'], 'categories': [], 'paymentMethods': ['wallet']}), isNull);
      final c = BillsConfig.parse({
        'currencies': ['XAF'],
        'categories': ['water'],
        'paymentMethods': ['wallet'],
        'security': {'reauthAbove': {'XAF': 100000}},
      })!;
      expect(c.needsReauth(99999, 'XAF'), isFalse);
      expect(c.needsReauth(100000, 'XAF'), isTrue);
      expect(c.needsReauth(1, 'EUR'), isTrue, reason: 'no threshold: always (the rules refuse an older sign-in)');
    });

    test('biller: parsed defensively; account pattern anchored; bad pattern ignored', () {
      final b = Biller.fromMap({'name': 'ENEO', 'currency': 'XAF', 'amountType': 'open', 'accountPattern': r'\d{11}', 'min': 500, 'max': 200000})!;
      expect(b.accountValid('12345678901'), isTrue);
      expect(b.accountValid('123456789012'), isFalse);
      expect(Biller.fromMap({'name': 'X', 'currency': 'XAF', 'accountPattern': '(['})!.accountValid('anything'), isTrue);
      expect(Biller.fromMap({'name': 'X', 'currency': 'XAF', 'amountType': 'packages'}), isNull);
      expect(Biller.fromMap({'name': 'X', 'currency': 'XAF', 'amountType': 'magic'}), isNull);
      expect(Biller.fromMap({'name': 'X', 'currency': 'XAF', 'amountType': 'due'})!.lookup, isTrue);
    });

    test('amounts by biller type', () {
      final open = Biller.fromMap({'name': 'ENEO', 'currency': 'XAF', 'amountType': 'open', 'min': 500, 'max': 200000})!;
      expect(open.amountProblem(1000), isNull);
      expect(open.amountProblem(100), contains('minimum'));
      expect(open.amountProblem(300000), contains('maximum'));
      final due = Biller.fromMap({'name': 'CDE', 'currency': 'XAF', 'amountType': 'due'})!;
      expect(due.amountProblem(5000, due: 5000), isNull);
      expect(due.amountProblem(4000, due: 5000), contains('in full'));
      expect(due.amountProblem(5000, due: 0), contains('Nothing'));
      final partial = Biller.fromMap({'name': 'CDE', 'currency': 'XAF', 'amountType': 'due', 'partialPayment': true})!;
      expect(partial.amountProblem(4000, due: 5000), isNull);
      expect(partial.amountProblem(6000, due: 5000), contains('more than'));
      final tv = Biller.fromMap({
        'name': 'Canal+',
        'currency': 'XAF',
        'amountType': 'packages',
        'packages': [
          {'code': 'ACCESS', 'name': 'Access', 'amount': 5000},
        ],
      })!;
      expect(tv.amountProblem(5000), isNull);
      expect(tv.amountProblem(6000), contains('package'));
    });
  });
}

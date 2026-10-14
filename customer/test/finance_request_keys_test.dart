import 'package:customer/service/finance_group_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// A retried request keeps its idempotency key; a new one gets its own.
void main() {
  test('the same intent keeps its key until it succeeds', () {
    final String intent = FinanceRequestKeys.intentOf('savings.contribute', 'goal1', 10000, {'method': 'wallet'});
    final String first = FinanceRequestKeys.of(intent);
    expect(FinanceRequestKeys.of(intent), first, reason: 'a retry after a lost answer must reuse the key');
    FinanceRequestKeys.done(intent);
    expect(FinanceRequestKeys.of(intent), isNot(first), reason: 'after success it is a new operation');
    FinanceRequestKeys.done(intent);
  });

  test('a different amount, target or payment is another request', () {
    final a = FinanceRequestKeys.of(FinanceRequestKeys.intentOf('savings.contribute', 'goal1', 10000, {'method': 'wallet'}));
    final b = FinanceRequestKeys.of(FinanceRequestKeys.intentOf('savings.contribute', 'goal1', 20000, {'method': 'wallet'}));
    final c = FinanceRequestKeys.of(FinanceRequestKeys.intentOf('savings.contribute', 'goal2', 10000, {'method': 'wallet'}));
    final d = FinanceRequestKeys.of(FinanceRequestKeys.intentOf('savings.contribute', 'goal1', 10000, {'method': 'mobile_money', 'number': '690000001'}));
    expect({a, b, c, d}.length, 4);
  });

  test('send: a failed call keeps the key for the retry, an answer releases it', () async {
    final keys = <String>[];
    Future<String> failing(String key) async {
      keys.add(key);
      throw Exception('deadline-exceeded');
    }

    Future<String> answering(String key) async {
      keys.add(key);
      return 'ok';
    }

    await expectLater(FinanceRequestKeys.send('goal.contribute', 'g1', 500, const {'method': 'wallet'}, failing), throwsException);
    expect(await FinanceRequestKeys.send('goal.contribute', 'g1', 500, const {'method': 'wallet'}, answering), 'ok');
    expect(keys[0], keys[1], reason: 'the retry after a timeout reuses the key');
    await FinanceRequestKeys.send('goal.contribute', 'g1', 500, const {'method': 'wallet'}, answering);
    expect(keys[2], isNot(keys[1]), reason: 'a new contribution after an answer gets a new key');
  });
}

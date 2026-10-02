import 'dart:math';

import 'package:driver/services/delivery_pod_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Random that replays fixed values, to force a collision with the
/// previous code.
class _Scripted implements Random {
  final List<int> values;
  int _i = 0;
  _Scripted(this.values);
  @override
  int nextInt(int max) => values[_i++ % values.length] % max;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

void main() {
  final DateTime t0 = DateTime(2026, 10, 3, 12);

  group('generateCode', () {
    test('is always 6 digits, zero-padded', () {
      for (var i = 0; i < 500; i++) {
        expect(DeliveryPodRules.generateCode(), matches(RegExp(r'^\d{6}$')));
      }
      expect(DeliveryPodRules.generateCode(random: _Scripted([42])), '000042');
    });

    test('differs from the previous code', () {
      final String code = DeliveryPodRules.generateCode(previous: '123456', random: _Scripted([123456, 123456, 654321]));
      expect(code, '654321');
      for (var i = 0; i < 200; i++) {
        final String prev = DeliveryPodRules.generateCode();
        expect(DeliveryPodRules.generateCode(previous: prev), isNot(prev));
      }
    });
  });

  group('expiry', () {
    test('a code lasts 10 minutes', () {
      final DateTime exp = DeliveryPodRules.expiryFor(t0);
      expect(exp.difference(t0), const Duration(minutes: 10));
      expect(DeliveryPodRules.isExpired(now: t0.add(const Duration(minutes: 9, seconds: 59)), expiresAt: exp), isFalse);
      expect(DeliveryPodRules.isExpired(now: exp, expiresAt: exp), isTrue);
      expect(DeliveryPodRules.isExpired(now: t0, expiresAt: null), isTrue);
    });

    test('an expired code is refused', () {
      final check = DeliveryPodRules.check(
          status: 'pending', code: '111111', now: t0.add(const Duration(minutes: 10)), expiresAt: DeliveryPodRules.expiryFor(t0), attempts: 0, entered: '111111');
      expect(check.result, PodCheckResult.expired);
      expect(DeliveryPodRules.messageFor(check), 'This code has expired. Generate a new one.');
    });
  });

  group('verification and attempts', () {
    final DateTime exp = DeliveryPodRules.expiryFor(t0);
    PodCheck enter(String entered, {int attempts = 0, String status = 'pending'}) =>
        DeliveryPodRules.check(status: status, code: '482913', now: t0.add(const Duration(minutes: 1)), expiresAt: exp, attempts: attempts, entered: entered);

    test('the right code verifies', () {
      expect(enter('482913').result, PodCheckResult.verified);
      expect(enter(' 482913 ').isSuccess, isTrue);
    });

    test('a wrong code counts an attempt and says how many are left', () {
      final check = enter('000000');
      expect(check.result, PodCheckResult.wrong);
      expect(check.attemptsAfter, 1);
      expect(check.attemptsLeft, 4);
      expect(check.invalidates, isFalse);
      expect(DeliveryPodRules.messageFor(check), 'Incorrect code. 4 attempts left.');
    });

    test('the 5th wrong entry invalidates the code', () {
      final check = enter('000000', attempts: 4);
      expect(check.result, PodCheckResult.tooManyAttempts);
      expect(check.attemptsAfter, 5);
      expect(check.invalidates, isTrue);
    });

    test('after 5 wrong entries even the right code is refused', () {
      expect(enter('482913', attempts: 5).result, PodCheckResult.tooManyAttempts);
      expect(enter('482913', attempts: 5, status: 'expired').result, PodCheckResult.tooManyAttempts);
    });

    test('no code yet, and an already verified order', () {
      expect(DeliveryPodRules.check(status: null, code: null, now: t0, expiresAt: null, attempts: 0, entered: '123456').result, PodCheckResult.noCode);
      expect(enter('999999', status: 'verified').result, PodCheckResult.alreadyVerified);
    });

    test('Drop Delivery reuses only a pending, unexpired code with attempts left', () {
      expect(DeliveryPodRules.canReuse(status: 'pending', now: t0, expiresAt: exp, attempts: 0), isTrue);
      expect(DeliveryPodRules.canReuse(status: 'pending', now: exp, expiresAt: exp, attempts: 0), isFalse);
      expect(DeliveryPodRules.canReuse(status: 'pending', now: t0, expiresAt: exp, attempts: 5), isFalse);
      expect(DeliveryPodRules.canReuse(status: 'expired', now: t0, expiresAt: exp, attempts: 0), isFalse);
    });
  });

  group('new code: cooldown and regeneration cap', () {
    test('the first code is always allowed', () {
      expect(DeliveryPodRules.newCodeDecision(regenerations: 0, now: t0, lastGeneratedAt: null).allowed, isTrue);
    });

    test('a new code waits 60 seconds after the last one', () {
      final d = DeliveryPodRules.newCodeDecision(regenerations: 1, now: t0.add(const Duration(seconds: 15)), lastGeneratedAt: t0);
      expect(d.kind, PodNewCodeKind.cooldown);
      expect(d.wait, const Duration(seconds: 45));
      expect(DeliveryPodRules.newCodeDecision(regenerations: 1, now: t0.add(const Duration(seconds: 60)), lastGeneratedAt: t0).allowed, isTrue);
    });

    test('at most 5 regenerations per order (1 + 5 codes)', () {
      final DateTime later = t0.add(const Duration(minutes: 5));
      for (var codes = 1; codes <= 5; codes++) {
        expect(DeliveryPodRules.newCodeDecision(regenerations: codes, now: later, lastGeneratedAt: t0).allowed, isTrue, reason: 'after $codes codes');
      }
      final capped = DeliveryPodRules.newCodeDecision(regenerations: 6, now: later, lastGeneratedAt: t0);
      expect(capped.kind, PodNewCodeKind.capReached);
      expect(DeliveryPodRules.regenerationsLeft(1), 5);
      expect(DeliveryPodRules.regenerationsLeft(6), 0);
    });
  });
}

import 'dart:math';

import 'package:driver/models/order_model.dart';
import 'package:driver/services/delivery_pod_rules.dart';
import 'package:driver/services/delivery_pod_service.dart';
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

  group('cancellation while a code is pending', () {
    PodCheck enter(String? orderStatus, {String status = 'pending'}) => DeliveryPodRules.check(
        orderStatus: orderStatus, status: status, code: '482913', now: t0, expiresAt: DeliveryPodRules.expiryFor(t0), attempts: 0, entered: '482913');

    test('a cancelled or rejected order cannot be verified, even with the right code', () {
      expect(enter('Order Cancelled').result, PodCheckResult.orderClosed);
      expect(enter('Order Rejected').result, PodCheckResult.orderClosed);
      expect(enter('Order Cancelled', status: 'verified').result, PodCheckResult.orderClosed, reason: 'never completed once cancelled');
      expect(DeliveryPodRules.messageFor(enter('Order Cancelled')), DeliveryPodRules.orderClosedMessage);
    });

    test('a live order verifies; a completed one only as a retry', () {
      expect(enter('In Transit').result, PodCheckResult.verified);
      expect(enter('Order Completed', status: 'verified').result, PodCheckResult.alreadyVerified);
      expect(enter('Order Completed').result, PodCheckResult.orderClosed);
    });
  });

  group('clock skew', () {
    test('on the generating phone, expiresAt is exact', () {
      // This phone is 5 minutes fast; its expiresAt and its clock agree.
      final PodState s = PodState(status: 'pending', expiresAt: t0.add(const Duration(minutes: 15)), generatedAt: t0, sameClock: true, regenerations: 1);
      expect(s.deadline, t0.add(const Duration(minutes: 15)));
      expect(s.lastGeneratedAt, t0.add(const Duration(minutes: 5)));
    });

    test('elsewhere, the server generatedAt + 10 minutes (+30 s) decides', () {
      // Generated by the Store's phone, 5 minutes fast.
      final PodState fast = PodState(status: 'pending', expiresAt: t0.add(const Duration(minutes: 15)), generatedAt: t0, regenerations: 1);
      expect(fast.isLive(t0.add(const Duration(minutes: 10, seconds: 29))), isTrue);
      expect(fast.isLive(t0.add(const Duration(minutes: 10, seconds: 30))), isFalse, reason: 'not stretched to 15 minutes');
      // ...5 minutes slow: not cut to 5 minutes.
      final PodState slow = PodState(status: 'pending', expiresAt: t0.add(const Duration(minutes: 5)), generatedAt: t0, regenerations: 1);
      expect(slow.isLive(t0.add(const Duration(minutes: 7))), isTrue);
      expect(slow.lastGeneratedAt, t0);
      // No server time yet: expiresAt.
      final PodState noServer = PodState(status: 'pending', expiresAt: t0.add(const Duration(minutes: 10)), regenerations: 1);
      expect(noServer.deadline, t0.add(const Duration(minutes: 10)));
    });

    test('a closed order is never live', () {
      final PodState s = PodState(status: 'pending', expiresAt: t0.add(const Duration(minutes: 10)), sameClock: true, orderClosed: true);
      expect(s.isLive(t0), isFalse);
    });
  });

  group('order saves never touch pod', () {
    test('a pending or verified pod is read but not written back', () {
      for (final String status in ['pending', 'verified']) {
        final OrderModel order = OrderModel.fromJson({
          'id': 'o1',
          'status': 'In Transit',
          'products': <dynamic>[],
          'pod': {'method': 'otp', 'status': status},
        });
        expect(order.pod?.status, status);
        expect(order.toJson().containsKey('pod'), isFalse, reason: 'setOrder is a deep merge: a stale pending copy would roll a verified pod back');
      }
    });
  });
}

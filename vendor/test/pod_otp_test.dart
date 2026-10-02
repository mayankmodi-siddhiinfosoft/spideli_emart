import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/constant/constant.dart' as app;
import 'package:vendor/models/order_model.dart';
import 'package:vendor/utils/pod_otp.dart';

/// Proof of delivery by customer OTP (`.claude/POD-OTP-CONTRACT.md`): the
/// numbers and rules the Store app shares with the Driver and Customer apps.
void main() {
  final DateTime t0 = DateTime(2026, 10, 3, 12, 0, 0);

  PodCode codeAt(DateTime generated, {String code = '123456', String status = PodStatus.pending, int attempts = 0, int regenerations = 1}) => PodCode(
    orderId: 'o1',
    code: code,
    status: status,
    expiresAt: Timestamp.fromDate(PodOtp.expiryFor(generated)),
    attempts: attempts,
    regenerations: regenerations,
  );

  group('contract numbers', () {
    test('match the contract to the letter', () {
      expect(PodRules.codeLength, 6);
      expect(PodRules.codeLifetime, const Duration(minutes: 10));
      expect(PodRules.maxAttempts, 5);
      expect(PodRules.resendCooldown, const Duration(seconds: 60));
      expect(PodRules.maxRegenerations, 5);
      expect(PodRules.collection, 'order_pod');
      expect(PodRules.notificationType, 'delivery_otp');
      expect(PodRole.vendor, 'vendor');
    });
  });

  group('code generation', () {
    test('six digits, leading zeros kept', () {
      final Random rng = Random(7);
      for (int i = 0; i < 500; i++) {
        expect(PodOtp.generateCode(random: rng), matches(RegExp(r'^\d{6}$')));
      }
    });

    test('never the previous code', () {
      // A generator that keeps producing the previous code first.
      final _Scripted rng = _Scripted([1, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5, 6, 9, 9, 9, 9, 9, 9]);
      expect(PodOtp.generateCode(previous: '123456', random: rng), '999999');
    });
  });

  group('checking an entered code', () {
    test('the right code within 10 minutes verifies', () {
      final PodCheckResult r = PodOtp.check(code: codeAt(t0), entered: '123456', now: t0.add(const Duration(minutes: 9, seconds: 59)));
      expect(r.outcome, PodCheck.verified);
      expect(r.isVerified, isTrue);
    });

    test('a wrong code counts down the attempts', () {
      final PodCheckResult first = PodOtp.check(code: codeAt(t0), entered: '000000', now: t0);
      expect(first.outcome, PodCheck.wrongCode);
      expect(first.attemptsLeft, 4);
      expect(first.message, 'Incorrect code. 4 attempts left.');

      final PodCheckResult last = PodOtp.check(code: codeAt(t0, attempts: 4), entered: '000000', now: t0);
      expect(last.outcome, PodCheck.wrongCode);
      expect(last.attemptsLeft, 0, reason: 'the fifth wrong entry expires the code');
    });

    test('five wrong entries lock the code, even for the right digits', () {
      expect(PodOtp.check(code: codeAt(t0, attempts: 5), entered: '123456', now: t0).outcome, PodCheck.tooManyAttempts);
      expect(PodOtp.check(code: codeAt(t0, attempts: 5, status: PodStatus.expired), entered: '123456', now: t0).outcome, PodCheck.tooManyAttempts);
    });

    test('expires exactly 10 minutes after it was generated', () {
      expect(PodOtp.check(code: codeAt(t0), entered: '123456', now: t0.add(const Duration(minutes: 10))).outcome, PodCheck.expired);
      expect(PodOtp.check(code: codeAt(t0), entered: '123456', now: t0.add(const Duration(minutes: 11))).message, 'This code has expired. Generate a new one.');
    });

    test('no code yet, a malformed entry, an already verified code', () {
      expect(PodOtp.check(code: null, entered: '123456', now: t0).outcome, PodCheck.noCode);
      expect(PodOtp.check(code: codeAt(t0), entered: '12345', now: t0).outcome, PodCheck.invalidFormat);
      expect(PodOtp.check(code: codeAt(t0), entered: '12a456', now: t0).outcome, PodCheck.invalidFormat);
      expect(PodOtp.check(code: codeAt(t0, status: PodStatus.verified), entered: '000000', now: t0).outcome, PodCheck.alreadyVerified);
    });
  });

  group('reusing and replacing a code', () {
    test('a pending, unexpired code is reused', () {
      expect(codeAt(t0).isUsableAt(t0.add(const Duration(minutes: 5))), isTrue);
      expect(codeAt(t0).isUsableAt(t0.add(const Duration(minutes: 10))), isFalse);
      expect(codeAt(t0, attempts: 5).isUsableAt(t0), isFalse);
      expect(codeAt(t0, status: PodStatus.verified).isUsableAt(t0), isFalse);
    });

    test('a new code only after the 60-second cooldown', () {
      expect(PodOtp.canResend(codeAt(t0), t0.add(const Duration(seconds: 59))), PodResend.coolingDown);
      expect(PodOtp.cooldownLeft(codeAt(t0), t0.add(const Duration(seconds: 45))), const Duration(seconds: 15));
      expect(PodOtp.canResend(codeAt(t0), t0.add(const Duration(seconds: 60))), PodResend.allowed);
      expect(PodOtp.canResend(null, t0), PodResend.allowed, reason: 'no code yet: the first one');
    });

    test('at most 5 new codes after the first', () {
      final DateTime later = t0.add(const Duration(minutes: 2));
      expect(PodOtp.canResend(codeAt(t0, regenerations: 5), later), PodResend.allowed);
      expect(PodOtp.canResend(codeAt(t0, regenerations: 6), later), PodResend.limitReached);
    });

    test('a verified order never gets a new code', () {
      expect(PodOtp.canResend(codeAt(t0, status: PodStatus.verified), t0.add(const Duration(minutes: 2))), PodResend.alreadyVerified);
    });

    test('the copy shown on screen has no digits', () {
      expect(codeAt(t0).redacted().code, isEmpty);
    });
  });

  group('a cancelled order', () {
    test('its code can never be verified, even the right one', () {
      expect(PodOtp.check(code: codeAt(t0), entered: '123456', now: t0, orderStatus: app.Constant.orderCancelled).outcome, PodCheck.orderClosed);
      expect(PodOtp.check(code: codeAt(t0), entered: '123456', now: t0, orderStatus: app.Constant.orderRejected).outcome, PodCheck.orderClosed);
      expect(PodOtp.check(code: codeAt(t0, status: PodStatus.verified), entered: '123456', now: t0, orderStatus: app.Constant.orderCancelled).outcome, PodCheck.orderClosed,
          reason: 'a cancelled order is never completed');
      expect(PodOtp.check(code: codeAt(t0), entered: '123456', now: t0, orderStatus: app.Constant.orderInTransit).outcome, PodCheck.verified);
      expect(PodOtp.check(code: codeAt(t0, status: PodStatus.verified), entered: '000000', now: t0, orderStatus: app.Constant.orderCompleted).outcome, PodCheck.alreadyVerified,
          reason: 'a retry after a failed completion');
      expect(PodOtp.check(code: codeAt(t0), entered: '123456', now: t0, orderStatus: app.Constant.orderCompleted).outcome, PodCheck.orderClosed);
    });
  });

  group('clock skew', () {
    PodCode fromStore({required DateTime serverGeneratedAt, required DateTime deviceExpiresAt, String generatedBy = 'store-1', String me = 'store-1'}) => PodCode.fromJson('o1', {
      'orderId': 'o1',
      'code': '123456',
      'status': 'pending',
      'generatedAt': Timestamp.fromDate(serverGeneratedAt),
      'expiresAt': Timestamp.fromDate(deviceExpiresAt),
      'generatedBy': generatedBy,
      'attempts': 0,
      'regenerations': 1,
    }, me: me)!;

    test('the device that generated the code goes by its own expiresAt', () {
      // This phone is 5 minutes fast: its own clock and expiresAt agree.
      final PodCode c = fromStore(serverGeneratedAt: t0, deviceExpiresAt: t0.add(const Duration(minutes: 15)));
      expect(c.sameClock, isTrue);
      expect(c.deadline, t0.add(const Duration(minutes: 15)));
      expect(c.issuedAt, t0.add(const Duration(minutes: 5)));
    });

    test('another device goes by the server generatedAt + 10 minutes (+30 s)', () {
      // Generated by a driver phone 5 minutes fast; checked here.
      final PodCode c = fromStore(serverGeneratedAt: t0, deviceExpiresAt: t0.add(const Duration(minutes: 15)), generatedBy: 'driver-9');
      expect(c.sameClock, isFalse);
      expect(c.isUsableAt(t0.add(const Duration(minutes: 10, seconds: 29))), isTrue);
      expect(c.isUsableAt(t0.add(const Duration(minutes: 10, seconds: 30))), isFalse, reason: 'not stretched to 15 minutes');
      // ...and a slow one cannot shorten it to 5.
      final PodCode slow = fromStore(serverGeneratedAt: t0, deviceExpiresAt: t0.add(const Duration(minutes: 5)), generatedBy: 'driver-9');
      expect(slow.isUsableAt(t0.add(const Duration(minutes: 7))), isTrue);
      expect(PodOtp.cooldownLeft(slow, t0.add(const Duration(seconds: 20))), const Duration(seconds: 40));
    });
  });

  group('new codes left', () {
    test('counts down from 5 after the first code', () {
      expect(codeAt(t0, regenerations: 1).regenerationsLeft, 5);
      expect(codeAt(t0, regenerations: 6).regenerationsLeft, 0);
    });
  });

  group('the order pod', () {
    test('an order from before the contract shows nothing', () {
      final OrderModel order = OrderModel.fromJson(_order({}));
      expect(order.pod, isNull);
      expect(OrderPod.showsVerified(order.pod), isFalse);
      expect(OrderPod.showsWaiting(order.pod, order.status), isFalse);
      expect(order.toJson().containsKey('pod'), isFalse, reason: 'a later save never clears a pod');
    });

    test('a verified pod round-trips and never carries the code', () {
      final Timestamp at = Timestamp.fromDate(t0);
      final OrderModel order = OrderModel.fromJson(
        _order({
          'pod': {
            'method': 'otp',
            'status': 'verified',
            'requestedAt': at,
            'expiresAt': at,
            'verifiedAt': at,
            'verifiedBy': 'store-uid',
            'verifiedByRole': 'vendor',
            'deliveredBy': {'id': 'd1', 'name': 'Ravi Kumar', 'phone': '+91 98765', 'photo': 'null'},
            'code': '123456',
            'adminNote': 'kept',
          },
        }),
      );
      expect(OrderPod.showsVerified(order.pod), isTrue);
      expect(order.pod!.deliveredBy!.name, 'Ravi Kumar');
      expect(order.pod!.deliveredBy!.photo, isNull, reason: '"null" is no photo');
      final Map<String, dynamic> written = order.pod!.toJson();
      expect(written['status'], 'verified');
      expect(written['verifiedByRole'], 'vendor');
      expect(written['adminNote'], 'kept');
      expect(written.containsKey('code'), isFalse);
      // Never echoed by an order save: updateOrder() replaces each field it
      // writes whole, so only the POD transactions may write `pod`.
      expect(order.toJson().containsKey('pod'), isFalse);
    });

    test('a pending pod shows the waiting note only while the order is on its way, and is not echoed', () {
      final OrderModel order = OrderModel.fromJson(
        _order({
          'status': app.Constant.orderInTransit,
          'pod': {'method': 'otp', 'status': 'pending'},
        }),
      );
      expect(OrderPod.showsWaiting(order.pod, order.status), isTrue);
      expect(OrderPod.showsWaiting(order.pod, app.Constant.orderCompleted), isFalse);
      expect(OrderPod.showsVerified(order.pod), isFalse);
      expect(order.toJson().containsKey('pod'), isFalse, reason: 'only the POD transaction writes a pending record');
    });

    test('delivery man parts drop blanks and get a country code', () {
      final PodDeliveryMan man = PodDeliveryMan.of(id: 'd1', firstName: 'Ravi', lastName: 'null', countryCode: '91', phoneNumber: '98765', photo: '');
      expect(man.name, 'Ravi');
      expect(man.phone, '+91 98765');
      expect(man.photo, isNull);
      expect(man.toJson(), {'id': 'd1', 'name': 'Ravi', 'phone': '+91 98765', 'photo': ''});
    });
  });
}

Map<String, dynamic> _order(Map<String, dynamic> extra) => {
  'id': 'o1',
  'status': app.Constant.orderCompleted,
  'products': <dynamic>[],
  'deliveryCharge': '0',
  'tip_amount': '0',
  ...extra,
};

/// Random that returns a fixed script of digits.
class _Scripted implements Random {
  final List<int> _digits;
  int _i = 0;
  _Scripted(this._digits);

  @override
  int nextInt(int max) => _digits[_i++ % _digits.length] % max;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

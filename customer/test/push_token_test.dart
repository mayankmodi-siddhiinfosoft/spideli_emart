import 'package:customer/utils/push_tap.dart';
import 'package:customer/utils/push_token.dart';
import 'package:flutter_test/flutter_test.dart';

/// Receiving: when the customer's `users/{uid}.fcmToken` is written or
/// cleared, and what a tapped or foreground push does.
///
/// On iOS `getToken()` throws until the APNs token has arrived; the app used
/// to save '' in that case, over the good token, so iPhones got nothing.
void main() {
  tearDown(() => PushToken.device = null);

  group('PushToken.toWrite', () {
    test('an empty token is never written', () {
      for (final t in [null, '', '  ', 'null']) {
        expect(PushToken.toWrite(deviceToken: t, storedToken: 'good-token'), isNull, reason: '$t');
        expect(PushToken.toWrite(deviceToken: t, storedToken: ''), isNull, reason: '$t');
      }
    });

    test('the same token is not written again', () {
      expect(PushToken.toWrite(deviceToken: 'tok', storedToken: 'tok'), isNull);
      expect(PushToken.toWrite(deviceToken: ' tok ', storedToken: 'tok'), isNull);
    });

    test('a new or changed token is written, trimmed', () {
      expect(PushToken.toWrite(deviceToken: 'new', storedToken: 'old'), 'new');
      expect(PushToken.toWrite(deviceToken: ' new ', storedToken: ''), 'new');
      expect(PushToken.toWrite(deviceToken: 'new', storedToken: null), 'new');
    });
  });

  group('PushToken.shouldClearOnSignOut', () {
    test('only while the stored token is this device\'s', () {
      expect(PushToken.shouldClearOnSignOut(storedToken: 'mine', deviceToken: 'mine'), isTrue);
      expect(PushToken.shouldClearOnSignOut(storedToken: 'other-phone', deviceToken: 'mine'), isFalse);
      expect(PushToken.shouldClearOnSignOut(storedToken: '', deviceToken: 'mine'), isFalse);
      expect(PushToken.shouldClearOnSignOut(storedToken: 'mine', deviceToken: null), isFalse);
      expect(PushToken.shouldClearOnSignOut(storedToken: 'null', deviceToken: 'null'), isFalse);
    });
  });

  group('PushToken.preferDevice', () {
    test('a saved copy of the user carries this device\'s token when there is one', () {
      expect(PushToken.preferDevice('stale'), 'stale');
      PushToken.device = 'null';
      expect(PushToken.preferDevice('stale'), 'stale');
      PushToken.device = 'fresh';
      expect(PushToken.preferDevice('stale'), 'fresh');
      expect(PushToken.preferDevice(null), 'fresh');
    });
  });

  group('PushToken.waitForApns', () {
    test('returns once the APNs token arrives', () async {
      int calls = 0;
      final ok = await PushToken.waitForApns(() async => ++calls < 3 ? null : 'apns', step: const Duration(milliseconds: 1));
      expect(ok, isTrue);
      expect(calls, 3);
    });

    test('survives a throwing probe', () async {
      int calls = 0;
      final ok = await PushToken.waitForApns(() async {
        if (++calls == 1) throw StateError('not yet');
        return 'apns';
      }, step: const Duration(milliseconds: 1));
      expect(ok, isTrue);
    });

    test('gives up after the deadline', () async {
      final ok = await PushToken.waitForApns(() async => null, maxWait: const Duration(milliseconds: 30), step: const Duration(milliseconds: 5));
      expect(ok, isFalse);
    });
  });

  group('PushTap', () {
    test('a payload that is not a JSON object routes nowhere instead of throwing', () {
      expect(PushTap.decodePayload(null), isEmpty);
      expect(PushTap.decodePayload(''), isEmpty);
      expect(PushTap.decodePayload('not json'), isEmpty);
      expect(PushTap.decodePayload('[1, 2]'), isEmpty);
      expect(PushTap.decodePayload('{"type":"orderChat","n":1}'), {'type': 'orderChat', 'n': 1});
    });

    test('chat and support taps open the matching screen', () {
      expect(PushTap.targetOf({'type': 'admin_chat'}), PushTapTarget.supportChat);
      expect(PushTap.targetOf({'type': 'orderChat', 'chatType': 'vendor'}), PushTapTarget.storeInbox);
      expect(PushTap.targetOf({'type': 'orderChat', 'chatType': 'provider'}), PushTapTarget.providerInbox);
      expect(PushTap.targetOf({'type': 'orderChat', 'chatType': 'worker'}), PushTapTarget.workerInbox);
      expect(PushTap.targetOf({'type': 'orderChat', 'chatType': 'driver'}), PushTapTarget.driverInbox);
      expect(PushTap.targetOf({'type': 'orderChat'}), PushTapTarget.driverInbox);
    });

    test('status pushes and missing data just open the app', () {
      expect(PushTap.targetOf({'type': 'delivery_otp', 'orderId': 'o'}), isNull);
      expect(PushTap.targetOf({'type': 'restaurant_accepted'}), isNull);
      expect(PushTap.targetOf(const {}), isNull);
      expect(PushTap.targetOf({'type': null, 'chatType': 5}), isNull);
    });

    test('field reads strings, never "null"', () {
      expect(PushTap.field({'a': null}, 'a'), '');
      expect(PushTap.field({'a': 'null'}, 'a'), '');
      expect(PushTap.field({'a': 5}, 'a'), '5');
      expect(PushTap.field(const {}, 'a'), '');
    });

    test('foreground text: the notification, else data; never app text', () {
      expect(PushTap.displayText(title: 'T', body: 'B', data: {'title': 'x'}), (title: 'T', body: 'B'));
      expect(PushTap.displayText(data: {'title': 'dt', 'body': 'db'}), (title: 'dt', body: 'db'));
      expect(
        PushTap.displayText(data: {'type': 'delivery_otp'}),
        isNull,
      );
      expect(PushTap.displayText(title: ' ', body: '', data: {'type': 'order_placed'}), isNull);
    });

    test('each message gets its own notification id', () {
      final a = PushTap.notificationId('0:1696-a');
      final b = PushTap.notificationId('0:1696-b');
      expect(a, isNot(b));
      expect(a, greaterThanOrEqualTo(0));
      expect(PushTap.notificationId(null, now: DateTime.fromMillisecondsSinceEpoch(5000)), 5);
    });
  });
}

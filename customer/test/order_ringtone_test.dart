import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:customer/service/order_ringtone.dart';

/// Naming of the admin's order ring sound (globalSettings.order_ringtone_url).
/// The same fixed vectors are tested in customer, vendor and driver: senders
/// and receivers - and the server (.claude/PUSH-CHANNELS.md, "Order
/// ringtone") - must derive the same names from the same URL.
void main() {
  const String url = 'https://example.com/ring.mp3';
  const String firebaseUrl = 'https://firebasestorage.googleapis.com/v0/b/spideli-870b0.appspot.com/o/ringtones%2Forder.mp3?alt=media&token=abc';

  group('key (32-bit FNV-1a, 8 hex)', () {
    test('standard FNV-1a vectors', () {
      expect(OrderRingtone.fnv1a32Hex(''), '811c9dc5');
      expect(OrderRingtone.fnv1a32Hex('a'), 'e40c292c');
      expect(OrderRingtone.fnv1a32Hex('foobar'), 'bf9cf968');
    });

    test('fixed URL vectors (also checked against Python and Node.js)', () {
      expect(OrderRingtone.keyFor(url), '955470e2');
      expect(OrderRingtone.keyFor('https://example.com/ring2.mp3'), '7e9d3d28');
      expect(OrderRingtone.keyFor(firebaseUrl), 'f7c271b0');
      expect(OrderRingtone.keyFor('https://example.com/sonnerie-é.mp3'), '3f794eb2', reason: 'UTF-8 bytes');
    });

    test('surrounding whitespace does not change the key; every key is 8 lowercase hex', () {
      expect(OrderRingtone.keyFor('  $url \n'), '955470e2');
      for (final String u in [url, firebaseUrl, 'http://a', 'https://x.y/z?q=1']) {
        expect(OrderRingtone.isValidKey(OrderRingtone.keyFor(u)), isTrue, reason: u);
      }
    });

    test('no ringtone: empty, blank, not http(s)', () {
      for (final String? u in [null, '', '   ', 'ring.mp3', 'ftp://example.com/r.mp3', 'content://x']) {
        expect(OrderRingtone.isConfigured(u), isFalse, reason: '$u');
        expect(OrderRingtone.keyFor(u), '');
        expect(OrderRingtone.storeChannelIdFor(u), isNull);
        expect(OrderRingtone.driverJobChannelIdFor(u), isNull);
        expect(OrderRingtone.iosSoundFor(u), isNull);
      }
      expect(OrderRingtone.isConfigured('HTTPS://EXAMPLE.COM/R.MP3'), isTrue);
      expect(OrderRingtone.isConfigured('http://example.com/r.wav'), isTrue);
    });
  });

  group('names', () {
    test('Android channels and the iOS sound file', () {
      expect(OrderRingtone.storeChannelIdFor(url), 'new_order_rt_955470e2');
      expect(OrderRingtone.driverJobChannelIdFor(url), 'driver_jobs_rt_955470e2');
      expect(OrderRingtone.iosSoundFor(url), 'order_ringtone_955470e2.caf');
      // Within the sendPush function's accepted characters (SERVER-PUSH-CONTRACT.md).
      expect(RegExp(r'^[A-Za-z0-9_.-]{1,64}$').hasMatch(OrderRingtone.storeChannelIdFor(url)!), isTrue);
      expect(RegExp(r'^[A-Za-z0-9_. -]{1,64}$').hasMatch(OrderRingtone.iosSoundFor(url)!), isTrue);
    });

    test('recognising ringtone channels and sounds', () {
      expect(OrderRingtone.isStoreRingtoneChannel('new_order_rt_955470e2'), isTrue);
      expect(OrderRingtone.isStoreRingtoneChannel('new_order'), isFalse);
      expect(OrderRingtone.isDriverJobRingtoneChannel('driver_jobs_rt_955470e2'), isTrue);
      expect(OrderRingtone.isDriverJobRingtoneChannel('driver_jobs'), isFalse);
      expect(OrderRingtone.isRingtoneSoundName('order_ringtone_955470e2.caf'), isTrue);
      expect(OrderRingtone.isRingtoneSoundName('order_alert.caf'), isFalse);
      expect(OrderRingtone.isRingtoneSoundName('default'), isFalse);
    });

    test('stale channels: other keys of the same prefix; all of them without a ringtone', () {
      const String p = OrderRingtone.storeChannelPrefix;
      expect(OrderRingtone.isStaleChannel('new_order_rt_7e9d3d28', prefix: p, currentKey: '955470e2'), isTrue);
      expect(OrderRingtone.isStaleChannel('new_order_rt_955470e2', prefix: p, currentKey: '955470e2'), isFalse);
      expect(OrderRingtone.isStaleChannel('new_order', prefix: p, currentKey: '955470e2'), isFalse);
      expect(OrderRingtone.isStaleChannel('general', prefix: p, currentKey: ''), isFalse);
      expect(OrderRingtone.isStaleChannel('new_order_rt_955470e2', prefix: p, currentKey: ''), isTrue);
      expect(OrderRingtone.isStaleChannel('driver_jobs_rt_7e9d3d28', prefix: OrderRingtone.driverJobChannelPrefix, currentKey: '955470e2'), isTrue);
      expect(OrderRingtone.isStaleChannel('driver_jobs', prefix: OrderRingtone.driverJobChannelPrefix, currentKey: ''), isFalse);
    });

    test('a prepared sound is used only for the current URL', () {
      expect(OrderRingtone.usableKey(url: url, preparedKey: '955470e2'), '955470e2');
      expect(OrderRingtone.usableKey(url: 'https://example.com/ring2.mp3', preparedKey: '955470e2'), isNull, reason: 'URL changed, not prepared yet');
      expect(OrderRingtone.usableKey(url: '', preparedKey: '955470e2'), isNull, reason: 'ringtone removed');
      expect(OrderRingtone.usableKey(url: url, preparedKey: null), isNull);
      expect(OrderRingtone.usableKey(url: url, preparedKey: '../../x'), isNull);
    });
  });

  group('change detection (OrderRingtone.plan)', () {
    const String newUrl = 'https://example.com/ring2.mp3';

    test('unchanged: nothing to do', () {
      expect(OrderRingtone.plan(url: url, preparedKey: '955470e2', fileReady: true), const RingtonePlan(RingtoneAction.none, key: '955470e2'));
      expect(OrderRingtone.plan(url: '  $url ', preparedKey: '955470e2', fileReady: true, foreground: false), const RingtonePlan(RingtoneAction.none, key: '955470e2'));
    });

    test('URL changed: prepare the new key, keep the old one until it is ready', () {
      expect(OrderRingtone.plan(url: newUrl, preparedKey: '955470e2', fileReady: false), const RingtonePlan(RingtoneAction.prepare, key: '7e9d3d28', keep: '955470e2'));
      expect(OrderRingtone.plan(url: newUrl, preparedKey: '955470e2', fileReady: false, foreground: false), const RingtonePlan(RingtoneAction.prepare, key: '7e9d3d28', keep: '955470e2'));
    });

    test('first ringtone, or the prepared file vanished: prepare', () {
      expect(OrderRingtone.plan(url: url, preparedKey: null, fileReady: false), const RingtonePlan(RingtoneAction.prepare, key: '955470e2'));
      expect(OrderRingtone.plan(url: url, preparedKey: '955470e2', fileReady: false), const RingtonePlan(RingtoneAction.prepare, key: '955470e2', keep: '955470e2'));
    });

    test('file already there but not recorded (preferences cleared, or switched back): adopt, no download', () {
      expect(OrderRingtone.plan(url: url, preparedKey: null, fileReady: true), const RingtonePlan(RingtoneAction.adopt, key: '955470e2'));
      expect(OrderRingtone.plan(url: url, preparedKey: '7e9d3d28', fileReady: true), const RingtonePlan(RingtoneAction.adopt, key: '955470e2', keep: '7e9d3d28'));
    });

    test('ringtone removed: clear (background only when something was prepared)', () {
      expect(OrderRingtone.plan(url: '', preparedKey: '955470e2', fileReady: false), const RingtonePlan(RingtoneAction.clear));
      expect(OrderRingtone.plan(url: '', preparedKey: '955470e2', fileReady: false, foreground: false), const RingtonePlan(RingtoneAction.clear));
      expect(OrderRingtone.plan(url: '', preparedKey: null, fileReady: false), const RingtonePlan(RingtoneAction.clear), reason: 'foreground removes leftovers');
      expect(OrderRingtone.plan(url: '', preparedKey: null, fileReady: false, foreground: false), const RingtonePlan(RingtoneAction.none));
      expect(OrderRingtone.plan(url: null, preparedKey: 'junk', fileReady: false, foreground: false), const RingtonePlan(RingtoneAction.none));
    });

    test('background settings check: throttled, forced by a ringtone_changed push', () {
      final DateTime now = DateTime(2026, 10, 8, 12);
      expect(OrderRingtone.shouldCheckInBackground(lastCheck: null, now: now), isTrue);
      expect(OrderRingtone.shouldCheckInBackground(lastCheck: now.subtract(const Duration(minutes: 3)), now: now), isFalse);
      expect(OrderRingtone.shouldCheckInBackground(lastCheck: now.subtract(const Duration(minutes: 10)), now: now), isTrue);
      expect(OrderRingtone.shouldCheckInBackground(lastCheck: now.subtract(const Duration(minutes: 3)), now: now, forced: true), isTrue);
      expect(OrderRingtone.changedPushType, 'ringtone_changed');
    });
  });

  test('the three copies of order_ringtone.dart are identical', () {
    final List<File> copies = [
      File('../customer/lib/service/order_ringtone.dart'),
      File('../vendor/lib/utils/order_ringtone.dart'),
      File('../driver/lib/services/order_ringtone.dart'),
    ];
    if (copies.any((File f) => !f.existsSync())) {
      markTestSkipped('sibling apps not checked out');
      return;
    }
    final String first = copies.first.readAsStringSync();
    for (final File f in copies.skip(1)) {
      expect(f.readAsStringSync(), first, reason: f.path);
    }
  });
}

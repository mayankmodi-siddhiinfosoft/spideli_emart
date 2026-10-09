import 'dart:async';

import 'package:customer/screen_ui/multi_vendor_service/profile_screen/profile_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/unread_badge.dart';
import 'package:customer/utils/unread_sum.dart';
import 'package:customer/widget/live_unread_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// The profile screen's aggregate unread badges: the pure summing of live
/// per-conversation counts ([UnreadSum]) and the badge on a profile row.
/// A fake count source per key, recording (un)subscriptions.
final class Fake {
  final Map<String, StreamController<int>> sources = {};
  final List<String> subscribed = [];
  final List<String> cancelled = [];

  Stream<int> countOf(String key) {
    final StreamController<int> c = StreamController<int>(onListen: () => subscribed.add(key), onCancel: () => cancelled.add(key));
    sources[key] = c;
    return c.stream;
  }
}

void main() {
  group('UnreadSum.sumOf', () {
    test('an empty inbox is 0', () async {
      final keys = StreamController<Iterable<String>>();
      final Fake fake = Fake();
      final List<int> got = [];
      final sub = UnreadSum.sumOf<String>(keys.stream, fake.countOf).listen(got.add);
      keys.add(const []);
      await pumpEventQueue();
      expect(got, [0]);
      await sub.cancel();
    });

    test('sums the conversations live, emitting only on change', () async {
      final keys = StreamController<Iterable<String>>();
      final Fake fake = Fake();
      final List<int> got = [];
      final sub = UnreadSum.sumOf<String>(keys.stream, fake.countOf).listen(got.add);
      keys.add(['a', 'b']);
      await pumpEventQueue();
      expect(fake.subscribed, ['a', 'b']);
      fake.sources['a']!.add(2);
      await pumpEventQueue();
      fake.sources['b']!.add(3);
      await pumpEventQueue();
      fake.sources['b']!.add(3); // unchanged: no new total
      await pumpEventQueue();
      fake.sources['a']!.add(0); // read
      await pumpEventQueue();
      expect(got, [0, 2, 5, 3]);
      await sub.cancel();
    });

    test('follows the inbox list: new conversations subscribe, gone ones cancel', () async {
      final keys = StreamController<Iterable<String>>();
      final Fake fake = Fake();
      final List<int> got = [];
      final sub = UnreadSum.sumOf<String>(keys.stream, fake.countOf).listen(got.add);
      keys.add(['a', 'b']);
      await pumpEventQueue();
      fake.sources['a']!.add(1);
      fake.sources['b']!.add(4);
      await pumpEventQueue();
      expect(got.last, 5);

      // An inbox update listing the same conversations does not re-subscribe.
      keys.add(['b', 'a', 'a']);
      await pumpEventQueue();
      expect(fake.subscribed, ['a', 'b']);
      expect(fake.cancelled, isEmpty);

      // 'b' leaves the newest N, 'c' arrives.
      keys.add(['a', 'c']);
      await pumpEventQueue();
      expect(fake.cancelled, ['b']);
      expect(fake.subscribed, ['a', 'b', 'c']);
      expect(got.last, 1);
      fake.sources['c']!.add(2);
      await pumpEventQueue();
      expect(got.last, 3);
      await sub.cancel();
    });

    test('cancelling the total cancels the inbox and every conversation', () async {
      bool keysCancelled = false;
      final keys = StreamController<Iterable<String>>(onCancel: () => keysCancelled = true);
      final Fake fake = Fake();
      final sub = UnreadSum.sumOf<String>(keys.stream, fake.countOf).listen((_) {});
      keys.add(['a', 'b', 'c']);
      await pumpEventQueue();
      await sub.cancel();
      expect(keysCancelled, isTrue);
      expect(fake.cancelled.toSet(), {'a', 'b', 'c'});
    });

    test('a failing conversation counts 0; a failing inbox drops every count', () async {
      final keys = StreamController<Iterable<String>>();
      final Fake fake = Fake();
      final List<int> got = [];
      final sub = UnreadSum.sumOf<String>(keys.stream, fake.countOf).listen(got.add, onError: (_) => fail('no error expected'));
      keys.add(['a', 'b']);
      await pumpEventQueue();
      fake.sources['a']!.add(2);
      fake.sources['b']!.add(3);
      await pumpEventQueue();
      fake.sources['a']!.addError(StateError('permission-denied'));
      await pumpEventQueue();
      expect(got.last, 3);
      keys.addError(StateError('offline'));
      await pumpEventQueue();
      expect(got.last, 0);
      expect(fake.cancelled.toSet(), {'a', 'b'});
      await sub.cancel();
    });

    test('a total above 99 is shown as 99+ by the badge', () async {
      final keys = StreamController<Iterable<String>>();
      final Fake fake = Fake();
      final List<int> got = [];
      final sub = UnreadSum.sumOf<String>(keys.stream, fake.countOf).listen(got.add);
      keys.add(['a', 'b']);
      await pumpEventQueue();
      fake.sources['a']!.add(100);
      fake.sources['b']!.add(60);
      await pumpEventQueue();
      expect(got.last, 160);
      expect(UnreadBadge.label(got.last), '99+');
      await sub.cancel();
    });
  });

  group('UnreadSum.perUser', () {
    test('0 while signed out; the old user is cancelled on a switch or sign-out', () async {
      final uids = StreamController<String?>();
      final Fake fake = Fake();
      final List<int> got = [];
      final sub = UnreadSum.perUser(uids.stream, fake.countOf).listen(got.add);
      uids.add(null);
      await pumpEventQueue();
      expect(got, [0]);
      expect(fake.subscribed, isEmpty);

      uids.add('u1');
      await pumpEventQueue();
      fake.sources['u1']!.add(4);
      await pumpEventQueue();
      expect(got.last, 4);

      uids.add('u2');
      await pumpEventQueue();
      expect(fake.cancelled, ['u1']);
      expect(got.last, 0);
      fake.sources['u2']!.add(1);
      await pumpEventQueue();
      expect(got.last, 1);

      uids.add('');
      await pumpEventQueue();
      expect(fake.cancelled, ['u1', 'u2']);
      expect(got.last, 0);
      await sub.cancel();
    });
  });

  group('UnreadSum.threadsOf', () {
    test('the thread is the order, the peer the other party (as the inbox rows)', () {
      final threads = UnreadSum.threadsOf([
        {'orderId': 'o1', 'senderId': 'me', 'receiverId': 'store1'},
        {'orderId': 'o2', 'senderId': 'driver1', 'receiverId': 'me'},
        {'orderId': 'o1', 'senderId': 'me', 'receiverId': 'store1'}, // duplicate
        {'orderId': '', 'senderId': 'x', 'receiverId': 'me'}, // no thread: no badge
        {'senderId': 'y', 'receiverId': 'me'},
        {'orderId': 'o3', 'senderId': null, 'receiverId': 'me'}, // no peer: whole thread
      ], 'me');
      expect(threads, [(threadId: 'o1', peerId: 'store1'), (threadId: 'o2', peerId: 'driver1'), (threadId: 'o3', peerId: '')]);
    });
  });

  group('profile row badge', () {
    Widget host(Widget row) => GetMaterialApp(
      theme: DsTheme.light(),
      home: Scaffold(body: Center(child: row)),
    );

    testWidgets('live count before the chevron, nothing at 0, 99+ past 99', (tester) async {
      final counts = StreamController<int>();
      addTearDown(counts.close);
      // The stream event lands after a frame; the rebuild needs the next one.
      Future<void> deliver(int n) async {
        counts.add(n);
        await tester.pump();
        await tester.pump();
      }

      await tester.pumpWidget(
        host(
          ProfileSettingsTile(
            icon: Icons.forum_outlined,
            title: 'Store Inbox',
            badge: LiveUnreadBadge(streamKey: 'test', create: () => counts.stream),
          ),
        ),
      );
      expect(find.byType(DsBadge), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      await deliver(0);
      expect(find.byType(DsBadge), findsNothing);

      await deliver(7);
      expect(find.text('7'), findsOneWidget);
      expect(tester.getCenter(find.byType(DsBadge)).dx, lessThan(tester.getCenter(find.byIcon(Icons.chevron_right_rounded)).dx));

      await deliver(150);
      expect(find.text('99+'), findsOneWidget);

      await deliver(0);
      expect(find.byType(DsBadge), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('a custom trailing control replaces badge and chevron', (tester) async {
      await tester.pumpWidget(host(const ProfileSettingsTile(icon: Icons.dark_mode_outlined, title: 'Dark Mode', trailing: Text('switch'))));
      expect(find.text('switch'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });
  });
}

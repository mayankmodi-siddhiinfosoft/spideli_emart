import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/lang/app_ar.dart';
import 'package:customer/lang/app_en.dart';
import 'package:customer/models/customer_notification_model.dart';
import 'package:customer/screen_ui/notification_center/notification_center_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/customer_notification_record.dart';
import 'package:customer/utils/order_notification_opener.dart';
import 'package:customer/utils/unread_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// The pure parts of the customer Notification Center and the chat unread
/// badges (`.claude/CUSTOMER-NOTIFICATIONS.md`).
void main() {
  group('UnreadBadge.label', () {
    test('no badge at zero or below', () {
      expect(UnreadBadge.label(0), '');
      expect(UnreadBadge.label(-3), '');
    });
    test('the count up to 99, then 99+', () {
      expect(UnreadBadge.label(1), '1');
      expect(UnreadBadge.label(99), '99');
      expect(UnreadBadge.label(100), '99+');
      expect(UnreadBadge.label(UnreadBadge.queryLimit), '99+');
    });
    test('the listener reads one more than the cap', () {
      expect(UnreadBadge.queryLimit, UnreadBadge.cap + 1);
    });
  });

  group('needsFallback', () {
    test('only a push without a notificationId is recorded by the app', () {
      expect(CustomerNotificationRecord.needsFallback({'type': 'restaurant_accepted'}), isTrue);
      expect(CustomerNotificationRecord.needsFallback({'notificationId': ''}), isTrue);
      expect(CustomerNotificationRecord.needsFallback({'notificationId': 'null'}), isTrue);
      expect(CustomerNotificationRecord.needsFallback({'notificationId': 'abc123'}), isFalse);
    });
  });

  group('fallbackId', () {
    test('msg_<messageId>, the same for every handler', () {
      expect(CustomerNotificationRecord.fallbackId(messageId: '0:1696%abc'), 'msg_0:1696%abc');
      expect(CustomerNotificationRecord.fallbackId(messageId: ' 0:1 '), 'msg_0:1');
    });
    test('a slash never reaches the document id', () {
      expect(CustomerNotificationRecord.fallbackId(messageId: 'projects/p/messages/1'), 'msg_projects_p_messages_1');
    });
    test('without a messageId: a stable hash of type, order and sent time', () {
      final DateTime sent = DateTime.utc(2026, 10, 7, 10);
      final a = CustomerNotificationRecord.fallbackId(data: {'type': 'driver_accepted', 'orderId': 'o1'}, sentTime: sent);
      final b = CustomerNotificationRecord.fallbackId(data: {'type': 'driver_accepted', 'orderId': 'o1'}, sentTime: sent);
      final c = CustomerNotificationRecord.fallbackId(data: {'type': 'driver_accepted', 'orderId': 'o2'}, sentTime: sent);
      final d = CustomerNotificationRecord.fallbackId(data: {'type': 'driver_accepted', 'orderId': 'o1'}, sentTime: sent.add(const Duration(seconds: 1)));
      expect(a, startsWith('msg_h'));
      expect(a, b);
      expect(a, isNot(c));
      expect(a, isNot(d));
    });
    test('without a sent time the text tells two pushes apart', () {
      final a = CustomerNotificationRecord.fallbackId(data: {'type': 'x'}, title: 'A', body: 'one');
      final b = CustomerNotificationRecord.fallbackId(data: {'type': 'x'}, title: 'A', body: 'two');
      expect(a, isNot(b));
    });
    test('FNV-1a is the published 32-bit hash', () {
      expect(CustomerNotificationRecord.fnv1a(''), 0x811c9dc5);
      expect(CustomerNotificationRecord.fnv1a('a'), 0xe40c292c);
      expect(CustomerNotificationRecord.fnv1a('foobar'), 0xbf9cf968);
    });
  });

  group('categoryOf', () {
    String cat(Map<String, dynamic> d) => CustomerNotificationRecord.categoryOf(d);
    test('order events and delivery codes', () {
      for (final t in [
        'restaurant_accepted',
        'driver_accepted',
        'restaurant_cancelled',
        'restaurant_rejected',
        'driver_completed',
        'takeaway_completed',
        'parcel_accepted',
        'rental_completed',
        'dinein_accepted',
        'dinein_canceled',
        'delivery_otp',
        'order_placed',
      ]) {
        expect(cat({'type': t}), CustomerNotificationRecord.categoryOrder, reason: t);
      }
    });
    test('chat pushes', () {
      for (final t in ['orderChat', 'chat', 'admin_chat', 'adminchat']) {
        expect(cat({'type': t, 'orderId': 'o1'}), CustomerNotificationRecord.categoryChat, reason: t);
      }
    });
    test('on-demand bookings', () {
      expect(cat({'type': 'provider_order', 'orderId': 'b1'}), CustomerNotificationRecord.categoryBooking);
      expect(cat({'type': 'service_completed'}), CustomerNotificationRecord.categoryBooking);
      expect(cat({'type': 'x', 'event': 'worker_assigned'}), CustomerNotificationRecord.categoryBooking);
      expect(cat({'type': 'booking_placed'}), CustomerNotificationRecord.categoryBooking);
    });
    test('account alerts', () {
      expect(cat({'type': 'wallet_topup'}), CustomerNotificationRecord.categoryAccount);
      expect(cat({'type': 'referral_bonus'}), CustomerNotificationRecord.categoryAccount);
    });
    test('an unknown type with an order id is an order update, else other', () {
      expect(cat({'type': 'status_update', 'orderId': 'o1'}), CustomerNotificationRecord.categoryOrder);
      expect(cat({'type': 'promo'}), CustomerNotificationRecord.categoryOther);
      expect(cat(const {}), CustomerNotificationRecord.categoryOther);
    });
  });

  group('document', () {
    test('every contract field, read false, strings-only data', () {
      final doc = CustomerNotificationRecord.document(
        id: 'msg_1',
        title: ' Order accepted ',
        body: 'Your order is being prepared',
        data: {'type': 'restaurant_accepted', 'orderId': 'o1', 'status': 'Order Accepted', 'n': 3, 'nil': null, 'm': {'a': 1}},
        createdAt: 'TS',
      );
      expect(doc, {
        'id': 'msg_1',
        'title': 'Order accepted',
        'body': 'Your order is being prepared',
        'type': 'restaurant_accepted',
        'category': 'order',
        'orderId': 'o1',
        'status': 'Order Accepted',
        'data': {'type': 'restaurant_accepted', 'orderId': 'o1', 'status': 'Order Accepted', 'n': '3', 'm': '{"a":1}'},
        'read': false,
        'createdAt': 'TS',
        'source': 'customer',
      });
    });
    test('order id from the other spellings', () {
      expect(CustomerNotificationRecord.orderIdOf({'order_id': 'x'}), 'x');
      expect(CustomerNotificationRecord.orderIdOf({'orderID': 'y'}), 'y');
      expect(CustomerNotificationRecord.orderIdOf({'orderId': 'null'}), '');
    });
  });

  group('CustomerNotificationModel', () {
    test('reads a stored document', () {
      final at = DateTime(2026, 10, 7, 9, 30);
      final n = CustomerNotificationModel.fromMap('doc1', {
        'id': 'other',
        'title': 'T',
        'body': 'B',
        'type': 'orderChat',
        'category': 'chat',
        'orderId': 'o1',
        'status': '',
        'data': {'type': 'orderChat', 'chatType': 'vendor', 'x': 1},
        'read': true,
        'createdAt': Timestamp.fromDate(at),
        'source': 'store',
      });
      expect(n.id, 'doc1');
      expect(n.read, isTrue);
      expect(n.createdAt, at);
      expect(n.data, {'type': 'orderChat', 'chatType': 'vendor', 'x': '1'});
      expect(n.category, 'chat');
    });
    test('missing or mistyped fields read as empty, never throw', () {
      final n = CustomerNotificationModel.fromMap('d', {'read': 'yes', 'data': 'junk', 'createdAt': 'soon', 'title': null});
      expect(n.read, isFalse);
      expect(n.data, isEmpty);
      expect(n.createdAt, isNull);
      expect(n.title, '');
      expect(n.category, 'other');
      expect(CustomerNotificationModel.fromMap('d', null).id, 'd');
    });
    test('routeData completes type and orderId from the fields', () {
      const n = CustomerNotificationModel(id: 'a', type: 'delivery_otp', orderId: 'o9', data: {'x': 'y'});
      expect(n.routeData, {'x': 'y', 'type': 'delivery_otp', 'orderId': 'o9'});
      const m = CustomerNotificationModel(id: 'b', type: 'ignored', orderId: 'o1', data: {'type': 'orderChat', 'orderId': 'o2'});
      expect(m.routeData, {'type': 'orderChat', 'orderId': 'o2'});
    });
  });

  group('idsToMarkRead', () {
    test('unread rows not marked during this visit yet', () {
      const list = [
        CustomerNotificationModel(id: 'a'),
        CustomerNotificationModel(id: 'b', read: true),
        CustomerNotificationModel(id: 'c'),
        CustomerNotificationModel(id: ''),
      ];
      expect(CustomerNotificationRecord.idsToMarkRead(list, {}), ['a', 'c']);
      expect(CustomerNotificationRecord.idsToMarkRead(list, {'a'}), ['c']);
      expect(CustomerNotificationRecord.idsToMarkRead(list, {'a', 'c'}), isEmpty);
    });
  });

  group('relativeTime', () {
    final now = DateTime(2026, 10, 7, 15, 0);
    test('just now, minutes, hours today, yesterday, then the date only', () {
      expect(CustomerNotificationRecord.relativeTime(null, now), 'Just now');
      expect(CustomerNotificationRecord.relativeTime(now.subtract(const Duration(seconds: 20)), now), 'Just now');
      expect(CustomerNotificationRecord.relativeTime(now.subtract(const Duration(minutes: 5)), now), '5 min ago');
      expect(CustomerNotificationRecord.relativeTime(now.subtract(const Duration(hours: 3)), now), '3 h ago');
      expect(CustomerNotificationRecord.relativeTime(DateTime(2026, 10, 6, 23, 0), now), 'Yesterday');
      expect(CustomerNotificationRecord.relativeTime(DateTime(2026, 10, 1), now), '');
    });
  });

  group('OrderNotificationOpener.isOwn', () {
    test('only the signed-in customer\'s order opens', () {
      expect(OrderNotificationOpener.isOwn({'authorID': 'u1'}, 'u1'), isTrue);
      expect(OrderNotificationOpener.isOwn({'authorID': 'u2'}, 'u1'), isFalse);
      expect(OrderNotificationOpener.isOwn({}, 'u1'), isFalse);
      expect(OrderNotificationOpener.isOwn({'authorID': ''}, ''), isFalse);
      expect(OrderNotificationOpener.isOwn(null, 'u1'), isFalse);
    });
  });

  group('translations', () {
    const keys = [
      'Notifications',
      'No notifications yet',
      'Order updates, messages and alerts will appear here.',
      'Just now',
      '@n min ago',
      '@n h ago',
      'Yesterday',
      'New',
      '@n unread',
      '@n unread notifications',
    ];
    final placeholder = RegExp(r'@\w+');
    for (final entry in const {'en_US': enUS, 'ar_AR': arAR}.entries) {
      test('${entry.key} translates every Notification Center label', () {
        for (final k in keys) {
          final String? v = entry.value[k];
          expect(v?.trim(), isNotEmpty, reason: k);
          expect(placeholder.allMatches(v!).map((m) => m.group(0)).toSet(), placeholder.allMatches(k).map((m) => m.group(0)).toSet(), reason: k);
        }
      });
    }
  });

  group('NotificationRow', () {
    final now = DateTime(2026, 10, 7, 15, 0);
    Widget host(Widget child) => GetMaterialApp(theme: DsTheme.light(), home: Scaffold(body: child));

    testWidgets('title, body, relative time, status and a tap', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        host(
          NotificationRow(
            notification: CustomerNotificationModel(
              id: 'a',
              title: 'Order accepted',
              body: 'The store is preparing your order',
              category: 'order',
              status: 'Order Accepted',
              createdAt: now.subtract(const Duration(minutes: 5)),
            ),
            isNew: true,
            now: now,
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.text('Order accepted'), findsOneWidget);
      expect(find.text('The store is preparing your order'), findsOneWidget);
      expect(find.text('Order Accepted'), findsOneWidget);
      expect(find.textContaining('5 min ago'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
      final Text title = tester.widget(find.text('Order accepted'));
      expect(title.style?.fontWeight, FontWeight.w700);
      await tester.tap(find.text('Order accepted'));
      expect(taps, 1);
    });

    testWidgets('a read row is not bold and has no status chip without a status', (tester) async {
      await tester.pumpWidget(
        host(NotificationRow(notification: CustomerNotificationModel(id: 'b', title: 'Hi', body: 'There', category: 'chat', read: true, createdAt: DateTime(2026, 9, 1)), isNew: false, now: now, onTap: () {})),
      );
      final Text title = tester.widget(find.text('Hi'));
      expect(title.style?.fontWeight, FontWeight.w500);
      expect(find.byType(DsStatusChip), findsNothing);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      expect(find.textContaining('01 Sep 2026'), findsOneWidget);
    });
  });
}

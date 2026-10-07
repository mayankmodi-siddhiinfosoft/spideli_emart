import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/lang/app_ar.dart';
import 'package:vendor/lang/app_de.dart';
import 'package:vendor/lang/app_en.dart';
import 'package:vendor/lang/app_fr.dart';
import 'package:vendor/lang/app_hi.dart';
import 'package:vendor/lang/app_ja.dart';
import 'package:vendor/lang/app_pt.dart';
import 'package:vendor/lang/app_ru.dart';
import 'package:vendor/lang/app_zh.dart';
import 'package:vendor/utils/chat_unread.dart';
import 'package:vendor/utils/customer_notification.dart';
import 'package:vendor/utils/push_payload.dart';

/// Customer Notification Center entries the store writes with its pushes, and
/// the chat inbox unread badge (.claude/CUSTOMER-NOTIFICATIONS.md).
void main() {
  group('categoryFor', () {
    test('order status pushes the store sends are orders', () {
      for (final t in ['restaurant_accepted', 'restaurant_rejected', 'restaurant_cancelled', 'takeaway_completed', 'store_completed', 'store_intransit', 'delivery_otp', 'pickup_otp', 'driver_completed']) {
        expect(CustomerNotification.categoryFor(t), CustomerNotification.categoryOrder, reason: t);
      }
    });

    test('chat pushes are chat, whatever the case', () {
      expect(CustomerNotification.categoryFor('orderChat'), CustomerNotification.categoryChat);
      expect(CustomerNotification.categoryFor('chat'), CustomerNotification.categoryChat);
      expect(CustomerNotification.categoryFor('admin_chat'), CustomerNotification.categoryChat);
    });

    test('dine-in and service bookings are bookings', () {
      expect(CustomerNotification.categoryFor('dinein_accepted'), CustomerNotification.categoryBooking);
      expect(CustomerNotification.categoryFor('dinein_canceled'), CustomerNotification.categoryBooking);
      expect(CustomerNotification.categoryFor('provider_order'), CustomerNotification.categoryBooking);
    });

    test('unknown types: an order id makes it an order, else other', () {
      expect(CustomerNotification.categoryFor('something', orderId: 'o1'), CustomerNotification.categoryOrder);
      expect(CustomerNotification.categoryFor('something'), CustomerNotification.categoryOther);
      expect(CustomerNotification.categoryFor(null), CustomerNotification.categoryOther);
      expect(CustomerNotification.categoryFor('wallet_topup'), CustomerNotification.categoryAccount);
    });
  });

  group('shouldRecord', () {
    test('only a customer with a known id', () {
      expect(CustomerNotification.shouldRecord(recipient: PushRecipient.customer, recipientId: 'c1'), isTrue);
      expect(CustomerNotification.shouldRecord(recipient: PushRecipient.customer, recipientId: ' '), isFalse);
      expect(CustomerNotification.shouldRecord(recipient: PushRecipient.customer, recipientId: null), isFalse);
      expect(CustomerNotification.shouldRecord(recipient: PushRecipient.customer, recipientId: 'admin'), isFalse);
      expect(CustomerNotification.shouldRecord(recipient: PushRecipient.driver, recipientId: 'd1'), isFalse);
      expect(CustomerNotification.shouldRecord(recipient: PushRecipient.store, recipientId: 's1'), isFalse);
    });
  });

  group('document', () {
    test('has every contract field, unread, from the store', () {
      const Object ts = 'SERVER_TS';
      final data = CustomerNotification.dataWithId({'type': 'restaurant_accepted', 'orderId': 'o1'}, 'n1');
      final doc = CustomerNotification.document(id: 'n1', title: 'Accepted', body: 'Your order was accepted', data: data, kind: 'restaurant_accepted', status: 'Order Accepted', createdAt: ts);
      expect(doc, {
        'id': 'n1',
        'title': 'Accepted',
        'body': 'Your order was accepted',
        'type': 'restaurant_accepted',
        'category': 'order',
        'orderId': 'o1',
        'status': 'Order Accepted',
        'data': {'type': 'restaurant_accepted', 'orderId': 'o1', 'notificationId': 'n1'},
        'read': false,
        'createdAt': ts,
        'source': 'store',
      });
    });

    test('type is the push data type (what the customer routes on), else the template type', () {
      final pod = CustomerNotification.document(id: 'n', title: 't', body: 'b', data: {'type': 'delivery_otp', 'orderId': 'o'}, kind: 'pickup_otp', createdAt: 0);
      expect(pod['type'], 'delivery_otp');
      final noType = CustomerNotification.document(id: 'n', title: 't', body: 'b', data: const {}, kind: 'dinein_accepted', createdAt: 0);
      expect(noType['type'], 'dinein_accepted');
      expect(noType['orderId'], '');
      expect(noType['status'], '');
      expect(noType['category'], 'booking');
    });

    test('chat entry keeps the chat routing data', () {
      final data = CustomerNotification.dataWithId({'type': 'orderChat', 'chatType': 'vendor', 'orderId': 'o1', 'senderId': 's1'}, 'n2');
      final doc = CustomerNotification.document(id: 'n2', title: 'Pizza Place', body: 'On its way', data: data, kind: 'chat', createdAt: 0);
      expect(doc['category'], 'chat');
      expect(doc['type'], 'orderChat');
      expect((doc['data'] as Map)['chatType'], 'vendor');
      expect((doc['data'] as Map)['notificationId'], 'n2');
    });

    test('long text is clipped like the push', () {
      final doc = CustomerNotification.document(id: 'n', title: 'x' * 500, body: 'y' * 5000, data: const {}, createdAt: 0);
      expect((doc['title'] as String).length, PushPayload.maxTitleLength);
      expect((doc['body'] as String).length, PushPayload.maxBodyLength);
    });

    test('dataWithId does not change the input map', () {
      final input = {'type': 'x'};
      final out = CustomerNotification.dataWithId(input, 'n');
      expect(input.containsKey('notificationId'), isFalse);
      expect(out['notificationId'], 'n');
    });
  });

  group('send layer wiring (source checks)', () {
    final String send = File('lib/constant/send_notification.dart').readAsStringSync();

    test('every public sender records the customer entry', () {
      expect(RegExp(r'_recordForCustomer\(').allMatches(send).length, 4, reason: '3 senders + the definition');
      expect(send.contains('await FireStoreUtils.addCustomerNotification(customerId: customerId, id: id, document: document).timeout(_recordTimeout)'), isTrue,
          reason: 'the write is bounded, so a refused write can drop the id');
    });

    test('no static notification text for the delivered push', () {
      final String home = File('lib/app/Home_screen/home_screen.dart').readAsStringSync();
      expect(home.contains('"Your order has been delivered successfully".tr'), isFalse);
      expect(home.contains('Constant.orderDeliveredTemplate'), isTrue);
    });
  });

  group('chat unread badge', () {
    test('label: none for zero, the number, then 99+', () {
      expect(ChatUnread.label(0), '');
      expect(ChatUnread.label(null), '');
      expect(ChatUnread.label(-3), '');
      expect(ChatUnread.label(1), '1');
      expect(ChatUnread.label(99), '99');
      expect(ChatUnread.label(100), '99+');
      expect(ChatUnread.label(250), '99+');
      expect(ChatUnread.hasBadge(0), isFalse);
      expect(ChatUnread.hasBadge(2), isTrue);
    });

    test('the listener reads one more document than it shows', () {
      expect(ChatUnread.queryLimit, ChatUnread.displayCap + 1);
    });

    test('opening a conversation marks seen and stops when it closes', () {
      final String controller = File('lib/controller/chat_controller.dart').readAsStringSync();
      expect(controller.contains('FireStoreUtils.setSeenChatForOrder('), isTrue);
      expect(controller.contains('FireStoreUtils.stopSeenChatForOrder()'), isTrue);
    });

    test('the badge label is translated in every language', () {
      for (final lang in [enUS, lnAr, deGR, trFR, hiIN, jaJP, ptPO, ruRU, zhCH]) {
        expect(lang['@count unread messages'], isNotNull);
        expect(lang['@count unread messages'], contains('@count'));
      }
    });
  });
}

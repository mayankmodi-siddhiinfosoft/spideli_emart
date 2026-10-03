import 'package:flutter_test/flutter_test.dart';
import 'package:spideliprovider/lang/app_ar.dart';
import 'package:spideliprovider/lang/app_en.dart';
import 'package:spideliprovider/services/booking_push.dart';
import 'package:spideliprovider/services/push_message.dart';

/// On-demand booking pushes sent by the provider (.claude/ONDEMAND-NOTIFICATIONS.md)
/// and where a tapped booking push leads (lib/services/booking_push.dart).
void main() {
  const BookingPushFacts base = BookingPushFacts(
    orderId: 'order-1',
    status: BookingStatus.accepted,
    serviceId: 'svc-1',
    serviceName: 'Deep cleaning',
    customerId: 'cust-1',
    customerToken: 'cust-token-copy',
    providerId: 'prov-1',
  );

  BookingPushFacts facts({String status = BookingStatus.accepted, String workerId = '', String previousWorkerId = '', String workerToken = ''}) {
    return BookingPushFacts(
      orderId: base.orderId,
      status: status,
      serviceId: base.serviceId,
      serviceName: base.serviceName,
      customerId: base.customerId,
      customerToken: base.customerToken,
      providerId: base.providerId,
      workerId: workerId,
      previousWorkerId: previousWorkerId,
      workerToken: workerToken,
    );
  }

  group('payload', () {
    test('carries the contract keys, all strings, no empty or null values', () {
      final Map<String, String> data = bookingPushData(BookingEvent.providerAccepted, facts(workerId: 'w-1'));
      expect(data, <String, String>{
        'type': 'provider_order',
        'event': 'provider_accepted',
        'orderId': 'order-1',
        'status': 'Order Accepted',
        'serviceId': 'svc-1',
        'serviceName': 'Deep cleaning',
        'customerId': 'cust-1',
        'providerId': 'prov-1',
        'workerId': 'w-1',
        'senderRole': 'provider',
      });
    });

    test('unknown parties are dropped, never sent as "" or "null"', () {
      final Map<String, String> data = bookingPushData(
        BookingEvent.serviceCompleted,
        const BookingPushFacts(orderId: 'o', status: BookingStatus.completed, serviceName: 'null', workerId: '  '),
      );
      expect(data.containsKey('workerId'), isFalse);
      expect(data.containsKey('serviceName'), isFalse);
      expect(data.containsKey('serviceId'), isFalse);
      expect(data.values.any((String v) => v.isEmpty || v == 'null'), isFalse);
    });

    test('stays a valid FCM data block after the sender stringifies it', () {
      final Map<String, String> data = buildPushData(bookingPushData(BookingEvent.stopTime, facts(status: BookingStatus.ongoing)), kind: 'stop_time');
      expect(data['type'], 'provider_order');
      expect(data['event'], 'stop_time');
    });
  });

  group('who is notified, once each', () {
    void expectSingleCustomerPush(ProviderBookingAction action, String event, String status) {
      final List<BookingPush> pushes = planProviderBookingPushes(action, facts(status: status));
      expect(pushes, hasLength(1), reason: action.name);
      final BookingPush push = pushes.single;
      expect(push.event, event);
      expect(push.template, event, reason: 'the Firestore template of the same name');
      expect(push.recipient, PushApp.customer);
      expect(push.recipientId, 'cust-1', reason: 'the current token is read from users/{authorID}');
      expect(push.fallbackToken, 'cust-token-copy');
      expect(push.data['event'], event);
      expect(push.data['status'], status);
    }

    test('accept -> customer, provider_accepted (3)', () {
      expectSingleCustomerPush(ProviderBookingAction.accept, 'provider_accepted', BookingStatus.accepted);
    });

    test('start -> customer, service_intransit (8)', () {
      expectSingleCustomerPush(ProviderBookingAction.start, 'service_intransit', BookingStatus.ongoing);
    });

    test('stop time -> customer, stop_time (9)', () {
      expectSingleCustomerPush(ProviderBookingAction.stopTime, 'stop_time', BookingStatus.ongoing);
    });

    test('extra charges -> customer, service_charges (10)', () {
      expectSingleCustomerPush(ProviderBookingAction.extraCharges, 'service_charges', BookingStatus.ongoing);
    });

    test('complete -> customer, service_completed (11)', () {
      expectSingleCustomerPush(ProviderBookingAction.complete, 'service_completed', BookingStatus.completed);
    });

    test('reject -> customer only when no worker is on the booking (4)', () {
      final List<BookingPush> pushes = planProviderBookingPushes(ProviderBookingAction.reject, facts(status: BookingStatus.rejected));
      expect(pushes.map((BookingPush p) => '${p.recipient.name}:${p.event}'), <String>['customer:provider_rejected']);
      expect(pushes.single.template, 'provider_rejected');
    });

    test('reject -> customer and the assigned worker (4)', () {
      final List<BookingPush> pushes = planProviderBookingPushes(ProviderBookingAction.reject, facts(status: BookingStatus.rejected, workerId: 'w-1'));
      expect(pushes.map((BookingPush p) => '${p.recipient.name}:${p.recipientId}:${p.event}'), <String>[
        'customer:cust-1:provider_rejected',
        'worker:w-1:provider_rejected',
      ]);
      // The template is worded for the customer: the worker gets app text.
      expect(pushes.last.template, isNull);
      expect(pushes.last.titleKey, BookingPushText.workerCancelledTitle);
    });

    test('assign to myself -> customer, provider_self_assigned (14)', () {
      final List<BookingPush> pushes = planProviderBookingPushes(ProviderBookingAction.assignSelf, facts(status: BookingStatus.assigned));
      expect(pushes, hasLength(1));
      expect(pushes.single.event, 'provider_self_assigned');
      expect(pushes.single.recipient, PushApp.customer);
      expect(pushes.single.template, isNull);
    });

    test('assign a worker -> worker (5) and customer (6)', () {
      final List<BookingPush> pushes =
          planProviderBookingPushes(ProviderBookingAction.assignWorker, facts(status: BookingStatus.assigned, workerId: 'w-1', workerToken: 'w-token'));
      expect(pushes.map((BookingPush p) => '${p.recipient.name}:${p.recipientId}:${p.event}'), <String>[
        'worker:w-1:worker_assigned',
        'customer:cust-1:worker_assigned_customer',
      ]);
      final BookingPush worker = pushes.first;
      expect(worker.template, 'worker_assigned');
      expect(worker.fallbackToken, 'w-token');
      expect(worker.data['workerId'], 'w-1');
      final BookingPush customer = pushes.last;
      expect(customer.template, isNull);
      expect(customer.bodyKey, 'A worker has been assigned to your booking');
    });

    test('reassign -> new worker (5), previous worker (7), customer (6)', () {
      final List<BookingPush> pushes =
          planProviderBookingPushes(ProviderBookingAction.assignWorker, facts(status: BookingStatus.assigned, workerId: 'w-2', previousWorkerId: 'w-1'));
      expect(pushes.map((BookingPush p) => '${p.recipient.name}:${p.recipientId}:${p.event}'), <String>[
        'worker:w-2:worker_assigned',
        'worker:w-1:worker_unassigned',
        'customer:cust-1:worker_assigned_customer',
      ]);
      final BookingPush previous = pushes[1];
      expect(previous.template, isNull);
      expect(previous.fallbackToken, isEmpty, reason: 'read fresh from providers_workers/{id}');
      expect(previous.bodyKey, 'This booking is no longer assigned to you');
      expect(previous.data['previousWorkerId'], 'w-1');
      expect(pushes.last.bodyKey, "Your booking's worker has changed");
    });

    test('picking the same worker again sends nothing', () {
      expect(planProviderBookingPushes(ProviderBookingAction.assignWorker, facts(status: BookingStatus.assigned, workerId: 'w-1', previousWorkerId: 'w-1')), isEmpty);
      expect(planProviderBookingPushes(ProviderBookingAction.assignWorker, facts(status: BookingStatus.assigned)), isEmpty);
    });

    test('every action sends at most one push per recipient', () {
      for (final ProviderBookingAction action in ProviderBookingAction.values) {
        final List<BookingPush> pushes = planProviderBookingPushes(action, facts(status: BookingStatus.assigned, workerId: 'w-2', previousWorkerId: 'w-1'));
        final List<String> recipients = pushes.map((BookingPush p) => '${p.recipient.name}:${p.recipientId}').toList();
        expect(recipients.toSet(), hasLength(recipients.length), reason: action.name);
        expect(pushes.every((BookingPush p) => p.data['senderRole'] == 'provider' && p.data['orderId'] == 'order-1'), isTrue, reason: action.name);
      }
    });

    test('no booking id, or no customer at all: nothing to the customer', () {
      expect(planProviderBookingPushes(ProviderBookingAction.accept, const BookingPushFacts(orderId: '', status: 'Order Accepted', customerId: 'c')), isEmpty);
      expect(planProviderBookingPushes(ProviderBookingAction.accept, const BookingPushFacts(orderId: 'o', status: 'Order Accepted', customerToken: 'null')), isEmpty);
      // Only the token copy: still sent, to the copy.
      final List<BookingPush> pushes = planProviderBookingPushes(ProviderBookingAction.accept, const BookingPushFacts(orderId: 'o', status: 'Order Accepted', customerToken: 'tok'));
      expect(pushes.single.recipientId, isEmpty);
      expect(pushes.single.fallbackToken, 'tok');
    });

    test('every title and body is translated in English and Arabic', () {
      for (final String key in BookingPushText.all) {
        expect(enUS[key], isNotNull, reason: 'app_en.dart: $key');
        expect(lnAr[key], isNotNull, reason: 'app_ar.dart: $key');
        expect(lnAr[key], isNot(key), reason: 'app_ar.dart is not English: $key');
      }
      for (final ProviderBookingAction action in ProviderBookingAction.values) {
        for (final BookingPush p in planProviderBookingPushes(action, facts(status: BookingStatus.assigned, workerId: 'w-2', previousWorkerId: 'w-1'))) {
          expect(BookingPushText.all, containsAll(<String>[p.titleKey, p.bodyKey]), reason: p.toString());
        }
      }
    });
  });

  group('deduper', () {
    test('a second identical push within the window is dropped, a later one is sent', () {
      DateTime now = DateTime(2026, 10, 3, 12);
      final BookingPushDeduper deduper = BookingPushDeduper(window: const Duration(seconds: 30), now: () => now);
      expect(deduper.claim('k'), isTrue);
      expect(deduper.claim('k'), isFalse);
      expect(deduper.claim('other'), isTrue);
      now = now.add(const Duration(seconds: 31));
      expect(deduper.claim('k'), isTrue);
    });

    test('a push to a different recipient or with another status is not a duplicate', () {
      final List<BookingPush> reassign =
          planProviderBookingPushes(ProviderBookingAction.assignWorker, facts(status: BookingStatus.assigned, workerId: 'w-2', previousWorkerId: 'w-1'));
      final Set<String> keys = reassign.map((BookingPush p) => p.dedupeKey).toSet();
      expect(keys, hasLength(reassign.length));
      final String accepted = planProviderBookingPushes(ProviderBookingAction.accept, facts()).single.dedupeKey;
      final String completed = planProviderBookingPushes(ProviderBookingAction.complete, facts(status: BookingStatus.completed)).single.dedupeKey;
      expect(accepted, isNot(completed));
    });

    test('release lets a failed send be retried', () {
      final BookingPushDeduper deduper = BookingPushDeduper();
      expect(deduper.claim('k'), isTrue);
      deduper.release('k');
      expect(deduper.claim('k'), isTrue);
    });
  });

  group('tap target', () {
    test('a booking push opens that booking', () {
      expect(providerTapTarget(<String, dynamic>{'type': 'provider_order', 'event': 'booking_placed', 'orderId': 'o1'}),
          const ProviderTapTarget(ProviderTapKind.bookingDetails, 'o1'));
    });

    test('contract events used as the type, or as the event without a type, open the booking', () {
      for (final String event in <String>['booking_placed', 'booking_cancelled_by_customer', 'worker_accepted', 'worker_rejected']) {
        expect(providerTapTarget(<String, dynamic>{'type': event, 'orderId': 'o2'}), const ProviderTapTarget(ProviderTapKind.bookingDetails, 'o2'), reason: event);
        expect(providerTapTarget(<String, dynamic>{'event': event, 'orderId': 'o2'}), const ProviderTapTarget(ProviderTapKind.bookingDetails, 'o2'), reason: event);
      }
    });

    test('a missing or invalid order id opens the bookings list', () {
      const ProviderTapTarget list = ProviderTapTarget(ProviderTapKind.bookingList);
      expect(providerTapTarget(<String, dynamic>{'type': 'provider_order'}), list);
      expect(providerTapTarget(<String, dynamic>{'type': 'provider_order', 'orderId': ''}), list);
      expect(providerTapTarget(<String, dynamic>{'type': 'provider_order', 'orderId': 'null'}), list);
      expect(providerTapTarget(<String, dynamic>{'type': 'provider_order', 'orderId': 'a/b'}), list);
      expect(providerTapTarget(<String, dynamic>{'type': 'worker_rejected', 'orderId': null}), list);
    });

    test('non-string values from a decoded local payload do not throw', () {
      expect(providerTapTarget(<dynamic, dynamic>{'type': 'provider_order', 'orderId': 12345}), const ProviderTapTarget(ProviderTapKind.bookingDetails, '12345'));
      expect(providerTapTarget(decodeTapPayload('{"type":"provider_order","orderId":"o9"}')), const ProviderTapTarget(ProviderTapKind.bookingDetails, 'o9'));
      expect(providerTapTarget(decodeTapPayload('not json')), const ProviderTapTarget(ProviderTapKind.none));
      expect(providerTapTarget(null), const ProviderTapTarget(ProviderTapKind.none));
    });

    test('chat and support pushes keep their routes', () {
      expect(providerTapTarget(<String, dynamic>{'type': 'orderChat', 'orderId': 'o', 'senderId': 's'}), const ProviderTapTarget(ProviderTapKind.orderChat, 'o'));
      expect(providerTapTarget(<String, dynamic>{'type': 'orderChat', 'orderId': 'o'}), const ProviderTapTarget(ProviderTapKind.none));
      expect(providerTapTarget(<String, dynamic>{'type': 'provider_chat', 'orderId': 'o'}), const ProviderTapTarget(ProviderTapKind.providerChat, 'o'));
      expect(providerTapTarget(<String, dynamic>{'type': 'admin_chat'}), const ProviderTapTarget(ProviderTapKind.adminChat));
      expect(providerTapTarget(<String, dynamic>{'type': 'something_else', 'orderId': 'o'}), const ProviderTapTarget(ProviderTapKind.none));
    });

    test('isOpenableOrderId', () {
      expect(isOpenableOrderId('abc'), isTrue);
      expect(isOpenableOrderId(' '), isFalse);
      expect(isOpenableOrderId('x/y'), isFalse);
      expect(isOpenableOrderId('..'), isFalse);
    });
  });
}

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/models/order_model.dart';
import 'package:customer/models/order_pod.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/widget/delivery_code_card.dart';
import 'package:customer/widget/pod_info_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// POD-OTP-CONTRACT, customer half: the delivery code card on the order
/// screens (pending → digits + countdown; expired → ask for a new one;
/// verified → gone), the verified proof-of-delivery block, and `pod` riding
/// through OrderModel untouched.
void main() {
  final DateTime t0 = DateTime(2026, 10, 3, 14, 0, 0);
  late DateTime clock;

  OrderPodCode code({String status = 'pending', String digits = '482913', Duration ttl = const Duration(minutes: 10), bool serverTime = true}) => OrderPodCode.fromJson({
    'orderId': 'order-1',
    'customerId': 'cust-1',
    'driverId': 'drv-1',
    'vendorId': 'ven-1',
    'code': digits,
    'status': status,
    if (serverTime) 'generatedAt': Timestamp.fromDate(t0),
    'expiresAt': Timestamp.fromDate(t0.add(ttl)),
    'attempts': 0,
    'regenerations': 1,
  });

  Widget host(Widget child) => GetMaterialApp(
    theme: DsTheme.light(),
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
  );

  Widget card(OrderPodCode? c) => DeliveryCodeCard(code: c, now: () => clock);

  setUp(() => clock = t0);

  testWidgets('pending code shows the 6 digits, the warning and a live countdown', (tester) async {
    await tester.pumpWidget(host(card(code())));
    expect(find.text('Your delivery code'), findsOneWidget);
    for (final d in '482913'.split('')) {
      expect(find.text(d), findsOneWidget);
    }
    expect(find.text('Share this code with your delivery partner only when you receive your order'), findsOneWidget);
    expect(find.text('Expires in 10:00'), findsOneWidget);

    clock = t0.add(const Duration(minutes: 1, seconds: 15));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Expires in 08:45'), findsOneWidget);
  });

  testWidgets('a new code replaces the old one immediately', (tester) async {
    await tester.pumpWidget(host(card(code(digits: '111111'))));
    expect(find.text('1'), findsNWidgets(6));
    await tester.pumpWidget(host(card(code(digits: '765432'))));
    expect(find.text('1'), findsNothing);
    for (final d in '765432'.split('')) {
      expect(find.text(d), findsOneWidget);
    }
  });

  testWidgets('a pending code past its 10 minutes turns into "Code expired" (after the skew grace)', (tester) async {
    await tester.pumpWidget(host(card(code())));
    expect(find.text('4'), findsOneWidget);

    // 10 minutes on: the countdown reads 00:00 but the digits stay for the
    // 30-second clock-skew grace (the checking phone may be a little behind).
    clock = t0.add(const Duration(minutes: 10, seconds: 20));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Expires in 00:00'), findsOneWidget);

    clock = t0.add(const Duration(minutes: 10, seconds: 31));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('4'), findsNothing);
    expect(find.text('Code expired — ask your delivery partner for a new one'), findsOneWidget);
  });

  testWidgets('without the server time yet, expiresAt is used', (tester) async {
    await tester.pumpWidget(host(card(code(ttl: const Duration(seconds: 2), serverTime: false))));
    expect(find.text('4'), findsOneWidget);

    clock = t0.add(const Duration(seconds: 33));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('4'), findsNothing);
    expect(find.text('Code expired — ask your delivery partner for a new one'), findsOneWidget);
  });

  group('clock skew', () {
    test('the countdown follows the server generatedAt, not the generating phone', () {
      // Driver phone 5 minutes fast: expiresAt says t0+15m.
      final fast = code(ttl: const Duration(minutes: 15));
      expect(fast.remaining(t0), const Duration(minutes: 10));
      expect(fast.isLive(t0.add(const Duration(minutes: 11))), isFalse);
      // Driver phone 5 minutes slow: expiresAt says t0+5m.
      final slow = code(ttl: const Duration(minutes: 5));
      expect(slow.isLive(t0.add(const Duration(minutes: 6))), isTrue);
      expect(slow.remaining(t0.add(const Duration(minutes: 6))), const Duration(minutes: 4));
    });

    test('a customer phone running behind never shows more than 10 minutes', () {
      expect(code().remaining(t0.subtract(const Duration(minutes: 3))), const Duration(minutes: 10));
    });
  });

  testWidgets('status expired (too many attempts) shows the expired message', (tester) async {
    await tester.pumpWidget(host(card(code(status: 'expired'))));
    expect(find.text('Code expired — ask your delivery partner for a new one'), findsOneWidget);
    expect(find.textContaining('Expires in'), findsNothing);
  });

  testWidgets('verified (or no code) hides the card', (tester) async {
    await tester.pumpWidget(host(card(code(status: 'verified'))));
    expect(find.text('Your delivery code'), findsNothing);
    expect(find.text('4'), findsNothing);

    await tester.pumpWidget(host(card(null)));
    expect(find.text('Your delivery code'), findsNothing);
  });

  test('a code is only shown for this customer\'s own order', () {
    final c = code();
    expect(c.belongsTo(orderId: 'order-1', uid: 'cust-1'), isTrue);
    expect(c.belongsTo(orderId: 'order-1', uid: 'someone-else'), isFalse);
    expect(c.belongsTo(orderId: 'order-2', uid: 'cust-1'), isFalse);

    OrderModel order({String status = Constant.orderInTransit, bool takeAway = false, Map<String, dynamic>? pod}) =>
        OrderModel(id: 'order-1', authorID: 'cust-1', status: status, takeAway: takeAway, pod: OrderPod.tryParse(pod));
    expect(DeliveryCodeWatcher.shouldWatch(order(), 'cust-1'), isTrue);
    expect(DeliveryCodeWatcher.shouldWatch(order(), 'someone-else'), isFalse);
    expect(DeliveryCodeWatcher.shouldWatch(order(), null), isFalse);
    // 5 Oct 2026: the store asks for the code on a takeaway too.
    expect(DeliveryCodeWatcher.shouldWatch(order(takeAway: true), 'cust-1'), isTrue);
    expect(DeliveryCodeWatcher.shouldWatch(order(takeAway: true, status: Constant.orderAccepted), 'cust-1'), isTrue);
    expect(DeliveryCodeWatcher.shouldWatch(order(takeAway: true), 'someone-else'), isFalse);
    expect(DeliveryCodeWatcher.shouldWatch(order(takeAway: true, status: Constant.orderCompleted), 'cust-1'), isFalse);
    expect(DeliveryCodeWatcher.shouldWatch(order(takeAway: true, status: Constant.orderCancelled), 'cust-1'), isFalse);
    expect(DeliveryCodeWatcher.shouldWatch(order(takeAway: true, status: Constant.orderRejected), 'cust-1'), isFalse);
    expect(DeliveryCodeWatcher.shouldWatch(order(takeAway: true, pod: {'method': 'otp', 'status': 'verified'}), 'cust-1'), isFalse);
    expect(DeliveryCodeWatcher.shouldWatch(order(status: Constant.orderCompleted), 'cust-1'), isFalse);
    expect(DeliveryCodeWatcher.shouldWatch(order(status: Constant.orderCancelled), 'cust-1'), isFalse);
    expect(DeliveryCodeWatcher.shouldWatch(order(pod: {'method': 'otp', 'status': 'verified'}), 'cust-1'), isFalse);
    expect(DeliveryCodeWatcher.shouldWatch(order(pod: {'method': 'otp', 'status': 'pending'}), 'cust-1'), isTrue);
  });

  group('takeaway: the pickup code', () {
    Widget pickup(OrderPodCode? c) => DeliveryCodeCard(code: c, takeAway: true, now: () => clock);

    testWidgets('a live code reads "Your pickup code" and says to share it with the store', (tester) async {
      await tester.pumpWidget(host(pickup(code())));
      expect(find.text('Your pickup code'), findsOneWidget);
      expect(find.text('Your delivery code'), findsNothing);
      for (final d in '482913'.split('')) {
        expect(find.text(d), findsOneWidget);
      }
      expect(find.text('Share this code with the store only when you collect your order'), findsOneWidget);
      expect(find.text('Expires in 10:00'), findsOneWidget);
    });

    testWidgets('an expired code says to ask the store', (tester) async {
      await tester.pumpWidget(host(pickup(code(status: 'expired'))));
      expect(find.text('Code expired — ask the store for a new one'), findsOneWidget);
      expect(find.textContaining('delivery partner'), findsNothing);
    });

    testWidgets('verified hides it, as for a delivery', (tester) async {
      await tester.pumpWidget(host(pickup(code(status: 'verified'))));
      expect(find.text('Your pickup code'), findsNothing);
    });

    final storeVerified = OrderPod.tryParse({
      'method': 'otp',
      'status': 'verified',
      'verifiedAt': Timestamp.fromDate(DateTime(2026, 10, 5, 12, 30)),
      'verifiedBy': 'store-uid',
      'verifiedByRole': 'vendor',
    });

    testWidgets('block: Proof of pickup, Picked up, Verified by the store, no delivery man', (tester) async {
      await tester.pumpWidget(host(PodInfoBlock(pod: storeVerified, takeAway: true)));
      expect(find.text('Proof of pickup'), findsOneWidget);
      expect(find.text('Picked up'), findsOneWidget);
      expect(find.text('Delivered'), findsNothing);
      expect(find.text('OTP Verified'), findsOneWidget);
      expect(find.text('Verified by the store'), findsOneWidget);
      expect(find.text('Delivery man'), findsNothing);
      expect(find.textContaining('null'), findsNothing);
    });

    testWidgets('history line', (tester) async {
      await tester.pumpWidget(host(PodInfoLine(pod: storeVerified, takeAway: true)));
      expect(find.text('Picked up · OTP Verified · Verified by the store · 05 Oct 2026, 12:30 PM'), findsOneWidget);
    });
  });

  group('proof of delivery once verified', () {
    final verifiedPod = OrderPod.tryParse({
      'method': 'otp',
      'status': 'verified',
      'requestedAt': Timestamp.fromDate(t0),
      'expiresAt': Timestamp.fromDate(t0.add(const Duration(minutes: 10))),
      'verifiedAt': Timestamp.fromDate(DateTime(2026, 10, 3, 14, 4)),
      'verifiedBy': 'drv-1',
      'verifiedByRole': 'driver',
      'deliveredBy': {'id': 'drv-1', 'name': 'Ravi Kumar', 'phone': '+91 98765 43210', 'photo': ''},
    });

    testWidgets('block: Delivered, OTP Verified, time, delivery man', (tester) async {
      await tester.pumpWidget(host(PodInfoBlock(pod: verifiedPod)));
      expect(find.text('Delivered'), findsOneWidget);
      expect(find.text('OTP Verified'), findsOneWidget);
      expect(find.text('03 Oct 2026, 02:04 PM'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
    });

    testWidgets('history line', (tester) async {
      await tester.pumpWidget(host(PodInfoLine(pod: verifiedPod)));
      expect(find.text('Delivered · OTP Verified · 03 Oct 2026, 02:04 PM · Ravi Kumar'), findsOneWidget);
    });

    testWidgets('older orders and pending pods show nothing', (tester) async {
      await tester.pumpWidget(host(const Column(children: [PodInfoBlock(pod: null), PodInfoLine(pod: null)])));
      expect(find.byType(Text), findsNothing);
      await tester.pumpWidget(host(PodInfoBlock(pod: OrderPod.tryParse({'method': 'otp', 'status': 'pending'}))));
      expect(find.byType(Text), findsNothing);
      // Verified but missing optional fields: no "null" anywhere.
      await tester.pumpWidget(host(PodInfoBlock(pod: OrderPod.tryParse({'method': 'otp', 'status': 'verified'}))));
      expect(find.text('OTP Verified'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
    });

    test('OrderModel reads pod but never writes it back (no save can roll it back)', () {
      final Map<String, dynamic> raw = {'id': 'order-1', 'deliveryCharge': '0', 'tip_amount': '0', 'pod': verifiedPod!.toJson()..['extra'] = 'kept'};
      final OrderModel read = OrderModel.fromJson(raw);
      expect(read.pod!.isVerified, isTrue);
      expect(read.pod!.toJson()['extra'], 'kept');
      expect(read.toJson().containsKey('pod'), isFalse);

      final pending = OrderModel.fromJson({'id': 'order-3', 'deliveryCharge': '0', 'tip_amount': '0', 'pod': {'method': 'otp', 'status': 'pending'}});
      expect(pending.toJson().containsKey('pod'), isFalse, reason: 'a stale pending copy must never overwrite a verified pod');

      final older = OrderModel.fromJson({'id': 'order-2', 'deliveryCharge': '0', 'tip_amount': '0'});
      expect(older.pod, isNull);
      expect(older.toJson().containsKey('pod'), isFalse);
    });
  });
}

import 'package:customer/utils/delivery_code_push.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `delivery_otp` push tapped while the app was closed: the order is held
/// until the customer reaches the home (ServiceListController.onReady calls
/// markAppReady), so a customer the splash first sends to set an address or to
/// sign in still gets the order opened afterwards, exactly once.
void main() {
  late List<String> opened;

  setUp(() {
    DeliveryCodePush.resetForTest();
    opened = [];
    DeliveryCodePush.opener = (orderId) async => opened.add(orderId);
  });

  tearDown(DeliveryCodePush.resetForTest);

  test('a cold-start tap waits for the home, then opens its order once', () async {
    await DeliveryCodePush.handleTap({'type': DeliveryCodePush.type, 'orderId': 'order-1'}, coldStart: true);
    expect(opened, isEmpty);
    expect(DeliveryCodePush.pendingOrderId, 'order-1');

    // The splash sent the customer to the location screen: nothing opens
    // until the home is reached, however long that takes.
    await Future<void>.delayed(Duration.zero);
    expect(opened, isEmpty);

    DeliveryCodePush.markAppReady();
    await Future<void>.delayed(Duration.zero);
    expect(opened, ['order-1']);
    expect(DeliveryCodePush.pendingOrderId, isNull);

    // Coming back to the home later opens nothing again.
    DeliveryCodePush.markAppReady();
    await Future<void>.delayed(Duration.zero);
    expect(opened, ['order-1']);
  });

  test('once the home was reached, a tap opens its order right away', () async {
    DeliveryCodePush.markAppReady();
    await DeliveryCodePush.handleTap({'type': DeliveryCodePush.type, 'orderId': 'order-2'}, coldStart: true);
    expect(opened, ['order-2']);
    expect(DeliveryCodePush.pendingOrderId, isNull);
  });

  test('a tap while the app is running opens its order right away', () async {
    await DeliveryCodePush.handleTap({'type': DeliveryCodePush.type, 'orderId': 'order-3'});
    expect(opened, ['order-3']);
  });

  test('the latest cold-start tap wins', () async {
    await DeliveryCodePush.handleTap({'orderId': 'order-a'}, coldStart: true);
    await DeliveryCodePush.handleTap({'order_id': 'order-b'}, coldStart: true);
    DeliveryCodePush.markAppReady();
    await Future<void>.delayed(Duration.zero);
    expect(opened, ['order-b']);
  });

  test('a payload without an order id holds nothing', () async {
    await DeliveryCodePush.handleTap({'type': DeliveryCodePush.type}, coldStart: true);
    await DeliveryCodePush.handleTap({'orderId': 'null'}, coldStart: true);
    expect(DeliveryCodePush.pendingOrderId, isNull);
    DeliveryCodePush.markAppReady();
    await Future<void>.delayed(Duration.zero);
    expect(opened, isEmpty);
  });
}

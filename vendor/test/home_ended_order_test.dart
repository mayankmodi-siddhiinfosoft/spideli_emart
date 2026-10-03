import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/home_controller.dart';
import 'package:vendor/models/order_model.dart';

/// Store home screen: an order the store cancels or rejects must show in the
/// Cancelled / Rejected tab at once, not only after every follow-up step.
void main() {
  setUp(() => Get.testMode = true);

  test('a cancelled order leaves its tab and shows in Cancelled at once', () {
    final HomeController controller = HomeController();
    final OrderModel order = OrderModel(id: 'o1', status: Constant.orderAccepted);
    controller.allOrderList.add(order);
    controller.showEndedOrder(order);
    expect(controller.cancelledOrderList, isEmpty);

    order.status = Constant.orderCancelled;
    controller.showEndedOrder(order);
    expect(controller.cancelledOrderList.map((o) => o.id), ['o1']);
    expect(controller.preparingOrderList.where((o) => o.id == 'o1'), isEmpty);
    expect(controller.allOrderList.length, 1);
  });

  test('a rejected new order shows in Rejected at once, even before the list had it', () {
    final HomeController controller = HomeController();
    final OrderModel order = OrderModel(id: 'o2', status: Constant.orderRejected);
    controller.showEndedOrder(order);
    expect(controller.rejectedOrderList.map((o) => o.id), ['o2']);
    expect(controller.newOrderList, isEmpty);
  });
}

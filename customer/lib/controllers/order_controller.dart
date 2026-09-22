import 'package:customer/constant/constant.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/order_model.dart';
import '../service/cart_provider.dart';
import '../service/fire_store_utils.dart';
import 'package:get/get.dart';
import '../utils/order_history_limit.dart';
import '../utils/wholesale_pricing.dart';
import 'package:customer/models/vendor_model.dart';

class OrderController extends GetxController {
  RxList<OrderModel> allList = <OrderModel>[].obs;
  RxList<OrderModel> inProgressList = <OrderModel>[].obs;
  RxList<OrderModel> deliveredList = <OrderModel>[].obs;
  RxList<OrderModel> rejectedList = <OrderModel>[].obs;
  RxList<OrderModel> cancelledList = <OrderModel>[].obs;

  RxBool isLoading = true.obs;

  /// Orders hidden by the free order-history limit (spec 18.9); 0 = none.
  RxInt hiddenOrderCount = 0.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getOrder();
    super.onInit();
  }

  Future<void> getOrder() async {
    if (Constant.userModel != null) {
      // The free limit applies HERE, in the customer's own history screen,
      // never in FireStoreUtils (the store app / panels must see everything).
      final int? limit = await OrderHistoryLimit.visibleCount();
      await FireStoreUtils.getAllOrder().then((value) {
        // The limit is on order HISTORY. Orders still being placed, prepared
        // or delivered are always shown, however old, so a customer can
        // always track and act on them.
        const activeStatuses = {
          Constant.orderPlaced,
          Constant.orderAccepted,
          Constant.driverPending,
          Constant.driverAccepted,
          Constant.orderShipped,
          Constant.orderInTransit,
        };
        final active = value.where((o) => activeStatuses.contains(o.status)).toList();
        final finished = value.where((o) => !activeStatuses.contains(o.status)).toList();
        final visibleFinished = OrderHistoryLimit.newest(finished, limit, (OrderModel o) => o.createdAt);
        hiddenOrderCount.value = finished.length - visibleFinished.length;
        allList.value = [...active, ...visibleFinished]
          ..sort((a, b) => (b.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(a.createdAt?.millisecondsSinceEpoch ?? 0));

        rejectedList.value = visibleFinished.where((p0) => p0.status == Constant.orderRejected).toList();
        inProgressList.value =
            active
                .where(
                  (p0) => p0.status == Constant.orderAccepted || p0.status == Constant.driverPending || p0.status == Constant.orderShipped || p0.status == Constant.orderInTransit,
                )
                .toList();

        deliveredList.value = visibleFinished.where((p0) => p0.status == Constant.orderCompleted).toList();
        cancelledList.value = visibleFinished.where((p0) => p0.status == Constant.orderCancelled).toList();
      });
    }

    isLoading.value = false;
  }

  final CartProvider cartProvider = CartProvider();

  /// Reorder: the past order line carries the price that was charged (maybe
  /// wholesale), so retail prices and tiers are refreshed from the product.
  Future<void> addToCart({required CartProductModel cartProductModel, VendorModel? vendor}) async {
    final CartProductModel line = await WholesalePricing.reorderLine(cartProductModel, vendor: vendor);
    await cartProvider.addToCart(Get.context!, line, line.quantity!);
    update();
  }
}

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
        final visible = OrderHistoryLimit.newest(value, limit, (OrderModel o) => o.createdAt);
        hiddenOrderCount.value = value.length - visible.length;
        allList.value = visible;

        rejectedList.value = allList.where((p0) => p0.status == Constant.orderRejected).toList();
        inProgressList.value =
            allList
                .where(
                  (p0) => p0.status == Constant.orderAccepted || p0.status == Constant.driverPending || p0.status == Constant.orderShipped || p0.status == Constant.orderInTransit,
                )
                .toList();

        deliveredList.value = allList.where((p0) => p0.status == Constant.orderCompleted).toList();
        cancelledList.value = allList.where((p0) => p0.status == Constant.orderCancelled).toList();
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

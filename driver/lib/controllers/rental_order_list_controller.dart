import 'dart:async';
import 'package:get/get.dart';
import '../models/rental_order_model.dart';
import '../utils/fire_store_utils.dart';

class RentalOrderListController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<RentalOrderModel> rentalOrders = <RentalOrderModel>[].obs;

  RxString selectedTab = "On Going".obs;
  RxList<String> tabTitles = ["On Going", "Completed", "Cancelled"].obs;

  StreamSubscription<List<RentalOrderModel>>? _rentalSubscription;
  final RxString selectedPaymentMethod = ''.obs;

  RxString driverId = ''.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    driverId.value = args?['driverId'] ?? FireStoreUtils.getCurrentUid();
    listenRentalOrders();
  }

  void selectTab(String tab) {
    selectedTab.value = tab;
  }

  /// Start listening to rental orders live. Cancel previous subscription first.
  void listenRentalOrders() {
    isLoading.value = true;
    _rentalSubscription?.cancel();

    _rentalSubscription = FireStoreUtils.getRentalOrders(driverId.value).listen(
      (orders) {
        rentalOrders.assignAll(orders);
        isLoading.value = false;
      },
      onError: (err) {
        isLoading.value = false;
        print("Error fetching rental orders: $err");
      },
    );
  }

  /// Return filtered list for a specific tab title
  List<RentalOrderModel> getOrdersForTab(String tab) {
    switch (tab) {
      case "On Going":
        return rentalOrders
            .where(
              (order) => [
                "Order Placed",
                "Order Accepted",
                "Driver Accepted",
                "Driver Pending",
                "Order Shipped",
                "In Transit",
              ].contains(order.status),
            )
            .toList();

      case "Completed":
        return rentalOrders.where((order) => ["Order Completed"].contains(order.status)).toList();

      case "Cancelled":
        return rentalOrders.where((order) => ["Order Rejected", "Order Cancelled", "Driver Rejected"].contains(order.status)).toList();

      default:
        return [];
    }
  }

  @override
  void onClose() {
    _rentalSubscription?.cancel();
    super.onClose();
  }
}

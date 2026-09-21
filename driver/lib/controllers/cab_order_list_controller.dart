import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/cab_order_model.dart';
import '../utils/fire_store_utils.dart';

class CabOrderListController extends GetxController {
  RxBool isLoading = true.obs;
  RxString selectedTab = "On Going".obs;
  RxList<CabOrderModel> cabOrder = <CabOrderModel>[].obs;

  RxList<String> tabTitles = ["On Going", "Completed", "Cancelled"].obs;

  RxString driverId = ''.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    driverId.value = args?['driverId'] ?? FireStoreUtils.getCurrentUid();
    fetchCabOrders();
  }

  void selectTab(String tab) {
    selectedTab.value = tab;
    fetchCabOrders();
  }

  void fetchCabOrders() {
    isLoading.value = true;

    FireStoreUtils.getCabDriverOrders(driverId.value).listen((orders) {
      print("cabOrder length ::::::${cabOrder.length}");
      cabOrder.value = orders;
      isLoading.value = false;
    });
  }

  /// Return filtered list for a specific tab title
  List<CabOrderModel> getOrdersForTab(String tab) {
    switch (tab) {
      case "On Going":
        return cabOrder.where((order) => ["Order Placed", "Order Accepted", "Driver Accepted", "Driver Pending", "Order Shipped", "In Transit"].contains(order.status)).toList();

      case "Completed":
        return cabOrder.where((order) => ["Order Completed"].contains(order.status)).toList();

      case "Cancelled":
        return cabOrder.where((order) => ["Order Rejected", "Order Cancelled", "Driver Rejected"].contains(order.status)).toList();

      default:
        return [];
    }
  }

  String formatDate(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return DateFormat("dd MMM yyyy, hh:mm a").format(dateTime);
  }
}

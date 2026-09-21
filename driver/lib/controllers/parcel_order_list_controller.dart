import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/parcel_order_model.dart';
import '../utils/fire_store_utils.dart'; // adjust path if needed

class ParcelOrderListController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<ParcelOrderModel> parcelOrder = <ParcelOrderModel>[].obs;

  RxString selectedTab = "In Transit".obs;
  RxList<String> tabTitles = ["In Transit", "Delivered", "Cancelled"].obs;

  StreamSubscription<List<ParcelOrderModel>>? _parcelSubscription;

  RxString driverId = ''.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    driverId.value = args?['driverId'] ?? FireStoreUtils.getCurrentUid();
    listenParcelOrders();
  }

  /// only update the selectedTab (do NOT re-subscribe)
  void selectTab(String tab) {
    selectedTab.value = tab;
  }

  /// Start listening to orders live. Cancel previous subscription to avoid leaks.
  void listenParcelOrders() {
    isLoading.value = true;
    _parcelSubscription?.cancel();
    _parcelSubscription = FireStoreUtils.listenParcelOrders(driverId.value).listen(
      (orders) {
        parcelOrder.assignAll(orders);
        isLoading.value = false;
      },
      onError: (err) {
        isLoading.value = false;
        // optional: handle the error or show toast/log
      },
    );
  }

  /// Return filtered list for a specific tab title
  List<ParcelOrderModel> getOrdersForTab(String tab) {
    switch (tab) {
      case "In Transit":
        return parcelOrder.where((order) => ["Order Placed", "Order Accepted", "Driver Accepted", "Driver Pending", "Order Shipped", "In Transit"].contains(order.status)).toList();

      case "Delivered":
        return parcelOrder.where((order) => ["Order Completed"].contains(order.status)).toList();

      case "Cancelled":
        return parcelOrder.where((order) => ["Order Rejected", "Order Cancelled", "Driver Rejected"].contains(order.status)).toList();

      default:
        return [];
    }
  }

  String formatDate(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return DateFormat("dd MMM yyyy, hh:mm a").format(dateTime);
  }

  @override
  void onClose() {
    _parcelSubscription?.cancel();
    super.onClose();
  }
}

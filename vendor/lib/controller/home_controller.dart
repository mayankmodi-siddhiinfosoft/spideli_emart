import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/order_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/service/audio_player_service.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/region_service.dart';

class HomeController extends GetxController {
  RxBool isLoading = true.obs;

  Rx<TextEditingController> estimatedTimeController = TextEditingController().obs;
  Rx<TextEditingController> courierCompanyName = TextEditingController().obs;
  Rx<TextEditingController> courierCompanyTrackingId = TextEditingController().obs;

  RxInt selectedTabIndex = 0.obs;

  /// The live `vendor_orders` listener. New orders reach the store from this
  /// listener, not from the push, so an order placed or assigned without a
  /// push still appears and still rings (report 02#12).
  ///
  /// Static on purpose: the home tab's controller is disposed when the vendor
  /// opens another tab, and the listener must keep ringing meanwhile (as it
  /// always did). Each [getOrder] replaces the previous listener instead of
  /// stacking another one - they used to accumulate per visit to the home
  /// tab, and the previous store's kept ringing after switching stores.
  static StreamSubscription? _orderSubscription;

  /// True while the last snapshot had an order waiting for the store.
  static bool _ordersWaiting = false;

  /// Brought back to the foreground with an order still waiting: ring again
  /// (the OS may have stopped the in-app player while it was in the
  /// background) without waiting for the next Firestore change.
  static AppLifecycleListener? _lifecycle;

  /// Stops the order listener and the alert, e.g. on sign-out.
  static Future<void> stopOrderAlerts() async {
    await _orderSubscription?.cancel();
    _orderSubscription = null;
    _ordersWaiting = false;
    await AudioPlayerService.playSound(false);
  }

  @override
  void onInit() {
    getUserProfile();
    _lifecycle ??= AppLifecycleListener(
      onResume: () {
        if (_ordersWaiting) AudioPlayerService.playSound(true);
      },
    );
    super.onInit();
  }

  RxList<OrderModel> allOrderList = <OrderModel>[].obs;
  RxList<OrderModel> newOrderList = <OrderModel>[].obs;
  /// "Preparing": accepted by the store, waiting for / assigned to a driver.
  RxList<OrderModel> preparingOrderList = <OrderModel>[].obs;

  /// "Ready": handed over and on its way.
  RxList<OrderModel> readyOrderList = <OrderModel>[].obs;
  RxList<OrderModel> completedOrderList = <OrderModel>[].obs;
  RxList<OrderModel> rejectedOrderList = <OrderModel>[].obs;
  RxList<OrderModel> cancelledOrderList = <OrderModel>[].obs;

  static const List<String> preparingStatuses = [Constant.orderAccepted, Constant.driverPending, Constant.driverRejected, Constant.driverAccepted];
  static const List<String> readyStatuses = [Constant.orderShipped, Constant.orderInTransit];

  Rx<UserModel> userModel = UserModel().obs;
  Rx<VendorModel> vendermodel = VendorModel().obs;

  Future<void> getUserProfile() async {
    await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) async {
      if (value != null) {
        userModel.value = value;
        Constant.userModel = userModel.value;
        if (userModel.value.employeePermissionId != null) {
          Constant.employeeRoleModel = await FireStoreUtils.getEmployeeRoleById(userModel.value.employeePermissionId!);
        }
      }
    });
    if (userModel.value.vendorID != null && userModel.value.vendorID!.isNotEmpty) {
      await FireStoreUtils.getVendorById(userModel.value.vendorID!).then((vender) {
        if (vender?.id != null) {
          vendermodel.value = vender!;
        }
      });
    }
    // Regions/currencies must be cached before order cards render, so each
    // order can show the currency it was charged in.
    await RegionService.applyStore(vendermodel.value.id != null ? vendermodel.value : null);
    await getOrder();

    isLoading.value = false;
  }

  RxList<UserModel> driverUserList = <UserModel>[].obs;
  Rx<UserModel> selectDriverUser = UserModel().obs;

  /// How many delivery men the store has at all, available or not. Lets the
  /// assign dialog say *why* the list is empty instead of only "no driver
  /// found" (report #9).
  RxInt storeDriverCount = 0.obs;

  Future<void> getAllDriverList() async {
    final List<UserModel> all = await FireStoreUtils.getStoreDrivers();
    storeDriverCount.value = all.length;
    // Assigned unconditionally: the old code only wrote the list when it came
    // back non-empty, so one failed load left a stale (or empty) list behind
    // with nothing to explain it.
    driverUserList.value = all.where((driver) => driver.isActive == true && driver.active == true).toList();
    // A selection left over from a previous order must not be reused.
    selectDriverUser.value = UserModel();
    isLoading.value = false;
  }

  /// Shows an order the store has just cancelled or rejected in its tab
  /// straight away, without waiting for the order listener (which then
  /// confirms it with the stored record).
  void showEndedOrder(OrderModel order) {
    final String? id = order.id;
    if (id == null) return;
    final int index = allOrderList.indexWhere((o) => o.id == id);
    if (index >= 0) {
      // The listener may already have delivered the stored record (server
      // timestamps, fields others wrote meanwhile): only a list entry that
      // has not caught up with the new status is replaced.
      if (allOrderList[index].status != order.status) allOrderList[index] = order;
    } else {
      allOrderList.insert(0, order);
    }
    _splitIntoTabs();
  }

  void _splitIntoTabs() {
    // Tabs (spec: New | Preparing | Ready | Completed, then Rejected and
    // Cancelled), mapped onto the existing statuses.
    newOrderList.value = allOrderList.where((p0) => p0.status == Constant.orderPlaced).toList();
    preparingOrderList.value = allOrderList.where((p0) => preparingStatuses.contains(p0.status)).toList();
    readyOrderList.value = allOrderList.where((p0) => readyStatuses.contains(p0.status)).toList();
    completedOrderList.value = allOrderList.where((p0) => p0.status == Constant.orderCompleted).toList();
    rejectedOrderList.value = allOrderList.where((p0) => p0.status == Constant.orderRejected).toList();
    cancelledOrderList.value = allOrderList.where((p0) => p0.status == Constant.orderCancelled).toList();
    update();
  }

  Future<void> getOrder() async {
    await _orderSubscription?.cancel();
    _orderSubscription = FireStoreUtils.fireStore.collection(CollectionName.vendorOrders).where('vendorID', isEqualTo: Constant.userModel!.vendorID).orderBy('createdAt', descending: true).snapshots().listen((
      event,
    ) async {
      allOrderList.clear();
      for (var element in event.docs) {
        // One unreadable order used to throw out of the whole listener, so
        // the lists stopped updating and a new order never rang.
        try {
          allOrderList.add(OrderModel.fromJson(element.data()));
        } catch (e) {
          log("Skipping unreadable order ${element.id}: $e");
        }
      }
      _splitIntoTabs();
      _ordersWaiting = newOrderList.isNotEmpty;
      if (newOrderList.isNotEmpty == true) {
        await AudioPlayerService.playSound(true);
      }
      if (newOrderList.isEmpty == true) {
        await AudioPlayerService.playSound(false);
      }
    });
  }
}

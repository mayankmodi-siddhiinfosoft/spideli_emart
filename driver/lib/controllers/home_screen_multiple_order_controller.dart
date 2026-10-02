import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/assigned_delivery_orders.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/cancel_reason_sheet.dart';
import 'package:get/get.dart';

class HomeScreenMultipleOrderController extends GetxController {
  /// `Constant.userModel!` threw in the field initialiser — i.e. before
  /// `onInit`, so GetX could not even construct this controller — whenever the
  /// global had not been populated yet (cold start straight onto the
  /// dashboard). The live user document arrives from [getDriver] anyway.
  Rx<UserModel> driverModel = (Constant.userModel ?? UserModel()).obs;
  RxBool isLoading = true.obs;
  RxInt selectedTabIndex = 0.obs;

  RxList<dynamic> newOrder = [].obs;
  RxList<dynamic> activeOrder = [].obs;

  /// The orders behind [newOrder] and [activeOrder], live. The cards used to
  /// be `FutureBuilder(getOrderById)` created inside build: every
  /// `users/{me}` snapshot (one per location update) cleared both lists and
  /// rebuilt them, every card dropped back to a skeleton while it re-read its
  /// order, and a tap on Accept / Reject or on an active order mostly landed on
  /// a skeleton that does nothing.
  final RxMap<String, OrderModel> orders = <String, OrderModel>{}.obs;
  final RxBool ordersLoaded = false.obs;
  late final VendorOrdersWatch _ordersWatch = VendorOrdersWatch(_onOrdersChanged);
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _driverSub;

  @override
  void onInit() {
    // TODO: implement onInt
    getDriver();
    super.onInit();
  }

  @override
  void onClose() {
    _driverSub?.cancel();
    _ordersWatch.cancel();
    super.onClose();
  }

  void _onOrdersChanged(Map<String, OrderModel> found, bool fromServer) {
    orders.assignAll(found);
    ordersLoaded.value = true;
    final String? uid = driverModel.value.id;
    if (fromServer && uid != null) {
      AssignedDeliveryOrders.pruneStale(uid, driverModel.value.inProgressOrderID, found);
    }
  }

  static bool _sameIds(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].toString() != b[i].toString()) return false;
    }
    return true;
  }

  Future<void> getDriver() async {
    _driverSub?.cancel();
    _driverSub = FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).snapshots().listen(
      (event) async {
        if (event.exists) {
          driverModel.value = UserModel.fromJson(event.data()!);
          Constant.userModel = driverModel.value;
          final List<dynamic> requests = List<dynamic>.from(driverModel.value.orderRequestData ?? const []);
          final List<dynamic> inProgress = List<dynamic>.from(driverModel.value.inProgressOrderID ?? const []);
          // Only touched when the ids really changed (see [orders]).
          if (!_sameIds(newOrder, requests)) newOrder.assignAll(requests);
          if (!_sameIds(activeOrder, inProgress)) activeOrder.assignAll(inProgress);
          _ordersWatch.watch([...inProgress, ...requests]);

          if (newOrder.isEmpty == true) {
            await AudioPlayerService.playSound(false);
          }

          if (newOrder.isNotEmpty) {
            if (driverModel.value.vendorID?.isEmpty == true) {
              await AudioPlayerService.playSound(true);
            }
          }
        }
        isLoading.value = false;
      },
      onError: (Object e) {
        log("HomeScreenMultipleOrderController.getDriver failed: $e");
        isLoading.value = false;
      },
    );
  }

  Future<void> acceptOrder(OrderModel currentOrder) async {
    await AudioPlayerService.playSound(false);
    ShowToastDialog.showLoader("Please wait".tr);
    // Same as the single-order screen: these arrays can be absent on a
    // driver's user document, and the `!` made Accept fail silently.
    driverModel.value.inProgressOrderID ??= [];
    driverModel.value.orderRequestData ??= [];
    driverModel.value.orderRequestData!.remove(currentOrder.id);
    if (!driverModel.value.inProgressOrderID!.contains(currentOrder.id)) {
      driverModel.value.inProgressOrderID!.add(currentOrder.id);
    }

    await FireStoreUtils.updateUser(driverModel.value);

    currentOrder.status = Constant.driverAccepted;
    currentOrder.driverID = driverModel.value.id;
    currentOrder.driver = driverModel.value;

    await FireStoreUtils.setOrder(currentOrder);
    ShowToastDialog.closeLoader();
    await SendNotification.sendFcmMessage(Constant.driverAcceptedNotification, currentOrder.author?.fcmToken ?? '', {});
    await SendNotification.sendFcmMessage(Constant.driverAcceptedNotification, currentOrder.vendor?.fcmToken ?? '', {});
  }

  /// Driver passes on one of the offers in the list. A reason is mandatory
  /// and nothing changes until one is given. The order goes back to dispatch
  /// (status "Driver Rejected", this driver in `rejectedByDrivers`) and the
  /// reason is appended to `driverRejections`, in one known-fields write.
  Future<void> rejectOrder(OrderModel currentOrder) async {
    final String? orderId = currentOrder.id;
    final String? driverId = driverModel.value.id;
    if (orderId == null || driverId == null) return;
    final reason = await CancelReasonSheet.show(title: "Why are you rejecting this order?".tr);
    if (reason == null) return;
    ShowToastDialog.showLoader("Please wait".tr);
    await AudioPlayerService.playSound(false);
    final ok = await FireStoreUtils.updateVendorOrderFields(orderId, {
      'status': Constant.driverRejected,
      'rejectedByDrivers': FieldValue.arrayUnion([driverId]),
      ...reason.toFields(driverId),
    });
    if (!ok) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
      return;
    }
    driverModel.value.orderRequestData ??= [];
    driverModel.value.orderRequestData!.remove(orderId);
    await FireStoreUtils.updateUser(driverModel.value);
    ShowToastDialog.closeLoader();
  }
}

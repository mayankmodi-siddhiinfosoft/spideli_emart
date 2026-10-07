import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/services/dispatch_offer_rules.dart';
import 'package:driver/widget/cancel_reason_sheet.dart';
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
        // A "Driver Rejected" booking was passed back to dispatch, not
        // cancelled: it is the next driver's offer.
        return rentalOrders.where((order) => ["Order Rejected", "Order Cancelled"].contains(order.status)).toList();

      default:
        return [];
    }
  }

  /// The driver cancels a booking he accepted. A reason is mandatory and
  /// nothing changes until one is given. Like a cab ride cancelled after
  /// accept, the booking is handed back rather than ended: it goes back to
  /// the dispatch ("Driver Rejected", both driver fields null, this driver in
  /// `rejectedByDrivers` — rentalDispatch offers it to the next driver) and
  /// the reason is appended to `driverRejections` with `afterAccept: true`. Guarded: refused when the booking already
  /// moved on (started, cancelled, or another driver's).
  Future<void> cancelBooking(RentalOrderModel order) async {
    final id = order.id;
    if (id == null) return;
    final reason = await CancelReasonSheet.show(title: "Why are you cancelling this booking?".tr);
    if (reason == null) return;
    final uid = FireStoreUtils.getCurrentUid();
    ShowToastDialog.showLoader("Please wait".tr);
    String? error;
    try {
      final ref = FireStoreUtils.fireStore.collection(CollectionName.rentalOrders).doc(id);
      await FireStoreUtils.fireStore.runTransaction((tx) async {
        final data = (await tx.get(ref)).data();
        if (!DispatchOrderRules.canHandBack(data, uid)) {
          error = "This booking can no longer be cancelled".tr;
          return;
        }
        // `Driver Rejected` (not `Order Placed`): the status rentalDispatch
        // re-offers on, as cab_home_controller.cancelAcceptedRide writes.
        tx.update(ref, DispatchOrderRules.handBackFields(uid, reasonFields: reason.toFields(uid, afterAccept: true)));
      });
    } catch (e) {
      log("cancelBooking failed: $e");
      error = "Something went wrong. Please try again.".tr;
    }
    if (error == null) {
      // Handed back: no longer this driver's active job (spec §4).
      await FireStoreUtils.updateUserFields(uid, {
        'inProgressOrderID': FieldValue.arrayRemove([id]),
      });
    }
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast(error ?? "Booking cancelled".tr);
  }

  @override
  void onClose() {
    _rentalSubscription?.cancel();
    super.onClose();
  }
}

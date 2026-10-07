import '../utils/booking_status_tabs.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constant/constant.dart';
import '../models/parcel_order_model.dart';
import '../models/wallet_transaction_model.dart';
import '../screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import '../service/fire_store_utils.dart';
import '../service/parcel_cancellation.dart';
import '../themes/show_toast_dialog.dart';
import '../widget/cancel_reason_sheet.dart';

class ParcelMyBookingController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<ParcelOrderModel> parcelOrder = <ParcelOrderModel>[].obs;

  RxString selectedTab = "New".obs;
  RxList<String> tabTitles = ["New", "In Transit", "Delivered", "Cancelled"].obs;

  StreamSubscription<List<ParcelOrderModel>>? _parcelSubscription;

  @override
  void onInit() {
    super.onInit();
    listenParcelOrders();
  }

  void selectTab(String tab) {
    selectedTab.value = tab;
  }

  /// Start listening to orders live. Cancel previous subscription first.
  void listenParcelOrders() {
    isLoading.value = true;
    if (Constant.userModel == null) {
      isLoading.value = false;
      return;
    }
    _parcelSubscription?.cancel();
    _parcelSubscription = FireStoreUtils.listenParcelOrders().listen(
      (orders) {
        parcelOrder.assignAll(orders);
        isLoading.value = false;
      },
      onError: (err) {
        isLoading.value = false;
        // optionally handle error
      },
    );
  }

  /// Return filtered list for a specific tab title
  List<ParcelOrderModel> getOrdersForTab(String tab) {
    switch (tab) {
      case "New":
        // Quote requests (route not served) wait here until priced and paid,
        // and a parcel stays here while the dispatch looks for a driver
        // ("Driver Pending", or "Driver Rejected" which re-dispatches).
        return parcelOrder.where((order) => BookingStatusTabs.parcelNew.contains(order.status)).toList();

      case "In Transit":
        return parcelOrder.where((order) => BookingStatusTabs.parcelInTransit.contains(order.status)).toList();

      case "Delivered":
        return parcelOrder.where((order) => BookingStatusTabs.completed.contains(order.status)).toList();

      case "Cancelled":
        return parcelOrder.where((order) => BookingStatusTabs.cancelled.contains(order.status)).toList();

      default:
        return [];
    }
  }

  /// Old helper (optional)
  List<ParcelOrderModel> get filteredParcelOrders => getOrdersForTab(selectedTab.value);

  String formatDate(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return DateFormat("dd MMM yyyy, hh:mm a").format(dateTime);
  }

  /// Same rule, same write and same refund as the order screen
  /// ([ParcelCancellation]): a transaction that updates only the status, the
  /// reason and the tracking event.
  Future<void> cancelParcelOrder(ParcelOrderModel order) async {
    final String? orderId = order.id;
    if (orderId == null) return;
    // Mandatory reason (CANCEL-REASON-CONTRACT): backing out changes nothing.
    final reason = await CancelReasonSheet.show(title: "Why are you cancelling this parcel?".tr);
    if (reason == null) return;
    try {
      isLoading.value = true;

      final ParcelCancelResult result = await ParcelCancellation.cancel(orderId, reason.toFields());
      if (!result.ok) {
        ShowToastDialog.showToast(result.error!);
        return;
      }
      order.status = Constant.orderCancelled;
      reason.applyTo(order);

      final double refund = ParcelCancellation.refundAmount(result.before!);
      if (refund > 0) {
        WalletTransactionModel walletTransaction = WalletTransactionModel(
          id: Constant.getUuid(),
          amount: refund,
          date: Timestamp.now(),
          paymentMethod: PaymentGateway.wallet.name,
          transactionUser: "customer",
          userId: FireStoreUtils.getCurrentUid(),
          isTopup: true,
          // refund
          orderId: orderId,
          regionId: result.before!.regionId,
          note: "Refund for cancelled parcel order",
          paymentStatus: "success",
          serviceType: Constant.parcelServiceType,
        );

        // Save wallet transaction
        await FireStoreUtils.setWalletTransaction(walletTransaction);

        // Update wallet balance
        await FireStoreUtils.updateUserWallet(amount: refund.toString(), userId: FireStoreUtils.getCurrentUid());
      }

      listenParcelOrders();
      ShowToastDialog.showToast("Order cancelled successfully".tr);
    } catch (e) {
      ShowToastDialog.showToast("${'Failed to cancel order:'.tr} $e".tr);
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    _parcelSubscription?.cancel();
    super.onClose();
  }
}

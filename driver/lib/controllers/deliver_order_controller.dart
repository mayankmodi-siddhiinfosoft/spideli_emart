import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/app/home_screen/widgets/delivery_otp_sheet.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/cart_product_model.dart';
import 'package:driver/models/delivery_pod.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/wallet_transaction_model.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/services/delivery_pod_rules.dart';
import 'package:driver/services/delivery_pod_service.dart';
import 'package:driver/services/vendor_wallet_service.dart';
import 'package:driver/services/wallet_once.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class DeliverOrderController extends GetxController {
  RxBool isLoading = true.obs;
  RxBool conformPickup = false.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getArgument();
    super.onInit();
  }

  Rx<OrderModel> orderModel = OrderModel().obs;

  RxInt totalQuantity = 0.obs;

  void getArgument() {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      orderModel.value = argumentData['orderModel'];
      // A record without `products` (panel / Store hand assignments) threw
      // here, in onInit, and the job could never be completed.
      for (final CartProductModel element in orderModel.value.products ?? const <CartProductModel>[]) {
        totalQuantity.value += (element.quantity ?? 0);
      }
    }
    isLoading.value = false;
  }

  /// Proof of delivery by customer OTP (`.claude/POD-OTP-CONTRACT.md`) for
  /// a multivendor / e-commerce delivery order. "Drop Delivery" reuses the
  /// order's pending, unexpired code or creates one (and notifies the
  /// customer); the driver types the code the customer reads from their app.
  /// No OTP, no completion: there is no photo or skip path for these orders.
  ///
  /// Returns true once `pod.status` is `verified` — immediately on a retry
  /// after a completion that failed past verification. Returns false when the
  /// driver backed out or the code could not be created; nothing is written
  /// or credited then.
  Future<bool> verifyDeliveryOtp(BuildContext context, {required bool isDark}) async {
    // One flow at a time: a second swipe while the sheet is up does nothing.
    if (_otpFlowOpen) return false;
    if (orderModel.value.pod?.isVerified == true) return true;
    _otpFlowOpen = true;
    try {
      ShowToastDialog.showLoader("Please wait".tr);
      final PodState state;
      try {
        state = await DeliveryPodService.requestCode(orderModel.value);
      } on PodOfflineException {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast(DeliveryPodRules.offlineMessage.tr);
        return false;
      } catch (e) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("The delivery code could not be created. Please try again.".tr);
        return false;
      }
      ShowToastDialog.closeLoader();
      if (state.orderClosed) {
        ShowToastDialog.showToast(DeliveryPodRules.orderClosedMessage.tr);
        return false;
      }
      if (state.isVerified) {
        _markVerified(DeliveryPod(method: 'otp', status: DeliveryPodRules.statusVerified, verifiedAt: state.verifiedAt));
        return true;
      }
      if (!context.mounted) return false;
      final DeliveryPod? pod = await showDeliveryOtpSheet(context, isDark: isDark, order: orderModel.value, initial: state);
      if (pod == null || !pod.isVerified) return false;
      _markVerified(pod);
      return true;
    } finally {
      _otpFlowOpen = false;
    }
  }

  bool _otpFlowOpen = false;

  /// Keeps the in-memory order in step with Firestore, so a retry skips the
  /// code. Display only: `OrderModel.toJson` never writes `pod` (only the
  /// POD transactions do), so no save can roll it back.
  void _markVerified(DeliveryPod pod) {
    orderModel.value.pod = pod;
  }

  /// Guards against a second completion (a double tap on the slider): the
  /// wallet credit must happen exactly once.
  bool _completing = false;

  Future<void> completedOrder() async {
    if (_completing || orderModel.value.status == Constant.orderCompleted) return;
    _completing = true;
    final String? previousStatus = orderModel.value.status;
    try {
      await _completeOrder();
    } catch (e) {
      // A failed completion must be retryable: every payment above is
      // once-per-order (WalletOnce, vendorCredited), so the retry pays nothing
      // twice, and the verified `pod` means it asks for no new code.
      orderModel.value.status = previousStatus;
      _completing = false;
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("The delivery could not be completed: ${e.toString()}");
    }
  }

  Future<void> _completeOrder() async {
    ShowToastDialog.showLoader("Please wait".tr);
    await AudioPlayerService.playSound(false);
    orderModel.value.status = Constant.orderCompleted;
    await FireStoreUtils.updateWallateAmount(orderModel.value);
    // APP-SPEC-STORE.md §2 / APP-SPEC-ADMIN.md §7: the delivery also has to
    // credit the STORE. updateWallateAmount() only moves the driver's balance.
    // Idempotent, and a no-op when the Store app already credited this order.
    await VendorWalletService.creditStoreForCompletedOrder(orderModel.value);
    // One cashback row per order (`cashback_<orderId>`, shared with the Store
    // app), written together with the wallet balance in one transaction that
    // first checks the row: a retried completion, or both apps completing at
    // once, cannot pay it twice.
    final String? orderId = orderModel.value.id;
    if (orderModel.value.cashback?.cashbackValue != null && orderModel.value.cashback?.id != null) {
      final double cashback = double.parse("${orderModel.value.cashback?.cashbackValue ?? 0.0}");
      WalletTransactionModel transactionModel = WalletTransactionModel(
          id: orderId != null ? WalletOnce.cashbackRowId(orderId) : Constant.getUuid(),
          amount: cashback,
          date: Timestamp.now(),
          paymentMethod: "Cashback Amount",
          transactionUser: "user",
          userId: orderModel.value.author?.id,
          isTopup: true,
          orderId: orderModel.value.id,
          note: "Cashback Amount",
          paymentStatus: "success");
      await WalletOnce.pay(rowId: transactionModel.id!, row: transactionModel.toJson(), userId: orderModel.value.author?.id, amount: cashback);
    }
    await FireStoreUtils.setOrder(orderModel.value);
    if (Constant.userModel?.vendorID != null) {
      Constant.userModel?.orderRequestData?.remove(orderModel.value.id);
      Constant.userModel?.inProgressOrderID?.remove(orderModel.value.id);
      // Only the delivered id leaves the driver's arrays (field-level): the
      // whole user document written back from the global copy undid every
      // assignment, offer and wallet change made since that copy was read.
      final String? uid = Constant.userModel?.id;
      if (uid != null && orderId != null) {
        await FireStoreUtils.updateUserFields(uid, {
          'orderRequestData': FieldValue.arrayRemove([orderId]),
          'inProgressOrderID': FieldValue.arrayRemove([orderId]),
        });
      }
    }
    await FireStoreUtils.getFirestOrderOrNOt(orderModel.value).then((value) async {
      if (value == true) {
        await FireStoreUtils.updateReferralAmount(orderModel.value);
      }
    });

    await SendNotification.notifyCustomer(Constant.driverCompleted,
        customerId: orderModel.value.authorID ?? orderModel.value.author?.id,
        embeddedToken: orderModel.value.author?.fcmToken,
        payload: {'orderId': orderModel.value.id},
        status: orderModel.value.status);
    ShowToastDialog.closeLoader();
    Get.back(result: true);
  }
}

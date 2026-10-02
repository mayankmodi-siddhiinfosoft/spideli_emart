import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/app/home_screen/widgets/delivery_otp_sheet.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/delivery_pod.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/wallet_transaction_model.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/services/delivery_pod_rules.dart';
import 'package:driver/services/delivery_pod_service.dart';
import 'package:driver/services/vendor_wallet_service.dart';
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
      for (var element in orderModel.value.products!) {
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
    if (orderModel.value.pod?.isVerified == true) return true;
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
    if (state.isVerified) {
      _markVerified(DeliveryPod(method: 'otp', status: DeliveryPodRules.statusVerified, verifiedAt: state.verifiedAt));
      return true;
    }
    if (!context.mounted) return false;
    final DeliveryPod? pod = await showDeliveryOtpSheet(context, isDark: isDark, order: orderModel.value, initial: state);
    if (pod == null || !pod.isVerified) return false;
    _markVerified(pod);
    return true;
  }

  /// Keeps the in-memory order in step with Firestore, so the completion's
  /// `setOrder` (a deep merge) writes `pod.status: verified`, never an older
  /// value, and a retry skips the code.
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
      // A failed completion must be retryable — and must not have credited.
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
    if (orderModel.value.cashback?.cashbackValue != null && orderModel.value.cashback?.id != null) {
      WalletTransactionModel transactionModel = WalletTransactionModel(
          id: Constant.getUuid(),
          amount: double.parse("${orderModel.value.cashback?.cashbackValue ?? 0.0}"),
          date: Timestamp.now(),
          paymentMethod: "Cashback Amount",
          transactionUser: "user",
          userId: orderModel.value.author?.id,
          isTopup: true,
          orderId: orderModel.value.id,
          note: "Cashback Amount",
          paymentStatus: "success");
      await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
        if (value == true) {
          await FireStoreUtils.updateUserWallet(amount: double.parse("${orderModel.value.cashback?.cashbackValue ?? 0.0}").toString(), userId: orderModel.value.author!.id.toString());
        }
      });
    }
    await FireStoreUtils.setOrder(orderModel.value);
    if (Constant.userModel?.vendorID != null) {
      Constant.userModel?.orderRequestData?.remove(orderModel.value.id);
      Constant.userModel?.inProgressOrderID?.remove(orderModel.value.id);
      await FireStoreUtils.updateUser(Constant.userModel!);
    }
    await FireStoreUtils.getFirestOrderOrNOt(orderModel.value).then((value) async {
      if (value == true) {
        await FireStoreUtils.updateReferralAmount(orderModel.value);
      }
    });

    await SendNotification.sendFcmMessage(Constant.driverCompleted, orderModel.value.author?.fcmToken ?? '', {});
    ShowToastDialog.closeLoader();
    Get.back(result: true);
  }
}

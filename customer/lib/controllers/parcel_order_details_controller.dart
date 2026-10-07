import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/models/rating_model.dart';
import 'package:customer/models/wallet_transaction_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/widget/cancel_reason_sheet.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constant/constant.dart';
import '../models/parcel_category.dart';
import '../models/parcel_order_model.dart';
import '../models/user_model.dart';
import '../service/fire_store_utils.dart';
import '../service/parcel_cancellation.dart';
import '../service/parcel_shipping_service.dart';
import '../utils/booking_status_tabs.dart';

class ParcelOrderDetailsController extends GetxController {
  Rx<ParcelOrderModel> parcelOrder = ParcelOrderModel().obs;
  RxList<ParcelCategory> parcelCategory = <ParcelCategory>[].obs;
  RxBool isLoading = false.obs;

  Rx<UserModel?> driverUser = Rx<UserModel?>(null);
  Rx<RatingModel> ratingModel = RatingModel().obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args != null && args is ParcelOrderModel) {
      parcelOrder.value = args;
      setStatusHistoryFromString(parcelOrder.value);
    }
    loadParcelCategories();
    calculateTotalAmount();
    fetchDriverDetails();
  }

  RxDouble subTotal = 0.0.obs;
  RxDouble discount = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;
  RxDouble orderTaxAmount = 0.0.obs;
  RxDouble platformTaxAmount = 0.0.obs;

  void calculateTotalAmount() {
    taxAmount = 0.0.obs;
    discount = 0.0.obs;
    orderTaxAmount.value = 0;
    platformTaxAmount.value = 0;
    subTotal.value = double.parse(parcelOrder.value.subTotal.toString());
    discount.value = double.parse(parcelOrder.value.discount ?? '0.0');

    /// ---------------- ORDER TAX ----------------
    for (var taxElement in parcelOrder.value.taxSetting ?? []) {
      orderTaxAmount.value += Constant.calculateTax(amount: (subTotal.value - discount.value).toString(), taxModel: taxElement);
    }

    /// ---------------- PLATFORM TAX ----------------
    if (double.parse(parcelOrder.value.platformFee ?? '0.0') > 0) {
      for (var taxElement in parcelOrder.value.platformTax ?? []) {
        platformTaxAmount.value += Constant.calculateTax(amount: parcelOrder.value.platformFee ?? '0.0', taxModel: taxElement);
      }
    }

    taxAmount.value = orderTaxAmount.value + platformTaxAmount.value;

    totalAmount.value = (subTotal.value - discount.value) + double.parse(parcelOrder.value.platformFee ?? '0.0') + taxAmount.value + parcelOrder.value.scopeTaxAmount + parcelOrder.value.smsChargeAmount;
    update();
  }

  Future<void> fetchDriverDetails() async {
    // Only a driver who accepted the parcel: at "Driver Pending" the dispatch
    // has written the id of a driver who was only OFFERED it, and a decline
    // ("Driver Rejected") nulls it; nor the offered driver of a parcel
    // cancelled before anyone accepted it.
    if (!BookingStatusTabs.hasAssignedDriver(parcelOrder.value.status, parcelOrder.value.driverId, acceptedDriverId: parcelOrder.value.driver?.id)) {
      driverUser.value = null;
      return;
    }
    await FireStoreUtils.getUserProfile(parcelOrder.value.driverId!).then((value) {
      if (value != null) {
        driverUser.value = value;
      }
    });

    await FireStoreUtils.getReviewsbyID(parcelOrder.value.id.toString()).then((value) {
      if (value != null) {
        ratingModel.value = value;
      }
    });
  }

  void setStatusHistoryFromString(ParcelOrderModel order) {
    final steps = ["Order Placed", "Driver Accepted", "Pickup Done", "In Transit", "Delivered"];

    final history = <ParcelStatus>[];

    DateTime baseTime = order.createdAt?.toDate() ?? DateTime.now();
    int minutesGap = 30;

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];

      history.add(ParcelStatus(status: step, time: baseTime.add(Duration(minutes: i * minutesGap))));

      if (step == order.status) break;
    }

    order.statusHistory = history;
  }

  /// Cancellable while placed, an unpaid quote or with the driver dispatch
  /// (Driver Pending / Driver Rejected), and still with the sender.
  static bool canCancel(ParcelOrderModel order) => ParcelCancellation.canCancel(order.status, order.parcelStatus);

  Future<void> cancelParcelOrder() async {
    final String? orderId = parcelOrder.value.id;
    if (orderId == null) return;
    // Mandatory reason (CANCEL-REASON-CONTRACT): backing out changes nothing.
    final reason = await CancelReasonSheet.show(title: "Why are you cancelling this parcel?".tr);
    if (reason == null) return;
    ShowToastDialog.showLoader("Cancelling order...".tr);
    // Re-reads the order and writes only the status, the reason and the
    // tracking event (never the whole model).
    final ParcelCancelResult result = await ParcelCancellation.cancel(orderId, reason.toFields());
    if (!result.ok) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(result.error!);
      // Show what the order says now (e.g. a driver accepted meanwhile).
      final ParcelOrderModel? fresh = await ParcelShippingService.findOrder(orderId);
      if (fresh != null) {
        parcelOrder.value.status = fresh.status;
        parcelOrder.value.parcelStatus = fresh.parcelStatus;
      }
      parcelOrder.refresh();
      return;
    }
    // The refund is worked out on the order as it was just before the cancel.
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

    parcelOrder.value.status = Constant.orderCancelled;
    reason.applyTo(parcelOrder.value);
    if (result.before!.isTrackable) parcelOrder.value.parcelStatus = ParcelShipping.cancelled;
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast("Order cancelled successfully".tr);
    Get.back(result: true);
  }

  void loadParcelCategories() async {
    isLoading.value = true;
    final categories = await FireStoreUtils.getParcelServiceCategory();
    parcelCategory.value = categories;
    isLoading.value = false;
  }

  /// Fields [ParcelOrderModel.toJson] does not write back but a quote
  /// payment needs to read (manual price, events, status).
  Map<String, dynamic> readOnlyJson() => {
    'manualPrice': parcelOrder.value.manualPrice,
    'parcelStatus': parcelOrder.value.parcelStatus,
    'trackingEvents': parcelOrder.value.trackingEvents.map((e) => e.toJson()).toList(),
    'createdAt': parcelOrder.value.createdAt,
  };

  String formatDate(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return DateFormat("dd MMM yyyy, hh:mm a").format(dateTime);
  }

  ParcelCategory? getSelectedCategory() {
    try {
      return parcelCategory.firstWhere((cat) => cat.title?.toLowerCase().trim() == parcelOrder.value.parcelType?.toLowerCase().trim(), orElse: () => ParcelCategory());
    } catch (e) {
      return null;
    }
  }
}

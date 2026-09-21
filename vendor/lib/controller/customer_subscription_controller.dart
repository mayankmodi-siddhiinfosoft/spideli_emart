import 'package:get/get.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/vendor_subscription_model.dart';
import 'package:vendor/models/vendor_subscription_payment_model.dart';
import 'package:vendor/models/vendor_subscription_plan_model.dart';
import 'package:vendor/utils/customer_subscription_service.dart';

/// Backs the "Customer Subscriptions" screen (Plans / Subscribers / Payments).
class CustomerSubscriptionController extends GetxController {
  RxBool isPlansLoading = true.obs;
  RxBool isSubscribersLoading = true.obs;
  RxBool isPaymentsLoading = true.obs;

  RxList<VendorSubscriptionPlanModel> planList = <VendorSubscriptionPlanModel>[].obs;
  RxList<VendorSubscriptionModel> subscriberList = <VendorSubscriptionModel>[].obs;
  RxList<VendorSubscriptionPaymentModel> paymentList = <VendorSubscriptionPaymentModel>[].obs;

  @override
  void onInit() {
    getPlans();
    getSubscribers();
    getPayments();
    super.onInit();
  }

  Future<void> getPlans() async {
    try {
      planList.value = await CustomerSubscriptionService.getPlans();
    } catch (e) {
      ShowToastDialog.showToast("${'Something went wrong:'.tr} $e");
    }
    isPlansLoading.value = false;
  }

  Future<void> getSubscribers() async {
    try {
      subscriberList.value = await CustomerSubscriptionService.getSubscribers();
    } catch (e) {
      ShowToastDialog.showToast("${'Something went wrong:'.tr} $e");
    }
    isSubscribersLoading.value = false;
  }

  Future<void> getPayments() async {
    try {
      paymentList.value = await CustomerSubscriptionService.getPayments();
    } catch (e) {
      ShowToastDialog.showToast("${'Something went wrong:'.tr} $e");
    }
    isPaymentsLoading.value = false;
  }

  /// Sum of the STORED vendorEarning values (never recomputed).
  double get totalEarned {
    double total = 0;
    for (final p in paymentList) {
      total += double.tryParse(p.vendorEarning ?? '') ?? 0;
    }
    return total;
  }

  Future<void> togglePlan(VendorSubscriptionPlanModel plan, bool value) async {
    final previous = plan.isEnable;
    plan.isEnable = value;
    planList.refresh();
    try {
      await CustomerSubscriptionService.setPlanEnabled(plan.id!, value);
    } catch (e) {
      plan.isEnable = previous;
      planList.refresh();
      ShowToastDialog.showToast("${'Something went wrong:'.tr} $e");
    }
  }

  Future<void> deletePlan(VendorSubscriptionPlanModel plan) async {
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      await CustomerSubscriptionService.deletePlan(plan.id!);
      planList.remove(plan);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Plan deleted".tr);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("${'Something went wrong:'.tr} $e");
    }
  }

  static String periodLabel(String? expiryDay) {
    final days = int.tryParse(expiryDay ?? '') ?? 0;
    if (days == 30) return "Monthly".tr;
    if (days == 365) return "Annual".tr;
    if (days <= 0) return "-";
    return "$days ${"days".tr}";
  }
}

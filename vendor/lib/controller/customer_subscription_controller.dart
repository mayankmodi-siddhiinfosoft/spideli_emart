import 'package:get/get.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/vendor_subscription_model.dart';
import 'package:vendor/models/vendor_subscription_payment_model.dart';
import 'package:vendor/models/vendor_subscription_plan_model.dart';
import 'package:vendor/utils/customer_subscription_service.dart';

/// Backs the "Customer Subscriptions" screen (Plans / Subscribers / Payments).
class CustomerSubscriptionController extends GetxController {
  static const String filterAll = "all";
  static const String filterActive = "active";
  static const String filterExpiringSoon = "expiring";
  static const String filterExpired = "expired";
  static const String filterCancelled = "cancelled";
  static const String filterPaused = "paused";
  static const List<String> subscriberFilters = [filterAll, filterActive, filterPaused, filterExpiringSoon, filterExpired, filterCancelled];

  RxBool isPlansLoading = true.obs;
  RxBool isSubscribersLoading = true.obs;
  RxBool isPaymentsLoading = true.obs;

  RxList<VendorSubscriptionPlanModel> planList = <VendorSubscriptionPlanModel>[].obs;
  RxList<VendorSubscriptionModel> subscriberList = <VendorSubscriptionModel>[].obs;
  RxList<VendorSubscriptionPaymentModel> paymentList = <VendorSubscriptionPaymentModel>[].obs;

  RxString subscriberFilter = filterAll.obs;

  /// Ids of subscriptions that are a renewal: the newest one for a
  /// customer + plan pair that has older subscriptions. Derived, never stored.
  RxSet<String> renewedIds = <String>{}.obs;

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
      renewedIds
        ..clear()
        ..addAll(computeRenewedIds(subscriberList));
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

  // ---------------------------------------------------------------- Subscriber filters / renewals

  /// Subscribers matching the selected filter chip.
  List<VendorSubscriptionModel> get filteredSubscribers => subscriberList.where((s) => matchesFilter(s, subscriberFilter.value)).toList();

  int countFor(String filter) => subscriberList.where((s) => matchesFilter(s, filter)).length;

  static bool matchesFilter(VendorSubscriptionModel sub, String filter) {
    switch (filter) {
      case filterActive:
        return sub.effectiveStatus == 'active';
      case filterExpiringSoon:
        return sub.isExpiringSoon;
      case filterExpired:
        return sub.effectiveStatus == 'expired';
      case filterCancelled:
        return sub.effectiveStatus == 'cancelled';
      case filterPaused:
        return sub.effectiveStatus == 'paused';
      default:
        return true;
    }
  }

  static String filterLabel(String filter) {
    switch (filter) {
      case filterActive:
        return "Active".tr;
      case filterExpiringSoon:
        return "Expiring soon".tr;
      case filterExpired:
        return "Expired".tr;
      case filterCancelled:
        return "Cancelled".tr;
      case filterPaused:
        return "Paused".tr;
      default:
        return "All".tr;
    }
  }

  /// A renewal shows up as a newer subscription for the same customer + plan;
  /// the newest of each such pair is marked "Renewed".
  static Set<String> computeRenewedIds(List<VendorSubscriptionModel> subs) {
    final groups = <String, List<VendorSubscriptionModel>>{};
    for (final s in subs) {
      if ((s.customerId ?? '').isEmpty || s.effectivePlanId.isEmpty || (s.id ?? '').isEmpty) continue;
      // Only real subscription periods count: a failed or pending payment, or a
      // cancelled attempt, is not something that was renewed.
      if (s.effectiveStatus != 'active' && s.effectiveStatus != 'expired') continue;
      groups.putIfAbsent("${s.customerId}|${s.effectivePlanId}", () => []).add(s);
    }
    final ids = <String>{};
    for (final group in groups.values) {
      if (group.length < 2) continue;
      group.sort((a, b) => (b.startDate?.millisecondsSinceEpoch ?? 0).compareTo(a.startDate?.millisecondsSinceEpoch ?? 0));
      ids.add(group.first.id!);
    }
    return ids;
  }

  /// "Expires in N days" / "Expires today" / "Expired N days ago"; empty for
  /// cancelled subscriptions or when there is no expiry date.
  static String expiryRelativeLabel(VendorSubscriptionModel sub) {
    final days = sub.daysUntilExpiry;
    final status = sub.effectiveStatus;
    if (days == null || status == 'cancelled') return '';
    if (status == 'expired') {
      final ago = -days;
      if (ago <= 0) return "Expired today".tr;
      return ago == 1 ? "Expired 1 day ago".tr : "Expired @days days ago".trParams({'days': ago.toString()});
    }
    if (days <= 0) return "Expires today".tr;
    return days == 1 ? "Expires in 1 day".tr : "Expires in @days days".trParams({'days': days.toString()});
  }

  // ---------------------------------------------------------------- Labels

  static String periodLabel(String? expiryDay) {
    final days = int.tryParse(expiryDay ?? '') ?? 0;
    if (days == 30) return "Monthly".tr;
    if (days == 365) return "Annual".tr;
    if (days <= 0) return "-";
    return "$days ${"days".tr}";
  }

  static String frequencyLabel(String? frequency) {
    if (frequency == VendorSubscriptionPlanModel.frequencyDaily) return "Daily".tr;
    if (frequency == VendorSubscriptionPlanModel.frequencyWeekly) return "Weekly".tr;
    return "-";
  }

  static String shortDay(String day) => (day.length <= 3 ? day : day.substring(0, 3)).tr;

  /// "Every day", "Mon - Sat" (a consecutive run) or "Mon, Wed, Fri".
  static String daysLabel(List<String> days) {
    if (days.isEmpty) return "-";
    const all = VendorSubscriptionPlanModel.weekdays;
    if (days.length == all.length) return "Every day".tr;
    final indexes = days.map(all.indexOf).where((i) => i >= 0).toList()..sort();
    if (indexes.length == 1) return all[indexes.first].tr;
    final consecutive = indexes.length > 2 && indexes.last - indexes.first == indexes.length - 1;
    if (consecutive) return "${shortDay(all[indexes.first])} - ${shortDay(all[indexes.last])}";
    return indexes.map((i) => shortDay(all[i])).join(", ");
  }

  /// "Baguette × 2, Croissant × 4" for a plan's items.
  static String itemsLabel(List<VendorSubscriptionPlanItem> items) {
    return items.map((e) => "${e.name} × ${formatQuantity(e.quantityValue)}").join(", ");
  }

  static String formatQuantity(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
}

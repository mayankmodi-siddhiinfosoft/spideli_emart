import 'package:get/get.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/vendor_subscription_model.dart';
import 'package:vendor/models/vendor_subscription_plan_model.dart';
import 'package:vendor/utils/customer_subscription_service.dart';

/// Summed quantity of one item across deliveries ("Baguette × 24").
class ProductionItemTotal {
  final String name;
  double quantity;

  ProductionItemTotal(this.name, this.quantity);
}

/// Everything one plan needs for the chosen day.
class ProductionPlanGroup {
  final String planId;
  final String title;
  final List<VendorSubscriptionModel> deliveries = [];
  final List<ProductionItemTotal> totals = [];

  ProductionPlanGroup(this.planId, this.title);
}

/// Daily production list (spec 8.3): for a chosen day, what to prepare and
/// deliver for every subscription active that day. Read-only; built from the
/// plan SNAPSHOT each subscriber bought (`subscription.plan`), not the live plan.
class CustomerSubscriptionProductionController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<VendorSubscriptionModel> subscriptions = <VendorSubscriptionModel>[].obs;

  /// Local calendar day (time part always 00:00).
  Rx<DateTime> selectedDate = _today().obs;

  RxList<ProductionPlanGroup> groups = <ProductionPlanGroup>[].obs;
  RxList<ProductionItemTotal> overallTotals = <ProductionItemTotal>[].obs;

  /// Active that day but their snapshot has no delivery schedule (older plans).
  RxList<VendorSubscriptionModel> unscheduled = <VendorSubscriptionModel>[].obs;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get isToday => selectedDate.value == _today();

  int get deliveryCount => groups.fold(0, (sum, g) => sum + g.deliveries.length);

  @override
  void onInit() {
    load();
    super.onInit();
  }

  Future<void> load() async {
    try {
      subscriptions.value = await CustomerSubscriptionService.getSubscribers();
    } catch (e) {
      ShowToastDialog.showToast("${'Something went wrong:'.tr} $e");
    }
    _rebuild();
    isLoading.value = false;
  }

  void previousDay() => setDate(selectedDate.value.subtract(const Duration(days: 1)));

  void nextDay() => setDate(selectedDate.value.add(const Duration(days: 1)));

  void setDate(DateTime date) {
    // Rebuild from Y/M/D so DST shifts never leave a stray hour.
    selectedDate.value = DateTime(date.year, date.month, date.day);
    _rebuild();
  }

  void _rebuild() {
    final day = selectedDate.value;
    final byPlan = <String, ProductionPlanGroup>{};
    final noSchedule = <VendorSubscriptionModel>[];

    for (final sub in subscriptions) {
      if (!sub.isActiveOn(day)) continue;
      // The customer paused the subscription over this day, or skipped it.
      if (sub.isPausedOn(day) || sub.isSkipped(day)) continue;
      final plan = sub.plan;
      if (plan == null || !plan.hasSchedule) {
        noSchedule.add(sub);
        continue;
      }
      if (!plan.deliversOn(day)) continue;
      final planId = sub.effectivePlanId.isNotEmpty ? sub.effectivePlanId : (plan.title ?? '');
      final group = byPlan.putIfAbsent(planId, () => ProductionPlanGroup(planId, (plan.title ?? '').isEmpty ? "Untitled plan".tr : plan.title!));
      group.deliveries.add(sub);
      _addItems(group.totals, plan.items);
    }

    final list = byPlan.values.toList();
    for (final g in list) {
      g.deliveries.sort(_bySlotThenStart);
    }
    list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    final overall = <ProductionItemTotal>[];
    for (final g in list) {
      for (final t in g.totals) {
        _addTotal(overall, t.name, t.quantity);
      }
    }

    groups.value = list;
    overallTotals.value = overall;
    unscheduled.value = noSchedule;
  }

  /// Each delivery uses the quantities of its own snapshot, so subscribers on
  /// an older version of a plan are counted with what they bought.
  static void _addItems(List<ProductionItemTotal> totals, List<VendorSubscriptionPlanItem> items) {
    for (final item in items) {
      final name = (item.name ?? '').trim();
      if (name.isEmpty) continue;
      _addTotal(totals, name, item.quantityValue);
    }
  }

  static void _addTotal(List<ProductionItemTotal> totals, String name, double quantity) {
    final key = name.toLowerCase();
    for (final t in totals) {
      if (t.name.toLowerCase() == key) {
        t.quantity += quantity;
        return;
      }
    }
    totals.add(ProductionItemTotal(name, quantity));
  }

  static int _bySlotThenStart(VendorSubscriptionModel a, VendorSubscriptionModel b) {
    final af = VendorSubscriptionTimeSlot.minutesOf(a.plan?.timeSlot?.from) ?? 24 * 60;
    final bf = VendorSubscriptionTimeSlot.minutesOf(b.plan?.timeSlot?.from) ?? 24 * 60;
    if (af != bf) return af.compareTo(bf);
    return (a.startDate?.millisecondsSinceEpoch ?? 0).compareTo(b.startDate?.millisecondsSinceEpoch ?? 0);
  }
}

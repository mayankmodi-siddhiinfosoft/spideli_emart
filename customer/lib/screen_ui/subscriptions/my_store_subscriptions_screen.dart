import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/models/vendor_subscription_model.dart';
import 'package:customer/screen_ui/subscriptions/store_plans_section.dart';
import 'package:customer/screen_ui/subscriptions/subscription_ui.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/region_service.dart';
import 'package:customer/utils/store_subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Profile > My subscriptions (spec 4.7 step 5 / 7.9): the customer's store
/// subscriptions with Pause / Resume / Skip a day / Cancel, and payments.
class MyStoreSubscriptionsScreen extends StatefulWidget {
  const MyStoreSubscriptionsScreen({super.key});

  @override
  State<MyStoreSubscriptionsScreen> createState() => _MyStoreSubscriptionsScreenState();
}

class _MyStoreSubscriptionsScreenState extends State<MyStoreSubscriptionsScreen> {
  bool _loading = true;
  List<VendorSubscriptionModel> _subs = [];
  List<VendorSubscriptionPaymentModel> _payments = [];
  final Map<String, VendorModel?> _vendors = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([StoreSubscriptionService.mySubscriptions(), StoreSubscriptionService.myPayments()]);
      _subs = results[0] as List<VendorSubscriptionModel>;
      _payments = results[1] as List<VendorSubscriptionPaymentModel>;
      await RegionService.ensureLoaded();
      final ids = {..._subs.map((s) => s.vendorID ?? ''), ..._payments.map((p) => p.vendorID ?? '')}..remove('');
      for (final id in ids) {
        if (_vendors.containsKey(id)) continue;
        try {
          _vendors[id] = await FireStoreUtils.getVendorById(id);
        } catch (_) {
          _vendors[id] = null;
        }
      }
    } catch (e) {
      ShowToastDialog.showToast("${'Something went wrong:'.tr} $e");
    }
    if (mounted) setState(() => _loading = false);
  }

  String _storeName(String? id) => _vendors[id ?? '']?.title ?? "Store".tr;

  Future<void> _run(Future<void> Function() action, String done) async {
    ShowToastDialog.showLoader("Please wait...".tr);
    try {
      await action();
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(done);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("${'Something went wrong:'.tr} $e");
    }
    await _load();
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime _lastDay(VendorSubscriptionModel s) {
    final e = s.expiryDate?.toDate();
    if (e == null) return DateTime(_today.year + 1, _today.month, _today.day);
    final last = DateTime(e.year, e.month, e.day - 1);
    return last.isBefore(_today) ? _today : last;
  }

  DateTime _firstDay(VendorSubscriptionModel s) {
    final st = s.startDate?.toDate();
    if (st == null) return _today;
    final d = DateTime(st.year, st.month, st.day);
    return d.isAfter(_today) ? d : _today;
  }

  Future<void> _pause(VendorSubscriptionModel s) async {
    final first = _firstDay(s);
    final last = _lastDay(s);
    final from = await showDatePicker(context: context, helpText: "Pause from".tr, initialDate: first, firstDate: first, lastDate: last);
    if (from == null || !mounted) return;
    final open = await Get.dialog<bool>(
      AlertDialog(
        title: Text("Pause until".tr),
        content: Text("Pause until a date, or until you resume?".tr),
        actions: [
          TextButton(onPressed: () => Get.back(result: true), child: Text("Until I resume".tr)),
          TextButton(onPressed: () => Get.back(result: false), child: Text("Choose a date".tr)),
        ],
      ),
    );
    if (open == null || !mounted) return;
    DateTime? until;
    if (open == false) {
      until = await showDatePicker(context: context, helpText: "Pause until (inclusive)".tr, initialDate: from, firstDate: from, lastDate: last);
      if (until == null) return;
    }
    await _run(() => StoreSubscriptionService.pause(s.id!, from: from, until: until), "Subscription paused".tr);
  }

  Future<void> _skip(VendorSubscriptionModel s) async {
    final plan = s.plan;
    final first = _firstDay(s);
    final last = _lastDay(s);
    bool selectable(DateTime d) => (plan == null || !plan.hasSchedule || plan.deliversOn(d)) && !s.isSkipped(d) && !s.isPausedOn(d);
    DateTime initial = first;
    int guard = 0;
    while (!selectable(initial) && initial.isBefore(last) && guard < 400) {
      initial = DateTime(initial.year, initial.month, initial.day + 1);
      guard++;
    }
    if (!selectable(initial)) {
      ShowToastDialog.showToast("No delivery day left to skip".tr);
      return;
    }
    final day = await showDatePicker(context: context, helpText: "Skip a delivery day".tr, initialDate: initial, firstDate: first, lastDate: last, selectableDayPredicate: selectable);
    if (day == null) return;
    await _run(() => StoreSubscriptionService.skipDay(s.id!, day), "Delivery day skipped".tr);
  }

  Future<void> _cancel(VendorSubscriptionModel s) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text("Cancel subscription".tr),
        content: Text("Deliveries stop and the subscription will not be renewed. Payments already made are not refunded.".tr),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text("Keep".tr)),
          TextButton(onPressed: () => Get.back(result: true), child: Text("Cancel subscription".tr, style: TextStyle(color: AppThemeData.danger300))),
        ],
      ),
    );
    if (ok == true) await _run(() => StoreSubscriptionService.cancel(s.id!), "Subscription cancelled".tr);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Get.find<ThemeController>().isDark.value;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: SubUi.surface(isDark),
        appBar: SubUi.appBar(
          "My subscriptions".tr,
          isDark,
          bottom: TabBar(
            labelColor: AppThemeData.primary300,
            unselectedLabelColor: SubUi.muted(isDark),
            indicatorColor: AppThemeData.primary300,
            tabs: [Tab(text: "Subscriptions".tr), Tab(text: "Payments".tr)],
          ),
        ),
        body:
            _loading
                ? Constant.loader()
                : TabBarView(
                  children: [
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: _subs.isEmpty ? [SubUi.empty("You have no store subscriptions yet. Stores that sell them show a Subscriptions section on their page.".tr, isDark)] : _subs.map((s) => _subCard(s, isDark)).toList(),
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.all(16), children: _payments.isEmpty ? [SubUi.empty("No payments yet.".tr, isDark)] : _payments.map((p) => _paymentCard(p, isDark)).toList()),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _statusChip(String status) {
    switch (status) {
      case VendorSubscriptionModel.statusActive:
        return SubUi.chip("Active".tr, AppThemeData.success400);
      case VendorSubscriptionModel.statusPaused:
        return SubUi.chip("Paused".tr, AppThemeData.warning400);
      case VendorSubscriptionModel.statusCancelled:
        return SubUi.chip("Cancelled".tr, AppThemeData.danger300);
      case VendorSubscriptionModel.statusExpired:
        return SubUi.chip("Expired".tr, AppThemeData.grey500);
      default:
        return SubUi.chip(status.capitalizeFirst ?? status, AppThemeData.grey500);
    }
  }

  Widget _subCard(VendorSubscriptionModel s, bool isDark) {
    final status = s.effectiveStatus;
    final plan = s.plan;
    final currency = RegionService.currencyForRecord(s.regionId);
    final next = s.nextDeliveryDay();
    final upcomingSkips = s.skippedDates.where((d) => (DateTime.tryParse(d) ?? DateTime(2000)).isAfter(_today.subtract(const Duration(days: 1)))).toList()..sort();
    final bool running = status == VendorSubscriptionModel.statusActive || status == VendorSubscriptionModel.statusPaused;
    final bool pausedNow = (s.status ?? '').toLowerCase() == VendorSubscriptionModel.statusPaused && status != VendorSubscriptionModel.statusExpired;
    return SubUi.card(
      isDark,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: SubUi.title(plan?.title ?? '-', isDark)), _statusChip(status)]),
          const SizedBox(height: 4),
          SubUi.body(_storeName(s.vendorID), isDark),
          const SizedBox(height: 6),
          if (plan != null) SubUi.row("Price".tr, "${Constant.amountShow(amount: plan.price, currency: currency)} / ${StoreSubscriptionService.periodLabel(plan.expiryDay).tr}", isDark),
          if (plan != null && plan.items.isNotEmpty) SubUi.row("Each delivery".tr, storePlanItemsText(plan), isDark),
          if (plan != null && plan.hasSchedule) SubUi.row("Schedule".tr, storePlanScheduleText(plan), isDark),
          SubUi.row("Period".tr, "${s.startDate == null ? '-' : Constant.timestampToDate(s.startDate!)}  →  ${s.expiryDate == null ? '-' : Constant.timestampToDate(s.expiryDate!)}", isDark),
          if (s.deliveryAddressText.isNotEmpty) SubUi.row("Deliver to".tr, s.deliveryAddressText, isDark),
          if (pausedNow)
            SubUi.row(
              "Paused".tr,
              "${s.pausedFrom == null ? '' : Constant.timestampToDate(s.pausedFrom!)} → ${s.pausedUntil == null ? "until resumed".tr : Constant.timestampToDate(s.pausedUntil!)}",
              isDark,
            ),
          if (running && next != null) SubUi.row("Next delivery".tr, VendorSubscriptionModel.dayFormat.format(next), isDark),
          if (upcomingSkips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SubUi.body("${"Skipped".tr}:", isDark),
                  ...upcomingSkips.map(
                    (d) => InputChip(
                      label: Text(d, style: const TextStyle(fontSize: 12)),
                      onDeleted: running ? () => _run(() => StoreSubscriptionService.unskipDay(s.id!, d), "Delivery restored".tr) : null,
                    ),
                  ),
                ],
              ),
            ),
          if (s.cancelledAt != null) SubUi.row("Cancelled on".tr, Constant.timestampToDate(s.cancelledAt!), isDark),
          if (running) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (pausedNow)
                  OutlinedButton(onPressed: () => _run(() => StoreSubscriptionService.resume(s.id!), "Subscription resumed".tr), child: Text("Resume".tr))
                else
                  OutlinedButton(onPressed: () => _pause(s), child: Text("Pause".tr)),
                OutlinedButton(onPressed: () => _skip(s), child: Text("Skip a day".tr)),
                OutlinedButton(onPressed: () => _cancel(s), child: Text("Cancel".tr, style: TextStyle(color: AppThemeData.danger300))),
              ],
            ),
          ],
          if (status == VendorSubscriptionModel.statusExpired && plan != null && _vendors[s.vendorID ?? ''] != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: () => Get.to(() => StoreSubscribeScreen(plan: plan, vendor: _vendors[s.vendorID!]!)), child: Text("Subscribe again".tr)),
            ),
        ],
      ),
    );
  }

  Widget _paymentCard(VendorSubscriptionPaymentModel p, bool isDark) {
    final currency = RegionService.currencyForRecord(p.regionId);
    final sub = _subs.firstWhereOrNull((s) => s.id == p.subscriptionId);
    return SubUi.card(
      isDark,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SubUi.title(sub?.plan?.title ?? _storeName(p.vendorID), isDark)),
              Text(Constant.amountShow(amount: p.amount, currency: currency), style: TextStyle(fontFamily: AppThemeData.semiBold, color: SubUi.text(isDark))),
            ],
          ),
          const SizedBox(height: 4),
          SubUi.row("Store".tr, _storeName(p.vendorID), isDark),
          SubUi.row("Date".tr, p.createdAt == null ? '-' : Constant.timestampToDateTime(p.createdAt!), isDark),
          SubUi.row("Paid with".tr, (p.paymentMethod ?? '-').capitalizeFirst ?? '-', isDark),
          SubUi.row("Status".tr, (p.status ?? '-').capitalizeFirst ?? '-', isDark),
          SubUi.row("Reference".tr, p.id ?? '-', isDark),
        ],
      ),
    );
  }
}

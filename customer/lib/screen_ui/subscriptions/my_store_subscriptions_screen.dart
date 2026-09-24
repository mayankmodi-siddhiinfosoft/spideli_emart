import 'package:customer/constant/constant.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/models/vendor_subscription_model.dart';
import 'package:customer/screen_ui/subscriptions/store_plans_section.dart';
import 'package:customer/screen_ui/subscriptions/subscription_ui.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/region_service.dart';
import 'package:customer/utils/store_subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Profile > My subscriptions (spec 4.7 step 5 / 7.9): the customer's store
/// subscriptions with Pause / Resume / Skip a day / Cancel, and payments.
///
/// Archetype **F — history**: two tabs, status-chipped cards, inline actions.
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
      DsDialog(
        title: "Pause until".tr,
        message: "Pause until a date, or until you resume?".tr,
        icon: Icons.pause_circle_outline_rounded,
        tone: DsTone.warning,
        primaryLabel: "Until I resume".tr,
        onPrimary: () => Get.back(result: true),
        secondaryLabel: "Choose a date".tr,
        onSecondary: () => Get.back(result: false),
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
      DsDialog(
        title: "Cancel subscription".tr,
        message: "Deliveries stop and the subscription will not be renewed. Payments already made are not refunded.".tr,
        icon: Icons.cancel_outlined,
        tone: DsTone.danger,
        destructive: true,
        primaryLabel: "Cancel subscription".tr,
        onPrimary: () => Get.back(result: true),
        secondaryLabel: "Keep".tr,
        onSecondary: () => Get.back(result: false),
      ),
    );
    if (ok == true) await _run(() => StoreSubscriptionService.cancel(s.id!), "Subscription cancelled".tr);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return DefaultTabController(
      length: 2,
      child: DsScaffold(
        maxContentWidth: DsLayout.contentMax,
        appBar: DsAppBar(
          title: "My subscriptions".tr,
          bottom: DsTabBar(tabs: ["Subscriptions".tr, "Payments".tr]),
        ),
        body: DsAsync(
          isLoading: _loading,
          skeleton: const DsSkeletonList(itemCount: 3, leading: false, trailing: false),
          builder: (_) => TabBarView(
            children: [
              RefreshIndicator(
                onRefresh: _load,
                color: c.brand,
                child: _subs.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(DsSpace.lg),
                        children: [
                          DsEmptyState(
                            icon: Icons.event_repeat_rounded,
                            title: "Subscriptions".tr,
                            message: "You have no store subscriptions yet. Stores that sell them show a Subscriptions section on their page.".tr,
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxxl),
                        children: [
                          for (var i = 0; i < _subs.length; i++) DsFadeSlideIn(index: i, child: _subCard(context, _subs[i])),
                        ],
                      ),
              ),
              RefreshIndicator(
                onRefresh: _load,
                color: c.brand,
                child: _payments.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(DsSpace.lg),
                        children: [DsEmptyState(icon: Icons.receipt_long_outlined, title: "Payments".tr, message: "No payments yet.".tr)],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxxl),
                        children: [
                          for (var i = 0; i < _payments.length; i++) DsFadeSlideIn(index: i, child: _paymentCard(context, _payments[i])),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DsTone _statusTone(String status) {
    switch (status) {
      case VendorSubscriptionModel.statusActive:
        return DsTone.success;
      case VendorSubscriptionModel.statusPaused:
        return DsTone.warning;
      case VendorSubscriptionModel.statusCancelled:
        return DsTone.danger;
      case VendorSubscriptionModel.statusExpired:
        return DsTone.neutral;
      default:
        return DsTone.neutral;
    }
  }

  Widget _statusChip(String status) {
    switch (status) {
      case VendorSubscriptionModel.statusActive:
        return DsStatusChip(label: "Active".tr, tone: DsTone.success, pulse: true);
      case VendorSubscriptionModel.statusPaused:
        return DsStatusChip(label: "Paused".tr, tone: DsTone.warning);
      case VendorSubscriptionModel.statusCancelled:
        return DsStatusChip(label: "Cancelled".tr, tone: DsTone.danger);
      case VendorSubscriptionModel.statusExpired:
        return DsStatusChip(label: "Expired".tr, tone: DsTone.neutral);
      default:
        return DsStatusChip(label: status.capitalizeFirst ?? status, tone: DsTone.neutral);
    }
  }

  Widget _subCard(BuildContext context, VendorSubscriptionModel s) {
    final c = DsColors.of(context);
    final t = context.dsText;
    final status = s.effectiveStatus;
    final plan = s.plan;
    final currency = RegionService.currencyForRecord(s.regionId);
    final next = s.nextDeliveryDay();
    final upcomingSkips = s.skippedDates.where((d) => (DateTime.tryParse(d) ?? DateTime(2000)).isAfter(_today.subtract(const Duration(days: 1)))).toList()..sort();
    final bool running = status == VendorSubscriptionModel.statusActive || status == VendorSubscriptionModel.statusPaused;
    // From the effective status: a pause whose pausedUntil has passed is active.
    final bool pausedNow = status == VendorSubscriptionModel.statusPaused;
    return SubUi.card(
      context,
      borderColor: running ? c.tone(_statusTone(status)).main : null,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsIconWell(icon: pausedNow ? Icons.pause_rounded : Icons.event_repeat_rounded, tone: _statusTone(status), size: 44),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SubUi.title(context, plan?.title ?? '-'),
                    const DsGap(DsSpace.xxs),
                    Text(_storeName(s.vendorID), style: t.bodySm),
                  ],
                ),
              ),
              const DsGap(DsSpace.sm),
              _statusChip(status),
            ],
          ),
          const DsGap(DsSpace.md),
          DsDivider(spacing: DsSpace.xs),
          const DsGap(DsSpace.sm),
          if (plan != null) SubUi.row(context, "Price".tr, "${Constant.amountShow(amount: plan.price, currency: currency)} / ${StoreSubscriptionService.periodLabel(plan.expiryDay).tr}"),
          if (plan != null && plan.items.isNotEmpty) SubUi.row(context, "Each delivery".tr, storePlanItemsText(plan)),
          if (plan != null && plan.hasSchedule) SubUi.row(context, "Schedule".tr, storePlanScheduleText(plan)),
          SubUi.row(context, "Period".tr, "${s.startDate == null ? '-' : Constant.timestampToDate(s.startDate!)}  →  ${s.expiryDate == null ? '-' : Constant.timestampToDate(s.expiryDate!)}"),
          if (s.deliveryAddressText.isNotEmpty) SubUi.row(context, "Deliver to".tr, s.deliveryAddressText),
          if (pausedNow)
            SubUi.row(
              context,
              "Paused".tr,
              "${s.pausedFrom == null ? '' : Constant.timestampToDate(s.pausedFrom!)} → ${s.pausedUntil == null ? "until resumed".tr : Constant.timestampToDate(s.pausedUntil!)}",
            ),
          if (running && next != null) SubUi.row(context, "Next delivery".tr, VendorSubscriptionModel.dayFormat.format(next)),
          if (upcomingSkips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.sm),
              child: Wrap(
                spacing: DsSpace.sm,
                runSpacing: DsSpace.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text("${"Skipped".tr}:", style: t.bodySm),
                  ...upcomingSkips.map(
                    (d) => InputChip(
                      label: Text(d, style: t.labelSm.withColor(c.textPrimary)),
                      backgroundColor: c.surfaceAlt,
                      side: BorderSide(color: c.border),
                      onDeleted: running ? () => _run(() => StoreSubscriptionService.unskipDay(s.id!, d), "Delivery restored".tr) : null,
                    ),
                  ),
                ],
              ),
            ),
          if (s.cancelledAt != null) SubUi.row(context, "Cancelled on".tr, Constant.timestampToDate(s.cancelledAt!)),
          if (running) ...[
            const DsGap(DsSpace.lg),
            Wrap(
              spacing: DsSpace.sm,
              runSpacing: DsSpace.sm,
              children: [
                if (pausedNow)
                  DsButton.tonal(
                    label: "Resume".tr,
                    icon: Icons.play_arrow_rounded,
                    size: DsButtonSize.sm,
                    onPressed: () => _run(() => StoreSubscriptionService.resume(s.id!), "Subscription resumed".tr),
                  )
                else
                  DsButton.tonal(label: "Pause".tr, icon: Icons.pause_rounded, size: DsButtonSize.sm, onPressed: () => _pause(s)),
                DsButton.secondary(label: "Skip a day".tr, icon: Icons.event_busy_outlined, size: DsButtonSize.sm, onPressed: () => _skip(s)),
                DsButton.dangerTonal(label: "Cancel".tr, icon: Icons.close_rounded, size: DsButtonSize.sm, onPressed: () => _cancel(s)),
              ],
            ),
          ],
          if (status == VendorSubscriptionModel.statusExpired && plan != null && _vendors[s.vendorID ?? ''] != null)
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DsButton.ghost(
                  label: "Subscribe again".tr,
                  trailingIcon: Icons.arrow_forward_rounded,
                  size: DsButtonSize.sm,
                  onPressed: () => Get.to(() => StoreSubscribeScreen(plan: plan, vendor: _vendors[s.vendorID!]!)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _paymentCard(BuildContext context, VendorSubscriptionPaymentModel p) {
    final currency = RegionService.currencyForRecord(p.regionId);
    final sub = _subs.firstWhereOrNull((s) => s.id == p.subscriptionId);
    return SubUi.card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsIconWell(icon: Icons.payments_outlined, tone: DsTone.success, size: 40),
              const DsGap(DsSpace.md),
              Expanded(child: SubUi.title(context, sub?.plan?.title ?? _storeName(p.vendorID))),
              const DsGap(DsSpace.sm),
              SubUi.price(context, Constant.amountShow(amount: p.amount, currency: currency)),
            ],
          ),
          const DsGap(DsSpace.md),
          SubUi.row(context, "Store".tr, _storeName(p.vendorID)),
          SubUi.row(context, "Date".tr, p.createdAt == null ? '-' : Constant.timestampToDateTime(p.createdAt!)),
          SubUi.row(context, "Paid with".tr, (p.paymentMethod ?? '-').capitalizeFirst ?? '-'),
          SubUi.row(context, "Status".tr, (p.status ?? '-').capitalizeFirst ?? '-'),
          SubUi.row(context, "Reference".tr, p.id ?? '-'),
        ],
      ),
    );
  }
}

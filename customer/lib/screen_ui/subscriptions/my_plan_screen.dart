import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/subscriptions/gateway_checkout_screen.dart';
import 'package:customer/screen_ui/subscriptions/subscription_ui.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/customer_plan_service.dart';
import 'package:customer/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// "My plan" (spec 7.7): status of the full order-history plan, renewal
/// date, the plans on sale in the customer's region, and past purchases
/// (the `subscription_history` rows serve as invoices).
///
/// Archetype **H/E**: a status hero tinted by plan state, plan cards with a
/// price badge and benefit bullets, then invoice cards.
class MyPlanScreen extends StatefulWidget {
  const MyPlanScreen({super.key});

  @override
  State<MyPlanScreen> createState() => _MyPlanScreenState();
}

class _MyPlanScreenState extends State<MyPlanScreen> {
  bool _loading = true;
  Map<String, dynamic>? _user;
  List<CustomerPlan> _plans = [];
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([CustomerPlanService.currentUserData(), CustomerPlanService.availablePlans(), CustomerPlanService.purchaseHistory()]);
      _user = results[0] as Map<String, dynamic>?;
      _plans = results[1] as List<CustomerPlan>;
      _history = results[2] as List<Map<String, dynamic>>;
    } catch (e) {
      ShowToastDialog.showToast("${'Something went wrong:'.tr} $e");
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _buy(CustomerPlan plan) async {
    final result = await Get.to(
      () => GatewayCheckoutScreen(
        title: "${"Full order history".tr} - ${plan.name}",
        amount: plan.price,
        currency: CustomerPlanService.currency,
        regionId: RegionService.customerRegionId,
        onPaid: (method) => CustomerPlanService.recordPurchase(plan, paymentType: method),
      ),
    );
    if (result == true) {
      ShowToastDialog.showToast("Your plan is active. Your complete order history is now visible.".tr);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DsScaffold(
      title: "My plan".tr,
      maxContentWidth: DsLayout.contentMax,
      body: DsAsync(
        isLoading: _loading,
        skeleton: const _PlanSkeleton(),
        builder: (_) => RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
            children: DsFadeSlideIn.stagger([
              _status(context),
              SubUi.heading(context, "Plans".tr, icon: Icons.workspace_premium_outlined),
              ..._planCards(context),
              SubUi.heading(context, "Past purchases".tr, icon: Icons.receipt_long_outlined),
              ..._historyCards(context),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _status(BuildContext context) {
    final c = DsColors.of(context);
    final plan = CustomerPlanService.customerPlanOf(_user);
    final Timestamp? expiry = CustomerPlanService.expiryOf(_user);
    final bool active = CustomerPlanService.hasFullHistory(_user);
    String statusText;
    DsTone tone;
    if (plan == null) {
      statusText = "No plan".tr;
      tone = DsTone.neutral;
    } else if (active) {
      statusText = "Active".tr;
      tone = DsTone.success;
    } else {
      statusText = "Expired".tr;
      tone = DsTone.danger;
    }
    return SubUi.card(
      context,
      tone: tone == DsTone.neutral ? null : tone,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsIconWell(icon: active ? Icons.verified_rounded : Icons.history_rounded, tone: tone, size: 44),
              const DsGap(DsSpace.md),
              Expanded(child: SubUi.title(context, plan == null ? "Full order history".tr : (plan['name']?.toString() ?? '-'))),
              const DsGap(DsSpace.sm),
              SubUi.chip(statusText, tone),
            ],
          ),
          const DsGap(DsSpace.md),
          if (plan == null) SubUi.body(context, "Free access shows your latest orders only. Subscribe to see your complete order history.".tr),
          if (plan != null) SubUi.row(context, "Period".tr, CustomerPlanService.periodLabel(plan['expiryDay']?.toString() ?? '')),
          if (plan != null) SubUi.row(context, active ? "Renews / expires".tr : "Expired on".tr, expiry == null ? "Never expires".tr : Constant.timestampToDate(expiry)),
          if (active && expiry != null)
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.sm),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: c.textMuted),
                  const DsGap(DsSpace.sm),
                  Expanded(child: Text("Buying again now adds the new period after this date.".tr, style: DsTypography.caption.copyWith(color: c.textMuted))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool get _lifetime => CustomerPlanService.hasFullHistory(_user) && CustomerPlanService.expiryOf(_user) == null;

  List<Widget> _planCards(BuildContext context) {
    final c = DsColors.of(context);
    if (_plans.isEmpty) return [SubUi.empty(context, "No plan is offered in your region yet.".tr, icon: Icons.workspace_premium_outlined)];
    return _plans.map((p) {
      return SubUi.card(
        context,
        borderColor: _lifetime ? null : c.brand,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SubUi.title(context, p.name)),
                const DsGap(DsSpace.sm),
                SubUi.price(context, "${Constant.amountShow(amount: p.price, currency: CustomerPlanService.currency)} / ${p.periodLabel}"),
              ],
            ),
            if (p.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: DsSpace.xs), child: SubUi.body(context, p.description)),
            if (p.points.isNotEmpty) const DsGap(DsSpace.md),
            ...p.points.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: DsSpace.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: c.successStrong),
                    const DsGap(DsSpace.sm),
                    Expanded(child: Text(e, style: DsTypography.bodySm.copyWith(color: c.textSecondary))),
                  ],
                ),
              ),
            ),
            const DsGap(DsSpace.lg),
            DsButton.primary(
              label: _lifetime ? "You already have lifetime access".tr : (CustomerPlanService.hasFullHistory(_user) ? "Renew".tr : "Subscribe".tr),
              expand: true,
              icon: _lifetime ? Icons.all_inclusive_rounded : Icons.bolt_rounded,
              onPressed: _lifetime ? null : () => _buy(p),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _historyCards(BuildContext context) {
    if (_history.isEmpty) return [SubUi.empty(context, "No purchases yet.".tr, icon: Icons.receipt_long_outlined)];
    return _history.map((h) {
      final plan = Map<String, dynamic>.from(h['subscription_plan'] as Map);
      final createdAt = h['createdAt'];
      final expiry = h['expiry_date'];
      final currency = RegionService.currencyForRecord(h['regionId']?.toString());
      return SubUi.card(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DsIconWell(icon: Icons.receipt_outlined, tone: DsTone.neutral, size: 40),
                const DsGap(DsSpace.md),
                Expanded(child: SubUi.title(context, plan['name']?.toString() ?? '-')),
                const DsGap(DsSpace.sm),
                SubUi.price(context, Constant.amountShow(amount: plan['price']?.toString() ?? '0', currency: currency)),
              ],
            ),
            const DsGap(DsSpace.md),
            SubUi.row(context, "Invoice no.".tr, h['id']?.toString() ?? '-'),
            SubUi.row(context, "Date".tr, createdAt is Timestamp ? Constant.timestampToDateTime(createdAt) : '-'),
            SubUi.row(context, "Period".tr, CustomerPlanService.periodLabel(plan['expiryDay']?.toString() ?? '')),
            SubUi.row(context, "Valid until".tr, expiry is Timestamp ? Constant.timestampToDate(expiry) : "Never expires".tr),
            SubUi.row(context, "Paid with".tr, (h['payment_type']?.toString() ?? '-').capitalizeFirst ?? '-'),
          ],
        ),
      );
    }).toList();
  }
}

/// Status card + plan card skeleton.
class _PlanSkeleton extends StatelessWidget {
  const _PlanSkeleton();

  @override
  Widget build(BuildContext context) {
    return DsShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(DsSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: double.infinity, child: DsSkeleton.box(height: 150, radius: DsRadius.lg)),
            const DsGap(DsSpace.xxl),
            DsSkeleton.line(width: 90, height: 14),
            const DsGap(DsSpace.md),
            SizedBox(width: double.infinity, child: DsSkeleton.box(height: 180, radius: DsRadius.lg)),
            const DsGap(DsSpace.md),
            SizedBox(width: double.infinity, child: DsSkeleton.box(height: 180, radius: DsRadius.lg)),
          ],
        ),
      ),
    );
  }
}

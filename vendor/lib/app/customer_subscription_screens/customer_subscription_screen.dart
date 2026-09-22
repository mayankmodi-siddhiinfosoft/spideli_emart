import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/app/customer_subscription_screens/add_edit_customer_subscription_plan_screen.dart';
import 'package:vendor/app/customer_subscription_screens/customer_subscription_production_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/utils/region_service.dart';
import 'package:vendor/controller/customer_subscription_controller.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_subscription_model.dart';
import 'package:vendor/models/vendor_subscription_payment_model.dart';
import 'package:vendor/models/vendor_subscription_plan_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/utils/customer_subscription_service.dart';
import 'package:vendor/utils/network_image_widget.dart';

/// "Customer Subscriptions": plans this store sells to its OWN customers,
/// their subscribers and payments. Separate from the platform subscription the
/// store itself buys (SubscriptionPlanScreen).
class CustomerSubscriptionScreen extends StatefulWidget {
  const CustomerSubscriptionScreen({super.key});

  @override
  State<CustomerSubscriptionScreen> createState() => _CustomerSubscriptionScreenState();
}

class _CustomerSubscriptionScreenState extends State<CustomerSubscriptionScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: CustomerSubscriptionController(),
      builder: (controller) {
        return DsScaffold(
          maxContentWidth: null,
          appBar: DsAppBar(
            title: "Customer Subscriptions".tr,
            actions: [
              DsIconButton(
                icon: Icons.checklist_rtl_rounded,
                semanticLabel: "Daily production list".tr,
                variant: DsIconButtonVariant.tonal,
                onPressed: () => Get.to(() => const CustomerSubscriptionProductionScreen()),
              ),
              const DsGap(DsSpace.sm),
            ],
            bottom: DsTabBar(controller: _tabController, tabs: ["Plans".tr, "Subscribers".tr, "Payments".tr]),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [_plansTab(context, controller, isDark), _subscribersTab(controller, isDark), _paymentsTab(controller, isDark)],
          ),
          floatingActionButton: AnimatedScale(
            duration: DsMotion.of(context, DsMotion.base),
            curve: DsMotion.emphasized,
            scale: _tabController.index == 0 ? 1 : 0,
            child: _tabController.index == 0
                ? FloatingActionButton(
                    shape: const CircleBorder(),
                    tooltip: "Add".tr,
                    onPressed: () {
                      Get.to(const AddEditCustomerSubscriptionPlanScreen())!.then((value) {
                        if (value == true) controller.getPlans();
                      });
                    },
                    child: const Icon(Icons.add_rounded),
                  )
                : null,
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------ Plans

  Widget _plansTab(BuildContext context, CustomerSubscriptionController controller, bool isDark) {
    if (controller.isPlansLoading.value) return const DsSkeletonList(itemCount: 4);
    if (controller.planList.isEmpty) {
      return RefreshIndicator(
        color: context.dsColors.brand,
        onRefresh: controller.getPlans,
        child: _scrollableEmpty("No customer subscription plans yet. Tap + to create one.".tr, isDark, icon: Icons.card_membership_outlined),
      );
    }
    return RefreshIndicator(
      color: context.dsColors.brand,
      onRefresh: controller.getPlans,
      child: Builder(
        builder: (context) {
          final l = context.dsLayout;
          return ListView(
            padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.md, l.gutter, 96),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              DsAdaptiveGrid(
                minItemWidth: 340,
                maxColumns: 2,
                children: [
                  for (var index = 0; index < controller.planList.length; index++)
                    DsFadeSlideIn(index: index, child: _planCard(context, controller, controller.planList[index])),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _planCard(BuildContext context, CustomerSubscriptionController controller, VendorSubscriptionPlanModel plan) {
    final c = context.dsColors;
    final t = context.dsText;
    final enabled = plan.isEnable ?? true;
    return DsCard.outlined(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.sm, DsSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedOpacity(
                  duration: DsMotion.of(context, DsMotion.base),
                  opacity: enabled ? 1 : 0.45,
                  child: ClipRRect(
                    borderRadius: DsRadius.brMd,
                    child: NetworkImageWidget(imageUrl: plan.photo ?? '', height: 76, width: 76, fit: BoxFit.cover),
                  ),
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.title ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSm),
                      const DsGap(DsSpace.xs),
                      DsBadge(
                        label: "${_money(plan.price)} / ${CustomerSubscriptionController.periodLabel(plan.expiryDay)}",
                        tone: DsTone.brand,
                        icon: Icons.sell_outlined,
                      ),
                      const DsGap(DsSpace.sm),
                      if (plan.hasSchedule) ...[
                        _scheduleLine(
                          Icons.event_repeat,
                          "${CustomerSubscriptionController.frequencyLabel(plan.frequency)} · ${CustomerSubscriptionController.daysLabel(plan.effectiveDeliveryDays)}",
                        ),
                        if (plan.timeSlot?.isSet == true) _scheduleLine(Icons.schedule, plan.timeSlot!.label),
                      ] else ...[
                        _scheduleLine(Icons.info_outline, "No delivery schedule - edit to add one".tr, tone: DsTone.warning),
                      ],
                      if (plan.items.isNotEmpty) _scheduleLine(Icons.inventory_2_outlined, CustomerSubscriptionController.itemsLabel(plan.items)),
                    ],
                  ),
                ),
                Column(
                  children: [
                    _iconButton(
                      SvgPicture.asset("assets/icons/ic_edit_coupon.svg", width: 18, height: 18, colorFilter: ColorFilter.mode(c.textPrimary, BlendMode.srcIn)),
                      'Edit'.tr,
                      () {
                        Get.to(const AddEditCustomerSubscriptionPlanScreen(), arguments: {"planModel": plan})!.then((value) {
                          if (value == true) controller.getPlans();
                        });
                      },
                    ),
                    _iconButton(
                      SvgPicture.asset("assets/icons/ic_delete-one.svg", width: 18, height: 18, colorFilter: ColorFilter.mode(c.dangerStrong, BlendMode.srcIn)),
                      'Delete'.tr,
                      () {
                        showDialog(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            return DsDialog(
                              title: "Delete Plan".tr,
                              message: "Are you sure you want to delete this plan? Existing subscribers keep their current subscription.".tr,
                              icon: Icons.delete_outline_rounded,
                              tone: DsTone.danger,
                              destructive: true,
                              primaryLabel: "Delete".tr,
                              secondaryLabel: "Cancel".tr,
                              onPrimary: () async {
                                Get.back();
                                await controller.deletePlan(plan);
                              },
                              onSecondary: () {
                                Get.back();
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            color: c.surfaceAlt,
            padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.lg, DsSpace.xs, DsSpace.sm, DsSpace.xs),
            child: Row(
              children: [
                DsStatusChip(label: enabled ? "Enabled".tr : "Disabled".tr, tone: enabled ? DsTone.success : DsTone.neutral),
                const Spacer(),
                Switch(value: plan.isEnable ?? true, onChanged: (value) => controller.togglePlan(plan, value)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ Subscribers (read-only)

  Widget _subscribersTab(CustomerSubscriptionController controller, bool isDark) {
    if (controller.isSubscribersLoading.value) return const DsSkeletonList(itemCount: 5);
    if (controller.subscriberList.isEmpty) {
      return RefreshIndicator(
        onRefresh: controller.getSubscribers,
        child: _scrollableEmpty("No subscribers yet".tr, isDark, icon: Icons.group_outlined),
      );
    }
    final list = controller.filteredSubscribers;
    return Column(
      children: [
        _subscriberFilters(controller, isDark),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.getSubscribers,
            child: list.isEmpty
                ? _scrollableEmpty("No subscribers in this list".tr, isDark, icon: Icons.filter_list_off_rounded)
                : Builder(
                    builder: (context) {
                      final l = context.dsLayout;
                      return ListView.builder(
                        padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.xs, l.gutter, DsSpace.xl),
                        itemCount: list.length,
                        itemBuilder: (context, index) => DsFadeSlideIn(
                          index: index,
                          child: DsResponsive(child: _subscriberCard(controller, list[index], isDark)),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _subscriberFilters(CustomerSubscriptionController controller, bool isDark) {
    const filters = CustomerSubscriptionController.subscriberFilters;
    return Builder(
      builder: (context) {
        final l = context.dsLayout;
        return Padding(
          padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, DsSpace.sm),
          child: DsSegmentedTabs(
            scrollable: true,
            segments: [for (final filter in filters) DsSegment(CustomerSubscriptionController.filterLabel(filter), count: controller.countFor(filter))],
            index: filters.indexOf(controller.subscriberFilter.value).clamp(0, filters.length - 1),
            onChanged: (i) => controller.subscriberFilter.value = filters[i],
          ),
        );
      },
    );
  }

  Widget _subscriberCard(CustomerSubscriptionController controller, VendorSubscriptionModel sub, bool isDark) {
    final status = sub.effectiveStatus;
    final relative = CustomerSubscriptionController.expiryRelativeLabel(sub);
    final expiringSoon = sub.isExpiringSoon;
    final renewed = controller.renewedIds.contains(sub.id);
    return Builder(
      builder: (context) {
        final c = context.dsColors;
        return _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _customerInfo(sub.customerId, isDark)),
                  const DsGap(DsSpace.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _statusChip(status, isDark),
                      if (expiringSoon) ...[const DsGap(DsSpace.xs), _tagChip("Expiring soon".tr, DsTone.warning)],
                      if (renewed) ...[const DsGap(DsSpace.xs), _tagChip("Renewed".tr, DsTone.brand)],
                    ],
                  ),
                ],
              ),
              const DsGap(DsSpace.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
                child: Column(
                  children: [
                    // Plan title/price come from the stored snapshot, never the live plan.
                    _labelValue("Plan".tr, sub.plan?.title ?? '-', isDark),
                    _labelValue(
                      "Price".tr,
                      sub.plan?.price == null
                          ? '-'
                          : "${_money(sub.plan!.price, regionId: sub.regionId)} / ${CustomerSubscriptionController.periodLabel(sub.plan!.expiryDay)}",
                      isDark,
                    ),
                    _labelValue("Start date".tr, sub.startDate == null ? '-' : Constant.timestampToDate(sub.startDate!), isDark),
                    _labelValue("Expiry date".tr, sub.expiryDate == null ? '-' : Constant.timestampToDate(sub.expiryDate!), isDark),
                    if (relative.isNotEmpty)
                      _labelValue("", relative, isDark, valueColor: status == 'expired' ? c.dangerStrong : (expiringSoon ? c.warningStrong : c.successStrong)),
                    if (sub.plan?.hasSchedule == true)
                      _labelValue(
                        "Delivery".tr,
                        [
                          CustomerSubscriptionController.daysLabel(sub.plan!.effectiveDeliveryDays),
                          if (sub.plan!.timeSlot?.isSet == true) sub.plan!.timeSlot!.label,
                        ].join(" · "),
                        isDark,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------ Payments (read-only)

  Widget _paymentsTab(CustomerSubscriptionController controller, bool isDark) {
    if (controller.isPaymentsLoading.value) return const DsSkeletonList(itemCount: 5, leading: false);
    if (controller.paymentList.isEmpty) {
      return RefreshIndicator(
        onRefresh: controller.getPayments,
        child: _scrollableEmpty("No payments yet".tr, isDark, icon: Icons.payments_outlined),
      );
    }
    return RefreshIndicator(
      onRefresh: controller.getPayments,
      child: Builder(
        builder: (context) {
          final l = context.dsLayout;
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.md, l.gutter, DsSpace.xl),
            itemCount: controller.paymentList.length + 1,
            itemBuilder: (context, index) {
              final c = context.dsColors;
              final t = context.dsText;
              if (index == 0) {
                return DsFadeSlideIn(
                  child: DsResponsive(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: DsSpace.lg),
                      child: DsCard.gradient(
                        gradient: DsGradients.deep(context),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Total earned".tr, style: t.label.withColor(Colors.white.withValues(alpha: 0.8))),
                                  const DsGap(DsSpace.sm),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: AlignmentDirectional.centerStart,
                                    child: DsAnimatedCounter(
                                      value: controller.totalEarned,
                                      format: (v) => _money(v.toString()),
                                      style: t.metricLg.withColor(Colors.white),
                                    ),
                                  ),
                                  const DsGap(DsSpace.xs),
                                  DsBadge(
                                    label: "${controller.paymentList.length} ${"payments".tr}",
                                    icon: Icons.receipt_long_rounded,
                                    tone: DsTone.neutral,
                                    small: true,
                                  ),
                                ],
                              ),
                            ),
                            const DsIconWell(icon: Icons.savings_rounded, onBrand: true, size: 56),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
              final VendorSubscriptionPaymentModel payment = controller.paymentList[index - 1];
              return DsFadeSlideIn(
                index: index,
                child: DsResponsive(
                  child: _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _customerInfo(payment.customerId, isDark)),
                            const DsGap(DsSpace.sm),
                            Text(_money(payment.amount, regionId: payment.regionId), style: t.titleSm.tabular.withColor(c.textPrimary)),
                          ],
                        ),
                        const DsGap(DsSpace.md),
                        Divider(height: 1, thickness: 1, color: c.divider),
                        const DsGap(DsSpace.sm),
                        _labelValue("Amount".tr, _money(payment.amount, regionId: payment.regionId), isDark),
                        _labelValue("Admin commission".tr, _money(payment.adminCommission, regionId: payment.regionId), isDark),
                        if ((payment.adminCommissionType ?? '').isNotEmpty)
                          _labelValue("Commission type".tr, payment.adminCommissionType!.capitalizeFirst ?? payment.adminCommissionType!, isDark),
                        _labelValue("Store earning".tr, _money(payment.vendorEarning, regionId: payment.regionId), isDark, valueColor: c.successStrong),
                        _labelValue("Payment method".tr, (payment.paymentMethod ?? '').isEmpty ? '-' : payment.paymentMethod!, isDark),
                        if ((payment.status ?? '').isNotEmpty) _labelValue("Status".tr, payment.status!.capitalizeFirst ?? payment.status!, isDark),
                        _labelValue("Date".tr, payment.createdAt == null ? '-' : Constant.timestampToDateTime(payment.createdAt!), isDark),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------ Helpers

  /// Formats a stored amount string; tolerates empty / malformed values from other clients.
  ///
  /// [regionId] is the record's own region: a payment or subscription keeps the
  /// currency it was charged in, like an order.
  String _money(String? amount, {String? regionId}) {
    return Constant.amountShow(
      currency: regionId == null ? null : RegionService.currencyForOrder(regionId),
      amount: (double.tryParse(amount?.trim() ?? '') ?? 0).toString(),
    );
  }

  Widget _scrollableEmpty(String message, bool isDark, {IconData icon = Icons.inbox_outlined}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.xxl),
            child: Center(
              child: DsEmptyState(icon: icon, title: message, compact: true),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.md),
      child: DsCard.outlined(child: child),
    );
  }

  Widget _iconButton(Widget icon, String label, VoidCallback onTap) {
    return DsIconButton(semanticLabel: label, variant: DsIconButtonVariant.plain, onPressed: onTap, child: icon);
  }

  Widget _labelValue(String label, String value, bool isDark, {Color? valueColor}) {
    return Builder(
      builder: (context) {
        final c = context.dsColors;
        final t = context.dsText;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label, style: t.bodySm.withColor(c.textSecondary))),
              const DsGap(DsSpace.md),
              Flexible(
                child: Text(value, textAlign: TextAlign.end, style: t.bodyStrong.tabular.withColor(valueColor ?? c.textPrimary)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tagChip(String label, DsTone tone) {
    return DsBadge(label: label, tone: tone, small: true);
  }

  Widget _scheduleLine(IconData icon, String text, {DsTone? tone}) {
    return Builder(
      builder: (context) {
        final c = context.dsColors;
        final color = tone == null ? c.textSecondary : c.tone(tone).strong;
        return Padding(
          padding: const EdgeInsets.only(top: DsSpace.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 14, color: color),
              ),
              const DsGap(6),
              Expanded(
                child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.dsText.caption.withColor(color)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusChip(String status, bool isDark) {
    DsTone tone;
    switch (status) {
      case 'active':
        tone = DsTone.success;
        break;
      case 'cancelled':
        tone = DsTone.danger;
        break;
      default:
        tone = DsTone.neutral;
    }
    return DsStatusChip(label: (status.capitalizeFirst ?? status).tr, tone: tone, pulse: status == 'active');
  }

  /// Customer name/phone, looked up lazily from users/{customerId}; tolerates a
  /// missing or deleted user.
  Widget _customerInfo(String? customerId, bool isDark) {
    return FutureBuilder<UserModel?>(
      future: CustomerSubscriptionService.getCustomer(customerId),
      builder: (context, snapshot) {
        final c = context.dsColors;
        final t = context.dsText;
        final user = snapshot.data;
        final name = user == null ? '' : user.fullName().trim();
        final phone = user == null || (user.phoneNumber ?? '').isEmpty ? '' : "${user.countryCode ?? ''} ${user.phoneNumber}".trim();
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        return Row(
          children: [
            DsAvatar(name: waiting ? null : name, imageUrl: user?.profilePictureURL, size: 44),
            const DsGap(DsSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    waiting ? "Loading...".tr : (name.isEmpty ? "Unknown customer".tr : name),
                    style: waiting ? t.bodyStrong.withColor(c.textMuted) : t.titleSm,
                  ),
                  if (phone.isNotEmpty) ...[
                    const DsGap(DsSpace.xxs),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 13, color: c.textMuted),
                        const DsGap(DsSpace.xs),
                        Flexible(child: Text(phone, style: t.bodySm.withColor(c.textSecondary))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

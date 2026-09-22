import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:vendor/controller/customer_subscription_controller.dart';
import 'package:vendor/controller/customer_subscription_production_controller.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_subscription_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/customer_subscription_service.dart';

/// Daily production list for Customer Subscriptions: what to prepare and
/// deliver on a chosen day for every active subscriber, grouped by plan.
class CustomerSubscriptionProductionScreen extends StatelessWidget {
  const CustomerSubscriptionProductionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: CustomerSubscriptionProductionController(),
      builder: (controller) {
        return DsScaffold(
          title: "Daily production list".tr,
          maxContentWidth: null,
          body: Column(
            children: [
              _dateBar(context, controller),
              Expanded(
                child: DsAsync(
                  isLoading: controller.isLoading.value,
                  skeleton: const DsSkeletonList(itemCount: 4, leading: false),
                  builder: (context) => RefreshIndicator(color: context.dsColors.brand, onRefresh: controller.load, child: _content(controller)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dateBar(BuildContext context, CustomerSubscriptionProductionController controller) {
    final date = controller.selectedDate.value;
    final c = context.dsColors;
    final t = context.dsText;
    final l = context.dsLayout;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      padding: EdgeInsets.fromLTRB(l.gutter - DsSpace.xs, DsSpace.sm, l.gutter - DsSpace.xs, DsSpace.sm),
      child: DsResponsive(
        child: Row(
          children: [
            DsIconButton(
              icon: Icons.chevron_left_rounded,
              semanticLabel: "Previous day".tr,
              variant: DsIconButtonVariant.tonal,
              onPressed: controller.previousDay,
            ),
            const DsGap(DsSpace.xs),
            Expanded(
              child: Material(
                color: c.surfaceAlt,
                borderRadius: DsRadius.brMd,
                child: InkWell(
                  borderRadius: DsRadius.brMd,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(date.year - 2),
                      lastDate: DateTime(date.year + 2, 12, 31),
                    );
                    if (picked != null) controller.setDate(picked);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 20, color: c.brand),
                        const DsGap(DsSpace.sm),
                        Flexible(
                          child: AnimatedSwitcher(
                            duration: DsMotion.of(context, DsMotion.base),
                            child: Column(
                              key: ValueKey(date),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(controller.isToday ? "Today".tr : DateFormat('EEEE').format(date).tr, style: t.labelSm.withColor(c.brandStrong)),
                                Text(DateFormat('EEE, MMM dd, yyyy').format(date), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const DsGap(DsSpace.xs),
            DsIconButton(icon: Icons.chevron_right_rounded, semanticLabel: "Next day".tr, variant: DsIconButtonVariant.tonal, onPressed: controller.nextDay),
            if (!controller.isToday) ...[
              const DsGap(DsSpace.xs),
              DsButton.ghost(label: "Today".tr, size: DsButtonSize.sm, onPressed: () => controller.setDate(DateTime.now())),
            ],
          ],
        ),
      ),
    );
  }

  Widget _content(CustomerSubscriptionProductionController controller) {
    if (controller.groups.isEmpty && controller.unscheduled.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.xxl),
              child: Center(
                child: DsEmptyState(icon: Icons.event_available_outlined, title: "No subscription deliveries on this day".tr, compact: true),
              ),
            ),
          ),
        ),
      );
    }
    return Builder(
      builder: (context) {
        final l = context.dsLayout;
        final cards = <Widget>[...controller.groups.map((g) => _planCard(g)), if (controller.unscheduled.isNotEmpty) _unscheduledCard(controller.unscheduled)];
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxl),
          children: [
            if (controller.groups.isNotEmpty) DsFadeSlideIn(child: _summaryCard(controller)),
            if (controller.groups.isNotEmpty) const DsGap(DsSpace.lg),
            DsResponsive(
              maxWidth: DsLayout.wideMax,
              child: DsAdaptiveGrid(
                minItemWidth: 360,
                maxColumns: 2,
                equalHeight: false,
                spacing: DsSpace.md,
                runSpacing: DsSpace.md,
                children: [for (var i = 0; i < cards.length; i++) DsFadeSlideIn(index: i + 1, child: cards[i])],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard(CustomerSubscriptionProductionController controller) {
    return Builder(
      builder: (context) {
        final t = context.dsText;
        return DsResponsive(
          maxWidth: DsLayout.wideMax,
          child: DsCard.gradient(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const DsIconWell(icon: Icons.soup_kitchen_rounded, onBrand: true, size: 48),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("To prepare".tr, style: t.label.withColor(Colors.white.withValues(alpha: 0.85))),
                          const DsGap(DsSpace.xxs),
                          Text("${controller.deliveryCount} ${"deliveries".tr}", style: t.headline.withColor(Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (controller.overallTotals.isNotEmpty) ...[
                  const DsGap(DsSpace.lg),
                  Wrap(spacing: DsSpace.sm, runSpacing: DsSpace.sm, children: controller.overallTotals.map((t) => _qtyChip(t, onBrand: true)).toList()),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _planCard(ProductionPlanGroup group) {
    final count = group.deliveries.length;
    return Builder(
      builder: (context) {
        final c = context.dsColors;
        final t = context.dsText;
        return DsCard.outlined(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: c.brandSoft,
                padding: const EdgeInsets.all(DsSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const DsIconWell(icon: Icons.card_membership_rounded, size: 36),
                        const DsGap(DsSpace.md),
                        Expanded(child: Text(group.title, style: t.titleSm)),
                        const DsGap(DsSpace.sm),
                        DsBadge(
                          label: count == 1 ? "1 subscriber".tr : "@count subscribers".trParams({'count': count.toString()}),
                          tone: DsTone.brand,
                          style: DsBadgeStyle.solid,
                          icon: Icons.people_alt_rounded,
                          small: true,
                        ),
                      ],
                    ),
                    if (group.totals.isNotEmpty) ...[
                      const DsGap(DsSpace.md),
                      Wrap(spacing: DsSpace.sm, runSpacing: DsSpace.sm, children: group.totals.map((t) => _qtyChip(t)).toList()),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Deliveries".tr.toUpperCase(), style: t.overline.withColor(c.textMuted)),
                    ...group.deliveries.map((s) => _deliveryRow(s)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _unscheduledCard(List<VendorSubscriptionModel> subs) {
    return Builder(
      builder: (context) {
        final c = context.dsColors;
        final t = context.dsText;
        return DsCard.tinted(
          tone: DsTone.warning,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const DsIconWell(icon: Icons.info_outline, tone: DsTone.warning, size: 36),
                  const DsGap(DsSpace.md),
                  Expanded(child: Text("No delivery schedule".tr, style: t.titleSm)),
                  DsBadge(label: "${subs.length}", tone: DsTone.warning, style: DsBadgeStyle.solid),
                ],
              ),
              const DsGap(DsSpace.sm),
              Text(
                "Active subscribers whose plan was bought before it had items, days and a time slot. Check with them what to deliver.".tr,
                style: t.bodySm.withColor(c.textSecondary),
              ),
              const DsGap(DsSpace.sm),
              Divider(height: DsSpace.lg, thickness: 1, color: c.warning.withValues(alpha: 0.3)),
              ...subs.map((s) => _deliveryRow(s, showPlan: true)),
            ],
          ),
        );
      },
    );
  }

  Widget _deliveryRow(VendorSubscriptionModel sub, {bool showPlan = false}) {
    final slot = sub.plan?.timeSlot?.isSet == true ? sub.plan!.timeSlot!.label : '';
    return FutureBuilder<UserModel?>(
      future: CustomerSubscriptionService.getCustomer(sub.customerId),
      builder: (context, snapshot) {
        final c = context.dsColors;
        final t = context.dsText;
        final secondary = c.textSecondary;
        final user = snapshot.data;
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        final name = user == null ? '' : user.fullName().trim();
        final phone = user == null || (user.phoneNumber ?? '').isEmpty ? '' : "${user.countryCode ?? ''} ${user.phoneNumber}".trim();
        final address = sub.deliveryAddress ?? CustomerSubscriptionService.customerAddress(user) ?? '';
        return Padding(
          padding: const EdgeInsets.only(top: DsSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsAvatar(name: waiting ? null : name, imageUrl: user?.profilePictureURL, size: 36),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      waiting ? "Loading...".tr : (name.isEmpty ? "Unknown customer".tr : name),
                      style: waiting ? t.bodyStrong.withColor(c.textMuted) : t.label.withColor(c.textPrimary),
                    ),
                    if (showPlan && (sub.plan?.title ?? '').isNotEmpty) _line(Icons.card_membership, sub.plan!.title!, secondary),
                    if (phone.isNotEmpty) _line(Icons.phone_outlined, phone, secondary),
                    if (address.isNotEmpty) _line(Icons.location_on_outlined, address, secondary),
                    if (sub.plan != null && sub.plan!.items.isNotEmpty && showPlan)
                      _line(Icons.inventory_2_outlined, CustomerSubscriptionController.itemsLabel(sub.plan!.items), secondary),
                  ],
                ),
              ),
              if (slot.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: DsSpace.sm),
                  child: DsBadge(label: slot, tone: DsTone.brand, icon: Icons.schedule_rounded, small: true),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _line(IconData icon, String text, Color color) {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.only(top: DsSpace.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 14, color: color),
            ),
            const DsGap(6),
            Expanded(child: Text(text, style: context.dsText.caption.withColor(color))),
          ],
        ),
      ),
    );
  }

  Widget _qtyChip(ProductionItemTotal total, {bool onBrand = false}) {
    return Builder(
      builder: (context) {
        final c = context.dsColors;
        final t = context.dsText;
        final fg = onBrand ? Colors.white : c.brandStrong;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: 6),
          decoration: BoxDecoration(
            color: onBrand ? Colors.white.withValues(alpha: 0.18) : c.surface,
            borderRadius: DsRadius.brPill,
            border: onBrand ? null : Border.all(color: c.brand.withValues(alpha: 0.35)),
          ),
          child: Text(
            "${total.name} × ${CustomerSubscriptionController.formatQuantity(total.quantity)}",
            style: t.label.tabular.withColor(fg).copyWith(fontSize: 13),
          ),
        );
      },
    );
  }
}

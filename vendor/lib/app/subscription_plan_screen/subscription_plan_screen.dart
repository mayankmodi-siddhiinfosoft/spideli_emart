import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/section_model.dart';
import 'package:vendor/app/subscription_plan_screen/select_payment_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/subscription_controller.dart';
import 'package:vendor/models/subscription_plan_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/network_image_widget.dart';

class SubscriptionPlanScreen extends StatelessWidget {
  const SubscriptionPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: SubscriptionController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        return DsScaffold.hero(
          heroGradient: DsGradients.deep(context),
          hero: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsBadge(label: "Business Plan".tr, icon: Icons.workspace_premium_rounded, tone: DsTone.warning, style: DsBadgeStyle.solid),
              const DsGap(DsSpace.md),
              Semantics(header: true, child: Text("Choose Your Business Plan".tr, style: t.display.withColor(Colors.white))),
              const DsGap(DsSpace.sm),
              Text(
                "Select the most suitable business plan for your store to maximize your potential and access exclusive features.".tr,
                style: t.body.withColor(Colors.white.withValues(alpha: 0.8)),
              ),
            ],
          ),
          slivers: [
            DsSliverResponsive(
              maxWidth: DsLayout.wideMax,
              top: DsSpace.xl,
              sliver: SliverToBoxAdapter(
                child: DsAsync(
                  isLoading: controller.isLoading.value,
                  skeleton: const _PlansSkeleton(),
                  builder: (context) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DsFadeSlideIn(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: DsLayout.contentMax),
                              child: controller.userModel.value.sectionId != null && controller.userModel.value.sectionId!.isNotEmpty
                                  ? InkWell(
                                      borderRadius: DsRadius.brMd,
                                      onTap: () {
                                        ShowToastDialog.showToast("cannot_change_section".trArgs([controller.selectedSectionModel.value.name ?? '']));
                                      },
                                      child: DsTextField(
                                        readOnly: true,
                                        label: 'Section'.tr,
                                        controller: null,
                                        hint: 'Section Name'.tr,
                                        initialValue: controller.selectedSectionModel.value.name,
                                        enabled: false,
                                        prefixIcon: Icons.category_outlined,
                                        suffix: const Icon(Icons.lock_outline_rounded, size: 18),
                                      ),
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.only(bottom: DsSpace.lg),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          DsFieldLabel("Section".tr),
                                          DropdownButtonFormField<SectionModel>(
                                            isExpanded: true,
                                            dropdownColor: c.surfaceRaised,
                                            borderRadius: DsRadius.brMd,
                                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
                                            decoration: DsInputDecoration.of(context, prefixIcon: Icons.category_outlined),
                                            validator: (value) => value == null ? 'field required' : null,
                                            initialValue: controller.selectedSectionModel.value,
                                            onChanged: (value) {
                                              controller.selectedSectionModel.value = value!;
                                              controller.subscriptionPlanList.clear();
                                              controller.getSubscriptionPlanList();
                                            },
                                            style: t.bodyStrong.withColor(c.textPrimary),
                                            hint: Text('Select Section'.tr),
                                            items: controller.sectionsList.map((SectionModel item) {
                                              return DropdownMenuItem<SectionModel>(value: item, child: Text("${item.name} (${item.serviceType})"));
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        controller.subscriptionPlanList.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: DsSpace.huge),
                                child: DsEmptyState(icon: Icons.workspace_premium_outlined, title: "Subscription plan not found.".tr),
                              )
                            : DsAdaptiveGrid(
                                minItemWidth: 300,
                                maxColumns: 3,
                                spacing: DsSpace.lg,
                                runSpacing: DsSpace.lg,
                                children: [
                                  for (var index = 0; index < controller.subscriptionPlanList.length; index++)
                                    Builder(
                                      builder: (context) {
                                        final subscriptionPlanModel = controller.subscriptionPlanList[index];
                                        return DsFadeSlideIn(
                                          index: index + 1,
                                          child: SubscriptionPlanWidget(
                                            onContainClick: () {
                                              controller.selectedSubscriptionPlan.value = subscriptionPlanModel;
                                              controller.totalAmount.value = double.parse(subscriptionPlanModel.price ?? '0.0');
                                              controller.update();
                                            },
                                            onClick: () {
                                              if (controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id) {
                                                if (controller.selectedSubscriptionPlan.value.type == 'free' ||
                                                    controller.selectedSubscriptionPlan.value.id == Constant.commissionSubscriptionID) {
                                                  controller.selectedPaymentMethod.value = 'free';
                                                  controller.placeOrder();
                                                } else {
                                                  Get.to(const SelectPaymentScreen());
                                                }
                                              }
                                            },
                                            type: 'Plan',
                                            subscriptionPlanModel: subscriptionPlanModel,
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlansSkeleton extends StatelessWidget {
  const _PlansSkeleton();

  @override
  Widget build(BuildContext context) {
    return DsShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsSkeleton.line(width: 80),
          const DsGap(DsSpace.sm),
          DsSkeleton.box(height: 52, radius: DsRadius.md),
          const DsGap(DsSpace.xl),
          DsAdaptiveGrid(
            minItemWidth: 300,
            maxColumns: 3,
            spacing: DsSpace.lg,
            runSpacing: DsSpace.lg,
            children: [for (var i = 0; i < 3; i++) DsSkeleton.box(height: 380, radius: DsRadius.xl)],
          ),
        ],
      ),
    );
  }
}

class FeatureItem extends StatelessWidget {
  final String title;
  final bool isActive;
  final bool selectedPlan;

  const FeatureItem({super.key, required this.title, required this.isActive, required this.selectedPlan});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final fg = selectedPlan == true ? Colors.white : c.textPrimary;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.sm, 6, DsSpace.md, 6),
      decoration: BoxDecoration(color: selectedPlan == true ? Colors.white.withValues(alpha: 0.10) : c.surfaceAlt, borderRadius: DsRadius.brPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isActive == true
              ? SvgPicture.asset('assets/icons/ic_check.svg', width: 16, height: 16)
              : SvgPicture.asset('assets/icons/ic_close.svg', width: 16, height: 16, colorFilter: ColorFilter.mode(c.danger, BlendMode.srcIn)),
          const DsGap(6),
          Flexible(
            child: Text(
              title == 'chat'
                  ? 'Chat'.tr
                  : title == 'dineIn'
                  ? "DineIn".tr
                  : title == 'qrCodeGenerate'
                  ? 'QR Code Generate'.tr
                  : title == 'ownerMobileApp'
                  ? 'Store Mobile App'.tr
                  : '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.labelSm.withColor(isActive == true ? fg : fg.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }
}

class SubscriptionPlanWidget extends StatelessWidget {
  final VoidCallback onClick;
  final VoidCallback onContainClick;
  final String type;
  final SubscriptionPlanModel subscriptionPlanModel;

  const SubscriptionPlanWidget({super.key, required this.onClick, required this.type, required this.subscriptionPlanModel, required this.onContainClick});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: SubscriptionController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final selected = controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id;
        final isCurrent = controller.userModel.value.subscriptionPlanId == subscriptionPlanModel.id;
        final fg = selected ? Colors.white : c.textPrimary;
        final fgMuted = selected ? Colors.white.withValues(alpha: 0.72) : c.textSecondary;
        final divider = selected ? Colors.white.withValues(alpha: 0.16) : c.divider;

        Widget bullet(String text) {
          return Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.check_circle_rounded, size: 16, color: selected ? c.brand : c.success),
                ),
                const DsGap(DsSpace.sm),
                Expanded(
                  child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySm.withColor(fg)),
                ),
              ],
            ),
          );
        }

        Widget limit(IconData icon, String text) {
          return Row(
            children: [
              Icon(icon, size: 18, color: fgMuted),
              const DsGap(DsSpace.sm),
              Expanded(
                child: Text(text, maxLines: 2, textAlign: TextAlign.start, style: t.bodySm.withColor(fg)),
              ),
            ],
          );
        }

        final br = BorderRadius.circular(DsRadius.xl);
        return Semantics(
          selected: selected,
          button: true,
          label: subscriptionPlanModel.name ?? '',
          child: DsPressable(
            child: AnimatedContainer(
              duration: DsMotion.of(context, DsMotion.slow),
              curve: DsMotion.emphasized,
              decoration: BoxDecoration(
                gradient: selected ? DsGradients.deep(context) : null,
                color: selected ? null : c.surface,
                borderRadius: br,
                border: Border.all(color: selected ? c.brand : (isCurrent ? c.success : c.border), width: selected || isCurrent ? 1.6 : 1),
                boxShadow: selected ? DsShadows.glow(context) : DsShadows.xs(context),
              ),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: br,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  splashColor: Colors.transparent,
                  onTap: onContainClick,
                  child: Padding(
                    padding: const EdgeInsets.all(DsSpace.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(DsSpace.xs),
                              decoration: BoxDecoration(color: selected ? Colors.white.withValues(alpha: 0.12) : c.surfaceAlt, borderRadius: DsRadius.brMd),
                              child: ClipRRect(
                                borderRadius: DsRadius.brSm,
                                child: NetworkImageWidget(imageUrl: subscriptionPlanModel.image ?? '', fit: BoxFit.cover, width: 44, height: 44),
                              ),
                            ),
                            const DsGap(DsSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(subscriptionPlanModel.name ?? '', style: t.title.withColor(fg)),
                                  const DsGap(DsSpace.xxs),
                                  Text(
                                    "${subscriptionPlanModel.description}",
                                    maxLines: 2,
                                    softWrap: true,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.bodySm.withColor(fgMuted),
                                  ),
                                ],
                              ),
                            ),
                            if (isCurrent) ...[
                              const DsGap(DsSpace.sm),
                              DsBadge(label: "Active".tr, tone: DsTone.success, style: DsBadgeStyle.solid, icon: Icons.verified_rounded, small: true),
                            ],
                          ],
                        ),
                        const DsGap(DsSpace.xl),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.end,
                          spacing: DsSpace.sm,
                          runSpacing: DsSpace.xxs,
                          children: [
                            Text(
                              subscriptionPlanModel.type == "free"
                                  ? "Free".tr
                                  : Constant.amountShow(amount: double.parse(subscriptionPlanModel.price ?? '0.0').toString()),
                              style: t.metricLg.withColor(fg),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                subscriptionPlanModel.expiryDay == "-1" ? "Lifetime".tr : "${subscriptionPlanModel.expiryDay} ${"Days".tr}",
                                style: t.label.withColor(fgMuted),
                              ),
                            ),
                          ],
                        ),
                        const DsGap(DsSpace.lg),
                        Divider(height: 1, thickness: 1, color: divider),
                        const DsGap(DsSpace.lg),
                        Wrap(
                          spacing: DsSpace.sm,
                          runSpacing: DsSpace.sm,
                          children:
                              subscriptionPlanModel.features?.toJson().entries.map((entry) {
                                return FeatureItem(title: entry.key, isActive: entry.value, selectedPlan: selected);
                              }).toList() ??
                              [],
                        ),
                        const DsGap(DsSpace.lg),
                        if (subscriptionPlanModel.id == Constant.commissionSubscriptionID)
                          bullet(
                            // Constant.userModel!.vendorID != null && Constant.userModel!.vendorID!.isNotEmpty
                            //     ? "Pay a commission of ${Constant.vendorAdminCommission?.commissionType == 'Percent' ? "${Constant.vendorAdminCommission?.amount} %" : "${Constant.amountShow(amount: Constant.vendorAdminCommission?.amount)} Flat"} on each order"
                            //         .tr
                            //     :
                            "${"Pay a commission of".tr} ${controller.selectedSectionModel.value.adminCommision!.commissionType == 'Percent' || controller.selectedSectionModel.value.adminCommision!.commissionType == 'percentage' ? "${controller.selectedSectionModel.value.adminCommision!.amount} %" : "${Constant.amountShow(amount: controller.selectedSectionModel.value.adminCommision!.amount)} ${'Flat'.tr}"} ${"on each order".tr}"
                                .tr,
                          ),
                        for (var index = 0; index < (subscriptionPlanModel.planPoints?.length ?? 0); index++)
                          bullet(subscriptionPlanModel.planPoints?[index] ?? ''),
                        const DsGap(DsSpace.sm),
                        Container(
                          padding: const EdgeInsets.all(DsSpace.md),
                          decoration: BoxDecoration(color: selected ? Colors.white.withValues(alpha: 0.08) : c.surfaceAlt, borderRadius: DsRadius.brMd),
                          child: Column(
                            children: [
                              limit(
                                Icons.inventory_2_outlined,
                                '${"Add item limits :".tr} ${subscriptionPlanModel.itemLimit == '-1' ? 'Unlimited'.tr : subscriptionPlanModel.itemLimit ?? '0'}',
                              ),
                              const DsGap(DsSpace.sm),
                              limit(
                                Icons.receipt_long_outlined,
                                '${'Accept order limits :'.tr} ${subscriptionPlanModel.orderLimit == '-1' ? 'Unlimited'.tr : subscriptionPlanModel.orderLimit ?? '0'}',
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const DsGap(DsSpace.xl),
                        selected
                            ? DsButton.primary(
                                label: isCurrent ? "Renew".tr : "Active".tr,
                                icon: isCurrent ? Icons.autorenew_rounded : Icons.arrow_forward_rounded,
                                expand: true,
                                onPressed: onClick,
                              )
                            : DsButton.secondary(label: isCurrent ? "Renew".tr : "Select Plan".tr, expand: true, onPressed: onClick),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

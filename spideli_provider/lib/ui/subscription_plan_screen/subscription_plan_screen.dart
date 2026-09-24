import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/subscription_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/sectionModel.dart';
import 'package:spideliprovider/model/subscription_plan_model.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/subscription_plan_screen/select_payment_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/widgets/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Plans (archetype J – subscription pricing). A pricing page: centred
/// headline, the section selector, then pricing cards where the selected plan
/// is a brand-gradient card and the rest are outlined. Two columns from tablet
/// width up, with equal-height rows so the cards read as a price comparison.
class SubscriptionPlanScreen extends StatelessWidget {
  final bool? isDrawer;

  const SubscriptionPlanScreen({this.isDrawer, super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<SubscriptionController>(
      init: SubscriptionController(),
      builder: (controller) {
        // Read synchronously so this GetX tracks them: the responsive /
        // item builders below run later and would not be observed.
        final List<SubscriptionPlanModel> plans = controller.subscriptionPlanList.toList();
        final bool sectionLocked = isDrawer == true || controller.isDropdownDisable.value == true;

        return controller.isLoading.value
            ? loader()
            : DsScaffold(
                appBar: controller.isShowAppBar.value ? const DsAppBar() : null,
                maxContentWidth: DsLayout.wideMax,
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: DsFadeSlideIn.stagger([
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Choose Your Business Plan".tr, textAlign: TextAlign.center, style: context.dsText.display),
                            const DsGap(DsSpace.sm),
                            Text(
                              "Select the most suitable business plan for your business to maximize your potential and access exclusive features.".tr,
                              textAlign: TextAlign.center,
                              style: context.dsText.bodySecondary,
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: DsSpace.xl),
                          child: sectionLocked
                              ? InkWell(
                                  borderRadius: DsRadius.brMd,
                                  onTap: () {
                                    ShowToastDialog.showToast("You are not able to change section. because of your plan is purchased on ${selectedSectionModel!.name} section");
                                  },
                                  child: DsTextField(
                                    label: 'Section'.tr,
                                    hint: 'Section'.tr,
                                    initialValue: "${controller.selectedSectionModeldata.value.name} (${controller.selectedSectionModeldata.value.serviceType})",
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.streetAddress,
                                    enabled: false,
                                    suffix: const Icon(Icons.lock_outline_rounded, size: 18),
                                    bottomSpacing: 0,
                                  ),
                                )
                              : DsDropdown<SectionModel>(
                                  label: 'Section'.tr,
                                  hint: 'Select Section'.tr,
                                  prefixIcon: Icons.category_outlined,
                                  validator: (value) => value == null ? 'field required' : null,
                                  value: controller.selectedSectionModeldata.value.id == null || controller.selectedSectionModeldata.value.id == '' ? null : controller.selectedSectionModeldata.value,
                                  onChanged: (value) {
                                    controller.selectedSectionModeldata.value = value!;
                                    controller.subscriptionPlanList.clear();
                                    controller.getSubscriptionPlanList();
                                  },
                                  bottomSpacing: 0,
                                  items: controller.sectionsVal.map((SectionModel item) {
                                    return DropdownMenuItem<SectionModel>(
                                      value: item,
                                      child: Text("${item.name} (${item.serviceType})", overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList(),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: DsSpace.xl),
                          child: controller.isLoading.value
                              ? loader()
                              : plans.isEmpty
                              ? DsEmptyState(
                                  icon: Icons.workspace_premium_outlined,
                                  title: "${"Oops! The selected section doesn't have a subscription plan. Please contact the admin.".tr}\n$adminEmail",
                                )
                              : DsResponsiveBuilder(
                                  builder: (context, l) {
                                    final List<Widget> cards = [
                                      for (final SubscriptionPlanModel subscriptionPlanModel in plans)
                                        SubscriptionPlanWidget(
                                          onContainClick: () {
                                            controller.selectedSubscriptionPlan.value = subscriptionPlanModel;
                                            controller.totalAmount.value = double.parse(subscriptionPlanModel.price ?? '0.0');
                                            controller.update();
                                          },
                                          onClick: () {
                                            if (controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id) {
                                              if (controller.selectedSubscriptionPlan.value.type == 'free' || controller.selectedSubscriptionPlan.value.isCommissionPlan == true) {
                                                controller.selectedPaymentMethod.value = 'free';
                                                controller.setOrder();
                                              } else {
                                                Get.to(const SelectPaymentScreen());
                                              }
                                            }
                                          },
                                          type: 'Plan',
                                          subscriptionPlanModel: subscriptionPlanModel,
                                        ),
                                    ];
                                    if (l.isWide) {
                                      return DsAdaptiveGrid(minItemWidth: 340, children: cards);
                                    }
                                    return Column(
                                      children: [
                                        for (int i = 0; i < cards.length; i++)
                                          Padding(
                                            padding: EdgeInsets.only(bottom: i == cards.length - 1 ? 0 : DsSpace.lg),
                                            child: cards[i],
                                          ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
      },
    );
  }
}

/// One feature of a plan, ticked or crossed.
class FeatureItem extends StatelessWidget {
  final String title;
  final bool isActive;
  final bool selectedPlan;

  const FeatureItem({super.key, required this.title, required this.isActive, required this.selectedPlan});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final Color labelColor = selectedPlan ? Colors.white : c.textPrimary;
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isActive == true
              ? SvgPicture.asset('assets/icons/ic_check.svg', colorFilter: ColorFilter.mode(selectedPlan ? Colors.white : c.success, BlendMode.srcIn))
              : SvgPicture.asset('assets/icons/ic_close.svg', colorFilter: ColorFilter.mode(selectedPlan ? Colors.white70 : c.danger, BlendMode.srcIn)),
          const DsGap(DsSpace.xs),
          Expanded(
            child: Text(
              title == 'chat'
                  ? 'Chat'
                  : title == 'dineIn'
                  ? "DineIn"
                  : title == 'ownerMobileApp'
                  ? 'Service Provider Mobile App'
                  : '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.dsText.bodySm.withColor(labelColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// A pricing card. Selected = brand-gradient with white content; otherwise an
/// outlined card that picks up a brand border when it is the current plan.
class SubscriptionPlanWidget extends StatelessWidget {
  final VoidCallback onClick;
  final VoidCallback onContainClick;
  final String type;
  final SubscriptionPlanModel subscriptionPlanModel;

  const SubscriptionPlanWidget({super.key, required this.onClick, required this.type, required this.subscriptionPlanModel, required this.onContainClick});

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return GetX<SubscriptionController>(
      init: SubscriptionController(),
      builder: (controller) {
        final bool selected = controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id;
        final bool isCurrent = controller.userModel.value.subscriptionPlanId == subscriptionPlanModel.id;
        final c = context.dsColors;
        final t = context.dsText;
        final Color onCard = selected ? Colors.white : c.textPrimary;
        final Color onCardMuted = selected ? Colors.white70 : c.textSecondary;
        final Color rule = selected ? Colors.white24 : c.divider;

        final Widget body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: DsRadius.brMd,
                  child: NetworkImageWidget(imageUrl: subscriptionPlanModel.image ?? '', fit: BoxFit.cover, width: 50, height: 50),
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subscriptionPlanModel.name ?? '', style: t.title.withColor(onCard)),
                      const DsGap(DsSpace.xxs),
                      Text("${subscriptionPlanModel.description}", maxLines: 2, softWrap: true, style: t.bodySm.withColor(onCardMuted)),
                    ],
                  ),
                ),
                if (isCurrent) ...[
                  const DsGap(DsSpace.sm),
                  DsBadge(label: "Active".tr, tone: DsTone.success, style: selected ? DsBadgeStyle.solid : DsBadgeStyle.soft, icon: Icons.check_circle_rounded, small: true),
                ],
              ],
            ),
            const DsGap(DsSpace.lg),
            Text(subscriptionPlanModel.type == "free" ? "Free" : amountShow(amount: double.parse(subscriptionPlanModel.price ?? '0.0').toString()), style: t.metric.tabular.withColor(onCard)),
            const DsGap(DsSpace.xxs),
            Text(subscriptionPlanModel.expiryDay == "-1" ? "Lifetime" : "${subscriptionPlanModel.expiryDay} Days", style: t.caption.withColor(onCardMuted)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpace.lg),
              child: Divider(height: 1, thickness: 1, color: rule),
            ),
            Wrap(
              spacing: 0,
              runSpacing: DsSpace.md,
              children:
                  subscriptionPlanModel.features?.toJson().entries.map((entry) {
                    Widget widget = entry.key == 'qrCodeGenerate' ? SizedBox() : FeatureItem(title: entry.key, isActive: entry.value, selectedPlan: selected);
                    return widget;
                  }).toList() ??
                  [],
            ),
            if (subscriptionPlanModel.isCommissionPlan == true)
              _Bullet(
                color: onCard,
                text: MyAppState.currentUser?.adminCommission != null
                    ? "Pay a commission of ${MyAppState.currentUser?.adminCommission?.type == 'percentage' ? "${MyAppState.currentUser?.adminCommission?.commission ?? 0}%" : "${amountShow(amount: "${MyAppState.currentUser?.adminCommission?.commission ?? 0}")} Flat"} on each booking."
                    : "Pay a commission of ${controller.selectedSectionModeldata.value.adminCommision?.type == 'percentage' ? "${controller.selectedSectionModeldata.value.adminCommision?.commission ?? 0}%" : "${amountShow(amount: "${controller.selectedSectionModeldata.value.adminCommision?.commission ?? 0}")} Flat"} on each booking."
                          .tr,
              ),
            for (int index = 0; index < (subscriptionPlanModel.planPoints?.length ?? 0); index++) _Bullet(color: onCard, text: subscriptionPlanModel.planPoints?[index] ?? ''),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpace.lg),
              child: Divider(height: 1, thickness: 1, color: rule),
            ),
            Wrap(
              spacing: DsSpace.sm,
              runSpacing: DsSpace.sm,
              children: [
                _LimitChip(selected: selected, label: 'Add service limits : ${subscriptionPlanModel.itemLimit == '-1' ? 'Unlimited' : subscriptionPlanModel.itemLimit ?? '0'}'),
                _LimitChip(selected: selected, label: 'Accept booking limits : ${subscriptionPlanModel.orderLimit == '-1' ? 'Unlimited' : subscriptionPlanModel.orderLimit ?? '0'}'),
              ],
            ),
            const DsGap(DsSpace.xl),
            selected
                ? DsButton.primary(label: isCurrent ? "Renew" : "Active".tr, icon: isCurrent ? Icons.autorenew_rounded : Icons.check_rounded, color: Colors.white, expand: true, onPressed: onClick)
                : DsButton.secondary(label: isCurrent ? "Renew" : "Select Plan".tr, icon: isCurrent ? Icons.autorenew_rounded : Icons.arrow_forward_rounded, expand: true, onPressed: onClick),
          ],
        );

        return selected
            ? DsCard.gradient(onTap: onContainClick, padding: const EdgeInsets.all(DsSpace.xl), child: body)
            : DsCard.outlined(onTap: onContainClick, borderColor: isCurrent ? c.brand : null, padding: const EdgeInsets.all(DsSpace.xl), child: body);
      },
    );
  }
}

/// Bullet line inside a plan card.
class _Bullet extends StatelessWidget {
  final String text;
  final Color color;

  const _Bullet({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: t.body.withColor(color)),
          Expanded(child: Text(text, maxLines: 2, style: t.body.withColor(color))),
        ],
      ),
    );
  }
}

/// Plan limit shown as a chip so the two limits read as specs, not paragraphs.
class _LimitChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _LimitChip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    if (!selected) return DsBadge(label: label, tone: DsTone.neutral, style: DsBadgeStyle.soft);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: DsRadius.brPill),
      child: Text(label, style: t.labelSm.withColor(Colors.white)),
    );
  }
}

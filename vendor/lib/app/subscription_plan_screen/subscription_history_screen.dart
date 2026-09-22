import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/subscription_history_controller.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/network_image_widget.dart';

class SubscriptionHistoryScreen extends StatelessWidget {
  const SubscriptionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: SubscriptionHistoryController(),
      builder: (controller) {
        return DsScaffold.collapsing(
          title: "Purchase History".tr,
          slivers: [
            if (controller.isLoading.value)
              const SliverToBoxAdapter(child: DsSkeletonList(itemCount: 4))
            else if (controller.subscriptionHistoryList.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: DsEmptyState(icon: Icons.receipt_long_outlined, title: "Purchase History Not found".tr),
                ),
              )
            else
              DsSliverResponsive(
                top: DsSpace.sm,
                sliver: SliverList.builder(
                  itemCount: controller.subscriptionHistoryList.length,
                  itemBuilder: (context, index) {
                    final subscriptionHistoryModel = controller.subscriptionHistoryList[index];
                    final c = context.dsColors;
                    final t = context.dsText;
                    final isActive = index == 0;

                    Widget row(IconData icon, String label, String value) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: DsSpace.xs + 2),
                        child: Row(
                          children: [
                            Icon(icon, size: 18, color: c.textMuted),
                            const DsGap(DsSpace.sm),
                            Expanded(child: Text(label, maxLines: 2, style: t.bodySm.withColor(c.textSecondary))),
                            const DsGap(DsSpace.sm),
                            Flexible(
                              child: Text(value, textAlign: TextAlign.end, maxLines: 2, style: t.bodyStrong.tabular),
                            ),
                          ],
                        ),
                      );
                    }

                    return DsFadeSlideIn(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: DsSpace.md),
                        child: DsCard(
                          padding: EdgeInsets.zero,
                          borderColor: isActive ? c.success : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(DsSpace.lg),
                                color: isActive ? c.successSoft : null,
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: DsRadius.brMd,
                                      child: NetworkImageWidget(
                                        imageUrl: subscriptionHistoryModel.subscriptionPlan?.image ?? '',
                                        fit: BoxFit.cover,
                                        width: 48,
                                        height: 48,
                                      ),
                                    ),
                                    const DsGap(DsSpace.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(subscriptionHistoryModel.subscriptionPlan?.name ?? '', textAlign: TextAlign.start, style: t.titleSm),
                                          const DsGap(DsSpace.xxs),
                                          Text(
                                            Constant.amountShow(amount: subscriptionHistoryModel.subscriptionPlan?.price ?? '0'),
                                            style: t.label.tabular.withColor(c.brandStrong),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isActive) DsStatusChip(label: 'Active'.tr, tone: DsTone.success, pulse: true),
                                  ],
                                ),
                              ),
                              Divider(height: 1, thickness: 1, color: c.divider),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, DsSpace.md),
                                child: Column(
                                  children: [
                                    row(
                                      Icons.timelapse_rounded,
                                      'Validity'.tr,
                                      subscriptionHistoryModel.subscriptionPlan?.expiryDay == '-1'
                                          ? "Unlimited".tr
                                          : '${subscriptionHistoryModel.subscriptionPlan?.expiryDay ?? '0'}  Days',
                                    ),
                                    row(Icons.sell_outlined, 'Price'.tr, Constant.amountShow(amount: subscriptionHistoryModel.subscriptionPlan?.price ?? '0')),
                                    row(Icons.credit_card_rounded, 'Payment Type'.tr, (subscriptionHistoryModel.paymentType ?? '').capitalizeString()),
                                    row(
                                      Icons.event_available_rounded,
                                      'Purchase Date'.tr,
                                      Constant.timestampToDateTime(subscriptionHistoryModel.subscriptionPlan!.createdAt!),
                                    ),
                                    row(
                                      Icons.event_busy_rounded,
                                      'Expiry Date'.tr,
                                      subscriptionHistoryModel.expiryDate == null
                                          ? "Unlimited".tr
                                          : Constant.timestampToDateTime(subscriptionHistoryModel.expiryDate!),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

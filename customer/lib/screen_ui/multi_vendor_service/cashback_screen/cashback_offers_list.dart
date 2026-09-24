import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cashback_controller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Archetype **G — offers ledger**: each cashback deal is a coupon-style card
/// with the reward as the headline metric and the conditions underneath.
class CashbackOffersListScreen extends StatelessWidget {
  const CashbackOffersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: CashbackController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final loading = controller.isLoading.value;
        final offers = controller.cashbackList.toList();
        return DsScaffold(
          title: "Cashback Offers".tr,
          maxContentWidth: DsLayout.contentMax,
          body: DsAsync(
            isLoading: loading,
            skeleton: const DsSkeletonList(itemCount: 4, leading: false, trailing: false),
            isEmpty: offers.isEmpty,
            empty: DsEmptyState(icon: Icons.savings_outlined, title: "Cashback Offers".tr, message: "New cashback deals will appear here.".tr),
            builder: (_) => ListView.builder(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
              itemCount: offers.length,
              itemBuilder: (BuildContext context, int index) {
                final offer = offers[index];
                final reward = offer.cashbackType == 'Percent'
                    ? "${offer.cashbackAmount}%"
                    : Constant.amountShow(amount: "${offer.cashbackAmount}", currency: RegionService.customerCurrency);
                return DsFadeSlideIn(
                  index: index,
                  child: DsCard(
                    margin: const EdgeInsets.only(bottom: DsSpace.md),
                    padding: const EdgeInsets.all(DsSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DsIconWell(icon: Icons.savings_outlined, tone: DsTone.success, size: 44),
                            const DsGap(DsSpace.md),
                            Expanded(child: Text(offer.title ?? '', style: t.titleSm)),
                            const DsGap(DsSpace.sm),
                            DsBadge(label: reward, tone: DsTone.success, style: DsBadgeStyle.solid),
                          ],
                        ),
                        const DsGap(DsSpace.md),
                        DsDivider(spacing: DsSpace.xs),
                        const DsGap(DsSpace.md),
                        _InfoLine(
                          icon: Icons.shopping_bag_outlined,
                          text:
                              "${"Min spent".tr} ${Constant.amountShow(amount: "${offer.minimumPurchaseAmount ?? 0.0}", currency: RegionService.customerCurrency)} | ${"Valid till".tr} ${Constant.timestampToDateTime2(offer.endDate!)}",
                        ),
                        const DsGap(DsSpace.sm),
                        _InfoLine(
                          icon: Icons.trending_up_rounded,
                          color: c.brandStrong,
                          text: "${"Maximum cashback up to".tr} ${Constant.amountShow(amount: "${offer.maximumDiscount ?? 0.0}", currency: RegionService.customerCurrency)}",
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Icon + text condition line inside an offer card.
class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _InfoLine({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color ?? c.textMuted),
        const DsGap(DsSpace.sm),
        Expanded(child: Text(text, style: color == null ? t.bodySm : t.bodySm.withColor(color!))),
      ],
    );
  }
}

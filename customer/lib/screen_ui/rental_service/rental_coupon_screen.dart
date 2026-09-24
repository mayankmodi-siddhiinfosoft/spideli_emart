import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/rental_coupon_controller.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/widget/my_separator.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Rental coupons (archetype B — catalogue): each offer leads with a round
/// discount medallion, then the code chip and the terms under a dashed rule.
class RentalCouponScreen extends StatelessWidget {
  const RentalCouponScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.dsLayout;
    return GetX(
      init: RentalCouponController(),
      builder: (controller) {
        final bool loading = controller.isLoading.value;
        final List<CouponModel> coupons = controller.cabCouponList.toList();
        return DsScaffold(
          title: "Coupon".tr,
          onBack: () => Get.back(),
          maxContentWidth: DsLayout.contentMax,
          body: DsAsync(
            isLoading: loading,
            skeleton: const DsSkeletonList(itemCount: 4),
            isEmpty: coupons.isEmpty,
            empty: DsEmptyState(icon: Icons.local_activity_outlined, title: "Coupon not found".tr),
            builder: (context) => ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
              itemCount: coupons.length,
              itemBuilder: (context, index) {
                return DsFadeSlideIn(index: index, child: _RentalCouponCard(coupon: coupons[index]));
              },
            ),
          ),
        );
      },
    );
  }
}

class _RentalCouponCard extends StatelessWidget {
  final CouponModel coupon;

  const _RentalCouponCard({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final String discount =
        "${coupon.discountType == "Fix Price" ? Constant.amountShow(amount: coupon.discount, currency: RegionService.customerCurrency) : "${coupon.discount}%"} ${'Off'.tr}";
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.lg),
      semanticLabel: discount,
      onTap: () {
        Get.back(result: coupon);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(DsSpace.xs),
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: DsGradients.brand(context)),
                child: Text(
                  discount,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelSm.withColor(Colors.white),
                ),
              ),
              const DsGap(DsSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: DsRadius.brSm,
                        border: Border.all(color: c.borderStrong),
                      ),
                      child: Text("${coupon.code}", maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label.tabular),
                    ),
                    const DsGap(DsSpace.sm),
                    Row(
                      children: [
                        Text("Tap To Apply".tr, style: t.link),
                        const DsGap(DsSpace.xs),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: c.brandStrong),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const DsGap(DsSpace.lg),
          MySeparator(color: c.divider),
          const DsGap(DsSpace.lg),
          Text("${coupon.description}", style: t.bodySecondary),
        ],
      ),
    );
  }
}

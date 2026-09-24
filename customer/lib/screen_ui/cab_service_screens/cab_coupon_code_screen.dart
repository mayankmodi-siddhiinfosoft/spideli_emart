import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cab_coupon_code_controller.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Ride coupons (archetype B — list): torn-ticket rows where a gradient stub
/// carries the discount and the body carries the dotted code, the apply
/// action and the terms.
class CabCouponCodeScreen extends StatelessWidget {
  const CabCouponCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: CabCouponCodeController(),
      builder: (controller) {
        final loading = controller.isLoading.value;
        final coupons = controller.cabCouponList;
        return DsScaffold.collapsing(
          title: "Coupon".tr,
          subtitle: loading || coupons.isEmpty ? null : "${coupons.length} ${'available'.tr}",
          onBack: () => Get.back(),
          slivers: [
            if (loading)
              const SliverToBoxAdapter(child: DsSkeletonList(itemCount: 4, trailing: false))
            else if (coupons.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: Constant.showEmptyView(message: "Coupon not found".tr))
            else
              DsSliverResponsive(
                maxWidth: DsLayout.contentMax,
                bottom: DsSpace.xxl,
                sliver: SliverList.separated(
                  itemCount: coupons.length,
                  separatorBuilder: (context, index) => const DsGap(DsSpace.md),
                  itemBuilder: (context, index) {
                    final CouponModel couponModel = coupons[index];
                    return DsFadeSlideIn(
                      index: index,
                      child: _CouponTicket(couponModel: couponModel),
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

/// One coupon: gradient stub + code, apply action and description.
class _CouponTicket extends StatelessWidget {
  final CouponModel couponModel;

  const _CouponTicket({required this.couponModel});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final discount = couponModel.discountType == "Fix Price" ? Constant.amountShow(amount: couponModel.discount, currency: RegionService.customerCurrency) : "${couponModel.discount}%";
    return DsCard.outlined(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Discount stub. The brand gradient is deepened for light accents
            // (cab amber), so white stays readable on it.
            Container(
              width: 96,
              decoration: BoxDecoration(gradient: DsGradients.brand(context)),
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.lg),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(discount, textAlign: TextAlign.center, style: t.title.withColor(Colors.white).tabular),
                  ),
                  const DsGap(DsSpace.xxs),
                  Text('Off'.tr, textAlign: TextAlign.center, style: t.overline.withColor(Colors.white.withValues(alpha: 0.88))),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DsSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: DsSpace.sm,
                      runSpacing: DsSpace.sm,
                      children: [
                        DottedBorder(
                          options: RoundedRectDottedBorderOptions(strokeWidth: 1, radius: const Radius.circular(DsRadius.xs), color: c.borderStrong),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                            child: Text("${couponModel.code}", style: t.label.withColor(c.textSecondary).tabular),
                          ),
                        ),
                        DsButton.ghost(
                          label: "Tap To Apply".tr,
                          size: DsButtonSize.sm,
                          trailingIcon: Icons.arrow_forward_rounded,
                          onPressed: () {
                            Get.back(result: couponModel);
                          },
                        ),
                      ],
                    ),
                    const DsDivider(spacing: DsSpace.xl),
                    Text("${couponModel.description}", style: t.bodySm.withColor(c.textPrimary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

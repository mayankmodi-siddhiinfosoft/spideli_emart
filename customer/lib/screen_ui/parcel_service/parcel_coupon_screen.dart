import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/parcel_coupon_controller.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/widget/my_separator.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Parcel coupons (archetype B — catalogue): each offer is a torn ticket, with
/// the discount on a brand-gradient stub and the code on a dashed chip.
class ParcelCouponScreen extends StatelessWidget {
  const ParcelCouponScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.dsLayout;
    return GetX(
      init: ParcelCouponController(),
      builder: (controller) {
        final bool loading = controller.isLoading.value;
        final List<CouponModel> coupons = controller.cabCouponList.toList();
        return DsScaffold(
          title: "Coupon".tr,
          onBack: () => Get.back(),
          maxContentWidth: DsLayout.contentMax,
          body: DsAsync(
            isLoading: loading,
            skeleton: const DsSkeletonList(itemCount: 4, leading: false),
            isEmpty: coupons.isEmpty,
            empty: DsEmptyState(icon: Icons.local_activity_outlined, title: "Coupon not found".tr),
            builder: (context) => ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
              itemCount: coupons.length,
              itemBuilder: (context, index) {
                return DsFadeSlideIn(index: index, child: ParcelCouponTicket(coupon: coupons[index]));
              },
            ),
          ),
        );
      },
    );
  }
}

/// One coupon ticket: gradient stub + code + description, shared by the parcel
/// and rental coupon lists.
class ParcelCouponTicket extends StatelessWidget {
  final CouponModel coupon;

  const ParcelCouponTicket({super.key, required this.coupon});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final String discount =
        "${coupon.discountType == "Fix Price" ? Constant.amountShow(amount: coupon.discount, currency: RegionService.customerCurrency) : "${coupon.discount}%"} ${'Off'.tr}";
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: EdgeInsets.zero,
      semanticLabel: discount,
      onTap: () {
        Get.back(result: coupon);
      },
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(gradient: DsGradients.brand(context)),
              child: RotatedBox(
                quarterTurns: -1,
                child: Text(
                  discount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSm.withColor(Colors.white),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DsSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                            decoration: BoxDecoration(
                              color: c.surfaceAlt,
                              borderRadius: DsRadius.brSm,
                              border: Border.all(color: c.borderStrong),
                            ),
                            child: Text("${coupon.code}", maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label.tabular),
                          ),
                        ),
                        const Expanded(child: SizedBox(height: 10)),
                        Text("Tap To Apply".tr, style: t.link),
                      ],
                    ),
                    const DsGap(DsSpace.lg),
                    MySeparator(color: c.divider),
                    const DsGap(DsSpace.lg),
                    Text("${coupon.description}", style: t.bodySecondary),
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

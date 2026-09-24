import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cart_controller.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../themes/show_toast_dialog.dart';

/// Archetype C — checkout helper. A redeem field pinned under the app bar,
/// then coupons as tear-off tickets: the discount sits on a brand stub, the
/// code and terms on the paper.
class CouponListScreen extends StatelessWidget {
  const CouponListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: CartController(),
      builder: (controller) {
        final List<CouponModel> coupons = controller.couponList.toList();
        return DsScaffold(
          maxContentWidth: DsLayout.contentMax,
          appBar: DsAppBar(
            title: "Coupon Code".tr,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(72),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.lg, DsSpace.md),
                child: DsTextField(
                  hint: 'Enter coupon code'.tr,
                  controller: controller.couponCodeController.value,
                  prefixIcon: Icons.confirmation_number_outlined,
                  bottomSpacing: 0,
                  suffix: DsButton.ghost(
                    label: "Apply".tr,
                    size: DsButtonSize.sm,
                    onPressed: () {
                      if (controller.couponCodeController.value.text.isEmpty) {
                        ShowToastDialog.showToast("Please enter coupon code".tr);
                        return;
                      }
                      CouponModel? matchedCoupon = controller.couponList.firstWhereOrNull((coupon) => coupon.code!.toLowerCase() == controller.couponCodeController.value.text.toLowerCase());
                      if (matchedCoupon != null) {
                        double couponAmount = Constant.calculateDiscount(amount: controller.subTotal.value.toString(), offerModel: matchedCoupon);

                        if (couponAmount < controller.subTotal.value) {
                          controller.selectedCouponModel.value = matchedCoupon;
                          controller.calculatePrice();
                          Get.back();
                        } else {
                          ShowToastDialog.showToast("Coupon code not applied".tr);
                        }
                      } else {
                        ShowToastDialog.showToast("Invalid Coupon".tr);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          body: coupons.isEmpty
              ? DsEmptyState(icon: Icons.local_offer_outlined, title: "Coupon Code".tr, message: "Enter coupon code".tr)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxl),
                  itemCount: coupons.length,
                  itemBuilder: (context, index) {
                    final CouponModel couponModel = coupons[index];
                    return DsFadeSlideIn(
                      index: index,
                      child: _CouponTicket(
                        couponModel: couponModel,
                        currency: controller.storeCurrency,
                        onApply: () {
                          double couponAmount = Constant.calculateDiscount(amount: controller.subTotal.value.toString(), offerModel: couponModel);

                          if (couponAmount < controller.subTotal.value) {
                            controller.selectedCouponModel.value = couponModel;
                            controller.calculatePrice();
                            Get.back();
                          } else {
                            ShowToastDialog.showToast("Coupon code not applied".tr);
                          }
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _CouponTicket extends StatelessWidget {
  final CouponModel couponModel;
  final CurrencyModel? currency;
  final VoidCallback onApply;
  const _CouponTicket({required this.couponModel, required this.currency, required this.onApply});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 76,
              decoration: BoxDecoration(gradient: DsGradients.brand(context)),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: DsSpace.lg, horizontal: DsSpace.sm),
              child: RotatedBox(
                quarterTurns: -1,
                child: Text(
                  "${couponModel.discountType == "Fix Price" ? Constant.amountShow(amount: couponModel.discount, currency: currency) : "${couponModel.discount}%"} ${'Off'.tr}",
                  textAlign: TextAlign.center,
                  style: t.titleSm.tabular.withColor(c.onBrand),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DsSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                            decoration: BoxDecoration(
                              color: c.surfaceAlt,
                              borderRadius: DsRadius.brSm,
                              border: Border.all(color: c.borderStrong, style: BorderStyle.solid),
                            ),
                            child: Text("${couponModel.code}", maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label.tabular),
                          ),
                        ),
                        const Expanded(child: SizedBox(height: DsSpace.md)),
                        DsButton.ghost(label: "Tap To Apply".tr, size: DsButtonSize.sm, onPressed: onApply),
                      ],
                    ),
                    const DsGap(DsSpace.md),
                    const DsDivider(spacing: 0),
                    const DsGap(DsSpace.md),
                    Text("${couponModel.description}", style: t.bodySecondary),
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

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/app/offer_screens/add_edit_offer_screen.dart';
import 'package:vendor/app/offer_screens/widgets/coupon_ticket.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/offer_controller.dart';
import 'package:vendor/models/coupon_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/network_image_widget.dart';

class OfferScreen extends StatelessWidget {
  const OfferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: OfferController(),
      builder: (controller) {
        return DsScaffold.collapsing(
          title: "Offers".tr,
          subtitle: controller.isLoading.value || controller.offerList.isEmpty ? null : '${controller.offerList.length} ${"Offers".tr}',
          onRefresh: controller.getOffers,
          slivers: [
            if (controller.isLoading.value)
              const DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                top: DsSpace.sm,
                sliver: SliverToBoxAdapter(child: DsSkeletonList(itemCount: 5, padding: EdgeInsets.zero)),
              )
            else if (controller.offerList.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(icon: Icons.confirmation_number_outlined, title: "No Offer found".tr),
              )
            else
              DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                top: DsSpace.sm,
                bottom: 88,
                sliver: SliverToBoxAdapter(
                  child: DsAdaptiveGrid(
                    minItemWidth: 380,
                    maxColumns: 2,
                    equalHeight: false,
                    spacing: DsSpace.lg,
                    runSpacing: DsSpace.md,
                    children: [
                      for (int index = 0; index < controller.offerList.length; index++)
                        DsFadeSlideIn(index: index, child: _couponCard(context, controller, controller.offerList[index])),
                    ],
                  ),
                ),
              ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add_rounded),
            label: Text("Create Offer".tr),
            onPressed: () {
              Get.to(const AddEditOfferScreen())!.then((value) {
                if (value == true) {
                  controller.getOffers();
                }
              });
            },
          ),
        );
      },
    );
  }

  Widget _couponCard(BuildContext context, OfferController controller, CouponModel couponModel) {
    final c = context.dsColors;
    final t = context.dsText;
    final isExpired = couponModel.expiresAt != null && couponModel.expiresAt!.toDate().isBefore(DateTime.now());
    return CouponTicket(
      stubGradient: isExpired ? DsGradients.tone(context, DsTone.neutral) : null,
      stub: CouponStubLabel(
        icon: couponModel.discountType == "Fix Price" ? Icons.payments_outlined : Icons.percent_rounded,
        text: (couponModel.discountType == "Fix Price" ? "${Constant.amountShow(amount: couponModel.discount)} ${"Off".tr}" : "${couponModel.discount} % ${"Off".tr}").tr,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: DsRadius.brSm,
                child: NetworkImageWidget(imageUrl: couponModel.image.toString(), height: 44, width: 44, fit: BoxFit.cover),
              ),
              const DsGap(DsSpace.sm),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DottedBorder(
                    options: RoundedRectDottedBorderOptions(radius: const Radius.circular(DsRadius.sm), dashPattern: const [5, 4], color: c.brand.withValues(alpha: 0.6)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs + 2),
                      decoration: BoxDecoration(color: c.brandSoft, borderRadius: DsRadius.brSm),
                      child: Text(
                        "${couponModel.code}".tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleSm.copyWith(color: c.brandStrong, letterSpacing: 1.2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const DsGap(DsSpace.sm),
          Wrap(
            spacing: DsSpace.xs,
            runSpacing: DsSpace.xs,
            children: [
              if (isExpired) DsBadge(label: "Expired".tr, tone: DsTone.danger, small: true, icon: Icons.history_toggle_off_rounded),
              if (couponModel.isEnabled == true) DsBadge(label: "Active".tr, tone: DsTone.success, small: true),
              if (couponModel.isPublic == true) DsBadge(label: "Public".tr, tone: DsTone.info, small: true, icon: Icons.public_rounded),
            ],
          ),
          const DsGap(DsSpace.sm),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 15, color: isExpired ? c.dangerStrong : c.textMuted),
              const DsGap(DsSpace.xs),
              Expanded(
                child: Text(
                  "${"This offer is expire on".tr} ${Constant.timestampToDateTime(couponModel.expiresAt!)}".tr,
                  style: t.caption.withColor(isExpired ? c.dangerStrong : c.textSecondary),
                ),
              ),
            ],
          ),
          const DsGap(DsSpace.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DsIconButton(
                icon: Icons.edit_outlined,
                semanticLabel: "Edit Offer".tr,
                variant: DsIconButtonVariant.tonal,
                size: 36,
                onPressed: () {
                  Get.to(const AddEditOfferScreen(), arguments: {"couponModel": couponModel})!.then((value) {
                    if (value == true) {
                      controller.getOffers();
                    }
                  });
                },
              ),
              DsIconButton(
                icon: Icons.delete_outline_rounded,
                semanticLabel: "Delete".tr,
                variant: DsIconButtonVariant.tonal,
                color: c.dangerStrong,
                size: 36,
                onPressed: () async {
                  ShowToastDialog.showLoader("Please wait".tr);
                  await FireStoreUtils.deleteCoupon(couponModel).then((value) {
                    controller.getOffers();
                    ShowToastDialog.closeLoader();
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/screen_ui/rental_service/rental_coupon_screen.dart';
import 'package:customer/screen_ui/rental_service/widget/rental_common_widgets.dart';
import 'package:customer/screen_ui/rental_service/widget/rental_proposal_widgets.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import '../../controllers/rental_conformation_controller.dart';

/// Rental checkout (archetype C — cart / checkout): trip recap, the chosen
/// package and vehicle, the coupon block and the bill; "Book now" and the
/// "Propose my price" negotiation live together in the sticky bar.
class RentalConformationScreen extends StatelessWidget {
  const RentalConformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final l = context.dsLayout;
    return GetX(
      init: RentalConformationController(),
      builder: (controller) {
        final currency = RegionService.currencyForRecord(
          RegionService.regionOf(regionId: controller.rentalOrderModel.value.regionId, zoneId: controller.rentalOrderModel.value.zoneId),
        );
        return DsScaffold(
          title: "Confirm Rent a Car".tr,
          onBack: () {
            Get.back();
          },
          maxContentWidth: DsLayout.contentMax,
          body: controller.isLoading.value
              ? const DsSkeletonDetail(mediaHeight: 120)
              : ListView(
                  padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.xl, l.gutter, DsSpace.xxl),
                  children: DsFadeSlideIn.stagger([
                    RentalInfoCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const DsIconWell(icon: Icons.trip_origin_rounded, size: 40),
                          const DsGap(DsSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${controller.rentalOrderModel.value.sourceLocationName}", style: t.titleSm),
                                const DsGap(DsSpace.xxs),
                                Row(
                                  children: [
                                    Icon(Icons.event_rounded, size: 13, color: c.textMuted),
                                    const DsGap(DsSpace.xs),
                                    Expanded(
                                      child: Text(Constant.timestampToDate(controller.rentalOrderModel.value.bookingDateTime!), style: t.caption),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const DsGap(DsSpace.xl),
                    RentalInfoCard(
                      title: "Your Preference".tr,
                      icon: Icons.tune_rounded,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(controller.rentalOrderModel.value.rentalPackageModel!.name.toString(), style: t.title),
                                const DsGap(DsSpace.xs),
                                Text(controller.rentalOrderModel.value.rentalPackageModel!.description.toString(), style: t.bodySecondary),
                              ],
                            ),
                          ),
                          const DsGap(DsSpace.md),
                          Text(
                            Constant.amountShow(amount: controller.rentalOrderModel.value.rentalPackageModel!.baseFare.toString(), currency: currency),
                            style: t.title.tabular,
                          ),
                        ],
                      ),
                    ),
                    const DsGap(DsSpace.xl),
                    RentalInfoCard(
                      title: "Vehicle Type".tr,
                      icon: Icons.directions_car_filled_outlined,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DsImage(
                            url: controller.rentalOrderModel.value.rentalVehicleType!.rentalVehicleIcon.toString(),
                            height: 50,
                            width: 50,
                            radius: DsRadius.sm,
                            errorIcon: Icons.directions_car_outlined,
                          ),
                          const DsGap(DsSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${controller.rentalOrderModel.value.rentalVehicleType!.name}", style: t.title),
                                const DsGap(DsSpace.xxs),
                                Text("${controller.rentalOrderModel.value.rentalVehicleType!.shortDescription}", style: t.bodySecondary),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const DsGap(DsSpace.xl),
                    DsSectionHeader(
                      title: "Coupons".tr,
                      icon: Icons.local_activity_outlined,
                      padding: const EdgeInsets.only(bottom: DsSpace.md),
                      actionLabel: "View All".tr,
                      onAction: () {
                        Get.to(RentalCouponScreen())!.then((value) {
                          if (value != null) {
                            double couponAmount = Constant.calculateDiscount(amount: controller.subTotal.value.toString(), offerModel: value);
                            if (couponAmount < controller.subTotal.value) {
                              controller.selectedCouponModel.value = value;
                              controller.calculateAmount();
                            } else {
                              ShowToastDialog.showToast("This offer not eligible for this booking".tr);
                            }
                          }
                        });
                      },
                    ),

                    // Coupon input
                    DsCard.tinted(
                      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.md, DsSpace.md),
                      child: Row(
                        children: [
                          SvgPicture.asset("assets/icons/ic_coupon_parcel.svg", height: 28, width: 28),
                          const DsGap(DsSpace.md),
                          Expanded(
                            child: TextFormField(
                              controller: controller.couponController.value,
                              style: t.bodyStrong,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                hintText: "Write coupon code".tr,
                                hintStyle: t.bodySecondary,
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          const DsGap(DsSpace.sm),
                          DsButton.primary(
                            label: "Redeem now".tr,
                            size: DsButtonSize.sm,
                            onPressed: () {
                              if (controller.couponList.where((element) => element.code!.toLowerCase() == controller.couponController.value.text.toLowerCase()).isNotEmpty) {
                                CouponModel couponModel = controller.couponList.firstWhere((p0) => p0.code!.toLowerCase() == controller.couponController.value.text.toLowerCase());
                                if (couponModel.expiresAt!.toDate().isAfter(DateTime.now())) {
                                  double couponAmount = Constant.calculateDiscount(amount: controller.subTotal.value.toString(), offerModel: couponModel);
                                  if (couponAmount < controller.subTotal.value) {
                                    controller.selectedCouponModel.value = couponModel;
                                    controller.calculateAmount();
                                    controller.update();
                                  } else {
                                    ShowToastDialog.showToast("This offer not eligible for this booking".tr);
                                  }
                                } else {
                                  ShowToastDialog.showToast("This coupon code has been expired".tr);
                                }
                              } else {
                                ShowToastDialog.showToast("Invalid coupon code".tr);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const DsGap(DsSpace.lg),
                    RentalInfoCard(
                      title: "Order Summary".tr,
                      icon: Icons.receipt_long_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Subtotal
                          RentalSummaryRow(label: "Subtotal".tr, value: Constant.amountShow(amount: controller.subTotal.value.toString(), currency: currency)),

                          // Discount
                          RentalSummaryRow(
                            label: "Discount".tr,
                            value: Constant.amountShow(amount: controller.discount.value.toString(), currency: currency),
                            tone: DsTone.danger,
                          ),
                          if (Constant.platformFeeModel?.enable == true)
                            RentalSummaryRow(label: "Platform fee".tr, value: Constant.amountShow(amount: Constant.platformFeeModel?.fee.toString(), currency: currency)),
                          RentalSummaryRow(
                            label: "Tax amount".tr,
                            value: Constant.amountShow(amount: (controller.taxAmount.value).toString(), currency: currency),
                            underline: true,
                            onTap: () {
                              showBillBifurcationDialog(context, controller);
                            },
                          ),

                          const DsDivider(spacing: DsSpace.md),

                          // Total
                          RentalSummaryRow(label: "Order Total".tr, value: Constant.amountShow(amount: controller.totalAmount.value.toString(), currency: currency), emphasis: true),
                        ],
                      ),
                    ),
                  ]),
                ),
          bottomBar: controller.isLoading.value
              ? null
              : DsStickyBar(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text("Order Total".tr, style: t.bodySecondary)),
                          const DsGap(DsSpace.md),
                          Text(Constant.amountShow(amount: controller.totalAmount.value.toString(), currency: currency), style: t.title.tabular),
                        ],
                      ),
                      const DsGap(DsSpace.md),
                      DsButton.primary(
                        label: "Book now".tr,
                        icon: Icons.check_circle_outline_rounded,
                        size: DsButtonSize.lg,
                        expand: true,
                        onPressed: () {
                          controller.placeOrder();
                        },
                      ),
                      const DsGap(DsSpace.sm),
                      // Spec 4.9: book at the listed price above, or propose a price.
                      DsButton.secondary(
                        label: "Propose my price".tr,
                        icon: Icons.local_offer_outlined,
                        expand: true,
                        onPressed: () async {
                          final input = await showProposePriceSheet(
                            listedPrice: Constant.amountShow(amount: controller.subTotal.value.toString(), currency: currency),
                          );
                          if (input == null) return;
                          await controller.proposePrice(amount: input.amount, message: input.message);
                        },
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  void showBillBifurcationDialog(BuildContext context, RentalConformationController controller) {
    final currency = RegionService.currencyForRecord(
      RegionService.regionOf(regionId: controller.rentalOrderModel.value.regionId, zoneId: controller.rentalOrderModel.value.zoneId),
    );
    showDialog(
      context: context,
      builder: (context) {
        return DsDialog(
          title: "Tax Details".tr,
          icon: Icons.percent_rounded,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RentalSummaryRow(label: "Tax on Order Total".tr, value: Constant.amountShow(amount: controller.orderTaxAmount.value.toString(), currency: currency)),
              const DsDivider(spacing: DsSpace.md),
              RentalSummaryRow(label: "Tax on Platform Fee".tr, value: Constant.amountShow(amount: controller.platformTaxAmount.value.toString(), currency: currency)),
              const DsDivider(spacing: DsSpace.md),
              RentalSummaryRow(label: "Total Tax Amount".tr, value: Constant.amountShow(amount: controller.taxAmount.value.toString(), currency: currency), emphasis: true),
            ],
          ),
          primaryLabel: "Close".tr,
          onPrimary: () => Navigator.pop(context),
        );
      },
    );
  }
}

import 'package:customer/utils/region_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/on_demand_order_details_controller.dart';
import '../../constant/constant.dart';
import '../../themes/show_toast_dialog.dart';
import '../multi_vendor_service/chat_screens/chat_screen.dart';
import 'on_demand_payment_screen.dart';
import 'on_demand_review_screen.dart';
import 'package:customer/utils/order_receipt_pdf.dart';

/// Archetype F – booking detail: status hero, service recap, the people on
/// the job (worker / provider) and the bill, with the payment actions.
class OnDemandOrderDetailsScreen extends StatelessWidget {
  const OnDemandOrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: OnDemandOrderDetailsController(),
      builder: (controller) {
        final t = context.dsText;
        final l = context.dsLayout;
        final order = controller.onProviderOrder.value;
        final String status = order?.status ?? '';

        return DsScaffold(
          appBar: DsAppBar(
            title: "Order Details".tr,
            subtitle: status.isEmpty ? null : status,
            actions: [
              // PDF receipt: download / share (spec 7.6).
              if (controller.onProviderOrder.value != null)
                DsIconButton(
                  icon: Icons.receipt_long_outlined,
                  semanticLabel: "Order Details".tr,
                  variant: DsIconButtonVariant.tonal,
                  onPressed: () => OrderReceiptPdf.showOptions(context, () => OrderReceiptPdf.fromProviderOrder(controller)),
                ),
            ],
          ),
          maxContentWidth: DsLayout.contentMax,
          body:
              controller.isLoading.value
                  ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonDetail(mediaHeight: 120))
                  : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: DsFadeSlideIn.stagger([
                        if (status == Constant.orderCancelled)
                          DsInlineAlert(tone: DsTone.danger, title: 'Cancel Reason'.tr, message: controller.onProviderOrder.value?.reason ?? ''),
                        if (status == Constant.orderCancelled) const DsGap(DsSpace.md),

                        // Status + booking id + address hero.
                        DsCard.tinted(
                          tone: DsTone.fromStatus(status),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: DsStatusChip(label: status, status: status, pulse: status == Constant.orderOngoing)),
                                ],
                              ),
                              const DsGap(DsSpace.md),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: Text('Booking ID'.tr, style: t.bodySecondary)),
                                  const DsGap(DsSpace.sm),
                                  InkWell(
                                    onTap: () {
                                      final bookingId = controller.onProviderOrder.value?.id ?? '';
                                      if (bookingId.isEmpty) return;
                                      Clipboard.setData(ClipboardData(text: bookingId)).then((value) {
                                        SnackBar snackBar = SnackBar(
                                          content: Text("Booking ID Copied".tr, textAlign: TextAlign.center, style: t.bodyStrong.withColor(context.dsColors.onSurfaceInverse)),
                                          backgroundColor: context.dsColors.surfaceInverse,
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                      });
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            '# ${controller.onProviderOrder.value?.id ?? ''}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: t.bodyStrong.withColor(context.dsColors.brandStrong).tabular,
                                          ),
                                        ),
                                        const DsGap(DsSpace.xs),
                                        Icon(Icons.copy_rounded, size: 14, color: context.dsColors.brandStrong),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const DsDivider(spacing: DsSpace.md),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on_outlined, size: 18, color: context.dsColors.iconDefault),
                                  const DsGap(DsSpace.sm),
                                  Expanded(
                                    child: Text(
                                      "${'Booking Address :'.tr}  ${controller.onProviderOrder.value?.address?.getFullAddress()}",
                                      style: t.body,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const DsGap(DsSpace.md),

                        // Booked service.
                        DsCard.outlined(
                          padding: const EdgeInsets.all(DsSpace.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DsImage(
                                url:
                                    (controller.onProviderOrder.value != null && controller.onProviderOrder.value!.provider.photos.isNotEmpty)
                                        ? controller.onProviderOrder.value!.provider.photos.first
                                        : Constant.placeHolderImage,
                                height: 80,
                                width: 80,
                                radius: DsRadius.md,
                              ),
                              const DsGap(DsSpace.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(controller.onProviderOrder.value?.provider.title ?? "", style: t.titleSm),
                                    const DsGap(DsSpace.sm),
                                    Wrap(
                                      spacing: DsSpace.sm,
                                      runSpacing: DsSpace.xs,
                                      children: [
                                        DsBadge(
                                          label:
                                              '${'Date:'.tr} ${controller.onProviderOrder.value?.scheduleDateTime != null ? DateFormat('dd-MMM-yyyy').format(controller.onProviderOrder.value!.scheduleDateTime!.toDate()) : ""}',
                                          icon: Icons.event_outlined,
                                          small: true,
                                        ),
                                        DsBadge(
                                          label:
                                              '${'Time:'.tr} ${controller.onProviderOrder.value?.scheduleDateTime != null ? DateFormat('hh:mm a').format(controller.onProviderOrder.value!.scheduleDateTime!.toDate()) : ""}',
                                          icon: Icons.schedule_outlined,
                                          small: true,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Worker block.
                        (controller.onProviderOrder.value?.status == Constant.orderAccepted ||
                                    controller.onProviderOrder.value?.status == Constant.orderAssigned ||
                                    controller.onProviderOrder.value?.status == Constant.orderOngoing ||
                                    controller.onProviderOrder.value?.status == Constant.orderCompleted) &&
                                (controller.onProviderOrder.value?.workerId != null && controller.onProviderOrder.value!.workerId!.isNotEmpty)
                            ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DsSectionHeader(title: 'About Worker'.tr, icon: Icons.engineering_outlined),
                                DsCard.outlined(
                                  padding: const EdgeInsets.all(DsSpace.md),
                                  child: Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          DsAvatar(
                                            imageUrl: controller.worker.value?.profilePictureURL ?? '',
                                            name: controller.worker.value?.fullName(),
                                            size: 56,
                                            ring: true,
                                          ),
                                          const DsGap(DsSpace.md),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(controller.worker.value?.fullName() ?? '', style: t.titleSm),
                                                const DsGap(DsSpace.xs),
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(Icons.location_on_outlined, size: 15, color: context.dsColors.iconDefault),
                                                    const DsGap(DsSpace.xs),
                                                    Expanded(child: Text(controller.worker.value?.address ?? '', style: t.bodySm)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const DsGap(DsSpace.sm),
                                          // Rating Box
                                          DsBadge(
                                            label:
                                                (controller.worker.value != null && double.parse(controller.worker.value!.reviewsCount.toString()) != 0)
                                                    ? (double.parse(controller.worker.value!.reviewsSum.toString()) / double.parse(controller.worker.value!.reviewsCount.toString()))
                                                        .toStringAsFixed(1)
                                                    : '0',
                                            tone: DsTone.warning,
                                            icon: Icons.star_rounded,
                                            small: true,
                                          ),
                                        ],
                                      ),
                                      Visibility(
                                        visible: controller.onProviderOrder.value?.status == Constant.orderCompleted ? true : false,
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: DsSpace.md),
                                          child: DsButton.tonal(
                                            label: 'Add Review'.tr,
                                            icon: Icons.rate_review_outlined,
                                            expand: true,
                                            onPressed: () async {
                                              final result = await Get.to(() => OnDemandReviewScreen(), arguments: {'order': controller.onProviderOrder.value, 'reviewFor': "Worker"});

                                              // If review was submitted successfully
                                              if (result == true) {
                                                await controller.getData();
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      controller.onProviderOrder.value?.status == Constant.orderAccepted ||
                                              controller.onProviderOrder.value?.status == Constant.orderOngoing ||
                                              controller.onProviderOrder.value?.status == Constant.orderAssigned
                                          ? Padding(
                                            padding: const EdgeInsets.only(top: DsSpace.md),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: DsButton.secondary(
                                                    label: 'Call'.tr,
                                                    icon: Icons.call_rounded,
                                                    onPressed: () async {
                                                      Constant.makePhoneCall(controller.worker.value!.phoneNumber.toString());
                                                    },
                                                  ),
                                                ),
                                                const DsGap(DsSpace.md),
                                                Expanded(
                                                  child: DsButton.primary(
                                                    label: 'Chat'.tr,
                                                    icon: Icons.chat_bubble_outline_rounded,
                                                    onPressed: () async {
                                                      ShowToastDialog.showLoader("Please wait...".tr);
                                                      ShowToastDialog.closeLoader();

                                                      Get.to(
                                                        const ChatScreen(),
                                                        arguments: {
                                                          "senderName": Constant.userModel?.fullName(),
                                                          "receivedName": "${controller.worker.value?.firstName ?? ''} ${controller.worker.value?.lastName ?? ''}",
                                                          "orderId": controller.onProviderOrder.value?.id,
                                                          "receivedId": controller.worker.value?.id,
                                                          "senderId": Constant.userModel?.id,
                                                          "senderProfileUrl": Constant.userModel?.profilePictureURL,
                                                          "receivedProfileUrl": controller.worker.value?.profilePictureURL,
                                                          "token": controller.worker.value?.fcmToken,
                                                          "chatType": Constant.userRoleWorker,
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                          : SizedBox(),
                                    ],
                                  ),
                                ),
                              ],
                            )
                            : SizedBox(),

                        // Provider block.
                        DsSectionHeader(title: "About provider".tr, icon: Icons.storefront_outlined),
                        DsCard.outlined(
                          padding: const EdgeInsets.all(DsSpace.md),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DsAvatar(
                                    imageUrl: controller.providerUser.value?.profilePictureURL ?? '',
                                    name: controller.providerUser.value?.fullName(),
                                    size: 56,
                                    ring: true,
                                  ),
                                  const DsGap(DsSpace.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(controller.providerUser.value?.fullName() ?? '', style: t.titleSm),
                                        const DsGap(DsSpace.xs),
                                        Text(controller.providerUser.value?.email ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm),
                                      ],
                                    ),
                                  ),
                                  const DsGap(DsSpace.sm),
                                  // Rating Box
                                  DsBadge(
                                    label:
                                        (controller.providerUser.value != null && double.parse(controller.providerUser.value!.reviewsCount.toString()) != 0)
                                            ? (double.parse(controller.providerUser.value!.reviewsSum.toString()) / double.parse(controller.providerUser.value!.reviewsCount.toString()))
                                                .toStringAsFixed(1)
                                            : '0',
                                    tone: DsTone.warning,
                                    icon: Icons.star_rounded,
                                    small: true,
                                  ),
                                ],
                              ),
                              Visibility(
                                visible: controller.onProviderOrder.value?.status == Constant.orderCompleted ? true : false,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: DsSpace.md),
                                  child: DsButton.tonal(
                                    label: 'Add Review'.tr,
                                    icon: Icons.rate_review_outlined,
                                    expand: true,
                                    onPressed: () async {
                                      final result = await Get.to(() => OnDemandReviewScreen(), arguments: {'order': controller.onProviderOrder.value, 'reviewFor': "Provider"});
                                      if (result == true) {
                                        await controller.getData();
                                      }
                                    },
                                  ),
                                ),
                              ),
                              controller.onProviderOrder.value?.status == Constant.orderAccepted ||
                                      controller.onProviderOrder.value?.status == Constant.orderOngoing ||
                                      controller.onProviderOrder.value?.status == Constant.orderAssigned
                                  ? Padding(
                                    padding: const EdgeInsets.only(top: DsSpace.md),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: DsButton.secondary(
                                            label: 'Call'.tr,
                                            icon: Icons.call_rounded,
                                            onPressed: () async {
                                              Constant.makePhoneCall(controller.providerUser.value!.phoneNumber.toString());
                                            },
                                          ),
                                        ),
                                        if ((Constant.isSubscriptionModelApplied == false && Constant.sectionConstantModel?.adminCommision?.isEnabled == false) ||
                                            ((Constant.isSubscriptionModelApplied == true || Constant.sectionConstantModel?.adminCommision?.isEnabled == true) &&
                                                controller.onProviderOrder.value?.provider.subscriptionPlan?.features?.chat == true))
                                          const DsGap(DsSpace.md),
                                        if ((Constant.isSubscriptionModelApplied == false && Constant.sectionConstantModel?.adminCommision?.isEnabled == false) ||
                                            ((Constant.isSubscriptionModelApplied == true || Constant.sectionConstantModel?.adminCommision?.isEnabled == true) &&
                                                controller.onProviderOrder.value?.provider.subscriptionPlan?.features?.chat == true))
                                          Expanded(
                                            child: DsButton.primary(
                                              label: 'Chat'.tr,
                                              icon: Icons.chat_bubble_outline_rounded,
                                              onPressed: () async {
                                                ShowToastDialog.showLoader("Please wait...".tr);

                                                ShowToastDialog.closeLoader();

                                                Get.to(
                                                  const ChatScreen(),
                                                  arguments: {
                                                    "senderName": Constant.userModel?.fullName(),
                                                    "receivedName": "${controller.providerUser.value?.firstName ?? ''} ${controller.providerUser.value?.lastName ?? ''}",
                                                    "orderId": controller.onProviderOrder.value?.id,
                                                    "receivedId": controller.providerUser.value?.id,
                                                    "senderId": Constant.userModel?.id,
                                                    "senderProfileUrl": Constant.userModel?.profilePictureURL,
                                                    "receivedProfileUrl": controller.providerUser.value?.profilePictureURL,
                                                    "token": controller.providerUser.value?.fcmToken,
                                                    "chatType": Constant.userRoleProvider,
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  )
                                  : SizedBox(),
                            ],
                          ),
                        ),

                        // Bill.
                        (controller.onProviderOrder.value?.status != Constant.orderCompleted || controller.onProviderOrder.value?.status != Constant.orderCancelled) &&
                                controller.onProviderOrder.value?.provider.priceUnit == "Fixed"
                            ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DsSectionHeader(title: "Price Detail".tr, icon: Icons.receipt_long_outlined),
                                priceTotalRow(context, controller),
                              ],
                            )
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                controller.onProviderOrder.value?.paymentStatus == false || controller.onProviderOrder.value?.extraPaymentStatus == false
                                    ? Column(
                                      children: [
                                        controller.couponList.isNotEmpty
                                            ? SizedBox(
                                              height: 92,
                                              child: ListView.builder(
                                                itemCount: controller.couponList.length,
                                                scrollDirection: Axis.horizontal,
                                                padding: EdgeInsets.zero,
                                                itemBuilder: (context, index) {
                                                  final coupon = controller.couponList[index];
                                                  return GestureDetector(onTap: () => controller.applyCoupon(coupon), child: buildOfferItem(context, controller, index));
                                                },
                                              ),
                                            )
                                            : Container(),
                                        buildPromoCode(context, controller),
                                      ],
                                    )
                                    : Offstage(),
                                DsSectionHeader(title: "Price Detail".tr, icon: Icons.receipt_long_outlined),
                                priceTotalRow(context, controller),
                              ],
                            ),

                        // Extra charges.
                        controller.onProviderOrder.value?.extraCharges.toString() != ""
                            ? Padding(
                              padding: const EdgeInsets.only(top: DsSpace.md),
                              child: DsCard.tinted(
                                tone: DsTone.warning,
                                padding: const EdgeInsets.all(DsSpace.md),
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: Text("Total Extra Charges : ".tr, style: t.bodyStrong)),
                                        const DsGap(DsSpace.sm),
                                        Text(
                                          Constant.amountShow(amount: controller.onProviderOrder.value?.extraCharges.toString(), currency: RegionService.currencyForRecord(controller.onProviderOrder.value?.regionId)),
                                          style: t.bodyStrong.tabular,
                                        ),
                                      ],
                                    ),
                                    const DsGap(DsSpace.xs),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: Text("Extra charge Notes : ".tr, style: t.bodySm)),
                                        const DsGap(DsSpace.sm),
                                        Flexible(child: Text(controller.onProviderOrder.value?.extraChargesDescription ?? '', textAlign: TextAlign.end, style: t.bodySm)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : SizedBox(),
                        const DsGap(DsSpace.md),

                        // Reschedule + cancel.
                        Visibility(
                          visible: controller.onProviderOrder.value?.status == Constant.orderPlaced || controller.onProviderOrder.value?.newScheduleDateTime != null ? true : false,
                          child: DsCard.outlined(
                            padding: const EdgeInsets.all(DsSpace.md),
                            child: Column(
                              children: [
                                controller.onProviderOrder.value?.newScheduleDateTime != null
                                    ? Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: Text("New Date : ".tr, style: t.bodyStrong)),
                                        const DsGap(DsSpace.sm),
                                        Text(DateFormat('dd-MMM-yyyy hh:mm a').format(controller.onProviderOrder.value!.newScheduleDateTime!.toDate()), style: t.bodyStrong.tabular),
                                      ],
                                    )
                                    : SizedBox(),
                                controller.onProviderOrder.value?.status == Constant.orderPlaced || controller.onProviderOrder.value?.status == Constant.orderAccepted
                                    ? Padding(
                                      padding: const EdgeInsets.only(top: DsSpace.md),
                                      child: DsButton.dangerTonal(
                                        label: "Cancel Booking".tr,
                                        icon: Icons.cancel_outlined,
                                        expand: true,
                                        onPressed: () {
                                          showCancelBookingDialog(context, controller);
                                        },
                                      ),
                                    )
                                    : SizedBox(),
                              ],
                            ),
                          ),
                        ),
                        const DsGap(DsSpace.lg),
                        controller.onProviderOrder.value?.extraPaymentStatus == false && controller.onProviderOrder.value?.status == Constant.orderOngoing
                            ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
                              child: DsButton.primary(
                                label: 'Pay Extra Amount'.tr,
                                icon: Icons.account_balance_wallet_outlined,
                                size: DsButtonSize.lg,
                                expand: true,
                                onPressed: () async {
                                  double finalTotalAmount = 0.0;
                                  finalTotalAmount = double.parse(controller.onProviderOrder.value!.extraCharges.toString());
                                  Get.to(() => OnDemandPaymentScreen(), arguments: {'onDemandOrderModel': controller.onProviderOrder, 'totalAmount': finalTotalAmount, 'isExtra': true});
                                },
                              ),
                            )
                            : SizedBox(),
                        controller.onProviderOrder.value?.provider.priceUnit != "Fixed" && controller.onProviderOrder.value?.paymentStatus == false
                            ? Visibility(
                              visible: controller.onProviderOrder.value?.status == Constant.orderOngoing ? true : false,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
                                child: DsButton.primary(
                                  label: 'Pay Now'.tr,
                                  icon: Icons.lock_outline_rounded,
                                  size: DsButtonSize.lg,
                                  expand: true,
                                  onPressed: () async {
                                    double finalTotalAmount = 0.0;
                                    finalTotalAmount =
                                        controller.totalAmount.value +
                                        double.parse(controller.onProviderOrder.value!.extraCharges!.isNotEmpty ? controller.onProviderOrder.value!.extraCharges.toString() : "0.0");
                                    controller.onProviderOrder.value?.discount = controller.discountAmount.toString();
                                    controller.onProviderOrder.value?.discountType = controller.discountType.toString();
                                    controller.onProviderOrder.value?.discountLabel = controller.discountLabel.toString();
                                    controller.onProviderOrder.value?.couponCode = controller.offerCode.toString();

                                    Get.to(() => OnDemandPaymentScreen(), arguments: {'onDemandOrderModel': controller.onProviderOrder, 'totalAmount': finalTotalAmount, 'isExtra': false});
                                  },
                                ),
                              ),
                            )
                            : SizedBox(),
                      ]),
                    ),
                  ),
        );
      },
    );
  }

  /// Ticket-style coupon chip.
  Widget buildOfferItem(BuildContext context, OnDemandOrderDetailsController controller, int index) {
    return Obx(() {
      final coupon = controller.couponList[index];
      final c = context.dsColors;
      final t = context.dsText;

      return Container(
        margin: const EdgeInsetsDirectional.only(end: DsSpace.md, top: DsSpace.sm, bottom: DsSpace.sm),
        child: DottedBorder(
          options: RoundedRectDottedBorderOptions(strokeWidth: 1, radius: const Radius.circular(DsRadius.md), color: c.brand),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Image(image: AssetImage('assets/images/offer_icon.png'), height: 22, width: 22),
                    const DsGap(DsSpace.sm),
                    Text(
                      coupon.discountType == "Fix Price" ? "${Constant.amountShow(amount: coupon.discount.toString(), currency: RegionService.currencyForRecord(controller.onProviderOrder.value?.regionId))} ${'OFF'.tr}" : "${coupon.discount} ${'% Off'.tr}",
                      style: t.titleSm.tabular,
                    ),
                  ],
                ),
                const DsGap(DsSpace.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(coupon.code ?? '', style: t.labelSm.withColor(c.brandStrong)),
                    Container(margin: const EdgeInsets.symmetric(horizontal: DsSpace.md), width: 1, height: 12, color: c.border),
                    Text("valid till ".tr + controller.getDate(coupon.expiresAt!.toDate().toString()), style: t.caption),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget buildPromoCode(BuildContext context, OnDemandOrderDetailsController controller) {
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.sm),
      child: DsCard.outlined(
        padding: const EdgeInsets.all(DsSpace.md),
        onTap: () {
          Get.bottomSheet(promoCodeSheet(context, controller), isScrollControlled: true, isDismissible: true, backgroundColor: Colors.transparent, enableDrag: true);
        },
        child: Row(
          children: [
            Image.asset("assets/images/reedem.png", height: 44, width: 44),
            const DsGap(DsSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Promo Code".tr, overflow: TextOverflow.ellipsis, style: t.titleSm),
                  const DsGap(DsSpace.xxs),
                  Text("Apply promo code".tr, overflow: TextOverflow.ellipsis, style: t.bodySm),
                ],
              ),
            ),
            DsIconButton(
              icon: Icons.add_rounded,
              semanticLabel: "Apply promo code".tr,
              variant: DsIconButtonVariant.tonal,
              onPressed: () {
                Get.bottomSheet(promoCodeSheet(context, controller), isScrollControlled: true, isDismissible: true, backgroundColor: Colors.transparent, enableDrag: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget promoCodeSheet(BuildContext context, OnDemandOrderDetailsController controller) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsSheet(
      title: 'Redeem Your Coupons'.tr,
      showClose: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Image(image: AssetImage('assets/images/redeem_coupon.png'), width: 100),
          const DsGap(DsSpace.lg),
          Text("Voucher or Coupon code".tr, textAlign: TextAlign.center, style: t.bodySecondary),
          const DsGap(DsSpace.lg),
          DottedBorder(
            options: RoundedRectDottedBorderOptions(strokeWidth: 1, radius: const Radius.circular(DsRadius.md), color: c.brand),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
              child: TextFormField(
                textAlign: TextAlign.center,
                style: t.titleSm.tabular,
                controller: controller.couponTextController.value,
                decoration: InputDecoration(border: InputBorder.none, hintText: "Write Coupon Code".tr, hintStyle: t.bodySecondary),
              ),
            ),
          ),
          const DsGap(DsSpace.xl),
          DsButton.primary(
            label: "REDEEM NOW".tr,
            size: DsButtonSize.lg,
            expand: true,
            onPressed: () {
              final inputCode = controller.couponTextController.value.text.trim().toLowerCase();
              print("Entered code: $inputCode");
              print("Available coupons: ${controller.couponList.map((e) => e.code).toList()}");

              final matchingCoupon = controller.couponList.firstWhereOrNull((c) => (c.code ?? '').trim().toLowerCase() == inputCode);

              if (matchingCoupon != null) {
                print("✅ Coupon matched: ${matchingCoupon.code}");
                controller.applyCoupon(matchingCoupon);
                Future.delayed(const Duration(milliseconds: 300), () {
                  Get.back();
                });
              } else {
                print("❌ No matching coupon found");
                ShowToastDialog.showToast("Applied coupon not valid.".tr);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget priceTotalRow(BuildContext context, OnDemandOrderDetailsController controller) {
    return Obx(() {
      final c = context.dsColors;
      final t = context.dsText;
      return DsCard.outlined(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
        child: Column(
          children: [
            rowText(
              context,
              "Price".tr,
              //Constant.amountShow(amount: controller.price.value.toString(), currency: RegionService.currencyForRecord(controller.onProviderOrder.value?.regionId)),
              controller.onProviderOrder.value?.provider.disPrice == "" || controller.onProviderOrder.value?.provider.disPrice == "0"
                  ? "${Constant.amountShow(amount: controller.onProviderOrder.value?.provider.price.toString(), currency: RegionService.currencyForRecord(controller.onProviderOrder.value?.regionId))} × ${controller.onProviderOrder.value?.quantity.toStringAsFixed(2)}    ${Constant.amountShow(amount: controller.price.value.toString(), currency: RegionService.currencyForRecord(controller.onProviderOrder.value?.regionId))}"
                  : "${Constant.amountShow(amount: controller.onProviderOrder.value?.provider.disPrice.toString(), currency: RegionService.currencyForRecord(controller.onProviderOrder.value?.regionId))} × ${controller.onProviderOrder.value?.quantity.toStringAsFixed(2)}    ${Constant.amountShow(amount: controller.price.value.toString(), currency: RegionService.currencyForRecord(controller.onProviderOrder.value?.regionId))}",
            ),
            controller.discountAmount.value != 0 ? const DsDivider(spacing: DsSpace.xs) : const SizedBox(),
            controller.discountAmount.value != 0
                ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${"Discount".tr} ${controller.discountType.value == 'Percentage' || controller.discountType.value == 'Percent' ? "(${controller.discountLabel.value}%)" : "(${Constant.amountShow(amount: controller.discountLabel.value, currency: RegionService.currencyForRecord(controller.onProviderOrder.value?.regionId))})"}",
                              style: t.body,
                            ),
                            Text(controller.offerCode.value, style: t.caption),
                          ],
                        ),
                      ),
                      Text(
                        "(-${Constant.amountShow(amount: controller.discountAmount.value.toString(), currency: RegionService.currencyForRecord(controller.onProviderOrder.value?.regionId))})",
                        style: t.bodyStrong.withColor(c.dangerStrong).tabular,
                      ),
                    ],
                  ),
                )
                : const SizedBox(),

            const DsDivider(spacing: DsSpace.xs),
            if (Constant.platformFeeModel?.enable == true) rowText(context, "Platform fee".tr, Constant.amountShow(amount: Constant.platformFeeModel?.fee.toString(), currency: RegionService.currencyForRecord(controller.onProviderOrder.value?.regionId))),
            if (Constant.platformFeeModel?.enable == true) const DsDivider(spacing: DsSpace.xs),
            InkWell(
              onTap: () {
                showBillBifurcationDialog(context, controller);
              },
              child: rowText(context, "Tax amount".tr, Constant.amountShow(amount: (controller.taxAmount.value).toString(), currency: RegionService.currencyForRecord(controller.onProviderOrder.value?.regionId)), underline: true),
            ),
            // Total Amount
            const DsDivider(spacing: DsSpace.xs),
            rowText(context, "Total Amount".tr, Constant.amountShow(amount: controller.totalAmount.value.toString(), currency: RegionService.currencyForRecord(controller.onProviderOrder.value?.regionId)), total: true),
          ],
        ),
      );
    });
  }

  Widget rowText(BuildContext context, String title, String value, {bool? underline, bool total = false}) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: (total ? t.titleSm : t.body).copyWith(decoration: underline == true ? TextDecoration.underline : TextDecoration.none, decorationColor: c.textSecondary),
            ),
          ),
          const DsGap(DsSpace.md),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: total ? t.title.withColor(c.brandStrong).tabular : t.bodyStrong.tabular)),
        ],
      ),
    );
  }

  Future<void> showCancelBookingDialog(BuildContext context, OnDemandOrderDetailsController controller) {
    return Get.dialog(
      DsDialog(
        title: 'Please give reason for canceling this Booking'.tr,
        icon: Icons.cancel_outlined,
        tone: DsTone.danger,
        destructive: true,
        content: DsTextField(
          controller: controller.cancelBookingController.value,
          hint: "Specify your reason here".tr,
          maxLines: 5,
          minLines: 3,
          bottomSpacing: 0,
        ),
        secondaryLabel: 'Cancel'.tr,
        onSecondary: () => Get.back(),
        primaryLabel: 'Continue'.tr,
        onPrimary: () async {
          if (controller.cancelBookingController.value.text.trim().isEmpty) {
            ShowToastDialog.showToast("Please enter reason".tr);
          } else {
            await controller.cancelBooking();
          }
        },
      ),
      barrierDismissible: false,
    );
  }

  void showBillBifurcationDialog(BuildContext context, OnDemandOrderDetailsController controller) {
    showDialog(
      context: context,
      builder: (context) {
        return DsDialog(
          title: "Tax Details".tr,
          icon: Icons.receipt_long_outlined,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              amountRow(context, title: "Tax on Order Total".tr, amount: Constant.amountShow(amount: controller.orderTaxAmount.value.toString(), currency: RegionService.currencyForRecord(controller.onProviderOrder.value?.regionId))),
              const DsDivider(spacing: DsSpace.sm),
              amountRow(context, title: "Tax on Platform Fee".tr, amount: Constant.amountShow(amount: controller.platformTaxAmount.value.toString(), currency: RegionService.currencyForRecord(controller.onProviderOrder.value?.regionId))),
              const DsDivider(spacing: DsSpace.sm),
              amountRow(context, title: "Total Tax Amount".tr, amount: Constant.amountShow(amount: controller.taxAmount.value.toString(), currency: RegionService.currencyForRecord(controller.onProviderOrder.value?.regionId)), highlight: true),
            ],
          ),
          primaryLabel: "Close".tr,
          onPrimary: () => Navigator.pop(context),
        );
      },
    );
  }

  Widget amountRow(BuildContext context, {required String title, required String amount, bool highlight = false}) {
    final c = context.dsColors;
    final t = context.dsText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(title.tr, style: t.bodySecondary)),
        const DsGap(DsSpace.md),
        Text(amount, style: highlight ? t.titleSm.withColor(c.brandStrong).tabular : t.bodyStrong.tabular),
      ],
    );
  }
}

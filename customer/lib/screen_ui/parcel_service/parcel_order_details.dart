import 'package:customer/utils/region_service.dart';
import 'package:customer/screen_ui/parcel_service/parcel_review_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/parcel_order_details_controller.dart';
import '../../models/user_model.dart';
import '../../service/fire_store_utils.dart';
import '../../themes/show_toast_dialog.dart';
import '../multi_vendor_service/chat_screens/chat_screen.dart';
import '../../models/parcel_order_model.dart';
import '../widgets/order_ui.dart';
import '../../utils/parcel_receipt_pdf.dart';
import 'parcel_order_confirmation.dart';
import 'parcel_shipping_widgets.dart';
import 'parcel_tracking_screen.dart';

/// Parcel order details (archetype F — order detail): a tinted status hero with
/// the track shortcut, the scannable codes, the shipment and price cards, the
/// route, the driver block and the bill; the single stateful action (pay the
/// quote / cancel) sits in a sticky bar.
class ParcelOrderDetails extends StatelessWidget {
  const ParcelOrderDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    final l = context.dsLayout;
    return GetX(
      init: ParcelOrderDetailsController(),
      builder: (controller) {
        final String statusLabel = controller.parcelOrder.value.awaitingQuote
            ? "Waiting for a quote".tr
            : controller.parcelOrder.value.quoteReadyToPay
            ? "Quote ready - pay to confirm".tr
            : (controller.parcelOrder.value.parcelStatus ?? controller.parcelOrder.value.status ?? '').tr;
        return DsScaffold(
          appBar: DsAppBar(
            title: "Order Details".tr,
            subtitle: "Your parcel is on the way. Track it in real time below.".tr,
            onBack: () => Get.back(),
          ),
          maxContentWidth: DsLayout.contentMax,
          body: controller.isLoading.value
              ? const DsSkeletonDetail(mediaHeight: 140)
              : ListView(
                  padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxl),
                  children: DsFadeSlideIn.stagger([
                    // Shipping: status, QR / barcode / pickup code, route, price breakdown, receipt, tracking.
                    if (controller.parcelOrder.value.isTrackable) ...[
                      DsCard.tinted(
                        tone: DsTone.fromStatus(controller.parcelOrder.value.parcelStatus ?? controller.parcelOrder.value.status ?? ''),
                        padding: const EdgeInsets.all(DsSpace.lg),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Tracking status".tr, style: t.overline),
                                  const DsGap(DsSpace.xs),
                                  Text(statusLabel, style: t.title),
                                ],
                              ),
                            ),
                            const DsGap(DsSpace.md),
                            DsButton.tonal(
                              label: "Track".tr,
                              icon: Icons.timeline_rounded,
                              size: DsButtonSize.sm,
                              onPressed: () => Get.to(() => ParcelTrackingScreen(order: controller.parcelOrder.value)),
                            ),
                          ],
                        ),
                      ),
                      const DsGap(DsSpace.lg),
                      ParcelCodesCard(order: controller.parcelOrder.value),
                      const DsGap(DsSpace.lg),
                      ParcelShippingSummaryCard(order: controller.parcelOrder.value),
                      if (controller.parcelOrder.value.priceBreakdown != null) ...[
                        const DsGap(DsSpace.lg),
                        ParcelBreakdownCard(
                          currency: RegionService.currencyForRecord(controller.parcelOrder.value.regionId),
                          breakdown: controller.parcelOrder.value.priceBreakdown!,
                        ),
                      ],
                      const DsGap(DsSpace.lg),
                      DsButton.secondary(
                        label: "Download / share receipt (PDF)".tr,
                        icon: Icons.receipt_long_outlined,
                        expand: true,
                        onPressed: () => ParcelReceiptPdf.showOptions(context, controller.parcelOrder.value),
                      ),
                      const DsGap(DsSpace.lg),
                    ],
                    ParcelCard(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
                      child: OrderIdHeader(
                        title: 'Order Id:'.tr,
                        id: controller.parcelOrder.value.id.toString(),
                        // The tracking hero above already carries the status.
                        statusLabel: controller.parcelOrder.value.isTrackable ? null : statusLabel,
                        status: controller.parcelOrder.value.parcelStatus ?? controller.parcelOrder.value.status ?? '',
                      ),
                    ),
                    const DsGap(DsSpace.lg),
                    ParcelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ParcelRouteBlock(
                            senderName: controller.parcelOrder.value.sender?.name ?? '',
                            senderAddress: controller.parcelOrder.value.sender?.address ?? '',
                            senderPhone: controller.parcelOrder.value.sender?.phone ?? '',
                            receiverName: controller.parcelOrder.value.receiver?.name ?? '',
                            receiverAddress: controller.parcelOrder.value.receiver?.address ?? '',
                            receiverPhone: controller.parcelOrder.value.receiver?.phone ?? '',
                          ),

                          const DsDivider(spacing: DsSpace.xl),

                          if (controller.parcelOrder.value.isSchedule == true)
                            _DateLine(
                              icon: Icons.event_available_outlined,
                              label: "${'Schedule Pickup time:'.tr} ${controller.formatDate(controller.parcelOrder.value.senderPickupDateTime!)}",
                            ),

                          _DateLine(
                            icon: Icons.event_outlined,
                            label:
                                "${'Order Date:'.tr}${controller.parcelOrder.value.isSchedule == true ? controller.formatDate(controller.parcelOrder.value.createdAt!) : controller.formatDate(controller.parcelOrder.value.senderPickupDateTime!)}",
                          ),

                          const DsGap(DsSpace.md),
                          Row(
                            children: [
                              Expanded(child: Text("Parcel Type:".tr, style: t.bodyStrong)),
                              const DsGap(DsSpace.sm),
                              if (controller.getSelectedCategory()?.image != null && controller.getSelectedCategory()!.image!.isNotEmpty) ...[
                                DsImage(url: controller.getSelectedCategory()?.image ?? '', height: 20, width: 20, radius: DsRadius.xs),
                                const DsGap(DsSpace.sm),
                              ],
                              DsBadge(label: controller.parcelOrder.value.parcelType ?? '', tone: DsTone.brand),
                            ],
                          ),
                          controller.parcelOrder.value.parcelImages!.isEmpty
                              ? const SizedBox()
                              : Padding(
                                  padding: const EdgeInsets.only(top: DsSpace.md),
                                  child: SizedBox(
                                    height: 104,
                                    child: ListView.separated(
                                      itemCount: controller.parcelOrder.value.parcelImages!.length,
                                      shrinkWrap: true,
                                      scrollDirection: Axis.horizontal,
                                      separatorBuilder: (context, index) => const DsGap(DsSpace.md),
                                      itemBuilder: (context, index) {
                                        return DsImage(url: controller.parcelOrder.value.parcelImages![index], width: 100, height: 104, fit: BoxFit.cover, radius: DsRadius.md);
                                      },
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                    const DsGap(DsSpace.lg),
                    // Distance, Weight, Rate
                    DsAdaptiveGrid(
                      minItemWidth: 110,
                      children: [
                        ParcelMetricTile(
                          value: "${controller.parcelOrder.value.distance ?? '--'} ${Constant.distanceType}",
                          label: "Distance".tr,
                          asset: "assets/icons/ic_distance_parcel.svg",
                        ),
                        ParcelMetricTile(value: controller.parcelOrder.value.parcelWeight ?? '--', label: "Weight".tr, asset: "assets/icons/ic_weight_parcel.svg"),
                        ParcelMetricTile(
                          value: Constant.amountShow(
                            amount: controller.parcelOrder.value.subTotal,
                            currency: RegionService.currencyForRecord(RegionService.regionOf(regionId: controller.parcelOrder.value.regionId, zoneId: controller.parcelOrder.value.senderZoneId)),
                          ),
                          label: "Rate".tr,
                          asset: "assets/icons/ic_rate_parcel.svg",
                        ),
                      ],
                    ),
                    const DsGap(DsSpace.lg),
                    if (controller.parcelOrder.value.driver != null) ...[
                      ParcelCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ParcelCardTitle("About Driver".tr, icon: Icons.badge_outlined),
                            Row(
                              children: [
                                DsAvatar(
                                  imageUrl: controller.driverUser.value?.profilePictureURL ?? '',
                                  name: controller.parcelOrder.value.driver?.fullName() ?? '',
                                  size: 52,
                                  ring: true,
                                ),
                                const DsGap(DsSpace.lg),
                                Expanded(
                                  child: Text(controller.parcelOrder.value.driver?.fullName() ?? '', style: t.title),
                                ),
                                const DsGap(DsSpace.sm),
                                DsBadge(
                                  label: controller.driverUser.value!.averageRating.toStringAsFixed(1),
                                  tone: DsTone.warning,
                                  icon: Icons.star_rounded,
                                ),
                              ],
                            ),
                            Visibility(
                              visible: controller.parcelOrder.value.status == Constant.orderCompleted ? true : false,
                              child: Padding(
                                padding: const EdgeInsets.only(top: DsSpace.lg),
                                child: DsButton.tonal(
                                  label: controller.ratingModel.value.id != null && controller.ratingModel.value.id!.isNotEmpty ? 'Update Review'.tr : 'Add Review'.tr,
                                  icon: Icons.rate_review_outlined,
                                  expand: true,
                                  onPressed: () async {
                                    final result = await Get.to(() => ParcelReviewScreen(), arguments: {'order': controller.parcelOrder.value});

                                    // If review was submitted successfully
                                    if (result == true) {
                                      await controller.fetchDriverDetails();
                                    }
                                  },
                                ),
                              ),
                            ),
                            if (controller.parcelOrder.value.status != Constant.orderCompleted)
                              Padding(
                                padding: const EdgeInsets.only(top: DsSpace.lg),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: DsButton.secondary(
                                        label: "Call".tr,
                                        icon: Icons.call_outlined,
                                        expand: true,
                                        onPressed: () {
                                          Constant.makePhoneCall(controller.parcelOrder.value.driver!.phoneNumber.toString());
                                        },
                                      ),
                                    ),
                                    const DsGap(DsSpace.md),
                                    Expanded(
                                      child: DsButton.secondary(
                                        label: "Chat".tr,
                                        icon: Icons.chat_bubble_outline_rounded,
                                        expand: true,
                                        onPressed: () async {
                                          ShowToastDialog.showLoader("Please wait...".tr);

                                          UserModel? customer = await FireStoreUtils.getUserProfile(controller.parcelOrder.value.authorID ?? '');
                                          UserModel? driverUser = await FireStoreUtils.getUserProfile(controller.parcelOrder.value.driverId ?? '');

                                          ShowToastDialog.closeLoader();

                                          Get.to(
                                            const ChatScreen(),
                                            arguments: {
                                              "senderName": customer?.fullName(),
                                              "receivedName": driverUser?.fullName(),
                                              "orderId": controller.parcelOrder.value.id,
                                              "receivedId": driverUser?.id,
                                              "senderId": customer?.id,
                                              "senderProfileUrl": customer?.profilePictureURL,
                                              "receivedProfileUrl": driverUser?.profilePictureURL,
                                              "token": driverUser?.fcmToken,
                                              "chatType": Constant.userRoleDriver,
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const DsGap(DsSpace.lg),
                    ],
                    ParcelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ParcelCardTitle("Order Summary".tr, icon: Icons.receipt_long_rounded),

                          // Subtotal
                          ParcelSummaryRow(
                            label: "Subtotal".tr,
                            value: Constant.amountShow(
                              amount: controller.subTotal.value.toString(),
                              currency: RegionService.currencyForRecord(RegionService.regionOf(regionId: controller.parcelOrder.value.regionId, zoneId: controller.parcelOrder.value.senderZoneId)),
                            ),
                          ),

                          // Discount
                          ParcelSummaryRow(
                            label: "Discount".tr,
                            value: "-${Constant.amountShow(amount: controller.discount.value.toString(), currency: RegionService.currencyForRecord(RegionService.regionOf(regionId: controller.parcelOrder.value.regionId, zoneId: controller.parcelOrder.value.senderZoneId)))}",
                            tone: DsTone.danger,
                          ),

                          // Fixed intercity / intercountry tax (outside VAT and coupons).
                          if (controller.parcelOrder.value.scopeTaxAmount > 0)
                            ParcelSummaryRow(
                              label: "Fixed tax".tr,
                              value: Constant.amountShow(
                                amount: controller.parcelOrder.value.scopeTaxAmount.toString(),
                                currency: RegionService.currencyForRecord(RegionService.regionOf(regionId: controller.parcelOrder.value.regionId, zoneId: controller.parcelOrder.value.senderZoneId)),
                              ),
                            ),

                          // Tax List
                          if (double.parse(controller.parcelOrder.value.platformFee ?? '0.0') > 0.0)
                            ParcelSummaryRow(
                              label: "Platform fee".tr,
                              value: Constant.amountShow(
                                amount: controller.parcelOrder.value.platformFee ?? '0.0',
                                currency: RegionService.currencyForRecord(RegionService.regionOf(regionId: controller.parcelOrder.value.regionId, zoneId: controller.parcelOrder.value.senderZoneId)),
                              ),
                            ),
                          ParcelSummaryRow(
                            label: "Tax amount".tr,
                            value: Constant.amountShow(
                              amount: (controller.taxAmount.value).toString(),
                              currency: RegionService.currencyForRecord(RegionService.regionOf(regionId: controller.parcelOrder.value.regionId, zoneId: controller.parcelOrder.value.senderZoneId)),
                            ),
                            underline: true,
                            onTap: () {
                              showBillBifurcationDialog(context, controller);
                            },
                          ),
                          const DsDivider(spacing: DsSpace.md),

                          // Total
                          ParcelSummaryRow(
                            label: "Order Total".tr,
                            value: Constant.amountShow(
                              amount: controller.totalAmount.value.toString(),
                              currency: RegionService.currencyForRecord(RegionService.regionOf(regionId: controller.parcelOrder.value.regionId, zoneId: controller.parcelOrder.value.senderZoneId)),
                            ),
                            emphasis: true,
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
          bottomBar: controller.parcelOrder.value.quoteReadyToPay
              ? DsStickyBar(
                  child: DsButton.primary(
                    label: "Pay the quote".tr,
                    icon: Icons.payments_outlined,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () => Get.to(
                      () => const ParcelOrderConfirmationScreen(),
                      arguments: {'parcelOrder': ParcelOrderModel.fromJson(controller.parcelOrder.value.toJson()..addAll(controller.readOnlyJson())), 'images': []},
                    ),
                  ),
                )
              : ParcelOrderDetailsController.canCancel(controller.parcelOrder.value)
              ? DsStickyBar(
                  child: DsButton.dangerTonal(
                    label: "Cancel Parcel".tr,
                    icon: Icons.cancel_outlined,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () {
                      controller.cancelParcelOrder();
                    },
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget statusBottomSheet(BuildContext context, ParcelOrderDetailsController controller) {
    return DraggableScrollableSheet(
      initialChildSize: 0.30,
      minChildSize: 0.20,
      maxChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) {
        final c = context.dsColors;
        final t = context.dsText;
        return Container(
          padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xl),
          decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: DsRadius.sheetTop),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.borderStrong, borderRadius: DsRadius.brPill)),
                ),
                const DsGap(DsSpace.lg),
                Text("Parcel Status Timeline".tr, style: t.title),
                const DsGap(DsSpace.lg),

                // Dynamic List
                DsObserve(
                  builder: (context) {
                    final history = controller.parcelOrder.value.statusHistory ?? [];

                    if (history.isEmpty) {
                      return SizedBox(
                        height: 80,
                        child: Center(child: Text("No status updates yet".tr, style: t.bodySecondary)),
                      );
                    }

                    return DsTimeline(
                      steps: [
                        for (int index = 0; index < history.length; index++)
                          DsTimelineStep(
                            title: history[index].status ?? '',
                            state: index == history.length - 1 ? DsStepState.current : DsStepState.done,
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showBillBifurcationDialog(BuildContext context, ParcelOrderDetailsController controller) {
    showDialog(
      context: context,
      builder: (context) {
        return DsDialog(
          title: "Tax Details".tr,
          icon: Icons.percent_rounded,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ParcelSummaryRow(
                label: "Tax on Order Total".tr,
                value: Constant.amountShow(
                  amount: controller.orderTaxAmount.value.toString(),
                  currency: RegionService.currencyForRecord(RegionService.regionOf(regionId: controller.parcelOrder.value.regionId, zoneId: controller.parcelOrder.value.senderZoneId)),
                ),
              ),
              const DsDivider(spacing: DsSpace.md),
              ParcelSummaryRow(
                label: "Tax on Platform Fee".tr,
                value: Constant.amountShow(
                  amount: controller.platformTaxAmount.value.toString(),
                  currency: RegionService.currencyForRecord(RegionService.regionOf(regionId: controller.parcelOrder.value.regionId, zoneId: controller.parcelOrder.value.senderZoneId)),
                ),
              ),
              const DsDivider(spacing: DsSpace.md),
              ParcelSummaryRow(
                label: "Total Tax Amount".tr,
                value: Constant.amountShow(
                  amount: controller.taxAmount.value.toString(),
                  currency: RegionService.currencyForRecord(RegionService.regionOf(regionId: controller.parcelOrder.value.regionId, zoneId: controller.parcelOrder.value.senderZoneId)),
                ),
                emphasis: true,
              ),
            ],
          ),
          primaryLabel: "Close".tr,
          onPrimary: () => Navigator.pop(context),
        );
      },
    );
  }
}

/// Small icon + info line for the schedule / order dates.
class _DateLine extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DateLine({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: c.infoStrong),
          const DsGap(DsSpace.sm),
          Expanded(child: Text(label, style: t.bodySm.withColor(c.infoStrong))),
        ],
      ),
    );
  }
}

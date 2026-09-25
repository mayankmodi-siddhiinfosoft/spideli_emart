import 'package:driver/app/parcel_screen/parcel_tracking/parcel_shipment_info_card.dart';
import 'package:driver/app/widgets/order_ui.dart';
import 'package:driver/utils/region_service.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/parcel_order_details_controller.dart';
import '../../themes/theme_controller.dart';

/// Parcel order details (archetype D/J detail): a gradient order header, the
/// shipment contract, the sender → receiver rail, the numbers and the fare
/// breakdown, each in its own surface.
class ParcelOrderDetails extends StatelessWidget {
  const ParcelOrderDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: ParcelOrderDetailsController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final order = controller.parcelOrder.value;
        return DsScaffold(
          backgroundColor: c.background,
          title: "Order Details".tr,
          body: controller.isLoading.value
              ? const DsSkeletonDetail()
              : DsResponsive(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(DsSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: DsFadeSlideIn.stagger([
                        // ---------------------------------------------- header
                        DsCard.gradient(
                          child: OrderHeaderRow(
                            title: Row(
                              children: [
                                Icon(Icons.local_shipping_outlined, size: 20, color: Colors.white.withValues(alpha: 0.9)),
                                const DsGap(DsSpace.sm),
                                Expanded(
                                  child: Text(
                                    "Parcel".tr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.overline.withColor(Colors.white.withValues(alpha: 0.85)),
                                  ),
                                ),
                              ],
                            ),
                            trailing: (order.status ?? '').isEmpty
                                ? null
                                : Text(
                                    order.status!.tr,
                                    textAlign: TextAlign.end,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.labelSm.withColor(Colors.white),
                                  ),
                            subtitle: OrderIdLine(
                              label: 'Order Id:'.tr,
                              id: controller.parcelOrder.value.id.toString(),
                              copiedMessage: "Order ID copied to clipboard".tr,
                              onColor: Colors.white,
                            ),
                          ),
                        ),
                        const DsGap(DsSpace.lg),

                        // ------------------------------------------- shipment
                        ParcelShipmentInfoCard(order: controller.parcelOrder.value, isDark: isDark),

                        // ---------------------------------------------- route
                        DsCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PartyBlock(
                                kind: DsStopKind.pickup,
                                title: "Pickup Address (Sender):".tr,
                                name: controller.parcelOrder.value.sender?.name ?? '',
                                address: controller.parcelOrder.value.sender?.address ?? '',
                                phone: controller.parcelOrder.value.sender?.phone ?? '',
                                showConnector: true,
                              ),
                              _PartyBlock(
                                kind: DsStopKind.drop,
                                title: "Delivery Address (Receiver):".tr,
                                name: controller.parcelOrder.value.receiver?.name ?? '',
                                address: controller.parcelOrder.value.receiver?.address ?? '',
                                phone: controller.parcelOrder.value.receiver?.phone ?? '',
                                showConnector: false,
                              ),
                              const DsDivider(spacing: DsSpace.lg),
                              if (controller.parcelOrder.value.isSchedule == true)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: DsSpace.sm),
                                  child: DsInlineAlert(
                                    tone: DsTone.info,
                                    icon: Icons.schedule_rounded,
                                    message: "Schedule Pickup time: ${controller.formatDate(controller.parcelOrder.value.senderPickupDateTime!)}".tr,
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: DsSpace.sm),
                                child: Row(
                                  children: [
                                    Icon(Icons.event_outlined, size: 18, color: c.info),
                                    const DsGap(DsSpace.sm),
                                    Expanded(
                                      child: Text(
                                        "Order Date:${controller.parcelOrder.value.isSchedule == true ? controller.formatDate(controller.parcelOrder.value.createdAt!) : controller.formatDate(controller.parcelOrder.value.senderPickupDateTime!)}"
                                            .tr,
                                        style: t.bodySm.withColor(c.infoStrong),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Parcel Type:".tr, style: t.bodySecondary),
                                  Flexible(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            controller.parcelOrder.value.parcelType ?? '',
                                            textAlign: TextAlign.end,
                                            style: t.bodyStrong,
                                          ),
                                        ),
                                        if (controller.getSelectedCategory()?.image != null && controller.getSelectedCategory()!.image!.isNotEmpty) ...[
                                          const DsGap(DsSpace.sm),
                                          DsImage(url: controller.getSelectedCategory()?.image ?? '', height: 20, width: 20, radius: DsRadius.xs),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              controller.parcelOrder.value.parcelImages == null || controller.parcelOrder.value.parcelImages!.isEmpty
                                  ? const SizedBox()
                                  : Padding(
                                      padding: const EdgeInsets.only(top: DsSpace.md),
                                      child: SizedBox(
                                        height: 104,
                                        child: ListView.separated(
                                          itemCount: controller.parcelOrder.value.parcelImages!.length,
                                          shrinkWrap: true,
                                          scrollDirection: Axis.horizontal,
                                          separatorBuilder: (_, _) => const DsGap(DsSpace.sm),
                                          itemBuilder: (context, index) {
                                            return DsImage(
                                              url: controller.parcelOrder.value.parcelImages![index],
                                              width: 100,
                                              height: 104,
                                              radius: DsRadius.md,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                        const DsGap(DsSpace.lg),

                        // -------------------------------- distance, weight, rate
                        DsCard(
                          padding: const EdgeInsets.all(DsSpace.md),
                          child: DsTripMetrics(
                            filled: false,
                            items: [
                              DsTripMetric(
                                icon: Icons.route_outlined,
                                value: "${controller.parcelOrder.value.distance ?? '--'} ${Constant.distanceType}",
                                label: "Distance".tr,
                              ),
                              DsTripMetric(
                                icon: Icons.scale_outlined,
                                value: controller.parcelOrder.value.parcelWeight ?? '--',
                                label: "Weight".tr,
                              ),
                              DsTripMetric(
                                icon: Icons.payments_outlined,
                                value: Constant.amountShow(
                                    currency: RegionService.currencyForRecord(controller.parcelOrder.value.regionId),
                                    amount: controller.parcelOrder.value.subTotal),
                                label: "Rate".tr,
                              ),
                            ],
                          ),
                        ),
                        const DsGap(DsSpace.lg),

                        // ------------------------------------------- customer
                        DsCard(
                          padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                                child: Text("About Customer".tr, style: t.overline),
                              ),
                              DsListTile(
                                title: controller.parcelOrder.value.author?.fullName() ?? '',
                                leading: DsAvatar(
                                  imageUrl: controller.parcelOrder.value.author?.profilePictureURL ?? '',
                                  name: controller.parcelOrder.value.author?.fullName() ?? '',
                                  size: 52,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const DsGap(DsSpace.lg),

                        // -------------------------------------------- summary
                        DsCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Order Summary".tr, style: t.overline),
                              const DsGap(DsSpace.sm),

                              // Subtotal
                              OrderMoneyRow(
                                label: "Subtotal".tr,
                                value: Constant.amountShow(
                                    currency: RegionService.currencyForRecord(controller.parcelOrder.value.regionId), amount: controller.subTotal.value.toString()),
                              ),

                              // Discount
                              OrderMoneyRow(
                                label: "Discount".tr,
                                value: Constant.amountShow(
                                    currency: RegionService.currencyForRecord(controller.parcelOrder.value.regionId), amount: controller.discount.value.toString()),
                              ),

                              // Tax List
                              ...List.generate(controller.parcelOrder.value.taxSetting!.length, (index) {
                                return OrderMoneyRow(
                                  label:
                                      "${controller.parcelOrder.value.taxSetting![index].title} ${controller.parcelOrder.value.taxSetting![index].type == 'fix' ? '' : '(${controller.parcelOrder.value.taxSetting![index].tax}%)'}",
                                  value: Constant.amountShow(
                                    currency: RegionService.currencyForRecord(controller.parcelOrder.value.regionId),
                                    amount: Constant.getTaxValue(
                                      amount: ((double.tryParse(controller.parcelOrder.value.subTotal.toString()) ?? 0.0) -
                                              (double.tryParse(controller.parcelOrder.value.discount.toString()) ?? 0.0))
                                          .toString(),
                                      taxModel: controller.parcelOrder.value.taxSetting![index],
                                    ).toString(),
                                  ),
                                );
                              }),

                              // Total
                              OrderTotalRow(
                                label: "Order Total".tr,
                                value: Constant.amountShow(
                                    currency: RegionService.currencyForRecord(controller.parcelOrder.value.regionId), amount: controller.totalAmount.value.toString()),
                              ),
                              OrderMoneyRow(
                                label:
                                    "Admin Commission (${controller.parcelOrder.value.adminCommission}${controller.parcelOrder.value.adminCommissionType == "Percentage" || controller.parcelOrder.value.adminCommissionType == "percentage" ? "%" : Constant.currencyModel!.symbol})"
                                        .tr,
                                value: Constant.amountShow(
                                    currency: RegionService.currencyForRecord(controller.parcelOrder.value.regionId), amount: controller.adminCommission.value.toString()),
                                valueTone: DsTone.danger,
                              ),

                              // controller.parcelOrder.value.driver?.ownerId != null &&
                              //             controller.parcelOrder.value.driver?.ownerId.isNotEmpty ||
                              //         controller.parcelOrder.value.status == Constant.orderPlaced
                              ((controller.parcelOrder.value.driver?.ownerId != null && (controller.parcelOrder.value.driver?.ownerId?.isNotEmpty ?? false)) ||
                                      controller.parcelOrder.value.status == Constant.orderPlaced)
                                  ? const SizedBox()
                                  : Padding(
                                      padding: const EdgeInsets.only(top: DsSpace.md),
                                      child: DsInlineAlert(
                                        tone: DsTone.danger,
                                        icon: Icons.info_outline_rounded,
                                        message:
                                            "Note : Admin commission will be debited from your wallet balance. \n \nAdmin commission will apply on your booking Amount minus Discount(if applicable).",
                                      ),
                                    ),
                            ],
                          ),
                        ),
                        const DsGap(DsSpace.xxl),
                      ]),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// One party of the shipment (sender / receiver) on a route rail.
class _PartyBlock extends StatelessWidget {
  final DsStopKind kind;
  final String title;
  final String name;
  final String address;
  final String phone;
  final bool showConnector;

  const _PartyBlock({
    required this.kind,
    required this.title,
    required this.name,
    required this.address,
    required this.phone,
    required this.showConnector,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool isPickup = kind == DsStopKind.pickup;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                DsIconWell(
                  icon: isPickup ? Icons.inventory_2_outlined : Icons.flag_outlined,
                  tone: isPickup ? DsTone.brand : DsTone.danger,
                  size: 36,
                  circle: true,
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                      decoration: BoxDecoration(color: c.border, borderRadius: DsRadius.brPill),
                    ),
                  ),
              ],
            ),
          ),
          const DsGap(DsSpace.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showConnector ? DsSpace.lg : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.overline),
                  const DsGap(DsSpace.xs),
                  if (name.isNotEmpty) Text(name, style: t.titleSm.w600),
                  if (address.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: DsSpace.xxs),
                      child: Text(address, style: t.bodySecondary),
                    ),
                  if (phone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: DsSpace.xxs),
                      child: Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 14, color: c.iconDefault),
                          const DsGap(DsSpace.xs),
                          Flexible(child: Text(phone, style: t.bodySm.tabular)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

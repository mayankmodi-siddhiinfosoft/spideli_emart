import 'package:driver/app/widgets/order_ui.dart';
import 'package:driver/utils/region_service.dart';
import 'package:driver/app/order_list_screen/order_details_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/dash_board_controller.dart';
import 'package:driver/controllers/order_list_controller.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Archetype J — history list. Each trip is an outlined card with the order id
/// and live status on top, a compact pickup → drop route and the driver's
/// earnings for that trip at the bottom.
class OrderListScreen extends StatelessWidget {
  const OrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      // Kept as the observable read that rebuilds this screen on a theme
      // change; colors now come from `context.dsColors`.
      themeController.isDark.value;
      return GetX(
          init: OrderListController(),
          builder: (controller) {
            final bool isLoading = controller.isLoading.value;
            final List<OrderModel> orders = controller.orderList.toList();
            final bool documentsPending = Constant.userModel?.isDocumentVerify == false && Constant.userModel?.isAutoVerify == false;

            return DsScaffold(
              body: documentsPending
                  ? _documentsPendingView(context)
                  : DsAsync(
                      isLoading: isLoading,
                      skeleton: const DsSkeletonList(itemCount: 4, trailing: false),
                      isEmpty: orders.isEmpty,
                      empty: DsEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: "Order Not found".tr,
                        message: "Completed and ongoing deliveries will appear here.".tr,
                      ),
                      builder: (_) => ListView.builder(
                        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          return DsFadeSlideIn(
                            index: index,
                            child: _orderCard(context, orders[index]),
                          );
                        },
                      ),
                    ),
            );
          });
    });
  }

  Widget _documentsPendingView(BuildContext context) {
    return Center(
      child: DsEmptyState(
        icon: Icons.assignment_outlined,
        tone: DsTone.warning,
        title: "Document Verification in Pending".tr,
        message: "Your documents are being reviewed. We will notify you once the verification is complete.".tr,
        actionLabel: "View Status".tr,
        actionIcon: Icons.arrow_forward_rounded,
        onAction: () async {
          DashBoardController dashBoardController = Get.put(DashBoardController());
          dashBoardController.drawerIndex.value = 4;
        },
      ),
    );
  }

  Widget _orderCard(BuildContext context, OrderModel orderModel) {
    final c = context.dsColors;
    final t = context.dsText;

    final String tip = orderModel.tipAmount ?? '';
    final bool hasTip = tip.isNotEmpty && double.parse(tip.toString()) > 0;
    final bool showEarnings = Constant.userModel?.vendorID?.isEmpty == true;

    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.lg),
      semanticLabel: '${"Order ID".tr} ${Constant.orderId(orderId: orderModel.id.toString())}',
      onTap: () {
        Get.to(const OrderDetailsScreen(), arguments: {"orderModel": orderModel});
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrderIdHeader(
            label: "Order ID".tr,
            id: orderModel.id.toString(),
            copyable: false,
            copiedMessage: "Order ID copied to clipboard".tr,
            trailing: Semantics(
              label: "${"Status".tr}: ${orderModel.status.toString().tr}",
              excludeSemantics: true,
              child: DsStatusChip(label: orderModel.status.toString().tr, status: orderModel.status),
            ),
          ),
          const DsGap(DsSpace.md),
          Wrap(
            spacing: DsSpace.sm,
            runSpacing: DsSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                label: "${"Section".tr}: ${Constant.sectionNameFromId(orderModel.sectionId)}",
                excludeSemantics: true,
                child: DsSectionBadge(section: DsSection.delivery, label: Constant.sectionNameFromId(orderModel.sectionId)),
              ),
              Semantics(
                label: "${"Date".tr}: ${Constant.timestampToDateTime(orderModel.createdAt!)}",
                excludeSemantics: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: c.textMuted),
                    const DsGap(DsSpace.xs),
                    Text(Constant.timestampToDateTime(orderModel.createdAt!), style: t.caption),
                  ],
                ),
              ),
            ],
          ),
          const DsGap(DsSpace.lg),
          DsRouteStops(
            addressMaxLines: 1,
            stops: [
              DsRouteStop(
                kind: DsStopKind.pickup,
                label: "${orderModel.vendor!.title}",
                address: "${orderModel.vendor!.location}",
              ),
              DsRouteStop(
                kind: DsStopKind.drop,
                label: "Deliver to the".tr,
                address: orderModel.address!.getFullAddress(),
              ),
            ],
          ),
          if (showEarnings || hasTip) ...[
            const DsGap(DsSpace.md),
            DsTripMetrics(
              items: [
                if (showEarnings)
                  DsTripMetric(
                    icon: Icons.delivery_dining_rounded,
                    value: Constant.amountShow(currency: RegionService.currencyForRecord(orderModel.regionId), amount: orderModel.deliveryCharge),
                    label: "Delivery Charge".tr,
                  ),
                if (hasTip)
                  DsTripMetric(
                    icon: Icons.volunteer_activism_outlined,
                    value: Constant.amountShow(currency: RegionService.currencyForRecord(orderModel.regionId), amount: orderModel.tipAmount),
                    label: "Tips".tr,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

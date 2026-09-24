import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/cab_order_list_controller.dart';
import '../../models/cab_order_model.dart';
import '../../themes/ds/ds.dart';
import '../../themes/theme_controller.dart';
import 'cab_order_details.dart';

/// Archetype J – segmented ride history. Pinned pill tabs, skeleton list while
/// loading, route rows with a status chip.
class CabOrderListScreen extends StatelessWidget {
  const CabOrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      // Keeps the tab reacting to the theme switch.
      themeController.isDark.value;
      return GetX(
        init: CabOrderListController(),
        builder: (controller) {
          return DefaultTabController(
            length: controller.tabTitles.length,
            initialIndex: controller.tabTitles.indexOf(controller.selectedTab.value),
            child: DsScaffold(
              body: Column(
                children: [
                  // TabBar
                  DsTabBar(
                    onTap: (index) {
                      controller.selectTab(controller.tabTitles[index]);
                    },
                    tabs: controller.tabTitles.toList(),
                  ),

                  // Body: loader or TabBarView
                  Expanded(
                    child: DsAsync(
                      isLoading: controller.isLoading.value,
                      skeleton: const DsSkeletonList(itemCount: 4, leading: false, trailing: false),
                      builder: (_) => TabBarView(
                        children: controller.tabTitles.map((title) {
                          // filter by tab using controller helper
                          final orders = controller.getOrdersForTab(title);

                          if (orders.isEmpty) {
                            return Center(
                              child: DsEmptyState(
                                icon: Icons.local_taxi_outlined,
                                title: "No orders found",
                                compact: true,
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(DsSpace.lg),
                            itemCount: orders.length,
                            itemBuilder: (context, index) {
                              CabOrderModel order = orders[index];
                              return DsFadeSlideIn(
                                index: index,
                                child: _CabOrderTile(
                                  order: order,
                                  bookingDate: controller.formatDate(order.scheduleDateTime!),
                                  onTap: () {
                                    Get.to(() => CabOrderDetails(), arguments: {"cabOrderModel": order});
                                  },
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}

class _CabOrderTile extends StatelessWidget {
  final CabOrderModel order;
  final String bookingDate;
  final VoidCallback onTap;

  const _CabOrderTile({required this.order, required this.bookingDate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.lg),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${'Booking Date:'.tr} $bookingDate".tr, style: t.titleSm),
                    const DsGap(DsSpace.xxs),
                    Row(
                      children: [
                        Text("${'Section:'.tr} ", style: t.caption),
                        Flexible(
                          child: Text(
                            Constant.sectionNameFromId(order.sectionId),
                            style: t.caption.withColor(c.textPrimary).w600,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const DsGap(DsSpace.sm),
              DsStatusChip(label: order.status.toString(), status: order.status),
            ],
          ),
          const DsGap(DsSpace.lg),
          DsRouteStops(
            addressMaxLines: 1,
            stops: [
              DsRouteStop(kind: DsStopKind.pickup, label: "Pickup".tr, address: order.sourceLocationName.toString()),
              DsRouteStop(kind: DsStopKind.drop, label: "Destination".tr, address: order.destinationLocationName.toString()),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:driver/app/parcel_screen/parcel_order_details.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/parcel_order_list_controller.dart';
import '../../models/parcel_order_model.dart';
import '../../themes/theme_controller.dart';

/// Parcel order history (archetype J): pinned status tabs over a list of
/// shipment cards with their route rail and status.
class ParcelOrderListScreen extends StatelessWidget {
  const ParcelOrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      // The theme observable read must stay inside this Obx: it is what
      // rebuilds the screen when the driver switches light / dark mode.
      themeController.isDark.value;
      return GetX<ParcelOrderListController>(
        init: ParcelOrderListController(),
        builder: (controller) {
          final c = context.dsColors;
          return DefaultTabController(
            length: controller.tabTitles.length,
            initialIndex: controller.tabTitles.indexOf(controller.selectedTab.value),
            child: Scaffold(
              backgroundColor: c.background,
              body: Column(
                children: [
                  // TabBar
                  Material(
                    color: c.surface,
                    child: SafeArea(
                      bottom: false,
                      child: DsTabBar(
                        onTap: (index) {
                          controller.selectTab(controller.tabTitles[index]);
                        },
                        tabs: controller.tabTitles.toList(),
                      ),
                    ),
                  ),

                  // Body: loader or TabBarView
                  Expanded(
                    child: controller.isLoading.value
                        ? const DsSkeletonList(itemCount: 4)
                        : TabBarView(
                            children: controller.tabTitles.map((title) {
                              // filter by tab using controller helper
                              final orders = controller.getOrdersForTab(title);

                              if (orders.isEmpty) {
                                return DsEmptyState(
                                  icon: Icons.inventory_2_outlined,
                                  compact: true,
                                  title: "No orders found".tr,
                                );
                              }

                              return DsResponsive(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(DsSpace.lg),
                                  itemCount: orders.length,
                                  itemBuilder: (context, index) {
                                    final order = orders[index];
                                    return DsFadeSlideIn(
                                      index: index,
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: DsSpace.lg),
                                        child: _ParcelHistoryCard(
                                          order: order,
                                          dateLabel:
                                              "Order Date:${order.isSchedule == true ? controller.formatDate(order.createdAt!) : controller.formatDate(order.senderPickupDateTime!)}",
                                          sectionName: Constant.sectionNameFromId(order.sectionId),
                                          onTap: () {
                                            Get.to(() => const ParcelOrderDetails(), arguments: order);
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }).toList(),
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

/// One past / running shipment: when, which section, and the two addresses.
class _ParcelHistoryCard extends StatelessWidget {
  final ParcelOrderModel order;
  final String dateLabel;
  final String sectionName;
  final VoidCallback onTap;

  const _ParcelHistoryCard({required this.order, required this.dateLabel, required this.sectionName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: c.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateLabel, style: t.bodySm.withColor(c.infoStrong)),
                      const DsGap(DsSpace.xxs),
                      Row(
                        children: [
                          Text("${'Section:'.tr} ", style: t.caption),
                          Flexible(
                            child: Text(
                              sectionName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.labelSm.withColor(c.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (order.status != null) ...[
                  const DsGap(DsSpace.sm),
                  DsStatusChip(label: order.status!, status: order.status),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DsSpace.lg),
            child: Column(
              children: [
                _StopLine(
                  isPickup: true,
                  title: "Pickup Address (Sender):".tr,
                  name: order.sender?.name ?? '',
                  address: order.sender?.address ?? '',
                  phone: order.sender?.phone ?? '',
                  showConnector: true,
                ),
                _StopLine(
                  isPickup: false,
                  title: "Delivery Address (Receiver):".tr,
                  name: order.receiver?.name ?? '',
                  address: order.receiver?.address ?? '',
                  phone: order.receiver?.phone ?? '',
                  showConnector: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact stop on the card's route rail.
class _StopLine extends StatelessWidget {
  final bool isPickup;
  final String title;
  final String name;
  final String address;
  final String phone;
  final bool showConnector;

  const _StopLine({
    required this.isPickup,
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const DsGap(DsSpace.xxs),
                isPickup
                    ? Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle, border: Border.all(color: c.routePickup, width: 2)),
                      )
                    : Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(color: c.routeDrop, borderRadius: DsRadius.brXs),
                        child: const Icon(Icons.flag_rounded, size: 12, color: Colors.white),
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
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.overline),
                  const DsGap(DsSpace.xxs),
                  if (name.isNotEmpty) Text(name, style: t.bodyStrong),
                  if (address.isNotEmpty) Text(address, style: t.bodySecondary),
                  if (phone.isNotEmpty) Text(phone, style: t.bodySm.tabular),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

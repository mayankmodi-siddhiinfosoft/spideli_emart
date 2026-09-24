import 'package:driver/utils/region_service.dart';
import 'package:driver/app/rental_service/rental_order_details_screen.dart';
import 'package:flutter/material.dart';
import '../../constant/constant.dart';
import '../../controllers/rental_order_list_controller.dart';
import '../../models/rental_order_model.dart';
import '../../themes/ds/ds.dart';
import 'package:get/get.dart';

/// Archetype J – rental bookings by state. Pill tabs, skeleton list, vehicle
/// and package blocks inside one outlined card per booking.
class RentalOrderListScreen extends StatelessWidget {
  const RentalOrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<RentalOrderListController>(
      init: RentalOrderListController(),
      builder: (controller) {
        return DefaultTabController(
          length: controller.tabTitles.length,
          initialIndex: controller.tabTitles.indexOf(controller.selectedTab.value),
          child: Column(
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
                  skeleton: const DsSkeletonList(itemCount: 3, leading: false, trailing: false),
                  builder: (_) => TabBarView(
                    children: controller.tabTitles.map((title) {
                      // filter by tab using controller helper
                      final orders = controller.getOrdersForTab(title);

                      if (orders.isEmpty) {
                        return Center(
                          child: DsEmptyState(icon: Icons.car_rental_rounded, title: "No orders found".tr, compact: true),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(DsSpace.lg),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          RentalOrderModel order = orders[index]; //use this
                          return DsFadeSlideIn(index: index, child: _RentalOrderTile(order: order));
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RentalOrderTile extends StatelessWidget {
  final RentalOrderModel order;

  const _RentalOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      onTap: () {
        Get.to(() => RentalOrderDetailsScreen(), arguments: {"rentalOrder": order.id});
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: DsSpace.xs),
                child: Image.asset("assets/icons/pickup.png", height: 18, width: 18),
              ),
              const DsGap(DsSpace.md),
              Expanded(
                //prevents overflow
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          //text wraps if too long
                          child: Text(
                            order.sourceLocationName ?? "-",
                            style: t.titleSm,
                            overflow: TextOverflow.ellipsis, //safe cutoff
                            maxLines: 2,
                          ),
                        ),
                        if (order.status != null) ...[
                          const DsGap(DsSpace.sm),
                          DsStatusChip(label: order.status ?? '', status: order.status),
                        ],
                      ],
                    ),
                    if (order.bookingDateTime != null) Text(Constant.timestampToDateTime(order.bookingDateTime!), style: t.caption),
                  ],
                ),
              ),
            ],
          ),
          const DsGap(DsSpace.sm),
          Row(
            children: [
              Text("${'Section:'.tr} ", style: t.caption),
              Flexible(
                child: Text(Constant.sectionNameFromId(order.sectionId), style: t.caption.withColor(c.textPrimary).w600, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const DsGap(DsSpace.md),
          Text("Vehicle Type :".tr, style: t.overline),
          const DsGap(DsSpace.sm),
          Row(
            children: [
              DsImage(
                url: order.rentalVehicleType?.rentalVehicleIcon ?? Constant.placeHolderImage,
                height: 60,
                width: 60,
                radius: DsRadius.md,
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${order.rentalVehicleType!.name}", style: t.title),
                    const DsGap(DsSpace.xxs),
                    Text("${order.rentalVehicleType!.shortDescription}", style: t.bodySm),
                  ],
                ),
              ),
            ],
          ),
          const DsGap(DsSpace.md),
          Text("Package info :".tr, style: t.overline),
          const DsGap(DsSpace.sm),
          Container(
            padding: const EdgeInsets.all(DsSpace.md),
            decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.rentalPackageModel!.name.toString(), style: t.title),
                      const DsGap(DsSpace.xs),
                      Text(order.rentalPackageModel!.description.toString(), style: t.bodySm),
                    ],
                  ),
                ),
                const DsGap(DsSpace.md),
                Text(
                  Constant.amountShow(currency: RegionService.currencyForRecord(order.regionId), amount: order.rentalPackageModel!.baseFare.toString()),
                  style: t.title.w700.tabular,
                ),
              ],
            ),
          ),
          if (order.status == Constant.orderPlaced || order.status == Constant.driverAccepted) ...[
            const DsGap(DsSpace.md),
            if (order.status == Constant.orderPlaced || order.status == Constant.driverAccepted)
              DsButton.danger(
                label: "Cancel Booking".tr,
                expand: true,
                onPressed: () {
                  // controller.cancelRentalRequest(order);
                },
              ),
          ],
        ],
      ),
    );
  }
}

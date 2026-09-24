import 'package:driver/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/owner_order_list_controller.dart';
import '../../models/cab_order_model.dart';
import '../../models/order_model.dart';
import '../../models/rental_order_model.dart';
import '../../models/section_model.dart';
import '../../models/user_model.dart';
import '../../themes/ds/ds.dart';
import '../cab_screen/cab_order_details.dart';
import '../order_list_screen/order_details_screen.dart';
import '../parcel_screen/parcel_order_details.dart';
import '../rental_service/rental_order_details_screen.dart';

/// Archetype J – fleet order history: a filter card on top, then the matching
/// service's tabbed list with route/status cards.
class OwnerOrderListScreen extends StatelessWidget {
  const OwnerOrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<OwnerOrderListController>(
      init: OwnerOrderListController(),
      builder: (controller) {
        final c = context.dsColors;
        if (controller.isLoading.value) {
          return Scaffold(
            backgroundColor: c.background,
            body: const Padding(
              padding: EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.lg),
              child: DsSkeletonList(itemCount: 4),
            ),
          );
        }

        return Scaffold(
          backgroundColor: c.background,
          body: DsResponsive(
            maxWidth: DsLayout.wideMax,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Filters ───────────────────────────────────────────
                  DsCard(
                    padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Section dropdown ──────────────────────────
                        DsDropdown<SectionModel>(
                          label: "Select Section".tr,
                          hint: "Select Section".tr,
                          prefixIcon: Icons.grid_view_rounded,
                          bottomSpacing: DsSpace.md,
                          value: controller.selectedSection.value,
                          items: controller.ownerSections.map((section) {
                            return DropdownMenuItem<SectionModel>(
                              value: section,
                              child: Text(section.name ?? section.id ?? '', overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (value) {
                            controller.selectedSection.value = value;
                            controller.selectedDriver.value = null;
                          },
                        ),

                        // ── Driver dropdown ──────────────────────────
                        Obx(() => DsDropdown<UserModel?>(
                              label: "Select Driver".tr,
                              hint: "All Drivers".tr,
                              prefixIcon: Icons.person_outline_rounded,
                              bottomSpacing: DsSpace.md,
                              value: controller.selectedDriver.value,
                              items: [
                                DropdownMenuItem<UserModel?>(
                                  value: null,
                                  child: Text("All Drivers".tr, overflow: TextOverflow.ellipsis),
                                ),
                                ...controller.filteredDrivers.map((driver) {
                                  return DropdownMenuItem<UserModel?>(
                                    value: driver,
                                    child: Text(
                                      "${driver.firstName ?? ''} ${driver.lastName ?? ''}",
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (UserModel? value) {
                                controller.selectedDriver.value = value;
                              },
                            )),

                        // ── Search button ────────────────────────────
                        DsButton.primary(
                          label: "Search".tr,
                          icon: Icons.search_rounded,
                          expand: true,
                          onPressed: controller.searchOrders,
                        ),
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.lg),

                  // ── Order list based on section's serviceTypeFlag ────
                  Expanded(
                    child: Obx(() {
                      if (controller.isLoadingOrders.value) {
                        return const DsSkeletonList(itemCount: 4);
                      }

                      switch (controller.selectedServiceFlag) {
                        case 'cab-service':
                          return _cabListView(controller);
                        case 'parcel_delivery':
                          return _parcelListView(controller);
                        case 'rental-service':
                          return _rentalListView(controller);
                        case 'delivery-service':
                          return _vendorListView(controller);
                        default:
                          return DsEmptyState(
                            icon: Icons.tune_rounded,
                            title: "Select a section to view orders".tr,
                          );
                      }
                    }),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Shared pieces ─────────────────────────────────────────────────────

  Widget _emptyOrders() => DsEmptyState(
        icon: Icons.receipt_long_outlined,
        title: "No orders found".tr,
      );

  Widget _orderDate(BuildContext context, String text) {
    final t = context.dsText;
    final c = context.dsColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 14, color: c.info),
          const DsGap(DsSpace.xs),
          Flexible(child: Text(text, style: t.caption.withColor(c.infoStrong), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  // ── Cab list view ─────────────────────────────────────────────────────

  Widget _cabListView(OwnerOrderListController controller) {
    return DefaultTabController(
      length: controller.cabTabTitles.length,
      initialIndex:
          controller.cabTabTitles.indexOf(controller.cabSelectedTab.value),
      child: Column(
        children: [
          DsTabBar(
            onTap: (index) {
              controller.cabSelectedTab(controller.cabTabTitles[index]);
            },
            tabs: controller.cabTabTitles.toList(),
          ),
          Expanded(
            child: TabBarView(
              children: controller.cabTabTitles.map((title) {
                final orders = controller.getCabOrdersForTab(title);
                if (orders.isEmpty) {
                  return _emptyOrders();
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: DsSpace.md, bottom: DsSpace.xxxl),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    CabOrderModel order = orders[index];
                    final t = context.dsText;
                    return DsFadeSlideIn(
                      index: index,
                      child: DsCard.outlined(
                        margin: const EdgeInsets.only(bottom: DsSpace.md),
                        onTap: () => Get.to(() => CabOrderDetails(),
                            arguments: {"cabOrderModel": order}),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                DsSectionBadge(section: DsSection.cab, label: 'Cab'.tr),
                                const Spacer(),
                                Flexible(
                                  child: DsStatusChip(
                                    label: order.status.toString(),
                                    status: order.status?.toString(),
                                  ),
                                ),
                              ],
                            ),
                            const DsGap(DsSpace.md),
                            DsRouteStops(
                              stops: [
                                DsRouteStop(
                                  kind: DsStopKind.pickup,
                                  label: 'Pickup'.tr,
                                  address: order.sourceLocationName.toString(),
                                ),
                                DsRouteStop(
                                  kind: DsStopKind.drop,
                                  label: 'Drop-off'.tr,
                                  address: order.destinationLocationName.toString(),
                                ),
                              ],
                            ),
                            const DsGap(DsSpace.sm),
                            Row(
                              children: [
                                const Spacer(),
                                Text('View details'.tr, style: t.link),
                                Icon(Icons.chevron_right_rounded, size: 18, color: context.dsColors.brand),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Parcel list view ──────────────────────────────────────────────────

  Widget _parcelListView(OwnerOrderListController controller) {
    return DefaultTabController(
      length: controller.parcelTabTitles.length,
      initialIndex: controller.parcelTabTitles
          .indexOf(controller.parcelSelectedTab.value),
      child: Column(
        children: [
          DsTabBar(
            onTap: (index) {
              controller
                  .parcelSelectedTab(controller.parcelTabTitles[index]);
            },
            tabs: controller.parcelTabTitles.toList(),
          ),
          Expanded(
            child: TabBarView(
              children: controller.parcelTabTitles.map((title) {
                final orders =
                    controller.getParcelOrdersForTab(title);
                if (orders.isEmpty) {
                  return _emptyOrders();
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: DsSpace.md, bottom: DsSpace.xxxl),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return DsFadeSlideIn(
                      index: index,
                      child: DsCard.outlined(
                        margin: const EdgeInsets.only(bottom: DsSpace.md),
                        onTap: () => Get.to(
                            () => const ParcelOrderDetails(),
                            arguments: order),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                DsSectionBadge(section: DsSection.parcel, label: 'Parcel'.tr),
                                const Spacer(),
                                if (order.status != null)
                                  Flexible(child: DsStatusChip(label: order.status!, status: order.status)),
                              ],
                            ),
                            const DsGap(DsSpace.sm),
                            _orderDate(
                              context,
                              "Order Date:${order.isSchedule == true ? controller.formatDate(order.createdAt!) : controller.formatDate(order.senderPickupDateTime!)}",
                            ),
                            _contactBlock(
                              context,
                              kind: DsStopKind.pickup,
                              title: "Pickup Address (Sender):".tr,
                              name: order.sender?.name ?? '',
                              address: order.sender?.address ?? '',
                              phone: order.sender?.phone ?? '',
                            ),
                            const DsGap(DsSpace.md),
                            _contactBlock(
                              context,
                              kind: DsStopKind.drop,
                              title: "Delivery Address (Receiver):".tr,
                              name: order.receiver?.name ?? '',
                              address: order.receiver?.address ?? '',
                              phone: order.receiver?.phone ?? '',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactBlock(
    BuildContext context, {
    required DsStopKind kind,
    required String title,
    required String name,
    required String address,
    required String phone,
  }) {
    final c = context.dsColors;
    final t = context.dsText;
    final isPickup = kind == DsStopKind.pickup;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsIconWell(
          icon: isPickup ? Icons.arrow_upward_rounded : Icons.flag_rounded,
          tone: isPickup ? DsTone.brand : DsTone.danger,
          size: 36,
        ),
        const DsGap(DsSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              const DsGap(DsSpace.xxs),
              Text(name, style: t.titleSm, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(address, style: t.bodySecondary, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (phone.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.call_outlined, size: 14, color: c.textMuted),
                    const DsGap(DsSpace.xs),
                    Flexible(child: Text(phone, style: t.bodySm.tabular, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Rental list view ──────────────────────────────────────────────────

  Widget _rentalListView(OwnerOrderListController controller) {
    return DefaultTabController(
      length: controller.rentalTabTitles.length,
      initialIndex: controller.rentalTabTitles
          .indexOf(controller.rentalSelectedTab.value),
      child: Column(
        children: [
          DsTabBar(
            onTap: (index) {
              controller
                  .rentalSelectedTab(controller.rentalTabTitles[index]);
            },
            tabs: controller.rentalTabTitles.toList(),
          ),
          Expanded(
            child: TabBarView(
              children: controller.rentalTabTitles.map((title) {
                final orders =
                    controller.getRentalOrdersForTab(title);
                if (orders.isEmpty) {
                  return _emptyOrders();
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: DsSpace.md, bottom: DsSpace.xxxl),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    RentalOrderModel order = orders[index];
                    final c = context.dsColors;
                    final t = context.dsText;
                    return DsFadeSlideIn(
                      index: index,
                      child: DsCard.outlined(
                        margin: const EdgeInsets.only(bottom: DsSpace.md),
                        onTap: () => Get.to(
                            () => RentalOrderDetailsScreen(),
                            arguments: {"rentalOrder": order.id}),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                DsSectionBadge(section: DsSection.rental, label: 'Rental'.tr),
                                const Spacer(),
                                if (order.status != null)
                                  Flexible(child: DsStatusChip(label: order.status ?? '', status: order.status)),
                              ],
                            ),
                            const DsGap(DsSpace.md),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DsIconWell(icon: Icons.place_outlined, tone: DsTone.brand, size: 36),
                                const DsGap(DsSpace.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.sourceLocationName ?? "-",
                                        style: t.titleSm,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                      if (order.bookingDateTime != null)
                                        Text(
                                          Constant.timestampToDateTime(order.bookingDateTime!),
                                          style: t.caption,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const DsGap(DsSpace.lg),
                            Text("Vehicle Type :".tr, style: t.label.withColor(c.textSecondary)),
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
                                      Text(
                                        "${order.rentalVehicleType!.name}",
                                        style: t.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const DsGap(DsSpace.xxs),
                                      Text(
                                        "${order.rentalVehicleType!.shortDescription}",
                                        style: t.bodySecondary,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const DsGap(DsSpace.lg),
                            Text("Package info :", style: t.label.withColor(c.textSecondary)),
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
                                        Text(
                                          order.rentalPackageModel!.name.toString(),
                                          style: t.titleSm,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const DsGap(DsSpace.xs),
                                        Text(
                                          order.rentalPackageModel!.description.toString(),
                                          style: t.bodySecondary,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const DsGap(DsSpace.md),
                                  Text(
                                    Constant.amountShow(
                                        currency: RegionService.currencyForRecord(order.regionId),
                                        amount: order.rentalPackageModel!.baseFare.toString()),
                                    style: t.title.tabular,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Vendor (Delivery) list view ───────────────────────────────────────

  Widget _vendorListView(OwnerOrderListController controller) {
    return DefaultTabController(
      length: controller.vendorTabTitles.length,
      initialIndex: controller.vendorTabTitles
          .indexOf(controller.vendorSelectedTab.value),
      child: Column(
        children: [
          DsTabBar(
            onTap: (index) {
              controller
                  .vendorSelectedTab(controller.vendorTabTitles[index]);
            },
            tabs: controller.vendorTabTitles.toList(),
          ),
          Expanded(
            child: TabBarView(
              children: controller.vendorTabTitles.map((title) {
                final orders =
                    controller.getVendorOrdersForTab(title);
                if (orders.isEmpty) {
                  return _emptyOrders();
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: DsSpace.md, bottom: DsSpace.xxxl),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    OrderModel order = orders[index];
                    final c = context.dsColors;
                    final t = context.dsText;
                    return DsFadeSlideIn(
                      index: index,
                      child: DsCard.outlined(
                        margin: const EdgeInsets.only(bottom: DsSpace.md),
                        onTap: () => Get.to(
                            () => const OrderDetailsScreen(),
                            arguments: {"orderModel": order}),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                DsSectionBadge(section: DsSection.delivery, label: 'Delivery'.tr),
                                const Spacer(),
                                // ── Status ───────────────────────
                                if (order.status != null)
                                  Flexible(child: DsStatusChip(label: order.status!, status: order.status)),
                              ],
                            ),
                            const DsGap(DsSpace.sm),
                            // ── Order date ───────────────────
                            if (order.createdAt != null)
                              _orderDate(context, "Order Date: ${controller.formatDate(order.createdAt!)}"),
                            // ── Vendor name ──────────────────
                            Text(
                              order.vendor?.title ?? '-',
                              style: t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const DsGap(DsSpace.sm),
                            // ── Delivery address ─────────────
                            if (order.address != null)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on_outlined, size: 18, color: c.textMuted),
                                  const DsGap(DsSpace.xs),
                                  Expanded(
                                    child: Text(
                                      order.address?.address ?? '',
                                      style: t.bodySecondary,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            const DsGap(DsSpace.sm),
                            // ── Products summary ─────────────
                            if (order.products != null &&
                                order.products!.isNotEmpty)
                              DsBadge(
                                label: "${order.products!.length} item${order.products!.length > 1 ? 's' : ''}",
                                icon: Icons.shopping_bag_outlined,
                                small: true,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

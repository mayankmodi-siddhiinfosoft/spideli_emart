import 'package:driver/app/owner_screen/driver_create_screen.dart';
import 'package:driver/app/owner_screen/driver_order_list.dart';
import 'package:driver/controllers/owner_home_controller.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Archetype G – fleet roster: outlined driver cards with avatar, contact and
/// an availability status chip.
class ViewAllDriverScreen extends StatelessWidget {
  const ViewAllDriverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<OwnerHomeController>(
      init: Get.find<OwnerHomeController>(),
      builder: (controller) {
        final drivers = controller.driverList.toList();
        final online = drivers.where((d) => d.isActive != false).length;
        return DsScaffold.collapsing(
          title: "All Drivers".tr,
          subtitle: drivers.isEmpty ? null : '${'Online'.tr}: $online / ${drivers.length}',
          slivers: [
            if (drivers.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(
                  icon: Icons.groups_outlined,
                  title: "No drivers found".tr,
                ),
              )
            else
              DsSliverResponsive(
                top: DsSpace.md,
                bottom: DsSpace.xxxl,
                sliver: SliverList.builder(
                  itemCount: drivers.length,
                  itemBuilder: (context, index) {
                    final driver = drivers[index];
                    return DsFadeSlideIn(
                      index: index,
                      child: _DriverCard(
                        driver: driver,
                        onEdit: () {
                          Get.to(() => const DriverCreateScreen(), arguments: {"driverModel": driver})?.then((value0) {
                            if (value0 == true) controller.getDriverList();
                          });
                        },
                        onDelete: () {
                          controller.deleteDriver(driver.id.toString());
                        },
                        onViewOrders: () {
                          Get.to(() => const DriverOrderList(), arguments: {
                            "driverId": driver.id,
                            "serviceType": driver.serviceTypes?.first,
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DriverCard extends StatelessWidget {
  final UserModel driver;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewOrders;

  const _DriverCard({
    required this.driver,
    required this.onEdit,
    required this.onDelete,
    required this.onViewOrders,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final isOnline = driver.isActive != false;
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsAvatar(
                imageUrl: driver.profilePictureURL ?? '',
                name: driver.fullName(),
                size: 46,
                statusTone: isOnline ? DsTone.success : DsTone.neutral,
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(driver.fullName(), style: t.titleSm, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const DsGap(DsSpace.xxs),
                    Text(
                      '${driver.countryCode ?? ''} ${driver.phoneNumber ?? ''}',
                      style: t.bodySm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const DsGap(DsSpace.sm),
              PopupMenuButton<String>(
                tooltip: 'More'.tr,
                onSelected: (value) {
                  if (value == 'Edit Driver') {
                    onEdit();
                  } else if (value == 'Delete Driver') {
                    onDelete();
                  } else if (value == 'View All Order') {
                    onViewOrders();
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: 'Edit Driver', child: Text('Edit Driver'.tr, style: t.body)),
                  PopupMenuItem<String>(value: 'Delete Driver', child: Text('Delete Driver'.tr, style: t.body)),
                  PopupMenuItem<String>(value: 'View All Order', child: Text('View All Order'.tr, style: t.body)),
                ],
                color: c.surfaceRaised,
                icon: Icon(Icons.more_vert, color: c.iconDefault),
              ),
            ],
          ),
          const DsGap(DsSpace.md),
          Row(
            children: [
              DsBadge(
                label: isOnline ? "Online".tr : "Offline".tr,
                tone: isOnline ? DsTone.success : DsTone.neutral,
                icon: isOnline ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded,
                small: true,
              ),
              const Spacer(),
              DsButton.ghost(
                label: 'View All Order'.tr,
                size: DsButtonSize.sm,
                trailingIcon: Icons.chevron_right_rounded,
                onPressed: onViewOrders,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

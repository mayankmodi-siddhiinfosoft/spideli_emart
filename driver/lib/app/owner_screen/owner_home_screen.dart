import 'package:driver/app/owner_screen/driver_create_screen.dart';
import 'package:driver/app/owner_screen/view_all_drivers.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/owner_dashboard_controller.dart';
import 'package:driver/controllers/owner_home_controller.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'driver_order_list.dart';

/// Fleet owner dashboard – archetype E/G hybrid: an earnings hero, a KPI grid
/// and the fleet roster with live online status.
class OwnerHomeScreen extends StatelessWidget {
  const OwnerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final dashController = Get.put(OwnerDashboardController());
    return Obx(() {
      themeController.isDark.value;
      final c = context.dsColors;
      final t = context.dsText;
      return GetX(
          init: OwnerHomeController(),
          builder: (controller) {
            return Scaffold(
              backgroundColor: c.background,
              body: controller.isLoading.value
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.lg),
                      child: DsSkeletonDashboard(tiles: 4),
                    )
                  : Constant.userModel?.isDocumentVerify == false && Constant.userModel?.isAutoVerify == false
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                          child: Center(
                            child: DsResponsive(
                              // Fill the Center, and center the content inside it.
                              alignment: Alignment.center,
                              maxWidth: 520,
                              child: DsEmptyState(
                                icon: Icons.assignment_outlined,
                                tone: DsTone.warning,
                                title: "Document Verification in Pending".tr,
                                message: "Your documents are being reviewed. We will notify you once the verification is complete.".tr,
                                actionLabel: "View Status".tr,
                                actionIcon: Icons.visibility_outlined,
                                onAction: () {
                                  OwnerDashboardController dashBoardController = Get.put(OwnerDashboardController());
                                  dashBoardController.drawerIndex.value = 4;
                                },
                              ),
                            ),
                          ),
                        )
                      : DsResponsive(
                          maxWidth: DsLayout.wideMax,
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: DsFadeSlideIn.stagger([
                                  Obx(() {
                                    num wallet = dashController.userModel.value.walletAmount ?? 0.0;
                                    return wallet < double.parse(Constant.ownerMinimumDepositToRideAccept)
                                        ? Padding(
                                            padding: const EdgeInsets.only(bottom: DsSpace.md),
                                            child: DsInlineAlert(
                                              tone: DsTone.danger,
                                              icon: Icons.account_balance_wallet_outlined,
                                              message:
                                                  "You must have a minimum of ${Constant.amountShow(amount: Constant.ownerMinimumDepositToRideAccept.toString())} in your wallet to receive orders to your driver"
                                                      .tr,
                                            ),
                                          )
                                        : const SizedBox();
                                  }),
                                  const DsGap(DsSpace.sm),

                                  // ── Earnings hero ────────────────────────────
                                  DsCard.gradient(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Earnings'.tr,
                                                style: t.labelSm.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                                              ),
                                              const DsGap(DsSpace.xs),
                                              DsAnimatedCounter(
                                                value: controller.totalEarningsAllDrivers,
                                                style: t.metricLg.copyWith(color: Colors.white),
                                                format: (v) => '${Constant.currencyModel!.symbol.toString()}${v.toStringAsFixed(2)}',
                                              ),
                                            ],
                                          ),
                                        ),
                                        const DsGap(DsSpace.md),
                                        const DsIconWell(icon: Icons.trending_up_rounded, size: 48, circle: true, onBrand: true),
                                      ],
                                    ),
                                  ),
                                  const DsGap(DsSpace.md),

                                  // ── KPI tiles ────────────────────────────────
                                  DsAdaptiveGrid(
                                    minItemWidth: 160,
                                    children: [
                                      DsStatTile(
                                        icon: Icons.receipt_long_rounded,
                                        label: 'Total Bookings'.tr,
                                        countTo: controller.totalRidesAllDrivers,
                                        format: (v) => v.toInt().toString(),
                                        tone: DsTone.info,
                                      ),
                                      DsStatTile(
                                        icon: Icons.groups_rounded,
                                        label: 'Total Drivers'.tr,
                                        countTo: controller.driverList.length,
                                        format: (v) => v.toInt().toString(),
                                        tone: DsTone.brand,
                                        onTap: () {
                                          Get.to(ViewAllDriverScreen())!.then(
                                            (value) {
                                              controller.getDriverList();
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const DsGap(DsSpace.xxl),

                                  // ── Fleet roster ─────────────────────────────
                                  if (controller.driverList.isNotEmpty) ...[
                                    DsSectionHeader(
                                      title: 'Your Available Drivers'.tr,
                                      subtitle: 'Real-time status and earnings summary'.tr,
                                      actionLabel: 'View all'.tr,
                                      onAction: () {
                                        Get.to(ViewAllDriverScreen())!.then(
                                          (value) {
                                            controller.getDriverList();
                                          },
                                        );
                                      },
                                    ),
                                    const DsGap(DsSpace.md),
                                    DsCard(
                                      padding: EdgeInsets.zero,
                                      child: Column(
                                        children: [
                                          for (var index = 0; index < (controller.driverList.length > 5 ? 5 : controller.driverList.length); index++) ...[
                                            if (index > 0) DsDivider(spacing: 0, indent: 68),
                                            _DriverRow(
                                              index: index,
                                              driverModel: controller.driverList[index],
                                              isActive: controller.driverList[index].isActive != false,
                                              onEdit: () {
                                                Get.to(DriverCreateScreen(), arguments: {"driverModel": controller.driverList[index]})!.then(
                                                  (value0) {
                                                    if (value0 == true) {
                                                      controller.getDriverList();
                                                    }
                                                  },
                                                );
                                              },
                                              onDelete: () {
                                                controller.deleteDriver(controller.driverList[index].id.toString());
                                              },
                                              onViewOrders: () {
                                                final UserModel driverModel = controller.driverList[index];
                                                print("driver ::::::: ${driverModel.email}");
                                                Get.to(() => const DriverOrderList(), arguments: {
                                                  "driverId": driverModel.id,
                                                  "serviceType": driverModel.serviceTypes?.first,
                                                });
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                  const DsGap(DsSpace.huge),
                                ]),
                              ),
                            ),
                          ),
                        ),
              floatingActionButton: (Constant.userModel?.isDocumentVerify == true && Constant.userModel?.isAutoVerify == false) || Constant.userModel?.isAutoVerify == true
                  ? FloatingActionButton.extended(
                      onPressed: () {
                        Get.to(DriverCreateScreen())!.then((value) {
                          if (value == true) {
                            controller.getDriverList();
                          }
                        });
                      },
                      backgroundColor: c.brand,
                      foregroundColor: c.onBrand,
                      icon: const Icon(Icons.add_rounded),
                      label: Text('Add Driver'.tr, style: t.label.copyWith(color: c.onBrand)),
                    )
                  : const SizedBox.shrink(),
            );
          });
    });
  }
}

/// One fleet driver row: avatar with a live status ring, name, phone, an
/// online / offline status chip and the existing actions menu.
class _DriverRow extends StatelessWidget {
  final int index;
  final UserModel driverModel;
  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewOrders;

  const _DriverRow({
    required this.index,
    required this.driverModel,
    required this.isActive,
    required this.onEdit,
    required this.onDelete,
    required this.onViewOrders,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsFadeSlideIn(
      index: index,
      child: DsListTile(
        leading: DsAvatar(
          imageUrl: driverModel.profilePictureURL.toString(),
          name: driverModel.fullName(),
          size: 44,
          statusTone: isActive ? DsTone.success : DsTone.neutral,
        ),
        title: driverModel.fullName(),
        subtitle: '${driverModel.countryCode ?? ''} ${driverModel.phoneNumber ?? ''}',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsBadge(
              label: isActive ? "Online".tr : "Offline".tr,
              tone: isActive ? DsTone.success : DsTone.neutral,
              icon: isActive ? Icons.circle : Icons.circle_outlined,
              small: true,
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
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
      ),
    );
  }
}

import 'package:driver/utils/region_service.dart';
import 'package:driver/app/parcel_screen/parcel_order_details.dart';
import 'package:driver/app/parcel_screen/parcel_search_screen.dart';
import 'package:driver/app/parcel_screen/parcel_tracking_screen.dart';
import 'package:driver/app/parcel_screen/parcel_tracking/parcel_scan_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/parcel_dashboard_controller.dart';
import 'package:driver/controllers/parcel_home_controller.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/services/driver_job_queue_service.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constant/show_toast_dialog.dart';
import '../../models/user_model.dart';
import '../../utils/fire_store_utils.dart';
import '../chat_screens/chat_screen.dart';

/// Parcel home (archetype A/J hybrid): a scan-first job board. The scan FAB
/// stays on top of a live list of assigned parcels, each one a route card with
/// its own on-the-road action.
class ParcelHomeScreen extends StatelessWidget {
  const ParcelHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetX(
          init: ParcelHomeController(),
          builder: (controller) {
            final c = context.dsColors;
            final t = context.dsText;
            final bool isVerified = !(Constant.userModel?.isDocumentVerify == false && Constant.userModel?.isAutoVerify == false);
            final bool isLoading = controller.isLoading.value;
            final bool docsPending = Constant.userModel?.isDocumentVerify == false && Constant.userModel?.isAutoVerify == false;
            final bool isOffline = controller.userModel.value.isActive == false;
            final List<ParcelOrderModel> orders = controller.parcelOrdersList.toList();

            Widget body;
            if (isLoading) {
              body = const DsSkeletonList(itemCount: 4);
            } else if (docsPending) {
              body = DsEmptyState(
                icon: Icons.assignment_outlined,
                tone: DsTone.warning,
                title: "Document Verification in Pending".tr,
                message: "Your documents are being reviewed. We will notify you once the verification is complete.".tr,
                actionLabel: "View Status".tr,
                actionIcon: Icons.verified_user_outlined,
                onAction: () async {
                  ParcelDashboardController dashBoardController = Get.put(ParcelDashboardController());
                  dashBoardController.drawerIndex.value = 4;
                },
              );
            } else if (isOffline) {
              body = DsEmptyState(
                icon: Icons.wifi_tethering_off_rounded,
                tone: DsTone.neutral,
                title: 'You’re Currently Offline'.tr,
                message: 'Switch to online mode to accept and deliver parcel orders.'.tr,
              );
            } else if (orders.isEmpty) {
              body = Column(
                children: [
                  Obx(() {
                    final user = controller.userModel.value;
                    final controllerOwner = controller.ownerModel.value;

                    final num wallet = user.walletAmount ?? 0.0;
                    final num ownerWallet = controllerOwner.walletAmount ?? 0.0;
                    final String? ownerId = user.ownerId;

                    final num minDeposit = double.parse(Constant.minimumDepositToRideAccept);

                    // 🧠 Logic:
                    // If individual driver → check driver's own wallet
                    // If owner driver → check owner's wallet
                    if ((ownerId == null || ownerId.isEmpty) && wallet < minDeposit) {
                      // Individual driver case
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, 0),
                        child: DsInlineAlert(
                          tone: DsTone.warning,
                          icon: Icons.account_balance_wallet_outlined,
                          message:
                              "${'You must have at least'.tr} ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} ${'in your wallet to receive orders'.tr}",
                        ),
                      );
                    } else if (ownerId != null && ownerId.isNotEmpty && ownerWallet < minDeposit) {
                      // Owner-driver case
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, 0),
                        child: DsInlineAlert(
                          tone: DsTone.warning,
                          icon: Icons.account_balance_wallet_outlined,
                          message: "Your owner doesn't have the minimum wallet amount to receive orders. Please contact your owner.".tr,
                        ),
                      );
                    } else {
                      return const SizedBox();
                    }
                  }),
                  const _NewParcelJobsBanner(),
                  Expanded(
                    child: DsEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No parcel requests available in your selected zone.'.tr,
                      message: 'Try changing the location or date.'.tr,
                      actionLabel: "Search Parcel".tr,
                      actionIcon: Icons.search_rounded,
                      onAction: () {
                        Get.to(ParcelSearchScreen())!.then((value) {
                          if (value != null && value is bool && value) {
                            controller.getParcelList();
                          }
                        });
                      },
                    ),
                  ),
                ],
              );
            } else {
              body = RefreshIndicator(
                color: c.brand,
                onRefresh: () async {
                  await controller.getParcelList();
                },
                child: CustomScrollView(
                  slivers: [
                    const DsSliverResponsive(
                      sliver: SliverToBoxAdapter(child: _NewParcelJobsBanner(gutter: false)),
                    ),
                    DsSliverResponsive(
                      top: DsSpace.lg,
                      sliver: SliverToBoxAdapter(
                        child: DsFadeSlideIn(
                          child: Row(
                            children: [
                              DsSectionBadge(section: DsSection.parcel, label: "Parcel".tr),
                              const DsGap(DsSpace.sm),
                              Expanded(
                                child: Text(
                                  "${'Active parcels'.tr} · ${orders.length}",
                                  style: t.labelSm,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    DsSliverResponsive(
                      top: DsSpace.md,
                      bottom: 96,
                      sliver: SliverList.separated(
                        itemCount: orders.length,
                        separatorBuilder: (_, _) => const DsGap(DsSpace.lg),
                        itemBuilder: (context, index) {
                          ParcelOrderModel parcelBookingData = orders[index];
                          return DsFadeSlideIn(
                            index: index,
                            child: _ParcelJobCard(
                              order: parcelBookingData,
                              amount: Constant.amountShow(
                                      currency: RegionService.currencyForRecord(parcelBookingData.regionId),
                                      amount: controller.calculateParcelTotalAmountBooking(parcelBookingData))
                                  .tr,
                              onOpen: () {
                                Get.to(() => const ParcelOrderDetails(), arguments: parcelBookingData);
                              },
                              onChat: () async {
                                ShowToastDialog.showLoader("Please wait".tr);

                                UserModel? customer = await FireStoreUtils.getUserProfile(parcelBookingData.authorID.toString());
                                UserModel? driver = await FireStoreUtils.getUserProfile(parcelBookingData.driverId.toString());

                                ShowToastDialog.closeLoader();

                                Get.to(const ChatScreen(), arguments: {
                                  "senderName": driver!.fullName(),
                                  "receivedName": customer!.fullName(),
                                  "orderId": parcelBookingData.id,
                                  "senderId": driver.id,
                                  "receivedId": customer.id,
                                  "receivedProfileUrl": customer.profilePictureURL ?? "",
                                  "senderProfileUrl": driver.profilePictureURL ?? "",
                                  "token": customer.fcmToken,
                                  "chatType": Constant.userRoleDriver,
                                });
                              },
                              onPickup: () async {
                                controller.pickupParcel(parcelBookingData);
                              },
                              onDeliver: () async {
                                controller.completeParcel(parcelBookingData, context: context, isDark: isDark);
                              },
                              onTrack: () async {
                                Get.to(() => ParcelTrackingScreen(), arguments: {'parcelOrder': parcelBookingData});
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }

            return DsScaffold(
              backgroundColor: c.background,
              floatingActionButton: isLoading || !isVerified
                  ? null
                  : FloatingActionButton.extended(
                      heroTag: 'parcelScan',
                      backgroundColor: c.brand,
                      foregroundColor: c.onBrand,
                      onPressed: () => Get.to(() => const ParcelScanScreen())!.then((_) => controller.getParcelList()),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text("Scan parcel".tr, style: t.label.withColor(c.onBrand)),
                    ),
              body: body,
            );
          });
    });
  }
}

/// Badge for the automatic driver-notification queue (admin spec §14): the
/// parcel requests placed while the driver was offline, found the moment they
/// came back online. Hidden — and costing nothing — when there are none.
class _NewParcelJobsBanner extends StatelessWidget {
  /// False inside a sliver that already applies the responsive gutter.
  final bool gutter;

  const _NewParcelJobsBanner({this.gutter = true});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int waiting = DriverJobQueueService.parcelJobCount.value;
      if (waiting <= 0) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.fromLTRB(gutter ? DsSpace.lg : 0, DsSpace.lg, gutter ? DsSpace.lg : 0, 0),
        child: DsInlineAlert(
          tone: DsTone.brand,
          icon: Icons.notifications_active_outlined,
          title: "New parcel requests".tr,
          message: waiting == 1
              ? "1 parcel request is waiting for you.".tr
              : "$waiting ${'parcel requests are waiting for you.'.tr}",
          actionLabel: "View requests".tr,
          onAction: () {
            Get.to(ParcelSearchScreen())!.then((value) {
              if (Get.isRegistered<ParcelHomeController>()) Get.find<ParcelHomeController>().getParcelList();
            });
          },
        ),
      );
    });
  }
}

/// One assigned parcel: route, customer, numbers and the step's action.
class _ParcelJobCard extends StatelessWidget {
  final ParcelOrderModel order;
  final String amount;
  final VoidCallback onOpen;
  final VoidCallback onChat;
  final VoidCallback onPickup;
  final VoidCallback onDeliver;
  final VoidCallback onTrack;

  const _ParcelJobCard({
    required this.order,
    required this.amount,
    required this.onOpen,
    required this.onChat,
    required this.onPickup,
    required this.onDeliver,
    required this.onTrack,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool isAccepted = order.status == Constant.driverAccepted;
    final bool showTrack = order.status == Constant.driverAccepted || order.status == Constant.orderInTransit;
    return DsCard.outlined(
      onTap: onOpen,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: c.surfaceAlt,
            padding: const EdgeInsets.all(DsSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DsSectionBadge(section: DsSection.parcel, label: "Parcel".tr),
                    const DsGap(DsSpace.sm),
                    if ((order.status ?? '').isNotEmpty) Flexible(child: DsStatusChip(label: order.status!.tr, status: order.status)),
                  ],
                ),
                const DsGap(DsSpace.md),
                DsRouteStops(
                  stops: [
                    DsRouteStop(kind: DsStopKind.pickup, label: 'Pickup'.tr, address: "${order.sender!.address}"),
                    DsRouteStop(kind: DsStopKind.drop, label: 'Delivery'.tr, address: "${order.receiver!.address}"),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DsSpace.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    DsAvatar(imageUrl: order.author!.profilePictureURL.toString(), name: order.author!.fullName(), size: 48),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: Text(
                        order.author!.fullName().tr,
                        textAlign: TextAlign.start,
                        style: t.titleSm.w700,
                      ),
                    ),
                    const DsGap(DsSpace.sm),
                    DsIconButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      semanticLabel: "Chat".tr,
                      variant: DsIconButtonVariant.tonal,
                      onPressed: onChat,
                    ),
                  ],
                ),
                const DsGap(DsSpace.lg),
                DsTripMetrics(
                  items: [
                    DsTripMetric(icon: Icons.payments_outlined, value: amount, label: 'Amount'.tr),
                    DsTripMetric(icon: Icons.event_outlined, value: '${Constant.timestampToDate(order.senderPickupDateTime!)}  '.tr, label: 'Date'.tr),
                    DsTripMetric(icon: Icons.scale_outlined, value: '${order.parcelWeight}'.tr, label: 'Weight'.tr),
                  ],
                ),
                const DsGap(DsSpace.lg),
                isAccepted
                    ? DsButton.success(
                        label: "Pickup Parcel".tr,
                        icon: Icons.inventory_2_outlined,
                        size: DsButtonSize.xl,
                        expand: true,
                        onPressed: onPickup,
                      )
                    : DsButton.success(
                        label: "Deliver Parcel".tr,
                        icon: Icons.check_circle_outline_rounded,
                        size: DsButtonSize.xl,
                        expand: true,
                        onPressed: onDeliver,
                      ),
                showTrack
                    ? Column(
                        children: [
                          const DsGap(DsSpace.md),
                          DsButton.tonal(
                            label: "Parcel Track".tr,
                            icon: Icons.location_on_outlined,
                            size: DsButtonSize.lg,
                            expand: true,
                            onPressed: onTrack,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

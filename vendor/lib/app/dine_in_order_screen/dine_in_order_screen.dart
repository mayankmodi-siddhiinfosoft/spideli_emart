import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:vendor/app/add_restaurant_screen/add_restaurant_screen.dart';
import 'package:vendor/app/dine_in_screen/dine_in_create_screen.dart';
import 'package:vendor/app/verification_screen/verification_screen.dart';
import 'package:vendor/app/widgets/order_ui.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/send_notification.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/dine_in_order_controller.dart';
import 'package:vendor/models/dine_in_booking_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class DineInOrderScreen extends StatelessWidget {
  const DineInOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: DineInOrderController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        return controller.isLoading.value
            ? ColoredBox(
                color: c.background,
                child: const SafeArea(
                  child: DsResponsive(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(DsSpace.lg),
                      child: Column(
                        children: [
                          DsSkeletonList(itemCount: 1, carded: false, padding: EdgeInsets.zero),
                          DsGap(DsSpace.lg),
                          DsSkeletonCard(height: 48),
                          DsGap(DsSpace.lg),
                          DsSkeletonCard(height: 220),
                          DsGap(DsSpace.md),
                          DsSkeletonCard(height: 220),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : DefaultTabController(
                length: 2,
                child: Scaffold(
                  backgroundColor: c.background,
                  appBar: DsAppBar(
                    showBack: false,
                    titleWidget: Row(
                      children: [
                        DsAvatar(imageUrl: controller.userModel.value.profilePictureURL.toString(), name: controller.userModel.value.fullName(), size: 42, ring: true),
                        const DsGap(DsSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Welcome to spideli Store".tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption),
                              Text(controller.userModel.value.fullName().tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                            ],
                          ),
                        ),
                      ],
                    ),
                    bottom: DsTabBar(
                      onTap: (value) {
                        controller.selectedTabIndex.value = value;
                      },
                      tabs: ["New".tr, "History".tr],
                    ),
                  ),
                  body: controller.userModel.value.isAutoVerify == false && controller.userModel.value.isDocumentVerify == false
                      ? Center(
                          child: SingleChildScrollView(
                            child: DsFadeSlideIn(
                              child: DsEmptyState(
                                icon: Icons.description_outlined,
                                tone: DsTone.warning,
                                title: "Document Verification in Pending".tr,
                                message: "Your documents are being reviewed. We will notify you once the verification is complete.".tr,
                                actionLabel: "View Status".tr,
                                actionIcon: Icons.verified_user_outlined,
                                onAction: () async {
                                  Get.to(const VerificationScreen());
                                },
                              ),
                            ),
                          ),
                        )
                      : controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            child: DsFadeSlideIn(
                              child: DsEmptyState(
                                icon: Icons.add_business_outlined,
                                title: "Add Your First Store".tr,
                                message: "Get started by adding your Store details to manage your menu, orders, and reservations.".tr,
                                actionLabel: "Add Store".tr,
                                actionIcon: Icons.add_rounded,
                                onAction: () async {
                                  Get.to(const AddRestaurantScreen());
                                },
                              ),
                            ),
                          ),
                        )
                      : (controller.vendorModel.value.restaurantCost == null || controller.vendorModel.value.restaurantCost!.isEmpty)
                      ? Center(
                          child: SingleChildScrollView(
                            child: DsFadeSlideIn(
                              child: DsEmptyState(
                                icon: Icons.table_restaurant_outlined,
                                tone: DsTone.info,
                                title: "Dine-In Details Missing".tr,
                                message: "Please add your store’s dine-in details to start accepting reservations.".tr,
                                actionLabel: "Add Dine in".tr,
                                actionIcon: Icons.add_rounded,
                                onAction: () async {
                                  Get.to(const DineInCreateScreen());
                                },
                              ),
                            ),
                          ),
                        )
                      : TabBarView(
                          children: [
                            controller.featureList.isEmpty
                                ? DsEmptyState(icon: Icons.event_available_outlined, title: "Upcoming Booking not found.".tr)
                                : RefreshIndicator(
                                    color: c.brand,
                                    backgroundColor: c.surface,
                                    onRefresh: () => controller.getDineBooking(),
                                    child: DsResponsive(
                                      child: ListView.builder(
                                        padding: EdgeInsets.fromLTRB(context.dsLayout.gutter, DsSpace.sm, context.dsLayout.gutter, DsSpace.xxl),
                                        scrollDirection: Axis.vertical,
                                        itemCount: controller.featureList.length,
                                        itemBuilder: (BuildContext context, int index) {
                                          DineInBookingModel dineBookingModel = controller.featureList[index];
                                          return DsFadeSlideIn(index: index, child: itemView(context, dineBookingModel, true, controller));
                                        },
                                      ),
                                    ),
                                  ),
                            controller.historyList.isEmpty
                                ? DsEmptyState(icon: Icons.history_rounded, tone: DsTone.neutral, title: "History not found.".tr)
                                : RefreshIndicator(
                                    color: c.brand,
                                    backgroundColor: c.surface,
                                    onRefresh: () => controller.getDineBooking(),
                                    child: DsResponsive(
                                      child: ListView.builder(
                                        itemCount: controller.historyList.length,
                                        padding: EdgeInsets.fromLTRB(context.dsLayout.gutter, DsSpace.sm, context.dsLayout.gutter, DsSpace.xxl),
                                        itemBuilder: (context, index) {
                                          DineInBookingModel dineBookingModel = controller.historyList[index];
                                          return DsFadeSlideIn(index: index, child: itemView(context, dineBookingModel, false, controller));
                                        },
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                ),
              );
      },
    );
  }

  /// Reservation card: date block, guest, details grid and accept / reject.
  Widget itemView(BuildContext context, DineInBookingModel orderModel, bool isNew, DineInOrderController controller) {
    final c = context.dsColors;
    final t = context.dsText;
    final bookingDate = orderModel.date?.toDate();
    final status = orderModel.status.toString();
    final tone = DsTone.fromStatus(status);
    final showActions = !(isNew == false || (orderModel.status == Constant.orderAccepted || orderModel.status == Constant.orderRejected));
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.md),
      child: DsCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top band tinted by status
            Container(
              height: 4,
              decoration: BoxDecoration(gradient: DsGradients.tone(context, tone == DsTone.neutral ? DsTone.brand : tone)),
            ),
            Padding(
              padding: const EdgeInsets.all(DsSpace.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date block
                  Container(
                    width: 64,
                    padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
                    decoration: BoxDecoration(color: c.brandSoft, borderRadius: DsRadius.brMd),
                    child: Column(
                      children: [
                        Text(bookingDate == null ? '--' : DateFormat('MMM').format(bookingDate).toUpperCase(), style: t.overline.withColor(c.brandStrong)),
                        Text(bookingDate == null ? '--' : DateFormat('dd').format(bookingDate), style: t.headline.withColor(c.brandStrong).tabular),
                        Text(bookingDate == null ? '' : DateFormat('hh:mm a').format(bookingDate), style: t.caption.withColor(c.brandStrong), maxLines: 1),
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "${orderModel.guestFirstName} ${orderModel.guestLastName}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.titleSm,
                              ),
                            ),
                            const DsGap(DsSpace.sm),
                            // Never wraps, and stays on the name's first line.
                            Flexible(child: DsStatusChip(label: status, status: status, pulse: isNew && showActions)),
                          ],
                        ),
                        const DsGap(DsSpace.xs),
                        Row(
                          children: [
                            DsAvatar(imageUrl: orderModel.vendor!.photo.toString(), name: orderModel.vendor!.title.toString(), size: 20),
                            const DsGap(DsSpace.xs),
                            Expanded(child: Text(orderModel.vendor!.title.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm)),
                          ],
                        ),
                        const DsGap(DsSpace.xs),
                        Text(Constant.timestampToDateTime(orderModel.createdAt!), style: t.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
              child: Container(
                padding: const EdgeInsets.all(DsSpace.md),
                decoration: BoxDecoration(color: c.surfaceAlt.withValues(alpha: c.isDark ? 0.5 : 0.7), borderRadius: DsRadius.brMd),
                child: DsAdaptiveGrid(
                  minItemWidth: 140,
                  maxColumns: 2,
                  equalHeight: false,
                  runSpacing: DsSpace.md,
                  children: [
                    _Info(icon: Icons.person_outline_rounded, label: "Name".tr, value: "${orderModel.guestFirstName} ${orderModel.guestLastName}"),
                    _Info(icon: Icons.phone_outlined, label: "Phone number".tr, value: "${orderModel.guestPhone}"),
                    _Info(icon: Icons.groups_2_outlined, label: "Guest".tr, value: orderModel.totalGuest!),
                    _Info(
                      icon: Icons.sell_outlined,
                      label: "Discount".tr,
                      value:
                          "${orderModel.discountType == "amount" ? (Constant.currencyModel!.symbolAtRight == true ? "${orderModel.discount}${Constant.currencyModel!.symbol}" : "${Constant.currencyModel!.symbol}${orderModel.discount}") : "${orderModel.discount}%"} ${'Off'.tr}",
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.xs, DsSpace.lg, DsSpace.md),
              child: OrderMoneyRow(
                icon: Icons.event_rounded,
                label: "Date and Time".tr,
                value: Constant.timestampToDateTime(orderModel.date!),
              ),
            ),
            if (showActions)
              Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.lg, DsSpace.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: DsButton.dangerTonal(
                        label: "Reject".tr,
                        icon: Icons.close_rounded,
                        expand: true,
                        onPressed: () async {
                          ShowToastDialog.showLoader("Please wait.".tr);
                          orderModel.status = Constant.orderRejected;
                          await FireStoreUtils.setBookedOrder(orderModel);
                          SendNotification.sendFcmMessage(Constant.dineInCanceled, orderModel.author!.fcmToken.toString(), {});
                          controller.getDineBooking();
                          ShowToastDialog.closeLoader();
                        },
                      ),
                    ),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: DsButton.primary(
                        label: "Accept".tr,
                        icon: Icons.check_rounded,
                        expand: true,
                        color: c.success,
                        onPressed: () async {
                          ShowToastDialog.showLoader("Please wait.".tr);
                          orderModel.status = Constant.orderAccepted;
                          await FireStoreUtils.setBookedOrder(orderModel);
                          SendNotification.sendFcmMessage(Constant.dineInAccepted, orderModel.author!.fcmToken.toString(), {});
                          controller.getDineBooking();
                          ShowToastDialog.closeLoader();
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Info({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: c.textMuted),
        const DsGap(DsSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t.caption),
              const DsGap(2),
              Text(value, style: t.label),
            ],
          ),
        ),
      ],
    );
  }
}

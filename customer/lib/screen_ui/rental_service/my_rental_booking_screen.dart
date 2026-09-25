import 'package:customer/utils/region_service.dart';
import 'package:customer/models/rental_order_model.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/screen_ui/rental_service/rental_order_details_screen.dart';
import 'package:customer/screen_ui/rental_service/widget/rental_proposal_widgets.dart';
import 'package:customer/screen_ui/widgets/order_ui.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/my_rental_booking_controller.dart';

/// Rental history (archetype F — booking history): pill tabs over vehicle
/// cards. Each row leads with the pickup point and status, then the vehicle and
/// the package, and carries its own Pay / Cancel actions.
class MyRentalBookingScreen extends StatelessWidget {
  const MyRentalBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.dsLayout;
    return GetX<MyRentalBookingController>(
      init: MyRentalBookingController(),
      builder: (controller) {
        final bool loading = controller.isLoading.value;
        final List<String> tabs = controller.tabTitles.toList();
        return DefaultTabController(
          length: controller.tabTitles.length,
          initialIndex: controller.tabTitles.indexOf(controller.selectedTab.value),
          child: DsScaffold(
            appBar: DsAppBar(
              title: "Rental History".tr,
              showBack: false,
              bottom: DsTabBar(
                tabs: tabs,
                onTap: (index) {
                  controller.selectTab(controller.tabTitles[index]);
                },
              ),
            ),
            body: loading
                ? const DsSkeletonList(itemCount: 3)
                : Constant.userModel == null
                ? const _LoginPrompt()
                : TabBarView(
                    children: tabs.map((title) {
                      List<RentalOrderModel> orders = controller.getOrdersForTab(title);

                      if (orders.isEmpty) {
                        return DsEmptyState(
                          icon: Icons.directions_car_outlined,
                          title: "No orders found".tr,
                          message: "Your rental bookings will show up here.".tr,
                        );
                      }
                      return ListView.builder(
                        padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          RentalOrderModel order = orders[index]; //use this
                          return DsFadeSlideIn(
                            index: index,
                            child: _RentalBookingCard(
                              order: order,
                              onCancel: () => controller.cancelRentalRequest(order, taxList: order.taxSetting),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
          ),
        );
      },
    );
  }
}

/// Logged-out state for the history tab.
class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt();

  @override
  Widget build(BuildContext context) {
    return DsEmptyState(
      icon: Icons.lock_outline_rounded,
      title: "Please Log In to Continue".tr,
      message: "You’re not logged in. Please sign in to access your account and explore all features.".tr,
      actionLabel: "Log in".tr,
      actionIcon: Icons.login_rounded,
      onAction: () async {
        Get.offAll(const LoginScreen());
      },
    );
  }
}

/// One rental booking row.
class _RentalBookingCard extends StatelessWidget {
  final RentalOrderModel order;
  final VoidCallback onCancel;

  const _RentalBookingCard({required this.order, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool canPay = order.status == Constant.orderInTransit && order.paymentStatus == false;
    final bool canCancel = order.status == Constant.orderPlaced || order.status == Constant.driverAccepted;
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.lg),
      semanticLabel: order.sourceLocationName ?? "-",
      onTap: () {
        Get.to(() => RentalOrderDetailsScreen(), arguments: order);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.trip_origin_rounded, size: 16, color: c.brandStrong),
              ),
              const DsGap(DsSpace.sm),
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
                    if (order.bookingDateTime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: DsSpace.xxs),
                        child: Row(
                          children: [
                            Icon(Icons.event_rounded, size: 13, color: c.textMuted),
                            const DsGap(DsSpace.xs),
                            Expanded(child: Text(Constant.timestampToDateTime(order.bookingDateTime!), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption)),
                            const DsGap(DsSpace.sm),
                            OrderIdLine(id: order.id.toString(), compact: true, copyable: false),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const DsGap(DsSpace.md),
          RentalProposalStatusLine(order: order),
          const DsDivider(spacing: DsSpace.md),
          Row(
            children: [
              DsImage(url: order.rentalVehicleType!.rentalVehicleIcon.toString(), height: 56, width: 56, radius: DsRadius.sm, errorIcon: Icons.directions_car_outlined),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Vehicle Type :".tr, style: t.overline),
                    Text("${order.rentalVehicleType!.name}", style: t.titleSm),
                    Text("${order.rentalVehicleType!.shortDescription}", style: t.bodySm, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const DsGap(DsSpace.md),
          Text("Package info :".tr, style: t.overline),
          const DsGap(DsSpace.xs),
          OrderItemRow(
            compact: true,
            name: order.rentalPackageModel!.name.toString(),
            price: Constant.amountShow(
              amount: order.rentalPackageModel!.baseFare.toString(),
              currency: RegionService.currencyForRecord(RegionService.regionOf(regionId: order.regionId, zoneId: order.zoneId)),
            ),
            footer: Padding(
              padding: const EdgeInsets.only(top: DsSpace.xxs),
              child: Text(order.rentalPackageModel!.description.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySm),
            ),
          ),
          if (Constant.isEnableOTPTripStartForRental == true) ...[
            const DsGap(DsSpace.md),
            DsCard.tinted(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
              child: Row(
                children: [
                  Icon(Icons.pin_rounded, size: 16, color: c.brandStrong),
                  const DsGap(DsSpace.sm),
                  Expanded(child: Text("${'OTP :'.tr} ${order.otpCode}", style: t.titleSm.tabular)),
                ],
              ),
            ),
          ],
          if (canPay || canCancel) ...[
            const DsGap(DsSpace.lg),
            Row(
              children: [
                if (canPay)
                  Expanded(
                    child: DsButton.primary(
                      label: "Pay Now".tr,
                      icon: Icons.payments_outlined,
                      expand: true,
                      onPressed: () {
                        Get.to(() => RentalOrderDetailsScreen(), arguments: order);
                      },
                    ),
                  ),
                if (canPay && canCancel) const DsGap(DsSpace.md),
                if (canCancel)
                  Expanded(
                    child: DsButton.dangerTonal(
                      label: "Cancel Booking",
                      icon: Icons.cancel_outlined,
                      expand: true,
                      onPressed: onCancel,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

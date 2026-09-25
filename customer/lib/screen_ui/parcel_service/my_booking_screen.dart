import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/screen_ui/parcel_service/parcel_order_details.dart';
import 'package:customer/screen_ui/widgets/order_ui.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/parcel_my_booking_controller.dart';
import '../../models/parcel_order_model.dart';

/// Parcel history (archetype F — booking history): pill tabs over a list of
/// route cards. Every row reads as a shipment: a vertical sender → receiver
/// rail, a status chip and the booking date.
class MyBookingScreen extends StatelessWidget {
  const MyBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<ParcelMyBookingController>(
      init: ParcelMyBookingController(),
      builder: (controller) {
        final bool loading = controller.isLoading.value;
        final List<String> tabs = controller.tabTitles.toList();
        return DefaultTabController(
          length: controller.tabTitles.length,
          initialIndex: controller.tabTitles.indexOf(controller.selectedTab.value),
          child: DsScaffold(
            appBar: DsAppBar(
              title: "Parcel History".tr,
              showBack: false,
              bottom: DsTabBar(
                tabs: tabs,
                // don't re-subscribe onTap — just update selectedTab (optional)
                onTap: (index) {
                  controller.selectTab(controller.tabTitles[index]);
                },
              ),
            ),
            body: loading
                ? const DsSkeletonList(itemCount: 4)
                : Constant.userModel == null
                ? const _LoginPrompt()
                : TabBarView(
                    children: tabs.map((title) {
                      final orders = controller.getOrdersForTab(title);

                      if (orders.isEmpty) {
                        return DsEmptyState(
                          icon: Icons.local_shipping_outlined,
                          title: "No orders found".tr,
                          message: "Your parcel bookings will show up here.".tr,
                        );
                      }

                      final List<String> dates = [
                        for (final order in orders)
                          "${'Order Date:'.tr}${order.isSchedule == true ? controller.formatDate(order.createdAt!) : controller.formatDate(order.senderPickupDateTime!)}",
                      ];

                      return ListView.builder(
                        padding: EdgeInsets.fromLTRB(context.dsLayout.gutter, DsSpace.lg, context.dsLayout.gutter, DsSpace.xxxl),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          return DsFadeSlideIn(
                            index: index,
                            child: _BookingCard(order: orders[index], dateLabel: dates[index]),
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

/// One shipment: pickup → delivery rail, contacts and the live status chip.
class _BookingCard extends StatelessWidget {
  final ParcelOrderModel order;
  final String dateLabel;

  const _BookingCard({required this.order, required this.dateLabel});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.lg),
      semanticLabel: order.sender?.address ?? '',
      onTap: () {
        Get.to(() => const ParcelOrderDetails(), arguments: order);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(Icons.event_outlined, size: 14, color: c.textMuted),
              ),
              const DsGap(DsSpace.xs),
              Expanded(child: Text(dateLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.caption)),
              if (order.status != null) ...[
                const DsGap(DsSpace.sm),
                DsStatusChip(label: order.status!.tr, status: order.status),
              ],
            ],
          ),
          OrderIdLine(id: order.id.toString(), compact: true, copyable: false),
          const DsGap(DsSpace.sm),
          _RouteBlock(order: order),
        ],
      ),
    );
  }
}

/// The sender → receiver rail shared by the list row.
class _RouteBlock extends StatelessWidget {
  final ParcelOrderModel order;

  const _RouteBlock({required this.order});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _RouteRail(),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              ParcelPartyBlock(
                title: "Pickup Address (Sender):".tr,
                name: order.sender?.name ?? '',
                address: order.sender?.address ?? '',
                phone: order.sender?.phone ?? '',
              ),
              const DsGap(DsSpace.lg),
              ParcelPartyBlock(
                title: "Delivery Address (Receiver):".tr,
                name: order.receiver?.name ?? '',
                address: order.receiver?.address ?? '',
                phone: order.receiver?.phone ?? '',
              ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Two dots joined by a dashed line, drawn with DS colors.
class _RouteRail extends StatelessWidget {
  const _RouteRail();

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return SizedBox(
      width: 22,
      child: Column(
        children: [
          Icon(Icons.trip_origin_rounded, size: 16, color: c.brandStrong),
          Expanded(child: CustomPaint(size: const Size(2, 68), painter: _DashedLinePainter(color: c.border))),
          Icon(Icons.place_rounded, size: 18, color: c.brandStrong),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const double dash = 4;
    const double gap = 4;
    double y = 2;
    while (y < size.height - 2) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, (y + dash).clamp(0, size.height)), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => oldDelegate.color != color;
}

/// Name / address / phone block for a sender or receiver.
class ParcelPartyBlock extends StatelessWidget {
  final String title;
  final String name;
  final String address;
  final String phone;

  const ParcelPartyBlock({super.key, required this.title, required this.name, required this.address, required this.phone});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.overline),
        const DsGap(DsSpace.xxs),
        if (name.isNotEmpty) Text(name, style: t.titleSm),
        if (address.isNotEmpty) Text(address, style: t.bodySecondary),
        if (phone.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.xxs),
            child: Row(
              children: [
                Icon(Icons.call_outlined, size: 13, color: c.textMuted),
                const DsGap(DsSpace.xs),
                Text(phone, style: t.bodySm.tabular),
              ],
            ),
          ),
      ],
    );
  }
}

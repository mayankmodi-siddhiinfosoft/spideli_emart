import 'package:customer/utils/region_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../constant/constant.dart';
import '../../controllers/my_booking_on_demand_controller.dart';
import '../../models/onprovider_order_model.dart';
import '../../models/worker_model.dart';
import '../widgets/order_ui.dart';
import 'on_demand_order_details_screen.dart';

/// Archetype F – booking history. Pill tabs over status-led booking cards
/// with a schedule/worker recap block.
class MyBookingOnDemandScreen extends StatelessWidget {
  const MyBookingOnDemandScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<MyBookingOnDemandController>(
      init: MyBookingOnDemandController(),
      builder: (controller) {
        final bool isLoading = controller.isLoading.value;
        final List<String> tabs = controller.tabTitles.toList();

        return DefaultTabController(
          length: controller.tabTitles.length,
          initialIndex: controller.tabTitles.indexOf(controller.selectedTab.value),
          child: DsScaffold(
            appBar: DsAppBar(
              title: "Booking History".tr,
              showBack: false,
              bottom: DsTabBar(
                tabs: tabs,
                onTap: (index) {
                  controller.selectTab(controller.tabTitles[index]);
                },
              ),
            ),
            body:
                isLoading
                    ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonList(itemCount: 4, trailing: false))
                    : TabBarView(
                      children:
                          tabs.map((title) {
                            final orders = controller.getOrdersForTab(title);

                            if (orders.isEmpty) {
                              return DsEmptyState(icon: Icons.event_busy_outlined, title: "No bookings found".tr);
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxxl),
                              itemCount: orders.length,
                              itemBuilder: (context, index) {
                                OnProviderOrderModel onProviderOrder = orders[index];
                                WorkerModel? worker = controller.getWorker(onProviderOrder.workerId);

                                return DsFadeSlideIn(
                                  index: index,
                                  child: _BookingCard(order: onProviderOrder, worker: worker),
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

/// One booking: status, service, price, OTP and the schedule recap.
class _BookingCard extends StatelessWidget {
  final OnProviderOrderModel order;
  final WorkerModel? worker;

  const _BookingCard({required this.order, required this.worker});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool showOtp =
        order.status != Constant.orderCompleted && order.status != Constant.orderCancelled && order.otp != null && order.otp!.isNotEmpty;

    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.lg),
      padding: const EdgeInsets.all(DsSpace.md),
      semanticLabel: order.provider.title.toString(),
      onTap: () {
        Get.to(() => OnDemandOrderDetailsScreen(), arguments: order);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsImage(url: order.provider.photos.isNotEmpty ? order.provider.photos.first : Constant.placeHolderImage, height: 86, width: 86, radius: DsRadius.md),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service name and status share the first line; the price
                    // closes the row on the right, in tabular figures.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(order.provider.title.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSm)),
                        const DsGap(DsSpace.sm),
                        DsStatusChip(label: order.status, status: order.status),
                      ],
                    ),
                    const DsGap(DsSpace.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        OrderIdLine(id: order.id, compact: true, copyable: false),
                        const DsGap(DsSpace.sm),
                        Expanded(child: Align(alignment: AlignmentDirectional.centerEnd, child: buildPriceText(context, order))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showOtp) ...[
            const DsGap(DsSpace.md),
            DsCard.tinted(
              tone: DsTone.info,
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
              child: Row(
                children: [
                  Icon(Icons.pin_rounded, size: 18, color: c.tone(DsTone.info).strong),
                  const DsGap(DsSpace.sm),
                  Text("OTP :".tr, style: t.bodySm),
                  const DsGap(DsSpace.sm),
                  Text("${order.otp}", style: t.titleSm.withColor(c.tone(DsTone.info).strong).tabular),
                ],
              ),
            ),
          ],

          /// Bottom Details (Date, Provider, Worker)
          buildBottomDetails(context, order, worker),
        ],
      ),
    );
  }

  Widget buildPriceText(BuildContext context, OnProviderOrderModel order) {
    final c = context.dsColors;
    final t = context.dsText;
    final hasDiscount = order.provider.disPrice != "" && order.provider.disPrice != "0";
    final price = hasDiscount ? order.provider.disPrice.toString() : order.provider.price.toString();

    return Text(
      order.provider.priceUnit == 'Fixed' ? Constant.amountShow(amount: price, currency: RegionService.currencyForRecord(order.regionId)) : "${Constant.amountShow(amount: price, currency: RegionService.currencyForRecord(order.regionId))}/${'hr'.tr}",
      style: t.titleSm.withColor(c.brandStrong).tabular,
    );
  }

  Widget buildBottomDetails(BuildContext context, OnProviderOrderModel order, WorkerModel? worker) {
    final c = context.dsColors;
    return Container(
      margin: const EdgeInsets.only(top: DsSpace.md),
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
      child: Column(
        children: [
          detailRow(context, "Date & Time", DateFormat('dd-MMM-yyyy hh:mm a').format(order.scheduleDateTime!.toDate())),
          const DsDivider(spacing: DsSpace.sm),
          detailRow(context, "Provider", order.provider.authorName.toString()),

          if (order.provider.priceUnit == "Hourly") ...[
            if (order.startTime != null) ...[const DsDivider(spacing: DsSpace.sm), detailRow(context, "Start Time", DateFormat('dd-MMM-yyyy hh:mm a').format(order.startTime!.toDate()))],
            if (order.endTime != null) ...[const DsDivider(spacing: DsSpace.sm), detailRow(context, "End Time", DateFormat('dd-MMM-yyyy hh:mm a').format(order.endTime!.toDate()))],
          ],

          if (worker != null) ...[const DsDivider(spacing: DsSpace.sm), detailRow(context, "Worker", worker.fullName().toString())],
        ],
      ),
    );
  }

  Widget detailRow(BuildContext context, String label, String value) {
    return OrderMoneyRow(label: label.tr, value: value.tr);
  }
}

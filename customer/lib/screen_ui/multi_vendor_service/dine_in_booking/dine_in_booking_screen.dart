import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/dine_in_booking_controller.dart';
import 'package:customer/models/dine_in_booking_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../widgets/order_ui.dart';
import 'dine_in_booking_details.dart';

/// Archetype F — reservation history. Upcoming / History pills over
/// reservation cards that lead with the table status and the party.
class DineInBookingScreen extends StatelessWidget {
  const DineInBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: DineInBookingController(),
      builder: (controller) {
        final bool isLoading = controller.isLoading.value;
        final bool isFeature = controller.isFeature.value;
        final List<DineInBookingModel> upcoming = controller.featureList.toList();
        final List<DineInBookingModel> history = controller.historyList.toList();
        final List<DineInBookingModel> shown = isFeature ? upcoming : history;

        return DsScaffold(
          maxContentWidth: DsLayout.contentMax,
          appBar: DsAppBar(title: "Dine in Bookings".tr),
          body: isLoading
              ? const SingleChildScrollView(child: DsSkeletonList(itemCount: 4))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, 0),
                      child: DsSegmentedTabs(
                        segments: [DsSegment("Upcoming".tr, count: upcoming.length), DsSegment("History".tr, count: history.length)],
                        index: isFeature ? 0 : 1,
                        onChanged: (i) {
                          controller.isFeature.value = i == 0;
                        },
                      ),
                    ),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: shown.isEmpty
                          ? DsEmptyState(
                              icon: Icons.event_seat_outlined,
                              title: isFeature ? "Upcoming Booking not found.".tr : "History not found.".tr,
                            )
                          : ListView.builder(
                              itemCount: shown.length,
                              shrinkWrap: true,
                              padding: const EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.lg, DsSpace.xxxl),
                              itemBuilder: (BuildContext context, int index) {
                                DineInBookingModel dineBookingModel = shown[index];
                                return DsFadeSlideIn(index: index, child: _BookingCard(bookingModel: dineBookingModel));
                              },
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final DineInBookingModel bookingModel;

  const _BookingCard({required this.bookingModel});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final String status = bookingModel.status.toString();

    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: EdgeInsets.zero,
      onTap: () {
        Get.to(const DineInBookingDetails(), arguments: {"bookingModel": bookingModel});
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(DsSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DsImage(url: bookingModel.vendor!.photo.toString(), width: 64, height: 64, radius: DsRadius.md, errorIcon: Icons.storefront_outlined),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Venue and status share the first line; the chip never
                      // wraps away from the title it belongs to.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(bookingModel.vendor!.title.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSm)),
                          const DsGap(DsSpace.sm),
                          DsStatusChip(label: status, status: status),
                        ],
                      ),
                      const DsGap(DsSpace.xxs),
                      Row(
                        children: [
                          Expanded(child: Text(Constant.timestampToDateTime(bookingModel.createdAt!), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption)),
                          const DsGap(DsSpace.sm),
                          OrderIdLine(id: bookingModel.id.toString(), compact: true, copyable: false),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: c.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
            child: Column(
              children: [
                OrderMoneyRow(label: "Name".tr, value: "${bookingModel.guestFirstName} ${bookingModel.guestLastName}"),
                OrderMoneyRow(label: "Guest Number".tr, value: bookingModel.totalGuest.toString()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DsSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SvgPicture.asset("assets/icons/ic_location.svg", width: 18, height: 18),
                const DsGap(DsSpace.sm),
                Expanded(child: Text(bookingModel.vendor!.location.toString(), style: t.bodySm.withColor(c.textPrimary))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

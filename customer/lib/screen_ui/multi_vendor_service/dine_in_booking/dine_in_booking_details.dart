import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/dine_in_booking_details_controller.dart';
import 'package:customer/models/dine_in_booking_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/order_ui.dart';

/// Archetype F (detail) — reservation ticket: status hero, the restaurant with
/// map / call actions, then the booking facts.
class DineInBookingDetails extends StatelessWidget {
  const DineInBookingDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: DineInBookingDetailsController(),
      builder: (controller) {
        final t = context.dsText;
        final bool isLoading = controller.isLoading.value;
        final DineInBookingModel booking = controller.bookingModel.value;
        final String status = "${booking.status}";

        return DsScaffold(
          maxContentWidth: DsLayout.contentMax,
          appBar: DsAppBar(title: "Dine in Bookings".tr),
          body: isLoading
              ? const SingleChildScrollView(child: DsSkeletonDetail(mediaHeight: 110))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: DsFadeSlideIn.stagger([
                      // ---------- status hero ----------
                      DsCard.tinted(
                        tone: DsTone.fromStatus(booking.status),
                        child: OrderIdHeader(
                          title: 'Order'.tr,
                          id: booking.id.toString(),
                          subtitle: "${booking.totalGuest} ${'Peoples'.tr}",
                          statusLabel: status,
                          status: booking.status,
                        ),
                      ),

                      // ---------- venue ----------
                      const DsGap(DsSpace.lg),
                      DsCard(
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SvgPicture.asset("assets/icons/ic_building.svg", width: 22, height: 22),
                                const DsGap(DsSpace.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(booking.vendor!.title.toString(), style: t.title),
                                      const DsGap(DsSpace.xxs),
                                      Text(booking.vendor!.location.toString(), style: t.bodySecondary),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const DsDivider(spacing: DsSpace.lg),
                            Row(
                              children: [
                                Expanded(
                                  child: DsButton.tonal(
                                    label: "View in Map".tr,
                                    icon: Icons.map_outlined,
                                    expand: true,
                                    onPressed: () {
                                      launchUrl(
                                        Constant.createCoordinatesUrl(
                                          booking.vendor!.latitude ?? 0.0,
                                          booking.vendor!.longitude ?? 0.0,
                                          booking.vendor!.title,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const DsGap(DsSpace.md),
                                Expanded(
                                  child: DsButton.tonal(
                                    label: "Call Now".tr,
                                    icon: Icons.call_outlined,
                                    expand: true,
                                    onPressed: () {
                                      if (booking.vendor!.phonenumber!.isNotEmpty) {
                                        final Uri launchUri = Uri(scheme: 'tel', path: booking.vendor!.phonenumber);
                                        launchUrl(launchUri);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ---------- booking facts ----------
                      const DsGap(DsSpace.lg),
                      DsSectionHeader(title: "Booking Details".tr, icon: Icons.event_note_outlined, padding: EdgeInsets.zero),
                      const DsGap(DsSpace.sm),
                      DsCard(
                        child: Column(
                          children: [
                            OrderMoneyRow(label: "Name".tr, value: "${booking.guestFirstName} ${booking.guestLastName}"),
                            OrderMoneyRow(label: "Phone number".tr, value: "${booking.guestPhone}"),
                            OrderMoneyRow(label: "Date and Time".tr, value: Constant.timestampToDateTime(booking.date!)),
                            OrderMoneyRow(label: "Guest".tr, value: "${booking.totalGuest}"),
                            OrderMoneyRow(label: "Discount".tr, value: "${booking.discount} %"),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
        );
      },
    );
  }

}

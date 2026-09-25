import 'package:spideliprovider/services/provider_verification_gate.dart';
import 'package:bottom_picker/bottom_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/booking_details_controller.dart';
import 'package:spideliprovider/main.dart';

import 'package:spideliprovider/model/onprovider_order_model.dart';
import 'package:spideliprovider/model/tax_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/region_service.dart';
import 'package:spideliprovider/services/send_notification.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/booking_list/assign_worker_list.dart';
import 'package:spideliprovider/ui/booking_list/verify_otp_screen.dart';
import 'package:spideliprovider/ui/chat_screen/chat_screen.dart';
import 'package:spideliprovider/utils/booking_receipt_pdf.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/widgets/common_ui.dart';
import 'package:spideliprovider/widgets/order_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:provider/provider.dart';

class BookingDetailsScreen extends StatelessWidget {
  const BookingDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetBuilder<BookingDetailsController>(
        init: BookingDetailsController(),
        builder: (controller) {
          return DsScaffold(
              title: 'Booking Summary'.tr,
              maxContentWidth: DsLayout.contentMax,
              body: controller.orderId.value.isNotEmpty
                  ? StreamBuilder(
                      stream: FireStoreUtils.firestore.collection(PROVIDER_ORDER).doc(controller.orderId.value).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return DsErrorState(message: 'Something went wrong'.tr);
                        }

                        // NOTE: deliberately a ternary, not DsAsync. DsAsync observes
                        // its builder, and priceTotalRow WRITES controller observables
                        // during build — observing them here would loop forever.
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const DsSkeletonDetail();
                        }

                        OnProviderOrderModel onProviderOrder = OnProviderOrderModel.fromJson(snapshot.data!.data()!);
                        double total = 0.0;
                        if (onProviderOrder.provider.disPrice == "" || onProviderOrder.provider.disPrice == "0") {
                          total += onProviderOrder.quantity * double.parse(onProviderOrder.provider.price.toString());
                        } else {
                          total += onProviderOrder.quantity * double.parse(onProviderOrder.provider.disPrice.toString());
                        }

                        if (onProviderOrder.taxModel != null) {
                          for (var element in onProviderOrder.taxModel!) {
                            total = total + getTaxValue(amount: (total).toString(), taxModel: element);
                          }
                        }

                        final Widget? actions = _actionsFor(
                          context: context,
                          controller: controller,
                          onProviderOrder: onProviderOrder,
                          total: total,
                          themeChange: themeChange,
                        );

                        return Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.fromLTRB(
                                  context.dsLayout.gutter,
                                  DsSpace.lg,
                                  context.dsLayout.gutter,
                                  DsSpace.xxxl,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: DsFadeSlideIn.stagger([
                                    _headerCard(context, onProviderOrder),
                                    DsGap.lg,
                                    _timelineCard(context, onProviderOrder),
                                    DsGap.lg,
                                    _workerSection(context, controller, onProviderOrder),
                                    _customerSection(context, onProviderOrder, themeChange),
                                    DsGap.lg,
                                    DsSectionHeader(title: "Price Detail".tr, icon: Icons.receipt_long_outlined),
                                    priceTotalRow(controller, onProviderOrder, context),
                                    _extraChargesCard(context, onProviderOrder),
                                    _cancelReasonCard(context, onProviderOrder),
                                    _adminCommissionCard(context, controller, onProviderOrder),
                                    receiptAndAssignmentSection(context, onProviderOrder, themeChange),
                                    _reviewsSection(context, controller),
                                  ]),
                                ),
                              ),
                            ),
                            if (actions != null) DsStickyBar(child: actions),
                          ],
                        );
                      })
                  : Container());
        });
  }

  // ---------------------------------------------------------------------------
  // Header — service media, title, schedule, booking id
  // ---------------------------------------------------------------------------

  Widget _headerCard(BuildContext context, OnProviderOrderModel onProviderOrder) {
    final c = context.dsColors;
    final t = context.dsText;

    final DateTime scheduled =
        onProviderOrder.newScheduleDateTime == null ? onProviderOrder.scheduleDateTime!.toDate() : onProviderOrder.newScheduleDateTime!.toDate();

    return DsCard(
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsImage(
                url: onProviderOrder.provider.photos.isNotEmpty ? onProviderOrder.provider.photos.first.toString() : placeholderImage,
                width: 88,
                height: 88,
                radius: DsRadius.md,
                heroTag: 'booking-${onProviderOrder.id}',
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DsStatusChip(
                      label: onProviderOrder.status.toString().tr,
                      status: onProviderOrder.status,
                      pulse: onProviderOrder.status == ORDER_STATUS_ONGOING,
                    ),
                    const DsGap(DsSpace.sm),
                    Text(
                      onProviderOrder.provider.title.toString(),
                      style: t.title,
                    ),
                    const DsGap(DsSpace.sm),
                    Row(
                      children: [
                        Icon(Icons.event_outlined, size: 15, color: c.iconDefault),
                        const DsGap(DsSpace.xs),
                        Text('Date: '.tr, style: t.caption),
                        Flexible(
                          child: Text(
                            DateFormat('dd-MMM-yyyy').format(scheduled),
                            style: t.bodyStrong,
                          ),
                        ),
                      ],
                    ),
                    const DsGap(DsSpace.xs),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 15, color: c.iconDefault),
                        const DsGap(DsSpace.xs),
                        Text('Time: '.tr, style: t.caption),
                        Flexible(
                          child: Text(
                            DateFormat('hh:mm a').format(scheduled),
                            style: t.bodyStrong,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const DsDivider(spacing: DsSpace.md),
          // One heading, one value: the short id stays on a single line and the
          // full id is copied on tap.
          OrderIdHeader(
            label: 'Booking ID'.tr,
            shortId: shortBookingId("${onProviderOrder.id}"),
            fullId: "${onProviderOrder.id}",
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Timeline — built only from fields the booking already carries
  // ---------------------------------------------------------------------------

  Widget _timelineCard(BuildContext context, OnProviderOrderModel onProviderOrder) {
    final DateFormat fmt = DateFormat('dd MMM, hh:mm a');
    final String status = onProviderOrder.status;

    const List<String> flow = [
      ORDER_STATUS_PLACED,
      ORDER_STATUS_ACCEPTED,
      ORDER_STATUS_ASSIGNED,
      ORDER_STATUS_ONGOING,
      ORDER_STATUS_COMPLETED,
    ];
    final bool ended = status == ORDER_STATUS_REJECTED || status == ORDER_STATUS_CANCELLED;
    final int current = flow.indexOf(status);

    DsStepState stateFor(int i) {
      if (ended) return i == 0 ? DsStepState.done : DsStepState.upcoming;
      if (current < 0) return DsStepState.upcoming;
      if (i < current) return DsStepState.done;
      if (i == current) return i == flow.length - 1 ? DsStepState.done : DsStepState.current;
      return DsStepState.upcoming;
    }

    final List<DsTimelineStep> steps = [
      DsTimelineStep(
        title: 'Placed'.tr,
        meta: fmt.format(onProviderOrder.createdAt.toDate()),
        state: stateFor(0),
        icon: Icons.receipt_long_outlined,
      ),
      DsTimelineStep(
        title: 'Accepted'.tr,
        meta: onProviderOrder.newScheduleDateTime == null ? null : fmt.format(onProviderOrder.newScheduleDateTime!.toDate()),
        state: stateFor(1),
        icon: Icons.check_rounded,
      ),
      DsTimelineStep(
        title: 'Assigned'.tr,
        state: stateFor(2),
        icon: Icons.engineering_outlined,
      ),
      DsTimelineStep(
        title: 'On Going'.tr,
        meta: onProviderOrder.startTime == null ? null : fmt.format(onProviderOrder.startTime!.toDate()),
        state: stateFor(3),
        icon: Icons.play_arrow_rounded,
      ),
      DsTimelineStep(
        title: 'Completed'.tr,
        meta: onProviderOrder.endTime == null ? null : fmt.format(onProviderOrder.endTime!.toDate()),
        state: stateFor(4),
        icon: Icons.verified_rounded,
      ),
      if (ended)
        DsTimelineStep(
          title: status == ORDER_STATUS_REJECTED ? 'Rejected'.tr : 'Cancelled'.tr,
          state: DsStepState.error,
          icon: Icons.cancel_outlined,
        ),
    ];

    return DsCard(
      padding: const EdgeInsets.all(DsSpace.lg),
      child: DsTimeline(steps: steps),
    );
  }

  // ---------------------------------------------------------------------------
  // Worker
  // ---------------------------------------------------------------------------

  Widget _workerSection(BuildContext context, BookingDetailsController controller, OnProviderOrderModel onProviderOrder) {
    if (!((onProviderOrder.status == ORDER_STATUS_ACCEPTED ||
            onProviderOrder.status == ORDER_STATUS_ASSIGNED ||
            onProviderOrder.status == ORDER_STATUS_ONGOING ||
            onProviderOrder.status == ORDER_STATUS_COMPLETED) &&
        onProviderOrder.workerId != '')) {
      return const SizedBox();
    }

    final t = context.dsText;
    final c = context.dsColors;

    return FutureBuilder(
        future: FireStoreUtils.getWorker(onProviderOrder.workerId.toString()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: Container());
          } else {
            if (snapshot.hasError) {
              return Center(child: Text('Error: '.tr + '${snapshot.error}'));
            } else if (snapshot.hasData) {
              controller.worker.value = snapshot.data!;
              // The worker values below are observables, so this subtree observes them.
              return DsObserve(builder: (context) {
                final double rating = controller.worker.value.reviewsCount != 0
                    ? (controller.worker.value.reviewsSum / controller.worker.value.reviewsCount)
                    : 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DsSectionHeader(title: 'About Worker'.tr, icon: Icons.engineering_outlined),
                    DsCard(
                      padding: const EdgeInsets.all(DsSpace.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DsAvatar(
                            imageUrl: controller.worker.value.profilePictureURL != "" ? controller.worker.value.profilePictureURL.toString() : placeholderImage,
                            name: controller.worker.value.fullName().toString(),
                            size: 56,
                          ),
                          const DsGap(DsSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        controller.worker.value.fullName().toString(),
                                        style: t.titleSm,
                                      ),
                                    ),
                                    DsBadge(
                                      label: controller.worker.value.reviewsCount != 0 ? rating.toStringAsFixed(1) : 0.toString(),
                                      tone: DsTone.warning,
                                      icon: Icons.star_rounded,
                                      small: true,
                                    ),
                                  ],
                                ),
                                const DsGap(DsSpace.xs),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 14, color: c.iconDefault),
                                    const DsGap(DsSpace.xs),
                                    Expanded(
                                      child: Text(
                                        controller.worker.value.address!.toString(),
                                        maxLines: 5,
                                        style: t.bodySecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    DsGap.lg,
                  ],
                );
              });
            } else {
              return Container();
            }
          }
        });
  }

  // ---------------------------------------------------------------------------
  // Customer
  // ---------------------------------------------------------------------------

  Widget _customerSection(BuildContext context, OnProviderOrderModel onProviderOrder, DarkThemeProvider themeChange) {
    final t = context.dsText;
    final c = context.dsColors;

    final bool canContact =
        onProviderOrder.status == ORDER_STATUS_ACCEPTED || onProviderOrder.status == ORDER_STATUS_ONGOING || onProviderOrder.status == ORDER_STATUS_ASSIGNED;
    final bool canChat = (isSubscriptionModelApplied == false && selectedSectionModel?.adminCommision?.enable == false) ||
        ((isSubscriptionModelApplied == true || selectedSectionModel?.adminCommision?.enable == true) && MyAppState.currentUser?.subscriptionPlan?.features?.chat == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsSectionHeader(
          title: 'About Customer'.tr,
          icon: Icons.person_outline_rounded,
          actionLabel: onProviderOrder.status == ORDER_STATUS_ACCEPTED ? 'Get Direction'.tr : null,
          onAction: onProviderOrder.status == ORDER_STATUS_ACCEPTED
              ? () async {
                  final directions = MapLauncher.directions(
                    LocationCoords(onProviderOrder.address!.location!.latitude, onProviderOrder.address!.location!.longitude, title: onProviderOrder.address!.locality),
                    mode: TravelMode.driving,
                  );
                  // map_launcher 6: isMapAvailable() replaced by getSupportedMaps(); isInstalled keeps the old "app installed" check.
                  final maps = await directions.getSupportedMaps(const [MapApp.google]);
                  if (maps.any((m) => m.isInstalled)) {
                    await directions.show(map: MapApp.google);
                  } else {
                    ShowToastDialog.showToast("Google map is not installed".tr);
                  }
                }
              : null,
        ),
        DsCard(
          padding: const EdgeInsets.all(DsSpace.md),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DsAvatar(
                    imageUrl: onProviderOrder.author.profilePictureURL != "" ? onProviderOrder.author.profilePictureURL.toString() : placeholderImage,
                    name: onProviderOrder.author.fullName().toString(),
                    size: 56,
                  ),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          onProviderOrder.author.fullName().toString(),
                          style: t.titleSm,
                        ),
                        const DsGap(DsSpace.xs),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_outlined, size: 15, color: c.iconDefault),
                            const DsGap(DsSpace.xs),
                            Expanded(
                              child: Text(
                                onProviderOrder.address!.getFullAddress().toString(),
                                maxLines: 5,
                                style: t.bodySecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (canContact) ...[
                const DsGap(DsSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: DsButton.primary(
                        label: "Call",
                        icon: Icons.call,
                        expand: true,
                        onPressed: () async {
                          makePhoneCall(onProviderOrder.author.phoneNumber.toString());
                        },
                      ),
                    ),
                    if (canChat) const DsGap(DsSpace.md),
                    if (canChat)
                      Expanded(
                        child: DsButton.tonal(
                          label: "Chat".tr,
                          icon: Icons.chat,
                          expand: true,
                          onPressed: () async {
                            ShowToastDialog.showLoader("Please wait".tr);

                            User? customer = await FireStoreUtils.getCurrentUser(onProviderOrder.authorID);
                            User? provider = await FireStoreUtils.getCurrentUser(onProviderOrder.provider.author.toString());
                            ShowToastDialog.closeLoader();
                            Get.to(ChatScreen(), arguments: {
                              "senderName": provider?.fullName(),
                              "senderId": provider?.id,
                              "senderProfileUrl": provider?.profilePictureURL,
                              "receivedName": customer?.fullName(),
                              "receivedId": customer?.id,
                              "receivedProfileUrl": customer?.profilePictureURL,
                              "orderId": onProviderOrder.id,
                              "token": provider?.fcmToken,
                              "chatType": userRoleProvider,
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Extra charges / cancel reason / admin commission
  // ---------------------------------------------------------------------------

  Widget _extraChargesCard(BuildContext context, OnProviderOrderModel onProviderOrder) {
    if (onProviderOrder.extraCharges.toString() == "") return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.md),
      child: DsCard.tinted(
        tone: DsTone.info,
        padding: const EdgeInsets.all(DsSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OrderMoneyRow(
              label: "Total Extra Charges : ",
              value: amountShow(currency: RegionService.currencyForBooking(onProviderOrder.regionId), amount: onProviderOrder.extraCharges.toString()),
              padding: EdgeInsets.zero,
            ),
            OrderMoneyRow(
              label: "Extra charge Notes : ",
              value: onProviderOrder.extraChargesDescription.toString(),
              padding: const EdgeInsets.only(top: DsSpace.sm),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cancelReasonCard(BuildContext context, OnProviderOrderModel onProviderOrder) {
    if (onProviderOrder.reason!.isEmpty || onProviderOrder.reason == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.md),
      child: DsInlineAlert(
        tone: DsTone.danger,
        icon: Icons.cancel_outlined,
        title: "Cancelled reason".tr,
        message: "${onProviderOrder.reason.toString()}",
      ),
    );
  }

  Widget _adminCommissionCard(BuildContext context, BookingDetailsController controller, OnProviderOrderModel onProviderOrder) {
    if (!(onProviderOrder.adminCommission != '0' && onProviderOrder.adminCommissionType != 'fixed')) {
      return const SizedBox();
    }
    final t = context.dsText;
    final c = context.dsColors;

    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.md),
      child: DsCard.tinted(
        tone: DsTone.danger,
        padding: const EdgeInsets.all(DsSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OrderMoneyRow(
              label: "Admin commission".tr,
              value: "(-${amountShow(currency: RegionService.currencyForBooking(onProviderOrder.regionId), amount: controller.adminComm.value.toString())})",
              valueColor: c.dangerStrong,
              padding: EdgeInsets.zero,
            ),
            const DsGap(DsSpace.sm),
            Text(
              "Note : Admin commission will be debited from your wallet balance. \nAdmin commission will apply on order Amount minus Discount(if applicable).".tr,
              style: t.bodySm.withColor(c.dangerStrong),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Reviews
  // ---------------------------------------------------------------------------

  Widget _reviewsSection(BuildContext context, BookingDetailsController controller) {
    if (controller.ratingService.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsSectionHeader(title: "Reviews (${controller.ratingService.length})", icon: Icons.star_outline_rounded),
        reviewTabViewWidget(controller),
      ],
    );
  }

  reviewTabViewWidget(BookingDetailsController controller) {
    return controller.ratingService.isEmpty
        ? Center(
            child: Text("No review Found".tr),
          )
        : ListView.builder(
            itemCount: controller.ratingService.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final t = context.dsText;
              return DsCard.outlined(
                margin: const EdgeInsets.only(bottom: DsSpace.md),
                padding: const EdgeInsets.all(DsSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(controller.ratingService[index].uname.toString(), style: t.titleSm)),
                        Text(
                          DateFormat('dd MMM').format(controller.ratingService[index].createdAt!.toDate()),
                          style: t.caption,
                        ),
                      ],
                    ),
                    const DsGap(DsSpace.xs),
                    RatingBar.builder(
                      ignoreGestures: true,
                      initialRating: double.parse(controller.ratingService[index].rating.toString()),
                      direction: Axis.horizontal,
                      itemSize: 18,
                      itemPadding: const EdgeInsets.only(right: 4.0),
                      itemBuilder: (context, _) => Icon(
                        Icons.star,
                        color: AppColors.colorPrimary,
                      ),
                      onRatingUpdate: (double rate) {},
                    ),
                    const DsDivider(spacing: DsSpace.md),
                    Text(controller.ratingService[index].comment.toString(), style: t.body),
                  ],
                ),
              );
            },
          );
  }

  /// Receipt (spec 7.6 / 10), reassignment and the manual assignment log
  /// (spec 10) of this booking.
  Widget receiptAndAssignmentSection(BuildContext context, OnProviderOrderModel onProviderOrder, DarkThemeProvider themeChange) {
    final bool canReassign = onProviderOrder.status == ORDER_STATUS_ASSIGNED && (onProviderOrder.workerId ?? '').isNotEmpty;
    final DateFormat fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final List<AssignmentLogEntry> log = [...onProviderOrder.assignmentLog]..sort((a, b) => (a.at?.millisecondsSinceEpoch ?? 0).compareTo(b.at?.millisecondsSinceEpoch ?? 0));
    String nameOf(String? workerId) {
      if (workerId == null || workerId.isEmpty) return '';
      final match = log.where((e) => e.workerId == workerId && e.workerName.isNotEmpty);
      return match.isNotEmpty ? match.first.workerName : workerId;
    }

    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsSectionHeader(title: 'Receipt'.tr, icon: Icons.picture_as_pdf_outlined),
          DsCard(
            padding: const EdgeInsets.all(DsSpace.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DsButton.secondary(
                        label: 'Download'.tr,
                        icon: Icons.download_outlined,
                        expand: true,
                        onPressed: () => BookingReceiptPdf.download(onProviderOrder, provider: MyAppState.currentUser),
                      ),
                    ),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: DsButton.secondary(
                        label: 'Share'.tr,
                        icon: Icons.share_outlined,
                        expand: true,
                        onPressed: () => BookingReceiptPdf.share(onProviderOrder, provider: MyAppState.currentUser),
                      ),
                    ),
                  ],
                ),
                if (canReassign) ...[
                  const DsGap(DsSpace.md),
                  DsButton.tonal(
                    label: 'Reassign worker'.tr,
                    icon: Icons.swap_horiz,
                    expand: true,
                    onPressed: () => Get.to(const AssignWorkerList(), arguments: {"onProviderOrder": onProviderOrder}),
                  ),
                ],
              ],
            ),
          ),
          if (log.isNotEmpty) ...[
            DsGap.lg,
            DsSectionHeader(title: 'Assignment log'.tr, icon: Icons.history_rounded),
            DsCard(
              padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
              child: Column(
                children: log.map((e) {
                  final String by = e.assignedBy == MyAppState.currentUser?.id ? 'you'.tr : e.assignedBy;
                  final String from = nameOf(e.previousWorkerId);
                  return DsListTile(
                    leadingIcon: e.previousWorkerId == null ? Icons.person_add_alt : Icons.swap_horiz,
                    leadingTone: DsTone.brand,
                    title: from.isEmpty
                        ? '${'Assigned to'.tr} ${e.workerName.isEmpty ? e.workerId : e.workerName}'
                        : '${'Reassigned from'.tr} $from ${'to'.tr} ${e.workerName.isEmpty ? e.workerId : e.workerName}',
                    subtitle: '${e.at != null ? fmt.format(e.at!.toDate()) : ''}  ${'by'.tr} $by',
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Price breakdown — NOTE: writes controller observables during build, so this
  // subtree must never be wrapped in Obx/DsObserve/DsAsync (it would loop).
  // ---------------------------------------------------------------------------

  Widget priceTotalRow(BookingDetailsController controller, OnProviderOrderModel onProviderOrder, context) {
    controller.price.value = 0.0;
    controller.discount.value = 0.0;
    controller.totalAmount.value = 0.0;
    controller.adminComm.value = 0.0;

    double safeDouble(value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      final parsed = double.tryParse(value.toString());
      return parsed ?? defaultValue;
    }

    if (onProviderOrder.provider.disPrice == "" || onProviderOrder.provider.disPrice == "0") {
      controller.price.value = safeDouble(onProviderOrder.provider.price) * onProviderOrder.quantity;
    } else {
      controller.price.value = safeDouble(onProviderOrder.provider.disPrice) * onProviderOrder.quantity;
    }

    if (onProviderOrder.discountType == 'Percentage' || onProviderOrder.discountType == 'Percent') {
      controller.discount.value = controller.price.value * safeDouble(onProviderOrder.discountLabel) / 100;
    } else {
      controller.discount.value = safeDouble(onProviderOrder.discountLabel);
    }

    controller.subTotal.value = controller.price.value - controller.discount.value;
    controller.totalAmount.value = controller.subTotal.value;

    controller.adminComm.value =
        (onProviderOrder.adminCommissionType == 'Percent') ? (controller.totalAmount.value * safeDouble(onProviderOrder.adminCommission)) / 100 : safeDouble(onProviderOrder.adminCommission);

    if (onProviderOrder.taxModel != null) {
      for (var element in onProviderOrder.taxModel!) {
        controller.totalAmount.value = controller.totalAmount.value + getTaxValue(amount: (controller.subTotal.value).toString(), taxModel: element);
      }
    }

    Provider.of<DarkThemeProvider>(context);
    final BuildContext ctx = context;
    final t = ctx.dsText;

    // One row per line, one padding for the whole block: labels left, amounts
    // right in a single tabular column.
    const EdgeInsets rowPadding = EdgeInsets.symmetric(vertical: DsSpace.md, horizontal: DsSpace.md);

    return DsCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: rowPadding,
            child: OrderItemRow(
              name: "Price".tr,
              meta: (onProviderOrder.provider.disPrice == "" || onProviderOrder.provider.disPrice == "0")
                  ? '${amountShow(currency: RegionService.currencyForBooking(onProviderOrder.regionId), amount: onProviderOrder.provider.price.toString())} × ${onProviderOrder.quantity.toStringAsFixed(2)}'
                  : '${amountShow(currency: RegionService.currencyForBooking(onProviderOrder.regionId), amount: onProviderOrder.provider.disPrice.toString())} × ${onProviderOrder.quantity.toStringAsFixed(2)}',
              price: amountShow(currency: RegionService.currencyForBooking(onProviderOrder.regionId), amount: controller.price.toString()),
            ),
          ),
          if (controller.discount.value != 0) const DsDivider(spacing: 0, indent: DsSpace.md),
          if (controller.discount.value != 0)
            OrderMoneyRow(
              label: "Discount".tr,
              value: '(- ${amountShow(currency: RegionService.currencyForBooking(onProviderOrder.regionId), amount: controller.discount.value.toString())})',
              valueColor: ctx.dsColors.successStrong,
              padding: rowPadding,
            ),
          const DsDivider(spacing: 0, indent: DsSpace.md),
          OrderMoneyRow(
            label: "SubTotal".tr,
            value: amountShow(currency: RegionService.currencyForBooking(onProviderOrder.regionId), amount: controller.subTotal.toString()),
            padding: rowPadding,
          ),
          const DsDivider(spacing: 0, indent: DsSpace.md),
          ListView.builder(
            itemCount: onProviderOrder.taxModel!.length,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              TaxModel taxModel = onProviderOrder.taxModel![index];
              return Column(
                children: [
                  OrderMoneyRow(
                    label:
                        "${taxModel.title.toString()} (${taxModel.type == "fix" ? amountShow(currency: RegionService.currencyForBooking(onProviderOrder.regionId), amount: taxModel.tax) : "${taxModel.tax}%"})",
                    value: amountShow(
                        currency: RegionService.currencyForBooking(onProviderOrder.regionId),
                        amount: getTaxValue(amount: (double.parse(controller.subTotal.toString())).toString(), taxModel: taxModel).toString()),
                    padding: rowPadding,
                  ),
                  const DsDivider(spacing: 0, indent: DsSpace.md),
                ],
              );
            },
          ),
          if (onProviderOrder.notes!.isNotEmpty)
            OrderMoneyRow(
              label: "Remarks".tr,
              padding: rowPadding,
              valueWidget: InkWell(
                borderRadius: DsRadius.brSm,
                onTap: () {
                  viewNotesheet(onProviderOrder.notes ?? "", Provider.of<DarkThemeProvider>(ctx, listen: false), ctx);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.xs, horizontal: DsSpace.xs),
                  child: Text(
                    "View".tr,
                    style: t.link,
                  ),
                ),
              ),
            ),
          OrderTotalRow(
            label: "Total Amount".tr,
            value: amountShow(currency: RegionService.currencyForBooking(onProviderOrder.regionId), amount: controller.totalAmount.toString()),
            divider: false,
            background: ctx.dsColors.surfaceAlt,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(DsRadius.lg)),
            padding: rowPadding,
          ),
        ],
      ),
    );
  }

  void viewNotesheet(String notes, themeChange, context) {
    final BuildContext ctx = context;
    Get.bottomSheet(
      DsSheet(
        title: 'Remark'.tr,
        child: Text(
          notes,
          textAlign: TextAlign.center,
          style: ctx.dsText.body,
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  // ---------------------------------------------------------------------------
  // Actions — every condition and handler is the original one, verbatim.
  // ---------------------------------------------------------------------------

  Widget? _actionsFor({
    required BuildContext context,
    required BookingDetailsController controller,
    required OnProviderOrderModel onProviderOrder,
    required double total,
    required DarkThemeProvider themeChange,
  }) {
    if (onProviderOrder.status == ORDER_STATUS_CANCELLED) return null;

    if (onProviderOrder.status == ORDER_STATUS_PLACED) {
      return Row(
        children: [
          Expanded(
            child: DsButton.primary(
              label: 'Accept'.tr,
              expand: true,
              onPressed: () async {
                //:::::::::11::::::::::::
                bool isSubscriptionActive = isSubscriptionModelApplied == true || selectedSectionModel?.adminCommision?.enable == true;

                bool isAcceptBooking = false;
                if (MyAppState.currentUser?.subscriptionTotalOrders == '-1') {
                  isAcceptBooking = true;
                } else if (int.parse(MyAppState.currentUser?.subscriptionTotalOrders ?? '0') > 0) {
                  isAcceptBooking = true;
                } else {
                  isAcceptBooking = false;
                }

                if (isSubscriptionActive && isAcceptBooking == false) {
                  ShowToastDialog.showToast(
                      "You have reached the maximum booking capacity for your current plan. Upgrade your subscription to continue accepting booking seamlessly!"
                          .tr);
                  return;
                }
                controller.dateTimeController.value = TextEditingController();
                controller.selectedDateTime.value = onProviderOrder.scheduleDateTime!.toDate();
                controller.dateTimeController.value.text = DateFormat('dd-MM-yyyy HH:mm').format(onProviderOrder.scheduleDateTime!.toDate());
                if (await ProviderVerificationGate.blocks()) return;
                showDialog(
                    context: context,
                    builder: (BuildContext context) => acceptDialog(context: context, controller: controller, onProviderOrder: onProviderOrder, themeChange: themeChange));
              },
            ),
          ),
          const DsGap(DsSpace.md),
          Expanded(
            child: DsButton.dangerTonal(
              label: 'Decline'.tr,
              expand: true,
              onPressed: () async {
                ShowToastDialog.showLoader('Please wait...');
                onProviderOrder.status = ORDER_STATUS_REJECTED;
                await FireStoreUtils.updateOrder(onProviderOrder);

                Map<String, dynamic> payLoad = <String, dynamic>{"type": "provider_order", "orderId": onProviderOrder.id};
                await SendNotification.sendFcmMessage(providerRejected, onProviderOrder.author.fcmToken, payLoad);

                if (onProviderOrder.provider.priceUnit == "Fixed") {
                  if (onProviderOrder.payment_method.toLowerCase() != 'cod') {
                    FireStoreUtils.topUpWalletAmount(userId: onProviderOrder.author.id, amount: total.toDouble()).then((value) {
                      FireStoreUtils.updateWalletAmount(userId: onProviderOrder.author.id, amount: total.toDouble());
                    });
                  }
                }
                ShowToastDialog.closeLoader();
              },
            ),
          ),
        ],
      );
    }

    if (onProviderOrder.status == ORDER_STATUS_ASSIGNED && onProviderOrder.workerId == '') {
      return DsButton.primary(
        label: 'On Going'.tr,
        icon: Icons.play_arrow_rounded,
        expand: true,
        onPressed: () async {
          if (onProviderOrder.newScheduleDateTime!.toDate().isBefore(Timestamp.now().toDate())) {
            if (await ProviderVerificationGate.blocks()) return;
            ShowToastDialog.showLoader('Please wait...');
            onProviderOrder.status = ORDER_STATUS_ONGOING;
            if (onProviderOrder.provider.priceUnit == "Hourly") {
              onProviderOrder.startTime = Timestamp.now();
            }
            await FireStoreUtils.updateOrder(onProviderOrder);
            Map<String, dynamic> payLoad = <String, dynamic>{"type": "provider_order", "orderId": onProviderOrder.id};
            await SendNotification.sendFcmMessage(providerServiceInTransit, onProviderOrder.author.fcmToken, payLoad);

            ShowToastDialog.closeLoader();
          } else {
            Get.showSnackbar(
              GetSnackBar(
                  message: ('${"You can start booking on".tr} ${DateFormat("EEE dd MMMM , hh:mm a").format(onProviderOrder.newScheduleDateTime!.toDate())}.'),
                  duration: 5.seconds),
            );
          }
        },
      );
    }

    if (onProviderOrder.status == ORDER_STATUS_ONGOING && onProviderOrder.workerId == '') {
      final bool showExtraCharges = !(onProviderOrder.extraCharges!.isNotEmpty && onProviderOrder.extraCharges != null);
      final Widget primary = onProviderOrder.provider.priceUnit.toString() == "Hourly" && onProviderOrder.endTime == null
          ? DsButton.primary(
              label: 'Stop Time'.tr,
              icon: Icons.timer_off_outlined,
              expand: true,
              onPressed: () async {
                ShowToastDialog.showLoader('Please wait...');
                if (onProviderOrder.provider.priceUnit == "Hourly") {
                  onProviderOrder.endTime = Timestamp.now();
                  onProviderOrder.paymentStatus = false;
                  int minutes = onProviderOrder.endTime!.toDate().difference(onProviderOrder.startTime!.toDate()).inMinutes;
                  onProviderOrder.quantity = minutes > 60 ? double.parse(durationToString(minutes)) : double.parse(durationToString(60));
                }
                await FireStoreUtils.updateOrder(onProviderOrder);
                Map<String, dynamic> payLoad = <String, dynamic>{"type": "provider_order", "orderId": onProviderOrder.id};
                await SendNotification.sendFcmMessage(providerStopTime, onProviderOrder.author.fcmToken, payLoad);
                ShowToastDialog.closeLoader();
              },
            )
          : DsButton.primary(
              label: 'Complete'.tr,
              icon: Icons.check_circle_outline_rounded,
              expand: true,
              onPressed: () async {
                if (onProviderOrder.extraPaymentStatus == false || (onProviderOrder.paymentStatus == false && onProviderOrder.payment_method != "cod")) {
                  ShowToastDialog.showToast('Payment is pending.'.tr);
                } else {
                  completePickUp(onProviderOrder);
                }
              },
            );

      return Row(
        children: [
          Expanded(child: primary),
          if (showExtraCharges) ...[
            const DsGap(DsSpace.md),
            Expanded(
              child: DsButton.tonal(
                label: 'Add Extra Charges'.tr,
                expand: true,
                onPressed: () async {
                  BookingDetailsController bookingDetailsController = Get.put(BookingDetailsController());
                  CommonUI.showAddExtraChargesDialog(context, bookingDetailsController, onProviderOrder);
                  Get.delete<BookingDetailsController>();
                },
              ),
            ),
          ],
        ],
      );
    }

    if (onProviderOrder.status == ORDER_STATUS_ACCEPTED && onProviderOrder.workerId == '') {
      return Row(
        children: [
          Expanded(
            child: DsButton.primary(
              label: 'Assign to Myself'.tr,
              expand: true,
              onPressed: () async {
                if (await ProviderVerificationGate.blocks()) return;
                ShowToastDialog.showLoader('Please wait...');
                onProviderOrder.status = ORDER_STATUS_ASSIGNED;
                await FireStoreUtils.updateOrder(onProviderOrder);
                ShowToastDialog.closeLoader();
              },
            ),
          ),
          const DsGap(DsSpace.md),
          Expanded(
            child: DsButton.secondary(
              label: 'Assign to Worker'.tr,
              expand: true,
              onPressed: () async {
                Get.to(const AssignWorkerList(), arguments: {
                  "onProviderOrder": onProviderOrder,
                });
              },
            ),
          ),
        ],
      );
    }

    return null;
  }

  acceptDialog({required BuildContext context, required BookingDetailsController controller, required OnProviderOrderModel onProviderOrder, themeChange}) {
    return DsDialog(
      title: "Accept Order",
      icon: Icons.event_available_rounded,
      tone: DsTone.brand,
      content: Builder(builder: (context) {
        return InkWell(
          onTap: () async {
            BottomPicker<DateTime>.dateTime(
              onSubmit: (index) {
                controller.selectedDateTime.value = index!;
                controller.dateTimeController.value.text = DateFormat('dd-MM-yyyy HH:mm').format(index);
              },
              minDateTime: DateTime.now(),
              initialDateTime: DateTime.now().isAfter(controller.selectedDateTime.value) ? DateTime.now() : controller.selectedDateTime.value,
              buttonAlignment: MainAxisAlignment.center,
              displaySubmitButton: true,
              // bottom_picker 5 removed pickerTitle and the built-in close icon; headerBuilder restores the empty title + close button.
              headerBuilder: (context) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(''),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: Colors.black, size: 20),
                  ),
                ],
              ),
              buttonSingleColor: AppColors.colorPrimary,
              buttonPadding: 10,
              buttonWidth: 70,
            ).show(context);
          },
          child: TextFormField(
            readOnly: false,
            controller: controller.dateTimeController.value,
            textAlignVertical: TextAlignVertical.center,
            textInputAction: TextInputAction.next,
            cursorColor: AppColors.colorPrimary,
            enabled: false,
            style: context.dsText.body,
            decoration: DsInputDecoration.of(
              context,
              hint: "Choose Date and Time",
              prefixIcon: Icons.event_outlined,
            ),
          ),
        );
      }),
      primaryLabel: 'Accept'.tr,
      onPrimary: () async {
        Navigator.of(context).pop();
        ShowToastDialog.showLoader('Please wait...');
        onProviderOrder.status = ORDER_STATUS_ACCEPTED;
        onProviderOrder.newScheduleDateTime = Timestamp.fromDate(controller.selectedDateTime.value);
        await FireStoreUtils.updateOrder(onProviderOrder);
        await FireStoreUtils.providerWalletSet(onProviderOrder, onProviderOrder.provider.priceUnit == "Fixed" ? true : false);
        String subscriptionTotalOrders = (int.parse(MyAppState.currentUser?.subscriptionTotalOrders ?? '1') - 1).toString();
        if ((isSubscriptionModelApplied == true || selectedSectionModel?.adminCommision?.enable == true) && MyAppState.currentUser!.subscriptionPlan != null) {
          if (MyAppState.currentUser?.subscriptionTotalOrders != '-1' && MyAppState.currentUser?.subscriptionTotalOrders != null) {
            await FireStoreUtils.getProviderServices().then((value) async {
              for (var element in value) {
                element.subscriptionTotalOrders = subscriptionTotalOrders;
                await FireStoreUtils.firebaseAddOrUpdateProvider(element);
              }
            });
            MyAppState.currentUser?.subscriptionTotalOrders = subscriptionTotalOrders;
            await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);
          }
        }
        Map<String, dynamic> payLoad = <String, dynamic>{"type": "provider_order", "orderId": onProviderOrder.id};
        await SendNotification.sendFcmMessage(providerAccepted, onProviderOrder.author.fcmToken, payLoad);
        ShowToastDialog.closeLoader();
      },
    );
  }

  completePickUp(OnProviderOrderModel onProviderOrder) async {
    final isComplete = await Navigator.of(Get.context!).push(
      MaterialPageRoute(
        builder: (context) => VerifyOtpScreen(otp: onProviderOrder.otp),
      ),
    );
    if (isComplete != null) {
      if (isComplete == true) {
        ShowToastDialog.showLoader('Please wait...');
        onProviderOrder.status = ORDER_STATUS_COMPLETED;

        if (onProviderOrder.provider.priceUnit != "Fixed") {
          await FireStoreUtils.providerWalletSet(onProviderOrder, true);
        }

        await FireStoreUtils.getFirestOrderOrNOt(onProviderOrder).then((value) async {
          if (value == true) {
            await FireStoreUtils.updateReferralAmount(onProviderOrder);
          }
        });

        await FireStoreUtils.updateOrder(onProviderOrder);
        Map<String, dynamic> payLoad = <String, dynamic>{"type": "provider_order", "orderId": onProviderOrder.id};
        await SendNotification.sendFcmMessage(providerServiceCompleted, onProviderOrder.author.fcmToken, payLoad);

        ShowToastDialog.closeLoader();
      }
    }
  }
}

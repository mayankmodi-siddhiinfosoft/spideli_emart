import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/controller/booking_details_controller.dart';
import 'package:spideliworker/model/onprovider_order_model.dart';
import 'package:spideliworker/model/tax_model.dart';
import 'package:spideliworker/model/user.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/ui/booking_list/job_actions.dart';
import 'package:spideliworker/ui/chat_screen/full_screen_image_viewer.dart';
import 'package:spideliworker/utils/region_service.dart';
import 'package:spideliworker/ui/chat_screen/chat_screen.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:spideliworker/widgets/common_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:provider/provider.dart';

/// Job detail (archetype K). The booking is read as a live document and laid
/// out as: service summary card, customer card with call / chat / directions,
/// a [DsTimeline] of the job lifecycle, the price breakdown, extra charges,
/// reviews and the completion proof. The current action (Start / Stop Time /
/// Complete / Add Extra Charges) sits in a [DsStickyBar] at thumb reach.
class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({super.key});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  /// The booking the body last rendered, so the sticky action bar can show
  /// the right action without opening a second stream.
  final ValueNotifier<OnProviderOrderModel?> _current = ValueNotifier<OnProviderOrderModel?>(null);

  @override
  void dispose() {
    _current.dispose();
    super.dispose();
  }

  void _publish(OnProviderOrderModel? order) {
    // Each snapshot rebuilds the model, so compare what the action bar uses.
    final OnProviderOrderModel? shown = _current.value;
    if (shown?.id == order?.id && shown?.status == order?.status) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _current.value = order;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Subscribes the page to theme changes.
    Provider.of<DarkThemeProvider>(context);
    return GetBuilder<BookingDetailsController>(
        init: BookingDetailsController(),
        builder: (controller) {
          final l = context.dsLayout;
          return Scaffold(
              backgroundColor: context.dsColors.background,
              appBar: DsAppBar(title: 'Booking Summary'.tr),
              body: controller.orderId.value.isNotEmpty
                  ? StreamBuilder(
                      stream: FireStoreUtils.firestore.collection(PROVIDER_ORDER).doc(controller.orderId.value).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          _publish(null);
                          return DsErrorState(message: 'Something went wrong'.tr);
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const DsSkeletonDetail(mediaHeight: 140);
                        }
                        OnProviderOrderModel onProviderOrder = OnProviderOrderModel.fromJson(snapshot.data!.data()!);
                        _publish(onProviderOrder);
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

                        final Widget primaryColumn = Column(crossAxisAlignment: CrossAxisAlignment.start, children: DsFadeSlideIn.stagger([
                          summaryCard(context, onProviderOrder, total),
                          const DsGap(DsSpace.lg),
                          lifecycleCard(context, onProviderOrder),
                        ]));

                        final Widget secondaryColumn = Column(crossAxisAlignment: CrossAxisAlignment.start, children: DsFadeSlideIn.stagger([
                          customerCard(context, onProviderOrder),
                          const DsGap(DsSpace.lg),
                          DsSectionHeader(title: "Price Detail".tr, icon: Icons.receipt_long_outlined, padding: EdgeInsets.zero),
                          const DsGap(DsSpace.sm),
                          priceTotalRow(controller, onProviderOrder, context),
                          extraChargesCard(context, onProviderOrder),
                          cancelReasonCard(context, onProviderOrder),
                          reviewsSection(context, controller),
                          completionPhotosWidget(context, onProviderOrder),
                        ]));

                        return SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
                          child: DsResponsive(
                            maxWidth: l.isWide ? DsLayout.wideMax : DsLayout.contentMax,
                            child: l.isWide
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: primaryColumn),
                                      const DsGap(DsSpace.xxl),
                                      Expanded(child: secondaryColumn),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [primaryColumn, const DsGap(DsSpace.lg), secondaryColumn],
                                  ),
                          ),
                        );
                      })
                  : const SizedBox.shrink(),
              bottomNavigationBar: ValueListenableBuilder<OnProviderOrderModel?>(
                valueListenable: _current,
                builder: (context, onProviderOrder, _) {
                  if (onProviderOrder == null) return const SizedBox.shrink();
                  return onProviderOrder.status == ORDER_STATUS_CANCELLED ? const SizedBox.shrink() : jobActionsWidget(context, onProviderOrder);
                },
              ));
        });
  }

  /// Service, schedule, status and the booking id (tap to copy).
  Widget summaryCard(BuildContext context, OnProviderOrderModel onProviderOrder, double total) {
    final c = context.dsColors;
    final t = context.dsText;
    final DateTime schedule = onProviderOrder.newScheduleDateTime == null ? onProviderOrder.scheduleDateTime!.toDate() : onProviderOrder.newScheduleDateTime!.toDate();
    final String amount = amountShow(amount: total.toString(), currency: RegionService.currencyForRegion(onProviderOrder.regionId));
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsImage(
                url: onProviderOrder.provider.photos.isNotEmpty ? onProviderOrder.provider.photos.first.toString() : placeholderImage,
                height: 84,
                width: 84,
                radius: DsRadius.md,
                heroTag: 'job-${onProviderOrder.id}',
              ),
              const DsGap(DsSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DsStatusChip(
                        label: onProviderOrder.status.toString().tr,
                        status: onProviderOrder.status,
                        pulse: onProviderOrder.status == ORDER_STATUS_ONGOING,
                      ),
                    ),
                    const DsGap(DsSpace.sm),
                    Text(onProviderOrder.provider.title.toString(), style: t.titleSm),
                    const DsGap(DsSpace.xs),
                    Text(
                      onProviderOrder.provider.priceUnit == 'Fixed' ? amount : "$amount/hr",
                      style: t.metric.copyWith(fontSize: 20).withColor(c.brandStrong).tabular,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const DsGap(DsSpace.lg),
          Divider(height: 1, color: c.divider),
          const DsGap(DsSpace.md),
          Wrap(
            spacing: DsSpace.xl,
            runSpacing: DsSpace.sm,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_outlined, size: 18, color: c.textMuted),
                  const DsGap(DsSpace.sm),
                  Text('Date: '.tr, style: t.caption),
                  Text(DateFormat('dd-MMM-yyyy').format(schedule), style: t.bodyStrong),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_outlined, size: 18, color: c.textMuted),
                  const DsGap(DsSpace.sm),
                  Text('Time: '.tr, style: t.caption),
                  Text(DateFormat('hh:mm a').format(schedule), style: t.bodyStrong),
                ],
              ),
            ],
          ),
          const DsGap(DsSpace.md),
          Semantics(
            button: true,
            label: 'Booking ID'.tr,
            child: InkWell(
              borderRadius: DsRadius.brSm,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: onProviderOrder.id)).then((value) {
                  ShowToastDialog.showToast("Booking ID Copied");
                });
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Row(
                  children: [
                    Text('Booking ID'.tr, style: t.caption),
                    const DsGap(DsSpace.sm),
                    Expanded(
                      child: Text(
                        '# ${onProviderOrder.id}',
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: t.bodySm.withColor(c.brandStrong).tabular,
                      ),
                    ),
                    const DsGap(DsSpace.sm),
                    Icon(Icons.copy_rounded, size: 16, color: c.brandStrong),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Created -> assigned/accepted -> started -> stopped -> completed, built
  /// only from fields the model already carries.
  Widget lifecycleCard(BuildContext context, OnProviderOrderModel onProviderOrder) {
    String? at(dynamic timestamp) => timestamp == null ? null : DateFormat('dd MMM, hh:mm a').format(timestamp.toDate());

    final String status = onProviderOrder.status.toString();
    final bool cancelled = status == ORDER_STATUS_CANCELLED || status == ORDER_STATUS_REJECTED;
    final bool started = onProviderOrder.startTime != null || status == ORDER_STATUS_ONGOING || status == ORDER_STATUS_COMPLETED;
    final bool stopped = onProviderOrder.endTime != null;
    final bool completed = status == ORDER_STATUS_COMPLETED;
    final bool hourly = onProviderOrder.provider.priceUnit == "Hourly";

    DsStepState state({required bool done, required bool current}) => done
        ? DsStepState.done
        : current
            ? DsStepState.current
            : DsStepState.upcoming;

    return DsCard.outlined(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsSectionHeader(title: 'Job progress'.tr, icon: Icons.timeline_rounded, padding: EdgeInsets.zero),
          const DsGap(DsSpace.md),
          DsTimeline(steps: [
            DsTimelineStep(
              title: 'Booked'.tr,
              meta: at(onProviderOrder.createdAt),
              state: DsStepState.done,
              icon: Icons.event_available_outlined,
            ),
            DsTimelineStep(
              title: 'Assigned'.tr,
              state: cancelled ? DsStepState.error : state(done: started, current: !started),
              icon: Icons.assignment_ind_outlined,
            ),
            DsTimelineStep(
              title: 'Started'.tr,
              meta: at(onProviderOrder.startTime),
              state: cancelled ? DsStepState.upcoming : state(done: started && (stopped || completed), current: started && !completed),
              icon: Icons.play_arrow_rounded,
            ),
            if (hourly)
              DsTimelineStep(
                title: 'Stopped'.tr,
                meta: at(onProviderOrder.endTime),
                state: state(done: stopped, current: started && !stopped),
                icon: Icons.timer_off_outlined,
              ),
            DsTimelineStep(
              title: 'Completed'.tr,
              state: completed ? DsStepState.done : DsStepState.upcoming,
              icon: Icons.check_circle_outline_rounded,
            ),
          ]),
        ],
      ),
    );
  }

  /// Customer avatar, address, "Get Direction", Call and Chat.
  Widget customerCard(BuildContext context, OnProviderOrderModel onProviderOrder) {
    final c = context.dsColors;
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DsSectionHeader(title: 'About Customer'.tr, icon: Icons.person_outline, padding: EdgeInsets.zero),
            ),
            onProviderOrder.status == ORDER_STATUS_ACCEPTED
                ? DsButton.ghost(
                    label: 'Get Direction'.tr,
                    icon: Icons.directions_outlined,
                    size: DsButtonSize.sm,
                    onPressed: () async {
                      final directions = MapLauncher.directions(
                        LocationCoords(onProviderOrder.address!.location!.latitude, onProviderOrder.address!.location!.longitude,
                            title: onProviderOrder.address!.locality),
                        mode: TravelMode.driving,
                      );
                      // map_launcher 6: getSupportedMaps also returns browser-only maps, so check isInstalled to keep the old "installed" check.
                      final supportedMaps = await directions.getSupportedMaps(const [GoogleMaps()]);
                      bool isAvailable = supportedMaps.any((map) => map.isInstalled);
                      if (isAvailable == true) {
                        await directions.show(map: const GoogleMaps());
                      } else {
                        ShowToastDialog.showToast("Google map is not installed".tr);
                      }
                    },
                  )
                : const SizedBox(),
          ],
        ),
        const DsGap(DsSpace.sm),
        DsCard(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DsAvatar(
                    imageUrl: onProviderOrder.author.profilePictureURL != "" ? onProviderOrder.author.profilePictureURL.toString() : placeholderImage,
                    name: onProviderOrder.author.fullName().toString(),
                    size: 60,
                    ring: true,
                  ),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(onProviderOrder.author.fullName().toString(), style: t.titleSm),
                        const DsGap(DsSpace.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_outlined, size: 16, color: c.textMuted),
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
              onProviderOrder.status == ORDER_STATUS_ACCEPTED || onProviderOrder.status == ORDER_STATUS_ONGOING || onProviderOrder.status == ORDER_STATUS_ASSIGNED
                  ? Padding(
                      padding: const EdgeInsets.only(top: DsSpace.lg),
                      child: Row(
                        children: [
                          Expanded(
                            child: DsButton.primary(
                              label: "Call",
                              icon: Icons.call,
                              onPressed: () async {
                                makePhoneCall(onProviderOrder.author.phoneNumber.toString());
                              },
                            ),
                          ),
                          const DsGap(DsSpace.md),
                          Expanded(
                            child: DsButton.secondary(
                              label: "Chat".tr,
                              icon: Icons.chat,
                              onPressed: () async {
                                ShowToastDialog.showLoader("Please wait".tr);

                                User? customer = await FireStoreUtils.getUser(onProviderOrder.authorID);
                                User? worker = await FireStoreUtils.getWorkerCurrentUser(onProviderOrder.workerId.toString());
                                ShowToastDialog.closeLoader();
                                Get.to(ChatScreen(), arguments: {
                                  "senderName": worker?.fullName(),
                                  "senderId": worker?.id,
                                  "senderProfileUrl": worker?.profilePictureURL,
                                  "receivedName": customer?.fullName(),
                                  "receivedId": customer?.id,
                                  "receivedProfileUrl": customer?.profilePictureURL,
                                  "orderId": onProviderOrder.id,
                                  "token": worker?.fcmToken,
                                  "chatType": userRoleWorker,
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(),
            ],
          ),
        ),
      ],
    );
  }

  Widget extraChargesCard(BuildContext context, OnProviderOrderModel onProviderOrder) {
    final t = context.dsText;
    if (onProviderOrder.extraCharges.toString() == "") return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.md),
      child: DsCard.tinted(
        tone: DsTone.info,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Total Extra Charges : ", style: t.bodyStrong),
                Text(
                  amountShow(currency: RegionService.currencyForRegion(onProviderOrder.regionId), amount: onProviderOrder.extraCharges.toString()),
                  style: t.bodyStrong.tabular,
                ),
              ],
            ),
            const DsGap(DsSpace.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text("Extra charge Notes : ", style: t.bodyStrong)),
                Flexible(
                  child: Text(
                    onProviderOrder.extraChargesDescription.toString(),
                    textAlign: TextAlign.end,
                    style: t.bodyStrong,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget cancelReasonCard(BuildContext context, OnProviderOrderModel onProviderOrder) {
    if (onProviderOrder.reason!.isEmpty || onProviderOrder.reason == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.md),
      child: DsInlineAlert(
        tone: DsTone.danger,
        icon: Icons.cancel_outlined,
        title: "Cancelled reason".tr,
        message: onProviderOrder.reason.toString(),
      ),
    );
  }

  Widget reviewsSection(BuildContext context, BookingDetailsController controller) {
    return DsObserve(builder: (context) {
      if (controller.ratingService.isEmpty) return const SizedBox();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DsGap(DsSpace.lg),
          DsSectionHeader(title: "Reviews (${controller.ratingService.length})", icon: Icons.star_outline_rounded, padding: EdgeInsets.zero),
          const DsGap(DsSpace.sm),
          reviewTabViewWidget(context, controller),
        ],
      );
    });
  }

  Widget reviewTabViewWidget(BuildContext context, BookingDetailsController controller) {
    final c = context.dsColors;
    final t = context.dsText;
    return controller.ratingService.isEmpty
        ? DsEmptyState(icon: Icons.star_outline_rounded, title: "No review Found".tr, compact: true)
        : ListView.separated(
            itemCount: controller.ratingService.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (_, _) => const DsGap(DsSpace.md),
            itemBuilder: (context, index) {
              return DsFadeSlideIn(
                index: index,
                child: DsCard.outlined(
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
                        itemSize: 20,
                        itemPadding: const EdgeInsets.only(right: DsSpace.xs),
                        itemBuilder: (context, _) => Icon(
                          Icons.star,
                          color: c.warning,
                        ),
                        onRatingUpdate: (double rate) {},
                      ),
                      const DsGap(DsSpace.sm),
                      Divider(height: 1, color: c.divider),
                      const DsGap(DsSpace.sm),
                      Text(controller.ratingService[index].comment.toString(), style: t.body),
                    ],
                  ),
                ),
              );
            },
          );
  }

  Widget priceTotalRow(BookingDetailsController controller, onProviderOrder, context) {
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

    final BuildContext ctx = context;
    final c = ctx.dsColors;
    final t = ctx.dsText;

    Widget line({required Widget label, required Widget value}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.sm, horizontal: DsSpace.lg),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [label, const DsGap(DsSpace.md), Flexible(child: value)]),
        );
    Widget rule() => Padding(padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg), child: Divider(height: 1, color: c.divider));

    return DsCard.outlined(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          line(
            label: Text("Price".tr, style: t.bodyStrong),
            value: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    (onProviderOrder.provider.disPrice == "" || onProviderOrder.provider.disPrice == "0")
                        ? '${amountShow(currency: RegionService.currencyForRegion(onProviderOrder.regionId), amount: onProviderOrder.provider.price.toString())} × ${onProviderOrder.quantity}'
                        : '${amountShow(currency: RegionService.currencyForRegion(onProviderOrder.regionId), amount: onProviderOrder.provider.disPrice.toString())} × ${onProviderOrder.quantity}',
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySecondary.tabular,
                  ),
                ),
                const DsGap(DsSpace.md),
                Text(
                  amountShow(currency: RegionService.currencyForRegion(onProviderOrder.regionId), amount: controller.price.toString()),
                  style: t.bodyStrong.tabular,
                ),
              ],
            ),
          ),
          controller.discount.value != 0 ? rule() : const SizedBox(),
          controller.discount.value != 0
              ? line(
                  label: Text("Discount".tr, style: t.bodyStrong),
                  value: Text(
                    '(- ${amountShow(currency: RegionService.currencyForRegion(onProviderOrder.regionId), amount: controller.discount.value.toString())})',
                    textAlign: TextAlign.end,
                    style: t.bodyStrong.withColor(c.successStrong).tabular,
                  ),
                )
              : const SizedBox(),
          rule(),
          line(
            label: Text("SubTotal".tr, style: t.bodyStrong),
            value: Text(
              amountShow(currency: RegionService.currencyForRegion(onProviderOrder.regionId), amount: controller.subTotal.toString()),
              textAlign: TextAlign.end,
              style: t.bodyStrong.tabular,
            ),
          ),
          rule(),
          ListView.builder(
            itemCount: onProviderOrder.taxModel!.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              TaxModel taxModel = onProviderOrder.taxModel![index];
              return Column(
                children: [
                  line(
                    label: Flexible(
                      child: Text(
                        "${taxModel.title.toString()} (${taxModel.type == "fix" ? amountShow(currency: RegionService.currencyForRegion(onProviderOrder.regionId), amount: taxModel.tax) : "${taxModel.tax}%"})",
                        style: t.bodySecondary,
                      ),
                    ),
                    value: Text(
                      amountShow(
                          currency: RegionService.currencyForRegion(onProviderOrder.regionId),
                          amount: getTaxValue(amount: (double.parse(controller.subTotal.toString())).toString(), taxModel: taxModel).toString()),
                      textAlign: TextAlign.end,
                      style: t.bodyStrong.tabular,
                    ),
                  ),
                  rule(),
                ],
              );
            },
          ),
          onProviderOrder.notes.isNotEmpty
              ? line(
                  label: Text("Remarks".tr, style: t.bodyStrong),
                  value: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: DsButton.ghost(
                      label: "View".tr,
                      size: DsButtonSize.sm,
                      onPressed: () {
                        viewNotesheet(onProviderOrder.notes, ctx);
                      },
                    ),
                  ),
                )
              : const SizedBox.shrink(),
          Container(
            decoration: BoxDecoration(color: c.brandSoft, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(DsRadius.md))),
            child: line(
              label: Text("Total Amount".tr, style: t.label),
              value: Text(
                amountShow(currency: RegionService.currencyForRegion(onProviderOrder.regionId), amount: controller.totalAmount.toString()),
                textAlign: TextAlign.end,
                style: t.metric.copyWith(fontSize: 20).withColor(c.brandStrong).tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void viewNotesheet(String notes, BuildContext context) {
    Get.bottomSheet(
      DsSheet(
        title: 'Remark'.tr,
        child: Text(notes, style: context.dsText.body),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  /// Photos attached by the worker when completing the job.
  Widget completionPhotosWidget(BuildContext context, OnProviderOrderModel onProviderOrder) {
    if (onProviderOrder.completionPhotos.isEmpty && onProviderOrder.completionSignature == null) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DsGap(DsSpace.lg),
        DsSectionHeader(title: "Completion photos".tr, icon: Icons.photo_library_outlined, padding: EdgeInsets.zero),
        const DsGap(DsSpace.sm),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: onProviderOrder.completionPhotos.length,
            separatorBuilder: (_, _) => const DsGap(DsSpace.sm),
            itemBuilder: (context, index) => Semantics(
              button: true,
              label: "Completion photos".tr,
              child: InkWell(
                borderRadius: DsRadius.brMd,
                onTap: () => Get.to(() => FullScreenImageViewer(imageUrl: onProviderOrder.completionPhotos[index])),
                child: DsImage(url: onProviderOrder.completionPhotos[index], height: 96, width: 96, radius: DsRadius.md),
              ),
            ),
          ),
        ),
        if (onProviderOrder.completionSignature != null) ...[
          const DsGap(DsSpace.lg),
          DsSectionHeader(title: "Customer signature".tr, icon: Icons.draw_outlined, padding: EdgeInsets.zero),
          const DsGap(DsSpace.sm),
          Semantics(
            button: true,
            label: "Customer signature".tr,
            child: InkWell(
              borderRadius: DsRadius.brMd,
              onTap: () => Get.to(() => FullScreenImageViewer(imageUrl: onProviderOrder.completionSignature!)),
              child: DsCard.outlined(
                padding: const EdgeInsets.all(DsSpace.sm),
                // White backdrop: the signature PNG is drawn in black ink.
                color: Colors.white,
                child: DsImage(url: onProviderOrder.completionSignature!, height: 96, width: 192, fit: BoxFit.contain, radius: DsRadius.sm),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Start / Stop Time / Complete / Add Extra Charges (see JobActions), at
  /// thumb reach in a sticky bar.
  Widget jobActionsWidget(BuildContext context, OnProviderOrderModel onProviderOrder) {
    final c = context.dsColors;
    if (onProviderOrder.status == ORDER_STATUS_ASSIGNED) {
      return DsStickyBar(
        child: DsButton.primary(
          label: 'Start'.tr,
          icon: Icons.play_arrow_rounded,
          size: DsButtonSize.lg,
          expand: true,
          onPressed: () => JobActions.start(onProviderOrder),
        ),
      );
    }
    if (onProviderOrder.status == ORDER_STATUS_ONGOING) {
      final bool stopTime = onProviderOrder.provider.priceUnit.toString() == "Hourly" && onProviderOrder.endTime == null;
      return DsStickyBar(
        child: Row(
          children: [
            Expanded(
              child: stopTime
                  ? DsButton.tonal(
                      label: 'Stop Time'.tr,
                      icon: Icons.timer_off_outlined,
                      size: DsButtonSize.lg,
                      expand: true,
                      onPressed: () => JobActions.stopTime(onProviderOrder),
                    )
                  : DsButton.primary(
                      label: 'Complete'.tr,
                      icon: Icons.check_circle_outline_rounded,
                      size: DsButtonSize.lg,
                      expand: true,
                      color: c.success,
                      onPressed: () => JobActions.complete(onProviderOrder),
                    ),
            ),
            onProviderOrder.extraCharges!.isNotEmpty && onProviderOrder.extraCharges != null
                ? const SizedBox()
                : Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: DsSpace.md),
                      child: DsButton.secondary(
                        label: 'Add Extra Charges'.tr,
                        icon: Icons.add_rounded,
                        size: DsButtonSize.lg,
                        expand: true,
                        onPressed: () {
                          BookingDetailsController bookingDetailsController = Get.put(BookingDetailsController());
                          CommonUI.showAddExtraChargesDialog(context, bookingDetailsController, onProviderOrder);
                          Get.delete<BookingDetailsController>();
                        },
                      ),
                    ),
                  ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

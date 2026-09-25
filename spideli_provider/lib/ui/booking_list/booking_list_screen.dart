import 'package:spideliprovider/services/provider_verification_gate.dart';
import 'package:bottom_picker/bottom_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/booking_details_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/onprovider_order_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/region_service.dart';
import 'package:spideliprovider/services/send_notification.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/booking_list/assign_worker_list.dart';
import 'package:spideliprovider/ui/booking_list/booking_details_screen.dart';
import 'package:spideliprovider/ui/booking_list/verify_otp_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/widgets/common_ui.dart';
import 'package:spideliprovider/widgets/order_ui.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

/// Which status-chip chain a tab renders. The original screen repeated a
/// slightly different ternary chain per tab; these mirror them exactly.
enum _ChipMode { open, completed, cancelled }

class BookingListScreen extends StatefulWidget {
  const BookingListScreen({super.key});

  @override
  State<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends State<BookingListScreen> with TickerProviderStateMixin {
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(
      initialIndex: 1,
      length: 5,
      vsync: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keeps this widget subscribed to dark-mode changes; colors come from the DS.
    Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;

    // This screen is a DashboardScreen drawer tab and already owned a Scaffold
    // (no app bar of its own) — keep exactly one Scaffold.
    return Scaffold(
      backgroundColor: c.background,
      body: DefaultTabController(
        length: 5,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(
              bottom: false,
              child: DsTabBar(
                controller: tabController,
                scrollable: true,
                tabs: [
                  "New Booking".tr,
                  "Today".tr,
                  "Upcoming".tr,
                  "Completed".tr,
                  "Cancelled".tr,
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  _bookingTab(
                    stream: FireStoreUtils.firestore
                        .collection(PROVIDER_ORDER)
                        .where("provider.author", isEqualTo: MyAppState.currentUser!.id)
                        .where("status", whereIn: [ORDER_STATUS_PLACED])
                        .orderBy("createdAt", descending: true)
                        .snapshots(),
                    emptyTitle: "No New booking found".tr,
                    emptyIcon: Icons.fiber_new_outlined,
                    chipMode: _ChipMode.open,
                    completeLabel: 'Completed'.tr,
                  ),
                  _bookingTab(
                    stream: FireStoreUtils.firestore
                        .collection(PROVIDER_ORDER)
                        .where("provider.author", isEqualTo: MyAppState.currentUser!.id)
                        .where("status", whereIn: [ORDER_STATUS_ACCEPTED, ORDER_STATUS_ASSIGNED, ORDER_STATUS_ONGOING])
                        .where("newScheduleDateTime",
                            isLessThan: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59),
                            isGreaterThan: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
                        .snapshots(),
                    emptyTitle: "No Today booking found".tr,
                    emptyIcon: Icons.today_outlined,
                    chipMode: _ChipMode.open,
                    completeLabel: 'Complete'.tr,
                  ),
                  _bookingTab(
                    stream: FireStoreUtils.firestore
                        .collection(PROVIDER_ORDER)
                        .where("provider.author", isEqualTo: MyAppState.currentUser!.id)
                        .where("status", whereIn: [ORDER_STATUS_ACCEPTED, ORDER_STATUS_ASSIGNED])
                        .where(
                          "newScheduleDateTime",
                          isGreaterThan: DateTime(
                              DateTime.now().add(const Duration(days: 1)).year, DateTime.now().add(const Duration(days: 1)).month, DateTime.now().add(const Duration(days: 1)).day, 0, 0),
                        )
                        .snapshots(),
                    emptyTitle: "No upcoming booking found".tr,
                    emptyIcon: Icons.event_available_outlined,
                    chipMode: _ChipMode.open,
                    completeLabel: 'Complete'.tr,
                  ),
                  _bookingTab(
                    stream: FireStoreUtils.firestore
                        .collection(PROVIDER_ORDER)
                        .where("provider.author", isEqualTo: MyAppState.currentUser!.id)
                        .where("status", isEqualTo: ORDER_STATUS_COMPLETED)
                        .orderBy("createdAt", descending: true)
                        .snapshots(),
                    emptyTitle: "No completed booking found".tr,
                    emptyIcon: Icons.task_alt_outlined,
                    chipMode: _ChipMode.completed,
                    completeLabel: 'Complete'.tr,
                    strictWorkerCheck: true,
                  ),
                  _bookingTab(
                    stream: FireStoreUtils.firestore
                        .collection(PROVIDER_ORDER)
                        .where("provider.author", isEqualTo: MyAppState.currentUser!.id)
                        .where("status", whereIn: [ORDER_STATUS_REJECTED, ORDER_STATUS_CANCELLED])
                        .orderBy("createdAt", descending: true)
                        .snapshots(),
                    emptyTitle: "No cancelled booking found".tr,
                    emptyIcon: Icons.event_busy_outlined,
                    chipMode: _ChipMode.cancelled,
                    completeLabel: 'Complete'.tr,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab
  // ---------------------------------------------------------------------------

  /// One status tab. Every tab used to repeat the same ~700-line card; the only
  /// real differences are the query, the empty text, which status-chip chain is
  /// drawn, the "Complete"/"Completed" button label and the completed tab's
  /// stricter worker-id check — all passed in here.
  Widget _bookingTab({
    required Stream<QuerySnapshot> stream,
    required String emptyTitle,
    required IconData emptyIcon,
    required _ChipMode chipMode,
    required String completeLabel,
    bool strictWorkerCheck = false,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        final l = context.dsLayout;
        final docs = snapshot.data?.docs ?? [];

        return DsAsync(
          isLoading: snapshot.connectionState == ConnectionState.waiting,
          skeleton: DsSkeletonList(carded: true, padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl)),
          hasError: snapshot.hasError,
          error: DsErrorState(message: 'Something went wrong'.tr),
          isEmpty: docs.isEmpty,
          empty: DsEmptyState(icon: emptyIcon, title: emptyTitle),
          builder: (context) => DsResponsive(
            maxWidth: DsLayout.contentMax,
            child: ListView.builder(
              itemCount: docs.length,
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
              itemBuilder: (context, index) {
                OnProviderOrderModel onProviderOrder = OnProviderOrderModel.fromJson(docs[index].data() as Map<String, dynamic>);
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

                return DsFadeSlideIn(
                  index: index,
                  child: _bookingCard(
                    context: context,
                    onProviderOrder: onProviderOrder,
                    total: total,
                    chipMode: chipMode,
                    completeLabel: completeLabel,
                    strictWorkerCheck: strictWorkerCheck,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Card
  // ---------------------------------------------------------------------------

  Widget _bookingCard({
    required BuildContext context,
    required OnProviderOrderModel onProviderOrder,
    required double total,
    required _ChipMode chipMode,
    required String completeLabel,
    required bool strictWorkerCheck,
  }) {
    final c = context.dsColors;
    final t = context.dsText;

    final String priceText = onProviderOrder.provider.priceUnit == 'Fixed'
        ? amountShow(
            currency: RegionService.currencyForBooking(onProviderOrder.regionId),
            amount: total.toString(),
          )
        : "${amountShow(
            currency: RegionService.currencyForBooking(onProviderOrder.regionId),
            amount: total.toString(),
          )}/hr";

    final Widget? actions = _actionsFor(
      context: context,
      onProviderOrder: onProviderOrder,
      total: total,
      completeLabel: completeLabel,
    );

    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.md),
      semanticLabel: onProviderOrder.provider.title.toString(),
      onTap: () {
        Get.to(const BookingDetailsScreen(), arguments: {
          "orderId": onProviderOrder.id,
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: service image, status, title, price.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsImage(
                url: onProviderOrder.provider.photos.isNotEmpty ? onProviderOrder.provider.photos.first.toString() : placeholderImage,
                width: 76,
                height: 76,
                radius: DsRadius.md,
                heroTag: 'booking-${onProviderOrder.id}',
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Identity and status on one line: the id never wraps and
                    // the chip is aligned to the heading. The card tap opens
                    // the booking, so the id itself is not tappable here.
                    OrderIdHeader(
                      label: 'Booking ID'.tr,
                      shortId: shortBookingId("${onProviderOrder.id}"),
                      fullId: "${onProviderOrder.id}",
                      copyable: false,
                      statusChip: _statusChip(onProviderOrder, chipMode),
                    ),
                    const DsGap(DsSpace.xs),
                    Text(
                      onProviderOrder.provider.title.toString(),
                      style: t.titleSm,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const DsGap(DsSpace.xs),
                    Text(
                      priceText,
                      style: t.titleSm.withColor(c.brand).tabular,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const DsGap(DsSpace.md),

          // Detail block.
          Container(
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: DsRadius.brMd,
              border: Border.all(color: c.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
            child: Column(
              children: [
                _detailRow(
                  context,
                  icon: Icons.place_outlined,
                  label: "Address  ".tr,
                  value: onProviderOrder.address!.getFullAddress().toString(),
                ),
                _detailDivider(context),
                _detailRow(
                  context,
                  icon: Icons.schedule_rounded,
                  label: "Date & Time".tr,
                  value: DateFormat('dd-MMM-yyyy hh:mm a')
                      .format(onProviderOrder.newScheduleDateTime == null ? onProviderOrder.scheduleDateTime!.toDate() : onProviderOrder.newScheduleDateTime!.toDate()),
                ),
                _detailDivider(context),
                _detailRow(
                  context,
                  icon: Icons.person_outline_rounded,
                  label: "Customer".tr,
                  value: onProviderOrder.author.fullName().toString(),
                ),
                if (onProviderOrder.provider.priceUnit == "Hourly") ...[
                  if (onProviderOrder.startTime != null) ...[
                    _detailDivider(context),
                    _detailRow(
                      context,
                      icon: Icons.play_circle_outline_rounded,
                      label: "Start Time".tr,
                      value: DateFormat('dd-MMM-yyyy hh:mm a').format(onProviderOrder.startTime!.toDate()),
                    ),
                  ],
                  if (onProviderOrder.endTime != null) ...[
                    _detailDivider(context),
                    _detailRow(
                      context,
                      icon: Icons.stop_circle_outlined,
                      label: "End Time".tr,
                      value: onProviderOrder.endTime == null ? "0" : DateFormat('dd-MMM-yyyy hh:mm a').format(onProviderOrder.endTime!.toDate()),
                    ),
                  ],
                ],
                if (strictWorkerCheck ? (onProviderOrder.workerId != '' && onProviderOrder.workerId != null) : onProviderOrder.workerId != '')
                  FutureBuilder(
                      future: FireStoreUtils.getWorker(onProviderOrder.workerId.toString()),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: Container());
                        } else {
                          if (snapshot.hasError) {
                            return Center(child: Text('Error: '.tr + '${snapshot.error}'));
                          } else if (strictWorkerCheck && snapshot.data == null) {
                            return const SizedBox();
                          } else {
                            User model = snapshot.data!;
                            return Column(
                              children: [
                                _detailDivider(context),
                                _detailRow(
                                  context,
                                  icon: Icons.engineering_outlined,
                                  label: "Worker".tr,
                                  value: model.fullName().toString(),
                                ),
                              ],
                            );
                          }
                        }
                      }),
                if (onProviderOrder.payment_method.isNotEmpty) ...[
                  _detailDivider(context),
                  _detailRow(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    label: "Payment Type".tr,
                    value: onProviderOrder.payment_method.toString(),
                  ),
                ],
              ],
            ),
          ),

          if (actions != null) ...[
            const DsGap(DsSpace.md),
            actions,
          ],
        ],
      ),
    );
  }

  /// The per-tab status chip chains, preserved exactly as they were.
  Widget _statusChip(OnProviderOrderModel onProviderOrder, _ChipMode mode) {
    switch (mode) {
      case _ChipMode.completed:
        return DsStatusChip(label: "Complete".tr, status: onProviderOrder.status);
      case _ChipMode.cancelled:
        return onProviderOrder.status == ORDER_STATUS_PLACED
            ? DsStatusChip(label: "Pending".tr, status: onProviderOrder.status)
            : onProviderOrder.status == ORDER_STATUS_ACCEPTED || onProviderOrder.status == ORDER_STATUS_ASSIGNED
                ? DsStatusChip(label: "Accepted".tr, status: onProviderOrder.status)
                : onProviderOrder.status == ORDER_STATUS_REJECTED || onProviderOrder.status == ORDER_STATUS_CANCELLED
                    ? DsStatusChip(
                        label: onProviderOrder.status == ORDER_STATUS_REJECTED ? "Rejected" : "Cancelled".tr,
                        status: onProviderOrder.status,
                      )
                    : DsStatusChip(label: "On Going".tr, status: onProviderOrder.status, pulse: true);
      case _ChipMode.open:
        return onProviderOrder.status == ORDER_STATUS_PLACED
            ? DsStatusChip(label: "Pending".tr, status: onProviderOrder.status)
            : onProviderOrder.status == ORDER_STATUS_ACCEPTED || onProviderOrder.status == ORDER_STATUS_ASSIGNED
                ? DsStatusChip(label: "Accepted".tr, status: onProviderOrder.status)
                : DsStatusChip(label: "On Going".tr, status: onProviderOrder.status, pulse: true);
    }
  }

  Widget _detailDivider(BuildContext context) => Divider(height: 1, thickness: 1, color: context.dsColors.divider);

  /// Label left, value right — the same row the booking detail uses, so both
  /// surfaces align identically.
  Widget _detailRow(BuildContext context, {required IconData icon, required String label, required String value}) {
    return OrderMoneyRow(
      icon: icon,
      label: label,
      value: value,
      padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions — every condition and handler is the original one, verbatim.
  // ---------------------------------------------------------------------------

  Widget? _actionsFor({
    required BuildContext context,
    required OnProviderOrderModel onProviderOrder,
    required double total,
    required String completeLabel,
  }) {
    // Keeps the dark-mode subscription for the dialogs built from this subtree.
    final themeChange = Provider.of<DarkThemeProvider>(context, listen: false);

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
                dateTimeController = TextEditingController();
                selectedDateTime = onProviderOrder.scheduleDateTime!.toDate();
                dateTimeController.text = DateFormat('dd-MM-yyyy HH:mm').format(onProviderOrder.scheduleDateTime!.toDate());
                if (await ProviderVerificationGate.blocks()) return;
                showDialog(context: context, builder: (BuildContext context) => acceptDialog(onProviderOrder, themeChange));
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
              label: completeLabel,
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

  DateTime selectedDateTime = DateTime.now();
  TextEditingController dateTimeController = TextEditingController();

  acceptDialog(OnProviderOrderModel onProviderOrder, themeChange) {
    return DsDialog(
      title: "Accept Order",
      icon: Icons.event_available_rounded,
      tone: DsTone.brand,
      content: Builder(builder: (context) {
        return InkWell(
          onTap: () async {
            BottomPicker<DateTime>.dateTime(
              onSubmit: (index) {
                setState(() {
                  selectedDateTime = index!;
                  dateTimeController.text = DateFormat('dd-MM-yyyy HH:mm').format(index);
                });
              },
              minDateTime: DateTime.now(),
              initialDateTime: DateTime.now().isAfter(selectedDateTime) ? DateTime.now() : selectedDateTime,
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
              controller: dateTimeController,
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
        onProviderOrder.newScheduleDateTime = Timestamp.fromDate(selectedDateTime);
        await FireStoreUtils.updateOrder(onProviderOrder);

        await FireStoreUtils.providerWalletSet(onProviderOrder, onProviderOrder.provider.priceUnit == "Fixed" ? true : false);
        MyAppState.currentUser = await FireStoreUtils.getCurrentUser(FireStoreUtils.getCurrentUid());
        if ((isSubscriptionModelApplied == true || selectedSectionModel?.adminCommision?.enable == true) && MyAppState.currentUser?.subscriptionPlan != null) {
          if (MyAppState.currentUser?.subscriptionTotalOrders != '-1' && MyAppState.currentUser?.subscriptionTotalOrders != null) {
            String subscriptionTotalOrders = (int.parse(MyAppState.currentUser?.subscriptionTotalOrders ?? '1') - 1).toString();
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
    final isComplete = await Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => VerifyOtpScreen(
              otp: onProviderOrder.otp,
            )));
    if (isComplete != null) {
      if (isComplete == true) {
        ShowToastDialog.showLoader('Please wait...');
        onProviderOrder.status = ORDER_STATUS_COMPLETED;
        if (onProviderOrder.provider.priceUnit != "Fixed") {
          await FireStoreUtils.providerWalletSet(onProviderOrder, true);
        }

        await FireStoreUtils.updateOrder(onProviderOrder);
        Map<String, dynamic> payLoad = <String, dynamic>{"type": "provider_order", "orderId": onProviderOrder.id};
        await SendNotification.sendFcmMessage(providerServiceCompleted, onProviderOrder.author.fcmToken, payLoad);

        ShowToastDialog.closeLoader();
        setState(() {});
      }
    }
  }
}

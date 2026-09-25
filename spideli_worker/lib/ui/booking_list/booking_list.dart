import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/controller/booking_details_controller.dart';
import 'package:spideliworker/controller/verification_controller.dart';
import 'package:spideliworker/main.dart';
import 'package:spideliworker/model/onprovider_order_model.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/ui/booking_list/booking_details_screen.dart';
import 'package:spideliworker/ui/booking_list/job_actions.dart';
import 'package:spideliworker/ui/documents/documents_screen.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:spideliworker/utils/region_service.dart';
import 'package:spideliworker/widgets/common_ui.dart';
import 'package:spideliworker/widgets/order_ui.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Jobs (spec 11): Assigned | In progress | Completed.
///
/// * Assigned = "Order Assigned" / "Order Accepted", In progress = "Order
///   Ongoing", Completed = "Order Completed" -- the statuses the Provider and
///   Customer apps already use.
/// * Assigned and In progress are hidden until the worker's documents are
///   approved (when the admin requires worker verification), and only show
///   jobs of the worker's region (a job without `regionId`, or a worker
///   without one, is shown as before).
///
/// Design: archetype J ("today's jobs"). A brand [DsHeroHeader] greets the
/// worker with today's date and three live counters, a [DsSegmentedTabs] row
/// replaces the Material `TabBar`, and each job is an image-led
/// `DsCard.outlined` with its status chip and its Start / Stop Time /
/// Complete action. The counters are fed by the three existing streams (no
/// extra query).
class BookingListScreen extends StatefulWidget {
  const BookingListScreen({super.key});

  @override
  State<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends State<BookingListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 3, vsync: this)..addListener(_onTab);

  /// Job counts published by the three lists below, purely for the header.
  final List<ValueNotifier<int?>> _counts = List.generate(3, (_) => ValueNotifier<int?>(null));

  int _index = 0;

  void _onTab() {
    if (_tabController.index != _index) setState(() => _index = _tabController.index);
  }

  /// Publishes a tab's job count. Guarded: the lists report after the frame,
  /// which can land once this screen (and its notifiers) are gone.
  void _setCount(int tab, int? value) {
    if (!mounted) return;
    _counts[tab].value = value;
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTab);
    _tabController.dispose();
    for (final counter in _counts) {
      counter.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Subscribes the tab to theme changes.
    Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    final l = context.dsLayout;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsHeroHeader(
            includeTopSafeArea: true,
            showBack: false,
            title: "Jobs".tr,
            subtitle: DateFormat('EEEE, dd MMM yyyy').format(DateTime.now()),
            child: DsFadeSlideIn(
              child: Row(
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    if (i > 0) const DsGap(DsSpace.sm),
                    Expanded(
                      child: ValueListenableBuilder<int?>(
                        valueListenable: _counts[i],
                        builder: (context, jobs, _) => DsStatTile(
                          label: _tabLabels[i].tr,
                          value: jobs == null ? '—' : null,
                          countTo: jobs?.toDouble(),
                          format: (v) => v.toInt().toString(),
                          // Three tiles abreast: the icon would squeeze the
                          // label on a phone, so it only shows on tablets.
                          icon: l.isWide ? _tabIcons[i] : null,
                          variant: DsStatTileVariant.onBrand,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.sm),
            child: DsResponsive(
              child: DsSegmentedTabs(
                segments: [for (int i = 0; i < 3; i++) DsSegment(_tabLabels[i].tr)],
                index: _index,
                onChanged: (i) {
                  _tabController.animateTo(i);
                  setState(() => _index = i);
                },
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: l.gutter),
              child: DsResponsive(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _JobList(
                      statuses: const [ORDER_STATUS_ACCEPTED, ORDER_STATUS_ASSIGNED],
                      emptyMessage: "No assigned job found",
                      activeJobs: true,
                      onCount: (value) => _setCount(0, value),
                    ),
                    _JobList(
                      statuses: const [ORDER_STATUS_ONGOING],
                      emptyMessage: "No job in progress",
                      activeJobs: true,
                      onCount: (value) => _setCount(1, value),
                    ),
                    _JobList(
                      statuses: const [ORDER_STATUS_COMPLETED],
                      emptyMessage: "No completed booking found",
                      activeJobs: false,
                      onCount: (value) => _setCount(2, value),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _tabLabels = ["Assigned", "In progress", "Completed"];
  static const List<IconData> _tabIcons = [Icons.assignment_outlined, Icons.timelapse_rounded, Icons.task_alt_rounded];
}

class _JobList extends StatelessWidget {
  final List<String> statuses;
  final String emptyMessage;

  /// Active jobs are gated by verification and filtered by region; completed
  /// jobs are history and always shown.
  final bool activeJobs;

  /// Reports the number of jobs in this tab so the header can show it.
  final ValueChanged<int?> onCount;

  const _JobList({required this.statuses, required this.emptyMessage, required this.activeJobs, required this.onCount});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    if (!activeJobs) return _stream(themeChange);
    return GetBuilder<VerificationController>(builder: (verification) {
      return Obx(() {
        if (verification.isLoading.value) return const DsSkeletonList(itemCount: 4, leading: true, trailing: false);
        if (!verification.canReceiveJobs) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.lg),
            child: Column(
              children: DsFadeSlideIn.stagger([
                VerificationSummaryCard(status: verification.overallStatus, required: true, dark: themeChange.getTheme()),
                const DsGap(DsSpace.lg),
                DsButton.primary(
                  label: "My documents".tr,
                  icon: Icons.badge_outlined,
                  size: DsButtonSize.lg,
                  expand: true,
                  onPressed: () => Get.to(() => const DocumentsScreen(isBack: true)),
                ),
              ]),
            ),
          );
        }
        return _stream(themeChange);
      });
    });
  }

  /// Publishes [value] to the header after this frame (never during build).
  /// The receiver drops it when the screen is gone.
  void _report(int? value) {
    WidgetsBinding.instance.addPostFrameCallback((_) => onCount(value));
  }

  Widget _stream(DarkThemeProvider themeChange) {
    Query<Map<String, dynamic>> query = FireStoreUtils.firestore.collection(PROVIDER_ORDER).where("workerId", isEqualTo: MyAppState.currentUser!.id.toString());
    query = statuses.length == 1 ? query.where("status", isEqualTo: statuses.first) : query.where("status", whereIn: statuses);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.orderBy("createdAt", descending: true).snapshots(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
        if (snapshot.hasError) {
          return DsErrorState(message: 'Something went wrong'.tr);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const DsSkeletonList(itemCount: 4, leading: true, trailing: false);
        }
        final List<OnProviderOrderModel> orders = snapshot.data!.docs
            .map((doc) => OnProviderOrderModel.fromJson(doc.data()))
            // No region filter here: these jobs were assigned to this worker by
            // name by their provider, so hiding one would leave it assigned to
            // nobody who can see it. Region-bound dispatch belongs where a job
            // is offered, not where it is already assigned.
            .toList();
        _report(orders.length);
        if (orders.isEmpty) {
          return DsEmptyState(icon: Icons.event_available_outlined, title: emptyMessage.tr);
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: DsSpace.sm, bottom: DsSpace.xxxl),
          itemCount: orders.length,
          itemBuilder: (context, index) => DsFadeSlideIn(index: index, child: _JobCard(order: orders[index], dark: themeChange.getTheme())),
        );
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  final OnProviderOrderModel order;
  final bool dark;

  const _JobCard({required this.order, required this.dark});

  double get _total {
    double total = 0.0;
    if (order.provider.disPrice == "" || order.provider.disPrice == "0") {
      total += order.quantity * double.parse(order.provider.price.toString());
    } else {
      total += order.quantity * double.parse(order.provider.disPrice.toString());
    }
    if (order.taxModel != null) {
      for (var element in order.taxModel!) {
        total = total + getTaxValue(amount: (total).toString(), taxModel: element);
      }
    }
    return total;
  }

  Widget _badge() {
    String label;
    if (order.status == ORDER_STATUS_PLACED) {
      label = "Pending";
    } else if (order.status == ORDER_STATUS_ACCEPTED || order.status == ORDER_STATUS_ASSIGNED) {
      label = "Assigned";
    } else if (order.status == ORDER_STATUS_COMPLETED) {
      label = "Completed";
    } else {
      label = "In progress";
    }
    return DsStatusChip(label: label.tr, status: order.status, pulse: order.status == ORDER_STATUS_ONGOING);
  }

  /// Label left, value right — the same row the booking detail uses, so both
  /// surfaces align identically.
  Widget _row(BuildContext context, IconData icon, String label, String value, {bool divider = true}) {
    final c = context.dsColors;
    return Column(
      children: [
        if (divider) Divider(height: 1, color: c.divider, indent: DsSpace.huge),
        OrderMoneyRow(
          icon: icon,
          label: label.tr,
          value: value,
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
        ),
      ],
    );
  }

  Widget _actions(BuildContext context) {
    final c = context.dsColors;
    if (order.status == ORDER_STATUS_ASSIGNED) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.md, DsSpace.md, DsSpace.md),
        child: DsButton.primary(
          label: 'Start'.tr,
          icon: Icons.play_arrow_rounded,
          size: DsButtonSize.lg,
          expand: true,
          onPressed: () => JobActions.start(order),
        ),
      );
    }
    if (order.status == ORDER_STATUS_ONGOING) {
      final bool stopTime = order.provider.priceUnit == "Hourly" && order.endTime == null;
      return Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.md, DsSpace.md, DsSpace.md),
        child: Column(
          children: [
            stopTime
                ? DsButton.tonal(
                    label: 'Stop Time'.tr,
                    icon: Icons.timer_off_outlined,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () => JobActions.stopTime(order),
                  )
                : DsButton.primary(
                    label: 'Complete'.tr,
                    icon: Icons.check_circle_outline_rounded,
                    size: DsButtonSize.lg,
                    expand: true,
                    color: c.success,
                    onPressed: () => JobActions.complete(order),
                  ),
            order.extraCharges!.isNotEmpty && order.extraCharges != null
                ? const SizedBox()
                : Padding(
                    padding: const EdgeInsets.only(top: DsSpace.sm),
                    child: DsButton.ghost(
                      label: 'Add Extra Charges'.tr,
                      icon: Icons.add_rounded,
                      expand: true,
                      onPressed: () {
                        BookingDetailsController bookingDetailsController = Get.put(BookingDetailsController());
                        CommonUI.showAddExtraChargesDialog(context, bookingDetailsController, order);
                        Get.delete<BookingDetailsController>();
                      },
                    ),
                  ),
          ],
        ),
      );
    }
    return const SizedBox(height: DsSpace.sm);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final String amount = amountShow(amount: _total.toString(), currency: RegionService.currencyForRegion(order.regionId));
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.lg),
      padding: const EdgeInsets.all(DsSpace.md),
      semanticLabel: order.provider.title.toString(),
      onTap: () {
        Get.to(const BookingDetailsScreen(), arguments: {"orderId": order.id});
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DsImage(
            url: order.provider.photos.isNotEmpty ? order.provider.photos.first.toString() : placeholderImage,
            height: 84,
            width: 84,
            radius: DsRadius.md,
            heroTag: 'job-${order.id}',
          ),
          const DsGap(DsSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Identity and status on one line: the id never wraps and the
                // chip is aligned to the heading. The card tap opens the job,
                // so the id itself is not tappable here.
                OrderIdHeader(
                  label: 'Booking ID'.tr,
                  shortId: shortBookingId(order.id),
                  fullId: order.id,
                  copyable: false,
                  statusChip: _badge(),
                ),
                const DsGap(DsSpace.xs),
                Text(
                  order.provider.title.toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSm,
                ),
                const DsGap(DsSpace.xs),
                Text(
                  order.provider.priceUnit == 'Fixed' ? amount : "$amount/hr",
                  style: t.label.withColor(c.brandStrong).tabular,
                ),
              ],
            ),
          )
        ]),
        const DsGap(DsSpace.md),
        DecoratedBox(
          decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
          child: Column(
            children: [
              _row(context, Icons.location_on_outlined, "Address  ", order.address!.getFullAddress().toString(), divider: false),
              _row(
                  context,
                  Icons.event_outlined,
                  "Date & Time",
                  DateFormat('dd-MMM-yyyy hh:mm a')
                      .format(order.newScheduleDateTime == null ? order.scheduleDateTime!.toDate() : order.newScheduleDateTime!.toDate())),
              _row(context, Icons.person_outline, "Customer", order.author.fullName().toString()),
              if (order.provider.priceUnit == "Hourly" && order.startTime != null)
                _row(context, Icons.play_circle_outline, "Start Time", DateFormat('dd-MMM-yyyy hh:mm a').format(order.startTime!.toDate())),
              if (order.provider.priceUnit == "Hourly" && order.endTime != null)
                _row(context, Icons.stop_circle_outlined, "End Time", DateFormat('dd-MMM-yyyy hh:mm a').format(order.endTime!.toDate())),
              if (order.payment_method.isNotEmpty && order.status != ORDER_STATUS_COMPLETED)
                _row(context, Icons.payments_outlined, "Payment Type", order.payment_method.toString()),
              _actions(context),
            ],
          ),
        )
      ]),
    );
  }
}

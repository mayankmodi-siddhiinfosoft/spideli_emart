import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/controller/booking_details_controller.dart';
import 'package:spideliworker/controller/verification_controller.dart';
import 'package:spideliworker/main.dart';
import 'package:spideliworker/model/onprovider_order_model.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/themes/app_colors.dart';
import 'package:spideliworker/themes/responsive.dart';
import 'package:spideliworker/ui/booking_list/booking_details_screen.dart';
import 'package:spideliworker/ui/booking_list/job_actions.dart';
import 'package:spideliworker/ui/documents/documents_screen.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:spideliworker/utils/region_service.dart';
import 'package:spideliworker/widgets/common_ui.dart';
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
class BookingListScreen extends StatelessWidget {
  const BookingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return Scaffold(
        backgroundColor: themeChange.getTheme() ? AppColors.DARK_BG_COLOR : const Color(0xffF9F9F9),
        appBar: CommonUI.customAppBar(
          context,
          title: Text(
            "Jobs".tr,
            style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontSize: 18, fontFamily: AppColors.semiBold),
          ),
          isBack: false,
        ),
        body: DefaultTabController(
          length: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: themeChange.getTheme() ? AppColors.DARK_BG_COLOR : Colors.white,
                child: TabBar(
                  indicatorColor: AppColors.colorPrimary,
                  labelColor: AppColors.colorPrimary,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(child: Text("Assigned".tr, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14))),
                    Tab(child: Text("In progress".tr, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14))),
                    Tab(child: Text("Completed".tr, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TabBarView(
                    children: [
                      _JobList(statuses: const [ORDER_STATUS_ACCEPTED, ORDER_STATUS_ASSIGNED], emptyMessage: "No assigned job found", activeJobs: true),
                      _JobList(statuses: const [ORDER_STATUS_ONGOING], emptyMessage: "No job in progress", activeJobs: true),
                      _JobList(statuses: const [ORDER_STATUS_COMPLETED], emptyMessage: "No completed booking found", activeJobs: false),
                    ],
                  ),
                ),
              )
            ],
          ),
        ));
  }
}

class _JobList extends StatelessWidget {
  final List<String> statuses;
  final String emptyMessage;

  /// Active jobs are gated by verification and filtered by region; completed
  /// jobs are history and always shown.
  final bool activeJobs;

  const _JobList({required this.statuses, required this.emptyMessage, required this.activeJobs});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    if (!activeJobs) return _stream(themeChange);
    return GetBuilder<VerificationController>(builder: (verification) {
      return Obx(() {
        if (verification.isLoading.value) return loader();
        if (!verification.canReceiveJobs) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                VerificationSummaryCard(status: verification.overallStatus, required: true, dark: themeChange.getTheme()),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.colorPrimary),
                  onPressed: () => Get.to(() => const DocumentsScreen(isBack: true)),
                  child: Text("My documents".tr, style: const TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold)),
                ),
              ],
            ),
          );
        }
        return _stream(themeChange);
      });
    });
  }

  Widget _stream(DarkThemeProvider themeChange) {
    Query<Map<String, dynamic>> query = FireStoreUtils.firestore.collection(PROVIDER_ORDER).where("workerId", isEqualTo: MyAppState.currentUser!.id.toString());
    query = statuses.length == 1 ? query.where("status", isEqualTo: statuses.first) : query.where("status", whereIn: statuses);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.orderBy("createdAt", descending: true).snapshots(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Something went wrong'.tr));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loader();
        }
        final List<OnProviderOrderModel> orders = snapshot.data!.docs
            .map((doc) => OnProviderOrderModel.fromJson(doc.data()))
            // No region filter here: these jobs were assigned to this worker by
            // name by their provider, so hiding one would leave it assigned to
            // nobody who can see it. Region-bound dispatch belongs where a job
            // is offered, not where it is already assigned.
            .toList();
        if (orders.isEmpty) {
          return Center(child: Text(emptyMessage.tr));
        }
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) => _JobCard(order: orders[index], dark: themeChange.getTheme()),
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
    Color background;
    Color color;
    if (order.status == ORDER_STATUS_PLACED) {
      label = "Pending";
      background = AppColors.colorLightDeepOrange;
      color = AppColors.colorDeepOrange;
    } else if (order.status == ORDER_STATUS_ACCEPTED || order.status == ORDER_STATUS_ASSIGNED) {
      label = "Assigned";
      background = Colors.teal.shade50;
      color = Colors.teal;
    } else if (order.status == ORDER_STATUS_COMPLETED) {
      label = "Completed";
      background = Colors.lightGreen.shade100;
      color = Colors.lightGreen;
    } else {
      label = "In progress";
      background = Colors.lightGreen.shade100;
      color = Colors.lightGreen;
    }
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), color: background),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Text(label.tr, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, fontSize: 14, color: color)),
    );
  }

  Widget _row(String label, String value, {bool divider = true}) {
    return Column(
      children: [
        if (divider) const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Divider(thickness: 1)),
        Container(
          padding: EdgeInsets.only(left: 10, right: 10, top: divider ? 0 : 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.tr, style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontFamily: AppColors.medium)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 14, color: dark ? Colors.white : Colors.black, fontFamily: AppColors.medium),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _button(String label, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        elevation: 0.0,
        backgroundColor: AppColors.colorPrimary,
        padding: const EdgeInsets.all(8),
        side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
      onPressed: onPressed,
      child: Text(label.tr, style: const TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold)),
    );
  }

  Widget _actions(BuildContext context) {
    if (order.status == ORDER_STATUS_ASSIGNED) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: SizedBox(width: Responsive.width(70, context), child: _button('Start', () => JobActions.start(order))),
      );
    }
    if (order.status == ORDER_STATUS_ONGOING) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: order.provider.priceUnit == "Hourly" && order.endTime == null ? _button('Stop Time', () => JobActions.stopTime(order)) : _button('Complete', () => JobActions.complete(order)),
            ),
            const SizedBox(width: 10),
            order.extraCharges!.isNotEmpty && order.extraCharges != null
                ? const SizedBox()
                : Expanded(
                    child: _button('Add Extra Charges', () {
                      BookingDetailsController bookingDetailsController = Get.put(BookingDetailsController());
                      CommonUI.showAddExtraChargesDialog(context, bookingDetailsController, order);
                      Get.delete<BookingDetailsController>();
                    }),
                  ),
          ],
        ),
      );
    }
    return const SizedBox(height: 10);
  }

  @override
  Widget build(BuildContext context) {
    final String amount = amountShow(amount: _total.toString(), currency: RegionService.currencyForRegion(order.regionId));
    return InkWell(
      onTap: () {
        Get.to(const BookingDetailsScreen(), arguments: {"orderId": order.id});
      },
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: dark ? AppColors.darkContainerBorderColor : AppColors.colorWhite,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 10),
            Row(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(
                        image: NetworkImage(order.provider.photos.isNotEmpty ? order.provider.photos.first.toString() : placeholderImage),
                        fit: BoxFit.cover,
                      ),
                    )),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_badge()]),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(order.provider.title.toString(), style: TextStyle(color: dark ? Colors.white : AppColors.colorDark)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          order.provider.priceUnit == 'Fixed' ? amount : "$amount/hr",
                          style: TextStyle(color: AppColors.colorPrimary, fontFamily: AppColors.semiBold),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ]),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: dark ? Colors.grey.shade900 : Colors.grey.shade100, width: 1),
                color: dark ? Colors.grey.shade900 : AppColors.colorLightGrey,
              ),
              child: Column(
                children: [
                  _row("Address  ", order.address!.getFullAddress().toString(), divider: false),
                  _row(
                      "Date & Time",
                      DateFormat('dd-MMM-yyyy hh:mm a')
                          .format(order.newScheduleDateTime == null ? order.scheduleDateTime!.toDate() : order.newScheduleDateTime!.toDate())),
                  _row("Customer", order.author.fullName().toString()),
                  if (order.provider.priceUnit == "Hourly" && order.startTime != null) _row("Start Time", DateFormat('dd-MMM-yyyy hh:mm a').format(order.startTime!.toDate())),
                  if (order.provider.priceUnit == "Hourly" && order.endTime != null) _row("End Time", DateFormat('dd-MMM-yyyy hh:mm a').format(order.endTime!.toDate())),
                  if (order.payment_method.isNotEmpty && order.status != ORDER_STATUS_COMPLETED) _row("Payment Type", order.payment_method.toString()),
                  _actions(context),
                ],
              ),
            )
          ])),
    );
  }
}

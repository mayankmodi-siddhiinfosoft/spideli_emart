import 'package:bottom_picker/bottom_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/booking_details_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/onprovider_order_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/send_notification.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/responsive.dart';
import 'package:spideliprovider/ui/booking_list/assign_worker_list.dart';
import 'package:spideliprovider/ui/booking_list/booking_details_screen.dart';
import 'package:spideliprovider/ui/booking_list/verify_otp_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/widgets/common_ui.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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
    print(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
    print(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59));

    print(DateTime(DateTime.now().add(const Duration(days: 1)).year, DateTime.now().add(const Duration(days: 1)).month, DateTime.now().add(const Duration(days: 1)).day, 0, 0));
  }

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return Scaffold(
        backgroundColor: themeChange.getTheme() ? AppColors.DARK_BG_COLOR : const Color(0xffF9F9F9),
        body: DefaultTabController(
          length: 5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TabBar(
                controller: tabController,
                indicatorColor: AppColors.colorPrimary,
                labelColor: AppColors.colorPrimary,
                unselectedLabelColor: Colors.grey,
                indicatorSize: TabBarIndicatorSize.label,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: EdgeInsets.zero,
                tabs: [
                  Tab(
                    child: Text(
                      "New Booking".tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Tab(
                    child: Text(
                      "Today".tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Tab(
                    child: Text(
                      "Upcoming".tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Tab(
                    child: Text(
                      "Completed".tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Tab(
                    child: Text(
                      "Cancelled".tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 10,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TabBarView(
                    controller: tabController,
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: FireStoreUtils.firestore
                            .collection(PROVIDER_ORDER)
                            .where("provider.author", isEqualTo: MyAppState.currentUser!.id)
                            .where("status", whereIn: [ORDER_STATUS_PLACED])
                            .orderBy("createdAt", descending: true)
                            .snapshots(),
                        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                          if (snapshot.hasError) {
                            return Center(child: Text('Something went wrong'.tr));
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return loader();
                          }
                          return snapshot.data!.docs.isEmpty
                              ? Center(
                                  child: Text("No New booking found".tr),
                                )
                              : ListView.builder(
                                  itemCount: snapshot.data!.docs.length,
                                  scrollDirection: Axis.vertical,
                                  shrinkWrap: true,
                                  itemBuilder: (context, index) {
                                    OnProviderOrderModel onProviderOrder = OnProviderOrderModel.fromJson(snapshot.data!.docs[index].data() as Map<String, dynamic>);
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

                                    return InkWell(
                                      onTap: () {
                                        Get.to(const BookingDetailsScreen(), arguments: {
                                          "orderId": onProviderOrder.id,
                                        });
                                      },
                                      child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                          margin: const EdgeInsets.only(bottom: 15),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            color: themeChange.getTheme() ? AppColors.darkContainerBorderColor : AppColors.colorWhite,
                                          ),
                                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            const SizedBox(
                                              height: 10,
                                            ),
                                            Row(children: [
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                                child: Container(
                                                    height: 80,
                                                    width: 80,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(10),
                                                      image: onProviderOrder.provider.photos.isNotEmpty
                                                          ? DecorationImage(
                                                              image: NetworkImage(onProviderOrder.provider.photos.first.toString()),
                                                              fit: BoxFit.cover,
                                                            )
                                                          : DecorationImage(
                                                              image: NetworkImage(placeholderImage),
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
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          onProviderOrder.status == ORDER_STATUS_PLACED
                                                              ? Container(
                                                                  decoration: BoxDecoration(
                                                                    borderRadius: BorderRadius.circular(5),
                                                                    color: AppColors.colorLightDeepOrange,
                                                                  ),
                                                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                                                  child: Text(
                                                                    "Pending".tr,
                                                                    style: TextStyle(
                                                                      fontWeight: FontWeight.bold,
                                                                      fontFamily: AppColors.medium,
                                                                      fontSize: 14,
                                                                      color: AppColors.colorDeepOrange,
                                                                    ),
                                                                  ),
                                                                )
                                                              : onProviderOrder.status == ORDER_STATUS_ACCEPTED || onProviderOrder.status == ORDER_STATUS_ASSIGNED
                                                                  ? Container(
                                                                      decoration: BoxDecoration(
                                                                        borderRadius: BorderRadius.circular(5),
                                                                        color: Colors.teal.shade50,
                                                                      ),
                                                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                                                      child: Text(
                                                                        "Accepted".tr,
                                                                        style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, fontSize: 14, color: Colors.teal),
                                                                      ),
                                                                    )
                                                                  : Container(
                                                                      decoration: BoxDecoration(
                                                                        borderRadius: BorderRadius.circular(5),
                                                                        color: Colors.lightGreen.shade100,
                                                                      ),
                                                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                                                      child: Text(
                                                                        "On Going".tr,
                                                                        style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, fontSize: 14, color: Colors.lightGreen),
                                                                      ),
                                                                    )
                                                        ],
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 6),
                                                        child: Text(
                                                          onProviderOrder.provider.title.toString(),
                                                          style: TextStyle(
                                                            color: themeChange.getTheme() ? Colors.white : AppColors.colorDark,
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 6),
                                                        child: Text(
                                                          onProviderOrder.provider.priceUnit == 'Fixed'
                                                              ? amountShow(
                                                                  amount: total.toString(),
                                                                )
                                                              : "${amountShow(
                                                                  amount: total.toString(),
                                                                )}/hr",
                                                          style: TextStyle(
                                                            color: AppColors.colorPrimary,
                                                            fontFamily: AppColors.semiBold,
                                                          ),
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
                                                border: Border.all(color: themeChange.getTheme() ? Colors.grey.shade900 : Colors.grey.shade100, width: 1),
                                                color: themeChange.getTheme() ? Colors.grey.shade900 : AppColors.colorLightGrey,
                                              ),
                                              child: Column(
                                                children: [
                                                  Container(
                                                      padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            "Address  ".tr,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey.shade500,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              onProviderOrder.address!.getFullAddress().toString(),
                                                              overflow: TextOverflow.ellipsis,
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                fontFamily: AppColors.medium,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      )),
                                                  const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                                    child: Divider(
                                                      thickness: 1,
                                                    ),
                                                  ),
                                                  Container(
                                                      padding: const EdgeInsets.only(left: 10, right: 10),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            "Date & Time".tr,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey.shade500,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                          Text(
                                                            DateFormat('dd-MMM-yyyy hh:mm a').format(onProviderOrder.newScheduleDateTime == null
                                                                ? onProviderOrder.scheduleDateTime!.toDate()
                                                                : onProviderOrder.newScheduleDateTime!.toDate()),
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                        ],
                                                      )),
                                                  const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                                    child: Divider(
                                                      thickness: 1,
                                                    ),
                                                  ),
                                                  Container(
                                                      padding: onProviderOrder.workerId == '' ? EdgeInsets.only(left: 10, right: 10, bottom: 10) : EdgeInsets.only(left: 10, right: 10),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            "Customer".tr,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey.shade500,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                          Text(
                                                            onProviderOrder.author.fullName().toString(),
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                        ],
                                                      )),
                                                  onProviderOrder.provider.priceUnit == "Hourly"
                                                      ? Column(
                                                          children: [
                                                            onProviderOrder.startTime == null
                                                                ? SizedBox()
                                                                : Column(
                                                                    children: [
                                                                      const Padding(
                                                                        padding: EdgeInsets.symmetric(horizontal: 10),
                                                                        child: Divider(
                                                                          thickness: 1,
                                                                        ),
                                                                      ),
                                                                      Container(
                                                                          padding: EdgeInsets.only(left: 10, right: 10),
                                                                          child: Row(
                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                            children: [
                                                                              Text(
                                                                                "Start Time".tr,
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: Colors.grey.shade500,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                              Text(
                                                                                DateFormat('dd-MMM-yyyy hh:mm a').format(onProviderOrder.startTime!.toDate()),
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          )),
                                                                    ],
                                                                  ),
                                                            onProviderOrder.endTime == null
                                                                ? SizedBox()
                                                                : Column(
                                                                    children: [
                                                                      const Padding(
                                                                        padding: EdgeInsets.symmetric(horizontal: 10),
                                                                        child: Divider(
                                                                          thickness: 1,
                                                                        ),
                                                                      ),
                                                                      Container(
                                                                          padding: EdgeInsets.only(left: 10, right: 10),
                                                                          child: Row(
                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                            children: [
                                                                              Text(
                                                                                "End Time".tr,
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: Colors.grey.shade500,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                              Text(
                                                                                onProviderOrder.endTime == null ? "0" : DateFormat('dd-MMM-yyyy hh:mm a').format(onProviderOrder.endTime!.toDate()),
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          )),
                                                                    ],
                                                                  ),
                                                          ],
                                                        )
                                                      : SizedBox(),
                                                  onProviderOrder.workerId != ''
                                                      ? FutureBuilder(
                                                          future: FireStoreUtils.getWorker(onProviderOrder.workerId.toString()),
                                                          builder: (context, snapshot) {
                                                            if (snapshot.connectionState == ConnectionState.waiting) {
                                                              return Center(child: Container());
                                                            } else {
                                                              if (snapshot.hasError) {
                                                                return Center(child: Text('Error: '.tr + '${snapshot.error}'));
                                                              } else {
                                                                User model = snapshot.data!;
                                                                return Column(
                                                                  children: [
                                                                    const Padding(
                                                                      padding: EdgeInsets.symmetric(horizontal: 10),
                                                                      child: Divider(
                                                                        thickness: 1,
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                        padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                                                                        child: Row(
                                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                          children: [
                                                                            Text(
                                                                              "Worker".tr,
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                color: Colors.grey.shade500,
                                                                                fontFamily: AppColors.medium,
                                                                              ),
                                                                            ),
                                                                            Text(
                                                                              model.fullName().toString(),
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                                fontFamily: AppColors.medium,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        )),
                                                                  ],
                                                                );
                                                              }
                                                            }
                                                          })
                                                      : SizedBox(),
                                                  onProviderOrder.payment_method.isNotEmpty
                                                      ? Column(
                                                          children: [
                                                            const Padding(
                                                              padding: EdgeInsets.symmetric(horizontal: 10),
                                                              child: Divider(
                                                                thickness: 1,
                                                              ),
                                                            ),
                                                            Container(
                                                                padding: onProviderOrder.workerId == '' ? EdgeInsets.only(left: 10, right: 10, bottom: 10) : EdgeInsets.only(left: 10, right: 10),
                                                                child: Row(
                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                  children: [
                                                                    Text(
                                                                      "Payment Type".tr,
                                                                      style: TextStyle(
                                                                        fontSize: 14,
                                                                        color: Colors.grey.shade500,
                                                                        fontFamily: AppColors.medium,
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      onProviderOrder.payment_method.toString(),
                                                                      style: TextStyle(
                                                                        fontSize: 14,
                                                                        color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                        fontFamily: AppColors.medium,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                )),
                                                          ],
                                                        )
                                                      : SizedBox(),
                                                  onProviderOrder.status == ORDER_STATUS_PLACED
                                                      ? Padding(
                                                          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              Expanded(
                                                                child: ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    elevation: 0.0,
                                                                    backgroundColor: AppColors.colorPrimary,
                                                                    padding: EdgeInsets.all(8),
                                                                    side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius: BorderRadius.all(
                                                                        Radius.circular(10),
                                                                      ),
                                                                    ),
                                                                  ),
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
                                                                    showDialog(context: context, builder: (BuildContext context) => acceptDialog(onProviderOrder, themeChange));
                                                                  },
                                                                  child: Text(
                                                                    'Accept'.tr,
                                                                    style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                  ),
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                width: 10,
                                                              ),
                                                              Expanded(
                                                                child: ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    elevation: 0.0,
                                                                    backgroundColor: AppColors.colorWhite,
                                                                    padding: EdgeInsets.all(8),
                                                                    side: BorderSide(color: AppColors.colorWhite, width: 0.4),
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius: BorderRadius.all(
                                                                        Radius.circular(10),
                                                                      ),
                                                                    ),
                                                                  ),
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
                                                                  child: Text(
                                                                    'Decline'.tr,
                                                                    style: TextStyle(color: Colors.black, fontFamily: AppColors.semiBold),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        )
                                                      : onProviderOrder.status == ORDER_STATUS_ASSIGNED && onProviderOrder.workerId == ''
                                                          ? Padding(
                                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                              child: SizedBox(
                                                                width: Responsive.width(70, context),
                                                                child: ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    elevation: 0.0,
                                                                    backgroundColor: AppColors.colorPrimary,
                                                                    padding: EdgeInsets.all(8),
                                                                    side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius: BorderRadius.all(
                                                                        Radius.circular(10),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  onPressed: () async {
                                                                    if (onProviderOrder.newScheduleDateTime!.toDate().isBefore(Timestamp.now().toDate())) {
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
                                                                            message:
                                                                                ('${"You can start booking on".tr} ${DateFormat("EEE dd MMMM , hh:mm a").format(onProviderOrder.newScheduleDateTime!.toDate())}.'),
                                                                            duration: 5.seconds),
                                                                      );
                                                                    }
                                                                  },
                                                                  child: Text(
                                                                    'On Going'.tr,
                                                                    style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                  ),
                                                                ),
                                                              ),
                                                            )
                                                          : onProviderOrder.status == ORDER_STATUS_ONGOING && onProviderOrder.workerId == ''
                                                              ? Padding(
                                                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                                  child: Row(
                                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                    children: [
                                                                      Expanded(
                                                                        child: onProviderOrder.provider.priceUnit.toString() == "Hourly" && onProviderOrder.endTime == null
                                                                            ? ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                  elevation: 0.0,
                                                                                  backgroundColor: AppColors.colorPrimary,
                                                                                  padding: EdgeInsets.all(8),
                                                                                  side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                  shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.all(
                                                                                      Radius.circular(10),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                onPressed: () async {
                                                                                  ShowToastDialog.showLoader('Please wait...');
                                                                                  ShowToastDialog.showLoader('Please wait...');
                                                                                  if (onProviderOrder.provider.priceUnit == "Hourly") {
                                                                                    onProviderOrder.endTime = Timestamp.now();
                                                                                    onProviderOrder.paymentStatus = false;
                                                                                    int minutes = onProviderOrder.endTime!.toDate().difference(onProviderOrder.startTime!.toDate()).inMinutes;
                                                                                    onProviderOrder.quantity =
                                                                                        minutes > 60 ? double.parse(durationToString(minutes)) : double.parse(durationToString(60));
                                                                                  }
                                                                                  await FireStoreUtils.updateOrder(onProviderOrder);
                                                                                  Map<String, dynamic> payLoad = <String, dynamic>{"type": "provider_order", "orderId": onProviderOrder.id};
                                                                                  await SendNotification.sendFcmMessage(providerStopTime, onProviderOrder.author.fcmToken, payLoad);
                                                                                  ShowToastDialog.closeLoader();
                                                                                },
                                                                                child: Text(
                                                                                  'Stop Time'.tr,
                                                                                  style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                                ),
                                                                              )
                                                                            : ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                  elevation: 0.0,
                                                                                  backgroundColor: AppColors.colorPrimary,
                                                                                  padding: EdgeInsets.all(8),
                                                                                  side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                  shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.all(
                                                                                      Radius.circular(10),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                onPressed: () async {
                                                                                  if (onProviderOrder.extraPaymentStatus == false ||
                                                                                      (onProviderOrder.paymentStatus == false && onProviderOrder.payment_method != "cod")) {
                                                                                    ShowToastDialog.showToast('Payment is pending.'.tr);
                                                                                  } else {
                                                                                    completePickUp(onProviderOrder);
                                                                                  }
                                                                                },
                                                                                child: Text(
                                                                                  'Completed'.tr,
                                                                                  style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                                ),
                                                                              ),
                                                                      ),
                                                                      SizedBox(
                                                                        width: 10,
                                                                      ),
                                                                      onProviderOrder.extraCharges!.isNotEmpty && onProviderOrder.extraCharges != null
                                                                          ? SizedBox()
                                                                          : Expanded(
                                                                              child: ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                  elevation: 0.0,
                                                                                  backgroundColor: AppColors.colorPrimary,
                                                                                  padding: EdgeInsets.all(8),
                                                                                  side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                  shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.all(
                                                                                      Radius.circular(10),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                onPressed: () async {
                                                                                  BookingDetailsController bookingDetailsController = Get.put(BookingDetailsController());
                                                                                  CommonUI.showAddExtraChargesDialog(context, bookingDetailsController, onProviderOrder);
                                                                                  Get.delete<BookingDetailsController>();
                                                                                },
                                                                                child: Text(
                                                                                  'Add Extra Charges'.tr,
                                                                                  style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                    ],
                                                                  ),
                                                                )
                                                              : onProviderOrder.status == ORDER_STATUS_ACCEPTED && onProviderOrder.workerId == ''
                                                                  ? Padding(
                                                                      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                                                      child: Row(
                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                        children: [
                                                                          Expanded(
                                                                            child: ElevatedButton(
                                                                              style: ElevatedButton.styleFrom(
                                                                                elevation: 0.0,
                                                                                backgroundColor: AppColors.colorPrimary,
                                                                                padding: EdgeInsets.all(8),
                                                                                side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                shape: RoundedRectangleBorder(
                                                                                  borderRadius: BorderRadius.all(
                                                                                    Radius.circular(10),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              onPressed: () async {
                                                                                ShowToastDialog.showLoader('Please wait...');
                                                                                onProviderOrder.status = ORDER_STATUS_ASSIGNED;
                                                                                await FireStoreUtils.updateOrder(onProviderOrder);
                                                                                ShowToastDialog.closeLoader();
                                                                              },
                                                                              child: Text(
                                                                                'Assign to Myself'.tr,
                                                                                style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          SizedBox(
                                                                            width: 10,
                                                                          ),
                                                                          Expanded(
                                                                            child: ElevatedButton(
                                                                              style: ElevatedButton.styleFrom(
                                                                                elevation: 0.0,
                                                                                backgroundColor: AppColors.colorWhite,
                                                                                padding: EdgeInsets.all(8),
                                                                                side: BorderSide(color: AppColors.colorWhite, width: 0.4),
                                                                                shape: RoundedRectangleBorder(
                                                                                  borderRadius: BorderRadius.all(
                                                                                    Radius.circular(10),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              onPressed: () async {
                                                                                Get.to(const AssignWorkerList(), arguments: {
                                                                                  "onProviderOrder": onProviderOrder,
                                                                                });
                                                                              },
                                                                              child: Text(
                                                                                'Assign to Worker'.tr,
                                                                                style: TextStyle(color: Colors.black, fontFamily: AppColors.semiBold),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    )
                                                                  : SizedBox(),
                                                ],
                                              ),
                                            )
                                          ])),
                                    );
                                  });
                        },
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FireStoreUtils.firestore
                            .collection(PROVIDER_ORDER)
                            .where("provider.author", isEqualTo: MyAppState.currentUser!.id)
                            .where("status", whereIn: [ORDER_STATUS_ACCEPTED, ORDER_STATUS_ASSIGNED, ORDER_STATUS_ONGOING])
                            .where("newScheduleDateTime",
                                isLessThan: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59),
                                isGreaterThan: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
                            .snapshots(),
                        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                          if (snapshot.hasError) {
                            return Center(child: Text('Something went wrong'.tr));
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return loader();
                          }
                          return snapshot.data!.docs.isEmpty
                              ? Center(
                                  child: Text("No Today booking found".tr),
                                )
                              : ListView.builder(
                                  itemCount: snapshot.data!.docs.length,
                                  scrollDirection: Axis.vertical,
                                  shrinkWrap: true,
                                  itemBuilder: (context, index) {
                                    OnProviderOrderModel onProviderOrder = OnProviderOrderModel.fromJson(snapshot.data!.docs[index].data() as Map<String, dynamic>);
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
                                    return InkWell(
                                      onTap: () {
                                        print("====${onProviderOrder.startTime}");
                                        print("====${onProviderOrder.provider.priceUnit}");
                                        Get.to(const BookingDetailsScreen(), arguments: {
                                          "orderId": onProviderOrder.id,
                                        });
                                      },
                                      child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                          margin: const EdgeInsets.only(bottom: 15),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            color: themeChange.getTheme() ? AppColors.darkContainerBorderColor : AppColors.colorWhite,
                                          ),
                                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            const SizedBox(
                                              height: 10,
                                            ),
                                            Row(children: [
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                                child: Container(
                                                    height: 80,
                                                    width: 80,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(10),
                                                      image: onProviderOrder.provider.photos.isNotEmpty
                                                          ? DecorationImage(
                                                              image: NetworkImage(onProviderOrder.provider.photos.first.toString()),
                                                              fit: BoxFit.cover,
                                                            )
                                                          : DecorationImage(
                                                              image: NetworkImage(placeholderImage),
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
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          onProviderOrder.status == ORDER_STATUS_PLACED
                                                              ? Container(
                                                                  decoration: BoxDecoration(
                                                                    borderRadius: BorderRadius.circular(5),
                                                                    color: AppColors.colorLightDeepOrange,
                                                                  ),
                                                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                                                  child: Text(
                                                                    "Pending".tr,
                                                                    style: TextStyle(
                                                                      fontWeight: FontWeight.bold,
                                                                      fontFamily: AppColors.medium,
                                                                      fontSize: 14,
                                                                      color: AppColors.colorDeepOrange,
                                                                    ),
                                                                  ),
                                                                )
                                                              : onProviderOrder.status == ORDER_STATUS_ACCEPTED || onProviderOrder.status == ORDER_STATUS_ASSIGNED
                                                                  ? Container(
                                                                      decoration: BoxDecoration(
                                                                        borderRadius: BorderRadius.circular(5),
                                                                        color: Colors.teal.shade50,
                                                                      ),
                                                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                                                      child: Text(
                                                                        "Accepted".tr,
                                                                        style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, fontSize: 14, color: Colors.teal),
                                                                      ),
                                                                    )
                                                                  : Container(
                                                                      decoration: BoxDecoration(
                                                                        borderRadius: BorderRadius.circular(5),
                                                                        color: Colors.lightGreen.shade100,
                                                                      ),
                                                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                                                      child: Text(
                                                                        "On Going".tr,
                                                                        style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, fontSize: 14, color: Colors.lightGreen),
                                                                      ),
                                                                    )
                                                        ],
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 6),
                                                        child: Text(
                                                          onProviderOrder.provider.title.toString(),
                                                          style: TextStyle(
                                                            color: themeChange.getTheme() ? Colors.white : AppColors.colorDark,
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 6),
                                                        child: Text(
                                                          onProviderOrder.provider.priceUnit == 'Fixed'
                                                              ? amountShow(
                                                                  amount: total.toString(),
                                                                )
                                                              : "${amountShow(
                                                                  amount: total.toString(),
                                                                )}/hr",
                                                          style: TextStyle(
                                                            color: AppColors.colorPrimary,
                                                            fontFamily: AppColors.semiBold,
                                                          ),
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
                                                border: Border.all(color: themeChange.getTheme() ? Colors.grey.shade900 : Colors.grey.shade100, width: 1),
                                                color: themeChange.getTheme() ? Colors.grey.shade900 : AppColors.colorLightGrey,
                                              ),
                                              child: Column(
                                                children: [
                                                  Container(
                                                      padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            "Address  ".tr,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey.shade500,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              onProviderOrder.address!.getFullAddress().toString(),
                                                              overflow: TextOverflow.ellipsis,
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                fontFamily: AppColors.medium,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      )),
                                                  const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                                    child: Divider(
                                                      thickness: 1,
                                                    ),
                                                  ),
                                                  Container(
                                                      padding: const EdgeInsets.only(left: 10, right: 10),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            "Date & Time".tr,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey.shade500,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                          Text(
                                                            DateFormat('dd-MMM-yyyy hh:mm a').format(onProviderOrder.newScheduleDateTime == null
                                                                ? onProviderOrder.scheduleDateTime!.toDate()
                                                                : onProviderOrder.newScheduleDateTime!.toDate()),
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                        ],
                                                      )),
                                                  const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                                    child: Divider(
                                                      thickness: 1,
                                                    ),
                                                  ),
                                                  Container(
                                                      padding: onProviderOrder.workerId == '' ? EdgeInsets.only(left: 10, right: 10) : EdgeInsets.only(left: 10, right: 10),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            "Customer".tr,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey.shade500,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                          Text(
                                                            onProviderOrder.author.fullName().toString(),
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                        ],
                                                      )),
                                                  onProviderOrder.provider.priceUnit == "Hourly"
                                                      ? Column(
                                                          children: [
                                                            onProviderOrder.startTime == null
                                                                ? SizedBox()
                                                                : Column(
                                                                    children: [
                                                                      const Padding(
                                                                        padding: EdgeInsets.symmetric(horizontal: 10),
                                                                        child: Divider(
                                                                          thickness: 1,
                                                                        ),
                                                                      ),
                                                                      Container(
                                                                          padding: EdgeInsets.only(left: 10, right: 10),
                                                                          child: Row(
                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                            children: [
                                                                              Text(
                                                                                "Start Time".tr,
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: Colors.grey.shade500,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                              Text(
                                                                                DateFormat('dd-MMM-yyyy hh:mm a').format(onProviderOrder.startTime!.toDate()),
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          )),
                                                                    ],
                                                                  ),
                                                            onProviderOrder.endTime == null
                                                                ? SizedBox()
                                                                : Column(
                                                                    children: [
                                                                      const Padding(
                                                                        padding: EdgeInsets.symmetric(horizontal: 10),
                                                                        child: Divider(
                                                                          thickness: 1,
                                                                        ),
                                                                      ),
                                                                      Container(
                                                                          padding: EdgeInsets.only(left: 10, right: 10),
                                                                          child: Row(
                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                            children: [
                                                                              Text(
                                                                                "End Time".tr,
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: Colors.grey.shade500,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                              Text(
                                                                                onProviderOrder.endTime == null ? "0" : DateFormat('dd-MMM-yyyy hh:mm a').format(onProviderOrder.endTime!.toDate()),
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          )),
                                                                    ],
                                                                  ),
                                                          ],
                                                        )
                                                      : SizedBox(),
                                                  onProviderOrder.workerId != ''
                                                      ? FutureBuilder(
                                                          future: FireStoreUtils.getWorker(onProviderOrder.workerId.toString()),
                                                          builder: (context, snapshot) {
                                                            if (snapshot.connectionState == ConnectionState.waiting) {
                                                              return Center(child: Container());
                                                            } else {
                                                              if (snapshot.hasError) {
                                                                return Center(child: Text('Error: '.tr + '${snapshot.error}'));
                                                              } else {
                                                                User model = snapshot.data!;
                                                                return Column(
                                                                  children: [
                                                                    const Padding(
                                                                      padding: EdgeInsets.symmetric(horizontal: 10),
                                                                      child: Divider(
                                                                        thickness: 1,
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                        padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                                                                        child: Row(
                                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                          children: [
                                                                            Text(
                                                                              "Worker".tr,
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                color: Colors.grey.shade500,
                                                                                fontFamily: AppColors.medium,
                                                                              ),
                                                                            ),
                                                                            Text(
                                                                              model.fullName().toString(),
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                                fontFamily: AppColors.medium,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        )),
                                                                  ],
                                                                );
                                                              }
                                                            }
                                                          })
                                                      : SizedBox(),
                                                  onProviderOrder.payment_method.isNotEmpty
                                                      ? Column(
                                                          children: [
                                                            const Padding(
                                                              padding: EdgeInsets.symmetric(horizontal: 10),
                                                              child: Divider(
                                                                thickness: 1,
                                                              ),
                                                            ),
                                                            Container(
                                                                padding: onProviderOrder.workerId == '' ? EdgeInsets.only(left: 10, right: 10, bottom: 10) : EdgeInsets.only(left: 10, right: 10),
                                                                child: Row(
                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                  children: [
                                                                    Text(
                                                                      "Payment Type".tr,
                                                                      style: TextStyle(
                                                                        fontSize: 14,
                                                                        color: Colors.grey.shade500,
                                                                        fontFamily: AppColors.medium,
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      onProviderOrder.payment_method.toString(),
                                                                      style: TextStyle(
                                                                        fontSize: 14,
                                                                        color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                        fontFamily: AppColors.medium,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                )),
                                                          ],
                                                        )
                                                      : SizedBox(),
                                                  onProviderOrder.status == ORDER_STATUS_PLACED
                                                      ? Padding(
                                                          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              Expanded(
                                                                child: ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    elevation: 0.0,
                                                                    backgroundColor: AppColors.colorPrimary,
                                                                    padding: EdgeInsets.all(8),
                                                                    side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius: BorderRadius.all(
                                                                        Radius.circular(10),
                                                                      ),
                                                                    ),
                                                                  ),
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
                                                                    showDialog(context: context, builder: (BuildContext context) => acceptDialog(onProviderOrder, themeChange));
                                                                  },
                                                                  child: Text(
                                                                    'Accept'.tr,
                                                                    style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                  ),
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                width: 10,
                                                              ),
                                                              Expanded(
                                                                child: ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    elevation: 0.0,
                                                                    backgroundColor: AppColors.colorWhite,
                                                                    padding: EdgeInsets.all(8),
                                                                    side: BorderSide(color: AppColors.colorWhite, width: 0.4),
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius: BorderRadius.all(
                                                                        Radius.circular(10),
                                                                      ),
                                                                    ),
                                                                  ),
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
                                                                  child: Text(
                                                                    'Decline'.tr,
                                                                    style: TextStyle(color: Colors.black, fontFamily: AppColors.semiBold),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        )
                                                      : onProviderOrder.status == ORDER_STATUS_ASSIGNED && onProviderOrder.workerId == ''
                                                          ? Padding(
                                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                              child: SizedBox(
                                                                width: Responsive.width(70, context),
                                                                child: ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    elevation: 0.0,
                                                                    backgroundColor: AppColors.colorPrimary,
                                                                    padding: EdgeInsets.all(8),
                                                                    side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius: BorderRadius.all(
                                                                        Radius.circular(10),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  onPressed: () async {
                                                                    if (onProviderOrder.newScheduleDateTime!.toDate().isBefore(Timestamp.now().toDate())) {
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
                                                                            message:
                                                                                ('${"You can start booking on".tr} ${DateFormat("EEE dd MMMM , hh:mm a").format(onProviderOrder.newScheduleDateTime!.toDate())}.'),
                                                                            duration: 5.seconds),
                                                                      );
                                                                    }
                                                                  },
                                                                  child: Text(
                                                                    'On Going'.tr,
                                                                    style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                  ),
                                                                ),
                                                              ),
                                                            )
                                                          : onProviderOrder.status == ORDER_STATUS_ONGOING && onProviderOrder.workerId == ''
                                                              ? Padding(
                                                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                                  child: Row(
                                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                    children: [
                                                                      Expanded(
                                                                        child: onProviderOrder.provider.priceUnit == "Hourly" && onProviderOrder.endTime == null
                                                                            ? ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                  elevation: 0.0,
                                                                                  backgroundColor: AppColors.colorPrimary,
                                                                                  padding: EdgeInsets.all(8),
                                                                                  side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                  shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.all(
                                                                                      Radius.circular(10),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                onPressed: () async {
                                                                                  ShowToastDialog.showLoader('Please wait...');
                                                                                  if (onProviderOrder.provider.priceUnit == "Hourly") {
                                                                                    onProviderOrder.endTime = Timestamp.now();
                                                                                    onProviderOrder.paymentStatus = false;
                                                                                    int minutes = onProviderOrder.endTime!.toDate().difference(onProviderOrder.startTime!.toDate()).inMinutes;
                                                                                    onProviderOrder.quantity =
                                                                                        minutes > 60 ? double.parse(durationToString(minutes)) : double.parse(durationToString(60));
                                                                                  }
                                                                                  await FireStoreUtils.updateOrder(onProviderOrder);
                                                                                  Map<String, dynamic> payLoad = <String, dynamic>{"type": "provider_order", "orderId": onProviderOrder.id};
                                                                                  await SendNotification.sendFcmMessage(providerStopTime, onProviderOrder.author.fcmToken, payLoad);
                                                                                  ShowToastDialog.closeLoader();
                                                                                },
                                                                                child: Text(
                                                                                  'Stop Time'.tr,
                                                                                  style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                                ),
                                                                              )
                                                                            : ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                  elevation: 0.0,
                                                                                  backgroundColor: AppColors.colorPrimary,
                                                                                  padding: EdgeInsets.all(8),
                                                                                  side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                  shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.all(
                                                                                      Radius.circular(10),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                onPressed: () async {
                                                                                  if (onProviderOrder.extraPaymentStatus == false ||
                                                                                      (onProviderOrder.paymentStatus == false && onProviderOrder.payment_method != "cod")) {
                                                                                    ShowToastDialog.showToast('Payment is pending.'.tr);
                                                                                  } else {
                                                                                    completePickUp(onProviderOrder);
                                                                                  }
                                                                                },
                                                                                child: Text(
                                                                                  'Complete'.tr,
                                                                                  style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                                ),
                                                                              ),
                                                                      ),
                                                                      SizedBox(
                                                                        width: 10,
                                                                      ),
                                                                      onProviderOrder.extraCharges!.isNotEmpty && onProviderOrder.extraCharges != null
                                                                          ? SizedBox()
                                                                          : Expanded(
                                                                              child: ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                  elevation: 0.0,
                                                                                  backgroundColor: AppColors.colorPrimary,
                                                                                  padding: EdgeInsets.all(8),
                                                                                  side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                  shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.all(
                                                                                      Radius.circular(10),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                onPressed: () async {
                                                                                  BookingDetailsController bookingDetailsController = Get.put(BookingDetailsController());
                                                                                  CommonUI.showAddExtraChargesDialog(context, bookingDetailsController, onProviderOrder);
                                                                                  Get.delete<BookingDetailsController>();
                                                                                },
                                                                                child: Text(
                                                                                  'Add Extra Charges'.tr,
                                                                                  style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                    ],
                                                                  ),
                                                                )
                                                              : onProviderOrder.status == ORDER_STATUS_ACCEPTED && onProviderOrder.workerId == ''
                                                                  ? Padding(
                                                                      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                                                      child: Row(
                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                        children: [
                                                                          Expanded(
                                                                            child: ElevatedButton(
                                                                              style: ElevatedButton.styleFrom(
                                                                                elevation: 0.0,
                                                                                backgroundColor: AppColors.colorPrimary,
                                                                                padding: EdgeInsets.all(8),
                                                                                side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                shape: RoundedRectangleBorder(
                                                                                  borderRadius: BorderRadius.all(
                                                                                    Radius.circular(10),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              onPressed: () async {
                                                                                ShowToastDialog.showLoader('Please wait...');
                                                                                onProviderOrder.status = ORDER_STATUS_ASSIGNED;
                                                                                await FireStoreUtils.updateOrder(onProviderOrder);
                                                                                ShowToastDialog.closeLoader();
                                                                              },
                                                                              child: Text(
                                                                                'Assign to Myself'.tr,
                                                                                style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          SizedBox(
                                                                            width: 10,
                                                                          ),
                                                                          Expanded(
                                                                            child: ElevatedButton(
                                                                              style: ElevatedButton.styleFrom(
                                                                                elevation: 0.0,
                                                                                backgroundColor: AppColors.colorWhite,
                                                                                padding: EdgeInsets.all(8),
                                                                                side: BorderSide(color: AppColors.colorWhite, width: 0.4),
                                                                                shape: RoundedRectangleBorder(
                                                                                  borderRadius: BorderRadius.all(
                                                                                    Radius.circular(10),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              onPressed: () async {
                                                                                Get.to(const AssignWorkerList(), arguments: {
                                                                                  "onProviderOrder": onProviderOrder,
                                                                                });
                                                                              },
                                                                              child: Text(
                                                                                'Assign to Worker'.tr,
                                                                                style: TextStyle(color: Colors.black, fontFamily: AppColors.semiBold),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    )
                                                                  : SizedBox(),
                                                ],
                                              ),
                                            )
                                          ])),
                                    );
                                  },
                                );
                        },
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FireStoreUtils.firestore
                            .collection(PROVIDER_ORDER)
                            .where("provider.author", isEqualTo: MyAppState.currentUser!.id)
                            .where("status", whereIn: [ORDER_STATUS_ACCEPTED, ORDER_STATUS_ASSIGNED])
                            .where(
                              "newScheduleDateTime",
                              isGreaterThan:
                                  DateTime(DateTime.now().add(const Duration(days: 1)).year, DateTime.now().add(const Duration(days: 1)).month, DateTime.now().add(const Duration(days: 1)).day, 0, 0),
                            )
                            .snapshots(),
                        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                          if (snapshot.hasError) {
                            return Center(child: Text('Something went wrong'.tr));
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return loader();
                          }
                          return snapshot.data!.docs.isEmpty
                              ? Center(
                                  child: Text("No upcoming booking found".tr),
                                )
                              : ListView.builder(
                                  itemCount: snapshot.data!.docs.length,
                                  scrollDirection: Axis.vertical,
                                  shrinkWrap: true,
                                  itemBuilder: (context, index) {
                                    OnProviderOrderModel onProviderOrder = OnProviderOrderModel.fromJson(snapshot.data!.docs[index].data() as Map<String, dynamic>);
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
                                    return InkWell(
                                      onTap: () {
                                        Get.to(const BookingDetailsScreen(), arguments: {
                                          "orderId": onProviderOrder.id,
                                        });
                                      },
                                      child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                          margin: const EdgeInsets.only(bottom: 15),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            color: themeChange.getTheme() ? AppColors.darkContainerBorderColor : AppColors.colorWhite,
                                          ),
                                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            const SizedBox(
                                              height: 10,
                                            ),
                                            Row(children: [
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                                child: Container(
                                                    height: 80,
                                                    width: 80,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(10),
                                                      image: onProviderOrder.provider.photos.isNotEmpty
                                                          ? DecorationImage(
                                                              image: NetworkImage(onProviderOrder.provider.photos.first.toString()),
                                                              fit: BoxFit.cover,
                                                            )
                                                          : DecorationImage(
                                                              image: NetworkImage(placeholderImage),
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
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          onProviderOrder.status == ORDER_STATUS_PLACED
                                                              ? Container(
                                                                  decoration: BoxDecoration(
                                                                    borderRadius: BorderRadius.circular(5),
                                                                    color: AppColors.colorLightDeepOrange,
                                                                  ),
                                                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                                                  child: Text(
                                                                    "Pending".tr,
                                                                    style: TextStyle(
                                                                      fontWeight: FontWeight.bold,
                                                                      fontFamily: AppColors.medium,
                                                                      fontSize: 14,
                                                                      color: AppColors.colorDeepOrange,
                                                                    ),
                                                                  ),
                                                                )
                                                              : onProviderOrder.status == ORDER_STATUS_ACCEPTED || onProviderOrder.status == ORDER_STATUS_ASSIGNED
                                                                  ? Container(
                                                                      decoration: BoxDecoration(
                                                                        borderRadius: BorderRadius.circular(5),
                                                                        color: Colors.teal.shade50,
                                                                      ),
                                                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                                                      child: Text(
                                                                        "Accepted".tr,
                                                                        style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, fontSize: 14, color: Colors.teal),
                                                                      ),
                                                                    )
                                                                  : Container(
                                                                      decoration: BoxDecoration(
                                                                        borderRadius: BorderRadius.circular(5),
                                                                        color: Colors.lightGreen.shade100,
                                                                      ),
                                                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                                                      child: Text(
                                                                        "On Going".tr,
                                                                        style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, fontSize: 14, color: Colors.lightGreen),
                                                                      ),
                                                                    )
                                                        ],
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 6),
                                                        child: Text(
                                                          onProviderOrder.provider.title.toString(),
                                                          style: TextStyle(
                                                            color: themeChange.getTheme() ? Colors.white : AppColors.colorDark,
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 6),
                                                        child: Text(
                                                          onProviderOrder.provider.priceUnit == 'Fixed'
                                                              ? amountShow(
                                                                  amount: total.toString(),
                                                                )
                                                              : "${amountShow(
                                                                  amount: total.toString(),
                                                                )}/hr",
                                                          style: TextStyle(
                                                            color: AppColors.colorPrimary,
                                                            fontFamily: AppColors.semiBold,
                                                          ),
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
                                                border: Border.all(color: themeChange.getTheme() ? Colors.grey.shade900 : Colors.grey.shade100, width: 1),
                                                color: themeChange.getTheme() ? Colors.grey.shade900 : AppColors.colorLightGrey,
                                              ),
                                              child: Column(
                                                children: [
                                                  Container(
                                                      padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            "Address  ".tr,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey.shade500,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              onProviderOrder.address!.getFullAddress().toString(),
                                                              overflow: TextOverflow.ellipsis,
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                fontFamily: AppColors.medium,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      )),
                                                  const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                                    child: Divider(
                                                      thickness: 1,
                                                    ),
                                                  ),
                                                  Container(
                                                      padding: const EdgeInsets.only(left: 10, right: 10),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            "Date & Time".tr,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey.shade500,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                          Text(
                                                            DateFormat('dd-MMM-yyyy hh:mm a').format(onProviderOrder.newScheduleDateTime == null
                                                                ? onProviderOrder.scheduleDateTime!.toDate()
                                                                : onProviderOrder.newScheduleDateTime!.toDate()),
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                        ],
                                                      )),
                                                  const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                                    child: Divider(
                                                      thickness: 1,
                                                    ),
                                                  ),
                                                  Container(
                                                      padding: onProviderOrder.workerId == '' ? EdgeInsets.only(left: 10, right: 10, bottom: 10) : EdgeInsets.only(left: 10, right: 10),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            "Customer".tr,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey.shade500,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                          Text(
                                                            onProviderOrder.author.fullName().toString(),
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                        ],
                                                      )),
                                                  onProviderOrder.provider.priceUnit == "Hourly"
                                                      ? Column(
                                                          children: [
                                                            onProviderOrder.startTime == null
                                                                ? SizedBox()
                                                                : Column(
                                                                    children: [
                                                                      const Padding(
                                                                        padding: EdgeInsets.symmetric(horizontal: 10),
                                                                        child: Divider(
                                                                          thickness: 1,
                                                                        ),
                                                                      ),
                                                                      Container(
                                                                          padding: EdgeInsets.only(left: 10, right: 10),
                                                                          child: Row(
                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                            children: [
                                                                              Text(
                                                                                "Start Time".tr,
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: Colors.grey.shade500,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                              Text(
                                                                                DateFormat('dd-MMM-yyyy hh:mm a').format(onProviderOrder.startTime!.toDate()),
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          )),
                                                                    ],
                                                                  ),
                                                            onProviderOrder.endTime == null
                                                                ? SizedBox()
                                                                : Column(
                                                                    children: [
                                                                      const Padding(
                                                                        padding: EdgeInsets.symmetric(horizontal: 10),
                                                                        child: Divider(
                                                                          thickness: 1,
                                                                        ),
                                                                      ),
                                                                      Container(
                                                                          padding: EdgeInsets.only(left: 10, right: 10),
                                                                          child: Row(
                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                            children: [
                                                                              Text(
                                                                                "End Time".tr,
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: Colors.grey.shade500,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                              Text(
                                                                                onProviderOrder.endTime == null ? "0" : DateFormat('dd-MMM-yyyy hh:mm a').format(onProviderOrder.endTime!.toDate()),
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          )),
                                                                    ],
                                                                  ),
                                                          ],
                                                        )
                                                      : SizedBox(),
                                                  onProviderOrder.workerId != ''
                                                      ? FutureBuilder(
                                                          future: FireStoreUtils.getWorker(onProviderOrder.workerId.toString()),
                                                          builder: (context, snapshot) {
                                                            if (snapshot.connectionState == ConnectionState.waiting) {
                                                              return Center(child: Container());
                                                            } else {
                                                              if (snapshot.hasError) {
                                                                return Center(child: Text('Error: '.tr + '${snapshot.error}'));
                                                              } else {
                                                                User model = snapshot.data!;
                                                                return Column(
                                                                  children: [
                                                                    const Padding(
                                                                      padding: EdgeInsets.symmetric(horizontal: 10),
                                                                      child: Divider(
                                                                        thickness: 1,
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                        padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                                                                        child: Row(
                                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                          children: [
                                                                            Text(
                                                                              "Worker".tr,
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                color: Colors.grey.shade500,
                                                                                fontFamily: AppColors.medium,
                                                                              ),
                                                                            ),
                                                                            Text(
                                                                              model.fullName().toString(),
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                                fontFamily: AppColors.medium,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        )),
                                                                  ],
                                                                );
                                                              }
                                                            }
                                                          })
                                                      : SizedBox(),
                                                  onProviderOrder.payment_method.isNotEmpty
                                                      ? Column(
                                                          children: [
                                                            const Padding(
                                                              padding: EdgeInsets.symmetric(horizontal: 10),
                                                              child: Divider(
                                                                thickness: 1,
                                                              ),
                                                            ),
                                                            Container(
                                                                padding: onProviderOrder.workerId == '' ? EdgeInsets.only(left: 10, right: 10, bottom: 10) : EdgeInsets.only(left: 10, right: 10),
                                                                child: Row(
                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                  children: [
                                                                    Text(
                                                                      "Payment Type".tr,
                                                                      style: TextStyle(
                                                                        fontSize: 14,
                                                                        color: Colors.grey.shade500,
                                                                        fontFamily: AppColors.medium,
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      onProviderOrder.payment_method.toString(),
                                                                      style: TextStyle(
                                                                        fontSize: 14,
                                                                        color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                        fontFamily: AppColors.medium,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                )),
                                                          ],
                                                        )
                                                      : SizedBox(),
                                                  onProviderOrder.status == ORDER_STATUS_PLACED
                                                      ? Padding(
                                                          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              Expanded(
                                                                child: ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    elevation: 0.0,
                                                                    backgroundColor: AppColors.colorPrimary,
                                                                    padding: EdgeInsets.all(8),
                                                                    side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius: BorderRadius.all(
                                                                        Radius.circular(10),
                                                                      ),
                                                                    ),
                                                                  ),
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
                                                                    showDialog(context: context, builder: (BuildContext context) => acceptDialog(onProviderOrder, themeChange));
                                                                  },
                                                                  child: Text(
                                                                    'Accept'.tr,
                                                                    style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                  ),
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                width: 10,
                                                              ),
                                                              Expanded(
                                                                child: ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    elevation: 0.0,
                                                                    backgroundColor: AppColors.colorWhite,
                                                                    padding: EdgeInsets.all(8),
                                                                    side: BorderSide(color: AppColors.colorWhite, width: 0.4),
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius: BorderRadius.all(
                                                                        Radius.circular(10),
                                                                      ),
                                                                    ),
                                                                  ),
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
                                                                  child: Text(
                                                                    'Decline'.tr,
                                                                    style: TextStyle(color: Colors.black, fontFamily: AppColors.semiBold),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        )
                                                      : onProviderOrder.status == ORDER_STATUS_ASSIGNED && onProviderOrder.workerId == ''
                                                          ? Padding(
                                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                              child: SizedBox(
                                                                width: Responsive.width(70, context),
                                                                child: ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    elevation: 0.0,
                                                                    backgroundColor: AppColors.colorPrimary,
                                                                    padding: EdgeInsets.all(8),
                                                                    side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius: BorderRadius.all(
                                                                        Radius.circular(10),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  onPressed: () async {
                                                                    if (onProviderOrder.newScheduleDateTime!.toDate().isBefore(Timestamp.now().toDate())) {
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
                                                                            message:
                                                                                ('${"You can start booking on".tr} ${DateFormat("EEE dd MMMM , hh:mm a").format(onProviderOrder.newScheduleDateTime!.toDate())}.'),
                                                                            duration: 5.seconds),
                                                                      );
                                                                    }
                                                                  },
                                                                  child: Text(
                                                                    'On Going'.tr,
                                                                    style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                  ),
                                                                ),
                                                              ),
                                                            )
                                                          : onProviderOrder.status == ORDER_STATUS_ONGOING && onProviderOrder.workerId == ''
                                                              ? Padding(
                                                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                                  child: Row(
                                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                    children: [
                                                                      Expanded(
                                                                        child: onProviderOrder.provider.priceUnit == "Hourly" && onProviderOrder.endTime == null
                                                                            ? ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                  elevation: 0.0,
                                                                                  backgroundColor: AppColors.colorPrimary,
                                                                                  padding: EdgeInsets.all(8),
                                                                                  side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                  shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.all(
                                                                                      Radius.circular(10),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                onPressed: () async {
                                                                                  ShowToastDialog.showLoader('Please wait...');
                                                                                  if (onProviderOrder.provider.priceUnit == "Hourly") {
                                                                                    onProviderOrder.endTime = Timestamp.now();
                                                                                    onProviderOrder.paymentStatus = false;
                                                                                    int minutes = onProviderOrder.endTime!.toDate().difference(onProviderOrder.startTime!.toDate()).inMinutes;
                                                                                    onProviderOrder.quantity =
                                                                                        minutes > 60 ? double.parse(durationToString(minutes)) : double.parse(durationToString(60));
                                                                                  }
                                                                                  await FireStoreUtils.updateOrder(onProviderOrder);
                                                                                  Map<String, dynamic> payLoad = <String, dynamic>{"type": "provider_order", "orderId": onProviderOrder.id};
                                                                                  await SendNotification.sendFcmMessage(providerStopTime, onProviderOrder.author.fcmToken, payLoad);
                                                                                  ShowToastDialog.closeLoader();
                                                                                },
                                                                                child: Text(
                                                                                  'Stop Time'.tr,
                                                                                  style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                                ),
                                                                              )
                                                                            : ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                  elevation: 0.0,
                                                                                  backgroundColor: AppColors.colorPrimary,
                                                                                  padding: EdgeInsets.all(8),
                                                                                  side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                  shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.all(
                                                                                      Radius.circular(10),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                onPressed: () async {
                                                                                  if (onProviderOrder.extraPaymentStatus == false ||
                                                                                      (onProviderOrder.paymentStatus == false && onProviderOrder.payment_method != "cod")) {
                                                                                    ShowToastDialog.showToast('Payment is pending.'.tr);
                                                                                  } else {
                                                                                    completePickUp(onProviderOrder);
                                                                                  }
                                                                                },
                                                                                child: Text(
                                                                                  'Complete'.tr,
                                                                                  style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                                ),
                                                                              ),
                                                                      ),
                                                                      SizedBox(
                                                                        width: 10,
                                                                      ),
                                                                      onProviderOrder.extraCharges!.isNotEmpty && onProviderOrder.extraCharges != null
                                                                          ? SizedBox()
                                                                          : Expanded(
                                                                              child: ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                  elevation: 0.0,
                                                                                  backgroundColor: AppColors.colorPrimary,
                                                                                  padding: EdgeInsets.all(8),
                                                                                  side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                  shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.all(
                                                                                      Radius.circular(10),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                onPressed: () async {
                                                                                  BookingDetailsController bookingDetailsController = Get.put(BookingDetailsController());
                                                                                  CommonUI.showAddExtraChargesDialog(context, bookingDetailsController, onProviderOrder);
                                                                                  Get.delete<BookingDetailsController>();
                                                                                },
                                                                                child: Text(
                                                                                  'Add Extra Charges'.tr,
                                                                                  style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                    ],
                                                                  ),
                                                                )
                                                              : onProviderOrder.status == ORDER_STATUS_ACCEPTED && onProviderOrder.workerId == ''
                                                                  ? Padding(
                                                                      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                                                      child: Row(
                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                        children: [
                                                                          Expanded(
                                                                            child: ElevatedButton(
                                                                              style: ElevatedButton.styleFrom(
                                                                                elevation: 0.0,
                                                                                backgroundColor: AppColors.colorPrimary,
                                                                                padding: EdgeInsets.all(8),
                                                                                side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                shape: RoundedRectangleBorder(
                                                                                  borderRadius: BorderRadius.all(
                                                                                    Radius.circular(10),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              onPressed: () async {
                                                                                ShowToastDialog.showLoader('Please wait...');
                                                                                onProviderOrder.status = ORDER_STATUS_ASSIGNED;
                                                                                await FireStoreUtils.updateOrder(onProviderOrder);
                                                                                ShowToastDialog.closeLoader();
                                                                              },
                                                                              child: Text(
                                                                                'Assign to Myself'.tr,
                                                                                style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          SizedBox(
                                                                            width: 10,
                                                                          ),
                                                                          Expanded(
                                                                            child: ElevatedButton(
                                                                              style: ElevatedButton.styleFrom(
                                                                                elevation: 0.0,
                                                                                backgroundColor: AppColors.colorWhite,
                                                                                padding: EdgeInsets.all(8),
                                                                                side: BorderSide(color: AppColors.colorWhite, width: 0.4),
                                                                                shape: RoundedRectangleBorder(
                                                                                  borderRadius: BorderRadius.all(
                                                                                    Radius.circular(10),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              onPressed: () async {
                                                                                Get.to(const AssignWorkerList(), arguments: {
                                                                                  "onProviderOrder": onProviderOrder,
                                                                                });
                                                                              },
                                                                              child: Text(
                                                                                'Assign to Worker'.tr,
                                                                                style: TextStyle(color: Colors.black, fontFamily: AppColors.semiBold),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    )
                                                                  : SizedBox(),
                                                ],
                                              ),
                                            )
                                          ])),
                                    );
                                  });
                        },
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FireStoreUtils.firestore
                            .collection(PROVIDER_ORDER)
                            .where("provider.author", isEqualTo: MyAppState.currentUser!.id)
                            .where("status", isEqualTo: ORDER_STATUS_COMPLETED)
                            .orderBy("createdAt", descending: true)
                            .snapshots(),
                        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                          if (snapshot.hasError) {
                            return Center(child: Text('Something went wrong'.tr));
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return loader();
                          }
                          return snapshot.data!.docs.isEmpty
                              ? Center(
                                  child: Text("No completed booking found".tr),
                                )
                              : ListView.builder(
                                  itemCount: snapshot.data!.docs.length,
                                  scrollDirection: Axis.vertical,
                                  shrinkWrap: true,
                                  itemBuilder: (context, index) {
                                    OnProviderOrderModel onProviderOrder = OnProviderOrderModel.fromJson(snapshot.data!.docs[index].data() as Map<String, dynamic>);
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
                                    return InkWell(
                                      onTap: () {
                                        Get.to(const BookingDetailsScreen(), arguments: {
                                          "orderId": onProviderOrder.id,
                                        });
                                      },
                                      child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                          margin: const EdgeInsets.only(bottom: 15),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            color: themeChange.getTheme() ? AppColors.darkContainerBorderColor : AppColors.colorWhite,
                                          ),
                                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            const SizedBox(
                                              height: 10,
                                            ),
                                            Row(children: [
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                                child: Container(
                                                    height: 80,
                                                    width: 80,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(10),
                                                      image: onProviderOrder.provider.photos.isNotEmpty
                                                          ? DecorationImage(
                                                              image: NetworkImage(onProviderOrder.provider.photos.first.toString()),
                                                              fit: BoxFit.cover,
                                                            )
                                                          : DecorationImage(
                                                              image: NetworkImage(placeholderImage),
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
                                                      Container(
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(5),
                                                          color: Colors.lightGreen.shade100,
                                                        ),
                                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                                        child: Text(
                                                          "Complete".tr,
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, fontSize: 14, color: Colors.lightGreen),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 6),
                                                        child: Text(
                                                          onProviderOrder.provider.title.toString(),
                                                          style: TextStyle(
                                                            color: themeChange.getTheme() ? Colors.white : AppColors.colorDark,
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 6),
                                                        child: Text(
                                                          onProviderOrder.provider.priceUnit == 'Fixed'
                                                              ? amountShow(
                                                                  amount: total.toString(),
                                                                )
                                                              : "${amountShow(
                                                                  amount: total.toString(),
                                                                )}/hr",
                                                          style: TextStyle(
                                                            color: AppColors.colorPrimary,
                                                            fontFamily: AppColors.semiBold,
                                                          ),
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
                                                border: Border.all(color: themeChange.getTheme() ? Colors.grey.shade900 : Colors.grey.shade100, width: 1),
                                                color: themeChange.getTheme() ? Colors.grey.shade900 : AppColors.colorLightGrey,
                                              ),
                                              child: Column(
                                                children: [
                                                  Container(
                                                      padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            "Address  ".tr,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey.shade500,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              onProviderOrder.address!.getFullAddress().toString(),
                                                              overflow: TextOverflow.ellipsis,
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                fontFamily: AppColors.medium,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      )),
                                                  const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                                    child: Divider(
                                                      thickness: 1,
                                                    ),
                                                  ),
                                                  Container(
                                                      padding: const EdgeInsets.only(left: 10, right: 10),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            "Date & Time".tr,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey.shade500,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                          Text(
                                                            DateFormat('dd-MMM-yyyy hh:mm a').format(onProviderOrder.newScheduleDateTime == null
                                                                ? onProviderOrder.scheduleDateTime!.toDate()
                                                                : onProviderOrder.newScheduleDateTime!.toDate()),
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                        ],
                                                      )),
                                                  const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                                    child: Divider(
                                                      thickness: 1,
                                                    ),
                                                  ),
                                                  Container(
                                                      padding: onProviderOrder.workerId == '' ? EdgeInsets.only(left: 10, right: 10, bottom: 10) : EdgeInsets.only(left: 10, right: 10),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            "Customer".tr,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey.shade500,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                          Text(
                                                            onProviderOrder.author.fullName().toString(),
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                        ],
                                                      )),
                                                  onProviderOrder.provider.priceUnit == "Hourly"
                                                      ? Column(
                                                          children: [
                                                            onProviderOrder.startTime == null
                                                                ? SizedBox()
                                                                : Column(
                                                                    children: [
                                                                      const Padding(
                                                                        padding: EdgeInsets.symmetric(horizontal: 10),
                                                                        child: Divider(
                                                                          thickness: 1,
                                                                        ),
                                                                      ),
                                                                      Container(
                                                                          padding: EdgeInsets.only(left: 10, right: 10),
                                                                          child: Row(
                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                            children: [
                                                                              Text(
                                                                                "Start Time".tr,
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: Colors.grey.shade500,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                              Text(
                                                                                DateFormat('dd-MMM-yyyy hh:mm a').format(onProviderOrder.startTime!.toDate()),
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          )),
                                                                    ],
                                                                  ),
                                                            onProviderOrder.endTime == null
                                                                ? SizedBox()
                                                                : Column(
                                                                    children: [
                                                                      const Padding(
                                                                        padding: EdgeInsets.symmetric(horizontal: 10),
                                                                        child: Divider(
                                                                          thickness: 1,
                                                                        ),
                                                                      ),
                                                                      Container(
                                                                          padding: EdgeInsets.only(left: 10, right: 10),
                                                                          child: Row(
                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                            children: [
                                                                              Text(
                                                                                "End Time".tr,
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: Colors.grey.shade500,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                              Text(
                                                                                onProviderOrder.endTime == null ? "0" : DateFormat('dd-MMM-yyyy hh:mm a').format(onProviderOrder.endTime!.toDate()),
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          )),
                                                                    ],
                                                                  ),
                                                          ],
                                                        )
                                                      : SizedBox(),
                                                  onProviderOrder.workerId != '' && onProviderOrder.workerId != null
                                                      ? FutureBuilder(
                                                          future: FireStoreUtils.getWorker(onProviderOrder.workerId.toString()),
                                                          builder: (context, snapshot) {
                                                            if (snapshot.connectionState == ConnectionState.waiting) {
                                                              return Center(child: Container());
                                                            } else {
                                                              if (snapshot.hasError) {
                                                                return Center(child: Text('Error: '.tr + '${snapshot.error}'));
                                                              } else if (snapshot.data == null) {
                                                                return SizedBox();
                                                              } else {
                                                                User model = snapshot.data!;
                                                                return Column(
                                                                  children: [
                                                                    const Padding(
                                                                      padding: EdgeInsets.symmetric(horizontal: 10),
                                                                      child: Divider(
                                                                        thickness: 1,
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                        padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                                                                        child: Row(
                                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                          children: [
                                                                            Text(
                                                                              "Worker".tr,
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                color: Colors.grey.shade500,
                                                                                fontFamily: AppColors.medium,
                                                                              ),
                                                                            ),
                                                                            Text(
                                                                              model.fullName().toString(),
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                                fontFamily: AppColors.medium,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        )),
                                                                  ],
                                                                );
                                                              }
                                                            }
                                                          })
                                                      : SizedBox(),
                                                  onProviderOrder.payment_method.isNotEmpty
                                                      ? Column(
                                                          children: [
                                                            const Padding(
                                                              padding: EdgeInsets.symmetric(horizontal: 10),
                                                              child: Divider(
                                                                thickness: 1,
                                                              ),
                                                            ),
                                                            Container(
                                                                padding: onProviderOrder.workerId == '' ? EdgeInsets.only(left: 10, right: 10, bottom: 10) : EdgeInsets.only(left: 10, right: 10),
                                                                child: Row(
                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                  children: [
                                                                    Text(
                                                                      "Payment Type".tr,
                                                                      style: TextStyle(
                                                                        fontSize: 14,
                                                                        color: Colors.grey.shade500,
                                                                        fontFamily: AppColors.medium,
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      onProviderOrder.payment_method.toString(),
                                                                      style: TextStyle(
                                                                        fontSize: 14,
                                                                        color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                        fontFamily: AppColors.medium,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                )),
                                                          ],
                                                        )
                                                      : SizedBox(),
                                                  onProviderOrder.status == ORDER_STATUS_PLACED
                                                      ? Padding(
                                                          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              Expanded(
                                                                child: ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    elevation: 0.0,
                                                                    backgroundColor: AppColors.colorPrimary,
                                                                    padding: EdgeInsets.all(8),
                                                                    side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius: BorderRadius.all(
                                                                        Radius.circular(10),
                                                                      ),
                                                                    ),
                                                                  ),
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
                                                                    showDialog(context: context, builder: (BuildContext context) => acceptDialog(onProviderOrder, themeChange));
                                                                  },
                                                                  child: Text(
                                                                    'Accept'.tr,
                                                                    style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                  ),
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                width: 10,
                                                              ),
                                                              Expanded(
                                                                child: ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    elevation: 0.0,
                                                                    backgroundColor: AppColors.colorWhite,
                                                                    padding: EdgeInsets.all(8),
                                                                    side: BorderSide(color: AppColors.colorWhite, width: 0.4),
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius: BorderRadius.all(
                                                                        Radius.circular(10),
                                                                      ),
                                                                    ),
                                                                  ),
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
                                                                  child: Text(
                                                                    'Decline'.tr,
                                                                    style: TextStyle(color: Colors.black, fontFamily: AppColors.semiBold),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        )
                                                      : onProviderOrder.status == ORDER_STATUS_ASSIGNED && onProviderOrder.workerId == ''
                                                          ? Padding(
                                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                              child: SizedBox(
                                                                width: Responsive.width(70, context),
                                                                child: ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    elevation: 0.0,
                                                                    backgroundColor: AppColors.colorPrimary,
                                                                    padding: EdgeInsets.all(8),
                                                                    side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius: BorderRadius.all(
                                                                        Radius.circular(10),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  onPressed: () async {
                                                                    if (onProviderOrder.newScheduleDateTime!.toDate().isBefore(Timestamp.now().toDate())) {
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
                                                                            message:
                                                                                ('${"You can start booking on".tr} ${DateFormat("EEE dd MMMM , hh:mm a").format(onProviderOrder.newScheduleDateTime!.toDate())}.'),
                                                                            duration: 5.seconds),
                                                                      );
                                                                    }
                                                                  },
                                                                  child: Text(
                                                                    'On Going'.tr,
                                                                    style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                  ),
                                                                ),
                                                              ),
                                                            )
                                                          : onProviderOrder.status == ORDER_STATUS_ONGOING && onProviderOrder.workerId == ''
                                                              ? Padding(
                                                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                                  child: Row(
                                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                    children: [
                                                                      Expanded(
                                                                        child: onProviderOrder.provider.priceUnit == "Hourly" && onProviderOrder.endTime == null
                                                                            ? ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                  elevation: 0.0,
                                                                                  backgroundColor: AppColors.colorPrimary,
                                                                                  padding: EdgeInsets.all(8),
                                                                                  side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                  shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.all(
                                                                                      Radius.circular(10),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                onPressed: () async {
                                                                                  ShowToastDialog.showLoader('Please wait...');
                                                                                  if (onProviderOrder.provider.priceUnit == "Hourly") {
                                                                                    onProviderOrder.endTime = Timestamp.now();
                                                                                    onProviderOrder.paymentStatus = false;
                                                                                    int minutes = onProviderOrder.endTime!.toDate().difference(onProviderOrder.startTime!.toDate()).inMinutes;
                                                                                    onProviderOrder.quantity =
                                                                                        minutes > 60 ? double.parse(durationToString(minutes)) : double.parse(durationToString(60));
                                                                                  }
                                                                                  await FireStoreUtils.updateOrder(onProviderOrder);
                                                                                  Map<String, dynamic> payLoad = <String, dynamic>{"type": "provider_order", "orderId": onProviderOrder.id};
                                                                                  await SendNotification.sendFcmMessage(providerStopTime, onProviderOrder.author.fcmToken, payLoad);
                                                                                  ShowToastDialog.closeLoader();
                                                                                },
                                                                                child: Text(
                                                                                  'Stop Time'.tr,
                                                                                  style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                                ),
                                                                              )
                                                                            : ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                  elevation: 0.0,
                                                                                  backgroundColor: AppColors.colorPrimary,
                                                                                  padding: EdgeInsets.all(8),
                                                                                  side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                  shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.all(
                                                                                      Radius.circular(10),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                onPressed: () async {
                                                                                  if (onProviderOrder.extraPaymentStatus == false ||
                                                                                      (onProviderOrder.paymentStatus == false && onProviderOrder.payment_method != "cod")) {
                                                                                    ShowToastDialog.showToast('Payment is pending.'.tr);
                                                                                  } else {
                                                                                    completePickUp(onProviderOrder);
                                                                                  }
                                                                                },
                                                                                child: Text(
                                                                                  'Complete'.tr,
                                                                                  style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                                ),
                                                                              ),
                                                                      ),
                                                                      SizedBox(
                                                                        width: 10,
                                                                      ),
                                                                      onProviderOrder.extraCharges!.isNotEmpty && onProviderOrder.extraCharges != null
                                                                          ? SizedBox()
                                                                          : Expanded(
                                                                              child: ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                  elevation: 0.0,
                                                                                  backgroundColor: AppColors.colorPrimary,
                                                                                  padding: EdgeInsets.all(8),
                                                                                  side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                  shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.all(
                                                                                      Radius.circular(10),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                onPressed: () async {
                                                                                  BookingDetailsController bookingDetailsController = Get.put(BookingDetailsController());
                                                                                  CommonUI.showAddExtraChargesDialog(context, bookingDetailsController, onProviderOrder);
                                                                                  Get.delete<BookingDetailsController>();
                                                                                },
                                                                                child: Text(
                                                                                  'Add Extra Charges'.tr,
                                                                                  style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                    ],
                                                                  ),
                                                                )
                                                              : onProviderOrder.status == ORDER_STATUS_ACCEPTED && onProviderOrder.workerId == ''
                                                                  ? Padding(
                                                                      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                                                      child: Row(
                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                        children: [
                                                                          Expanded(
                                                                            child: ElevatedButton(
                                                                              style: ElevatedButton.styleFrom(
                                                                                elevation: 0.0,
                                                                                backgroundColor: AppColors.colorPrimary,
                                                                                padding: EdgeInsets.all(8),
                                                                                side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                shape: RoundedRectangleBorder(
                                                                                  borderRadius: BorderRadius.all(
                                                                                    Radius.circular(10),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              onPressed: () async {
                                                                                ShowToastDialog.showLoader('Please wait...');
                                                                                onProviderOrder.status = ORDER_STATUS_ASSIGNED;
                                                                                await FireStoreUtils.updateOrder(onProviderOrder);
                                                                                ShowToastDialog.closeLoader();
                                                                              },
                                                                              child: Text(
                                                                                'Assign to Myself'.tr,
                                                                                style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          SizedBox(
                                                                            width: 10,
                                                                          ),
                                                                          Expanded(
                                                                            child: ElevatedButton(
                                                                              style: ElevatedButton.styleFrom(
                                                                                elevation: 0.0,
                                                                                backgroundColor: AppColors.colorWhite,
                                                                                padding: EdgeInsets.all(8),
                                                                                side: BorderSide(color: AppColors.colorWhite, width: 0.4),
                                                                                shape: RoundedRectangleBorder(
                                                                                  borderRadius: BorderRadius.all(
                                                                                    Radius.circular(10),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              onPressed: () async {
                                                                                Get.to(const AssignWorkerList(), arguments: {
                                                                                  "onProviderOrder": onProviderOrder,
                                                                                });
                                                                              },
                                                                              child: Text(
                                                                                'Assign to Worker'.tr,
                                                                                style: TextStyle(color: Colors.black, fontFamily: AppColors.semiBold),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    )
                                                                  : SizedBox(
                                                                      height: 10,
                                                                    ),
                                                ],
                                              ),
                                            )
                                          ])),
                                    );
                                  });
                        },
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FireStoreUtils.firestore
                            .collection(PROVIDER_ORDER)
                            .where("provider.author", isEqualTo: MyAppState.currentUser!.id)
                            .where("status", whereIn: [ORDER_STATUS_REJECTED, ORDER_STATUS_CANCELLED])
                            .orderBy("createdAt", descending: true)
                            .snapshots(),
                        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                          if (snapshot.hasError) {
                            return Center(child: Text('Something went wrong'.tr));
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return loader();
                          }
                          return snapshot.data!.docs.isEmpty
                              ? Center(
                                  child: Text("No cancelled booking found".tr),
                                )
                              : ListView.builder(
                                  itemCount: snapshot.data!.docs.length,
                                  scrollDirection: Axis.vertical,
                                  shrinkWrap: true,
                                  itemBuilder: (context, index) {
                                    OnProviderOrderModel onProviderOrder = OnProviderOrderModel.fromJson(snapshot.data!.docs[index].data() as Map<String, dynamic>);
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
                                    return InkWell(
                                      onTap: () {
                                        Get.to(const BookingDetailsScreen(), arguments: {
                                          "orderId": onProviderOrder.id,
                                        });
                                      },
                                      child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                          margin: const EdgeInsets.only(bottom: 15),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            color: themeChange.getTheme() ? AppColors.darkContainerBorderColor : AppColors.colorWhite,
                                          ),
                                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            const SizedBox(
                                              height: 10,
                                            ),
                                            Row(children: [
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                                child: Container(
                                                    height: 80,
                                                    width: 80,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(10),
                                                      image: onProviderOrder.provider.photos.isNotEmpty
                                                          ? DecorationImage(
                                                              image: NetworkImage(onProviderOrder.provider.photos.first.toString()),
                                                              fit: BoxFit.cover,
                                                            )
                                                          : DecorationImage(
                                                              image: NetworkImage(placeholderImage),
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
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          onProviderOrder.status == ORDER_STATUS_PLACED
                                                              ? Container(
                                                                  decoration: BoxDecoration(
                                                                    borderRadius: BorderRadius.circular(5),
                                                                    color: AppColors.colorLightDeepOrange,
                                                                  ),
                                                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                                                  child: Text(
                                                                    "Pending".tr,
                                                                    style: TextStyle(
                                                                      fontWeight: FontWeight.bold,
                                                                      fontFamily: AppColors.medium,
                                                                      fontSize: 14,
                                                                      color: AppColors.colorDeepOrange,
                                                                    ),
                                                                  ),
                                                                )
                                                              : onProviderOrder.status == ORDER_STATUS_ACCEPTED || onProviderOrder.status == ORDER_STATUS_ASSIGNED
                                                                  ? Container(
                                                                      decoration: BoxDecoration(
                                                                        borderRadius: BorderRadius.circular(5),
                                                                        color: Colors.teal.shade50,
                                                                      ),
                                                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                                                      child: Text(
                                                                        "Accepted".tr,
                                                                        style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, fontSize: 14, color: Colors.teal),
                                                                      ),
                                                                    )
                                                                  : onProviderOrder.status == ORDER_STATUS_REJECTED || onProviderOrder.status == ORDER_STATUS_CANCELLED
                                                                      ? Container(
                                                                          decoration: BoxDecoration(
                                                                            borderRadius: BorderRadius.circular(5),
                                                                            color: Colors.red.shade50,
                                                                          ),
                                                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                                                          child: Text(
                                                                            onProviderOrder.status == ORDER_STATUS_REJECTED ? "Rejected" : "Cancelled".tr,
                                                                            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, fontSize: 14, color: Colors.red),
                                                                          ),
                                                                        )
                                                                      : Container(
                                                                          decoration: BoxDecoration(
                                                                            borderRadius: BorderRadius.circular(5),
                                                                            color: Colors.lightGreen.shade100,
                                                                          ),
                                                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                                                          child: Text(
                                                                            "On Going".tr,
                                                                            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, fontSize: 14, color: Colors.lightGreen),
                                                                          ),
                                                                        )
                                                        ],
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 6),
                                                        child: Text(
                                                          onProviderOrder.provider.title.toString(),
                                                          style: TextStyle(
                                                            color: themeChange.getTheme() ? Colors.white : AppColors.colorDark,
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 6),
                                                        child: Text(
                                                          onProviderOrder.provider.priceUnit == 'Fixed'
                                                              ? amountShow(
                                                                  amount: total.toString(),
                                                                )
                                                              : "${amountShow(
                                                                  amount: total.toString(),
                                                                )}/hr",
                                                          style: TextStyle(
                                                            color: AppColors.colorPrimary,
                                                            fontFamily: AppColors.semiBold,
                                                          ),
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
                                                border: Border.all(color: themeChange.getTheme() ? Colors.grey.shade900 : Colors.grey.shade100, width: 1),
                                                color: themeChange.getTheme() ? Colors.grey.shade900 : AppColors.colorLightGrey,
                                              ),
                                              child: Column(
                                                children: [
                                                  Container(
                                                      padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            "Address  ".tr,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey.shade500,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              onProviderOrder.address!.getFullAddress().toString(),
                                                              overflow: TextOverflow.ellipsis,
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                fontFamily: AppColors.medium,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      )),
                                                  const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                                    child: Divider(
                                                      thickness: 1,
                                                    ),
                                                  ),
                                                  Container(
                                                      padding: const EdgeInsets.only(left: 10, right: 10),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            "Date & Time".tr,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey.shade500,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                          Text(
                                                            DateFormat('dd-MMM-yyyy hh:mm a').format(onProviderOrder.newScheduleDateTime == null
                                                                ? onProviderOrder.scheduleDateTime!.toDate()
                                                                : onProviderOrder.newScheduleDateTime!.toDate()),
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                        ],
                                                      )),
                                                  const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                                    child: Divider(
                                                      thickness: 1,
                                                    ),
                                                  ),
                                                  Container(
                                                      padding: onProviderOrder.workerId == '' ? EdgeInsets.only(left: 10, right: 10, bottom: 10) : EdgeInsets.only(left: 10, right: 10),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text(
                                                            "Customer".tr,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey.shade500,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                          Text(
                                                            onProviderOrder.author.fullName().toString(),
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                              fontFamily: AppColors.medium,
                                                            ),
                                                          ),
                                                        ],
                                                      )),
                                                  onProviderOrder.provider.priceUnit == "Hourly"
                                                      ? Column(
                                                          children: [
                                                            onProviderOrder.startTime == null
                                                                ? SizedBox()
                                                                : Column(
                                                                    children: [
                                                                      const Padding(
                                                                        padding: EdgeInsets.symmetric(horizontal: 10),
                                                                        child: Divider(
                                                                          thickness: 1,
                                                                        ),
                                                                      ),
                                                                      Container(
                                                                          padding: EdgeInsets.only(left: 10, right: 10),
                                                                          child: Row(
                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                            children: [
                                                                              Text(
                                                                                "Start Time".tr,
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: Colors.grey.shade500,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                              Text(
                                                                                DateFormat('dd-MMM-yyyy hh:mm a').format(onProviderOrder.startTime!.toDate()),
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          )),
                                                                    ],
                                                                  ),
                                                            onProviderOrder.endTime == null
                                                                ? SizedBox()
                                                                : Column(
                                                                    children: [
                                                                      const Padding(
                                                                        padding: EdgeInsets.symmetric(horizontal: 10),
                                                                        child: Divider(
                                                                          thickness: 1,
                                                                        ),
                                                                      ),
                                                                      Container(
                                                                          padding: EdgeInsets.only(left: 10, right: 10),
                                                                          child: Row(
                                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                            children: [
                                                                              Text(
                                                                                "End Time".tr,
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: Colors.grey.shade500,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                              Text(
                                                                                onProviderOrder.endTime == null ? "0" : DateFormat('dd-MMM-yyyy hh:mm a').format(onProviderOrder.endTime!.toDate()),
                                                                                style: TextStyle(
                                                                                  fontSize: 14,
                                                                                  color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                                  fontFamily: AppColors.medium,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          )),
                                                                    ],
                                                                  ),
                                                          ],
                                                        )
                                                      : SizedBox(),
                                                  onProviderOrder.workerId != ''
                                                      ? FutureBuilder(
                                                          future: FireStoreUtils.getWorker(onProviderOrder.workerId.toString()),
                                                          builder: (context, snapshot) {
                                                            if (snapshot.connectionState == ConnectionState.waiting) {
                                                              return Center(child: Container());
                                                            } else {
                                                              if (snapshot.hasError) {
                                                                return Center(child: Text('Error: '.tr + '${snapshot.error}'));
                                                              } else {
                                                                User model = snapshot.data!;
                                                                return Column(
                                                                  children: [
                                                                    const Padding(
                                                                      padding: EdgeInsets.symmetric(horizontal: 10),
                                                                      child: Divider(
                                                                        thickness: 1,
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                        padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                                                                        child: Row(
                                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                          children: [
                                                                            Text(
                                                                              "Worker".tr,
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                color: Colors.grey.shade500,
                                                                                fontFamily: AppColors.medium,
                                                                              ),
                                                                            ),
                                                                            Text(
                                                                              model.fullName().toString(),
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                                fontFamily: AppColors.medium,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        )),
                                                                  ],
                                                                );
                                                              }
                                                            }
                                                          })
                                                      : SizedBox(),
                                                  onProviderOrder.payment_method.isNotEmpty
                                                      ? Column(
                                                          children: [
                                                            const Padding(
                                                              padding: EdgeInsets.symmetric(horizontal: 10),
                                                              child: Divider(
                                                                thickness: 1,
                                                              ),
                                                            ),
                                                            Container(
                                                                padding: onProviderOrder.workerId == '' ? EdgeInsets.only(left: 10, right: 10, bottom: 10) : EdgeInsets.only(left: 10, right: 10),
                                                                child: Row(
                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                  children: [
                                                                    Text(
                                                                      "Payment Type".tr,
                                                                      style: TextStyle(
                                                                        fontSize: 14,
                                                                        color: Colors.grey.shade500,
                                                                        fontFamily: AppColors.medium,
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      onProviderOrder.payment_method.toString(),
                                                                      style: TextStyle(
                                                                        fontSize: 14,
                                                                        color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                                        fontFamily: AppColors.medium,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                )),
                                                          ],
                                                        )
                                                      : SizedBox(),
                                                  onProviderOrder.status == ORDER_STATUS_PLACED
                                                      ? Padding(
                                                          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              Expanded(
                                                                child: ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    elevation: 0.0,
                                                                    backgroundColor: AppColors.colorPrimary,
                                                                    padding: EdgeInsets.all(8),
                                                                    side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius: BorderRadius.all(
                                                                        Radius.circular(10),
                                                                      ),
                                                                    ),
                                                                  ),
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
                                                                    showDialog(context: context, builder: (BuildContext context) => acceptDialog(onProviderOrder, themeChange));
                                                                  },
                                                                  child: Text(
                                                                    'Accept'.tr,
                                                                    style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                  ),
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                width: 10,
                                                              ),
                                                              Expanded(
                                                                child: ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    elevation: 0.0,
                                                                    backgroundColor: AppColors.colorWhite,
                                                                    padding: EdgeInsets.all(8),
                                                                    side: BorderSide(color: AppColors.colorWhite, width: 0.4),
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius: BorderRadius.all(
                                                                        Radius.circular(10),
                                                                      ),
                                                                    ),
                                                                  ),
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
                                                                  child: Text(
                                                                    'Decline'.tr,
                                                                    style: TextStyle(color: Colors.black, fontFamily: AppColors.semiBold),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        )
                                                      : onProviderOrder.status == ORDER_STATUS_ASSIGNED && onProviderOrder.workerId == ''
                                                          ? Padding(
                                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                              child: SizedBox(
                                                                width: Responsive.width(70, context),
                                                                child: ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    elevation: 0.0,
                                                                    backgroundColor: AppColors.colorPrimary,
                                                                    padding: EdgeInsets.all(8),
                                                                    side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius: BorderRadius.all(
                                                                        Radius.circular(10),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  onPressed: () async {
                                                                    if (onProviderOrder.newScheduleDateTime!.toDate().isBefore(Timestamp.now().toDate())) {
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
                                                                            message:
                                                                                ('${"You can start booking on".tr} ${DateFormat("EEE dd MMMM , hh:mm a").format(onProviderOrder.newScheduleDateTime!.toDate())}.'),
                                                                            duration: 5.seconds),
                                                                      );
                                                                    }
                                                                  },
                                                                  child: Text(
                                                                    'On Going'.tr,
                                                                    style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                  ),
                                                                ),
                                                              ),
                                                            )
                                                          : onProviderOrder.status == ORDER_STATUS_ONGOING && onProviderOrder.workerId == ''
                                                              ? Padding(
                                                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                                  child: Row(
                                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                    children: [
                                                                      Expanded(
                                                                        child: onProviderOrder.provider.priceUnit == "Hourly" && onProviderOrder.endTime == null
                                                                            ? ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                  elevation: 0.0,
                                                                                  backgroundColor: AppColors.colorPrimary,
                                                                                  padding: EdgeInsets.all(8),
                                                                                  side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                  shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.all(
                                                                                      Radius.circular(10),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                onPressed: () async {
                                                                                  ShowToastDialog.showLoader('Please wait...');
                                                                                  ShowToastDialog.showLoader('Please wait...');
                                                                                  if (onProviderOrder.provider.priceUnit == "Hourly") {
                                                                                    onProviderOrder.endTime = Timestamp.now();
                                                                                    onProviderOrder.paymentStatus = false;
                                                                                    int minutes = onProviderOrder.endTime!.toDate().difference(onProviderOrder.startTime!.toDate()).inMinutes;
                                                                                    onProviderOrder.quantity =
                                                                                        minutes > 60 ? double.parse(durationToString(minutes)) : double.parse(durationToString(60));
                                                                                  }
                                                                                  await FireStoreUtils.updateOrder(onProviderOrder);
                                                                                  Map<String, dynamic> payLoad = <String, dynamic>{"type": "provider_order", "orderId": onProviderOrder.id};
                                                                                  await SendNotification.sendFcmMessage(providerStopTime, onProviderOrder.author.fcmToken, payLoad);
                                                                                  ShowToastDialog.closeLoader();
                                                                                },
                                                                                child: Text(
                                                                                  'Stop Time'.tr,
                                                                                  style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                                ),
                                                                              )
                                                                            : ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                  elevation: 0.0,
                                                                                  backgroundColor: AppColors.colorPrimary,
                                                                                  padding: EdgeInsets.all(8),
                                                                                  side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                  shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.all(
                                                                                      Radius.circular(10),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                onPressed: () async {
                                                                                  if (onProviderOrder.extraPaymentStatus == false ||
                                                                                      (onProviderOrder.paymentStatus == false && onProviderOrder.payment_method != "cod")) {
                                                                                    ShowToastDialog.showToast('Payment is pending.'.tr);
                                                                                  } else {
                                                                                    completePickUp(onProviderOrder);
                                                                                  }
                                                                                },
                                                                                child: Text(
                                                                                  'Complete'.tr,
                                                                                  style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                                ),
                                                                              ),
                                                                      ),
                                                                      SizedBox(
                                                                        width: 10,
                                                                      ),
                                                                      onProviderOrder.extraCharges!.isNotEmpty && onProviderOrder.extraCharges != null
                                                                          ? SizedBox()
                                                                          : Expanded(
                                                                              child: ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                  elevation: 0.0,
                                                                                  backgroundColor: AppColors.colorPrimary,
                                                                                  padding: EdgeInsets.all(8),
                                                                                  side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                  shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.all(
                                                                                      Radius.circular(10),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                onPressed: () async {
                                                                                  BookingDetailsController bookingDetailsController = Get.put(BookingDetailsController());
                                                                                  CommonUI.showAddExtraChargesDialog(context, bookingDetailsController, onProviderOrder);
                                                                                  Get.delete<BookingDetailsController>();
                                                                                },
                                                                                child: Text(
                                                                                  'Add Extra Charges'.tr,
                                                                                  style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                    ],
                                                                  ),
                                                                )
                                                              : onProviderOrder.status == ORDER_STATUS_ACCEPTED && onProviderOrder.workerId == ''
                                                                  ? Padding(
                                                                      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                                                      child: Row(
                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                        children: [
                                                                          Expanded(
                                                                            child: ElevatedButton(
                                                                              style: ElevatedButton.styleFrom(
                                                                                elevation: 0.0,
                                                                                backgroundColor: AppColors.colorPrimary,
                                                                                padding: EdgeInsets.all(8),
                                                                                side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                                shape: RoundedRectangleBorder(
                                                                                  borderRadius: BorderRadius.all(
                                                                                    Radius.circular(10),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              onPressed: () async {
                                                                                ShowToastDialog.showLoader('Please wait...');
                                                                                onProviderOrder.status = ORDER_STATUS_ASSIGNED;
                                                                                await FireStoreUtils.updateOrder(onProviderOrder);
                                                                                ShowToastDialog.closeLoader();
                                                                              },
                                                                              child: Text(
                                                                                'Assign to Myself'.tr,
                                                                                style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          SizedBox(
                                                                            width: 10,
                                                                          ),
                                                                          Expanded(
                                                                            child: ElevatedButton(
                                                                              style: ElevatedButton.styleFrom(
                                                                                elevation: 0.0,
                                                                                backgroundColor: AppColors.colorWhite,
                                                                                padding: EdgeInsets.all(8),
                                                                                side: BorderSide(color: AppColors.colorWhite, width: 0.4),
                                                                                shape: RoundedRectangleBorder(
                                                                                  borderRadius: BorderRadius.all(
                                                                                    Radius.circular(10),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              onPressed: () async {
                                                                                Get.to(const AssignWorkerList(), arguments: {
                                                                                  "onProviderOrder": onProviderOrder,
                                                                                });
                                                                              },
                                                                              child: Text(
                                                                                'Assign to Worker'.tr,
                                                                                style: TextStyle(color: Colors.black, fontFamily: AppColors.semiBold),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    )
                                                                  : SizedBox(),
                                                ],
                                              ),
                                            )
                                          ])),
                                    );
                                  });
                        },
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ));
  }

  DateTime selectedDateTime = DateTime.now();
  TextEditingController dateTimeController = TextEditingController();

  acceptDialog(OnProviderOrderModel onProviderOrder, themeChange) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), //this right here
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "Accept Order",
              style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 10,
            ),
            InkWell(
              onTap: () async {
                BottomPicker.dateTime(
                  onSubmit: (index) {
                    setState(() {
                      selectedDateTime = index;
                      dateTimeController.text = DateFormat('dd-MM-yyyy HH:mm').format(index);
                    });
                  },
                  minDateTime: DateTime.now(),
                  initialDateTime: DateTime.now().isAfter(selectedDateTime) ? DateTime.now() : selectedDateTime,
                  buttonAlignment: MainAxisAlignment.center,
                  displaySubmitButton: true,
                  pickerTitle: Text(''),
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
                style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  errorStyle: const TextStyle(color: Colors.red),
                  hintText: "Choose Date and Time",
                  hintStyle: TextStyle(color: Colors.white),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
              ),
            ),
            Padding(padding: EdgeInsets.only(top: 10.0)),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0.0,
                      backgroundColor: AppColors.colorPrimary,
                      padding: EdgeInsets.all(8),
                      side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(10),
                        ),
                      ),
                    ),
                    onPressed: () async {
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
                    child: Text(
                      'Accept'.tr,
                      style: TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
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

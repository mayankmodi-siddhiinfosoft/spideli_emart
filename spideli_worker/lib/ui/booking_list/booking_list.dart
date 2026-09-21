import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/controller/booking_details_controller.dart';
import 'package:spideliworker/main.dart';
import 'package:spideliworker/model/onprovider_order_model.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/services/send_notification.dart';
import 'package:spideliworker/themes/app_colors.dart';
import 'package:spideliworker/themes/responsive.dart';
import 'package:spideliworker/ui/booking_list/booking_details_screen.dart';
import 'package:spideliworker/ui/booking_list/verify_otp_screen.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:spideliworker/widgets/common_ui.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
            "Booking List".tr,
            style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontSize: 18, fontFamily: AppColors.semiBold),
          ),
          isBack: false,
        ),
        body: DefaultTabController(
          length: 2,
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
                    Tab(
                        child: Text(
                      "Upcoming".tr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    )),
                    Tab(
                        child: Text(
                      "Complete".tr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    )),
                  ],
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TabBarView(
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: FireStoreUtils.firestore
                            .collection(PROVIDER_ORDER)
                            .where("workerId", isEqualTo: MyAppState.currentUser!.id.toString())
                            .where("status", whereIn: [ORDER_STATUS_ACCEPTED, ORDER_STATUS_ASSIGNED, ORDER_STATUS_ONGOING])
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
                                                                    style: const TextStyle(
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
                                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, fontSize: 14, color: Colors.teal),
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
                                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, fontSize: 14, color: Colors.lightGreen),
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
                                                      padding: const EdgeInsets.only(left: 10, right: 10),
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
                                                                ? const SizedBox()
                                                                : Column(
                                                                    children: [
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
                                                                ? const SizedBox()
                                                                : Column(
                                                                    children: [
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
                                                      : const SizedBox(),
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
                                                                padding: const EdgeInsets.only(left: 10, right: 10),
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
                                                      : const SizedBox(),
                                                  onProviderOrder.status == ORDER_STATUS_ASSIGNED
                                                      ? Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                          child: SizedBox(
                                                            width: Responsive.width(70, context),
                                                            child: ElevatedButton(
                                                              style: ElevatedButton.styleFrom(
                                                                elevation: 0.0,
                                                                backgroundColor: AppColors.colorPrimary,
                                                                padding: const EdgeInsets.all(8),
                                                                side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                shape: const RoundedRectangleBorder(
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
                                                                style: const TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                              ),
                                                            ),
                                                          ),
                                                        )
                                                      : onProviderOrder.status == ORDER_STATUS_ONGOING
                                                          ? Padding(
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                              child: Row(
                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                children: [
                                                                  Expanded(
                                                                    child: onProviderOrder.provider.priceUnit == "Hourly" && onProviderOrder.endTime == null
                                                                        ? ElevatedButton(
                                                                            style: ElevatedButton.styleFrom(
                                                                              elevation: 0.0,
                                                                              backgroundColor: AppColors.colorPrimary,
                                                                              padding: const EdgeInsets.all(8),
                                                                              side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                              shape: const RoundedRectangleBorder(
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
                                                                                onProviderOrder.quantity = minutes > 60 ? double.parse(durationToString(minutes)) : double.parse(durationToString(60));
                                                                              }
                                                                              await FireStoreUtils.updateOrder(onProviderOrder);
                                                                              Map<String, dynamic> payLoad = <String, dynamic>{"type": "provider_order", "orderId": onProviderOrder.id};
                                                                              await SendNotification.sendFcmMessage(providerStopTime, onProviderOrder.author.fcmToken, payLoad);
                                                                              ShowToastDialog.closeLoader();
                                                                            },
                                                                            child: Text(
                                                                              'Stop Time'.tr,
                                                                              style: const TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                            ),
                                                                          )
                                                                        : ElevatedButton(
                                                                            style: ElevatedButton.styleFrom(
                                                                              elevation: 0.0,
                                                                              backgroundColor: AppColors.colorPrimary,
                                                                              padding: const EdgeInsets.all(8),
                                                                              side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                              shape: const RoundedRectangleBorder(
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
                                                                              style: const TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                            ),
                                                                          ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 10,
                                                                  ),
                                                                  onProviderOrder.extraCharges!.isNotEmpty && onProviderOrder.extraCharges != null
                                                                      ? const SizedBox()
                                                                      : Expanded(
                                                                          child: ElevatedButton(
                                                                            style: ElevatedButton.styleFrom(
                                                                              elevation: 0.0,
                                                                              backgroundColor: AppColors.colorPrimary,
                                                                              padding: const EdgeInsets.all(8),
                                                                              side: BorderSide(color: AppColors.colorPrimary, width: 0.4),
                                                                              shape: const RoundedRectangleBorder(
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
                                                                              style: const TextStyle(color: AppColors.colorWhite, fontFamily: AppColors.semiBold),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                ],
                                                              ),
                                                            )
                                                          : const SizedBox(),
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
                            .where("workerId", isEqualTo: MyAppState.currentUser!.id.toString())
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
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Container(
                                                            decoration: BoxDecoration(
                                                              borderRadius: BorderRadius.circular(5),
                                                              color: Colors.lightGreen.shade100,
                                                            ),
                                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                                            child: Text(
                                                              "Completed".tr,
                                                              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: AppColors.medium, fontSize: 14, color: Colors.lightGreen),
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
                                                      padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
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
                                                                ? const SizedBox()
                                                                : Column(
                                                                    children: [
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
                                                                ? const SizedBox()
                                                                : Column(
                                                                    children: [
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
                                                      : const SizedBox(),
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

  Future<void> completePickUp(OnProviderOrderModel onProviderOrder) async {
    final isComplete = await Navigator.of(Get.context!).push(MaterialPageRoute(
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

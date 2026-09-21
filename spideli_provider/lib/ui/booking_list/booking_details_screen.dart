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
import 'package:spideliprovider/services/send_notification.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/responsive.dart';
import 'package:spideliprovider/ui/booking_list/assign_worker_list.dart';
import 'package:spideliprovider/ui/booking_list/verify_otp_screen.dart';
import 'package:spideliprovider/ui/chat_screen/chat_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/widgets/common_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          return Scaffold(
              backgroundColor: themeChange.getTheme() ? AppColors.DARK_BG_COLOR : const Color(0xffF9F9F9),
              appBar: CommonUI.customAppBar(context,
                  title: Text(
                    'Booking Summary'.tr,
                    style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontSize: 18, fontFamily: AppColors.semiBold),
                  ),
                  isBack: true),
              body: controller.orderId.value.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: StreamBuilder(
                          stream: FireStoreUtils.firestore.collection(PROVIDER_ORDER).doc(controller.orderId.value).snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(child: Text('Something went wrong'.tr));
                            }

                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return loader();
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

                            return SingleChildScrollView(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 15),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Text(
                                      'Booking ID'.tr,
                                      style: TextStyle(color: AppColors.colorGrey500),
                                    ),
                                    InkWell(
                                      onTap: () async {
                                        await Clipboard.setData(ClipboardData(text: "${onProviderOrder.id}")).then((value) {
                                          ShowToastDialog.showToast("Booking ID Copied");
                                        });
                                      },
                                      child: Text(
                                        '# ${onProviderOrder.id}',
                                        style: TextStyle(color: AppColors.colorPrimary),
                                      ),
                                    ),
                                  ]),
                                ),
                                const Divider(
                                  color: AppColors.colorDivider,
                                ),
                                Row(children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.only(top: 6),
                                          child: Text(
                                            onProviderOrder.provider.title.toString(),
                                            style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.semiBold),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(top: 6),
                                              child: Text(
                                                'Date: '.tr,
                                                style: TextStyle(fontSize: 14, color: AppColors.colorGrey500, fontFamily: AppColors.medium),
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsets.only(top: 6),
                                              child: Text(
                                                DateFormat('dd-MMM-yyyy')
                                                    .format(onProviderOrder.newScheduleDateTime == null ? onProviderOrder.scheduleDateTime!.toDate() : onProviderOrder.newScheduleDateTime!.toDate()),
                                                style: TextStyle(fontSize: 14, fontFamily: AppColors.medium, color: themeChange.getTheme() ? Colors.white : Colors.black),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(top: 6),
                                              child: Text(
                                                'Time: '.tr,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: AppColors.colorGrey500,
                                                  fontFamily: AppColors.medium,
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsets.only(top: 6),
                                              child: Text(
                                                DateFormat('hh:mm a')
                                                    .format(onProviderOrder.newScheduleDateTime == null ? onProviderOrder.scheduleDateTime!.toDate() : onProviderOrder.newScheduleDateTime!.toDate()),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                  fontFamily: AppColors.medium,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(6.0),
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
                                ]),
                                (onProviderOrder.status == ORDER_STATUS_ACCEPTED ||
                                            onProviderOrder.status == ORDER_STATUS_ASSIGNED ||
                                            onProviderOrder.status == ORDER_STATUS_ONGOING ||
                                            onProviderOrder.status == ORDER_STATUS_COMPLETED) &&
                                        onProviderOrder.workerId != ''
                                    ? Padding(
                                        padding: EdgeInsets.only(top: 6),
                                        child: FutureBuilder(
                                            future: FireStoreUtils.getWorker(onProviderOrder.workerId.toString()),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.waiting) {
                                                return Center(child: Container());
                                              } else {
                                                if (snapshot.hasError) {
                                                  return Center(child: Text('Error: '.tr + '${snapshot.error}'));
                                                } else if (snapshot.hasData) {
                                                  controller.worker.value = snapshot.data!;
                                                  return Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Divider(
                                                        color: AppColors.colorDivider,
                                                      ),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            'About Worker'.tr,
                                                            style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontFamily: AppColors.bold),
                                                          ),
                                                        ],
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              color: themeChange.getTheme() ? AppColors.darkContainerBorderColor : AppColors.colorWhite,
                                                              borderRadius: const BorderRadius.only(
                                                                  topLeft: Radius.circular(10), topRight: Radius.circular(10), bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
                                                            ),
                                                            child: Padding(
                                                              padding: const EdgeInsets.all(8.0),
                                                              child: Row(
                                                                mainAxisAlignment: MainAxisAlignment.start,
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  controller.worker.value.profilePictureURL != ""
                                                                      ? CircleAvatar(backgroundImage: NetworkImage(controller.worker.value.profilePictureURL.toString()), radius: 30.0)
                                                                      : CircleAvatar(backgroundImage: NetworkImage(placeholderImage), radius: 30.0),
                                                                  SizedBox(
                                                                    width: 10,
                                                                  ),
                                                                  Expanded(
                                                                    child: Column(
                                                                      mainAxisAlignment: MainAxisAlignment.start,
                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                      children: [
                                                                        Row(
                                                                          mainAxisAlignment: MainAxisAlignment.start,
                                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                                          children: [
                                                                            Expanded(
                                                                              child: Text(
                                                                                controller.worker.value.fullName().toString(),
                                                                                style: TextStyle(
                                                                                    color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.semiBold, fontSize: 14),
                                                                              ),
                                                                            ),
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                const Icon(
                                                                                  Icons.star,
                                                                                  size: 16,
                                                                                  color: AppColors.colorDeepOrange,
                                                                                ),
                                                                                const SizedBox(width: 3),
                                                                                Text(
                                                                                    controller.worker.value.reviewsCount != 0
                                                                                        ? (controller.worker.value.reviewsSum / controller.worker.value.reviewsCount).toStringAsFixed(1)
                                                                                        : 0.toString(),
                                                                                    style: const TextStyle(
                                                                                      letterSpacing: 0.5,
                                                                                      fontSize: 12,
                                                                                      fontFamily: AppColors.medium,
                                                                                      fontWeight: FontWeight.w500,
                                                                                      color: AppColors.colorDeepOrange,
                                                                                    )),
                                                                              ],
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        Padding(
                                                                          padding: EdgeInsets.symmetric(vertical: 5),
                                                                          child: Row(
                                                                            mainAxisAlignment: MainAxisAlignment.start,
                                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                            children: [
                                                                              Icon(Icons.location_on_outlined, size: 14, color: themeChange.getTheme() ? Colors.white : Colors.black),
                                                                              SizedBox(
                                                                                width: 5,
                                                                              ),
                                                                              Container(
                                                                                width: Responsive.width(60, context),
                                                                                child: Text(
                                                                                  controller.worker.value.address!.toString(),
                                                                                  maxLines: 5,
                                                                                  style: TextStyle(
                                                                                      color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.regular, fontSize: 14),
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                } else {
                                                  return Container();
                                                }
                                              }
                                            }),
                                      )
                                    : SizedBox(),
                                const Divider(
                                  color: AppColors.colorDivider,
                                ),
                                Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'About Customer'.tr,
                                        style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontFamily: AppColors.bold),
                                      ),
                                      onProviderOrder.status == ORDER_STATUS_ACCEPTED
                                          ? Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                InkWell(
                                                  onTap: () async {
                                                    final directions = MapLauncher.directions(
                                                      LocationCoords(onProviderOrder.address!.location!.latitude, onProviderOrder.address!.location!.longitude,
                                                          title: onProviderOrder.address!.locality),
                                                      mode: TravelMode.driving,
                                                    );
                                                    // map_launcher 6: isMapAvailable() replaced by getSupportedMaps(); isInstalled keeps the old "app installed" check.
                                                    final maps = await directions.getSupportedMaps(const [MapApp.google]);
                                                    if (maps.any((m) => m.isInstalled)) {
                                                      await directions.show(map: MapApp.google);
                                                    } else {
                                                      ShowToastDialog.showToast("Google map is not installed".tr);
                                                    }
                                                  },
                                                  child: Text(
                                                    'Get Direction'.tr,
                                                    style: TextStyle(color: AppColors.colorPrimary, fontFamily: AppColors.bold),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : SizedBox(),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: themeChange.getTheme() ? AppColors.darkContainerBorderColor : AppColors.colorWhite,
                                      borderRadius:
                                          const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10), bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              onProviderOrder.author.profilePictureURL != ""
                                                  ? CircleAvatar(backgroundColor: Colors.amber, backgroundImage: NetworkImage(onProviderOrder.author.profilePictureURL.toString()), radius: 30.0)
                                                  : CircleAvatar(backgroundColor: Colors.amber, backgroundImage: NetworkImage(placeholderImage), radius: 30.0),
                                              SizedBox(
                                                width: 10,
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      onProviderOrder.author.fullName().toString(),
                                                      style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.semiBold, fontSize: 14),
                                                    ),
                                                    Padding(
                                                      padding: EdgeInsets.symmetric(vertical: 5),
                                                      child: Row(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Icon(Icons.location_on_outlined, size: 15, color: themeChange.getTheme() ? Colors.white : Colors.black),
                                                          SizedBox(
                                                            width: 5,
                                                          ),
                                                          Container(
                                                            width: Responsive.width(60, context),
                                                            child: Text(
                                                              onProviderOrder.address!.getFullAddress().toString(),
                                                              maxLines: 5,
                                                              style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.regular, fontSize: 14),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          onProviderOrder.status == ORDER_STATUS_ACCEPTED || onProviderOrder.status == ORDER_STATUS_ONGOING || onProviderOrder.status == ORDER_STATUS_ASSIGNED
                                              ? Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                                  child: Column(
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Expanded(
                                                            child: ElevatedButton.icon(
                                                              icon: const Icon(
                                                                Icons.call,
                                                                color: Colors.white,
                                                              ),
                                                              onPressed: () async {
                                                                makePhoneCall(onProviderOrder.author.phoneNumber.toString());
                                                              },
                                                              label: Text(
                                                                "Call",
                                                                style: TextStyle(fontSize: 16, color: Colors.white, fontFamily: AppColors.medium),
                                                              ),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: AppColors.colorPrimary,
                                                                //fixedSize: const Size(208, 43),
                                                              ),
                                                            ),
                                                          ),
                                                          if ((isSubscriptionModelApplied == false && selectedSectionModel?.adminCommision?.enable == false) ||
                                                              ((isSubscriptionModelApplied == true || selectedSectionModel?.adminCommision?.enable == true) &&
                                                                  MyAppState.currentUser?.subscriptionPlan?.features?.chat == true))
                                                            const SizedBox(
                                                              width: 10,
                                                            ),
                                                          if ((isSubscriptionModelApplied == false && selectedSectionModel?.adminCommision?.enable == false) ||
                                                              ((isSubscriptionModelApplied == true || selectedSectionModel?.adminCommision?.enable == true) &&
                                                                  MyAppState.currentUser?.subscriptionPlan?.features?.chat == true))
                                                            Expanded(
                                                              child: ElevatedButton.icon(
                                                                icon: Icon(Icons.chat, color: themeChange.getTheme() ? Colors.white : Colors.black),
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
                                                                label: Text(
                                                                  "Chat".tr,
                                                                  style: TextStyle(fontSize: 16, color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.medium),
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : SizedBox()
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Text("Price Detail".tr,
                                      style: TextStyle(
                                          color: themeChange.getTheme()
                                              ? Colors.white
                                              : themeChange.getTheme()
                                                  ? Colors.white
                                                  : Colors.black,
                                          fontFamily: AppColors.bold)),
                                ),
                                priceTotalRow(controller, onProviderOrder, context),
                                onProviderOrder.extraCharges.toString() != ""
                                    ? Container(
                                        margin: EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          color: themeChange.getTheme() ? AppColors.darkContainerBorderColor : AppColors.colorWhite,
                                          boxShadow: [
                                            themeChange.getTheme()
                                                ? const BoxShadow()
                                                : BoxShadow(
                                                    color: Colors.grey.withOpacity(0.5),
                                                    blurRadius: 5,
                                                  ),
                                          ],
                                        ),
                                        child: Container(
                                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                            child: Column(
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      "Total Extra Charges : ",
                                                      style: TextStyle(
                                                        color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                        fontFamily: "Poppinsm",
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    Text(
                                                      amountShow(amount: onProviderOrder.extraCharges.toString()),
                                                      style: TextStyle(
                                                        color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                        fontFamily: "Poppinsm",
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(
                                                  height: 5,
                                                ),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        "Extra charge Notes : ",
                                                        style: TextStyle(
                                                          color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                          fontFamily: "Poppinsm",
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      onProviderOrder.extraChargesDescription.toString(),
                                                      style: TextStyle(
                                                        color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                        fontFamily: "Poppinsm",
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            )),
                                      )
                                    : SizedBox(),
                                const SizedBox(
                                  height: 10,
                                ),
                                onProviderOrder.reason!.isEmpty || onProviderOrder.reason == null
                                    ? SizedBox()
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: themeChange.getTheme() ? AppColors.darkContainerBorderColor : AppColors.colorWhite,
                                          borderRadius:
                                              const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10), bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      "Cancelled reason".tr,
                                                      style: TextStyle(fontSize: 14),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(
                                                height: 10,
                                              ),
                                              Text(
                                                "${onProviderOrder.reason.toString()}",
                                                style: TextStyle(color: Colors.red),
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                if (onProviderOrder.adminCommission != '0' && onProviderOrder.adminCommissionType != 'fixed')
                                  const SizedBox(
                                    height: 10,
                                  ),
                                if (onProviderOrder.adminCommission != '0' && onProviderOrder.adminCommissionType != 'fixed')
                                  Container(
                                    decoration: BoxDecoration(
                                      color: themeChange.getTheme() ? AppColors.darkContainerBorderColor : AppColors.colorWhite,
                                      borderRadius:
                                          const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10), bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  "Admin commission".tr,
                                                  style: TextStyle(fontSize: 14),
                                                ),
                                              ),
                                              Text(
                                                "(-${amountShow(amount: controller.adminComm.value.toString())})",
                                                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red, fontSize: 14),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(
                                            height: 10,
                                          ),
                                          Text(
                                            "Note : Admin commission will be debited from your wallet balance. \nAdmin commission will apply on order Amount minus Discount(if applicable).".tr,
                                            style: TextStyle(color: Colors.red),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                const SizedBox(
                                  height: 10,
                                ),
                                controller.ratingService.isEmpty
                                    ? SizedBox()
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.symmetric(vertical: 16),
                                            child: Text("Reviews (${controller.ratingService.length})",
                                                style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontFamily: AppColors.bold)),
                                          ),
                                          reviewTabViewWidget(controller),
                                        ],
                                      ),
                                const SizedBox(
                                  height: 10,
                                ),
                                onProviderOrder.status == ORDER_STATUS_CANCELLED
                                    ? SizedBox()
                                    : Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        child: onProviderOrder.status == ORDER_STATUS_PLACED
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
                                                          controller.dateTimeController.value = TextEditingController();
                                                          controller.selectedDateTime.value = onProviderOrder.scheduleDateTime!.toDate();
                                                          controller.dateTimeController.value.text = DateFormat('dd-MM-yyyy HH:mm').format(onProviderOrder.scheduleDateTime!.toDate());
                                                          showDialog(
                                                              context: context,
                                                              builder: (BuildContext context) =>
                                                                  acceptDialog(context: context, controller: controller, onProviderOrder: onProviderOrder, themeChange: themeChange));
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
                                      ),
                              ]),
                            );
                          }),
                    )
                  : Container());
        });
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
              return Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14.0), border: Border.all(color: Colors.grey.withOpacity(0.30), width: 2.0)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(controller.ratingService[index].uname.toString(), style: const TextStyle(fontSize: 16, letterSpacing: 1, fontWeight: FontWeight.w600)),
                              Text(
                                DateFormat('dd MMM').format(controller.ratingService[index].createdAt!.toDate()),
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          RatingBar.builder(
                            ignoreGestures: true,
                            initialRating: double.parse(controller.ratingService[index].rating.toString()),
                            direction: Axis.horizontal,
                            itemSize: 20,
                            itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                            itemBuilder: (context, _) => Icon(
                              Icons.star,
                              color: AppColors.colorPrimary,
                            ),
                            onRatingUpdate: (double rate) {},
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(
                        height: 5,
                      ),
                      Text(controller.ratingService[index].comment.toString()),
                    ],
                  ),
                ),
              );
            },
          );
  }

  Widget priceTotalRow(BookingDetailsController controller, OnProviderOrderModel onProviderOrder, context) {
    controller.price.value = 0.0;
    controller.discount.value = 0.0;
    controller.totalAmount.value = 0.0;
    controller.adminComm.value = 0.0;

    // if (onProviderOrder.provider.disPrice == "" ||
    //     onProviderOrder.provider.disPrice == "0") {
    //   controller.price.value =
    //       double.parse(onProviderOrder.provider.price.toString()) *
    //           onProviderOrder.quantity;
    // } else {
    //   controller.price.value =
    //       double.parse(onProviderOrder.provider.disPrice.toString()) *
    //           onProviderOrder.quantity;
    // }
    // if (onProviderOrder.discountType == 'Percentage' ||
    //     onProviderOrder.discountType == 'Percent') {
    //   controller.discount.value = controller.price.value *
    //       double.parse(onProviderOrder.discountLabel.toString()) /
    //       100;
    // } else {
    //   controller.discount.value = double.parse(
    //       onProviderOrder.discountLabel!.isEmpty
    //           ? "0.0"
    //           : onProviderOrder.discountLabel.toString());
    // }
    //
    // controller.subTotal.value =
    //     controller.price.value - controller.discount.value;
    //
    // controller.totalAmount.value = controller.subTotal.value;
    //
    // print("======>");
    // print("${onProviderOrder.adminCommissionType}");
    // print("${onProviderOrder.adminCommission}");
    //
    // controller.adminComm.value =
    //     (onProviderOrder.adminCommissionType!.toLowerCase() == 'percentage')
    //         ? (controller.totalAmount.value *
    //                 double.parse(onProviderOrder.adminCommission!)) /
    //             100
    //         : double.parse(onProviderOrder.adminCommission!);

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

    final themeChange = Provider.of<DarkThemeProvider>(context);
    return Container(
      decoration: BoxDecoration(
        color: themeChange.getTheme() ? AppColors.darkContainerBorderColor : AppColors.colorWhite,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10), bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
      ),
      child: Column(
        children: [
          Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Price".tr,
                    style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.medium),
                  ),
                  Row(
                    children: [
                      Text(
                        (onProviderOrder.provider.disPrice == "" || onProviderOrder.provider.disPrice == "0")
                            ? '${amountShow(amount: onProviderOrder.adminCommission ?? '0')} × ${onProviderOrder.quantity.toStringAsFixed(2)}'
                            : '${amountShow(amount: onProviderOrder.provider.disPrice.toString())} × ${onProviderOrder.quantity.toStringAsFixed(2)}',
                        style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.regular),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        amountShow(amount: controller.price.toString()),
                        style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.medium),
                      ),
                    ],
                  ),
                ],
              )),
          controller.discount.value != 0
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Divider(),
                )
              : SizedBox(),
          controller.discount.value != 0
              ? Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Discount".tr,
                            style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.medium),
                          ),
                          // Text(
                          //   "(${controller.onProviderOrder.value.provider.disPrice}% off)",
                          //   style: TextStyle( color: Colors.green, fontFamily: AppColors.medium),
                          // ),
                        ],
                      ),
                      Text(
                        '(- ${amountShow(amount: controller.discount.value.toString())})',
                        style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.medium),
                      ),
                    ],
                  ))
              : SizedBox(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Divider(),
          ),
          Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "SubTotal".tr,
                    style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.medium),
                  ),
                  Text(
                    amountShow(amount: controller.subTotal.toString()),
                    style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.medium),
                  ),
                ],
              )),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Divider(),
          ),
          ListView.builder(
            itemCount: onProviderOrder.taxModel!.length,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              TaxModel taxModel = onProviderOrder.taxModel![index];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "${taxModel.title.toString()} (${taxModel.type == "fix" ? amountShow(amount: taxModel.tax) : "${taxModel.tax}%"})",
                            style: TextStyle(
                              fontFamily: AppColors.medium,
                              color: themeChange.getTheme() ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        Text(
                          amountShow(amount: getTaxValue(amount: (double.parse(controller.subTotal.toString())).toString(), taxModel: taxModel).toString()),
                          style: TextStyle(fontFamily: AppColors.medium, color: themeChange.getTheme() ? Colors.white : Colors.black, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Divider(),
                  ),
                ],
              );
            },
          ),
          onProviderOrder.notes!.isNotEmpty
              ? Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Remarks".tr,
                        style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.medium),
                      ),
                      InkWell(
                        onTap: () {
                          viewNotesheet(onProviderOrder.notes ?? "", themeChange, context);
                        },
                        child: Text(
                          "View".tr,
                          style: TextStyle(color: AppColors.colorPrimary, fontFamily: AppColors.medium),
                        ),
                      ),
                    ],
                  ))
              : Container(),
          Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total Amount".tr,
                    style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.medium),
                  ),
                  Text(
                    amountShow(amount: controller.totalAmount.toString()),
                    style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.medium),
                  ),
                ],
              )),
          SizedBox(
            height: 5,
          )
        ],
      ),
    );
  }

  void viewNotesheet(String notes, themeChange, context) {
    Get.bottomSheet(
      SizedBox(
        height: Responsive.height(20, context),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    'Remark'.tr,
                    style: TextStyle(color: themeChange.getTheme() ? Colors.white70 : Colors.black, fontSize: 16),
                  )),
              Container(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    color: const Color(0XFFF1F4F7),
                    alignment: Alignment.center,
                    child: Text(
                      notes,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: themeChange.getTheme() ? Colors.grey.shade500 : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: themeChange.getTheme() ? AppColors.colorDark : AppColors.colorWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  acceptDialog({required BuildContext context, required BookingDetailsController controller, required OnProviderOrderModel onProviderOrder, themeChange}) {
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
                decoration: InputDecoration(
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  errorStyle: const TextStyle(color: Colors.red),
                  fillColor: Colors.white,
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

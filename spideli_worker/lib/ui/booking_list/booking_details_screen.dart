import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/controller/booking_details_controller.dart';
import 'package:spideliworker/model/onprovider_order_model.dart';
import 'package:spideliworker/model/tax_model.dart';
import 'package:spideliworker/model/user.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/themes/app_colors.dart';
import 'package:spideliworker/ui/booking_list/job_actions.dart';
import 'package:spideliworker/ui/chat_screen/full_screen_image_viewer.dart';
import 'package:spideliworker/utils/region_service.dart';
import 'package:spideliworker/widgets/network_image_widget.dart';
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

import '../../themes/responsive.dart';

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
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Text(
                                      'Booking ID'.tr,
                                      style: const TextStyle(color: AppColors.colorGrey500),
                                    ),
                                    InkWell(
                                      onTap: () async {
                                        await Clipboard.setData(ClipboardData(text: onProviderOrder.id)).then((value) {
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
                                          padding: const EdgeInsets.only(top: 6),
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
                                                style: const TextStyle(fontSize: 14, color: AppColors.colorGrey500, fontFamily: AppColors.medium),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(top: 6),
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
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: AppColors.colorGrey500,
                                                  fontFamily: AppColors.medium,
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(top: 6),
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
                                const Divider(
                                  color: AppColors.colorDivider,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
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
                                                    // map_launcher 6: getSupportedMaps also returns browser-only maps, so check isInstalled to keep the old "installed" check.
                                                    final supportedMaps = await directions.getSupportedMaps(const [GoogleMaps()]);
                                                    bool isAvailable = supportedMaps.any((map) => map.isInstalled);
                                                    if (isAvailable == true) {
                                                      await directions.show(map: const GoogleMaps());
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
                                          : const SizedBox(),
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
                                              const SizedBox(
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
                                                      padding: const EdgeInsets.symmetric(vertical: 5),
                                                      child: Row(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Icon(Icons.location_on_outlined, size: 15, color: themeChange.getTheme() ? Colors.white : Colors.black),
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                          SizedBox(
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
                                                              label: const Text(
                                                                "Call",
                                                                style: TextStyle(fontSize: 16, color: Colors.white, fontFamily: AppColors.medium),
                                                              ),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: AppColors.colorPrimary,
                                                                //fixedSize: const Size(208, 43),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          Expanded(
                                                            child: ElevatedButton.icon(
                                                              icon: Icon(Icons.chat, color: themeChange.getTheme() ? Colors.white : Colors.black),
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
                                              : const SizedBox(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
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
                                        margin: const EdgeInsets.symmetric(vertical: 10),
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
                                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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
                                                      amountShow(currency: RegionService.currencyForRegion(onProviderOrder.regionId), amount: onProviderOrder.extraCharges.toString()),
                                                      style: TextStyle(
                                                        color: themeChange.getTheme() ? Colors.white : Colors.black,
                                                        fontFamily: "Poppinsm",
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(
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
                                    : const SizedBox(),
                                const SizedBox(
                                  height: 10,
                                ),
                                onProviderOrder.reason!.isEmpty || onProviderOrder.reason == null
                                    ? const SizedBox()
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
                                                      style: const TextStyle(fontSize: 14),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(
                                                height: 10,
                                              ),
                                              Text(
                                                onProviderOrder.reason.toString(),
                                                style: const TextStyle(color: Colors.red),
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                const SizedBox(
                                  height: 10,
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                                controller.ratingService.isEmpty
                                    ? const SizedBox()
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            child: Text("Reviews (${controller.ratingService.length})",
                                                style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontFamily: AppColors.bold)),
                                          ),
                                          reviewTabViewWidget(controller),
                                        ],
                                      ),
                                const SizedBox(
                                  height: 10,
                                ),
                                completionPhotosWidget(onProviderOrder, themeChange.getTheme()),
                                onProviderOrder.status == ORDER_STATUS_CANCELLED ? const SizedBox() : jobActionsWidget(context, onProviderOrder),
                              ]),
                            );
                          }),
                    )
                  : Container());
        });
  }

  Widget reviewTabViewWidget(BookingDetailsController controller) {
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
                                style: const TextStyle(fontSize: 14),
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

  Widget priceTotalRow(BookingDetailsController controller, onProviderOrder, context) {
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
    //
    // if (onProviderOrder.discountType == 'Percentage' ||
    //     onProviderOrder.discountType == 'Percent') {
    //   controller.discount.value = controller.price.value *
    //       double.parse(onProviderOrder.discountLabel.toString()) /
    //       100;
    // } else {
    //   controller.discount.value =
    //       double.parse(onProviderOrder.discountLabel.toString());
    // }
    //
    // controller.subTotal.value =
    //     controller.price.value - controller.discount.value;
    //
    // controller.totalAmount.value = controller.subTotal.value;
    //
    // controller.adminComm.value =
    //     (onProviderOrder.adminCommissionType == 'Percent')
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Container(
        decoration: BoxDecoration(
          color: themeChange.getTheme() ? Colors.grey.shade900 : AppColors.colorLightGrey,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10), bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10)),
        ),
        child: Column(
          children: [
            Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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
                              ? '${amountShow(currency: RegionService.currencyForRegion(onProviderOrder.regionId), amount: onProviderOrder.provider.price.toString())} × ${onProviderOrder.quantity}'
                              : '${amountShow(currency: RegionService.currencyForRegion(onProviderOrder.regionId), amount: onProviderOrder.provider.disPrice.toString())} × ${onProviderOrder.quantity}',
                          style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.regular),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Text(
                          amountShow(currency: RegionService.currencyForRegion(onProviderOrder.regionId), amount: controller.price.toString()),
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
                : const SizedBox(),
            controller.discount.value != 0
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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
                          '(- ${amountShow(currency: RegionService.currencyForRegion(onProviderOrder.regionId), amount: controller.discount.value.toString())})',
                          style: const TextStyle(color: Colors.green, fontFamily: AppColors.medium),
                        ),
                      ],
                    ))
                : const SizedBox(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Divider(),
            ),
            Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "SubTotal".tr,
                      style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.medium),
                    ),
                    Text(
                      amountShow(currency: RegionService.currencyForRegion(onProviderOrder.regionId), amount: controller.subTotal.toString()),
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
              physics: const NeverScrollableScrollPhysics(),
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
                              "${taxModel.title.toString()} (${taxModel.type == "fix" ? amountShow(currency: RegionService.currencyForRegion(onProviderOrder.regionId), amount: taxModel.tax) : "${taxModel.tax}%"})",
                              style: TextStyle(fontFamily: AppColors.medium, color: themeChange.getTheme() ? Colors.white : Colors.black),
                            ),
                          ),
                          Text(
                            amountShow(currency: RegionService.currencyForRegion(onProviderOrder.regionId), amount: getTaxValue(amount: (double.parse(controller.subTotal.toString())).toString(), taxModel: taxModel).toString()),
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
            onProviderOrder.notes.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Remarks".tr,
                          style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.medium),
                        ),
                        InkWell(
                          onTap: () {
                            viewNotesheet(onProviderOrder.notes, themeChange, context);
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
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total Amount".tr,
                      style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.medium),
                    ),
                    Text(
                      amountShow(currency: RegionService.currencyForRegion(onProviderOrder.regionId), amount: controller.totalAmount.toString()),
                      style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontFamily: AppColors.medium),
                    ),
                  ],
                )),
            const SizedBox(
              height: 5,
            )
          ],
        ),
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

  /// Photos attached by the worker when completing the job.
  Widget completionPhotosWidget(OnProviderOrderModel onProviderOrder, bool dark) {
    if (onProviderOrder.completionPhotos.isEmpty && onProviderOrder.completionSignature == null) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text("Completion photos".tr, style: TextStyle(color: dark ? Colors.white : AppColors.colorDark, fontFamily: AppColors.bold)),
        ),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: onProviderOrder.completionPhotos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) => InkWell(
              onTap: () => Get.to(() => FullScreenImageViewer(imageUrl: onProviderOrder.completionPhotos[index])),
              child: NetworkImageWidget(imageUrl: onProviderOrder.completionPhotos[index], height: 90, width: 90, fit: BoxFit.cover, borderRadius: 8),
            ),
          ),
        ),
        if (onProviderOrder.completionSignature != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text("Customer signature".tr, style: TextStyle(color: dark ? Colors.white : AppColors.colorDark, fontFamily: AppColors.bold)),
          ),
          InkWell(
            onTap: () => Get.to(() => FullScreenImageViewer(imageUrl: onProviderOrder.completionSignature!)),
            child: Container(
              color: Colors.white,
              child: NetworkImageWidget(imageUrl: onProviderOrder.completionSignature!, height: 90, width: 180, fit: BoxFit.contain, borderRadius: 8),
            ),
          ),
        ],
      ],
    );
  }

  /// Start / Stop Time / Complete / Add Extra Charges (see JobActions).
  Widget jobActionsWidget(BuildContext context, OnProviderOrderModel onProviderOrder) {
    Widget button(String label, VoidCallback onPressed) => ElevatedButton(
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

    if (onProviderOrder.status == ORDER_STATUS_ASSIGNED) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(width: Responsive.width(70, context), child: button('Start', () => JobActions.start(onProviderOrder))),
      );
    }
    if (onProviderOrder.status == ORDER_STATUS_ONGOING) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: onProviderOrder.provider.priceUnit.toString() == "Hourly" && onProviderOrder.endTime == null
                  ? button('Stop Time', () => JobActions.stopTime(onProviderOrder))
                  : button('Complete', () => JobActions.complete(onProviderOrder)),
            ),
            const SizedBox(width: 10),
            onProviderOrder.extraCharges!.isNotEmpty && onProviderOrder.extraCharges != null
                ? const SizedBox()
                : Expanded(
                    child: button('Add Extra Charges', () {
                      BookingDetailsController bookingDetailsController = Get.put(BookingDetailsController());
                      CommonUI.showAddExtraChargesDialog(context, bookingDetailsController, onProviderOrder);
                      Get.delete<BookingDetailsController>();
                    }),
                  ),
          ],
        ),
      );
    }
    return const SizedBox();
  }
}

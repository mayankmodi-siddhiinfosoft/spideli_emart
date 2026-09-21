import 'package:driver/app/chat_screens/chat_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import '../../controllers/rental_order_details_controller.dart';
import '../../themes/app_them_data.dart';
import '../../themes/responsive.dart';

class RentalOrderDetailsScreen extends StatelessWidget {
  const RentalOrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: RentalOrderDetailsController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              "Order Details".tr,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            backgroundColor: isDark ? Colors.black : Colors.white,
            iconTheme: IconThemeData(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          body: controller.isLoading.value
              ? Center(child: Constant.loader())
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                            border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "Booking Id : ${controller.order.value.id}",
                                      style: AppThemeData.semiBoldTextStyle(
                                        fontSize: 16,
                                        color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: controller.order.value.id.toString()));
                                      ShowToastDialog.showToast("Booking ID copied to clipboard".tr);
                                    },
                                    child: Icon(Icons.copy),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Image.asset("assets/icons/pickup.png", height: 15, width: 15),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          controller.order.value.sourceLocationName ?? "-",
                                          style: AppThemeData.semiBoldTextStyle(
                                            fontSize: 16,
                                            color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                          ),
                                        ),
                                        if (controller.order.value.bookingDateTime != null)
                                          Text(
                                            Constant.timestampToDate(controller.order.value.bookingDateTime!),
                                            style: AppThemeData.semiBoldTextStyle(
                                              fontSize: 12,
                                              color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        if (controller.order.value.rentalPackageModel != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                              border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Your Preference", style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                                SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            controller.order.value.rentalPackageModel!.name ?? "-",
                                            style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            controller.order.value.rentalPackageModel!.description ?? "",
                                            style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      Constant.amountShow(amount: controller.order.value.rentalPackageModel!.baseFare.toString()),
                                      style: AppThemeData.boldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 15),
                        if (controller.order.value.author != null)
                          Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                  border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("About Customer".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            SizedBox(
                                              width: 52,
                                              height: 52,
                                              child: ClipRRect(
                                                borderRadius: BorderRadiusGeometry.circular(10),
                                                child: NetworkImageWidget(
                                                  imageUrl: controller.userData.value?.profilePictureURL ?? '',
                                                  height: 70,
                                                  width: 70,
                                                  borderRadius: 35,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 20),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  controller.userData.value?.fullName() ?? '',
                                                  style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 18),
                                                ),
                                                Text(
                                                  controller.userData.value?.email ?? '',
                                                  style: TextStyle(
                                                    fontFamily: AppThemeData.medium,
                                                    color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                Text(
                                                  controller.userData.value?.phoneNumber ?? '',
                                                  style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700, fontSize: 16),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        InkWell(
                                          onTap: () async {
                                            ShowToastDialog.showLoader("Please wait".tr);

                                            UserModel? customer = await FireStoreUtils.getUserProfile(controller.order.value.authorID.toString());
                                            UserModel? driver = await FireStoreUtils.getUserProfile(controller.order.value.driverId.toString());

                                            ShowToastDialog.closeLoader();

                                            Get.to(const ChatScreen(), arguments: {
                                              "senderName": driver?.fullName(),
                                              "receivedName": customer?.fullName(),
                                              "orderId": controller.order.value.id,
                                              "senderId": driver?.id,
                                              "receivedId": customer?.id,
                                              "receivedProfileUrl": customer?.profilePictureURL ?? "",
                                              "senderProfileUrl": driver?.profilePictureURL ?? "",
                                              "token": customer?.fcmToken,
                                              "chatType": Constant.userRoleDriver,
                                            });
                                          },
                                          child: Container(
                                            width: 42,
                                            height: 42,
                                            decoration: ShapeDecoration(
                                              shape: RoundedRectangleBorder(
                                                side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                                borderRadius: BorderRadius.circular(120),
                                              ),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: SvgPicture.asset("assets/icons/ic_wechat.svg"),
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                    // Visibility(
                                    //   visible: controller.order.value?.status == Constant.orderCompleted ? true : false,
                                    //   child: Padding(
                                    //     padding: const EdgeInsets.symmetric(vertical: 10),
                                    //     child: RoundedButtonFill(
                                    //       title: 'Add Review'.tr,
                                    //       onPress: () async {
                                    //         final result = await Get.to(() => RentalReviewScreen(), arguments: {'order': controller.order.value});
                                    //
                                    //         // If review was submitted successfully
                                    //         if (result == true) {
                                    //           await controller.fetchCustomerDetails();
                                    //         }
                                    //       },
                                    //       height: 5,
                                    //       borderRadius: 15,
                                    //       color: Colors.orange,
                                    //       textColor: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                    //     ),
                                    //   ),
                                    // ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 15),
                            ],
                          ),
                        if (controller.order.value.rentalVehicleType != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                              border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Vehicle Type".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                                SizedBox(height: 10),
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: NetworkImageWidget(imageUrl: controller.order.value.rentalVehicleType!.rentalVehicleIcon ?? "", height: 50, width: 50),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            controller.order.value.rentalVehicleType!.name ?? "",
                                            style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                          ),
                                          Text(
                                            controller.order.value.rentalVehicleType!.shortDescription ?? "",
                                            style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 15),
                        Container(
                          width: Responsive.width(100, context),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                            border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Rental Details".tr,
                                  style: AppThemeData.boldTextStyle(
                                    fontSize: 16,
                                    color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                  ),
                                ),
                                Divider(color: isDark ? AppThemeData.greyDark300 : AppThemeData.grey300),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Rental Package'.tr,
                                          textAlign: TextAlign.start,
                                          style: AppThemeData.mediumTextStyle(
                                            fontSize: 14,
                                            color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        controller.order.value.rentalPackageModel!.name.toString().tr,
                                        textAlign: TextAlign.start,
                                        style: AppThemeData.boldTextStyle(
                                          fontSize: 14,
                                          color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Rental Package Price'.tr,
                                          textAlign: TextAlign.start,
                                          style: AppThemeData.mediumTextStyle(
                                            fontSize: 14,
                                            color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        Constant.amountShow(
                                          amount: controller.order.value.rentalPackageModel!.baseFare.toString(),
                                        ).tr,
                                        textAlign: TextAlign.start,
                                        style: AppThemeData.boldTextStyle(
                                          fontSize: 14,
                                          color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Including ${Constant.distanceType.tr}',
                                          textAlign: TextAlign.start,
                                          style: AppThemeData.mediumTextStyle(
                                            fontSize: 14,
                                            color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        "${controller.order.value.rentalPackageModel!.includedDistance.toString()} ${Constant.distanceType}".tr,
                                        textAlign: TextAlign.start,
                                        style: AppThemeData.boldTextStyle(
                                          fontSize: 14,
                                          color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Including Hours'.tr,
                                          textAlign: TextAlign.start,
                                          style: AppThemeData.mediumTextStyle(
                                            fontSize: 14,
                                            color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        "${controller.order.value.rentalPackageModel!.includedHours.toString()} Hr".tr,
                                        textAlign: TextAlign.start,
                                        style: AppThemeData.boldTextStyle(
                                          fontSize: 14,
                                          color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Extra ${Constant.distanceType}',
                                          textAlign: TextAlign.start,
                                          style: AppThemeData.mediumTextStyle(
                                            fontSize: 14,
                                            color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        controller.getExtraKm(),
                                        textAlign: TextAlign.start,
                                        style: AppThemeData.boldTextStyle(
                                          fontSize: 14,
                                          color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Padding(
                                //   padding: const EdgeInsets.symmetric(vertical: 10),
                                //   child: Row(
                                //     children: [
                                //       Expanded(
                                //         child: Text(
                                //           'Extra ${Constant.distanceType}',
                                //           textAlign: TextAlign.start,
                                //           style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                //         ),
                                //       ),
                                //       Text(
                                //         "${(double.parse(controller.order.value.endKitoMetersReading!.toString()) - double.parse(controller.order.value.startKitoMetersReading!.toString()) - double.parse(controller.order.value.rentalPackageModel!.includedDistance!.toString()))} ${Constant.distanceType}",
                                //         textAlign: TextAlign.start,
                                //         style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                //       ),
                                //     ],
                                //   ),
                                // ),
                                controller.order.value.endTime == null
                                    ? SizedBox()
                                    : Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Extra Minutes'.tr,
                                                textAlign: TextAlign.start,
                                                style: AppThemeData.mediumTextStyle(
                                                  fontSize: 14,
                                                  color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              "${controller.order.value.endTime == null ? "0" : (((controller.order.value.endTime!.toDate().difference(controller.order.value.startTime!.toDate()).inMinutes) - (int.parse(controller.order.value.rentalPackageModel!.includedHours.toString()) * 60)).clamp(0, double.infinity).toInt().toString())} Min",
                                              textAlign: TextAlign.start,
                                              style: AppThemeData.boldTextStyle(
                                                fontSize: 14,
                                                color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                            border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Order Summary".tr,
                                style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.grey500),
                              ),
                              const SizedBox(height: 8),
                              _summaryTile(
                                "Subtotal".tr,
                                Constant.amountShow(amount: controller.subTotal.value.toString()),
                                isDark,
                                null,
                              ),
                              _summaryTile(
                                "Discount".tr,
                                Constant.amountShow(amount: controller.discount.value.toString()),
                                isDark,
                                AppThemeData.dangerDark300,
                              ),
                              ...List.generate(controller.order.value.taxSetting?.length ?? 0, (index) {
                                final taxModel = controller.order.value.taxSetting![index];
                                final taxTitle = "${taxModel.title} ${taxModel.type == 'fix' ? '(${Constant.amountShow(amount: taxModel.tax)})' : '(${taxModel.tax}%)'}";
                                return _summaryTile(
                                  taxTitle,
                                  Constant.amountShow(
                                    amount: Constant.getTaxValue(
                                      amount: (controller.subTotal.value - controller.discount.value).toString(),
                                      taxModel: taxModel,
                                    ).toString(),
                                  ),
                                  isDark,
                                  null,
                                );
                              }),
                              const Divider(),
                              _summaryTile(
                                "Order Total".tr,
                                Constant.amountShow(amount: controller.totalAmount.value.toString()),
                                isDark,
                                null,
                              ),
                              _summaryTile(
                                "Admin Commission (${controller.order.value.adminCommission}${controller.order.value.adminCommissionType == "Percentage" || controller.order.value.adminCommissionType == "percentage" ? "%" : Constant.currencyModel!.symbol})"
                                    .tr,
                                Constant.amountShow(amount: controller.adminCommission.value.toString()),
                                isDark,
                                AppThemeData.danger300,
                              ),
                            ],
                          ),
                        ),
                        controller.order.value.driver != null && controller.order.value.driver!.ownerId != null && controller.order.value.driver!.ownerId!.isNotEmpty ||
                                controller.order.value.status == Constant.orderPlaced
                            ? SizedBox()
                            : Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Container(
                                  width: Responsive.width(100, context),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: isDark ? AppThemeData.danger50 : AppThemeData.danger50),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Note : Admin commission will be debited from your wallet balance. \n \nAdmin commission will apply on your booking Amount minus Discount(if applicable).",
                                          style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.danger300 : AppThemeData.danger300),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _summaryTile(String title, String value, bool isDark, Color? colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
          Text(
            value,
            style: AppThemeData.semiBoldTextStyle(fontSize: title == "Order Total" ? 18 : 16, color: colors ?? (isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
          ),
        ],
      ),
    );
  }
}

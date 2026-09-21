import 'package:driver/app/rental_service/rental_order_details_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/rental_booking_search_controller.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/round_button_fill.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/network_image_widget.dart';
import 'package:driver/widget/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:timelines_plus/timelines_plus.dart';

class RentalBookingSearchScreen extends StatelessWidget {
  const RentalBookingSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
        init: RentalBookingSearchController(),
        builder: (controller) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
              titleSpacing: 0,
              centerTitle: false,
            ),
            backgroundColor: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
            body: controller.isLoading.value
                ? Constant.loader()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: controller.rentalBookingData.isEmpty
                        ? Constant.showEmptyView(message: "No Rental booking available", isDark: isDark)
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: controller.rentalBookingData.length,
                            itemBuilder: (context, index) {
                              RentalOrderModel rentalBookingData = controller.rentalBookingData[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  onTap: () {},
                                  child: Container(
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                      border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        Get.to(() => RentalOrderDetailsScreen(), arguments: {"rentalOrder": rentalBookingData.id});
                                      },
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              ClipOval(
                                                child: NetworkImageWidget(
                                                  imageUrl: rentalBookingData.author!.profilePictureURL.toString(),
                                                  width: 52,
                                                  height: 52,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                              SizedBox(
                                                width: 10,
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '${rentalBookingData.author!.firstName} ${rentalBookingData.author!.lastName}'.tr,
                                                      textAlign: TextAlign.start,
                                                      style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: isDark ? AppThemeData.greyDark100 : AppThemeData.grey100,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              child: Column(
                                                children: [
                                                  Timeline.tileBuilder(
                                                    shrinkWrap: true,
                                                    padding: EdgeInsets.zero,
                                                    physics: const NeverScrollableScrollPhysics(),
                                                    theme: TimelineThemeData(
                                                      nodePosition: 0,
                                                      // indicatorPosition: 0,
                                                    ),
                                                    builder: TimelineTileBuilder.connected(
                                                      contentsAlign: ContentsAlign.basic,
                                                      indicatorBuilder: (context, index) {
                                                        return SvgPicture.asset("assets/icons/ic_location.svg");
                                                      },
                                                      connectorBuilder: (context, index, connectorType) {
                                                        return DashedLineConnector(
                                                          color: isDark ? AppThemeData.greyDark300 : AppThemeData.grey300,
                                                          gap: 4,
                                                        );
                                                      },
                                                      contentsBuilder: (context, index) {
                                                        return Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                          child: Text(
                                                            "${rentalBookingData.sourceLocationName}",
                                                            style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                          ),
                                                        );
                                                      },
                                                      itemCount: 1,
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    height: 5,
                                                  ),
                                                  DottedLine(
                                                    dashColor: Colors.grey,
                                                    lineThickness: 1.0,
                                                    dashLength: 4.0,
                                                    dashGapLength: 3.0,
                                                    direction: Axis.horizontal,
                                                  ),
                                                  SizedBox(
                                                    height: 10,
                                                  ),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          "Package Details:".tr,
                                                          textAlign: TextAlign.start,
                                                          style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                        ),
                                                      ),
                                                      Text(
                                                        "${rentalBookingData.rentalPackageModel!.name}".tr,
                                                        textAlign: TextAlign.start,
                                                        style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(
                                                    height: 5,
                                                  ),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          "Including Distance:".tr,
                                                          textAlign: TextAlign.start,
                                                          style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                        ),
                                                      ),
                                                      Text(
                                                        "${rentalBookingData.rentalPackageModel!.includedDistance} ${Constant.distanceType}".tr,
                                                        textAlign: TextAlign.start,
                                                        style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(
                                                    height: 5,
                                                  ),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          "Including Duration:".tr,
                                                          textAlign: TextAlign.start,
                                                          style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                        ),
                                                      ),
                                                      Text(
                                                        "${rentalBookingData.rentalPackageModel!.includedHours} Hr".tr,
                                                        textAlign: TextAlign.start,
                                                        style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                                      ),
                                                    ],
                                                  )
                                                ],
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            height: 12,
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  children: [
                                                    SvgPicture.asset("assets/icons/ic_amount.svg"),
                                                    SizedBox(
                                                      height: 5,
                                                    ),
                                                    Text(
                                                      Constant.amountShow(amount: rentalBookingData.subTotal).tr,
                                                      textAlign: TextAlign.start,
                                                      style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                    )
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  children: [
                                                    SvgPicture.asset("assets/icons/ic_date.svg"),
                                                    SizedBox(
                                                      height: 5,
                                                    ),
                                                    Text(
                                                      Constant.timestampToDateTime(rentalBookingData.bookingDateTime!).tr,
                                                      textAlign: TextAlign.start,
                                                      style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                    )
                                                  ],
                                                ),
                                              )
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: RoundedButtonFill(
                                                  title: "Reject".tr,
                                                  height: 5.5,
                                                  color: isDark ? AppThemeData.greyDark300 : AppThemeData.grey300,
                                                  textColor: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500,
                                                  onPress: () async {
                                                    ShowToastDialog.showLoader("Rejecting booking...".tr);
                                                    rentalBookingData.rejectedByDrivers!.add(FireStoreUtils.getCurrentUid());
                                                    await FireStoreUtils.rentalOrderPlace(rentalBookingData);
                                                    Get.back(result: true);
                                                    ShowToastDialog.showToast("Booking rejected successfully".tr);
                                                    controller.getRentalSearchBooking();
                                                  },
                                                ),
                                              ),
                                              SizedBox(
                                                width: 20,
                                              ),
                                              Expanded(
                                                child: RoundedButtonFill(
                                                  title: "Accept".tr,
                                                  height: 5.5,
                                                  color: AppThemeData.primary300,
                                                  textColor: AppThemeData.grey50,
                                                  onPress: () async {
                                                    if (controller.driverModel.value.ownerId != null && controller.driverModel.value.ownerId!.isNotEmpty) {
                                                      if (controller.ownerModel.value.walletAmount != null &&
                                                          controller.ownerModel.value.walletAmount! >= double.parse(Constant.minimumDepositToRideAccept)) {
                                                        ShowToastDialog.showLoader("Accepting booking...".tr);
                                                        // Update section model for this order's section (multi-section support)
                                                        final sid = rentalBookingData.sectionId;
                                                        if (sid != null && sid.isNotEmpty) {
                                                          await FireStoreUtils.getSectionBySectionId(sid).then((s) {
                                                            if (s != null) Constant.sectionModels[sid] = s;
                                                          });
                                                        }
                                                        rentalBookingData.status = Constant.driverAccepted;
                                                        rentalBookingData.driverId = FireStoreUtils.getCurrentUid();
                                                        rentalBookingData.driver = Constant.userModel;
                                                        await FireStoreUtils.rentalOrderPlace(rentalBookingData);
                                                        Get.back(result: true);
                                                        ShowToastDialog.showToast("Booking accepted successfully".tr);
                                                      } else {
                                                        ShowToastDialog.showToast(
                                                            "Your owner has to maintain minimum ${Constant.amountShow(amount: Constant.ownerMinimumDepositToRideAccept)} wallet balance to accept the rental booking. Please contact your owner"
                                                                .tr);
                                                      }
                                                    } else {
                                                      if (controller.driverModel.value.walletAmount! >= double.parse(Constant.minimumDepositToRideAccept)) {
                                                        ShowToastDialog.showLoader("Accepting booking...".tr);
                                                        // Update section model for this order's section (multi-section support)
                                                        final sid = rentalBookingData.sectionId;
                                                        if (sid != null && sid.isNotEmpty) {
                                                          await FireStoreUtils.getSectionBySectionId(sid).then((s) {
                                                            if (s != null) Constant.sectionModels[sid] = s;
                                                          });
                                                        }
                                                        rentalBookingData.status = Constant.driverAccepted;
                                                        rentalBookingData.driverId = FireStoreUtils.getCurrentUid();
                                                        rentalBookingData.driver = Constant.userModel;
                                                        await FireStoreUtils.rentalOrderPlace(rentalBookingData);
                                                        Get.back(result: true);
                                                        ShowToastDialog.showToast("Booking accepted successfully".tr);
                                                      } else {
                                                        ShowToastDialog.showToast("Your owner has to maintain minimum @amount wallet balance to accept the rental booking. Please contact your owner"
                                                            .trParams({"amount": Constant.amountShow(amount: Constant.ownerMinimumDepositToRideAccept)}));
                                                      }
                                                    }
                                                  },
                                                ),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          );
        });
  }
}

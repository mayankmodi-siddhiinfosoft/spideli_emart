import 'package:driver/app/parcel_screen/parcel_order_details.dart';
import 'package:driver/app/parcel_screen/parcel_search_screen.dart';
import 'package:driver/app/parcel_screen/parcel_tracking_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/parcel_dashboard_controller.dart';
import 'package:driver/controllers/parcel_home_controller.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/round_button_fill.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/network_image_widget.dart';
import 'package:driver/widget/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:timelines_plus/timelines_plus.dart';

import '../../constant/show_toast_dialog.dart';
import '../../models/user_model.dart';
import '../../utils/fire_store_utils.dart';
import '../chat_screens/chat_screen.dart';

class ParcelHomeScreen extends StatelessWidget {
  const ParcelHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetX(
          init: ParcelHomeController(),
          builder: (controller) {
            return Scaffold(
              backgroundColor: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
              body: controller.isLoading.value
                  ? Constant.loader()
                  : Constant.userModel?.isDocumentVerify == false && Constant.userModel?.isAutoVerify == false
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                decoration: ShapeDecoration(
                                  color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(120),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: SvgPicture.asset("assets/icons/ic_document.svg"),
                                ),
                              ),
                              const SizedBox(
                                height: 12,
                              ),
                              Text(
                                "Document Verification in Pending".tr,
                                style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 22, fontFamily: AppThemeData.semiBold),
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              Text(
                                "Your documents are being reviewed. We will notify you once the verification is complete.".tr,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.bold),
                              ),
                              const SizedBox(
                                height: 20,
                              ),
                              RoundedButtonFill(
                                title: "View Status".tr,
                                width: 55,
                                height: 5.5,
                                color: AppThemeData.primary300,
                                textColor: AppThemeData.grey50,
                                onPress: () async {
                                  ParcelDashboardController dashBoardController = Get.put(ParcelDashboardController());
                                  dashBoardController.drawerIndex.value = 4;
                                },
                              ),
                            ],
                          ),
                        )
                      : controller.userModel.value.isActive == false
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset("assets/images/empty_parcel.svg"),
                                  SizedBox(
                                    height: 20,
                                  ),
                                  Text(
                                    'You’re Currently Offline'.tr,
                                    textAlign: TextAlign.center,
                                    style: AppThemeData.mediumTextStyle(
                                      fontSize: 18,
                                      color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                    ),
                                  ),
                                  SizedBox(
                                    height: 10,
                                  ),
                                  Text(
                                    'Switch to online mode to accept and deliver parcel orders.'.tr,
                                    textAlign: TextAlign.center,
                                    style: AppThemeData.mediumTextStyle(
                                      fontSize: 14,
                                      color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : controller.parcelOrdersList.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(
                                    children: [
                                      Obx(() {
                                        final user = controller.userModel.value;
                                        final controllerOwner = controller.ownerModel.value;

                                        final num wallet = user.walletAmount ?? 0.0;
                                        final num ownerWallet = controllerOwner.walletAmount ?? 0.0;
                                        final String? ownerId = user.ownerId;

                                        final num minDeposit = double.parse(Constant.minimumDepositToRideAccept);

                                        // 🧠 Logic:
                                        // If individual driver → check driver's own wallet
                                        // If owner driver → check owner's wallet
                                        if ((ownerId == null || ownerId.isEmpty) && wallet < minDeposit) {
                                          // Individual driver case
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: AppThemeData.danger50,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text(
                                                  "${'You must have at least'.tr} ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} ${'in your wallet to receive orders'.tr}",
                                                  style: TextStyle(
                                                    color: AppThemeData.grey900,
                                                    fontSize: 14,
                                                    fontFamily: AppThemeData.semiBold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        } else if (ownerId != null && ownerId.isNotEmpty && ownerWallet < minDeposit) {
                                          // Owner-driver case
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: AppThemeData.danger50,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text(
                                                  "Your owner doesn't have the minimum wallet amount to receive orders. Please contact your owner.".tr,
                                                  style: TextStyle(
                                                    color: AppThemeData.grey900,
                                                    fontSize: 14,
                                                    fontFamily: AppThemeData.semiBold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        } else {
                                          return const SizedBox();
                                        }
                                      }),
                                      // (double.parse(Constant.userModel!.walletAmount == null ? "0.0" : Constant.userModel!.walletAmount.toString()) <
                                      //     double.parse(Constant.minimumDepositToRideAccept) &&
                                      //     (Constant.userModel?.ownerId == null || Constant.userModel!.ownerId!.isEmpty))
                                      //     ? Container(
                                      //         decoration: BoxDecoration(color: AppThemeData.danger50, borderRadius: BorderRadius.circular(10)),
                                      //         child: Padding(
                                      //           padding: const EdgeInsets.all(8.0),
                                      //           child: Text(
                                      //             "${'You have to minimum'.tr} ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} ${'wallet amount to receiving Order'.tr}",
                                      //             style: TextStyle(color: isDark ? AppThemeData.danger300 : AppThemeData.danger300, fontSize: 14, fontFamily: AppThemeData.semiBold),
                                      //           ),
                                      //         ),
                                      //       )
                                      //     : const SizedBox(),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SvgPicture.asset("assets/images/empty_parcel.svg"),
                                            SizedBox(
                                              height: 20,
                                            ),
                                            Text(
                                              'No parcel requests available in your selected zone.'.tr,
                                              textAlign: TextAlign.center,
                                              style: AppThemeData.mediumTextStyle(
                                                fontSize: 18,
                                                color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                              ),
                                            ),
                                            SizedBox(
                                              height: 10,
                                            ),
                                            Text(
                                              'Try changing the location or date.'.tr,
                                              textAlign: TextAlign.center,
                                              style: AppThemeData.mediumTextStyle(
                                                fontSize: 14,
                                                color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                              ),
                                            ),
                                            SizedBox(
                                              height: 20,
                                            ),
                                            RoundedButtonFill(
                                              title: "Search Parcel".tr,
                                              height: 5.5,
                                              color: AppThemeData.primary300,
                                              textColor: AppThemeData.grey50,
                                              onPress: () {
                                                Get.to(ParcelSearchScreen())!.then((value) {
                                                  if (value != null && value is bool && value) {
                                                    controller.getParcelList();
                                                  }
                                                });
                                              },
                                            )
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
                                  child: RefreshIndicator(
                                    onRefresh: () async {
                                      await controller.getParcelList();
                                    },
                                    child: ListView.builder(
                                      itemCount: controller.parcelOrdersList.length,
                                      shrinkWrap: true,
                                      itemBuilder: (context, index) {
                                        ParcelOrderModel parcelBookingData = controller.parcelOrdersList[index];
                                        return InkWell(
                                          onTap: () {
                                            Get.to(() => const ParcelOrderDetails(), arguments: parcelBookingData);
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(15),
                                              color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                              border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: isDark ? AppThemeData.greyDark100 : AppThemeData.grey100,
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                    child: Timeline.tileBuilder(
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
                                                          return index == 0
                                                              ? SvgPicture.asset("assets/icons/ic_source.svg")
                                                              : index == 1
                                                                  ? SvgPicture.asset("assets/icons/ic_destination.svg")
                                                                  : SizedBox();
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
                                                              index == 0 ? "${parcelBookingData.sender!.address}" : "${parcelBookingData.receiver!.address}",
                                                              style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                            ),
                                                          );
                                                        },
                                                        itemCount: 2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 15),
                                                  child: Row(
                                                    children: [
                                                      ClipOval(
                                                        child: NetworkImageWidget(
                                                          imageUrl: parcelBookingData.author!.profilePictureURL.toString(),
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
                                                              parcelBookingData.author!.fullName().tr,
                                                              textAlign: TextAlign.start,
                                                              style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      InkWell(
                                                        onTap: () async {
                                                          ShowToastDialog.showLoader("Please wait".tr);

                                                          UserModel? customer = await FireStoreUtils.getUserProfile(parcelBookingData.authorID.toString());
                                                          UserModel? driver = await FireStoreUtils.getUserProfile(parcelBookingData.driverId.toString());

                                                          ShowToastDialog.closeLoader();

                                                          Get.to(const ChatScreen(), arguments: {
                                                            "senderName": driver!.fullName(),
                                                            "receivedName": customer!.fullName(),
                                                            "orderId": parcelBookingData.id,
                                                            "senderId": driver.id,
                                                            "receivedId": customer.id,
                                                            "receivedProfileUrl": customer.profilePictureURL ?? "",
                                                            "senderProfileUrl": driver.profilePictureURL ?? "",
                                                            "token": customer.fcmToken,
                                                            "chatType": Constant.userRoleDriver,
                                                          });
                                                        },
                                                        child: Container(
                                                          width: 50,
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
                                                ),
                                                SizedBox(
                                                  height: 12,
                                                ),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        children: [
                                                          SvgPicture.asset(
                                                            "assets/icons/ic_amount.svg",
                                                            colorFilter: ColorFilter.mode(isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, BlendMode.srcIn),
                                                          ),
                                                          SizedBox(
                                                            height: 5,
                                                          ),
                                                          Text(
                                                            Constant.amountShow(amount: controller.calculateParcelTotalAmountBooking(parcelBookingData)).tr,
                                                            textAlign: TextAlign.start,
                                                            style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Column(
                                                        children: [
                                                          SvgPicture.asset(
                                                            "assets/icons/ic_date.svg",
                                                            colorFilter: ColorFilter.mode(isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, BlendMode.srcIn),
                                                          ),
                                                          SizedBox(
                                                            height: 5,
                                                          ),
                                                          Text(
                                                            '${Constant.timestampToDate(parcelBookingData.senderPickupDateTime!)}  '.tr,
                                                            textAlign: TextAlign.start,
                                                            style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Column(
                                                        children: [
                                                          SvgPicture.asset(
                                                            "assets/icons/weight-line.svg",
                                                            colorFilter: ColorFilter.mode(isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, BlendMode.srcIn),
                                                          ),
                                                          SizedBox(
                                                            height: 5,
                                                          ),
                                                          Text(
                                                            '${parcelBookingData.parcelWeight}'.tr,
                                                            textAlign: TextAlign.start,
                                                            style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                          )
                                                        ],
                                                      ),
                                                    )
                                                  ],
                                                ),
                                                const SizedBox(height: 16),
                                                DottedLine(
                                                  dashColor: Colors.grey,
                                                  lineThickness: 1.0,
                                                  dashLength: 4.0,
                                                  dashGapLength: 3.0,
                                                  direction: Axis.horizontal,
                                                ),
                                                const SizedBox(height: 16),
                                                parcelBookingData.status == Constant.driverAccepted
                                                    ? Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 15),
                                                        child: RoundedButtonFill(
                                                          title: "Pickup Parcel".tr,
                                                          height: 5.5,
                                                          color: AppThemeData.success400,
                                                          textColor: AppThemeData.grey50,
                                                          onPress: () async {
                                                            controller.pickupParcel(parcelBookingData);
                                                          },
                                                        ),
                                                      )
                                                    : Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 15),
                                                        child: RoundedButtonFill(
                                                          title: "Deliver Parcel".tr,
                                                          height: 5.5,
                                                          color: AppThemeData.success400,
                                                          textColor: AppThemeData.grey50,
                                                          onPress: () async {
                                                            controller.completeParcel(parcelBookingData);
                                                          },
                                                        ),
                                                      ),
                                                parcelBookingData.status == Constant.driverAccepted || parcelBookingData.status == Constant.orderInTransit
                                                    ? Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 15),
                                                        child: Column(
                                                          children: [
                                                            const SizedBox(height: 16),
                                                            RoundedButtonFill(
                                                              title: "Parcel Track".tr,
                                                              height: 5.5,
                                                              color: AppThemeData.success400,
                                                              textColor: AppThemeData.grey50,
                                                              onPress: () async {
                                                                Get.to(() => ParcelTrackingScreen(), arguments: {'parcelOrder': parcelBookingData});
                                                              },
                                                            ),
                                                          ],
                                                        ),
                                                      )
                                                    : SizedBox.shrink(),
                                                const SizedBox(height: 16),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
            );
          });
    });
  }
}

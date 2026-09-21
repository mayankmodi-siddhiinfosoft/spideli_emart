import 'package:driver/app/owner_screen/driver_create_screen.dart';
import 'package:driver/app/owner_screen/view_all_drivers.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/owner_dashboard_controller.dart';
import 'package:driver/controllers/owner_home_controller.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/round_button_fill.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'driver_order_list.dart';

class OwnerHomeScreen extends StatelessWidget {
  const OwnerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final dashController = Get.put(OwnerDashboardController());
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetX(
          init: OwnerHomeController(),
          builder: (controller) {
            return Scaffold(
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
                                onPress: () {
                                  OwnerDashboardController dashBoardController = Get.put(OwnerDashboardController());
                                  dashBoardController.drawerIndex.value = 4;
                                },
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Column(
                              children: [
                                Obx(() {
                                  num wallet = dashController.userModel.value.walletAmount ?? 0.0;
                                  return wallet < double.parse(Constant.ownerMinimumDepositToRideAccept)
                                      ? Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: Container(
                                            decoration: BoxDecoration(color: AppThemeData.danger50, borderRadius: BorderRadius.circular(10)),
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Text(
                                                "You must have a minimum of ${Constant.amountShow(amount: Constant.ownerMinimumDepositToRideAccept.toString())} in your wallet to receive orders to your driver"
                                                    .tr,
                                                style: TextStyle(
                                                  color: AppThemeData.danger300,
                                                  fontSize: 14,
                                                  fontFamily: AppThemeData.semiBold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : const SizedBox();
                                }),
                                SizedBox(
                                  height: 10,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppThemeData.homePageGradiant[0],
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // SvgPicture.asset("assets/icons/ic_ride.svg"),
                                              SizedBox(
                                                height: 10,
                                              ),
                                              Text(
                                                controller.totalRidesAllDrivers.toString(),
                                                textAlign: TextAlign.center,
                                                style: AppThemeData.boldTextStyle(
                                                  fontSize: 16,
                                                  color: AppThemeData.grey900,
                                                ),
                                              ),
                                              SizedBox(
                                                height: 5,
                                              ),
                                              Text(
                                                'Total Bookings'.tr,
                                                textAlign: TextAlign.center,
                                                style: AppThemeData.mediumTextStyle(
                                                  fontSize: 12,
                                                  color: AppThemeData.grey900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 10,
                                    ),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppThemeData.homePageGradiant[1],
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // SvgPicture.asset("assets/icons/ic_total_ride.svg"),
                                              SizedBox(
                                                height: 10,
                                              ),
                                              Text(
                                                '${controller.driverList.length} ',
                                                textAlign: TextAlign.center,
                                                style: AppThemeData.boldTextStyle(
                                                  fontSize: 16,
                                                  color: AppThemeData.grey900,
                                                ),
                                              ),
                                              SizedBox(
                                                height: 5,
                                              ),
                                              Text(
                                                'Total Drivers'.tr,
                                                textAlign: TextAlign.center,
                                                style: AppThemeData.mediumTextStyle(
                                                  fontSize: 12,
                                                  color: AppThemeData.grey900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: 10,
                                ),
                                Container(
                                  width: Responsive.width(100, context),
                                  decoration: BoxDecoration(
                                    color: AppThemeData.homePageGradiant[2],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SvgPicture.asset("assets/icons/ic_earning.svg"),
                                        SizedBox(
                                          height: 10,
                                        ),
                                        Text(
                                          '${Constant.currencyModel!.symbol.toString()}${controller.totalEarningsAllDrivers.toStringAsFixed(2)}',
                                          textAlign: TextAlign.center,
                                          style: AppThemeData.boldTextStyle(
                                            fontSize: 16,
                                            color: AppThemeData.grey900,
                                          ),
                                        ),
                                        SizedBox(
                                          height: 5,
                                        ),
                                        Text(
                                          'Earnings'.tr,
                                          textAlign: TextAlign.center,
                                          style: AppThemeData.mediumTextStyle(
                                            fontSize: 12,
                                            color: AppThemeData.grey900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 30,
                                ),
                                controller.driverList.isEmpty
                                    ? SizedBox()
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Your Available Drivers'.tr,
                                                      textAlign: TextAlign.center,
                                                      style: AppThemeData.boldTextStyle(
                                                        fontSize: 16,
                                                        color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Real-time status and earnings summary'.tr,
                                                      textAlign: TextAlign.center,
                                                      style: AppThemeData.mediumTextStyle(
                                                        fontSize: 12,
                                                        color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  Get.to(ViewAllDriverScreen())!.then(
                                                    (value) {
                                                      controller.getDriverList();
                                                    },
                                                  );
                                                },
                                                child: Text(
                                                  'View all'.tr,
                                                  textAlign: TextAlign.center,
                                                  style: AppThemeData.mediumTextStyle(
                                                      fontSize: 16, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, decoration: TextDecoration.underline),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(
                                            height: 16,
                                          ),
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isDark ? AppThemeData.greyDark300 : AppThemeData.grey300,
                                              ),
                                            ),
                                            child: ListView.builder(
                                              // itemCount: controller.driverList.length,
                                              // physics: NeverScrollableScrollPhysics(),
                                              // shrinkWrap: true,
                                              itemCount: controller.driverList.length > 5 ? 5 : controller.driverList.length,
                                              physics: const NeverScrollableScrollPhysics(),
                                              shrinkWrap: true,
                                              itemBuilder: (context, index) {
                                                UserModel driverModel = controller.driverList[index];
                                                return Padding(
                                                  padding: const EdgeInsets.all(8.0),
                                                  child: Row(
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius: BorderRadius.circular(10),
                                                        child: NetworkImageWidget(
                                                          imageUrl: driverModel.profilePictureURL.toString(),
                                                          height: 42,
                                                          width: 42,
                                                          fit: BoxFit.fill,
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
                                                              driverModel.fullName(),
                                                              textAlign: TextAlign.center,
                                                              style: AppThemeData.semiBoldTextStyle(
                                                                fontSize: 16,
                                                                color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                                              ),
                                                            ),
                                                            Text(
                                                              '${driverModel.countryCode} ${driverModel.phoneNumber}',
                                                              textAlign: TextAlign.center,
                                                              style: AppThemeData.mediumTextStyle(
                                                                fontSize: 12,
                                                                color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 10,
                                                      ),
                                                      RoundedButtonFill(
                                                        title: driverModel.isActive == false ? "Offline" : "Online".tr,
                                                        height: 3.5,
                                                        width: 18,
                                                        borderRadius: 10,
                                                        color: driverModel.isActive == false ? AppThemeData.danger300 : AppThemeData.success300,
                                                        textColor: AppThemeData.grey50,
                                                        onPress: () async {},
                                                      ),
                                                      PopupMenuButton<String>(
                                                        padding: EdgeInsets.zero,
                                                        onSelected: (value) {
                                                          if (value == 'Edit Driver') {
                                                            Get.to(DriverCreateScreen(), arguments: {"driverModel": driverModel})!.then(
                                                              (value0) {
                                                                if (value0 == true) {
                                                                  controller.getDriverList();
                                                                }
                                                              },
                                                            );
                                                          } else if (value == 'Delete Driver') {
                                                            controller.deleteDriver(driverModel.id.toString());
                                                          } else if (value == 'View All Order') {
                                                            print("driver ::::::: ${driverModel.email}");
                                                            Get.to(() => const DriverOrderList(), arguments: {
                                                              "driverId": driverModel.id,
                                                              "serviceType": driverModel.serviceTypes?.first,
                                                            });
                                                          }
                                                        },
                                                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                                          PopupMenuItem<String>(
                                                            value: 'Edit Driver',
                                                            child: Text('Edit Driver'.tr, style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.greyDark50)),
                                                          ),
                                                          PopupMenuItem<String>(
                                                            value: 'Delete Driver',
                                                            child: Text('Delete Driver'.tr, style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.greyDark50)),
                                                          ),
                                                          PopupMenuItem<String>(
                                                            value: 'View All Order',
                                                            child: Text('View All Order'.tr, style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.greyDark50)),
                                                          ),
                                                        ],
                                                        color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                                        icon: Icon(Icons.more_vert, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900), // Three dots icon
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                SizedBox(
                                  height: 30,
                                ),
                              ],
                            ),
                          ),
                        ),
              floatingActionButton: (Constant.userModel?.isDocumentVerify == true && Constant.userModel?.isAutoVerify == false) || Constant.userModel?.isAutoVerify == true
                  ? ClipOval(
                      child: FloatingActionButton(
                        onPressed: () {
                          Get.to(DriverCreateScreen())!.then((value) {
                            if (value == true) {
                              controller.getDriverList();
                            }
                          });
                        },
                        backgroundColor: AppThemeData.primary300,
                        child: Icon(
                          Icons.add,
                          color: AppThemeData.grey50,
                        ),
                      ),
                    )
                  : SizedBox.shrink(),
            );
          });
    });
  }
}

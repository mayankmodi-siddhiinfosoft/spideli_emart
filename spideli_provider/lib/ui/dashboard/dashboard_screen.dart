// ignore_for_file: deprecated_member_use

import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/controller/dashboard_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/helper.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/app_them_data.dart';
import 'package:spideliprovider/themes/responsive.dart';
import 'package:spideliprovider/themes/round_button_fill.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/widgets/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class DashBoardScreen extends StatelessWidget {
  const DashBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<DashBoardController>(
        init: DashBoardController(),
        builder: (controller) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: themeChange.getTheme()
                  ? AppColors.colorDark
                  : AppColors.colorWhite,
              title: Text(
                controller
                    .drawerItems[controller.selectedDrawerIndex.value].title,
                style: TextStyle(
                    color: themeChange.getTheme()
                        ? Colors.white
                        : AppColors.colorDark,
                    fontSize: 18,
                    fontFamily: AppColors.semiBold),
              ),
              leading: Builder(builder: (context) {
                return InkWell(
                  onTap: () {
                    Scaffold.of(context).openDrawer();
                  },
                  child: Padding(
                      padding: const EdgeInsets.only(
                          left: 10, right: 20, top: 20, bottom: 20),
                      child: Icon(
                        Icons.menu,
                        color: themeChange.getTheme()
                            ? AppColors.colorWhite
                            : AppColors.colorDark,
                      )),
                );
              }),
              actions: [
                InkWell(
                  onTap: () {
                    showResetPwdAlertDialog(context, themeChange, controller);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(Icons.info),
                  ),
                )
              ],
            ),
            drawer: buildAppDrawer(context, controller, themeChange),
            body: WillPopScope(
                onWillPop: controller.onWillPop,
                child: controller.isLoading.value == true
                    ? loader()
                    : controller.getDrawerItemWidget(
                        controller.selectedDrawerIndex.value)),
          );
        });
  }

  buildAppDrawer(
      BuildContext context, DashBoardController controller, themeChange) {
    var drawerOptions = <Widget>[];
    for (var i = 0; i < controller.drawerItems.length; i++) {
      var d = controller.drawerItems[i];
      drawerOptions.add(InkWell(
        onTap: () {
          controller.onSelectItem(i);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SvgPicture.asset(d.icon,
                    width: 20,
                    colorFilter: ColorFilter.mode(
                        i == controller.selectedDrawerIndex.value
                            ? AppColors.colorPrimary
                            : themeChange.getTheme()
                                ? Colors.white
                                : Colors.grey.shade600,
                        BlendMode.srcIn)),
                const SizedBox(
                  width: 20,
                ),
                Text(d.title,
                    style: TextStyle(
                      color: i == controller.selectedDrawerIndex.value
                          ? AppColors.colorPrimary
                          : themeChange.getTheme()
                              ? Colors.white
                              : Colors.black,
                      //    fontWeight: FontWeight.w500,
                    ))
              ],
            ),
          ),
        ),
      ));
    }
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.background,
      child: ListView(
        children: [
          DrawerHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipOval(
                    child: displayCircleImage(
                        controller.user.value.profilePictureURL, 75, false)),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    controller.user.value.fullName(),
                    style: TextStyle(
                        color: themeChange.getTheme()
                            ? Colors.white
                            : Colors.black,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      controller.user.value.email,
                      style: TextStyle(
                          color: themeChange.getTheme()
                              ? Colors.white
                              : Colors.black,
                          fontWeight: FontWeight.normal,
                          fontSize: 14),
                    )),
              ],
            ),
          ),
          if ((selectedSectionModel?.adminCommision?.enable == true ||
                  isSubscriptionModelApplied == true) &&
              MyAppState.currentUser?.subscriptionPlanId != null)
            SubscriptionPlanWidget(
              onClick: () {
                Get.back();
                controller.selectedDrawerIndex.value = 5;
              },
              userModel: MyAppState.currentUser!,
            ),
          Column(children: drawerOptions),
        ],
      ),
    );
  }

  void showResetPwdAlertDialog(BuildContext context, themeChange, controller) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text('Status Info'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "New Booking : ",
                  style: TextStyle(
                      color: AppColors.colorPrimary,
                      fontSize: 18,
                      fontFamily: AppColors.semiBold),
                ),
                Text(
                  "This status indicates that a new booking request has been received from a customer.",
                  style: TextStyle(
                      color: themeChange.getTheme()
                          ? Colors.white
                          : AppColors.colorDark,
                      fontSize: 18,
                      fontFamily: AppColors.semiBold),
                ),
                SizedBox(
                  height: 10,
                ),
                Text(
                  "Today : ",
                  style: TextStyle(
                      color: AppColors.colorPrimary,
                      fontSize: 18,
                      fontFamily: AppColors.semiBold),
                ),
                Text(
                  "This status refers to bookings that are scheduled for the current day.",
                  style: TextStyle(
                      color: themeChange.getTheme()
                          ? Colors.white
                          : AppColors.colorDark,
                      fontSize: 18,
                      fontFamily: AppColors.semiBold),
                ),
                SizedBox(
                  height: 10,
                ),
                Text(
                  "Upcoming : ",
                  style: TextStyle(
                      color: AppColors.colorPrimary,
                      fontSize: 18,
                      fontFamily: AppColors.semiBold),
                ),
                Text(
                  "Bookings that are scheduled for future dates but not for the current day fall under this status.",
                  style: TextStyle(
                      color: themeChange.getTheme()
                          ? Colors.white
                          : AppColors.colorDark,
                      fontSize: 18,
                      fontFamily: AppColors.semiBold),
                ),
                SizedBox(
                  height: 10,
                ),
                Text(
                  "Completed : ",
                  style: TextStyle(
                      color: AppColors.colorPrimary,
                      fontSize: 18,
                      fontFamily: AppColors.semiBold),
                ),
                Text(
                  "This status signifies that the service has been successfully provided to the customer, and the booking process is concluded.",
                  style: TextStyle(
                      color: themeChange.getTheme()
                          ? Colors.white
                          : AppColors.colorDark,
                      fontSize: 18,
                      fontFamily: AppColors.semiBold),
                ),
                SizedBox(
                  height: 10,
                ),
                Text(
                  "Canceled",
                  style: TextStyle(
                      color: AppColors.colorPrimary,
                      fontSize: 18,
                      fontFamily: AppColors.semiBold),
                ),
                Text(
                  "Bookings that have been canceled either by the customer or the service provider are categorized under this status.",
                  style: TextStyle(
                      color: themeChange.getTheme()
                          ? Colors.white
                          : AppColors.colorDark,
                      fontSize: 18,
                      fontFamily: AppColors.semiBold),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context); //close Dialog
              },
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }
}

class SubscriptionPlanWidget extends StatelessWidget {
  final VoidCallback onClick;
  final User userModel;

  const SubscriptionPlanWidget({
    super.key,
    required this.onClick,
    required this.userModel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
            color: isDarkMode(context)
                ? AppThemeData.grey800
                : AppThemeData.grey200),
        color: isDarkMode(context) ? AppThemeData.grey50 : AppThemeData.grey800,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
              bottom: 0,
              top: 10,
              child: Opacity(
                  opacity: 0.8,
                  child: Image.asset(
                    width: Responsive.width(100, context),
                    height: Responsive.height(100, context),
                    "assets/images/ic_gradient.png",
                    color: AppThemeData.secondary300,
                    fit: BoxFit.fill,
                  ))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipOval(
                      child: NetworkImageWidget(
                        imageUrl: userModel.subscriptionPlan?.image ?? '',
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userModel.subscriptionPlan?.name ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDarkMode(context)
                                        ? AppThemeData.grey900
                                        : AppThemeData.grey50,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: AppThemeData.semiBold,
                                  ),
                                ),
                                SizedBox(
                                  height: 35,
                                  child: SingleChildScrollView(
                                    child: Text(
                                      userModel.subscriptionPlan?.type == 'free'
                                          ? 'free'
                                          : amountShow(
                                              amount: userModel
                                                  .subscriptionPlan?.price),
                                      style: const TextStyle(
                                        fontFamily: AppThemeData.medium,
                                        fontSize: 12,
                                        color: AppThemeData.grey400,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Expiry Date'.tr,
                                style: TextStyle(
                                  fontFamily: AppThemeData.medium,
                                  fontSize: 12,
                                  color: isDarkMode(context)
                                      ? AppThemeData.grey900
                                      : AppThemeData.grey50,
                                ),
                              ),
                              Text(
                                userModel.subscriptionPlan?.expiryDay == "-1"
                                    ? "LifeTime"
                                    : timestampToDateTime(
                                        userModel.subscriptionExpiryDate!),
                                style: const TextStyle(
                                  fontFamily: AppThemeData.regular,
                                  fontSize: 12,
                                  color: AppThemeData.grey400,
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                RoundedButtonFill(
                  radius: 14,
                  textColor: AppThemeData.grey200,
                  title: "Change Plan".tr,
                  color: AppThemeData.secondary300,
                  width: 80,
                  height: 4,
                  onPress: onClick,
                ),
                if (selectedSectionModel?.adminCommision?.enable == true)
                  Visibility(
                    visible:
                        MyAppState.currentUser?.adminCommission?.enable == true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        "${MyAppState.currentUser?.adminCommission?.type == 'percentage' ? "${MyAppState.currentUser?.adminCommission?.commission}%" : "${amountShow(amount: MyAppState.currentUser?.adminCommission?.commission.toString())} Flat"} ${"admin commission will be charged from your account after the booking is accepted.".tr}",
                        style: const TextStyle(
                          fontFamily: AppThemeData.medium,
                          fontSize: 9,
                          color: AppThemeData.grey400,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

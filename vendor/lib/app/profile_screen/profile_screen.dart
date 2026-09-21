import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:vendor/app/change_password_screen/change_password_screen.dart';
import 'package:vendor/app/employee_role_screens/role_screen.dart';
import 'package:vendor/app/employee_screens/employee_list_screen.dart';
import 'package:vendor/app/help_support_screen/help_support_screen.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vendor/app/add_advertisement_screen/advertisement_list_screen.dart';
import 'package:vendor/app/add_restaurant_screen/add_restaurant_screen.dart';
import 'package:vendor/app/add_story_screen/add_story_screen.dart';
import 'package:vendor/app/auth_screen/login_screen.dart';
import 'package:vendor/app/change_language/change_language_screen.dart';
import 'package:vendor/app/dine_in_screen/dine_in_create_screen.dart';
import 'package:vendor/app/driver_screens/driver_list_screen.dart';
import 'package:vendor/app/edit_profile_screen/edit_profile_screen.dart';
import 'package:vendor/app/offer_screens/offer_screen.dart';
import 'package:vendor/app/special_discount_screen/special_discount_screen.dart';
import 'package:vendor/app/subscription_plan_screen/subscription_history_screen.dart';
import 'package:vendor/app/subscription_plan_screen/subscription_plan_screen.dart';
import 'package:vendor/app/terms_and_condition/terms_and_condition_screen.dart';
import 'package:vendor/app/verification_screen/verification_screen.dart';
import 'package:vendor/app/withdraw_method_setup_screens/withdraw_method_setup_screen.dart';
import 'package:vendor/app/working_hours_screen/working_hours_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/dash_board_controller.dart';
import 'package:vendor/controller/profile_controller.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/service/audio_player_service.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/custom_dialog_box.dart';
import 'package:vendor/themes/responsive.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/network_image_widget.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetX(
        init: ProfileController(),
        builder: (controller) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: AppThemeData.primary300,
              centerTitle: false,
              iconTheme: const IconThemeData(color: AppThemeData.grey50, size: 20),
              title: Text(
                "Store Profile".tr,
                style: TextStyle(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, fontSize: 18, fontFamily: AppThemeData.medium),
              ),
            ),
            body: controller.isLoading.value
                ? Constant.loader()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Row(
                              children: [
                                ClipOval(
                                  child: NetworkImageWidget(
                                    imageUrl: controller.userModel.value.profilePictureURL.toString(),
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorWidget: Image.asset("assets/images/user_placeholder.png"),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        controller.userModel.value.fullName(),
                                        style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500, fontSize: 18),
                                      ),
                                      Text(
                                        controller.userModel.value.email ?? '',
                                        style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w500, fontSize: 12),
                                      ),
                                      const SizedBox(height: 10),
                                      RoundedButtonFill(
                                        title: "Edit Profile".tr,
                                        color: AppThemeData.secondary50,
                                        textColor: AppThemeData.primary300,
                                        width: 50,
                                        height: 4,
                                        onPress: () async {
                                          Get.to(const EditProfileScreen())!.then((value) {
                                            if (value == true) {
                                              controller.getUserProfile();
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (Constant.isSubscriptionModelApplied == true || Constant.vendorAdminCommission?.isEnabled == true)
                            controller.userModel.value.subscriptionPlanId?.isNotEmpty == true
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: SubscriptionPlanWidget(
                                      onClick: () {
                                        Get.to(const SubscriptionPlanScreen(), arguments: {'isProfile': true})?.then((value) {
                                          if (value == true) {
                                            controller.getUserProfile();
                                          }
                                        });
                                      },
                                      userModel: controller.userModel.value,
                                    ),
                                  )
                                : SizedBox(),
                          if (Constant.getEmployeeRolePermission(module: "Add Story") == true ||
                              Constant.getEmployeeRolePermission(module: "Advertisement") == true ||
                              Constant.getEmployeeRolePermission(module: "Store Information's") == true ||
                              Constant.getEmployeeRolePermission(module: "Manage Products") == true ||
                              Constant.getEmployeeRolePermission(module: "Working Hours") == true ||
                              Constant.getEmployeeRolePermission(module: "Withdraw Method") == true)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Store Information".tr,
                                  style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: Responsive.width(100, context),
                                  decoration: ShapeDecoration(
                                    color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Column(
                                      children: [
                                        (controller.userModel.value.isAutoVerify == false && controller.userModel.value.isDocumentVerify == false) ||
                                                (controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty)
                                            ? const SizedBox()
                                            : Constant.storyEnable == false
                                            ? const SizedBox()
                                            : (Constant.getEmployeeRolePermission(module: "Add Story") == true)
                                            ? cardDecoration(
                                                isDark,
                                                controller,
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: ShapeDecoration(
                                                    color: isDark ? AppThemeData.secondary600 : AppThemeData.secondary50,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(10),
                                                    child: SvgPicture.asset("assets/icons/ic_story.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                                                  ),
                                                ),
                                                "Add Story",
                                                () {
                                                  Get.to(const AddStoryScreen());
                                                },
                                              )
                                            : SizedBox(),
                                        Visibility(
                                          visible: Constant.isEnableAdsFeature == true,
                                          child:
                                              (controller.userModel.value.isAutoVerify == false && controller.userModel.value.isDocumentVerify == false) ||
                                                  (controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty)
                                              ? const SizedBox()
                                              : Constant.storyEnable == false
                                              ? const SizedBox()
                                              : (Constant.getEmployeeRolePermission(module: "Advertisement") == true)
                                              ? cardDecoration(
                                                  isDark,
                                                  controller,
                                                  Container(
                                                    width: 44,
                                                    height: 44,
                                                    decoration: ShapeDecoration(
                                                      color: isDark ? AppThemeData.secondary600 : AppThemeData.secondary50,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(10),
                                                      child: SvgPicture.asset("assets/icons/ic_advertisement.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                                                    ),
                                                  ),
                                                  "Advertisement",
                                                  () {
                                                    Get.to(const AdvertisementListScreen());
                                                  },
                                                )
                                              : SizedBox(),
                                        ),
                                        (Constant.userModel?.isAutoVerify == false && Constant.userModel?.isDocumentVerify == false)
                                            ? const SizedBox()
                                            : (Constant.getEmployeeRolePermission(module: "Store Information's") == true)
                                            ? cardDecoration(
                                                isDark,
                                                controller,
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: ShapeDecoration(
                                                    color: isDark ? AppThemeData.secondary600 : AppThemeData.secondary50,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(10),
                                                    child: SvgPicture.asset("assets/icons/ic_building_two.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                                                  ),
                                                ),
                                                "Store Information's",
                                                () {
                                                  Get.to(const AddRestaurantScreen())?.then((v) {
                                                    controller.getUserProfile();
                                                  });
                                                },
                                              )
                                            : SizedBox(),
                                        (Constant.userModel?.isAutoVerify == false && Constant.userModel?.isDocumentVerify == false) ||
                                                (controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty)
                                            ? const SizedBox()
                                            : Constant.getEmployeeRolePermission(module: "Manage Products") == true
                                            ? cardDecoration(
                                                isDark,
                                                controller,
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: ShapeDecoration(
                                                    color: isDark ? AppThemeData.secondary600 : AppThemeData.secondary50,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(12),
                                                    child: SvgPicture.asset("assets/icons/ic_manage_product.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                                                  ),
                                                ),
                                                "Manage Products",
                                                () {
                                                  DashBoardController dashBoardController = Get.find<DashBoardController>();
                                                  if (controller.userModel.value.role == Constant.userRoleVendor) {
                                                    dashBoardController.selectedIndex.value = Constant.selectedSection!.dineInActive == true ? 2 : 1;
                                                  } else {
                                                    dashBoardController.selectedIndex.value =
                                                        Constant.getEmployeeRolePermission(module: "Dine in Request") == true && Constant.selectedSection?.dineInActive == true ? 2 : 1;
                                                  }
                                                },
                                              )
                                            : SizedBox(),
                                        Constant.selectedSection!.serviceTypeFlag == "ecommerce-service"
                                            ? SizedBox()
                                            : (Constant.userModel?.isAutoVerify == false && Constant.userModel?.isDocumentVerify == false) ||
                                                  (controller.userModel.value.vendorID == null || controller.userModel.value.vendorID?.isEmpty == true)
                                            ? const SizedBox()
                                            : (Constant.getEmployeeRolePermission(module: "Working Hours") == true)
                                            ? cardDecoration(
                                                isDark,
                                                controller,
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: ShapeDecoration(
                                                    color: isDark ? AppThemeData.secondary600 : AppThemeData.secondary50,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(10),
                                                    child: SvgPicture.asset("assets/icons/ic_alarm-clock.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                                                  ),
                                                ),
                                                "Working Hours",
                                                () {
                                                  Get.to(const WorkingHoursScreen());
                                                },
                                              )
                                            : SizedBox(),
                                        if (Constant.getEmployeeRolePermission(module: "Withdraw Method") == true)
                                          cardDecoration(
                                            isDark,
                                            controller,
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: ShapeDecoration(
                                                color: isDark ? AppThemeData.secondary600 : AppThemeData.secondary50,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(10),
                                                child: SvgPicture.asset("assets/icons/ic_wallet.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                                              ),
                                            ),
                                            "Withdraw Method",
                                            () {
                                              Get.to(const WithdrawMethodSetupScreen());
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          Constant.selectedSection!.serviceTypeFlag == "ecommerce-service"
                              ? SizedBox()
                              : Constant.isSelfDeliveryFeature == true && (Constant.getEmployeeRolePermission(module: "Manage Delivery Man") == true)
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 20),
                                    Text(
                                      "Delivery Man Information".tr,
                                      style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      width: Responsive.width(100, context),
                                      decoration: ShapeDecoration(
                                        color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Column(
                                          children: [
                                            cardDecoration(
                                              isDark,
                                              controller,
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: ShapeDecoration(
                                                  color: isDark ? AppThemeData.taxiBooking50 : AppThemeData.taxiBooking50.withAlpha(30),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(12),
                                                  child: SvgPicture.asset("assets/icons/ic_manage_delivery_man.svg", colorFilter: ColorFilter.mode(AppThemeData.taxiBooking400, BlendMode.srcIn)),
                                                ),
                                              ),
                                              "Manage Delivery Man",
                                              () {
                                                Get.to(DriverListScreen());
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : SizedBox(),
                          (Constant.isEmployeeManagement == false ||
                                  (Constant.getEmployeeRolePermission(module: "Employee Role") == false) && (Constant.getEmployeeRolePermission(module: "All Employee") == false))
                              ? SizedBox()
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 20),
                                    Text(
                                      "Employee Management".tr,
                                      style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      width: Responsive.width(100, context),
                                      decoration: ShapeDecoration(
                                        color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Column(
                                          children: [
                                            if (Constant.getEmployeeRolePermission(module: "Employee Role") == true)
                                              cardDecoration(
                                                isDark,
                                                controller,
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: ShapeDecoration(
                                                    color: isDark ? AppThemeData.info600 : AppThemeData.info50,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(12),
                                                    child: SvgPicture.asset("assets/icons/ic_manage_delivery_man.svg", colorFilter: ColorFilter.mode(AppThemeData.info400, BlendMode.srcIn)),
                                                  ),
                                                ),
                                                "Employee Role",
                                                () {
                                                  Get.to(const RoleScreen());
                                                },
                                              ),
                                            if (Constant.getEmployeeRolePermission(module: "All Employee") == true)
                                              cardDecoration(
                                                isDark,
                                                controller,
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: ShapeDecoration(
                                                    color: isDark ? AppThemeData.info600 : AppThemeData.info50,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(12),
                                                    child: SvgPicture.asset("assets/icons/ic_employee.svg", colorFilter: ColorFilter.mode(AppThemeData.info400, BlendMode.srcIn)),
                                                  ),
                                                ),
                                                "All Employee",
                                                () {
                                                  Get.to(EmployeeListScreen());
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                          (Constant.userModel?.isAutoVerify == false && Constant.userModel?.isDocumentVerify == false) ||
                                  (controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty) ||
                                  ((Constant.getEmployeeRolePermission(module: "Add Dine in") == false) && (Constant.getEmployeeRolePermission(module: "Dine in Request") == false))
                              ? const SizedBox()
                              : Constant.selectedSection!.dineInActive == true &&
                                    ((Constant.getEmployeeRolePermission(module: "Add Dine in") == true || Constant.getEmployeeRolePermission(module: "Dine in Request") == true))
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 20),
                                    Text(
                                      "Dine-in Information".tr,
                                      style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      width: Responsive.width(100, context),
                                      decoration: ShapeDecoration(
                                        color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Column(
                                          children: [
                                            if (Constant.getEmployeeRolePermission(module: "Add Dine in") == true)
                                              cardDecoration(
                                                isDark,
                                                controller,
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: ShapeDecoration(
                                                    color: isDark ? AppThemeData.primary600 : AppThemeData.primary50,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                  ),
                                                  child: Padding(padding: const EdgeInsets.all(10), child: SvgPicture.asset("assets/icons/ic_knife_fork.svg")),
                                                ),
                                                "Dine in Store",
                                                () {
                                                  Get.to(const DineInCreateScreen());
                                                },
                                              ),
                                            if (Constant.getEmployeeRolePermission(module: "Dine in Request") == true)
                                              cardDecoration(
                                                isDark,
                                                controller,
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: ShapeDecoration(
                                                    color: isDark ? AppThemeData.primary600 : AppThemeData.primary50,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                  ),
                                                  child: Padding(padding: const EdgeInsets.all(10), child: SvgPicture.asset("assets/icons/ic_people-unknown.svg")),
                                                ),
                                                "Dine in Requests",
                                                () {
                                                  DashBoardController dashBoardController = Get.find<DashBoardController>();
                                                  dashBoardController.selectedIndex.value = 1;
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox(),
                          if ((Constant.getEmployeeRolePermission(module: "Subscription Packages") == true) || (Constant.getEmployeeRolePermission(module: "Subscription History") == true))
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                Text(
                                  "Subscription Management".tr,
                                  style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: Responsive.width(100, context),
                                  decoration: ShapeDecoration(
                                    color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Column(
                                      children: [
                                        ((Constant.isSubscriptionModelApplied == true && controller.userModel.value.role != Constant.userRoleEmployee) &&
                                                Constant.getEmployeeRolePermission(module: "Subscription Packages") == true)
                                            ? cardDecoration(
                                                isDark,
                                                controller,
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: ShapeDecoration(
                                                    color: isDark ? AppThemeData.success50 : AppThemeData.success50,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                  ),
                                                  child: Padding(padding: const EdgeInsets.all(10), child: SvgPicture.asset("assets/icons/ic_subscription.svg")),
                                                ),
                                                "Subscription Packages",
                                                () {
                                                  Get.to(const SubscriptionPlanScreen(), arguments: {'isProfile': true})?.then((value) {
                                                    if (value == true) {
                                                      controller.getUserProfile();
                                                    }
                                                  });
                                                },
                                              )
                                            : SizedBox(),
                                        if (Constant.getEmployeeRolePermission(module: "Subscription History") == true)
                                          cardDecoration(
                                            isDark,
                                            controller,
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: ShapeDecoration(
                                                color: isDark ? AppThemeData.success50 : AppThemeData.success50,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                              ),
                                              child: Padding(padding: const EdgeInsets.all(10), child: SvgPicture.asset("assets/icons/ic_history.svg")),
                                            ),
                                            "Subscription History",
                                            () {
                                              Get.to(const SubscriptionHistoryScreen());
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          (Constant.userModel?.isAutoVerify == false && Constant.userModel?.isDocumentVerify == false) ||
                                  (controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty)
                              ? const SizedBox()
                              : ((Constant.getEmployeeRolePermission(module: "Offers") == true) || (Constant.getEmployeeRolePermission(module: "Special Discounts") == true))
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 20),
                                    Text(
                                      "Offers & Discounts".tr,
                                      style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      width: Responsive.width(100, context),
                                      decoration: ShapeDecoration(
                                        color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Column(
                                          children: [
                                            if (Constant.getEmployeeRolePermission(module: "Offers") == true)
                                              cardDecoration(
                                                isDark,
                                                controller,
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: ShapeDecoration(
                                                    color: isDark ? AppThemeData.success600 : AppThemeData.success50,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                  ),
                                                  child: Padding(padding: const EdgeInsets.all(10), child: SvgPicture.asset("assets/icons/ic_gift_box.svg")),
                                                ),
                                                "Offers",
                                                () {
                                                  Get.to(const OfferScreen());
                                                },
                                              ),

                                            if (Constant.specialDiscountOfferEnable == true && (Constant.getEmployeeRolePermission(module: "Special Discounts") == true))
                                              cardDecoration(
                                                isDark,
                                                controller,
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: ShapeDecoration(
                                                    color: isDark ? AppThemeData.success600 : AppThemeData.success50,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                  ),
                                                  child: Padding(padding: const EdgeInsets.all(10), child: SvgPicture.asset("assets/icons/ic_coupon.svg")),
                                                ),
                                                "Special Discounts",
                                                () {
                                                  Get.to(const SpecialDiscountScreen());
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : SizedBox(),
                          const SizedBox(height: 20),
                          Text(
                            "Preferences".tr,
                            style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: Responsive.width(100, context),
                            decoration: ShapeDecoration(
                              color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Column(
                                children: [
                                  cardDecoration(
                                    isDark,
                                    controller,
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: ShapeDecoration(
                                        color: isDark ? AppThemeData.warning600 : AppThemeData.warning50,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                      ),
                                      child: Padding(padding: const EdgeInsets.all(10), child: SvgPicture.asset("assets/icons/ic_language.svg")),
                                    ),
                                    "Change Language",
                                    () {
                                      Get.to(const ChangeLanguageScreen());
                                    },
                                  ),
                                  cardDecoration(
                                    isDark,
                                    controller,
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: ShapeDecoration(
                                        color: isDark ? AppThemeData.warning600 : AppThemeData.warning50,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                      ),
                                      child: Padding(padding: const EdgeInsets.all(10), child: SvgPicture.asset("assets/icons/ic_darkmode.svg")),
                                    ),
                                    "Dark Mode",
                                    () {},
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Social".tr,
                            style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: Responsive.width(100, context),
                            decoration: ShapeDecoration(
                              color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Column(
                                children: [
                                  cardDecoration(
                                    isDark,
                                    controller,
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: ShapeDecoration(
                                        color: isDark ? AppThemeData.info600 : AppThemeData.info50,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                      ),
                                      child: Padding(padding: const EdgeInsets.all(10), child: SvgPicture.asset("assets/icons/ic_share.svg")),
                                    ),
                                    "Share app",
                                    () {
                                      Share.share(
                                        '${"Check out Foodie, your ultimate food delivery application! \n\nGoogle Play:".tr} ${Constant.googlePlayLink} ${"\n\nApp Store:".tr} ${Constant.appStoreLink}',
                                        subject: 'Look what I made!'.tr,
                                      );
                                    },
                                  ),
                                  cardDecoration(
                                    isDark,
                                    controller,
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: ShapeDecoration(
                                        color: isDark ? AppThemeData.info600 : AppThemeData.info50,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                      ),
                                      child: Padding(padding: const EdgeInsets.all(10), child: SvgPicture.asset("assets/icons/ic_rate.svg")),
                                    ),
                                    "Rate the app",
                                    () {
                                      final InAppReview inAppReview = InAppReview.instance;
                                      inAppReview.requestReview();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Legal".tr,
                            style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 10),

                          Container(
                            width: Responsive.width(100, context),
                            decoration: ShapeDecoration(
                              color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: (Constant.userModel?.isAutoVerify == false && Constant.userModel?.isDocumentVerify == false) ? 8 : 0),
                              child: Column(
                                children: [
                                  if (controller.userModel.value.isAutoVerify == false)
                                    cardDecoration(
                                      isDark,
                                      controller,
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: ShapeDecoration(
                                          color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                        ),
                                        child: Padding(padding: const EdgeInsets.all(10), child: SvgPicture.asset("assets/icons/ic_documention.svg")),
                                      ),
                                      "Document Verifications".tr,
                                      () {
                                        Get.to(const VerificationScreen());
                                      },
                                    ),
                                  cardDecoration(
                                    isDark,
                                    controller,
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: ShapeDecoration(
                                        color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: SvgPicture.asset("assets/icons/ic_help_support.svg", color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                                      ),
                                    ),
                                    "Help & Support".tr,
                                    () {
                                      Get.to(HelpSupportScreen(isNavigateViaNotification: false));
                                    },
                                  ),

                                  cardDecoration(
                                    isDark,
                                    controller,
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: ShapeDecoration(
                                        color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                      ),
                                      child: Padding(padding: const EdgeInsets.all(10), child: SvgPicture.asset("assets/icons/ic_terms_condition.svg")),
                                    ),
                                    "Terms and Conditions",
                                    () {
                                      Get.to(const TermsAndConditionScreen(type: "termAndCondition"));
                                    },
                                  ),

                                  cardDecoration(
                                    isDark,
                                    controller,
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: ShapeDecoration(
                                        color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                      ),
                                      child: Padding(padding: const EdgeInsets.all(10), child: SvgPicture.asset("assets/icons/ic_privacyPolicy.svg")),
                                    ),
                                    "Privacy Policy",
                                    () {
                                      Get.to(const TermsAndConditionScreen(type: "privacy"));
                                    },
                                  ),
                                  if (Constant.userModel?.provider == 'email')
                                    cardDecoration(
                                      isDark,
                                      controller,
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: ShapeDecoration(
                                          color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                        ),
                                        child: Padding(padding: const EdgeInsets.all(10), child: SvgPicture.asset("assets/icons/ic_lock.svg")),
                                      ),
                                      "Change Password",
                                      () {
                                        Get.to(const ChangePasswordScreen());
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: Responsive.width(100, context),
                            decoration: ShapeDecoration(
                              color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Column(
                                children: [
                                  cardDecoration(isDark, controller, SvgPicture.asset("assets/icons/ic_logout.svg"), "Log out", () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return CustomDialogBox(
                                          title: "Log out".tr,
                                          descriptions: "Are you sure you want to log out? You will need to enter your credentials to log back in.".tr,
                                          positiveString: "Log out".tr,
                                          negativeString: "Cancel".tr,
                                          positiveClick: () async {
                                            ShowToastDialog.showLoader("Please wait".tr);
                                            await AudioPlayerService.playSound(false);
                                            Constant.userModel!.fcmToken = "";
                                            await FireStoreUtils.updateUser(Constant.userModel!);
                                            Constant.userModel = null;
                                            await FirebaseAuth.instance.signOut();
                                            ShowToastDialog.closeLoader();
                                            Get.offAll(const LoginScreen());
                                          },
                                          negativeClick: () {
                                            Get.back();
                                          },
                                          img: Image.asset('assets/images/ic_logout.gif', height: 50, width: 50),
                                        );
                                      },
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return CustomDialogBox(
                                      title: "Delete Account".tr,
                                      descriptions: "Are you sure you want to delete your account? This action is irreversible and will permanently remove all your data.".tr,
                                      positiveString: "Delete".tr,
                                      negativeString: "Cancel".tr,
                                      positiveClick: () async {
                                        ShowToastDialog.showLoader("Please wait".tr);
                                        await controller.deleteUserFromServer();
                                        await FireStoreUtils.deleteUser().then((value) {
                                          ShowToastDialog.closeLoader();
                                          if (value == true) {
                                            ShowToastDialog.showToast("Account deleted successfully".tr);
                                            Get.offAll(const LoginScreen());
                                          } else {
                                            ShowToastDialog.showToast("Contact Administrator".tr);
                                          }
                                        });
                                      },
                                      negativeClick: () {
                                        Get.back();
                                      },
                                      img: Image.asset('assets/icons/delete_dialog.gif', height: 50, width: 50),
                                    );
                                  },
                                );
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SvgPicture.asset("assets/icons/ic_delete.svg"),
                                  const SizedBox(width: 10),
                                  Text(
                                    "Delete Account".tr,
                                    textAlign: TextAlign.start,
                                    style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: isDark ? AppThemeData.danger300 : AppThemeData.danger300),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              "V : ${Constant.appVersion}",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          );
        },
      );
    });
  }

  Padding cardDecoration(isDark, ProfileController controller, Widget image, String title, Function()? onPress) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          onPress!();
        },
        child: Row(
          children: [
            image,
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title.tr,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontFamily: AppThemeData.medium,
                  fontSize: 16,
                  color: title == "Log out"
                      ? AppThemeData.danger300
                      : isDark
                      ? AppThemeData.grey100
                      : AppThemeData.grey800,
                ),
              ),
            ),
            title == "Dark Mode"
                ? Transform.scale(
                    scale: 0.8,
                    child: CupertinoSwitch(
                      value: controller.isDarkModeSwitch.value,
                      activeTrackColor: AppThemeData.primary300,
                      onChanged: (value) {
                        controller.toggleDarkMode(value);
                      },
                    ),
                  )
                : const Icon(Icons.keyboard_arrow_right),
          ],
        ),
      ),
    );
  }
}

class SubscriptionPlanWidget extends StatelessWidget {
  final VoidCallback onClick;
  final UserModel userModel;

  const SubscriptionPlanWidget({super.key, required this.onClick, required this.userModel});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? AppThemeData.grey800 : AppThemeData.grey200),
        color: isDark ? AppThemeData.grey50 : AppThemeData.grey800,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            top: 10,
            child: Opacity(
              opacity: 0.8,
              child: Image.asset(width: Responsive.width(100, context), height: Responsive.height(100, context), "assets/images/ic_gradient.png", color: AppThemeData.primary300, fit: BoxFit.fill),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    NetworkImageWidget(imageUrl: userModel.subscriptionPlan?.image ?? '', fit: BoxFit.cover, width: 50, height: 50),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userModel.subscriptionPlan?.name ?? '',
                                style: TextStyle(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: AppThemeData.semiBold),
                              ),
                              Text(
                                userModel.subscriptionPlan?.type == 'free' ? userModel.subscriptionPlan?.description ?? '' : Constant.amountShow(amount: userModel.subscriptionPlan?.price),
                                style: const TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: AppThemeData.grey400),
                              ),
                            ],
                          ),
                          if (userModel.subscriptionPlan?.type == 'paid')
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Expiry Date'.tr,
                                  style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 12, color: isDark ? AppThemeData.grey900 : AppThemeData.grey50),
                                ),
                                Text(
                                  userModel.subscriptionPlan!.expiryDay == "-1" ? "LifeTime" : Constant.timestampToDate(userModel.subscriptionExpiryDate!),
                                  style: const TextStyle(fontFamily: AppThemeData.regular, fontSize: 12, color: AppThemeData.grey400),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                RoundedButtonFill(radius: 14, textColor: AppThemeData.grey200, title: "Change Plan".tr, color: AppThemeData.primary300, width: 80, height: 5, onPress: onClick),
                if (Constant.selectedSection!.adminCommision?.isEnabled == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      Constant.userModel!.vendorID != null && Constant.userModel!.vendorID!.isNotEmpty
                          ? "${Constant.vendorAdminCommission?.commissionType == 'Percent' || Constant.vendorAdminCommission?.commissionType == 'percentage' ? "${Constant.vendorAdminCommission?.amount} %" : "${Constant.amountShow(amount: Constant.vendorAdminCommission?.amount)} "}${'Flat'.tr} ${"admin commission will be charged from customer billing orders and the admin charge will be earned after the order is accepted by the store.".tr}"
                          : "${Constant.selectedSection!.adminCommision!.commissionType == 'Percent' || Constant.selectedSection!.adminCommision!.commissionType == 'percentage' ? "${Constant.selectedSection!.adminCommision!.amount} %" : "${Constant.amountShow(amount: Constant.selectedSection!.adminCommision!.amount)} Flat"} ${"admin commission will be charged from customer billing orders and the admin charge will be earned after the order is accepted by the store.".tr}",
                      style: const TextStyle(fontFamily: AppThemeData.medium, fontSize: 9, color: AppThemeData.grey400),
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

import 'package:driver/app/auth_screen/login_screen.dart';
import 'package:driver/app/change_language/change_language_screen.dart';
import 'package:driver/app/chat_screens/driver_inbox_screen.dart';
import 'package:driver/app/change_section_screen/change_section_screen.dart';
import 'package:driver/app/edit_profile_screen/edit_profile_screen.dart';
import 'package:driver/app/parcel_screen/parcel_home_screen.dart';
import 'package:driver/app/parcel_screen/parcel_order_list_screen.dart';
import 'package:driver/app/terms_and_condition/terms_and_condition_screen.dart';
import 'package:driver/app/verification_screen/verification_screen.dart';
import 'package:driver/app/wallet_screen/wallet_screen.dart';
import 'package:driver/app/withdraw_method_setup_screens/withdraw_method_setup_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart' show ShowToastDialog;
import 'package:driver/controllers/parcel_dashboard_controller.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/custom_dialog_box.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/network_image_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';

class ParcelDashboardScreen extends StatelessWidget {
  const ParcelDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetX(
        init: ParcelDashboardController(),
        builder: (controller) {
          return Scaffold(
            drawerEnableOpenDragGesture: false,
            appBar: AppBar(
              //backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
              titleSpacing: 5,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome Back 👋'.tr,
                    style: TextStyle(
                      color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                      fontSize: 12,
                      fontFamily: AppThemeData.medium,
                    ),
                  ),
                  Text(
                    Constant.userModel!.fullName().tr,
                    style: TextStyle(
                      color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                      fontSize: 14,
                      fontFamily: AppThemeData.semiBold,
                    ),
                  )
                ],
              ),
              actions: [
                Constant.userModel!.ownerId != null && Constant.userModel!.ownerId!.isNotEmpty
                    ? SizedBox()
                    : InkWell(
                        onTap: () {
                          Get.to(const WalletScreen(isAppBarShow: true));
                        },
                        child: SvgPicture.asset("assets/icons/ic_wallet_home.svg")),
                const SizedBox(
                  width: 10,
                ),
                InkWell(
                    onTap: () {
                      Get.to(const EditProfileScreen());
                    },
                    child: SvgPicture.asset("assets/icons/ic_user_business.svg")),
                const SizedBox(
                  width: 10,
                ),
              ],
              leading: Builder(builder: (context) {
                return InkWell(
                  onTap: () {
                    Scaffold.of(context).openDrawer();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Container(
                        decoration: ShapeDecoration(
                          color: isDark ? AppThemeData.carRent600 : AppThemeData.carRent50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(120),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: SvgPicture.asset("assets/icons/ic_drawer_open.svg"),
                        )),
                  ),
                );
              }),
            ),
            drawer: const DrawerView(),
            body: controller.drawerIndex.value == 0
                ? const ParcelHomeScreen()
                : controller.drawerIndex.value == 1
                    ? ParcelOrderListScreen()
                    : controller.drawerIndex.value == 2
                        ? const WalletScreen(
                            isAppBarShow: false,
                          )
                        : controller.drawerIndex.value == 3
                            ? const WithdrawMethodSetupScreen()
                            : controller.drawerIndex.value == 4
                                ? const VerificationScreen()
                                : controller.drawerIndex.value == 5
                                    ? const DriverInboxScreen()
                                    : controller.drawerIndex.value == 6
                                        ? const ChangeLanguageScreen()
                                        : controller.drawerIndex.value == 7
                                            ? const TermsAndConditionScreen(type: "temsandcondition")
                                            : controller.drawerIndex.value == 8
                                                ? const TermsAndConditionScreen(type: "privacy")
                                                : TermsAndConditionScreen(),
          );
        },
      );
    });
  }
}

class DrawerView extends StatelessWidget {
  const DrawerView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetX(
          init: ParcelDashboardController(),
          builder: (controller) {
            return Drawer(
              backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
              child: Padding(
                padding: EdgeInsets.only(top: MediaQuery.of(context).viewPadding.top + 20, left: 16, right: 16),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    Row(
                      children: [
                        ClipOval(
                          child: NetworkImageWidget(
                            imageUrl: Constant.userModel == null ? "" : Constant.userModel!.profilePictureURL.toString(),
                            height: 55,
                            width: 55,
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Constant.userModel!.fullName().tr,
                                style: TextStyle(
                                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                  fontSize: 18,
                                  fontFamily: AppThemeData.semiBold,
                                ),
                              ),
                              Text(
                                '${Constant.userModel!.email}'.tr,
                                style: TextStyle(
                                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                  fontSize: 14,
                                  fontFamily: AppThemeData.regular,
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    ListTile(
                      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                      contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0),
                      trailing: Transform.scale(
                        scale: 0.8,
                        child: CupertinoSwitch(
                          value: controller.userModel.value.isActive ?? false,
                          activeTrackColor: AppThemeData.primary300,
                          onChanged: (value) async {
                            if (Constant.userModel?.isAutoVerify == false) {
                              if (controller.userModel.value.isDocumentVerify == true) {
                                controller.userModel.value.isActive = value;
                                if (controller.userModel.value.isActive == true) {
                                  controller.updateCurrentLocation();
                                }
                                await FireStoreUtils.updateUser(controller.userModel.value);
                              } else {
                                ShowToastDialog.showToast("Document verification is pending. Please proceed to set up your document verification.".tr);
                              }
                            } else {
                              controller.userModel.value.isActive = value;
                              if (controller.userModel.value.isActive == true) {
                                controller.updateCurrentLocation();
                              }
                              await FireStoreUtils.updateUser(controller.userModel.value);
                            }
                          },
                        ),
                      ),
                      dense: true,
                      title: Text(
                        'Available Status'.tr,
                        style: TextStyle(
                          color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                          fontFamily: AppThemeData.semiBold,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'About App'.tr,
                        style: TextStyle(
                          color: isDark ? AppThemeData.grey400 : AppThemeData.grey500,
                          fontSize: 12,
                          fontFamily: AppThemeData.medium,
                        ),
                      ),
                    ),
                    ListTile(
                      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                      contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0),
                      leading: SvgPicture.asset(
                        "assets/icons/ic_home_add.svg",
                        width: 20,
                      ),
                      trailing: const Icon(Icons.keyboard_arrow_right_rounded, size: 24),
                      dense: true,
                      title: Text(
                        'Home'.tr,
                        style: TextStyle(
                          color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                          fontFamily: AppThemeData.semiBold,
                        ),
                      ),
                      onTap: () {
                        Get.back();
                        controller.drawerIndex.value = 0;
                      },
                    ),
                    if ((Constant.userModel?.ownerId ?? '').isEmpty && (Constant.userModel?.vendorID ?? '').isEmpty)
                      ListTile(
                        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                        contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0),
                        leading: SvgPicture.asset(
                          "assets/icons/ic_view_grid_list.svg",
                          width: 20,
                          colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn),
                        ),
                        trailing: const Icon(Icons.keyboard_arrow_right_rounded, size: 24),
                        dense: true,
                        title: Text(
                          'Change Section'.tr,
                          style: TextStyle(
                            color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                            fontFamily: AppThemeData.semiBold,
                          ),
                        ),
                        onTap: () {
                          Get.back();
                          Get.to(() => const ChangeSectionScreen());
                        },
                      ),
                    ListTile(
                      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                      contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0),
                      leading: SvgPicture.asset(
                        "assets/icons/ic_shoping_cart.svg",
                        colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn),
                      ),
                      trailing: const Icon(Icons.keyboard_arrow_right_rounded, size: 24),
                      dense: true,
                      title: Text(
                        'Orders'.tr,
                        style: TextStyle(
                          color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                          fontFamily: AppThemeData.semiBold,
                        ),
                      ),
                      onTap: () {
                        Get.back();
                        controller.drawerIndex.value = 1;
                      },
                    ),
                    Constant.userModel!.ownerId != null && Constant.userModel!.ownerId!.isNotEmpty
                        ? SizedBox()
                        : ListTile(
                            visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0),
                            leading: SvgPicture.asset(
                              "assets/icons/ic_wallet.svg",
                              colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn),
                            ),
                            trailing: const Icon(Icons.keyboard_arrow_right_rounded, size: 24),
                            dense: true,
                            title: Text(
                              'Wallet'.tr,
                              style: TextStyle(
                                color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                                fontFamily: AppThemeData.semiBold,
                              ),
                            ),
                            onTap: () {
                              Get.back();
                              controller.drawerIndex.value = 2;
                            },
                          ),
                    Constant.userModel!.ownerId != null && Constant.userModel!.ownerId!.isNotEmpty
                        ? SizedBox()
                        : ListTile(
                            visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0),
                            leading: SvgPicture.asset(
                              "assets/icons/ic_settings.svg",
                            ),
                            trailing: const Icon(Icons.keyboard_arrow_right_rounded, size: 24),
                            dense: true,
                            title: Text(
                              'Withdrawal Method'.tr,
                              style: TextStyle(
                                color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                                fontFamily: AppThemeData.semiBold,
                              ),
                            ),
                            onTap: () {
                              Get.back();
                              controller.drawerIndex.value = 3;
                            },
                          ),
                    (((Constant.userModel?.ownerId == null || Constant.userModel!.ownerId!.isEmpty) && Constant.userModel?.isAutoVerify == false) &&
                            !((Constant.userModel?.ownerId != null && Constant.userModel!.ownerId!.isNotEmpty) && Constant.userModel?.isAutoVerify == false))
                        ? ListTile(
                            visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                            contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0),
                            leading: SvgPicture.asset("assets/icons/ic_notes.svg"),
                            trailing: const Icon(Icons.keyboard_arrow_right_rounded, size: 24),
                            dense: true,
                            title: Text(
                              'Document Verification'.tr,
                              style: TextStyle(
                                color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                                fontFamily: AppThemeData.semiBold,
                              ),
                            ),
                            onTap: () {
                              Get.back();
                              controller.drawerIndex.value = 4;
                            },
                          )
                        : SizedBox.shrink(),
                    ListTile(
                      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                      contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0),
                      leading: SvgPicture.asset(
                        "assets/icons/ic_chat.svg",
                      ),
                      trailing: const Icon(Icons.keyboard_arrow_right_rounded, size: 24),
                      dense: true,
                      title: Text(
                        'Inbox'.tr,
                        style: TextStyle(
                          color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                          fontFamily: AppThemeData.semiBold,
                        ),
                      ),
                      onTap: () {
                        Get.back();
                        controller.drawerIndex.value = 5;
                      },
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'App Preferences'.tr,
                        style: TextStyle(
                          color: isDark ? AppThemeData.grey400 : AppThemeData.grey500,
                          fontSize: 12,
                          fontFamily: AppThemeData.medium,
                        ),
                      ),
                    ),
                    ListTile(
                      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                      contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0),
                      leading: SvgPicture.asset(
                        "assets/icons/ic_change_language.svg",
                      ),
                      trailing: const Icon(Icons.keyboard_arrow_right_rounded, size: 24),
                      dense: true,
                      title: Text(
                        'Change Language'.tr,
                        style: TextStyle(
                          color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                          fontFamily: AppThemeData.semiBold,
                        ),
                      ),
                      onTap: () {
                        Get.back();
                        controller.drawerIndex.value = 6;
                      },
                    ),
                    ListTile(
                      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                      contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0),
                      leading: SvgPicture.asset(
                        "assets/icons/ic_light_dark.svg",
                      ),
                      trailing: Transform.scale(
                        scale: 0.8,
                        child: CupertinoSwitch(
                          value: controller.isDarkModeSwitch.value,
                          activeTrackColor: AppThemeData.primary300,
                          onChanged: (value) {
                            controller.toggleDarkMode(value);
                          },
                        ),
                      ),
                      dense: true,
                      title: Text(
                        'Dark Mode'.tr,
                        style: TextStyle(
                          color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                          fontFamily: AppThemeData.semiBold,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Social'.tr,
                        style: TextStyle(
                          color: isDark ? AppThemeData.grey400 : AppThemeData.grey500,
                          fontSize: 12,
                          fontFamily: AppThemeData.medium,
                        ),
                      ),
                    ),
                    ListTile(
                      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                      contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0),
                      leading: SvgPicture.asset(
                        "assets/icons/ic_share.svg",
                      ),
                      trailing: const Icon(Icons.keyboard_arrow_right_rounded, size: 24),
                      dense: true,
                      title: Text(
                        'Share app'.tr,
                        style: TextStyle(
                          color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                          fontFamily: AppThemeData.semiBold,
                        ),
                      ),
                      onTap: () {
                        Get.back();
                        Share.share(
                            '${'Check out spideli, your ultimate food delivery application!'.tr} \n\n${'Google Play:'.tr} ${Constant.googlePlayLink} \n\n${'App Store:'.tr} ${Constant.appStoreLink}',
                            subject: 'Look what I made!'.tr);
                      },
                    ),
                    ListTile(
                      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                      contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0),
                      leading: SvgPicture.asset(
                        "assets/icons/ic_rate.svg",
                      ),
                      trailing: const Icon(Icons.keyboard_arrow_right_rounded, size: 24),
                      dense: true,
                      title: Text(
                        'Rate the app'.tr,
                        style: TextStyle(
                          color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                          fontFamily: AppThemeData.semiBold,
                        ),
                      ),
                      onTap: () {
                        Get.back();
                        final InAppReview inAppReview = InAppReview.instance;
                        inAppReview.requestReview();
                      },
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Legal'.tr,
                        style: TextStyle(
                          color: isDark ? AppThemeData.grey400 : AppThemeData.grey500,
                          fontSize: 12,
                          fontFamily: AppThemeData.medium,
                        ),
                      ),
                    ),
                    ListTile(
                      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                      contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0),
                      leading: SvgPicture.asset(
                        "assets/icons/ic_terms_condition.svg",
                        colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn),
                      ),
                      trailing: const Icon(Icons.keyboard_arrow_right_rounded, size: 24),
                      dense: true,
                      title: Text(
                        'Terms and Conditions'.tr,
                        style: TextStyle(
                          color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                          fontFamily: AppThemeData.semiBold,
                        ),
                      ),
                      onTap: () {
                        Get.back();
                        controller.drawerIndex.value = 7;
                      },
                    ),
                    ListTile(
                      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                      contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0),
                      leading: SvgPicture.asset(
                        "assets/icons/ic_privacyPolicy.svg",
                        colorFilter: const ColorFilter.mode(AppThemeData.danger300, BlendMode.srcIn),
                      ),
                      trailing: const Icon(Icons.keyboard_arrow_right_rounded, size: 24),
                      dense: true,
                      title: Text(
                        'Privacy Policy'.tr,
                        style: TextStyle(
                          color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                          fontFamily: AppThemeData.semiBold,
                        ),
                      ),
                      onTap: () {
                        Get.back();
                        controller.drawerIndex.value = 8;
                      },
                    ),
                    if (Constant.userModel?.provider != 'apple' && Constant.userModel?.provider != 'google')
                      ListTile(
                        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                        contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0),
                        leading: SvgPicture.asset(
                          "assets/icons/ic_mail.svg",
                          colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn),
                        ),
                        trailing: const Icon(Icons.keyboard_arrow_right_rounded, size: 24),
                        dense: true,
                        title: Text(
                          'Change Password'.tr,
                          style: TextStyle(
                            color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                            fontFamily: AppThemeData.semiBold,
                          ),
                        ),
                        onTap: () {
                          Get.back();
                          controller.drawerIndex.value = 9;
                        },
                      ),
                    const SizedBox(
                      height: 10,
                    ),
                    ListTile(
                      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                      contentPadding: const EdgeInsets.only(left: 0.0, right: 0.0),
                      leading: SvgPicture.asset(
                        "assets/icons/ic_logout.svg",
                        colorFilter: const ColorFilter.mode(AppThemeData.danger300, BlendMode.srcIn),
                      ),
                      trailing: const Icon(
                        Icons.keyboard_arrow_right_rounded,
                        size: 24,
                        color: AppThemeData.danger300,
                      ),
                      dense: true,
                      title: Text(
                        'Log out'.tr,
                        style: TextStyle(
                          color: isDark ? AppThemeData.danger300 : AppThemeData.danger300,
                          fontFamily: AppThemeData.semiBold,
                        ),
                      ),
                      onTap: () {
                        Get.back();
                        showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return CustomDialogBox(
                                title: "Log out".tr,
                                descriptions: "Are you sure you want to log out? You will need to enter your credentials to log back in.".tr,
                                positiveString: "Log out".tr,
                                negativeString: "Cancel".tr,
                                positiveClick: () async {
                                  await AudioPlayerService.playSound(false);
                                  Constant.userModel!.fcmToken = "";
                                  await FireStoreUtils.updateUser(Constant.userModel!);
                                  await FirebaseAuth.instance.signOut();
                                  Get.offAll(const LoginScreen());
                                },
                                negativeClick: () {
                                  Get.back();
                                },
                                img: Image.asset(
                                  'assets/images/ic_logout.gif',
                                  height: 50,
                                  width: 50,
                                ),
                              );
                            });
                      },
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    InkWell(
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
                                img: Image.asset(
                                  'assets/icons/delete_dialog.gif',
                                  height: 50,
                                  width: 50,
                                ),
                              );
                            });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            "assets/icons/ic_delete.svg",
                            colorFilter: const ColorFilter.mode(AppThemeData.danger300, BlendMode.srcIn),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Text(
                            'Delete Account'.tr,
                            style: TextStyle(
                              color: isDark ? AppThemeData.danger300 : AppThemeData.danger300,
                              fontFamily: AppThemeData.semiBold,
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Center(
                      child: Text(
                        "V : ${Constant.appVersion}",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppThemeData.medium,
                          fontSize: 14,
                          color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                  ],
                ),
              ),
            );
          });
    });
  }
}

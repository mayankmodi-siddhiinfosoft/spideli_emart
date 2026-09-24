import 'package:driver/app/parcel_screen/parcel_tracking/parcel_run_screen.dart';
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
import 'package:driver/themes/custom_dialog_box.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';

/// Parcel service shell (archetype K): a DS app bar with the driver's greeting
/// and quick actions over the selected drawer destination.
class ParcelDashboardScreen extends StatelessWidget {
  const ParcelDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      // The theme observable read must stay inside this Obx: it is what
      // rebuilds the shell when the driver switches light / dark mode.
      themeController.isDark.value;
      return GetX(
        init: ParcelDashboardController(),
        builder: (controller) {
          final c = context.dsColors;
          final t = context.dsText;
          return Scaffold(
            backgroundColor: c.background,
            drawerEnableOpenDragGesture: false,
            appBar: DsAppBar(
              titleWidget: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome Back 👋'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption,
                  ),
                  Text(
                    Constant.userModel!.fullName().tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSm.w700,
                  ),
                ],
              ),
              actions: [
                Constant.userModel!.ownerId != null && Constant.userModel!.ownerId!.isNotEmpty
                    ? const SizedBox()
                    : DsIconButton(
                        icon: Icons.account_balance_wallet_outlined,
                        semanticLabel: 'Wallet'.tr,
                        variant: DsIconButtonVariant.tonal,
                        onPressed: () {
                          Get.to(const WalletScreen(isAppBarShow: true));
                        },
                      ),
                const DsGap(DsSpace.sm),
                DsIconButton(
                  icon: Icons.person_outline_rounded,
                  semanticLabel: 'Profile'.tr,
                  variant: DsIconButtonVariant.tonal,
                  onPressed: () {
                    Get.to(const EditProfileScreen());
                  },
                ),
              ],
              leading: Builder(builder: (context) {
                return Padding(
                  padding: const EdgeInsets.only(left: DsSpace.sm),
                  child: DsIconButton(
                    icon: Icons.menu_rounded,
                    semanticLabel: 'Menu'.tr,
                    variant: DsIconButtonVariant.tonal,
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
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
      // The theme observable read must stay inside this Obx: it is what
      // rebuilds the drawer when the driver switches light / dark mode.
      themeController.isDark.value;
      return GetX(
          init: ParcelDashboardController(),
          builder: (controller) {
            final c = context.dsColors;
            final t = context.dsText;
            final bool isOnline = controller.userModel.value.isActive ?? false;
            final bool isDarkSwitch = controller.isDarkModeSwitch.value;
            return Drawer(
              backgroundColor: c.background,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                  child: ListView(
                    padding: const EdgeInsets.only(top: DsSpace.xl, bottom: DsSpace.lg),
                    children: <Widget>[
                      // ------------------------------------------- profile
                      DsCard(
                        padding: const EdgeInsets.all(DsSpace.md),
                        child: Row(
                          children: [
                            DsAvatar(
                              imageUrl: Constant.userModel == null ? "" : Constant.userModel!.profilePictureURL.toString(),
                              name: Constant.userModel?.fullName(),
                              size: 52,
                              ring: true,
                              statusTone: isOnline ? DsTone.success : DsTone.neutral,
                            ),
                            const DsGap(DsSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Constant.userModel!.fullName().tr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.titleSm.w700,
                                  ),
                                  Text(
                                    '${Constant.userModel!.email}'.tr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.bodySm,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const DsGap(DsSpace.lg),

                      // -------------------------------------- availability
                      Text('Available Status'.tr, style: t.overline),
                      const DsGap(DsSpace.sm),
                      DsOnlineToggle(
                        isOnline: isOnline,
                        onChanged: (value) async {
                          if (Constant.userModel?.isAutoVerify == false) {
                            if (controller.userModel.value.isDocumentVerify == true) {
                              // Spec 3.6: expired / rejected documents block going online.
                              if (value == true) {
                                final blockReason = await FireStoreUtils.documentBlockReason();
                                if (blockReason != null) {
                                  ShowToastDialog.showToast(blockReason.tr);
                                  return;
                                }
                              }
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
                      const DsGap(DsSpace.lg),

                      // ----------------------------------------- about app
                      DsTileGroup(
                        title: 'About App'.tr,
                        children: [
                          DsListTile(
                            title: 'Home'.tr,
                            leadingIcon: Icons.home_outlined,
                            leadingTone: DsTone.brand,
                            showChevron: true,
                            onTap: () {
                              Get.back();
                              controller.drawerIndex.value = 0;
                            },
                          ),
                          if ((Constant.userModel?.ownerId ?? '').isEmpty && (Constant.userModel?.vendorID ?? '').isEmpty)
                            DsListTile(
                              title: 'Change Section'.tr,
                              leadingIcon: Icons.grid_view_rounded,
                              leadingTone: DsTone.brand,
                              showChevron: true,
                              onTap: () {
                                Get.back();
                                Get.to(() => const ChangeSectionScreen());
                              },
                            ),
                          DsListTile(
                            title: 'Orders'.tr,
                            leadingIcon: Icons.receipt_long_outlined,
                            leadingTone: DsTone.brand,
                            showChevron: true,
                            onTap: () {
                              Get.back();
                              controller.drawerIndex.value = 1;
                            },
                          ),
                          DsListTile(
                            title: 'Parcel run'.tr,
                            leadingIcon: Icons.qr_code_scanner,
                            leadingTone: DsTone.brand,
                            showChevron: true,
                            onTap: () {
                              Get.back();
                              Get.to(() => const ParcelRunScreen());
                            },
                          ),
                          Constant.userModel!.ownerId != null && Constant.userModel!.ownerId!.isNotEmpty
                              ? const SizedBox()
                              : DsListTile(
                                  title: 'Wallet'.tr,
                                  leadingIcon: Icons.account_balance_wallet_outlined,
                                  leadingTone: DsTone.brand,
                                  showChevron: true,
                                  onTap: () {
                                    Get.back();
                                    controller.drawerIndex.value = 2;
                                  },
                                ),
                          Constant.userModel!.ownerId != null && Constant.userModel!.ownerId!.isNotEmpty
                              ? const SizedBox()
                              : DsListTile(
                                  title: 'Withdrawal Method'.tr,
                                  leadingIcon: Icons.account_balance_outlined,
                                  leadingTone: DsTone.brand,
                                  showChevron: true,
                                  onTap: () {
                                    Get.back();
                                    controller.drawerIndex.value = 3;
                                  },
                                ),
                          (((Constant.userModel?.ownerId == null || Constant.userModel!.ownerId!.isEmpty) && Constant.userModel?.isAutoVerify == false) &&
                                  !((Constant.userModel?.ownerId != null && Constant.userModel!.ownerId!.isNotEmpty) && Constant.userModel?.isAutoVerify == false))
                              ? DsListTile(
                                  title: 'Document Verification'.tr,
                                  leadingIcon: Icons.verified_user_outlined,
                                  leadingTone: DsTone.brand,
                                  showChevron: true,
                                  onTap: () {
                                    Get.back();
                                    controller.drawerIndex.value = 4;
                                  },
                                )
                              : const SizedBox.shrink(),
                          DsListTile(
                            title: 'Inbox'.tr,
                            leadingIcon: Icons.chat_bubble_outline_rounded,
                            leadingTone: DsTone.brand,
                            showChevron: true,
                            onTap: () {
                              Get.back();
                              controller.drawerIndex.value = 5;
                            },
                          ),
                        ],
                      ),
                      const DsGap(DsSpace.lg),

                      // ---------------------------------- app preferences
                      DsTileGroup(
                        title: 'App Preferences'.tr,
                        children: [
                          DsListTile(
                            title: 'Change Language'.tr,
                            leadingIcon: Icons.language_rounded,
                            leadingTone: DsTone.info,
                            showChevron: true,
                            onTap: () {
                              Get.back();
                              controller.drawerIndex.value = 6;
                            },
                          ),
                          DsListTile(
                            title: 'Dark Mode'.tr,
                            leadingIcon: Icons.dark_mode_outlined,
                            leadingTone: DsTone.info,
                            trailing: Transform.scale(
                              scale: 0.8,
                              child: CupertinoSwitch(
                                value: isDarkSwitch,
                                activeTrackColor: c.brand,
                                onChanged: (value) {
                                  controller.toggleDarkMode(value);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const DsGap(DsSpace.lg),

                      // --------------------------------------------- social
                      DsTileGroup(
                        title: 'Social'.tr,
                        children: [
                          DsListTile(
                            title: 'Share app'.tr,
                            leadingIcon: Icons.ios_share_rounded,
                            leadingTone: DsTone.success,
                            showChevron: true,
                            onTap: () {
                              Get.back();
                              Share.share(
                                  '${'Check out spideli, your ultimate food delivery application!'.tr} \n\n${'Google Play:'.tr} ${Constant.googlePlayLink} \n\n${'App Store:'.tr} ${Constant.appStoreLink}',
                                  subject: 'Look what I made!'.tr);
                            },
                          ),
                          DsListTile(
                            title: 'Rate the app'.tr,
                            leadingIcon: Icons.star_outline_rounded,
                            leadingTone: DsTone.warning,
                            showChevron: true,
                            onTap: () {
                              Get.back();
                              final InAppReview inAppReview = InAppReview.instance;
                              inAppReview.requestReview();
                            },
                          ),
                        ],
                      ),
                      const DsGap(DsSpace.lg),

                      // ---------------------------------------------- legal
                      DsTileGroup(
                        title: 'Legal'.tr,
                        children: [
                          DsListTile(
                            title: 'Terms and Conditions'.tr,
                            leadingIcon: Icons.description_outlined,
                            leadingTone: DsTone.neutral,
                            showChevron: true,
                            onTap: () {
                              Get.back();
                              controller.drawerIndex.value = 7;
                            },
                          ),
                          DsListTile(
                            title: 'Privacy Policy'.tr,
                            leadingIcon: Icons.privacy_tip_outlined,
                            leadingTone: DsTone.neutral,
                            showChevron: true,
                            onTap: () {
                              Get.back();
                              controller.drawerIndex.value = 8;
                            },
                          ),
                          if (Constant.userModel?.provider != 'apple' && Constant.userModel?.provider != 'google')
                            DsListTile(
                              title: 'Change Password'.tr,
                              leadingIcon: Icons.lock_outline_rounded,
                              leadingTone: DsTone.neutral,
                              showChevron: true,
                              onTap: () {
                                Get.back();
                                controller.drawerIndex.value = 9;
                              },
                            ),
                        ],
                      ),
                      const DsGap(DsSpace.lg),

                      // --------------------------------------- destructive
                      DsTileGroup(
                        children: [
                          DsListTile(
                            title: 'Log out'.tr,
                            leadingIcon: Icons.logout_rounded,
                            destructive: true,
                            showChevron: true,
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
                          DsListTile(
                            title: 'Delete Account'.tr,
                            leadingIcon: Icons.delete_outline_rounded,
                            destructive: true,
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
                          ),
                        ],
                      ),
                      const DsGap(DsSpace.lg),
                      Center(
                        child: Text(
                          "V : ${Constant.appVersion}",
                          textAlign: TextAlign.center,
                          style: t.caption.tabular,
                        ),
                      ),
                      const DsGap(DsSpace.md),
                    ],
                  ),
                ),
              ),
            );
          });
    });
  }
}

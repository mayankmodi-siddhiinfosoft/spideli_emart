import 'package:driver/app/auth_screen/login_screen.dart';
import 'package:driver/app/change_language/change_language_screen.dart';
import 'package:driver/app/change_password_screen/change_password_screen.dart';
import 'package:driver/app/chat_screens/driver_inbox_screen.dart';
import 'package:driver/app/change_section_screen/change_section_screen.dart';
import 'package:driver/app/edit_profile_screen/edit_profile_screen.dart';
import 'package:driver/app/help_support_screen/help_support_screen.dart';
import 'package:driver/app/home_screen/home_screen.dart';
import 'package:driver/app/home_screen/home_screen_multiple_order.dart';
import 'package:driver/app/order_list_screen/order_list_screen.dart';
import 'package:driver/app/terms_and_condition/terms_and_condition_screen.dart';
import 'package:driver/app/verification_screen/verification_screen.dart';
import 'package:driver/app/wallet_screen/wallet_screen.dart';
import 'package:driver/app/withdraw_method_setup_screens/withdraw_method_setup_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/dash_board_controller.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/themes/custom_dialog_box.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';

/// Archetype K – drawer shell for the delivery service.
class DashBoardScreen extends StatelessWidget {
  const DashBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      themeController.isDark.value;
      final c = context.dsColors;
      final t = context.dsText;
      return GetX(
        init: DashBoardController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: c.background,
            drawerEnableOpenDragGesture: false,
            appBar: DsAppBar(
              showBack: false,
              titleWidget: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Welcome Back 👋'.tr, style: t.caption),
                  Text(
                    Constant.userModel != null ? Constant.userModel!.fullName().tr : "",
                    style: t.titleSm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                ],
              ),
              actions: [
                Constant.userModel?.vendorID?.isEmpty == true
                    ? DsIconButton(
                        icon: Icons.account_balance_wallet_outlined,
                        semanticLabel: 'Wallet'.tr,
                        variant: DsIconButtonVariant.tonal,
                        onPressed: () {
                          Get.to(const WalletScreen(isAppBarShow: true));
                        },
                      )
                    : const SizedBox(),
                const DsGap(DsSpace.sm),
                DsIconButton(
                  icon: Icons.person_outline_rounded,
                  semanticLabel: 'Profile'.tr,
                  variant: DsIconButtonVariant.tonal,
                  onPressed: () {
                    Get.to(const EditProfileScreen());
                  },
                ),
                const DsGap(DsSpace.sm),
              ],
              leading: Builder(builder: (context) {
                return Padding(
                  padding: const EdgeInsets.all(DsSpace.sm),
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
                ? Constant.singleOrderReceive == true
                    ? const HomeScreen(
                        isAppBarShow: false,
                      )
                    : const HomeScreenMultipleOrder()
                : controller.drawerIndex.value == 1
                    ? const OrderListScreen()
                    : controller.drawerIndex.value == 2
                        ? const WalletScreen(
                            isAppBarShow: false,
                          )
                        : controller.drawerIndex.value == 3
                            ? const WithdrawMethodSetupScreen()
                            : controller.userModel.value.isAutoVerify == false
                                ? controller.drawerIndex.value == 4
                                    ? const VerificationScreen()
                                    : controller.drawerIndex.value == 5
                                        ? const DriverInboxScreen()
                                        : controller.drawerIndex.value == 6
                                            ? const ChangeLanguageScreen()
                                            : controller.drawerIndex.value == 7
                                                ? HelpSupportScreen()
                                                : controller.drawerIndex.value == 8
                                                    ? const TermsAndConditionScreen(type: "temsandcondition")
                                                    : controller.drawerIndex.value == 9
                                                        ? const TermsAndConditionScreen(type: "privacy")
                                                        : ChangePasswordScreen()
                                : controller.drawerIndex.value == 4
                                    ? const DriverInboxScreen()
                                    : controller.drawerIndex.value == 5
                                        ? const ChangeLanguageScreen()
                                        : controller.drawerIndex.value == 6
                                            ? HelpSupportScreen()
                                            : controller.drawerIndex.value == 7
                                                ? const TermsAndConditionScreen(type: "temsandcondition")
                                                : controller.drawerIndex.value == 8
                                                    ? const TermsAndConditionScreen(type: "privacy")
                                                    : ChangePasswordScreen(),
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
      themeController.isDark.value;
      final c = context.dsColors;
      final t = context.dsText;
      return GetX(
          init: DashBoardController(),
          builder: (controller) {
            return Drawer(
              backgroundColor: c.background,
              child: Padding(
                padding: EdgeInsets.only(top: MediaQuery.of(context).viewPadding.top + DsSpace.xl, left: DsSpace.lg, right: DsSpace.lg),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    DsCard(
                      padding: const EdgeInsets.all(DsSpace.md),
                      child: Row(
                        children: [
                          DsAvatar(
                            imageUrl: Constant.userModel == null ? "" : Constant.userModel!.profilePictureURL.toString(),
                            name: Constant.userModel?.fullName(),
                            size: 55,
                            ring: true,
                            statusTone: (controller.userModel.value.isActive ?? false) ? DsTone.success : DsTone.neutral,
                          ),
                          const DsGap(DsSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(Constant.userModel!.fullName().tr, style: t.title),
                                Text('${Constant.userModel!.email}'.tr, style: t.bodySm),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const DsGap(DsSpace.md),
                    DsOnlineToggle(
                      isOnline: controller.userModel.value.isActive ?? false,
                      onlineLabel: 'Available Status'.tr,
                      offlineLabel: 'Available Status'.tr,
                      onChanged: (value) async {
                        if (controller.userModel.value.isAutoVerify == false) {
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
                            controller.userModel.value.inProgressOrderID = Constant.userModel!.inProgressOrderID;
                            controller.userModel.value.orderRequestData = Constant.userModel!.orderRequestData;
                            if (controller.userModel.value.isActive == true) {
                              controller.updateCurrentLocation();
                            }
                            await FireStoreUtils.updateUser(controller.userModel.value);
                          } else {
                            ShowToastDialog.showToast("Document verification is pending. Please proceed to set up your document verification.".tr);
                          }
                        } else {
                          controller.userModel.value.isActive = value;
                          controller.userModel.value.inProgressOrderID = Constant.userModel!.inProgressOrderID;
                          controller.userModel.value.orderRequestData = Constant.userModel!.orderRequestData;
                          if (controller.userModel.value.isActive == true) {
                            controller.updateCurrentLocation();
                          }
                          await FireStoreUtils.updateUser(controller.userModel.value);
                        }
                      },
                    ),
                    const DsGap(DsSpace.lg),
                    DsTileGroup(
                      title: 'About App'.tr,
                      children: [
                        DsListTile(
                          leadingIcon: Icons.home_outlined,
                          title: 'Home'.tr,
                          showChevron: true,
                          onTap: () {
                            Get.back();
                            controller.drawerIndex.value = 0;
                          },
                        ),
                        if ((Constant.userModel?.ownerId ?? '').isEmpty && (Constant.userModel?.vendorID ?? '').isEmpty)
                          DsListTile(
                            leadingIcon: Icons.grid_view_rounded,
                            title: 'Change Section'.tr,
                            showChevron: true,
                            onTap: () {
                              Get.back();
                              Get.to(() => const ChangeSectionScreen());
                            },
                          ),
                        DsListTile(
                          leadingIcon: Icons.receipt_long_outlined,
                          title: 'Orders'.tr,
                          showChevron: true,
                          onTap: () {
                            Get.back();
                            controller.drawerIndex.value = 1;
                          },
                        ),
                        if (Constant.userModel?.vendorID?.isEmpty == true)
                          DsListTile(
                            leadingIcon: Icons.account_balance_wallet_outlined,
                            title: 'Wallet'.tr,
                            showChevron: true,
                            onTap: () {
                              Get.back();
                              controller.drawerIndex.value = 2;
                            },
                          ),
                        if (Constant.userModel?.vendorID?.isEmpty == true)
                          DsListTile(
                            leadingIcon: Icons.settings_outlined,
                            title: 'Withdrawal Method'.tr,
                            showChevron: true,
                            onTap: () {
                              Get.back();
                              controller.drawerIndex.value = 3;
                            },
                          ),
                        if (controller.userModel.value.isAutoVerify == false)
                          DsListTile(
                            leadingIcon: Icons.assignment_outlined,
                            leadingTone: DsTone.warning,
                            title: 'Document Verification'.tr,
                            showChevron: true,
                            onTap: () {
                              Get.back();
                              controller.drawerIndex.value = 4;
                            },
                          ),
                        DsListTile(
                          leadingIcon: Icons.forum_outlined,
                          title: 'Inbox'.tr,
                          showChevron: true,
                          onTap: () {
                            Get.back();
                            if (controller.userModel.value.isAutoVerify == false) {
                              controller.drawerIndex.value = 5;
                            } else {
                              controller.drawerIndex.value = 4;
                            }
                          },
                        ),
                      ],
                    ),
                    DsTileGroup(
                      title: 'App Preferences'.tr,
                      children: [
                        DsListTile(
                          leadingIcon: Icons.translate_rounded,
                          title: 'Change Language'.tr,
                          showChevron: true,
                          onTap: () {
                            Get.back();
                            if (controller.userModel.value.isAutoVerify == false) {
                              controller.drawerIndex.value = 6;
                            } else {
                              controller.drawerIndex.value = 5;
                            }
                          },
                        ),
                        DsListTile(
                          leadingIcon: Icons.support_agent_rounded,
                          title: 'Help & Support'.tr,
                          showChevron: true,
                          onTap: () {
                            Get.back();
                            if (controller.userModel.value.isAutoVerify == false) {
                              controller.drawerIndex.value = 7;
                            } else {
                              controller.drawerIndex.value = 6;
                            }
                          },
                        ),
                        DsListTile(
                          leadingIcon: Icons.dark_mode_outlined,
                          title: 'Dark Mode'.tr,
                          trailing: Switch(
                            value: controller.isDarkModeSwitch.value,
                            onChanged: (value) {
                              controller.toggleDarkMode(value);
                            },
                          ),
                        ),
                      ],
                    ),
                    DsTileGroup(
                      title: 'Social'.tr,
                      children: [
                        DsListTile(
                          leadingIcon: Icons.ios_share_rounded,
                          title: 'Share app'.tr,
                          showChevron: true,
                          onTap: () {
                            Get.back();
                            Share.share(
                                '${'Check out spideli, your ultimate food delivery application!'.tr} \n\n${'Google Play:'.tr} ${Constant.googlePlayLink} \n\n${'App Store:'.tr} ${Constant.appStoreLink}',
                                subject: 'Look what I made!'.tr);
                          },
                        ),
                        DsListTile(
                          leadingIcon: Icons.star_outline_rounded,
                          title: 'Rate the app'.tr,
                          showChevron: true,
                          onTap: () {
                            Get.back();
                            final InAppReview inAppReview = InAppReview.instance;
                            inAppReview.requestReview();
                          },
                        ),
                      ],
                    ),
                    DsTileGroup(
                      title: 'Legal'.tr,
                      children: [
                        DsListTile(
                          leadingIcon: Icons.description_outlined,
                          title: 'Terms and Conditions'.tr,
                          showChevron: true,
                          onTap: () {
                            Get.back();
                            if (controller.userModel.value.isAutoVerify == false) {
                              controller.drawerIndex.value = 8;
                            } else {
                              controller.drawerIndex.value = 7;
                            }
                          },
                        ),
                        DsListTile(
                          leadingIcon: Icons.privacy_tip_outlined,
                          leadingTone: DsTone.danger,
                          title: 'Privacy Policy'.tr,
                          showChevron: true,
                          onTap: () {
                            Get.back();
                            if (controller.userModel.value.isAutoVerify == false) {
                              controller.drawerIndex.value = 9;
                            } else {
                              controller.drawerIndex.value = 8;
                            }
                          },
                        ),
                        if (Constant.userModel?.provider != 'apple' && Constant.userModel?.provider != 'google')
                          DsListTile(
                            leadingIcon: Icons.mail_outline_rounded,
                            title: 'Change Password'.tr,
                            showChevron: true,
                            onTap: () {
                              Get.back();
                              if (controller.userModel.value.isAutoVerify == false) {
                                controller.drawerIndex.value = 10;
                              } else {
                                controller.drawerIndex.value = 9;
                              }
                            },
                          ),
                      ],
                    ),
                    DsTileGroup(
                      children: [
                        DsListTile(
                          leadingIcon: Icons.logout_rounded,
                          title: 'Log out'.tr,
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
                          leadingIcon: Icons.delete_outline_rounded,
                          title: 'Delete Account'.tr,
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
                    const DsGap(DsSpace.md),
                    Center(
                      child: Text("V : ${Constant.appVersion}", textAlign: TextAlign.center, style: t.caption),
                    ),
                    const DsGap(DsSpace.md),
                  ],
                ),
              ),
            );
          });
    });
  }
}

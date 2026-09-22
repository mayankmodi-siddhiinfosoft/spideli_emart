import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:vendor/app/change_password_screen/change_password_screen.dart';
import 'package:vendor/app/customer_subscription_screens/customer_subscription_screen.dart';
import 'package:vendor/app/employee_role_screens/role_screen.dart';
import 'package:vendor/app/employee_screens/employee_list_screen.dart';
import 'package:vendor/app/help_support_screen/help_support_screen.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vendor/app/add_advertisement_screen/advertisement_list_screen.dart';
import 'package:vendor/app/add_restaurant_screen/add_restaurant_screen.dart';
import 'package:vendor/app/store_screens/my_stores_screen.dart';
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
import 'package:vendor/themes/custom_dialog_box.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/network_image_widget.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      // Read so the whole menu rebuilds when the theme is toggled.
      // ignore: unused_local_variable
      final isDark = themeController.isDark.value;
      return GetX(
        init: ProfileController(),
        builder: (controller) {
          if (controller.isLoading.value) {
            return DsScaffold(
              title: "Store Profile".tr,
              showBack: false,
              maxContentWidth: DsLayout.contentMax,
              body: const SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                child: Column(children: [DsSkeletonCard(height: 132), DsSkeletonList(itemCount: 7)]),
              ),
            );
          }

          final user = controller.userModel.value;

          // ---- Store Information --------------------------------------------------
          final Widget? storeInformation =
              (Constant.getEmployeeRolePermission(module: "Add Story") == true ||
                  Constant.getEmployeeRolePermission(module: "Advertisement") == true ||
                  Constant.getEmployeeRolePermission(module: "Store Information's") == true ||
                  Constant.getEmployeeRolePermission(module: "Manage Products") == true ||
                  Constant.getEmployeeRolePermission(module: "Working Hours") == true ||
                  Constant.getEmployeeRolePermission(module: "Withdraw Method") == true)
              ? _group("Store Information".tr, [
                  (controller.userModel.value.isAutoVerify == false && controller.userModel.value.isDocumentVerify == false) ||
                          (controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty)
                      ? null
                      : Constant.storyEnable == false
                      ? null
                      : (Constant.getEmployeeRolePermission(module: "Add Story") == true)
                      ? _tile(
                          context,
                          svg: "assets/icons/ic_story.svg",
                          tone: DsTone.brand,
                          title: "Add Story",
                          onPress: () {
                            Get.to(const AddStoryScreen());
                          },
                        )
                      : null,
                  Constant.isEnableAdsFeature == true
                      ? ((controller.userModel.value.isAutoVerify == false && controller.userModel.value.isDocumentVerify == false) ||
                                (controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty)
                            ? null
                            : Constant.storyEnable == false
                            ? null
                            : (Constant.getEmployeeRolePermission(module: "Advertisement") == true)
                            ? _tile(
                                context,
                                svg: "assets/icons/ic_advertisement.svg",
                                tone: DsTone.brand,
                                title: "Advertisement",
                                onPress: () {
                                  Get.to(const AdvertisementListScreen());
                                },
                              )
                            : null)
                      : null,
                  (Constant.userModel?.isAutoVerify == false && Constant.userModel?.isDocumentVerify == false)
                      ? null
                      : (Constant.getEmployeeRolePermission(module: "Store Information's") == true)
                      ? _tile(
                          context,
                          svg: "assets/icons/ic_building_two.svg",
                          tone: DsTone.brand,
                          title: "Store Information's",
                          onPress: () {
                            Get.to(const AddRestaurantScreen())?.then((v) {
                              controller.getUserProfile();
                            });
                          },
                        )
                      : null,
                  // A vendor account can own several stores. Owners only:
                  // an employee stays on the store they were created for.
                  // Shown before the first store exists too: Add Store then
                  // creates it.
                  (Constant.userModel != null && Constant.userModel!.role != Constant.userRoleEmployee)
                      ? _tile(
                          context,
                          icon: Icons.storefront_outlined,
                          tone: DsTone.brand,
                          title: "My Stores",
                          onPress: () {
                            Get.to(const MyStoresScreen())?.then((v) {
                              controller.getUserProfile();
                            });
                          },
                        )
                      : null,
                  (Constant.userModel?.isAutoVerify == false && Constant.userModel?.isDocumentVerify == false) ||
                          (controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty)
                      ? null
                      : Constant.getEmployeeRolePermission(module: "Manage Products") == true
                      ? _tile(
                          context,
                          svg: "assets/icons/ic_manage_product.svg",
                          tone: DsTone.brand,
                          title: "Manage Products",
                          onPress: () {
                            DashBoardController dashBoardController = Get.find<DashBoardController>();
                            if (controller.userModel.value.role == Constant.userRoleVendor) {
                              dashBoardController.selectedIndex.value = Constant.selectedSection!.dineInActive == true ? 2 : 1;
                            } else {
                              dashBoardController.selectedIndex.value =
                                  Constant.getEmployeeRolePermission(module: "Dine in Request") == true && Constant.selectedSection?.dineInActive == true ? 2 : 1;
                            }
                          },
                        )
                      : null,
                  Constant.selectedSection!.serviceTypeFlag == "ecommerce-service"
                      ? null
                      : (Constant.userModel?.isAutoVerify == false && Constant.userModel?.isDocumentVerify == false) ||
                            (controller.userModel.value.vendorID == null || controller.userModel.value.vendorID?.isEmpty == true)
                      ? null
                      : (Constant.getEmployeeRolePermission(module: "Working Hours") == true)
                      ? _tile(
                          context,
                          svg: "assets/icons/ic_alarm-clock.svg",
                          tone: DsTone.brand,
                          title: "Working Hours",
                          onPress: () {
                            Get.to(const WorkingHoursScreen());
                          },
                        )
                      : null,
                  if (Constant.getEmployeeRolePermission(module: "Withdraw Method") == true)
                    _tile(
                      context,
                      svg: "assets/icons/ic_wallet.svg",
                      tone: DsTone.brand,
                      title: "Withdraw Method",
                      onPress: () {
                        Get.to(const WithdrawMethodSetupScreen());
                      },
                    ),
                ])
              : null;

          // ---- Delivery Man Information -------------------------------------------
          final Widget? deliveryMan = Constant.selectedSection!.serviceTypeFlag == "ecommerce-service"
              ? null
              : Constant.isSelfDeliveryFeature == true && (Constant.getEmployeeRolePermission(module: "Manage Delivery Man") == true)
              ? _group("Delivery Man Information".tr, [
                  _tile(
                    context,
                    svg: "assets/icons/ic_manage_delivery_man.svg",
                    tone: DsTone.info,
                    title: "Manage Delivery Man",
                    onPress: () {
                      Get.to(DriverListScreen());
                    },
                  ),
                ])
              : null;

          // ---- Employee Management -------------------------------------------------
          final Widget? employee =
              (Constant.isEmployeeManagement == false ||
                  (Constant.getEmployeeRolePermission(module: "Employee Role") == false) && (Constant.getEmployeeRolePermission(module: "All Employee") == false))
              ? null
              : _group("Employee Management".tr, [
                  if (Constant.getEmployeeRolePermission(module: "Employee Role") == true)
                    _tile(
                      context,
                      svg: "assets/icons/ic_manage_delivery_man.svg",
                      tone: DsTone.info,
                      title: "Employee Role",
                      onPress: () {
                        Get.to(const RoleScreen());
                      },
                    ),
                  if (Constant.getEmployeeRolePermission(module: "All Employee") == true)
                    _tile(
                      context,
                      svg: "assets/icons/ic_employee.svg",
                      tone: DsTone.info,
                      title: "All Employee",
                      onPress: () {
                        Get.to(EmployeeListScreen());
                      },
                    ),
                ]);

          // ---- Dine-in Information -------------------------------------------------
          final Widget? dineIn =
              (Constant.userModel?.isAutoVerify == false && Constant.userModel?.isDocumentVerify == false) ||
                  (controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty) ||
                  ((Constant.getEmployeeRolePermission(module: "Add Dine in") == false) && (Constant.getEmployeeRolePermission(module: "Dine in Request") == false))
              ? null
              : Constant.selectedSection!.dineInActive == true &&
                    ((Constant.getEmployeeRolePermission(module: "Add Dine in") == true || Constant.getEmployeeRolePermission(module: "Dine in Request") == true))
              ? _group("Dine-in Information".tr, [
                  if (Constant.getEmployeeRolePermission(module: "Add Dine in") == true)
                    _tile(
                      context,
                      svg: "assets/icons/ic_knife_fork.svg",
                      tone: DsTone.warning,
                      title: "Dine in Store",
                      onPress: () {
                        Get.to(const DineInCreateScreen());
                      },
                    ),
                  if (Constant.getEmployeeRolePermission(module: "Dine in Request") == true)
                    _tile(
                      context,
                      svg: "assets/icons/ic_people-unknown.svg",
                      tone: DsTone.warning,
                      title: "Dine in Requests",
                      onPress: () {
                        DashBoardController dashBoardController = Get.find<DashBoardController>();
                        dashBoardController.selectedIndex.value = 1;
                      },
                    ),
                ])
              : null;

          // ---- Subscription Management --------------------------------------------
          final Widget? subscription =
              ((Constant.getEmployeeRolePermission(module: "Subscription Packages") == true) || (Constant.getEmployeeRolePermission(module: "Subscription History") == true))
              ? _group("Subscription Management".tr, [
                  ((Constant.isSubscriptionModelApplied == true && controller.userModel.value.role != Constant.userRoleEmployee) &&
                          Constant.getEmployeeRolePermission(module: "Subscription Packages") == true)
                      ? _tile(
                          context,
                          svg: "assets/icons/ic_subscription.svg",
                          tone: DsTone.success,
                          title: "Subscription Packages",
                          onPress: () {
                            Get.to(const SubscriptionPlanScreen(), arguments: {'isProfile': true})?.then((value) {
                              if (value == true) {
                                controller.getUserProfile();
                              }
                            });
                          },
                        )
                      : null,
                  if (Constant.getEmployeeRolePermission(module: "Subscription History") == true)
                    _tile(
                      context,
                      svg: "assets/icons/ic_history.svg",
                      tone: DsTone.success,
                      title: "Subscription History",
                      onPress: () {
                        Get.to(const SubscriptionHistoryScreen());
                      },
                    ),
                ])
              : null;

          // ---- Offers & Discounts ------------------------------------------------
          final Widget? offers =
              (Constant.userModel?.isAutoVerify == false && Constant.userModel?.isDocumentVerify == false) ||
                  (controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty)
              ? null
              : ((Constant.getEmployeeRolePermission(module: "Offers") == true) || (Constant.getEmployeeRolePermission(module: "Special Discounts") == true))
              ? _group("Offers & Discounts".tr, [
                  if (Constant.getEmployeeRolePermission(module: "Offers") == true)
                    _tile(
                      context,
                      svg: "assets/icons/ic_gift_box.svg",
                      tone: DsTone.success,
                      title: "Offers",
                      onPress: () {
                        Get.to(const OfferScreen());
                      },
                    ),
                  // Customer Subscriptions: plans the store sells to its own customers (gated like Offers).
                  if (Constant.getEmployeeRolePermission(module: "Offers") == true)
                    _tile(
                      context,
                      icon: Icons.card_membership_outlined,
                      tone: DsTone.success,
                      title: "Customer Subscriptions",
                      onPress: () {
                        Get.to(const CustomerSubscriptionScreen());
                      },
                    ),
                  if (Constant.specialDiscountOfferEnable == true && (Constant.getEmployeeRolePermission(module: "Special Discounts") == true))
                    _tile(
                      context,
                      svg: "assets/icons/ic_coupon.svg",
                      tone: DsTone.success,
                      title: "Special Discounts",
                      onPress: () {
                        Get.to(const SpecialDiscountScreen());
                      },
                    ),
                ])
              : null;

          // ---- Preferences -------------------------------------------------------
          final Widget? preferences = _group("Preferences".tr, [
            _tile(
              context,
              svg: "assets/icons/ic_language.svg",
              tone: DsTone.warning,
              title: "Change Language",
              onPress: () {
                Get.to(const ChangeLanguageScreen());
              },
            ),
            _tile(
              context,
              svg: "assets/icons/ic_darkmode.svg",
              tone: DsTone.warning,
              title: "Dark Mode",
              onPress: () {},
              trailing: Switch.adaptive(
                value: controller.isDarkModeSwitch.value,
                onChanged: (value) {
                  controller.toggleDarkMode(value);
                },
              ),
            ),
          ]);

          // ---- Social ------------------------------------------------------------
          final Widget? social = _group("Social".tr, [
            _tile(
              context,
              svg: "assets/icons/ic_share.svg",
              tone: DsTone.info,
              title: "Share app",
              onPress: () {
                Share.share(
                  '${"Check out Foodie, your ultimate food delivery application! \n\nGoogle Play:".tr} ${Constant.googlePlayLink} ${"\n\nApp Store:".tr} ${Constant.appStoreLink}',
                  subject: 'Look what I made!'.tr,
                );
              },
            ),
            _tile(
              context,
              svg: "assets/icons/ic_rate.svg",
              tone: DsTone.info,
              title: "Rate the app",
              onPress: () {
                final InAppReview inAppReview = InAppReview.instance;
                inAppReview.requestReview();
              },
            ),
          ]);

          // ---- Legal -------------------------------------------------------------
          final Widget? legal = _group("Legal".tr, [
            if (controller.userModel.value.isAutoVerify == false)
              _tile(
                context,
                svg: "assets/icons/ic_documention.svg",
                tone: DsTone.neutral,
                title: "Document Verifications".tr,
                onPress: () {
                  Get.to(const VerificationScreen());
                },
              ),
            _tile(
              context,
              svg: "assets/icons/ic_help_support.svg",
              tone: DsTone.neutral,
              title: "Help & Support".tr,
              onPress: () {
                Get.to(HelpSupportScreen(isNavigateViaNotification: false));
              },
            ),
            _tile(
              context,
              svg: "assets/icons/ic_terms_condition.svg",
              tone: DsTone.neutral,
              title: "Terms and Conditions",
              onPress: () {
                Get.to(const TermsAndConditionScreen(type: "termAndCondition"));
              },
            ),
            _tile(
              context,
              svg: "assets/icons/ic_privacyPolicy.svg",
              tone: DsTone.neutral,
              title: "Privacy Policy",
              onPress: () {
                Get.to(const TermsAndConditionScreen(type: "privacy"));
              },
            ),
            if (Constant.userModel?.provider == 'email')
              _tile(
                context,
                svg: "assets/icons/ic_lock.svg",
                tone: DsTone.neutral,
                title: "Change Password",
                onPress: () {
                  Get.to(const ChangePasswordScreen());
                },
              ),
          ]);

          // ---- Account (destructive) --------------------------------------------
          final Widget? account = _group(null, [
            _tile(
              context,
              svg: "assets/icons/ic_logout.svg",
              tone: DsTone.danger,
              title: "Log out",
              destructive: true,
              onPress: () {
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
              },
            ),
            _tile(
              context,
              svg: "assets/icons/ic_delete.svg",
              tone: DsTone.danger,
              title: "Delete Account".tr,
              destructive: true,
              onPress: () {
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
            ),
          ]);

          final Widget? planCard = (Constant.isSubscriptionModelApplied == true || Constant.vendorAdminCommission?.isEnabled == true)
              ? controller.userModel.value.subscriptionPlanId?.isNotEmpty == true
                    ? SubscriptionPlanWidget(
                        onClick: () {
                          Get.to(const SubscriptionPlanScreen(), arguments: {'isProfile': true})?.then((value) {
                            if (value == true) {
                              controller.getUserProfile();
                            }
                          });
                        },
                        userModel: controller.userModel.value,
                      )
                    : null
              : null;

          final groups = <Widget>[?storeInformation, ?deliveryMan, ?employee, ?dineIn, ?subscription, ?offers, ?preferences, ?social, ?legal, ?account];

          return DsScaffold.hero(
            title: "Store Profile".tr,
            showBack: false,
            hero: _ProfileHero(
              user: user,
              onEdit: () async {
                Get.to(const EditProfileScreen())!.then((value) {
                  if (value == true) {
                    controller.getUserProfile();
                  }
                });
              },
            ),
            slivers: [
              DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                top: DsSpace.xl,
                sliver: SliverToBoxAdapter(
                  child: DsResponsiveBuilder(
                    builder: (context, l) {
                      if (!l.isWide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: DsFadeSlideIn.stagger([
                            if (planCard != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: DsSpace.xl),
                                child: planCard,
                              ),
                            for (final g in groups)
                              Padding(
                                padding: const EdgeInsets.only(bottom: DsSpace.xl),
                                child: g,
                              ),
                          ]),
                        );
                      }
                      // Tablets / iPad: two columns of groups (masonry-like).
                      final left = <Widget>[];
                      final right = <Widget>[];
                      for (var i = 0; i < groups.length; i++) {
                        (i.isEven ? left : right).add(
                          DsFadeSlideIn(
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: DsSpace.xl),
                              child: groups[i],
                            ),
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (planCard != null)
                            DsFadeSlideIn(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: DsSpace.xl),
                                child: planCard,
                              ),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left),
                              ),
                              const DsGap(DsSpace.xl),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: DsSpace.sm),
                    child: Text("V : ${Constant.appVersion}", textAlign: TextAlign.center, style: context.dsText.caption),
                  ),
                ),
              ),
            ],
          );
        },
      );
    });
  }

  /// Grouped settings card. Returns null when no row is visible so the
  /// section disappears instead of rendering an empty card.
  Widget? _group(String? title, List<Widget?> rows) {
    final visible = rows.whereType<Widget>().toList();
    if (visible.isEmpty) return null;
    return DsTileGroup(title: title, children: visible);
  }

  /// One menu row. Same tap behaviour as the former `cardDecoration`:
  /// unfocus, then run the action.
  Widget _tile(
    BuildContext context, {
    String? svg,
    IconData? icon,
    required DsTone tone,
    required String title,
    required Function()? onPress,
    Widget? trailing,
    bool destructive = false,
  }) {
    final c = context.dsColors;
    final fg = c.tone(tone).strong;
    return DsListTile(
      title: title.tr,
      destructive: destructive,
      leading: DsIconWell(
        tone: tone,
        size: 40,
        circle: true,
        child: svg != null ? SvgPicture.asset(svg, width: 20, height: 20, colorFilter: ColorFilter.mode(fg, BlendMode.srcIn)) : Icon(icon, size: 20),
      ),
      trailing: trailing,
      showChevron: trailing == null && !destructive,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        onPress!();
      },
    );
  }
}

/// Profile hero: avatar, name, email, role badge and Edit Profile action.
class _ProfileHero extends StatelessWidget {
  final UserModel user;
  final VoidCallback onEdit;
  const _ProfileHero({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    final isEmployee = user.role == Constant.userRoleEmployee;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.3)),
                child: DsAvatar(imageUrl: user.profilePictureURL.toString(), name: user.fullName(), size: 72),
              ),
              const DsGap(DsSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.headline.withColor(Colors.white)),
                    if ((user.email ?? '').isNotEmpty) ...[
                      const DsGap(DsSpace.xxs),
                      Text(user.email ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm.withColor(Colors.white.withValues(alpha: 0.85))),
                    ],
                    const DsGap(DsSpace.sm),
                    Wrap(
                      spacing: DsSpace.sm,
                      runSpacing: DsSpace.xs,
                      children: [
                        _HeroChip(icon: isEmployee ? Icons.badge_outlined : Icons.workspace_premium_outlined, label: isEmployee ? 'Employee'.tr : 'Owner'.tr),
                        if (user.isDocumentVerify == true || user.isAutoVerify == true) _HeroChip(icon: Icons.verified_rounded, label: 'Verified'.tr),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const DsGap(DsSpace.lg),
          DsCard.glass(
            onTap: onEdit,
            semanticLabel: "Edit Profile".tr,
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
            radius: DsRadius.md,
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                const DsGap(DsSpace.md),
                Expanded(child: Text("Edit Profile".tr, style: t.label.withColor(Colors.white))),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.xxs + 1),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: DsRadius.brPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const DsGap(DsSpace.xs),
          Flexible(child: Text(label, style: context.dsText.labelSm.withColor(Colors.white))),
        ],
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
    final t = context.dsText;
    final muted = Colors.white.withValues(alpha: 0.75);
    return DsCard.gradient(
      gradient: DsGradients.deep(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DsSpace.xs),
                decoration: BoxDecoration(color: Colors.white, borderRadius: DsRadius.brMd),
                child: ClipRRect(
                  borderRadius: DsRadius.brSm,
                  child: NetworkImageWidget(imageUrl: userModel.subscriptionPlan?.image ?? '', fit: BoxFit.cover, width: 44, height: 44),
                ),
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userModel.subscriptionPlan?.name ?? '', style: t.title.withColor(Colors.white)),
                    Text(
                      userModel.subscriptionPlan?.type == 'free' ? userModel.subscriptionPlan?.description ?? '' : Constant.amountShow(amount: userModel.subscriptionPlan?.price),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySm.withColor(muted),
                    ),
                  ],
                ),
              ),
              if (userModel.subscriptionPlan?.type == 'paid') ...[
                const DsGap(DsSpace.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Expiry Date'.tr, style: t.caption.withColor(muted)),
                    Text(
                      userModel.subscriptionPlan!.expiryDay == "-1" ? "LifeTime" : Constant.timestampToDate(userModel.subscriptionExpiryDate!),
                      style: t.labelSm.withColor(Colors.white),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const DsGap(DsSpace.lg),
          DsButton.primary(label: "Change Plan".tr, icon: Icons.swap_horiz_rounded, expand: true, onPressed: onClick),
          if (Constant.selectedSection!.adminCommision?.isEnabled == true)
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: muted),
                  const DsGap(DsSpace.xs),
                  Expanded(
                    child: Text(
                      Constant.userModel!.vendorID != null && Constant.userModel!.vendorID!.isNotEmpty
                          ? "${Constant.vendorAdminCommission?.commissionType == 'Percent' || Constant.vendorAdminCommission?.commissionType == 'percentage' ? "${Constant.vendorAdminCommission?.amount} %" : "${Constant.amountShow(amount: Constant.vendorAdminCommission?.amount)} "}${'Flat'.tr} ${"admin commission will be charged from customer billing orders and the admin charge will be earned after the order is accepted by the store.".tr}"
                          : "${Constant.selectedSection!.adminCommision!.commissionType == 'Percent' || Constant.selectedSection!.adminCommision!.commissionType == 'percentage' ? "${Constant.selectedSection!.adminCommision!.amount} %" : "${Constant.amountShow(amount: Constant.selectedSection!.adminCommision!.amount)} Flat"} ${"admin commission will be charged from customer billing orders and the admin charge will be earned after the order is accepted by the store.".tr}",
                      style: t.caption.withColor(muted),
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

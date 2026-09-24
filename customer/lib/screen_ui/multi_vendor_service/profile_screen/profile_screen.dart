import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/my_profile_controller.dart';
import 'package:customer/screen_ui/change_password_screen/change_password_screen.dart';
import 'package:customer/screen_ui/help_support_screen/help_support_screen.dart';
import 'package:customer/screen_ui/on_demand_service/provider_inbox_screen.dart';
import 'package:customer/screen_ui/on_demand_service/worker_inbox_screen.dart';
import 'package:customer/themes/custom_dialog_box.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:in_app_review/in_app_review.dart';
import '../../../controllers/theme_controller.dart';
import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../../auth_screens/login_screen.dart';
import '../cashback_screen/cashback_offers_list.dart';
import '../change_language/change_language_screen.dart';
import '../chat_screens/driver_inbox_screen.dart';
import '../chat_screens/restaurant_inbox_screen.dart';
import '../dine_in_booking/dine_in_booking_screen.dart';
import '../dine_in_screeen/dine_in_screen.dart';
import '../edit_profile_screen/edit_profile_screen.dart';
import '../gift_card/gift_card_screen.dart';
import '../refer_friend_screen/refer_friend_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../terms_and_condition/terms_and_condition_screen.dart';
import '../../subscriptions/business_account_screen.dart';
import '../../subscriptions/my_plan_screen.dart';
import '../../subscriptions/my_store_subscriptions_screen.dart';
import '../../subscriptions/saved_payment_methods_screen.dart';

/// Archetype **H — profile / settings**: an identity header card followed by
/// grouped setting rows, a destructive group and the app version.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Scaffold(
      body: Obx(() {
        final isDark = themeController.isDark.value;
        return GetX(
          init: MyProfileController(),
          builder: (controller) {
            final c = context.dsColors;
            final t = context.dsText;
            final l = context.dsLayout;
            final user = Constant.userModel;
            final loading = controller.isLoading.value;
            return DsAsync(
              isLoading: loading,
              skeleton: const _ProfileSkeleton(),
              builder: (_) => SingleChildScrollView(
                padding: EdgeInsets.only(top: MediaQuery.of(context).viewPadding.top),
                child: DsResponsive(
                  maxWidth: DsLayout.contentMax,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: DsFadeSlideIn.stagger([
                        // ── Identity hero ────────────────────────────────
                        DsCard.gradient(
                          gradient: isDark ? DsGradients.deep(context) : DsGradients.brand(context),
                          padding: const EdgeInsets.all(DsSpace.xl),
                          onTap: user == null
                              ? null
                              : () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  Get.to(const EditProfileScreen());
                                },
                          semanticLabel: "My Profile".tr,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.28)),
                                child: DsAvatar(imageUrl: user?.profilePictureURL, name: user?.fullName(), size: 58),
                              ),
                              const DsGap(DsSpace.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user == null ? "My Profile".tr : user.fullName(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: DsTypography.headline.copyWith(color: Colors.white),
                                    ),
                                    const DsGap(DsSpace.xxs),
                                    Text(
                                      user == null
                                          ? "Manage your personal information, preferences, and settings all in one place.".tr
                                          : (user.email ?? '').isNotEmpty
                                          ? user.email!
                                          : "${user.countryCode ?? ''} ${user.phoneNumber ?? ''}".trim(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: DsTypography.body.copyWith(color: Colors.white.withValues(alpha: 0.88)),
                                    ),
                                  ],
                                ),
                              ),
                              if (user != null) const Icon(Icons.chevron_right_rounded, color: Colors.white),
                            ],
                          ),
                        ),
                        const DsGap(DsSpace.lg),

                        // ── General information ──────────────────────────
                        DsTileGroup(
                          title: "General Information".tr,
                          children: [
                            if (Constant.userModel != null)
                              _tile(context, "assets/images/ic_profile.svg", "Profile Information".tr, () {
                                Get.to(const EditProfileScreen());
                              }),
                            if (Constant.sectionConstantModel!.dineInActive == true)
                              _tile(context, "assets/images/ic_dinin.svg", "Dine-In".tr, () {
                                Get.to(const DineInScreen());
                              }),
                            _tile(context, "assets/images/ic_gift.svg", "Gift Card".tr, () {
                              Get.to(const GiftCardScreen());
                            }),
                            if (Constant.isCashbackActive == true)
                              _tile(context, "assets/icons/ic_cashback_Offer.svg", "Cashback Offers".tr, () {
                                Get.to(const CashbackOffersListScreen());
                              }),
                          ],
                        ),

                        // ── Account & subscriptions ──────────────────────
                        if (Constant.userModel != null)
                          DsTileGroup(
                            title: "Account & Subscriptions".tr,
                            children: [
                              _tile(context, "assets/icons/ic_orders.svg", "My plan".tr, () {
                                Get.to(() => const MyPlanScreen());
                              }),
                              _tile(context, "assets/icons/ic_dinin_order.svg", "My subscriptions".tr, () {
                                Get.to(() => const MyStoreSubscriptionsScreen());
                              }),
                              _tile(context, "assets/icons/ic_wallet.svg", "Payment methods".tr, () {
                                Get.to(() => const SavedPaymentMethodsScreen());
                              }),
                              _tile(context, "assets/images/ic_profile.svg", "Business account".tr, () {
                                Get.to(() => const BusinessAccountScreen());
                              }),
                            ],
                          ),

                        // ── Bookings ─────────────────────────────────────
                        Constant.sectionConstantModel!.dineInActive == true
                            ? DsTileGroup(
                                title: "Bookings Information".tr,
                                children: [
                                  _tile(context, "assets/icons/ic_dinin_order.svg", "Dine-In Booking".tr, () {
                                    Get.to(const DineInBookingScreen());
                                  }),
                                ],
                              )
                            : const SizedBox(),

                        // ── Preferences ──────────────────────────────────
                        DsTileGroup(
                          title: "Preferences".tr,
                          children: [
                            _tile(context, "assets/icons/ic_change_language.svg", "Change Language".tr, () {
                              Get.to(const ChangeLanguageScreen());
                            }),
                            _tile(
                              context,
                              "assets/icons/ic_light_dark.svg",
                              "Dark Mode".tr,
                              () {},
                              trailing: Transform.scale(
                                scale: 0.8,
                                child: Obx(
                                  () => CupertinoSwitch(value: controller.isDarkModeSwitch.value, activeTrackColor: c.brand, onChanged: controller.toggleDarkMode),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // ── Social ───────────────────────────────────────
                        DsTileGroup(
                          title: "Social".tr,
                          children: [
                            if (Constant.userModel != null)
                              _tile(context, "assets/icons/ic_refer.svg", "Refer a Friend".tr, () {
                                Get.to(const ReferFriendScreen());
                              }),
                            _tile(context, "assets/icons/ic_share.svg", "Share app".tr, () {
                              Share.share(
                                '${'Check out spideli, the ultimate all-in-one multi-vendor eBusiness platform.'.tr} \n\n${'Google Play:'.tr} ${Constant.googlePlayLink} \n\n${'App Store:'.tr} ${Constant.appStoreLink}',
                                subject: 'Look what I made!'.tr,
                              );
                            }),
                            _tile(context, "assets/icons/ic_rate.svg", "Rate the app".tr, () {
                              final InAppReview inAppReview = InAppReview.instance;
                              inAppReview.requestReview();
                            }),
                          ],
                        ),

                        // ── Communication ────────────────────────────────
                        Constant.userModel == null
                            ? const SizedBox()
                            : DsTileGroup(
                                title: "Communication".tr,
                                children: [
                                  _tile(context, "assets/icons/ic_restaurant_chat.svg", "Store Inbox".tr, () {
                                    Get.to(const RestaurantInboxScreen());
                                  }),
                                  _tile(context, "assets/icons/ic_restaurant_driver.svg", "Driver Inbox".tr, () {
                                    Get.to(const DriverInboxScreen());
                                  }),
                                  _tile(context, "assets/icons/ic_restaurant_chat.svg", "Provider Inbox".tr, () {
                                    Get.to(const ProviderInboxScreen());
                                  }),
                                  _tile(context, "assets/icons/ic_restaurant_driver.svg", "Worker Inbox".tr, () {
                                    Get.to(const WorkerInboxScreen());
                                  }),
                                ],
                              ),

                        // ── Legal ────────────────────────────────────────
                        DsTileGroup(
                          title: "Legal".tr,
                          children: [
                            if (Constant.userModel?.id != null)
                              _tile(context, "assets/icons/ic_help_support.svg", "Help & Support", tone: DsTone.success, () {
                                Get.to(HelpSupportScreen(isNavigateViaNotification: false));
                              }),
                            _tile(context, "assets/icons/ic_privacy_policy.svg", "Privacy Policy".tr, () {
                              Get.to(const TermsAndConditionScreen(type: "privacy"));
                            }),
                            _tile(context, "assets/icons/ic_tearm_condition.svg", "Terms and Conditions".tr, () {
                              Get.to(const TermsAndConditionScreen(type: "termAndCondition"));
                            }),
                            if (Constant.userModel?.provider == 'email')
                              _tile(context, "assets/icons/ic_lock.svg", "Change Password".tr, tone: DsTone.success, () {
                                Get.to(const ChangePasswordScreen());
                              }),
                          ],
                        ),

                        // ── Session ──────────────────────────────────────
                        DsTileGroup(
                          children: [
                            Constant.userModel == null
                                ? _tile(context, "assets/icons/ic_logout.svg", "Log In".tr, tone: DsTone.success, () {
                                    Get.offAll(const LoginScreen());
                                  })
                                : _tile(context, "assets/icons/ic_logout.svg", "Log out".tr, tone: DsTone.danger, showChevron: false, () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return CustomDialogBox(
                                          title: "Log out".tr,
                                          descriptions: "Are you sure you want to log out? You will need to enter your credentials to log back in.".tr,
                                          positiveString: "Log out".tr,
                                          negativeString: "Cancel".tr,
                                          positiveClick: () async {
                                            Constant.userModel!.fcmToken = "";
                                            await FireStoreUtils.updateUser(Constant.userModel!);
                                            Constant.userModel = null;
                                            await FirebaseAuth.instance.signOut();
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

                        // ── Delete account ───────────────────────────────
                        Constant.userModel == null
                            ? const SizedBox()
                            : Padding(
                                padding: const EdgeInsets.symmetric(vertical: DsSpace.lg),
                                child: DsButton.dangerTonal(
                                  label: "Delete Account".tr,
                                  expand: true,
                                  leading: SvgPicture.asset("assets/icons/ic_delete.svg", height: 20, width: 20, colorFilter: ColorFilter.mode(c.dangerStrong, BlendMode.srcIn)),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return CustomDialogBox(
                                          title: "Delete Account".tr,
                                          descriptions: "Are you sure you want to delete your account? This action is irreversible and will permanently remove all your data.".tr,
                                          positiveString: "Delete".tr,
                                          negativeString: "Cancel".tr,
                                          positiveClick: () async {
                                            ShowToastDialog.showLoader("Please wait...".tr);
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
                              ),
                        Center(child: Text("V : ${Constant.appVersion}", textAlign: TextAlign.center, style: t.caption.tabular)),
                      ]),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  /// One settings row: the screen's original SVG in a tinted well, the label
  /// and a chevron (or a custom [trailing] control).
  Widget _tile(
    BuildContext context,
    String image,
    String title,
    VoidCallback? onPress, {
    DsTone tone = DsTone.brand,
    Widget? trailing,
    bool showChevron = true,
  }) {
    final c = context.dsColors;
    final accent = c.tone(tone).strong;
    return DsListTile(
      title: title.tr,
      leading: DsIconWell(
        tone: tone,
        size: 40,
        child: SvgPicture.asset(image, height: 20, width: 20, colorFilter: ColorFilter.mode(accent, BlendMode.srcIn)),
      ),
      trailing: trailing,
      showChevron: trailing == null && showChevron,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        onPress?.call();
      },
      destructive: tone == DsTone.danger,
    );
  }
}

/// Skeleton for the profile page (identity card + grouped rows).
class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DsShimmer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(DsSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: double.infinity, child: DsSkeleton.box(height: 108, radius: DsRadius.xl)),
              const DsGap(DsSpace.xxl),
              for (var group = 0; group < 3; group++) ...[
                DsSkeleton.line(width: 120, height: 12),
                const DsGap(DsSpace.md),
                SizedBox(width: double.infinity, child: DsSkeleton.box(height: 148, radius: DsRadius.lg)),
                const DsGap(DsSpace.xl),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

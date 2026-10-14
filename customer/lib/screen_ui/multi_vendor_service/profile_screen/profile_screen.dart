import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/my_profile_controller.dart';
import 'package:customer/screen_ui/change_password_screen/change_password_screen.dart';
import 'package:customer/screen_ui/help_support_screen/help_support_screen.dart';
import 'package:customer/screen_ui/on_demand_service/provider_inbox_screen.dart';
import 'package:customer/screen_ui/notification_center/notification_center_screen.dart';
import 'package:customer/screen_ui/on_demand_service/worker_inbox_screen.dart';
import 'package:customer/service/inbox_unread_service.dart';
import 'package:customer/widget/live_unread_badge.dart';
import 'package:customer/themes/custom_dialog_box.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../../controllers/theme_controller.dart';
import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../../../utils/push_token_sync.dart';
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
      // Content stays below the status bar instead of scrolling under the clock.
      body: SafeArea(
        bottom: false,
        child: Obx(() {
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
                          // ── Account ──────────────────────────────────────
                          if (Constant.userModel != null)
                            DsTileGroup(
                              margin: _groupGap,
                              title: "Account".tr,
                              children: [
                                _tile(context, null, icon: Icons.person_outline_rounded, "Profile Information".tr, subtitle: "Name, email and phone number".tr, () {
                                  Get.to(const EditProfileScreen());
                                }),
                                _tile(context, null, icon: Icons.business_center_outlined, "Business account".tr, subtitle: "Business prices once your company is verified".tr, () {
                                  Get.to(() => const BusinessAccountScreen());
                                }),
                                _tile(context, null, icon: Icons.account_balance_wallet_outlined, "Payment methods".tr, subtitle: "Your saved Mobile Money and Wave numbers".tr, () {
                                  Get.to(() => const SavedPaymentMethodsScreen());
                                }),
                                if (Constant.userModel?.provider == 'email')
                                  _tile(context, null, icon: Icons.lock_outline_rounded, "Change Password".tr, () {
                                    Get.to(const ChangePasswordScreen());
                                  }),
                              ],
                            ),

                          // ── Money & rewards ──────────────────────────────
                          DsTileGroup(
                            margin: _groupGap,
                            title: "Money & rewards".tr,
                            children: [
                              // "Subscriptions", as the website renamed it
                              // from "Order History Plans" (WEB spec §5,
                              // "Naming and layout"). The store-sold
                              // subscriptions keep their own entry beside it,
                              // labelled so the two never read alike.
                              if (Constant.userModel != null)
                                _tile(context, null, icon: Icons.workspace_premium_outlined, "Subscriptions".tr, subtitle: "Your Spideli plan and renewal".tr, () {
                                  Get.to(() => const MyPlanScreen());
                                }),
                              if (Constant.userModel != null)
                                _tile(context, null, icon: Icons.autorenew_rounded, "Store subscriptions".tr, subtitle: "Regular deliveries from your stores".tr, () {
                                  Get.to(() => const MyStoreSubscriptionsScreen());
                                }),
                              _tile(context, null, icon: Icons.card_giftcard_rounded, "Gift Card".tr, () {
                                Get.to(const GiftCardScreen());
                              }),
                              if (Constant.isCashbackActive == true)
                                _tile(context, null, icon: Icons.local_offer_outlined, "Cashback Offers".tr, () {
                                  Get.to(const CashbackOffersListScreen());
                                }),
                            ],
                          ),

                          // ── Dining ───────────────────────────────────────
                          if (Constant.sectionConstantModel!.dineInActive == true)
                            DsTileGroup(
                              margin: _groupGap,
                              title: "Dining".tr,
                              children: [
                                _tile(context, null, icon: Icons.restaurant_rounded, "Dine-In".tr, subtitle: "Find restaurants and book a table".tr, () {
                                  Get.to(const DineInScreen());
                                }),
                                _tile(context, null, icon: Icons.event_seat_outlined, "Dine-In Booking".tr, subtitle: "Your table reservations".tr, () {
                                  Get.to(const DineInBookingScreen());
                                }),
                              ],
                            ),

                          // ── Messages ─────────────────────────────────────
                          if (Constant.userModel != null)
                            DsTileGroup(
                              margin: _groupGap,
                              title: "Messages".tr,
                              children: [
                                // Each row with its live unread total (the
                                // badge before the chevron; nothing at 0,
                                // 99+ past 99). The badges follow sign-in /
                                // sign-out themselves.
                                _tile(context, null, icon: Icons.notifications_none_rounded, "Notifications".tr, badge: LiveUnreadBadge.notifications(), () {
                                  Get.to(() => const NotificationCenterScreen());
                                }),
                                _tile(context, null, icon: Icons.storefront_outlined, "Store Inbox".tr, badge: LiveUnreadBadge.inbox(InboxKind.store), () {
                                  Get.to(const RestaurantInboxScreen());
                                }),
                                _tile(context, null, icon: Icons.delivery_dining_outlined, "Driver Inbox".tr, badge: LiveUnreadBadge.inbox(InboxKind.driver), () {
                                  Get.to(const DriverInboxScreen());
                                }),
                                _tile(context, null, icon: Icons.handyman_outlined, "Provider Inbox".tr, badge: LiveUnreadBadge.inbox(InboxKind.provider), () {
                                  Get.to(const ProviderInboxScreen());
                                }),
                                _tile(context, null, icon: Icons.engineering_outlined, "Worker Inbox".tr, badge: LiveUnreadBadge.inbox(InboxKind.worker), () {
                                  Get.to(const WorkerInboxScreen());
                                }),
                              ],
                            ),

                          // ── Preferences ──────────────────────────────────
                          DsTileGroup(
                            margin: _groupGap,
                            title: "Preferences".tr,
                            children: [
                              _tile(context, null, icon: Icons.translate_rounded, "Change Language".tr, () {
                                Get.to(const ChangeLanguageScreen());
                              }),
                              _tile(
                                context,
                                null,
                                icon: Icons.dark_mode_outlined,
                                "Dark Mode".tr,
                                () => controller.toggleDarkMode(!controller.isDarkModeSwitch.value),
                                trailing: Transform.scale(
                                  scale: 0.8,
                                  child: Obx(() => CupertinoSwitch(value: controller.isDarkModeSwitch.value, activeTrackColor: c.brand, onChanged: controller.toggleDarkMode)),
                                ),
                              ),
                            ],
                          ),

                          // ── Share Spideli ────────────────────────────────
                          DsTileGroup(
                            margin: _groupGap,
                            title: "Share Spideli".tr,
                            children: [
                              if (Constant.userModel != null)
                                _tile(context, null, icon: Icons.group_add_outlined, "Refer a Friend".tr, () {
                                  Get.to(const ReferFriendScreen());
                                }),
                              _tile(context, null, icon: Icons.ios_share_rounded, "Share app".tr, () {
                                SharePlus.instance.share(
                                  ShareParams(
                                    text:
                                        '${'Check out spideli, the ultimate all-in-one multi-vendor eBusiness platform.'.tr} \n\n${'Google Play:'.tr} ${Constant.googlePlayLink} \n\n${'App Store:'.tr} ${Constant.appStoreLink}',
                                    subject: 'Look what I made!'.tr,
                                  ),
                                );
                              }),
                              _tile(context, null, icon: Icons.star_outline_rounded, "Rate the app".tr, () {
                                final InAppReview inAppReview = InAppReview.instance;
                                inAppReview.requestReview();
                              }),
                            ],
                          ),

                          // ── Help & legal ─────────────────────────────────
                          DsTileGroup(
                            margin: _groupGap,
                            title: "Help & legal".tr,
                            children: [
                              if (Constant.userModel?.id != null)
                                _tile(context, null, icon: Icons.support_agent_rounded, "Help & Support", badge: LiveUnreadBadge.supportChat(), () {
                                  Get.to(HelpSupportScreen(isNavigateViaNotification: false));
                                }),
                              _tile(context, null, icon: Icons.privacy_tip_outlined, "Privacy Policy".tr, () {
                                Get.to(const TermsAndConditionScreen(type: "privacy"));
                              }),
                              _tile(context, null, icon: Icons.description_outlined, "Terms and Conditions".tr, () {
                                Get.to(const TermsAndConditionScreen(type: "termAndCondition"));
                              }),
                            ],
                          ),

                          // ── Session ──────────────────────────────────────
                          DsTileGroup(
                            margin: _groupGap,
                            children: [
                              Constant.userModel == null
                                  ? _tile(context, null, icon: Icons.login_rounded, "Log In".tr, tone: DsTone.success, () {
                                      Get.offAll(const LoginScreen());
                                    })
                                  : _tile(context, null, icon: Icons.logout_rounded, "Log out".tr, tone: DsTone.danger, showChevron: false, () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return CustomDialogBox(
                                            title: "Log out".tr,
                                            descriptions: "Are you sure you want to log out? You will need to enter your credentials to log back in.".tr,
                                            positiveString: "Log out".tr,
                                            negativeString: "Cancel".tr,
                                            positiveClick: () async {
                                              // Clears users/{uid}.fcmToken only while it is still
                                              // this phone's token (field-level). A whole-user save
                                              // with '' wiped the token of a phone the customer had
                                              // signed in on since.
                                              await PushTokenSync.clearOnSignOut();
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
                          Center(
                            child: Text("V : ${Constant.appVersion}", textAlign: TextAlign.center, style: t.caption.tabular),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  /// The space above every settings group, so each title belongs to its card.
  static const EdgeInsets _groupGap = EdgeInsets.only(top: DsSpace.xxl);

  /// One settings row: an [icon] (or an SVG asset) in a tinted well, the
  /// label, an optional [subtitle] and a chevron (or a custom [trailing] control).

  Widget _tile(
    BuildContext context,
    String? image,
    String title,
    VoidCallback? onPress, {
    String? subtitle,
    DsTone tone = DsTone.brand,
    IconData? icon,
    Widget? trailing,
    bool showChevron = true,

    /// Shown before the chevron (an unread count), unlike [trailing].
    Widget? badge,
  }) {
    return ProfileSettingsTile(image: image, icon: icon, title: title, subtitle: subtitle, onPress: onPress, tone: tone, trailing: trailing, showChevron: showChevron, badge: badge);
  }
}

/// A profile settings row: the icon in a tinted well, the label, then either
/// a custom [trailing] control, or an optional [badge] (an unread count)
/// followed by the chevron.
class ProfileSettingsTile extends StatelessWidget {
  /// An SVG asset for the well, or null to use [icon].
  final String? image;
  final IconData? icon;
  final String title;

  /// A short line saying what the row opens, where titles alone are ambiguous.
  final String? subtitle;
  final VoidCallback? onPress;
  final DsTone tone;
  final Widget? trailing;
  final bool showChevron;

  /// Shown before the chevron (an unread count), unlike [trailing].
  final Widget? badge;

  const ProfileSettingsTile({super.key, this.image, this.icon, required this.title, this.subtitle, this.onPress, this.tone = DsTone.brand, this.trailing, this.showChevron = true, this.badge});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final accent = c.tone(tone).strong;
    final String? asset = image;
    return DsListTile(
      title: title.tr,
      subtitle: subtitle,
      leading: asset == null || asset.isEmpty
          ? DsIconWell(icon: icon ?? Icons.circle_outlined, tone: tone, size: 40)
          : DsIconWell(
              tone: tone,
              size: 40,
              child: SvgPicture.asset(asset, height: 20, width: 20, colorFilter: ColorFilter.mode(accent, BlendMode.srcIn)),
            ),
      trailing: trailing ?? badge,
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
              SizedBox(
                width: double.infinity,
                child: DsSkeleton.box(height: 108, radius: DsRadius.xl),
              ),
              const DsGap(DsSpace.xxl),
              for (var group = 0; group < 3; group++) ...[
                DsSkeleton.line(width: 120, height: 12),
                const DsGap(DsSpace.md),
                SizedBox(
                  width: double.infinity,
                  child: DsSkeleton.box(height: 148, radius: DsRadius.lg),
                ),
                const DsGap(DsSpace.xl),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

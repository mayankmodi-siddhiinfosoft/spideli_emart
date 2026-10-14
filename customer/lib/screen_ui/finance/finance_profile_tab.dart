import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/my_profile_controller.dart';
import 'package:customer/screen_ui/change_password_screen/change_password_screen.dart';
import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_chat_screens.dart';
import 'package:customer/screen_ui/finance/finance_dashboard_screen.dart';
import 'package:customer/screen_ui/finance/finance_home_screen.dart';
import 'package:customer/screen_ui/finance/finance_restriction.dart';
import 'package:customer/screen_ui/finance/kyc_screen.dart';
import 'package:customer/screen_ui/finance/security_screens.dart';
import 'package:customer/screen_ui/finance/transactions_screen.dart';
import 'package:customer/screen_ui/help_support_screen/help_support_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/cashback_screen/cashback_offers_list.dart';
import 'package:customer/screen_ui/multi_vendor_service/change_language/change_language_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/driver_inbox_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/restaurant_inbox_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/dine_in_booking/dine_in_booking_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/dine_in_screeen/dine_in_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/edit_profile_screen/edit_profile_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/gift_card/gift_card_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/profile_screen/profile_actions.dart';
import 'package:customer/screen_ui/multi_vendor_service/refer_friend_screen/refer_friend_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/terms_and_condition/terms_and_condition_screen.dart';
import 'package:customer/screen_ui/notification_center/notification_center_screen.dart';
import 'package:customer/screen_ui/on_demand_service/provider_inbox_screen.dart';
import 'package:customer/screen_ui/on_demand_service/worker_inbox_screen.dart';
import 'package:customer/screen_ui/subscriptions/business_account_screen.dart';
import 'package:customer/screen_ui/subscriptions/my_plan_screen.dart';
import 'package:customer/screen_ui/subscriptions/my_store_subscriptions_screen.dart';
import 'package:customer/screen_ui/subscriptions/saved_payment_methods_screen.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/service/inbox_unread_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:customer/widget/live_unread_badge.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Profile tab: who the user is to Spideli Finance (verification, groups,
/// wallets, statements), then every option of the app's Profile screen
/// (account, money and rewards, dining, messages, preferences, sharing, help
/// and legal, log out, delete account) with the same behaviour - the
/// account actions are shared ([ProfileActions]) - in the finance style.
class FinanceProfileTab extends StatelessWidget {
  const FinanceProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return FinScaffold(
      title: "Profile".tr,
      showBack: false,
      // Its own controller (dark mode, account deletion): never the one of
      // the app's Profile screen, which may be open behind.
      body: GetBuilder<MyProfileController>(
        init: MyProfileController(),
        global: false,
        builder: (controller) => StreamBuilder<Map<String, dynamic>>(
          stream: FinanceService.myProfile(),
          builder: (context, snap) {
            final bool signedIn = Constant.userModel != null;
            final String? status = snap.data?['kycStatus']?.toString();
            final bool verified = (snap.data?['kycLevel']?.toString() ?? '').isNotEmpty;
            final String shown = verified ? KycStatus.approved : (status ?? 'none');
            // No verification status until the profile has loaded (not a
            // "not started" flash), nor when it could not be read.
            final bool known = snap.hasData;
            final String? chip = known ? (shown == KycStatus.approved ? 'verified' : shown) : null;
            final String? chipLabel = known ? KycStatus.label(verified ? KycStatus.approved : status).tr : null;
            return FinBody(children: [
              // The admin's restriction (blacklist), first: nothing when there is none.
              FinanceRestrictionNotice.of(snap.data),
              _ProfileHeader(status: chip, statusLabel: chipLabel, loading: !known && !snap.hasError),

              // ── Spideli Finance ─────────────────────────────────────────
              FinSection(
                title: "Spideli Finance".tr,
                divided: true,
                children: [
                  FinListTile(
                    icon: verified ? Icons.verified_user_outlined : Icons.badge_outlined,
                    iconTone: !known ? DsTone.neutral : (verified ? DsTone.success : DsTone.warning),
                    title: "Document verification".tr,
                    subtitle: snap.hasError ? "Could not load your verification status.".tr : null,
                    status: chip,
                    statusLabel: chipLabel,
                    chevron: true,
                    onTap: () => Get.to(() => const KycScreen()),
                  ),
                  _row(Icons.diversity_3_outlined, "Groups", subtitle: "Tontines, collective savings and loan groups", () => Get.to(() => const FinanceGroupsScreen())),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FinanceService.myAccounts(),
                    builder: (context, accounts) {
                      final String currencies =
                          activeWallets(accounts.data ?? const []).map((w) => w['currency']?.toString() ?? '').where((c) => c.isNotEmpty).join(' · ');
                      return FinListTile(
                        icon: Icons.account_balance_wallet_outlined,
                        iconTone: DsTone.brand,
                        title: "Wallets".tr,
                        subtitle: currencies.isEmpty ? "Your wallet opens with your first deposit.".tr : '${"One per currency".tr}: $currencies',
                        chevron: true,
                        onTap: () => FinanceDashboardController.showTab(FinanceTab.wallet, orOpen: () => const TransactionsScreen()),
                      );
                    },
                  ),
                  _row(Icons.forum_outlined, "Messages", subtitle: "Your tontine groups and members of your groups", () => Get.to(() => const FinanceChatsScreen())),
                  _row(Icons.picture_as_pdf_outlined, "Account statement", subtitle: "PDF of your transactions for a period", () => shareFinanceStatement(context)),
                  if (signedIn) ...[
                    _row(Icons.shield_outlined, "Security", subtitle: "Two-step verification with a code sent by SMS", () => Get.to(() => const FinanceSecurityScreen())),
                    _row(Icons.notifications_active_outlined, "Notifications", subtitle: "What Spideli Finance sends you by push, SMS and email",
                        () => Get.to(() => const FinanceNotificationsScreen())),
                  ],
                ],
              ),

              // ── Account ─────────────────────────────────────────────────
              if (signedIn)
                FinSection(
                  title: "Account".tr,
                  divided: true,
                  children: [
                    _row(Icons.person_outline_rounded, "Profile Information", subtitle: "Name, email and phone number", () => Get.to(const EditProfileScreen())),
                    _row(Icons.business_center_outlined, "Business account", subtitle: "Business prices once your company is verified", () => Get.to(() => const BusinessAccountScreen())),
                    _row(Icons.payments_outlined, "Payment methods", subtitle: "Mobile Money, Wave and bank accounts", () => Get.to(() => const SavedPaymentMethodsScreen())),
                    if (Constant.userModel?.provider == 'email') _row(Icons.lock_outline_rounded, "Change Password", () => Get.to(const ChangePasswordScreen())),
                  ],
                ),

              // ── Money & rewards ─────────────────────────────────────────
              FinSection(
                title: "Money & rewards".tr,
                divided: true,
                children: [
                  if (signedIn) _row(Icons.workspace_premium_outlined, "Subscriptions", subtitle: "Your Spideli plan and renewal", () => Get.to(() => const MyPlanScreen())),
                  if (signedIn)
                    _row(Icons.autorenew_rounded, "Store subscriptions", subtitle: "Regular deliveries from your stores", () => Get.to(() => const MyStoreSubscriptionsScreen())),
                  _row(Icons.card_giftcard_rounded, "Gift Card", () => Get.to(const GiftCardScreen())),
                  if (Constant.isCashbackActive == true) _row(Icons.local_offer_outlined, "Cashback Offers", () => Get.to(const CashbackOffersListScreen())),
                ],
              ),

              // ── Dining (when the open section offers dine-in) ───────────
              if (Constant.sectionConstantModel?.dineInActive == true)
                FinSection(
                  title: "Dining".tr,
                  divided: true,
                  children: [
                    _row(Icons.restaurant_rounded, "Dine-In", subtitle: "Find restaurants and book a table", () => Get.to(const DineInScreen())),
                    _row(Icons.event_seat_outlined, "Dine-In Booking", subtitle: "Your table reservations", () => Get.to(const DineInBookingScreen())),
                  ],
                ),

              // ── Messages ────────────────────────────────────────────────
              if (signedIn)
                FinSection(
                  title: "Messages".tr,
                  divided: true,
                  children: [
                    // Each row with its live unread total (nothing at 0).
                    _row(Icons.notifications_none_rounded, "Notifications", badge: LiveUnreadBadge.notifications(), () => Get.to(() => const NotificationCenterScreen())),
                    _row(Icons.storefront_outlined, "Store Inbox", badge: LiveUnreadBadge.inbox(InboxKind.store), () => Get.to(const RestaurantInboxScreen())),
                    _row(Icons.delivery_dining_outlined, "Driver Inbox", badge: LiveUnreadBadge.inbox(InboxKind.driver), () => Get.to(const DriverInboxScreen())),
                    _row(Icons.handyman_outlined, "Provider Inbox", badge: LiveUnreadBadge.inbox(InboxKind.provider), () => Get.to(const ProviderInboxScreen())),
                    _row(Icons.engineering_outlined, "Worker Inbox", badge: LiveUnreadBadge.inbox(InboxKind.worker), () => Get.to(const WorkerInboxScreen())),
                  ],
                ),

              // ── Preferences ─────────────────────────────────────────────
              FinSection(
                title: "Preferences".tr,
                divided: true,
                children: [
                  _row(Icons.translate_rounded, "Change Language", () => Get.to(const ChangeLanguageScreen())),
                  Obx(
                    () => FinListTile(
                      icon: Icons.dark_mode_outlined,
                      iconTone: DsTone.brand,
                      title: "Dark Mode".tr,
                      trailing: Transform.scale(
                        scale: 0.8,
                        child: CupertinoSwitch(value: controller.isDarkModeSwitch.value, activeTrackColor: FinColors.brand(context), onChanged: controller.toggleDarkMode),
                      ),
                      onTap: () => controller.toggleDarkMode(!controller.isDarkModeSwitch.value),
                    ),
                  ),
                ],
              ),

              // ── Share Spideli ───────────────────────────────────────────
              FinSection(
                title: "Share Spideli".tr,
                divided: true,
                children: [
                  if (signedIn) _row(Icons.group_add_outlined, "Refer a Friend", () => Get.to(const ReferFriendScreen())),
                  _row(Icons.ios_share_rounded, "Share app", ProfileActions.shareApp),
                  _row(Icons.star_outline_rounded, "Rate the app", ProfileActions.rateApp),
                ],
              ),

              // ── Help & legal ────────────────────────────────────────────
              FinSection(
                title: "Help & legal".tr,
                divided: true,
                children: [
                  if (Constant.userModel?.id != null)
                    _row(Icons.support_agent_rounded, "Help and support", subtitle: "Chat with the Spideli team", badge: LiveUnreadBadge.supportChat(),
                        () => Get.to(HelpSupportScreen(isNavigateViaNotification: false))),
                  _row(Icons.privacy_tip_outlined, "Privacy Policy", () => Get.to(const TermsAndConditionScreen(type: "privacy"))),
                  _row(Icons.description_outlined, "Terms and Conditions", () => Get.to(const TermsAndConditionScreen(type: "termAndCondition"))),
                  _row(Icons.apps_rounded, "Other Spideli services", subtitle: "Restaurants, parcels, rides and more", Get.back),
                ],
              ),

              // ── Session ─────────────────────────────────────────────────
              if (signedIn) ...[
                FinSection(
                  children: [
                    FinListTile(
                      icon: Icons.logout_rounded,
                      iconTone: DsTone.danger,
                      title: "Log out".tr,
                      onTap: () => ProfileActions.confirmLogout(context),
                    ),
                  ],
                ),
                const DsGap(DsSpace.lg),
                DsButton.dangerTonal(
                  label: "Delete Account".tr,
                  icon: Icons.delete_outline_rounded,
                  expand: true,
                  onPressed: () => ProfileActions.confirmDeleteAccount(context, controller),
                ),
              ],
              const DsGap(DsSpace.lg),
              Center(child: Text("V : ${Constant.appVersion}", textAlign: TextAlign.center, style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary).tabular)),
            ]);
          },
        ),
      ),
    );
  }

  /// A settings row: the icon, the label (a translation key), what it opens
  /// and an optional live [badge] before the chevron.
  static Widget _row(IconData icon, String title, VoidCallback onTap, {String? subtitle, Widget? badge}) => FinListTile(
        icon: icon,
        iconTone: DsTone.brand,
        title: title.tr,
        subtitle: subtitle?.tr,
        trailing: badge,
        chevron: true,
        onTap: onTap,
      );
}

/// The user, as Spideli Finance knows them: photo or initials, name, contact
/// and whether their identity is verified. Opens Profile Information, and
/// shows the changes made there on return.
class _ProfileHeader extends StatefulWidget {
  /// The verification status, once known.
  final String? status;
  final String? statusLabel;
  final bool loading;

  const _ProfileHeader({required this.status, required this.statusLabel, required this.loading});

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  Future<void> _edit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Get.to(const EditProfileScreen());
    if (mounted) setState(() {});
  }

  /// Whether the user turned on two-step verification (an SMS second factor).
  late final Future<bool> _twoStep = () async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      return u != null && (await u.multiFactor.getEnrolledFactors()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }();

  @override
  Widget build(BuildContext context) {
    final user = Constant.userModel;
    final String name = (user?.fullName() ?? '').trim();
    final String contact = [
      (user?.email ?? '').trim(),
      [(user?.countryCode ?? '').trim(), (user?.phoneNumber ?? '').trim()].where((p) => p.isNotEmpty).join(' '),
    ].where((p) => p.isNotEmpty).join(' · ');
    final bool verified = widget.status == 'verified';
    final Color muted = Colors.white.withValues(alpha: 0.72);
    final Color ring = verified ? FinColors.brass(context) : Colors.white.withValues(alpha: 0.35);
    // An ink identity card: photo with a ring (brass once verified), name,
    // contact, the verification badge, then three facts.
    Widget fact(String label, Widget value) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: DsTypography.caption.copyWith(color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            const DsGap(DsSpace.xxs),
            DefaultTextStyle.merge(style: DsTypography.bodyStrong.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis, child: value),
          ]),
        );
    return Semantics(
      button: user != null,
      child: ClipRRect(
        borderRadius: FinSpace.brHero,
        child: Material(
          color: FinColors.hero(context),
          child: InkWell(
            onTap: user == null ? null : _edit,
            child: Stack(children: [
              const Positioned.fill(child: FinPattern()),
              Padding(
                padding: const EdgeInsets.all(DsSpace.xl),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: 2)),
                      child: DsAvatar(imageUrl: user?.profilePictureURL, name: name.isEmpty ? null : name, size: 60),
                    ),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name.isEmpty ? "Spideli Finance".tr : name, style: DsTypography.headline.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (contact.isNotEmpty) ...[
                          const DsGap(DsSpace.xxs),
                          Text(contact, style: DsTypography.caption.copyWith(color: muted), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                        const DsGap(DsSpace.sm),
                        if (widget.status != null && widget.statusLabel != null)
                          _Badge(verified: verified, label: widget.statusLabel!)
                        else if (widget.loading)
                          DsShimmer(child: DsSkeleton.line(width: 96, height: 20)),
                      ]),
                    ),
                    if (user != null) Icon(Icons.chevron_right_rounded, color: muted),
                  ]),
                  const DsGap(DsSpace.lg),
                  Container(height: 1, color: Colors.white.withValues(alpha: 0.14)),
                  const DsGap(DsSpace.md),
                  Row(children: [
                    fact("Identity".tr, Text(widget.statusLabel ?? '—')),
                    fact(
                      "Wallets".tr,
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: FinanceService.myAccounts(),
                        builder: (context, a) {
                          final list = activeWallets(a.data ?? const []).map((w) => w['currency']?.toString() ?? '').where((c) => c.isNotEmpty).toList();
                          return Text(list.isEmpty ? '—' : list.join(' · '));
                        },
                      ),
                    ),
                    fact(
                      "Two-step".tr,
                      FutureBuilder<bool>(future: _twoStep, builder: (context, on) => Text(!on.hasData ? '…' : (on.data! ? "On".tr : "Off".tr))),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The verification badge of the identity card: brass with a seal once
/// verified, otherwise a quiet outline with the status.
class _Badge extends StatelessWidget {
  final bool verified;
  final String label;

  const _Badge({required this.verified, required this.label});

  @override
  Widget build(BuildContext context) {
    final Color fg = verified ? const Color(0xFF2A1E05) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.xxs),
      decoration: BoxDecoration(
        color: verified ? const Color(0xFFE3C17A) : Colors.white.withValues(alpha: 0.12),
        borderRadius: DsRadius.brPill,
        border: verified ? null : Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(verified ? Icons.verified_rounded : Icons.shield_outlined, size: 14, color: fg),
        const DsGap(DsSpace.xxs),
        Text(label, style: DsTypography.caption.copyWith(color: fg, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

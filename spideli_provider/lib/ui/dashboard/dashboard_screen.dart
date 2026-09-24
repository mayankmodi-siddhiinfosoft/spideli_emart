// ignore_for_file: deprecated_member_use

import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/controller/dashboard_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Dashboard shell (archetype A): the app bar + the premium drawer that owns
/// navigation for every drawer tab. The drawer keeps exactly the same items,
/// ids, order and `onSelectItem` behaviour – only the presentation changed:
/// a brand-gradient profile header, a soft "pill" for the selected row and a
/// destructive log-out row.
class DashBoardScreen extends StatelessWidget {
  const DashBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes the page to theme changes.
    Provider.of<DarkThemeProvider>(context);
    return GetX<DashBoardController>(
        init: DashBoardController(),
        builder: (controller) {
          final c = context.dsColors;
          return Scaffold(
            backgroundColor: c.background,
            appBar: DsAppBar(
              title: controller.drawerItems[controller.selectedDrawerIndex.value].title,
              showBack: false,
              leading: Builder(builder: (context) {
                return DsIconButton(
                  icon: Icons.menu_rounded,
                  semanticLabel: 'Menu'.tr,
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                );
              }),
              actions: [
                DsIconButton(
                  icon: Icons.info_outline_rounded,
                  semanticLabel: 'Status Info'.tr,
                  variant: DsIconButtonVariant.tonal,
                  size: 36,
                  onPressed: () {
                    showResetPwdAlertDialog(context);
                  },
                ),
              ],
            ),
            drawer: buildAppDrawer(context, controller),
            body: WillPopScope(
                onWillPop: controller.onWillPop,
                child: DsAsync(
                  isLoading: controller.isLoading.value == true,
                  skeleton: const DsSkeletonList(carded: true),
                  builder: (_) => controller.getDrawerItemWidget(controller.selectedDrawerIndex.value),
                )),
          );
        });
  }

  Widget buildAppDrawer(BuildContext context, DashBoardController controller) {
    final c = context.dsColors;
    final t = context.dsText;
    var drawerOptions = <Widget>[];
    for (var i = 0; i < controller.drawerItems.length; i++) {
      var d = controller.drawerItems[i];
      final bool selected = i == controller.selectedDrawerIndex.value;
      final bool destructive = d.id == 'logout';
      final Color fg = destructive
          ? c.dangerStrong
          : selected
              ? c.brandStrong
              : c.textSecondary;
      drawerOptions.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: DsSpace.md),
        child: Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: selected ? c.brandSoft : Colors.transparent,
            borderRadius: DsRadius.brMd,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                controller.onSelectItem(i);
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.md, horizontal: DsSpace.md),
                  child: Row(
                    children: [
                      SvgPicture.asset(d.icon, width: 20, colorFilter: ColorFilter.mode(fg, BlendMode.srcIn)),
                      const DsGap(DsSpace.lg),
                      Expanded(
                        child: Text(
                          d.title,
                          style: (selected ? t.label : t.bodyStrong).withColor(fg),
                        ),
                      ),
                      if (selected)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
    }
    return Drawer(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _DrawerHeader(user: controller.user.value),
          if ((selectedSectionModel?.adminCommision?.enable == true ||
                  isSubscriptionModelApplied == true) &&
              MyAppState.currentUser?.subscriptionPlanId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.md, DsSpace.md, 0),
              child: SubscriptionPlanWidget(
                onClick: () {
                  Get.back();
                  // By id, not position: inserting Documents shifted the indexes.
                  final int index = controller.drawerItems.indexWhere((e) => e.id == 'subscription');
                  if (index >= 0) controller.selectedDrawerIndex.value = index;
                },
                userModel: MyAppState.currentUser!,
              ),
            ),
          const DsGap(DsSpace.md),
          Column(children: drawerOptions),
          const DsGap(DsSpace.xxl),
        ],
      ),
    );
  }

  void showResetPwdAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DsDialog(
          title: 'Status Info',
          icon: Icons.info_outline_rounded,
          tone: DsTone.info,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              _StatusInfoRow(
                tone: DsTone.brand,
                icon: Icons.fiber_new_rounded,
                title: "New Booking : ",
                description: "This status indicates that a new booking request has been received from a customer.",
              ),
              _StatusInfoRow(
                tone: DsTone.info,
                icon: Icons.today_rounded,
                title: "Today : ",
                description: "This status refers to bookings that are scheduled for the current day.",
              ),
              _StatusInfoRow(
                tone: DsTone.warning,
                icon: Icons.event_rounded,
                title: "Upcoming : ",
                description: "Bookings that are scheduled for future dates but not for the current day fall under this status.",
              ),
              _StatusInfoRow(
                tone: DsTone.success,
                icon: Icons.task_alt_rounded,
                title: "Completed : ",
                description: "This status signifies that the service has been successfully provided to the customer, and the booking process is concluded.",
              ),
              _StatusInfoRow(
                tone: DsTone.danger,
                icon: Icons.cancel_outlined,
                title: "Canceled",
                description: "Bookings that have been canceled either by the customer or the service provider are categorized under this status.",
                last: true,
              ),
            ],
          ),
          primaryLabel: 'Close',
          onPrimary: () {
            Navigator.pop(context); //close Dialog
          },
        );
      },
    );
  }
}

/// Brand-gradient profile block at the top of the drawer.
class _DrawerHeader extends StatelessWidget {
  final User user;

  const _DrawerHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: BoxDecoration(
        gradient: DsGradients.brand(context),
        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(DsRadius.xxl)),
      ),
      padding: EdgeInsets.fromLTRB(DsSpace.xl, top + DsSpace.xl, DsSpace.xl, DsSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsAvatar(
            imageUrl: user.profilePictureURL,
            name: user.fullName(),
            size: 68,
            ring: true,
          ),
          const DsGap(DsSpace.md),
          Text(
            user.fullName(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DsTypography.title.copyWith(color: Colors.white),
          ),
          const DsGap(DsSpace.xxs),
          Text(
            user.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DsTypography.bodySm.copyWith(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

/// One tone-coded paragraph of the booking-status legend.
class _StatusInfoRow extends StatelessWidget {
  final DsTone tone;
  final IconData icon;
  final String title;
  final String description;
  final bool last;

  const _StatusInfoRow({required this.tone, required this.icon, required this.title, required this.description, this.last = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : DsSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsIconWell(icon: icon, tone: tone, size: 34),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: t.label.withColor(c.tone(tone).strong)),
                const DsGap(DsSpace.xxs),
                Text(description, style: t.bodySm),
              ],
            ),
          ),
        ],
      ),
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
    return DsCard.gradient(
      gradient: DsGradients.deep(context),
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsAvatar(
                imageUrl: userModel.subscriptionPlan?.image ?? '',
                name: userModel.subscriptionPlan?.name ?? '',
                size: 40,
                fallbackIcon: Icons.workspace_premium_outlined,
              ),
              const DsGap(DsSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userModel.subscriptionPlan?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsTypography.titleSm.copyWith(color: Colors.white),
                    ),
                    const DsGap(DsSpace.xxs),
                    Text(
                      userModel.subscriptionPlan?.type == 'free' ? 'free' : amountShow(amount: userModel.subscriptionPlan?.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsTypography.caption.copyWith(color: Colors.white.withValues(alpha: 0.78)),
                    ),
                  ],
                ),
              ),
              const DsGap(DsSpace.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Expiry Date'.tr,
                    style: DsTypography.overline.copyWith(color: Colors.white.withValues(alpha: 0.78)),
                  ),
                  const DsGap(DsSpace.xxs),
                  Text(
                    userModel.subscriptionPlan?.expiryDay == "-1" ? "LifeTime" : timestampToDateTime(userModel.subscriptionExpiryDate!),
                    textAlign: TextAlign.end,
                    style: DsTypography.caption.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          const DsGap(DsSpace.lg),
          DsButton.primary(
            label: "Change Plan".tr,
            icon: Icons.auto_awesome_rounded,
            size: DsButtonSize.sm,
            expand: true,
            color: Colors.white,
            onPressed: onClick,
          ),
          if (selectedSectionModel?.adminCommision?.enable == true)
            Visibility(
              visible: MyAppState.currentUser?.adminCommission?.enable == true,
              child: Padding(
                padding: const EdgeInsets.only(top: DsSpace.md),
                child: Text(
                  "${MyAppState.currentUser?.adminCommission?.type == 'percentage' ? "${MyAppState.currentUser?.adminCommission?.commission}%" : "${amountShow(amount: MyAppState.currentUser?.adminCommission?.commission.toString())} Flat"} ${"admin commission will be charged from your account after the booking is accepted.".tr}",
                  style: DsTypography.caption.copyWith(color: Colors.white.withValues(alpha: 0.78), fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

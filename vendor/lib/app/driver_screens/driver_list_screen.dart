import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/app/add_restaurant_screen/add_restaurant_screen.dart';
import 'package:vendor/app/driver_screens/add_driver_screen.dart';
import 'package:vendor/app/verification_screen/verification_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/driver_list_controller.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/themes/ds/ds.dart';

class DriverListScreen extends StatelessWidget {
  const DriverListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: DriverListController(),
      builder: (controller) {
        final c = context.dsColors;
        return DsScaffold.collapsing(
          title: "Manage Delivery Man".tr,
          actions: [
            ((Constant.userModel?.isAutoVerify == false && Constant.userModel?.isDocumentVerify == false) || (Constant.userModel?.vendorID == null || Constant.userModel?.vendorID?.isEmpty == true))
                ? SizedBox()
                : DsButton.tonal(
                    label: "Add".tr,
                    icon: Icons.add_rounded,
                    size: DsButtonSize.sm,
                    onPressed: () {
                      Get.to(const AddDriverScreen())?.then((value) {
                        if (value == true) {
                          controller.getAllDriverList();
                        }
                      });
                    },
                  ),
          ],
          slivers: [
            if (controller.isLoading.value)
              const DsSliverResponsive(
                top: DsSpace.sm,
                sliver: SliverToBoxAdapter(child: DsSkeletonList(itemCount: 6, padding: EdgeInsets.zero)),
              )
            else if (Constant.userModel?.isDocumentVerify == false && Constant.userModel?.isDocumentVerify == false)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(
                  tone: DsTone.warning,
                  illustration: _SvgHalo(asset: "assets/icons/ic_document.svg", tone: DsTone.warning),
                  title: "Document Verification in Pending".tr,
                  message: "Your documents are being reviewed. We will notify you once the verification is complete.".tr,
                  actionLabel: "View Status".tr,
                  actionIcon: Icons.verified_user_outlined,
                  onAction: () async {
                    Get.to(const VerificationScreen());
                  },
                ),
              )
            else if (Constant.userModel?.vendorID?.isEmpty == true || Constant.userModel?.vendorID == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(
                  illustration: _SvgHalo(asset: "assets/icons/ic_building_two.svg", tone: DsTone.brand),
                  title: "Add Your First Store".tr,
                  message: "Get started by adding your store details to manage your delivery men.".tr,
                  actionLabel: "Add Store".tr,
                  actionIcon: Icons.storefront_outlined,
                  onAction: () async {
                    Get.to(const AddRestaurantScreen());
                  },
                ),
              )
            else if (controller.driverUserList.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(
                  illustration: SvgPicture.asset("assets/icons/ic_manage_deliveryman.svg"),
                  title: "No Delivery Men Available".tr,
                  message: "No Delivery Men found! Add your first Delivery Man to start using the self-delivery feature.".tr,
                  actionLabel: "Add Delivery Man".tr,
                  actionIcon: Icons.person_add_alt_1_rounded,
                  onAction: () async {
                    Get.to(const AddDriverScreen())?.then((value) {
                      if (value == true) {
                        controller.getAllDriverList();
                      }
                    });
                  },
                ),
              )
            else ...[
              DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                top: DsSpace.sm,
                sliver: SliverToBoxAdapter(
                  child: GetBuilder<DriverListController>(
                    builder: (controller) => DsFadeSlideIn(child: _FleetSummary(drivers: controller.driverUserList)),
                  ),
                ),
              ),
              DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                top: DsSpace.xl,
                bottom: DsSpace.lg,
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DsSectionHeader(title: "Delivery Man".tr, icon: Icons.delivery_dining_rounded, padding: const EdgeInsets.only(bottom: DsSpace.md)),
                      DsAdaptiveGrid(
                        minItemWidth: 340,
                        maxColumns: 3,
                        children: [
                          for (int index = 0; index < controller.driverUserList.length; index++)
                            DsFadeSlideIn(
                              index: index,
                              child: GetBuilder<DriverListController>(
                                builder: (controller) {
                                  return _DriverCard(
                                    driver: controller.driverUserList[index],
                                    onTap: () {
                                      Get.to(const AddDriverScreen(), arguments: {"driverModel": controller.driverUserList[index]})!.then((value) {
                                        if (value == true) {
                                          controller.getAllDriverList();
                                        }
                                      });
                                    },
                                    onActiveChanged: (value) {
                                      controller.driverUserList[index].active = value;
                                      controller.updateDriver(controller.driverUserList[index]);
                                      controller.update();
                                    },
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
          backgroundColor: c.background,
        );
      },
    );
  }
}

/// Small overview card above the roster: total, on duty and off duty.
class _FleetSummary extends StatelessWidget {
  final List<UserModel> drivers;
  const _FleetSummary({required this.drivers});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final total = drivers.length;
    final active = drivers.where((d) => d.active == true).length;
    return DsCard.gradient(
      gradient: DsGradients.brand(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DsIconWell(icon: Icons.two_wheeler_rounded, onBrand: true),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Delivery Man".tr, style: t.labelSm.withColor(Colors.white.withValues(alpha: 0.85))),
                    DsAnimatedCounter(value: total, style: t.metric.withColor(Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const DsGap(DsSpace.lg),
          Row(
            children: [
              Expanded(child: _SummaryPill(label: "Active".tr, value: active, dot: c.success)),
              const DsGap(DsSpace.md),
              Expanded(child: _SummaryPill(label: "Inactive".tr, value: total - active, dot: Colors.white.withValues(alpha: 0.6))),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final int value;
  final Color dot;
  const _SummaryPill({required this.label, required this.value, required this.dot});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: DsRadius.brMd),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const DsGap(DsSpace.sm),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm.withColor(Colors.white))),
          Text('$value', style: t.label.withColor(Colors.white).tabular),
        ],
      ),
    );
  }
}

/// Roster card: avatar with presence dot, name + contact rows, status chip
/// and the on/off switch.
class _DriverCard extends StatelessWidget {
  final UserModel driver;
  final VoidCallback onTap;
  final ValueChanged<bool> onActiveChanged;
  const _DriverCard({required this.driver, required this.onTap, required this.onActiveChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final isActive = driver.active ?? false;
    final name = "${driver.firstName ?? ''} ${driver.lastName ?? ''}";
    return DsCard.outlined(
      onTap: onTap,
      padding: const EdgeInsets.all(DsSpace.md),
      semanticLabel: name,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsAvatar(
            imageUrl: driver.profilePictureURL == null || driver.profilePictureURL == '' ? null : driver.profilePictureURL.toString(),
            name: name,
            size: 56,
            statusTone: isActive ? DsTone.success : DsTone.neutral,
          ),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm.withColor(c.textPrimary)),
                const DsGap(DsSpace.xs),
                _ContactLine(icon: Icons.phone_outlined, text: "${driver.countryCode} ${driver.phoneNumber}"),
                _ContactLine(icon: Icons.mail_outline_rounded, text: driver.email.toString()),
                const DsGap(DsSpace.sm),
                AnimatedSwitcher(
                  duration: DsMotion.of(context, DsMotion.fast),
                  child: DsStatusChip(
                    key: ValueKey(isActive),
                    label: isActive ? "Active".tr : "Inactive".tr,
                    tone: isActive ? DsTone.success : DsTone.neutral,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: "Active".tr,
            child: Switch.adaptive(value: isActive, onChanged: onActiveChanged),
          ),
        ],
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ContactLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.xxs),
      child: Row(
        children: [
          Icon(icon, size: 14, color: c.textMuted),
          const DsGap(DsSpace.xs),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm.withColor(c.textSecondary))),
        ],
      ),
    );
  }
}

/// SVG illustration inside a soft tone halo, for the gate/empty states.
class _SvgHalo extends StatelessWidget {
  final String asset;
  final DsTone tone;
  const _SvgHalo({required this.asset, required this.tone});

  @override
  Widget build(BuildContext context) {
    final tc = context.dsColors.tone(tone);
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(color: tc.soft, shape: BoxShape.circle, border: Border.all(color: tc.main.withValues(alpha: 0.2))),
        padding: const EdgeInsets.all(DsSpace.xxxl),
        child: SvgPicture.asset(asset),
      ),
    );
  }
}

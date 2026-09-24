import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cab_dashboard_controller.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../controllers/on_demand_dashboard_controller.dart';

class OnDemandDashboardScreen extends StatelessWidget {
  const OnDemandDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      // The theme flag drives this Obx (unchanged behaviour).
      final isDark = themeController.isDark.value;
      return GetX(
        init: OnDemandDashboardController(),
        builder: (controller) {
          final c = context.dsColors;
          return Scaffold(
            backgroundColor: c.background,
            body: controller.pageList[controller.selectedIndex.value],
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.divider)),
                boxShadow: isDark ? null : DsShadows.sm(context),
              ),
              child: SafeArea(
                top: false,
                child: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  showUnselectedLabels: true,
                  showSelectedLabels: true,
                  selectedFontSize: 12,
                  unselectedFontSize: 12,
                  elevation: 0,
                  selectedLabelStyle: DsTypography.labelSm,
                  unselectedLabelStyle: DsTypography.caption.copyWith(fontWeight: FontWeight.w500),
                  currentIndex: controller.selectedIndex.value,
                  backgroundColor: Colors.transparent,
                  selectedItemColor: c.brandStrong,
                  unselectedItemColor: c.textMuted,
                  onTap: (int index) {
                    if (index == 0) {
                      Get.put(CabDashboardController());
                    }
                    controller.selectedIndex.value = index;
                  },
                  items:
                      Constant.walletSetting == false
                          ? [
                            navigationBarItem(isDark, index: 0, assetIcon: "assets/icons/ic_home_cab.svg", label: 'Home'.tr, controller: controller),
                            navigationBarItem(isDark, index: 1, assetIcon: "assets/icons/ic_fav.svg", label: 'Favourites'.tr, controller: controller),
                            navigationBarItem(isDark, index: 2, assetIcon: "assets/icons/ic_booking_cab.svg", label: 'My Bookings'.tr, controller: controller),
                            navigationBarItem(isDark, index: 3, assetIcon: "assets/icons/ic_profile.svg", label: 'Profile'.tr, controller: controller),
                          ]
                          : [
                            navigationBarItem(isDark, index: 0, assetIcon: "assets/icons/ic_home_cab.svg", label: 'Home'.tr, controller: controller),
                            navigationBarItem(isDark, index: 1, assetIcon: "assets/icons/ic_fav.svg", label: 'Favourites'.tr, controller: controller),

                            navigationBarItem(isDark, index: 2, assetIcon: "assets/icons/ic_booking_cab.svg", label: 'My Bookings'.tr, controller: controller),
                            navigationBarItem(isDark, index: 3, assetIcon: "assets/icons/ic_wallet_cab.svg", label: 'Wallet'.tr, controller: controller),
                            navigationBarItem(isDark, index: 4, assetIcon: "assets/icons/ic_profile.svg", label: 'Profile'.tr, controller: controller),
                          ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  BottomNavigationBarItem navigationBarItem(bool isDark, {required int index, required String label, required String assetIcon, required OnDemandDashboardController controller}) {
    return BottomNavigationBarItem(
      icon: _NavIcon(assetIcon: assetIcon, selected: controller.selectedIndex.value == index, label: label),
      label: label,
    );
  }
}

/// Bottom-navigation icon with an animated selected pill (private to this screen).
class _NavIcon extends StatelessWidget {
  final String assetIcon;
  final bool selected;
  final String label;

  const _NavIcon({required this.assetIcon, required this.selected, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Semantics(
      label: label,
      selected: selected,
      child: AnimatedContainer(
        duration: DsMotion.of(context, DsMotion.fast),
        curve: DsMotion.standard,
        margin: const EdgeInsets.only(bottom: DsSpace.xxs, top: DsSpace.xs),
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xs),
        decoration: BoxDecoration(color: selected ? c.brandSoft : Colors.transparent, borderRadius: DsRadius.brPill),
        child: SvgPicture.asset(
          assetIcon,
          height: 22,
          width: 22,
          colorFilter: ColorFilter.mode(selected ? c.brandStrong : c.textMuted, BlendMode.srcIn),
        ),
      ),
    );
  }
}

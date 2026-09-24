import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/parcel_dashboard_controller.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

/// Parcel section shell: the tab host for Home / My Bookings / (Wallet) /
/// Profile. The bar sits on a DS surface with a hairline separator and the
/// active tab gets a soft brand well behind its icon.
class ParcelDashboardScreen extends StatelessWidget {
  const ParcelDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      final c = DsColors.resolve(isDark);
      return GetX(
        init: ParcelDashboardController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: c.background,
            body: controller.pageList[controller.selectedIndex.value],
            bottomNavigationBar: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.divider)),
                boxShadow: [
                  BoxShadow(
                    color: c.shadow.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                showUnselectedLabels: true,
                showSelectedLabels: true,
                selectedFontSize: 12,
                unselectedFontSize: 12,
                elevation: 0,
                selectedLabelStyle: DsTypography.labelSm.copyWith(fontSize: 12),
                unselectedLabelStyle: DsTypography.labelSm.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
                currentIndex: controller.selectedIndex.value,
                backgroundColor: Colors.transparent,
                selectedItemColor: c.brandStrong,
                unselectedItemColor: c.textMuted,
                onTap: (int index) {
                  if (index == 0) {
                    Get.put(ParcelDashboardController());
                  }
                  controller.selectedIndex.value = index;
                },
                items: Constant.walletSetting == false
                    ? [
                        navigationBarItem(isDark, index: 0, assetIcon: "assets/icons/ic_home_parcel.svg", label: 'Home'.tr, controller: controller),
                        navigationBarItem(isDark, index: 1, assetIcon: "assets/icons/ic_mybooking_parcel.svg", label: 'My Bookings'.tr, controller: controller),
                        navigationBarItem(isDark, index: 2, assetIcon: "assets/icons/ic_profile_parcel.svg", label: 'Profile'.tr, controller: controller),
                      ]
                    : [
                        navigationBarItem(isDark, index: 0, assetIcon: "assets/icons/ic_home_parcel.svg", label: 'Home'.tr, controller: controller),
                        navigationBarItem(isDark, index: 1, assetIcon: "assets/icons/ic_mybooking_parcel.svg", label: 'My Bookings'.tr, controller: controller),
                        navigationBarItem(isDark, index: 2, assetIcon: "assets/icons/ic_wallet_parcel.svg", label: 'Wallet'.tr, controller: controller),
                        navigationBarItem(isDark, index: 3, assetIcon: "assets/icons/ic_profile_parcel.svg", label: 'Profile'.tr, controller: controller),
                      ],
              ),
            ),
          );
        },
      );
    });
  }

  BottomNavigationBarItem navigationBarItem(bool isDark, {required int index, required String label, required String assetIcon, required ParcelDashboardController controller}) {
    final c = DsColors.resolve(isDark);
    final selected = controller.selectedIndex.value == index;
    final tint = selected ? c.brandStrong : c.textMuted;
    final double size = label == 'Wallet'.tr ? 18 : 22;
    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: DsMotion.base,
        curve: DsMotion.emphasized,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: 5),
        decoration: BoxDecoration(color: selected ? c.brandSoft : Colors.transparent, borderRadius: DsRadius.brPill),
        child: SvgPicture.asset(assetIcon, height: size, width: size, colorFilter: ColorFilter.mode(tint, BlendMode.srcIn)),
      ),
      label: label,
    );
  }
}

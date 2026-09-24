import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/dash_board_controller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../controllers/theme_controller.dart';

class DashBoardScreen extends StatelessWidget {
  const DashBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      // Read kept so the shell re-themes when dark mode toggles.
      themeController.isDark.value;
      return GetX(
        init: DashBoardController(),
        builder: (controller) {
          final c = context.dsColors;
          final selected = controller.selectedIndex.value;
          final items = Constant.walletSetting == false
              ? [
                  navigationBarItem(context, index: 0, assetIcon: "assets/icons/ic_home_cab.svg", label: 'Home'.tr, selectedIndex: selected),
                  navigationBarItem(context, index: 1, assetIcon: "assets/icons/ic_fav.svg", label: 'Favourites'.tr, selectedIndex: selected),
                  navigationBarItem(context, index: 2, assetIcon: "assets/icons/ic_orders.svg", label: 'Orders'.tr, selectedIndex: selected),
                  navigationBarItem(context, index: 3, assetIcon: "assets/icons/ic_profile.svg", label: 'Profile'.tr, selectedIndex: selected),
                ]
              : [
                  navigationBarItem(context, index: 0, assetIcon: "assets/icons/ic_home_cab.svg", label: 'Home'.tr, selectedIndex: selected),
                  navigationBarItem(context, index: 1, assetIcon: "assets/icons/ic_fav.svg", label: 'Favourites'.tr, selectedIndex: selected),
                  navigationBarItem(context, index: 2, assetIcon: "assets/icons/ic_wallet.svg", label: 'Wallet'.tr, selectedIndex: selected),
                  navigationBarItem(context, index: 3, assetIcon: "assets/icons/ic_orders.svg", label: 'Orders'.tr, selectedIndex: selected),
                  navigationBarItem(context, index: 4, assetIcon: "assets/icons/ic_profile.svg", label: 'Profile'.tr, selectedIndex: selected),
                ];
          return Scaffold(
            backgroundColor: c.background,
            body: controller.pageList[selected],
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.divider)),
                boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: c.isDark ? 0.34 : 0.05), blurRadius: 20, offset: const Offset(0, -6))],
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                showUnselectedLabels: true,
                showSelectedLabels: true,
                elevation: 0,
                selectedFontSize: 11,
                unselectedFontSize: 11,
                selectedLabelStyle: DsTypography.labelSm.copyWith(fontSize: 11),
                unselectedLabelStyle: DsTypography.caption.copyWith(fontSize: 11),
                currentIndex: selected,
                backgroundColor: Colors.transparent,
                selectedItemColor: c.brandStrong,
                unselectedItemColor: c.textMuted,
                onTap: (int index) {
                  if (index == 0) {
                    Get.put(DashBoardController());
                  }
                  controller.selectedIndex.value = index;
                },
                items: items,
              ),
            ),
          );
        },
      );
    });
  }

  BottomNavigationBarItem navigationBarItem(BuildContext context, {required int index, required String label, required String assetIcon, required int selectedIndex}) {
    return BottomNavigationBarItem(
      icon: _NavIcon(assetIcon: assetIcon, label: label, active: selectedIndex == index),
      label: label,
    );
  }
}

/// Bottom-nav icon with an animated brand pill behind the active item.
class _NavIcon extends StatelessWidget {
  final String assetIcon;
  final String label;
  final bool active;
  const _NavIcon({required this.assetIcon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final color = active ? c.brandStrong : c.textMuted;
    return Semantics(
      label: label,
      selected: active,
      child: AnimatedContainer(
        duration: DsMotion.of(context, DsMotion.base),
        curve: DsMotion.emphasized,
        margin: const EdgeInsets.only(top: DsSpace.xs, bottom: DsSpace.xxs),
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xs),
        decoration: BoxDecoration(
          color: active ? c.brandSoft : Colors.transparent,
          borderRadius: DsRadius.brPill,
        ),
        child: SvgPicture.asset(
          assetIcon,
          height: 21,
          width: 21,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ),
    );
  }
}

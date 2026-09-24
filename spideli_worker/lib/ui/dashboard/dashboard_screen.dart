import 'package:spideliworker/controller/dashboard_controller.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// App shell: Jobs / Documents / Profile.
///
/// Phones keep the (theme-styled) Material `BottomNavigationBar`; tablets and
/// iPad switch to a `NavigationRail` on the leading edge, wired to the same
/// `controller.onItemTapped`.
class DashBoardScreen extends StatelessWidget {
  const DashBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes the shell to theme changes.
    Provider.of<DarkThemeProvider>(context);

    return GetX<DashBoardController>(
        init: DashBoardController(),
        builder: (controller) {
          // Read synchronously so this GetX tracks the selected tab.
          final int selected = controller.selectedIndex.value;
          final c = context.dsColors;
          final l = context.dsLayout;

          final pages = PageView.builder(
            controller: controller.pageController,
            onPageChanged: (value) {
              controller.selectedIndex.value = value;
            },
            itemCount: controller.pageList.length,
            itemBuilder: (context, index) {
              return controller.pageList[controller.selectedIndex.value];
            },
          );

          final destinations = <_NavDestination>[
            _NavDestination(label: 'Jobs'.tr, assetIcon: "assets/icons/ic_order.svg"),
            _NavDestination(label: 'Documents'.tr, icon: Icons.badge_outlined, selectedIcon: Icons.badge_rounded),
            _NavDestination(label: 'Profile'.tr, assetIcon: "assets/icons/ic_profile.svg"),
          ];

          if (l.isWide) {
            return Scaffold(
              backgroundColor: c.background,
              body: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: BorderDirectional(end: BorderSide(color: c.divider)),
                    ),
                    child: SafeArea(
                      right: false,
                      child: NavigationRail(
                        backgroundColor: c.surface,
                        selectedIndex: selected,
                        onDestinationSelected: controller.onItemTapped,
                        labelType: NavigationRailLabelType.all,
                        groupAlignment: -0.85,
                        useIndicator: false,
                        selectedLabelTextStyle: context.dsText.labelSm.withColor(c.brandStrong),
                        unselectedLabelTextStyle: context.dsText.labelSm.withColor(c.textMuted),
                        destinations: [
                          for (int i = 0; i < destinations.length; i++)
                            NavigationRailDestination(
                              icon: destinations[i].buildIcon(context, selected: false),
                              selectedIcon: destinations[i].buildIcon(context, selected: true),
                              label: Text(destinations[i].label),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(child: pages),
                ],
              ),
            );
          }

          return Scaffold(
            backgroundColor: c.background,
            body: pages,
            bottomNavigationBar: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.divider)),
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                showUnselectedLabels: true,
                showSelectedLabels: true,
                currentIndex: selected,
                elevation: 0,
                onTap: controller.onItemTapped,
                items: [
                  for (int i = 0; i < destinations.length; i++)
                    BottomNavigationBarItem(
                      icon: destinations[i].buildIcon(context, selected: selected == i),
                      label: destinations[i].label,
                    ),
                ],
              ),
            ),
          );
        });
  }
}

class _NavDestination {
  final String label;
  final String? assetIcon;
  final IconData? icon;
  final IconData? selectedIcon;

  const _NavDestination({required this.label, this.assetIcon, this.icon, this.selectedIcon});

  Widget buildIcon(BuildContext context, {required bool selected}) {
    final c = context.dsColors;
    final color = selected ? c.brand : c.textMuted;
    final Widget glyph = assetIcon != null
        ? SvgPicture.asset(
            assetIcon!,
            height: 22,
            width: 22,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          )
        : Icon(selected ? (selectedIcon ?? icon) : icon, size: 22, color: color);
    return AnimatedContainer(
      duration: DsMotion.of(context, DsMotion.base),
      curve: DsMotion.standard,
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xs),
      margin: const EdgeInsets.only(bottom: DsSpace.xxs),
      decoration: BoxDecoration(
        color: selected ? c.brandSoft : Colors.transparent,
        borderRadius: DsRadius.brPill,
      ),
      child: glyph,
    );
  }
}

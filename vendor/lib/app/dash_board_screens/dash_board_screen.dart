import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/dash_board_controller.dart';

class DashBoardScreen extends StatelessWidget {
  const DashBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetX(
        init: DashBoardController(),
        builder: (controller) {
          return PopScope(
            canPop: controller.canPopNow.value,
            onPopInvoked: (didPop) {
              final now = DateTime.now();
              if (controller.currentBackPressTime == null || now.difference(controller.currentBackPressTime!) > const Duration(seconds: 2)) {
                controller.currentBackPressTime = now;
                controller.canPopNow.value = false;
                ShowToastDialog.showToast("Double press to exit".tr);
                return;
              } else {
                controller.canPopNow.value = true;
              }
            },
            child: Scaffold(
              backgroundColor: context.dsColors.background,
              body: controller.isLoading.value
                  ? Constant.loader()
                  // The new tab's page fades in; the previous one is removed at
                  // once, exactly as before (no overlap of the two pages).
                  : KeyedSubtree(
                      key: ValueKey<int>(controller.selectedIndex.value),
                      child: DsFadeSlideIn(
                        offset: const Offset(0, 8),
                        duration: DsMotion.base,
                        child: controller.navigationItems[controller.selectedIndex.value].page,
                      ),
                    ),
              bottomNavigationBar: controller.isLoading.value
                  ? null
                  : _DsNavBar(
                      currentIndex: controller.selectedIndex.value,
                      onTap: (int index) {
                        controller.selectedIndex.value = index;
                      },
                      items: List.generate(controller.navigationItems.length, (index) => _navigationBarItem(controller.navigationItems[index], index, controller, isDark)),
                    ),
            ),
          );
        },
      );
    });
  }

  _NavEntry _navigationBarItem(NavigationItem item, int index, DashBoardController controller, bool isDark) {
    return _NavEntry(iconPath: item.iconPath, label: item.label.tr);
  }
}

class _NavEntry {
  final String iconPath;
  final String label;
  const _NavEntry({required this.iconPath, required this.label});
}

/// Premium bottom navigation: floating surface with a hairline + soft shadow,
/// an animated brand pill behind the selected icon and a bolder label.
/// Centered and width-capped on tablets.
class _DsNavBar extends StatelessWidget {
  final List<_NavEntry> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _DsNavBar({required this.items, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.divider)),
        boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: c.isDark ? 0.35 : 0.07), blurRadius: 20, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.xs, DsSpace.sm, DsSpace.xs, DsSpace.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavButton(entry: items[i], selected: i == currentIndex, index: i, count: items.length, onTap: () => onTap(i)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavEntry entry;
  final bool selected;
  final int index;
  final int count;
  final VoidCallback onTap;

  const _NavButton({required this.entry, required this.selected, required this.index, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final Duration d = DsMotion.of(context, DsMotion.base);
    final Color fg = selected ? c.brandStrong : c.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: entry.label,
      hint: "${index + 1} / $count",
      excludeSemantics: true,
      child: DsPressable(
        pressedScale: 0.94,
        child: InkWell(
          onTap: onTap,
          borderRadius: DsRadius.brMd,
          splashColor: c.brand.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: d,
                  curve: DsMotion.emphasized,
                  width: selected ? 60 : 44,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: selected ? c.brandSoft : Colors.transparent, borderRadius: DsRadius.brPill),
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: selected ? c.brand : c.iconDefault),
                    duration: d,
                    builder: (_, color, _) => AnimatedScale(
                      scale: selected ? 1.08 : 1,
                      duration: d,
                      curve: DsMotion.spring,
                      child: SvgPicture.asset(entry.iconPath, height: 22, width: 22, colorFilter: ColorFilter.mode(color ?? c.iconDefault, BlendMode.srcIn)),
                    ),
                  ),
                ),
                const DsGap(DsSpace.xs),
                AnimatedDefaultTextStyle(
                  duration: d,
                  style: DsTypography.labelSm.copyWith(color: fg, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                  child: Text(entry.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

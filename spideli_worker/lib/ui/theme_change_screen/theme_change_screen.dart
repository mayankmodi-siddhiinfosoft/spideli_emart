import 'package:spideliworker/controller/theme_change_controller.dart';
import 'package:spideliworker/services/preferences.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Settings picker (archetype E), visual variant: each theme option is a
/// selectable card with a miniature preview of the app in that theme, plus a
/// radio row underneath. Save stays in a sticky bar.
class ThemeChangeScreen extends StatelessWidget {
  const ThemeChangeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return GetX(
        init: ThemChangeController(),
        builder: (controller) {
          final bool isLoading = controller.isLoading.value;
          final String mode = controller.lightDarkMode.value;
          final t = context.dsText;
          final l = context.dsLayout;
          return DsScaffold(
            title: "Select Theme",
            onBack: () {
              Get.back();
            },
            body: isLoading
                ? const DsSkeletonGrid(itemCount: 2, minItemWidth: 150, imageAspectRatio: 0.9)
                : ListView(
                    padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, DsSpace.xxxl),
                    children: [
                      DsFadeSlideIn(
                        child: Text(
                          'Pick how the app looks on this device'.tr,
                          style: t.bodySecondary,
                        ),
                      ),
                      const DsGap(DsSpace.xl),
                      DsFadeSlideIn(
                        index: 1,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: DsAdaptiveGrid(
                            minItemWidth: 140,
                            maxColumns: 2,
                            children: [
                              _ThemeOption(
                                label: "Light",
                                value: "Light",
                                groupValue: mode,
                                dark: false,
                                onSelect: () {
                                  controller.lightDarkMode.value = "Light";
                                },
                                onChanged: controller.handleGenderChange,
                              ),
                              _ThemeOption(
                                label: "Dark",
                                value: "Dark",
                                groupValue: mode,
                                dark: true,
                                onSelect: () {
                                  controller.lightDarkMode.value = "Dark";
                                },
                                onChanged: controller.handleGenderChange,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
            bottomBar: isLoading
                ? null
                : DsStickyBar(
                    child: DsButton.primary(
                      label: 'Save'.tr,
                      icon: Icons.check_rounded,
                      size: DsButtonSize.lg,
                      expand: true,
                      onPressed: () {
                        Preferences.setString(Preferences.themeKey, controller.lightDarkMode.value);
                        if (controller.lightDarkMode.value == "Dark") {
                          themeChange.darkTheme = 0;
                        } else if (controller.lightDarkMode.value == "Light") {
                          themeChange.darkTheme = 1;
                        } else {
                          themeChange.darkTheme = 2;
                        }
                      },
                    ),
                  ),
          );
        });
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final bool dark;
  final VoidCallback onSelect;
  final ValueChanged<String?> onChanged;

  const _ThemeOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.dark,
    required this.onSelect,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool selected = value == groupValue;
    return Semantics(
      selected: selected,
      label: label,
      child: DsCard.outlined(
        onTap: onSelect,
        padding: const EdgeInsets.all(DsSpace.md),
        borderColor: selected ? c.brand : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ThemePreview(palette: DsColors.resolve(dark), brand: c.brand),
            const DsGap(DsSpace.md),
            Row(
              children: [
                Icon(dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, size: 20, color: selected ? c.brand : c.iconDefault),
                const DsGap(DsSpace.sm),
                Expanded(child: Text(label, style: selected ? t.label.withColor(c.brandStrong) : t.bodyStrong)),
                Radio<String>(
                  value: value,
                  // ignore: deprecated_member_use
                  groupValue: groupValue,
                  activeColor: c.brand,
                  // ignore: deprecated_member_use
                  onChanged: onChanged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Miniature mock of a job card in the given palette.
class _ThemePreview extends StatelessWidget {
  final DsColors palette;
  final Color brand;

  const _ThemePreview({required this.palette, required this.brand});

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, Color color, [double h = 6]) => Container(width: w, height: h, decoration: BoxDecoration(color: color, borderRadius: DsRadius.brPill));
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 1.1,
        child: Container(
          padding: const EdgeInsets.all(DsSpace.sm),
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: DsRadius.brMd,
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 28,
                decoration: BoxDecoration(color: brand, borderRadius: DsRadius.brSm),
              ),
              const DsGap(DsSpace.sm),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(DsSpace.sm),
                  decoration: BoxDecoration(color: palette.surface, borderRadius: DsRadius.brSm, border: Border.all(color: palette.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(width: 18, height: 18, decoration: BoxDecoration(color: palette.surfaceAlt, borderRadius: DsRadius.brXs)),
                        const DsGap(DsSpace.xs),
                        Expanded(child: bar(double.infinity, palette.textPrimary.withValues(alpha: 0.7))),
                      ]),
                      bar(60, palette.textMuted.withValues(alpha: 0.6), 5),
                      Container(height: 12, decoration: BoxDecoration(color: brand, borderRadius: DsRadius.brPill)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

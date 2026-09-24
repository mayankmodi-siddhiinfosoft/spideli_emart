import 'package:spideliprovider/controller/theme_change_controller.dart';
import 'package:spideliprovider/services/preferences.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class ThemChangeScreen extends StatelessWidget {
  const ThemChangeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    final t = context.dsText;

    return GetX(
      init: ThemChangeController(),
      builder: (controller) {
        final String mode = controller.lightDarkMode.value;
        return DsScaffold(
          backgroundColor: c.background,
          appBar: const DsAppBar(title: "Select Theme"),
          body: controller.isLoading.value
              ? const _ThemeSkeleton()
              : SingleChildScrollView(
                  child: DsResponsive(
                    maxWidth: DsLayout.contentMax,
                    padded: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: DsFadeSlideIn.stagger([
                        const DsGap(DsSpace.xl),
                        Text('Appearance'.tr, style: t.titleSm),
                        const DsGap(DsSpace.xs),
                        Text('Pick how the app looks on this device.'.tr, style: t.bodySecondary),
                        const DsGap(DsSpace.xl),
                        _ThemeOption(
                          label: "Light",
                          selected: mode == "Light",
                          preview: const _ThemePreview(dark: false),
                          groupValue: mode,
                          onChanged: controller.handleGenderChange,
                          onTap: () {
                            controller.lightDarkMode.value = "Light";
                          },
                        ),
                        const DsGap(DsSpace.md),
                        _ThemeOption(
                          label: "Dark",
                          selected: mode == "Dark",
                          preview: const _ThemePreview(dark: true),
                          groupValue: mode,
                          onChanged: controller.handleGenderChange,
                          onTap: () {
                            controller.lightDarkMode.value = "Dark";
                          },
                        ),
                        const DsGap(DsSpace.xxl),
                      ]),
                    ),
                  ),
                ),
          bottomBar: controller.isLoading.value
              ? null
              : DsStickyBar(
                  child: DsButton.primary(
                    label: 'Save'.tr,
                    icon: Icons.check_rounded,
                    expand: true,
                    size: DsButtonSize.lg,
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
      },
    );
  }
}

/// Selectable theme row: a miniature of the theme, its name and the radio
/// that keeps the controller's original `onChanged` handler.
class _ThemeOption extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget preview;
  final String groupValue;
  final ValueChanged<String?>? onChanged;
  final VoidCallback onTap;

  const _ThemeOption({required this.label, required this.selected, required this.preview, required this.groupValue, required this.onChanged, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      onTap: onTap,
      borderColor: selected ? c.brand : null,
      padding: const EdgeInsets.all(DsSpace.md),
      semanticLabel: label,
      child: Row(
        children: [
          preview,
          const DsGap(DsSpace.lg),
          Expanded(child: Text(label, style: t.titleSm)),
          Radio<String>(value: label, groupValue: groupValue, activeColor: c.brand, onChanged: onChanged, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ],
      ),
    );
  }
}

/// Miniature of a theme (bar + two rows) so the choice is visual.
class _ThemePreview extends StatelessWidget {
  final bool dark;
  const _ThemePreview({required this.dark});

  @override
  Widget build(BuildContext context) {
    final p = DsColors.resolve(dark);
    return Container(
      width: 64,
      height: 52,
      padding: const EdgeInsets.all(DsSpace.sm),
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: DsRadius.brSm,
        border: Border.all(color: context.dsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(
            width: 34,
            height: 6,
            decoration: BoxDecoration(color: p.brand, borderRadius: DsRadius.brPill),
          ),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: DsRadius.brPill),
          ),
          Container(
            width: 26,
            height: 5,
            decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: DsRadius.brPill),
          ),
        ],
      ),
    );
  }
}

/// Two option-shaped placeholders while the saved theme is read back.
class _ThemeSkeleton extends StatelessWidget {
  const _ThemeSkeleton();

  @override
  Widget build(BuildContext context) {
    return DsResponsive(
      maxWidth: DsLayout.contentMax,
      padded: true,
      child: DsShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DsGap(DsSpace.xl),
            DsSkeleton.line(width: 140, height: 16),
            const DsGap(DsSpace.sm),
            DsSkeleton.line(width: 220),
            const DsGap(DsSpace.xl),
            DsSkeleton.box(width: double.infinity, height: 76),
            const DsGap(DsSpace.md),
            DsSkeleton.box(width: double.infinity, height: 76),
          ],
        ),
      ),
    );
  }
}

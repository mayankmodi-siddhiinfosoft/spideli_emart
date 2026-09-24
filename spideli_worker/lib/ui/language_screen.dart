import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/controller/language_controller.dart';
import 'package:spideliworker/services/localization_service.dart';
import 'package:spideliworker/services/preferences.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Settings picker (archetype E): a single grouped card of language rows with
/// the flag as the leading visual and a radio-style check, Save pinned in a
/// sticky bar.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes the page to theme changes.
    Provider.of<DarkThemeProvider>(context);
    return GetX(
        init: LanguageController(),
        builder: (controller) {
          final bool isLoading = controller.isLoading.value;
          final t = context.dsText;
          final l = context.dsLayout;
          return DsScaffold(
            title: "Select Language",
            onBack: () {
              Get.back();
            },
            body: DsAsync(
              isLoading: isLoading,
              skeleton: const DsSkeletonList(itemCount: 6, trailing: true),
              builder: (_) => ListView(
                padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, DsSpace.xxxl),
                children: [
                  DsFadeSlideIn(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: DsSpace.lg),
                      child: Row(
                        children: [
                          const DsIconWell(icon: Icons.translate_rounded, size: 48),
                          const DsGap(DsSpace.md),
                          Expanded(
                            child: Text(
                              'Choose the language used across the app'.tr,
                              style: t.bodySecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DsFadeSlideIn(
                    index: 1,
                    child: DsCard.outlined(
                      padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                      child: Column(
                        children: [
                          for (int index = 0; index < controller.languageList.length; index++) ...[
                            if (index > 0) const Divider(height: 1, indent: 84),
                            _LanguageRow(controller: controller, index: index),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
                        LocalizationService().changeLocale(controller.selectedLanguage.value);
                        Preferences.setString(Preferences.languageKey, controller.selectedLanguage.value);

                        ShowToastDialog.showToast("Language Changed Successfully".tr);
                      },
                    ),
                  ),
          );
        });
  }
}

class _LanguageRow extends StatelessWidget {
  final LanguageController controller;
  final int index;

  const _LanguageRow({required this.controller, required this.index});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Obx(() {
      final bool selected = controller.languageList[index].slug == controller.selectedLanguage.value;
      return Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: () {
            controller.selectedLanguage.value = controller.languageList[index].slug.toString();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.sm),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(DsSpace.xs),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: DsRadius.brMd,
                      border: Border.all(color: selected ? c.brand : c.border),
                    ),
                    child: controller.languageList[index].flag != null
                        ? DsImage(
                            url: controller.languageList[index].flag.toString(),
                            height: 44,
                            width: 44,
                            radius: DsRadius.sm,
                            fit: BoxFit.contain,
                          )
                        : DsImage(
                            url: placeholderImage,
                            height: 44,
                            width: 44,
                            radius: DsRadius.sm,
                            fit: BoxFit.contain,
                          ),
                  ),
                  const DsGap(DsSpace.lg),
                  Expanded(
                    child: Text(
                      controller.languageList[index].title.toString(),
                      style: selected ? t.label.withColor(c.brandStrong) : t.bodyLg,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: DsMotion.of(context, DsMotion.fast),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      key: ValueKey(selected),
                      color: selected ? c.brand : c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

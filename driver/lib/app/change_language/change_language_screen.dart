import 'dart:convert';

import 'package:driver/controllers/change_language_controller.dart';
import 'package:driver/models/language_model.dart';
import 'package:driver/services/localization_service.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/network_image_widget.dart';
import 'package:driver/utils/preferences.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Archetype K – settings picker: an adaptive grid of selectable flag tiles
/// with a clear selected state (border + check), not a plain list.
class ChangeLanguageScreen extends StatelessWidget {
  const ChangeLanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      // The theme observable read must stay inside this Obx: it is what
      // rebuilds this screen when the driver switches light / dark mode.
      themeController.isDark.value;
      return GetX(
          init: ChangeLanguageController(),
          builder: (controller) {
            final c = context.dsColors;
            final t = context.dsText;

            // Read eagerly inside the tracked builder so selection changes
            // rebuild the grid.
            final languages = controller.languageList.toList();
            final selectedSlug = controller.selectedLanguage.value.slug;

            return Scaffold(
              backgroundColor: c.background,
              body: DsAsync(
                isLoading: controller.isLoading.value,
                skeleton: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xl),
                  child: DsSkeletonGrid(itemCount: 6, minItemWidth: 160, imageAspectRatio: 1.1),
                ),
                isEmpty: languages.isEmpty,
                empty: DsEmptyState(
                  icon: Icons.translate_rounded,
                  title: "No languages available".tr,
                ),
                builder: (_) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.xl, DsSpace.lg, DsSpace.xxxl),
                  child: DsResponsive(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: DsFadeSlideIn.stagger([
                        DsCard.tinted(
                          tone: DsTone.info,
                          child: Row(
                            children: [
                              const DsIconWell(icon: Icons.translate_rounded, tone: DsTone.info, size: 40),
                              const DsGap(DsSpace.md),
                              Expanded(
                                child: Text(
                                  "Choose the language you want to use in the app.".tr,
                                  style: t.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const DsGap(DsSpace.xl),
                        DsSectionHeader(title: "Language".tr),
                        const DsGap(DsSpace.md),
                        DsAdaptiveGrid(
                          minItemWidth: 160,
                          children: [
                            for (var i = 0; i < languages.length; i++)
                              _LanguageTile(
                                index: i,
                                data: languages[i],
                                selected: selectedSlug == languages[i].slug,
                                onTap: () {
                                  LocalizationService().changeLocale(languages[i].slug.toString());
                                  Preferences.setString(Preferences.languageCodeKey, jsonEncode(languages[i]));
                                  controller.selectedLanguage.value = languages[i];
                                },
                              ),
                          ],
                        ),
                      ], offset: const Offset(0, 18)),
                    ),
                  ),
                ),
              ),
            );
          });
    });
  }
}

/// Selectable language tile: flag, name and a check badge when selected.
class _LanguageTile extends StatelessWidget {
  final int index;
  final LanguageModel data;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.index,
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsFadeSlideIn(
      index: index,
      child: DsCard.outlined(
        onTap: onTap,
        borderColor: selected ? c.brand : null,
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.lg),
        semanticLabel: "${data.title}",
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: DsRadius.brMd,
                  child: NetworkImageWidget(
                    imageUrl: data.image.toString(),
                    height: 64,
                    width: 64,
                  ),
                ),
                if (selected)
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                      child: Icon(Icons.check_circle_rounded, size: 20, color: c.brand),
                    ),
                  ),
              ],
            ),
            const DsGap(DsSpace.md),
            Text(
              "${data.title}",
              textAlign: TextAlign.center,
              style: selected ? t.bodyStrong.withColor(c.brandStrong) : t.bodyStrong,
            ),
          ],
        ),
      ),
    );
  }
}

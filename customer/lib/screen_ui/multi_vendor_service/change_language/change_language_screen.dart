import 'dart:convert';
import 'package:customer/controllers/change_language_controller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:customer/utils/preferences.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../service/localization_service.dart';

/// Archetype **H — settings**: a picker screen. Languages are selectable
/// cards in an adaptive grid (2 columns on phones, more on tablets) with a
/// brand border + check mark on the active one.
class ChangeLanguageScreen extends StatelessWidget {
  const ChangeLanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: ChangeLanguageController(),
      builder: (controller) {
        final t = context.dsText;
        final loading = controller.isLoading.value;
        final languages = controller.languageList.toList();
        return DsScaffold(
          title: "Change Language".tr,
          maxContentWidth: DsLayout.contentMax,
          body: DsAsync(
            isLoading: loading,
            skeleton: const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonGrid(minItemWidth: 150, imageAspectRatio: 1.1)),
            isEmpty: languages.isEmpty,
            empty: DsEmptyState(icon: Icons.translate_rounded, title: "Change Language".tr, message: "Select your preferred language for a personalized app experience.".tr),
            builder: (_) => CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, DsSpace.lg),
                    child: DsFadeSlideIn(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DsIconWell(icon: Icons.translate_rounded, tone: DsTone.brand, size: 48),
                          const DsGap(DsSpace.lg),
                          Expanded(child: Text("Select your preferred language for a personalized app experience.".tr, style: t.bodySecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.lg, DsSpace.xxxl),
                  sliver: SliverGrid(
                    gridDelegate: DsLayout.gridDelegate(maxItemWidth: 200, mainAxisExtent: 168),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final data = languages[index];
                      return DsFadeSlideIn(
                        index: index,
                        child: DsObserve(
                          builder: (context) {
                            final c = context.dsColors;
                            final selected = controller.selectedLanguage.value.slug == data.slug;
                            return DsCard.outlined(
                              padding: const EdgeInsets.all(DsSpace.md),
                              borderColor: selected ? c.brand : null,
                              color: selected ? c.brandSoft : null,
                              onTap: () async {
                                LocalizationService().changeLocale(data.slug.toString());
                                await Preferences.setString(Preferences.languageCodeKey, jsonEncode(data));
                                controller.selectedLanguage.value = data;
                              },
                              semanticLabel: "${data.title}",
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: DsRadius.brMd,
                                        child: NetworkImageWidget(imageUrl: data.image.toString(), height: 76, width: 76),
                                      ),
                                      if (selected)
                                        PositionedDirectional(
                                          end: -2,
                                          bottom: -2,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
                                            child: Icon(Icons.check_rounded, size: 12, color: c.onBrand),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const DsGap(DsSpace.md),
                                  Text(
                                    "${data.title}",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: selected ? DsTypography.label.copyWith(color: c.brandStrong) : DsTypography.bodyStrong.copyWith(color: c.textSecondary),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    }, childCount: languages.length),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

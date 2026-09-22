import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/controller/change_language_controller.dart';
import 'package:vendor/service/localization_service.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/preferences.dart';

class ChangeLanguageScreen extends StatelessWidget {
  const ChangeLanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: ChangeLanguageController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final l = context.dsLayout;
        return DsScaffold(
          title: "Change Language".tr,
          maxContentWidth: DsLayout.wideMax,
          body: controller.isLoading.value
              ? const SingleChildScrollView(physics: NeverScrollableScrollPhysics(), child: DsSkeletonGrid(minItemWidth: 150, imageAspectRatio: 1.4))
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, DsSpace.xl),
                      sliver: SliverToBoxAdapter(
                        child: DsFadeSlideIn(
                          child: Row(
                            children: [
                              const DsIconWell(icon: Icons.translate_rounded, size: 48),
                              const DsGap(DsSpace.md),
                              Expanded(child: Text("Select your preferred language for a personalized app experience.".tr, style: t.bodyLg.withColor(c.textSecondary))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(l.gutter, 0, l.gutter, DsSpace.xxxl),
                      sliver: SliverGrid(
                        gridDelegate: DsLayout.gridDelegate(maxItemWidth: 200, mainAxisExtent: 176),
                        delegate: SliverChildBuilderDelegate(childCount: controller.languageList.length, (context, index) {
                          final data = controller.languageList[index];
                          return DsFadeSlideIn(
                            index: index,
                            child: Obx(() {
                              final selected = controller.selectedLanguage.value.slug == data.slug;
                              return _LanguageTile(
                                title: "${data.title}",
                                imageUrl: data.image.toString(),
                                selected: selected,
                                onTap: () {
                                  LocalizationService().changeLocale(data.slug.toString());
                                  Preferences.setString(Preferences.languageCodeKey, jsonEncode(data));
                                  controller.selectedLanguage.value = data;
                                },
                              );
                            }),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String title;
  final String imageUrl;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageTile({required this.title, required this.imageUrl, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Semantics(
      selected: selected,
      child: AnimatedContainer(
        duration: DsMotion.of(context, DsMotion.base),
        curve: DsMotion.standard,
        decoration: BoxDecoration(
          borderRadius: DsRadius.brLg,
          boxShadow: selected ? DsShadows.glow(context, color: c.brand) : DsShadows.xs(context),
        ),
        child: DsCard.outlined(
          onTap: onTap,
          semanticLabel: title,
          color: selected ? c.brandSoft : null,
          borderColor: selected ? c.brand : null,
          padding: const EdgeInsets.all(DsSpace.md),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DsImage(url: imageUrl, width: 72, height: 72, radius: DsRadius.pill, fit: BoxFit.cover),
                    const DsGap(DsSpace.md),
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: t.label.withColor(selected ? c.brandStrong : c.textPrimary)),
                  ],
                ),
              ),
              PositionedDirectional(
                top: 0,
                end: 0,
                child: AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: DsMotion.of(context, DsMotion.base),
                  curve: DsMotion.spring,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
                    child: Icon(Icons.check_rounded, size: 16, color: c.onBrand),
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

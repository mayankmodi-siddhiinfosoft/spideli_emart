import 'package:driver/controllers/change_section_controller.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Archetype H – service selection: selectable section tiles in an adaptive
/// grid with a sticky primary action.
class ChangeSectionScreen extends StatelessWidget {
  const ChangeSectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: ChangeSectionController(),
      builder: (controller) {
        final t = context.dsText;

        // Read eagerly inside the tracked builder so selection changes rebuild.
        final sections = controller.allSections.toList();
        final tiles = <Widget>[
          for (var i = 0; i < sections.length; i++)
            _SectionTile(
              index: i,
              title: sections[i].name ?? '',
              subtitle: controller.serviceFlagLabel(sections[i].serviceTypeFlag),
              serviceTypeFlag: sections[i].serviceTypeFlag,
              selected: controller.isSectionSelected(sections[i]),
              onTap: () async {
                await controller.toggleSection(sections[i]);
              },
            ),
        ];
        final selectedCount = sections.where(controller.isSectionSelected).length;

        return DsScaffold(
          title: "Change Section".tr,
          body: DsAsync(
            isLoading: controller.isLoading.value,
            skeleton: const Padding(
              padding: EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xl),
              child: DsSkeletonGrid(itemCount: 4, minItemWidth: 220, imageAspectRatio: 2.4),
            ),
            builder: (_) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.xl, DsSpace.lg, DsSpace.xxxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: DsFadeSlideIn.stagger([
                  DsCard.tinted(
                    tone: DsTone.info,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const DsIconWell(icon: Icons.tune_rounded, tone: DsTone.info, size: 40),
                        const DsGap(DsSpace.md),
                        Expanded(
                          child: Text(
                            "Select the sections you want to serve. You can add or remove sections anytime.".tr,
                            style: t.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.xl),
                  DsSectionHeader(
                    title: "Available Sections".tr,
                    trailing: sections.isEmpty
                        ? null
                        : DsBadge(
                            label: '$selectedCount/${sections.length}',
                            tone: DsTone.brand,
                            small: true,
                          ),
                  ),
                  const DsGap(DsSpace.md),
                  if (sections.isEmpty)
                    DsEmptyState(
                      icon: Icons.grid_view_rounded,
                      title: "No sections available".tr,
                      compact: true,
                    )
                  else
                    DsAdaptiveGrid(minItemWidth: 260, children: tiles),
                ], offset: const Offset(0, 18)),
              ),
            ),
          ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Save Changes".tr,
              icon: Icons.check_rounded,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: () => controller.saveChanges(),
            ),
          ),
        );
      },
    );
  }
}

/// Selectable service tile (archetype H): icon well in the section accent,
/// name, service label and a check affordance.
class _SectionTile extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  final String? serviceTypeFlag;
  final bool selected;
  final VoidCallback onTap;

  const _SectionTile({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.serviceTypeFlag,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final section = DsSection.fromServiceType(serviceTypeFlag);
    final accent = c.section(section);
    return DsFadeSlideIn(
      index: index,
      child: DsCard.outlined(
        onTap: onTap,
        borderColor: selected ? c.brand : null,
        padding: const EdgeInsets.all(DsSpace.lg),
        semanticLabel: '$title, $subtitle',
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: accent.soft, borderRadius: BorderRadius.circular(13)),
              child: Icon(section.icon, size: 22, color: accent.strong),
            ),
            const DsGap(DsSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: t.titleSm, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const DsGap(DsSpace.xxs),
                  Text(subtitle, style: t.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const DsGap(DsSpace.sm),
            AnimatedContainer(
              duration: DsMotion.of(context, DsMotion.fast),
              curve: DsMotion.standard,
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: selected ? c.brand : Colors.transparent,
                border: Border.all(color: selected ? c.brand : c.borderStrong, width: 1.6),
                borderRadius: DsRadius.brXs,
              ),
              child: selected ? Icon(Icons.check_rounded, size: 18, color: c.onBrand) : null,
            ),
          ],
        ),
      ),
    );
  }
}

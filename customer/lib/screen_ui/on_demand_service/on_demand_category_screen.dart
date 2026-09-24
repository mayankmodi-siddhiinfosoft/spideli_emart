import 'package:customer/screen_ui/on_demand_service/view_category_service_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/on_demand_category_controller.dart';
import '../../models/category_model.dart';

/// Archetype A/B – category catalogue grid.
class OnDemandCategoryScreen extends StatelessWidget {
  const OnDemandCategoryScreen({super.key});

  static const List<DsTone> _tones = [DsTone.brand, DsTone.info, DsTone.success, DsTone.warning];

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: OnDemandCategoryController(),
      builder: (controller) {
        final bool isLoading = controller.isLoading.value;
        final List<CategoryModel> categories = controller.categories.toList();

        return DsScaffold.collapsing(
          title: "Explore services".tr,
          subtitle: "Explore services tailored for you—quick, easy, and personalized.".tr,
          slivers: [
            if (isLoading)
              const DsSliverResponsive(top: DsSpace.md, sliver: SliverToBoxAdapter(child: DsSkeletonGrid(itemCount: 9, minItemWidth: 120)))
            else if (categories.isEmpty)
              DsSliverResponsive(
                top: DsSpace.xxxl,
                sliver: SliverToBoxAdapter(child: DsEmptyState(icon: Icons.category_outlined, title: "No Categories".tr)),
              )
            else
              DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                top: DsSpace.md,
                bottom: DsSpace.xl,
                sliver: SliverGrid.builder(
                  gridDelegate: DsLayout.gridDelegate(maxItemWidth: 170, mainAxisExtent: 108 + MediaQuery.textScalerOf(context).scale(32)),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    return DsFadeSlideIn(index: index, child: categoriesCell(context, categories[index], index));
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget categoriesCell(BuildContext context, CategoryModel category, int index) {
    final c = context.dsColors;
    final t = context.dsText;
    final tone = c.tone(_tones[index % _tones.length]);
    return DsCard.outlined(
      padding: const EdgeInsets.all(DsSpace.md),
      semanticLabel: category.title ?? "",
      onTap: () {
        Get.to(() => ViewCategoryServiceListScreen(), arguments: {'categoryId': category.id, 'categoryTitle': category.title});
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 68,
            width: 68,
            padding: const EdgeInsets.all(DsSpace.md),
            decoration: BoxDecoration(color: tone.soft, borderRadius: DsRadius.brLg),
            child: DsImage(url: category.image ?? "", radius: DsRadius.sm, fit: BoxFit.cover, errorIcon: Icons.category_outlined),
          ),
          const DsGap(DsSpace.sm),
          Text(category.title ?? "", textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.labelSm.withColor(c.textPrimary)),
        ],
      ),
    );
  }
}

import 'package:customer/controllers/view_all_category_controller.dart';
import 'package:customer/models/vendor_category_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'category_restaurant_screen.dart';

class ViewAllCategoryScreen extends StatelessWidget {
  const ViewAllCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: ViewAllCategoryController(),
      builder: (controller) {
        final isLoading = controller.isLoading.value;
        final categories = controller.vendorCategoryModel;
        return DsScaffold.collapsing(
          title: "Categories".tr,
          subtitle: isLoading ? null : '${categories.length} ${"Categories".tr}',
          slivers: [
            if (isLoading)
              const SliverToBoxAdapter(child: DsSkeletonGrid(minItemWidth: 150, itemCount: 8, imageAspectRatio: 1))
            else if (categories.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(icon: Icons.category_outlined, title: "No categories yet".tr, message: "Check back a little later.".tr),
              )
            else
              DsSliverResponsive(
                top: DsSpace.sm,
                sliver: SliverGrid(
                  gridDelegate: DsLayout.gridDelegate(maxItemWidth: 170, mainAxisExtent: 158, spacing: DsSpace.md),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final VendorCategoryModel vendorCategoryModel = categories[index];
                    return DsFadeSlideIn(index: index, child: _CategoryTile(model: vendorCategoryModel));
                  }, childCount: categories.length),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Circular category tile used by the "all categories" grid.
class _CategoryTile extends StatelessWidget {
  final VendorCategoryModel model;
  const _CategoryTile({required this.model});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.md),
      semanticLabel: '${model.title}',
      onTap: () {
        Get.to(const CategoryRestaurantScreen(), arguments: {"vendorCategoryModel": model, "dineIn": false});
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.brandSoft),
            child: ClipOval(child: NetworkImageWidget(imageUrl: model.photo.toString(), fit: BoxFit.cover)),
          ),
          const DsGap(DsSpace.md),
          Flexible(
            child: Text('${model.title}', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.labelSm.withColor(c.textPrimary)),
          ),
        ],
      ),
    );
  }
}

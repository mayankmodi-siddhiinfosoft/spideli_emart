import 'package:customer/controllers/all_brand_product_controller.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/screen_ui/ecommarce/widgets/product_card.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Archetype B – catalogue grid for one brand.
class AllBrandProductScreen extends StatelessWidget {
  const AllBrandProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: AllBrandProductController(),
      builder: (controller) {
        final bool isLoading = controller.isLoading.value;
        final List<ProductModel> products = controller.productList.toList();
        final String title = controller.brandModel.value.title ?? '';

        return DsScaffold.collapsing(
          title: title.isEmpty ? "Top Brands".tr : title,
          subtitle: isLoading ? null : "${products.length} ${'products'.tr}",
          slivers: [
            if (isLoading)
              const DsSliverResponsive(top: DsSpace.md, sliver: SliverToBoxAdapter(child: DsSkeletonGrid(itemCount: 9, minItemWidth: 170)))
            else if (products.isEmpty)
              DsSliverResponsive(
                top: DsSpace.xxxl,
                sliver: SliverToBoxAdapter(child: DsEmptyState(icon: Icons.inventory_2_outlined, title: "No Product Found".tr)),
              )
            else
              DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                top: DsSpace.md,
                bottom: DsSpace.xl,
                sliver: SliverGrid.builder(
                  gridDelegate: DsLayout.gridDelegate(maxItemWidth: 200, mainAxisExtent: EcommerceProductCard.gridExtent(context)),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    ProductModel productModel = products[index];
                    return DsFadeSlideIn(index: index, child: EcommerceProductCard(productModel: productModel));
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

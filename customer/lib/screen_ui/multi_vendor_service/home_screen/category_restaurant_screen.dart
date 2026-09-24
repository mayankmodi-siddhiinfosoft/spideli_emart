import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/category_restaurant_controller.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';
import 'widgets/store_widgets.dart';

/// Archetype B — catalogue list, "editorial row" variant: a tall portrait
/// photo on the leading edge with the store details beside it, so a category
/// reads differently from the full-bleed search results list.
class CategoryRestaurantScreen extends StatelessWidget {
  const CategoryRestaurantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: CategoryRestaurantController(),
      builder: (controller) {
        final isLoading = controller.isLoading.value;
        final stores = controller.allNearestRestaurant;
        final categoryTitle = controller.vendorCategoryModel.value.title;
        return DsScaffold.collapsing(
          title: (categoryTitle == null || categoryTitle.isEmpty) ? "Restaurants".tr : categoryTitle,
          subtitle: isLoading || stores.isEmpty ? null : '${stores.length} ${"Nearby".tr}',
          slivers: [
            if (isLoading)
              const SliverToBoxAdapter(child: DsSkeletonList(itemCount: 5, trailing: false))
            else if (stores.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(icon: Icons.no_meals_outlined, title: "No Restaurant found".tr, message: "Nothing open in this category near you right now.".tr),
              )
            else
              DsSliverResponsive(
                sliver: SliverList.builder(
                  itemCount: stores.length,
                  itemBuilder: (context, index) {
                    final VendorModel vendorModel = stores[index];
                    return DsFadeSlideIn(index: index, child: _StoreEditorialRow(vendorModel: vendorModel));
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StoreEditorialRow extends StatelessWidget {
  final VendorModel vendorModel;
  const _StoreEditorialRow({required this.vendorModel});

  @override
  Widget build(BuildContext context) {
    return DsCard.outlined(
      padding: const EdgeInsets.all(DsSpace.sm),
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      semanticLabel: vendorModel.title.toString(),
      onTap: () {
        Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: DsRadius.brMd,
            child: NetworkImageWidget(imageUrl: vendorModel.photo.toString(), fit: BoxFit.cover, width: 112, height: 136),
          ),
          const DsGap(DsSpace.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  StoreTitleBlock(vendorModel: vendorModel, compact: true),
                  const DsGap(DsSpace.md),
                  StoreMetaChips(
                    vendorModel: vendorModel,
                    showFreeDelivery: vendorModel.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true,
                    small: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

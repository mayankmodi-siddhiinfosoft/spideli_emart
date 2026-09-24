import 'package:customer/controllers/restaurant_list_controller.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../service/fire_store_utils.dart';
import 'dine_in_details_screen.dart';
import 'widgets/dine_in_widgets.dart';

/// Archetype B — dine-in catalogue. A collapsing title with the result count
/// over the same showcase cards the dine-in home uses.
class DineInRestaurantListScreen extends StatelessWidget {
  const DineInRestaurantListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: RestaurantListController(),
      builder: (controller) {
        final bool isLoading = controller.isLoading.value;
        final List<VendorModel> stores = controller.vendorSearchList.toList();

        return DsScaffold.collapsing(
          title: controller.title.value,
          subtitle: isLoading || stores.isEmpty ? null : '${stores.length} ${"Stores".tr}',
          slivers: [
            if (isLoading)
              const SliverToBoxAdapter(child: DsSkeletonList(itemCount: 3, leading: false, trailing: false))
            else if (stores.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(icon: Icons.restaurant_outlined, title: "No Restaurant found".tr),
              )
            else
              DsSliverResponsive(
                sliver: SliverList.builder(
                  itemCount: stores.length,
                  itemBuilder: (context, index) {
                    VendorModel vendorModel = stores[index];
                    return DsFadeSlideIn(
                      index: index,
                      child: DineInStoreCard(
                        vendorModel: vendorModel,
                        onTap: () {
                          Get.to(const DineInDetailsScreen(), arguments: {"vendorModel": vendorModel});
                        },
                        favourite: Obx(
                          () => DineInFavouriteButton(
                            isFavourite: controller.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty,
                            onTap: () async {
                              if (controller.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty) {
                                FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                                controller.favouriteList.removeWhere((item) => item.restaurantId == vendorModel.id);
                                await FireStoreUtils.removeFavouriteRestaurant(favouriteModel);
                              } else {
                                FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                                controller.favouriteList.add(favouriteModel);
                                await FireStoreUtils.setFavouriteRestaurant(favouriteModel);
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

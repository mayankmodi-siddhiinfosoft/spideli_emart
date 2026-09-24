import 'package:customer/controllers/restaurant_list_controller.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../service/fire_store_utils.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';
import 'widgets/store_widgets.dart';

/// Archetype B — catalogue list. Full-bleed showcase cards: the store photo
/// carousel is the hero, chips float over its bottom edge and the name sits
/// on the card surface underneath.
class RestaurantListScreen extends StatelessWidget {
  const RestaurantListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: RestaurantListController(),
      builder: (controller) {
        final isLoading = controller.isLoading.value;
        final stores = controller.vendorSearchList;
        return DsScaffold.collapsing(
          title: controller.title.value,
          subtitle: isLoading || stores.isEmpty ? null : '${stores.length} ${"Stores".tr}',
          slivers: [
            if (isLoading)
              const SliverToBoxAdapter(child: DsSkeletonList(itemCount: 3, leading: false, trailing: false))
            else if (stores.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(icon: Icons.storefront_outlined, title: "No Restaurant found".tr, message: "Try a different search or widen your area.".tr),
              )
            else
              DsSliverResponsive(
                sliver: SliverList.builder(
                  itemCount: stores.length,
                  itemBuilder: (context, index) {
                    final VendorModel vendorModel = stores[index];
                    return DsFadeSlideIn(
                      index: index,
                      child: StoreShowcaseCard(
                        vendorModel: vendorModel,
                        onTap: () {
                          Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel})?.then((v) {
                            controller.getFavouriteRestaurant();
                          });
                        },
                        // Favourite state is observable — keep the read in its
                        // own observer so only the heart rebuilds.
                        favourite: Obx(
                          () => StoreFavouriteButton(
                            onMedia: true,
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

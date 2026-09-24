import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/favourite_controller.dart';
import 'package:customer/models/favourite_item_model.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../../../widget/restaurant_image_view.dart';
import '../../auth_screens/login_screen.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';

/// Archetype B — saved catalogue. A dashboard tab (no route), so it carries
/// its own display title instead of an app bar. Stores are shown as wide
/// photo cards with the heart floating on the media; items as compact rows
/// with the heart on the thumbnail — the two tabs read differently on purpose.
class FavouriteScreen extends StatelessWidget {
  const FavouriteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: FavouriteController(),
      builder: (controller) {
        final isLoading = controller.isLoading.value;
        final bool storeTab = controller.favouriteRestaurant.value;
        final List<VendorModel> stores = controller.favouriteVendorList.toList();
        final List<ProductModel> items = controller.favouriteFoodList.toList();
        final bool signedOut = Constant.userModel == null;

        return DsScaffold(
          maxContentWidth: DsLayout.contentMax,
          body: SafeArea(
            bottom: false,
            child: isLoading
                ? const DsSkeletonList(itemCount: 4)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.lg),
                        child: Row(
                          children: [Expanded(child: Text("Your Favourites, All in One Place".tr, style: context.dsText.display))],
                        ),
                      ),
                      if (signedOut)
                        Expanded(
                          child: DsEmptyState(
                            illustration: Image.asset("assets/images/login.gif", height: 120),
                            title: "Please Log In to Continue".tr,
                            message: "You’re not logged in. Please sign in to access your account and explore all features.".tr,
                            actionLabel: "Log in".tr,
                            actionIcon: Icons.login_rounded,
                            onAction: () async {
                              Get.offAll(const LoginScreen());
                            },
                          ),
                        )
                      else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                          child: DsSegmentedTabs(
                            segments: [
                              DsSegment("Favourite Store".tr, icon: Icons.storefront_outlined, count: stores.isEmpty ? null : stores.length),
                              DsSegment("Favourite Item".tr, icon: Icons.local_mall_outlined, count: items.isEmpty ? null : items.length),
                            ],
                            index: storeTab ? 0 : 1,
                            onChanged: (i) {
                              controller.favouriteRestaurant.value = i == 0;
                            },
                          ),
                        ),
                        const DsGap(DsSpace.lg),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: DsMotion.of(context, DsMotion.base),
                            child: storeTab
                                ? _StoreTab(key: const ValueKey('stores'), controller: controller, stores: stores)
                                : _ItemTab(key: const ValueKey('items'), controller: controller, items: items),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }
}

Future<Map<String, dynamic>> _getPrice(ProductModel productModel) async {
  String price = "0.0";
  String disPrice = "0.0";
  List<String> selectedVariants = [];
  List<String> selectedIndexVariants = [];
  List<String> selectedIndexArray = [];

  print("=======>");
  print(productModel.price);
  print(productModel.disPrice);

  VendorModel? vendorModel = await FireStoreUtils.getVendorById(productModel.vendorID.toString());
  if (productModel.itemAttribute != null) {
    if (productModel.itemAttribute!.attributes!.isNotEmpty) {
      for (var element in productModel.itemAttribute!.attributes!) {
        if (element.attributeOptions!.isNotEmpty) {
          selectedVariants.add(productModel.itemAttribute!.attributes![productModel.itemAttribute!.attributes!.indexOf(element)].attributeOptions![0].toString());
          selectedIndexVariants.add('${productModel.itemAttribute!.attributes!.indexOf(element)} _${productModel.itemAttribute!.attributes![0].attributeOptions![0].toString()}');
          selectedIndexArray.add('${productModel.itemAttribute!.attributes!.indexOf(element)}_0');
        }
      }
    }
    if (productModel.itemAttribute!.variants!.where((element) => element.variantSku == selectedVariants.join('-')).isNotEmpty) {
      price = Constant.productCommissionPrice(vendorModel!, productModel.itemAttribute!.variants!.where((element) => element.variantSku == selectedVariants.join('-')).first.variantPrice ?? '0');
      disPrice = Constant.productCommissionPrice(vendorModel, '0');
    }
  } else {
    price = Constant.productCommissionPrice(vendorModel!, productModel.price.toString());
    disPrice = Constant.productCommissionPrice(vendorModel, productModel.disPrice.toString());
  }

  return {'price': price, 'disPrice': disPrice};
}

class _StoreTab extends StatelessWidget {
  final FavouriteController controller;
  final List<VendorModel> stores;
  const _StoreTab({super.key, required this.controller, required this.stores});

  @override
  Widget build(BuildContext context) {
    if (stores.isEmpty) {
      return DsEmptyState(icon: Icons.storefront_outlined, title: "Favourite Store not found.".tr);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.lg, DsSpace.xxl),
      itemCount: stores.length,
      itemBuilder: (BuildContext context, int index) {
        final VendorModel vendorModel = stores[index];
        return DsFadeSlideIn(
          index: index,
          child: _FavouriteStoreCard(controller: controller, vendorModel: vendorModel, index: index),
        );
      },
    );
  }
}

class _ItemTab extends StatelessWidget {
  final FavouriteController controller;
  final List<ProductModel> items;
  const _ItemTab({super.key, required this.controller, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return DsEmptyState(icon: Icons.favorite_border_rounded, title: "Favourite Item not found.".tr);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.lg, DsSpace.xxl),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final ProductModel productModel = items[index];
        return DsFadeSlideIn(
          index: index,
          child: _FavouriteItemCard(controller: controller, productModel: productModel, index: index),
        );
      },
    );
  }
}

/// Photo-led store card: the existing auto-rotating photo view stays as the
/// hero, chips sit over its bottom edge, the heart floats top-right.
class _FavouriteStoreCard extends StatelessWidget {
  final FavouriteController controller;
  final VendorModel vendorModel;
  final int index;
  const _FavouriteStoreCard({required this.controller, required this.vendorModel, required this.index});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return DsCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: DsSpace.xl),
      semanticLabel: vendorModel.title.toString(),
      onTap: () {
        ShowToastDialog.closeLoader();
        Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel})?.then((value) async {
          await controller.getData();
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              RestaurantImageView(vendorModel: vendorModel),
              const Positioned.fill(
                child: DecoratedBox(decoration: BoxDecoration(gradient: DsGradients.imageScrim)),
              ),
              Positioned(
                right: DsSpace.sm,
                top: DsSpace.sm,
                child: _HeartButton(
                  // Favourite state is observable: keep the read inside its own
                  // observer so only the heart rebuilds.
                  isFavourite: () => controller.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty,
                  onTap: () async {
                    if (controller.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty) {
                      FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                      controller.favouriteList.removeWhere((item) => item.restaurantId == vendorModel.id);
                      controller.favouriteVendorList.removeAt(index);
                      await FireStoreUtils.removeFavouriteRestaurant(favouriteModel);
                    } else {
                      FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                      controller.favouriteList.add(favouriteModel);
                      await FireStoreUtils.setFavouriteRestaurant(favouriteModel);
                    }
                  },
                ),
              ),
              Positioned(
                left: DsSpace.md,
                right: DsSpace.md,
                bottom: DsSpace.md,
                child: _StoreChips(vendorModel: vendorModel),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vendorModel.title.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.title),
                Text(vendorModel.location.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreChips extends StatelessWidget {
  final VendorModel vendorModel;
  const _StoreChips({required this.vendorModel});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: DsSpace.xs,
      runSpacing: DsSpace.xs,
      children: [
        if (vendorModel.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true)
          DsBadge(label: "Free Delivery".tr, tone: DsTone.success, style: DsBadgeStyle.solid, icon: Icons.delivery_dining_outlined, small: true),
        DsBadge(
          label:
              "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount!.toStringAsFixed(0), reviewSum: vendorModel.reviewsSum.toString())} (${vendorModel.reviewsCount!.toStringAsFixed(0)})",
          tone: DsTone.warning,
          style: DsBadgeStyle.solid,
          icon: Icons.star_rounded,
          small: true,
        ),
        DsBadge(
          label:
              "${Constant.getDistance(lat1: vendorModel.latitude.toString(), lng1: vendorModel.longitude.toString(), lat2: Constant.selectedLocation.location!.latitude.toString(), lng2: Constant.selectedLocation.location!.longitude.toString())} ${Constant.distanceType}",
          tone: DsTone.info,
          style: DsBadgeStyle.solid,
          icon: Icons.place_outlined,
          small: true,
        ),
      ],
    );
  }
}

/// Compact saved-item row: details on the leading edge, photo + heart trailing.
class _FavouriteItemCard extends StatelessWidget {
  final FavouriteController controller;
  final ProductModel productModel;
  final int index;
  const _FavouriteItemCard({required this.controller, required this.productModel, required this.index});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return FutureBuilder(
      future: _getPrice(productModel),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const DsSkeletonList(itemCount: 1, trailing: false, padding: EdgeInsets.only(bottom: DsSpace.md));
        } else {
          if (snapshot.hasError) {
            return Center(child: Text('${"error".tr}: ${snapshot.error}', style: t.bodySm));
          } else if (snapshot.data == null) {
            return const SizedBox();
          } else {
            Map<String, dynamic> map = snapshot.data!;
            String price = map['price'];
            String disPrice = map['disPrice'];
            return DsCard.outlined(
              margin: const EdgeInsets.only(bottom: DsSpace.md),
              padding: const EdgeInsets.all(DsSpace.md),
              semanticLabel: productModel.name.toString(),
              onTap: () async {
                await FireStoreUtils.getVendorById(productModel.vendorID.toString()).then((value) {
                  if (value != null) {
                    ShowToastDialog.closeLoader();
                    Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": value})?.then((value) async {
                      await controller.getData();
                    });
                  }
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            productModel.nonveg == true ? SvgPicture.asset("assets/icons/ic_nonveg.svg") : SvgPicture.asset("assets/icons/ic_veg.svg"),
                            const DsGap(DsSpace.xs),
                            Text(productModel.nonveg == true ? "Non Veg.".tr : "Pure veg.".tr, style: t.labelSm.withColor(productModel.nonveg == true ? c.dangerStrong : c.successStrong)),
                          ],
                        ),
                        const DsGap(DsSpace.xs),
                        Text(productModel.name.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSm),
                        const DsGap(DsSpace.xs),
                        double.parse(disPrice) <= 0
                            ? Text(
                                Constant.amountShow(amount: price, currency: RegionService.currencyForVendorId(productModel.vendorID)),
                                style: t.titleSm.tabular.withColor(c.brandStrong),
                              )
                            : Row(
                                children: [
                                  Text(
                                    Constant.amountShow(amount: disPrice, currency: RegionService.currencyForVendorId(productModel.vendorID)),
                                    style: t.titleSm.tabular.withColor(c.brandStrong),
                                  ),
                                  const DsGap(DsSpace.xs),
                                  Text(
                                    Constant.amountShow(amount: price, currency: RegionService.currencyForVendorId(productModel.vendorID)),
                                    style: t.bodySm.tabular.strike,
                                  ),
                                ],
                              ),
                        const DsGap(DsSpace.xs),
                        Row(
                          children: [
                            Icon(Icons.star_rounded, size: 15, color: c.warning),
                            const DsGap(DsSpace.xs),
                            Text(
                              "${Constant.calculateReview(reviewCount: productModel.reviewsCount!.toStringAsFixed(0), reviewSum: productModel.reviewsSum.toString())} (${productModel.reviewsCount!.toStringAsFixed(0)})",
                              style: t.bodySm.tabular,
                            ),
                          ],
                        ),
                        const DsGap(DsSpace.xs),
                        Text("${productModel.description}", maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySm),
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.md),
                  Stack(
                    children: [
                      DsImage(url: productModel.photo.toString(), fit: BoxFit.cover, height: 104, width: 104, radius: DsRadius.md, errorIcon: Icons.fastfood_outlined),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: _HeartButton(
                          isFavourite: () => controller.favouriteItemList.where((p0) => p0.productId == productModel.id).isNotEmpty,
                          onTap: () async {
                            if (controller.favouriteItemList.where((p0) => p0.productId == productModel.id).isNotEmpty) {
                              FavouriteItemModel favouriteModel = FavouriteItemModel(productId: productModel.id, storeId: productModel.vendorID, userId: FireStoreUtils.getCurrentUid());
                              controller.favouriteItemList.removeWhere((item) => item.productId == productModel.id);
                              controller.favouriteFoodList.removeAt(index);
                              await FireStoreUtils.removeFavouriteItem(favouriteModel);
                            } else {
                              FavouriteItemModel favouriteModel = FavouriteItemModel(productId: productModel.id, storeId: productModel.vendorID, userId: FireStoreUtils.getCurrentUid());
                              controller.favouriteItemList.add(favouriteModel);
                              await FireStoreUtils.setFavouriteItem(favouriteModel);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
        }
      },
    );
  }
}

/// Glass heart over media. [isFavourite] is read inside an [Obx] so the icon
/// tracks the controller's observable list on its own.
class _HeartButton extends StatelessWidget {
  final bool Function() isFavourite;
  final Future<void> Function() onTap;
  const _HeartButton({required this.isFavourite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool favourite = isFavourite();
      return DsIconButton(
        semanticLabel: favourite ? "Favourite Item".tr : "Favourite Store".tr,
        variant: DsIconButtonVariant.filled,
        size: 36,
        onPressed: () async {
          await onTap();
        },
        child: favourite ? SvgPicture.asset("assets/icons/ic_like_fill.svg") : SvgPicture.asset("assets/icons/ic_like.svg"),
      );
    });
  }
}

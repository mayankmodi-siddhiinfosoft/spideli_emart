import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/dine_in_controller.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_category_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/screen_ui/location_enable_screens/location_permission_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/dine_in_screeen/view_all_category_dine_in_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/banner_model.dart';
import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../home_screen/category_restaurant_screen.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';
import 'dine_in_details_screen.dart';
import 'dine_in_restaurant_list_screen.dart';
import 'widgets/dine_in_widgets.dart';

/// Archetype A — dine-in storefront. Editorial hero over the reservation
/// artwork, a circular cuisine rail, a "New Arrivals" band, banners and a
/// Popular / All switch over full-bleed showcase cards.
class DineInScreen extends StatelessWidget {
  const DineInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: DineInController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final l = context.dsLayout;
        final bool isLoading = controller.isLoading.value;
        final bool isPopular = controller.isPopular.value;
        final bool noStores = Constant.isZoneAvailable == false || controller.allNearestRestaurant.isEmpty;
        final bool hasNewArrivals = controller.newArrivalRestaurantList.isNotEmpty;
        final bool hasBanners = controller.bannerBottomModel.isNotEmpty;

        return Scaffold(
          backgroundColor: c.background,
          body: NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverAppBar(
                  expandedHeight: 260,
                  floating: true,
                  pinned: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: c.brand,
                  title: Row(
                    children: [
                      DineInGlassIconButton(
                        icon: Icons.arrow_back,
                        semanticLabel: 'Back'.tr,
                        onPressed: () {
                          Get.back();
                        },
                      ),
                    ],
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset("assets/images/dine_in_bg.png", fit: BoxFit.cover),
                        const DecoratedBox(decoration: BoxDecoration(gradient: DsGradients.imageScrim)),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.lg, DsSpace.xxl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Dine-In Reservations".tr, style: t.display.withColor(Colors.white)),
                                const DsGap(DsSpace.xs),
                                Text(
                                  "Book a table at your favorite restaurant and enjoy a delightful dining experience.".tr,
                                  style: t.body.withColor(Colors.white.withValues(alpha: 0.9)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: isLoading
                ? const SingleChildScrollView(child: DsSkeletonDashboard())
                : noStores
                ? const _NoDineInZone()
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: DsSpace.xxxl),
                    child: Column(
                      children: DsFadeSlideIn.stagger([
                        Padding(
                          padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, 0),
                          child: DsSectionHeader(
                            title: "Explore the Categories".tr,
                            actionLabel: "View all".tr,
                            padding: EdgeInsets.zero,
                            onAction: () {
                              Get.to(const ViewAllCategoryDineInScreen());
                            },
                          ),
                        ),
                        const DsGap(DsSpace.md),
                        _CategoryRail(controller: controller),
                        const DsGap(DsSpace.xxl),
                        if (hasNewArrivals)
                          Container(
                            decoration: const BoxDecoration(image: DecorationImage(image: AssetImage("assets/images/ic_new_arrival_dinein.png"), fit: BoxFit.cover)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.lg),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text("New Arrivals".tr, style: t.title.withColor(Colors.white))),
                                      DsPressable(
                                        semanticLabel: "View all".tr,
                                        onTap: () {
                                          Get.to(const DineInRestaurantListScreen(), arguments: {"vendorList": controller.newArrivalRestaurantList, "title": "New Arrival"});
                                        },
                                        child: Container(
                                          constraints: const BoxConstraints(minHeight: 48),
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text("View all".tr, style: t.label.withColor(Colors.white)),
                                              const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const DsGap(DsSpace.lg),
                                  _NewArrivalRail(controller: controller),
                                ],
                              ),
                            ),
                          ),
                        if (hasBanners) Padding(padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xl), child: _BannerRail(controller: controller)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: l.gutter),
                          child: DsSegmentedTabs(
                            segments: [DsSegment("Popular Stores".tr), DsSegment("All Stores".tr)],
                            index: isPopular ? 0 : 1,
                            onChanged: (i) {
                              controller.isPopular.value = i == 0;
                            },
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.xl, l.gutter, 0),
                          child: isPopular ? _StoreList(controller: controller, popular: true) : _StoreList(controller: controller, popular: false),
                        ),
                      ]),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

/// No zone / no restaurants nearby.
class _NoDineInZone extends StatelessWidget {
  const _NoDineInZone();

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xxl),
        child: DsResponsive(
          maxWidth: 440,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: DsFadeSlideIn.stagger([
              Image.asset("assets/images/location.gif", height: 120),
              const DsGap(DsSpace.md),
              Text("No Dine-In Reservations Found in Your Area".tr, textAlign: TextAlign.center, style: t.headline),
              const DsGap(DsSpace.sm),
              Text(
                "Currently, there are no available Dine-In Reservations in your zone. Try changing your location to find nearby options.".tr,
                textAlign: TextAlign.center,
                style: t.bodySecondary,
              ),
              const DsGap(DsSpace.xl),
              DsButton.primary(
                label: "Change Zone".tr,
                icon: Icons.my_location_rounded,
                size: DsButtonSize.lg,
                expand: true,
                onPressed: () async {
                  Get.offAll(const LocationPermissionScreen());
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Popular / all store list. Reads the controller's lists in its own build,
/// so the body is wrapped in a [DsObserve].
class _StoreList extends StatelessWidget {
  final DineInController controller;
  final bool popular;

  const _StoreList({required this.controller, required this.popular});

  @override
  Widget build(BuildContext context) {
    return DsObserve(
      builder: (context) {
        final List<VendorModel> stores = popular ? controller.popularRestaurantList.toList() : controller.allNearestRestaurant.toList();
        return ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          scrollDirection: Axis.vertical,
          itemCount: stores.length,
          itemBuilder: (BuildContext context, int index) {
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
        );
      },
    );
  }
}

/// Horizontal "New Arrivals" rail over the artwork band.
class _NewArrivalRail extends StatelessWidget {
  final DineInController controller;

  const _NewArrivalRail({required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return DsObserve(
      builder: (context) {
        final List<VendorModel> stores = controller.newArrivalRestaurantList.toList();
        return SizedBox(
          height: 218,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: stores.length >= 10 ? 10 : stores.length,
            itemBuilder: (BuildContext context, int index) {
              VendorModel vendorModel = stores[index];
              return DsPressable(
                onTap: () {
                  Get.to(const DineInDetailsScreen(), arguments: {"vendorModel": vendorModel});
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: DsSpace.md),
                  child: SizedBox(
                    width: 230,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(child: DsImage(url: vendorModel.photo.toString(), radius: DsRadius.md, errorIcon: Icons.storefront_outlined)),
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: DsRadius.brMd,
                                  child: const DecoratedBox(decoration: BoxDecoration(gradient: DsGradients.imageScrim)),
                                ),
                              ),
                              Positioned(
                                right: DsSpace.xs,
                                top: DsSpace.xs,
                                child: Obx(
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
                            ],
                          ),
                        ),
                        const DsGap(DsSpace.sm),
                        Text(vendorModel.title.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm.withColor(Colors.white)),
                        const DsGap(DsSpace.xs),
                        Wrap(
                          spacing: DsSpace.sm,
                          children: [DineInRatingChip(vendorModel: vendorModel), DineInDistanceChip(vendorModel: vendorModel)],
                        ),
                        const DsGap(DsSpace.xs),
                        Text(
                          vendorModel.location.toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySm.withColor(Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Cuisine rail.
class _CategoryRail extends StatelessWidget {
  final DineInController controller;

  const _CategoryRail({required this.controller});

  @override
  Widget build(BuildContext context) {
    return DsObserve(
      builder: (context) {
        final List<VendorCategoryModel> categories = controller.vendorCategoryModel.toList();
        return SizedBox(
          height: 118,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              VendorCategoryModel vendorCategoryModel = categories[index];
              return Padding(
                padding: const EdgeInsets.only(right: DsSpace.md),
                child: SizedBox(
                  width: 80,
                  child: DineInCategoryTile(
                    photo: vendorCategoryModel.photo.toString(),
                    title: '${vendorCategoryModel.title}',
                    onTap: () {
                      Get.to(const CategoryRestaurantScreen(), arguments: {"vendorCategoryModel": vendorCategoryModel, "dineIn": true});
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Bottom banner carousel with animated dots.
class _BannerRail extends StatelessWidget {
  final DineInController controller;

  const _BannerRail({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return DsObserve(
      builder: (context) {
        final List<BannerModel> banners = controller.bannerBottomModel.toList();
        return Column(
          children: [
            SizedBox(
              height: 160,
              child: PageView.builder(
                physics: const BouncingScrollPhysics(),
                controller: controller.pageBottomController.value,
                scrollDirection: Axis.horizontal,
                itemCount: banners.length,
                padEnds: false,
                pageSnapping: true,
                onPageChanged: (value) {
                  controller.currentBottomPage.value = value;
                },
                itemBuilder: (BuildContext context, int index) {
                  BannerModel bannerModel = banners[index];
                  return DsPressable(
                    onTap: () async {
                      if (bannerModel.redirect_type == "store") {
                        ShowToastDialog.showLoader("Please wait...".tr);
                        VendorModel? vendorModel = await FireStoreUtils.getVendorById(bannerModel.redirect_id.toString());
                        if (vendorModel!.zoneId == Constant.selectedZone!.id) {
                          ShowToastDialog.closeLoader();
                          Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
                        } else {
                          ShowToastDialog.closeLoader();
                          ShowToastDialog.showToast("The store is not available in your area. Change other location first.".tr);
                        }
                      } else if (bannerModel.redirect_type == "product") {
                        ShowToastDialog.showLoader("Please wait...".tr);
                        ProductModel? productModel = await FireStoreUtils.getProductById(bannerModel.redirect_id.toString());
                        VendorModel? vendorModel = await FireStoreUtils.getVendorById(productModel!.vendorID.toString());
                        if (vendorModel!.zoneId == Constant.selectedZone!.id) {
                          ShowToastDialog.closeLoader();
                          Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
                        } else {
                          ShowToastDialog.closeLoader();
                          ShowToastDialog.showToast("The store is not available in your area. Change other location first.".tr);
                        }
                      } else if (bannerModel.redirect_type == "external_link") {
                        final uri = Uri.parse(bannerModel.redirect_id.toString());
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else {
                          ShowToastDialog.showToast("Could not launch".tr);
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: DsSpace.md),
                      child: DsImage(url: bannerModel.photo.toString(), radius: DsRadius.lg, errorIcon: Icons.image_outlined),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(banners.length, (index) {
                  return Obx(
                    () => AnimatedContainer(
                      duration: DsMotion.of(context, DsMotion.fast),
                      margin: const EdgeInsets.only(right: DsSpace.xs),
                      height: 7,
                      width: controller.currentBottomPage.value == index ? 20 : 7,
                      decoration: BoxDecoration(
                        borderRadius: DsRadius.brPill,
                        color: controller.currentBottomPage.value == index ? c.brand : c.borderStrong,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}

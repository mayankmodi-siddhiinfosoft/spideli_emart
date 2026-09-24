import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/home_e_commerce_controller.dart';
import 'package:customer/models/advertisement_model.dart';
import 'package:customer/models/banner_model.dart';
import 'package:customer/models/brands_model.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vendor_category_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/screen_ui/ecommarce/all_brand_product_screen.dart';
import 'package:customer/screen_ui/ecommarce/all_category_product_screen.dart';
import 'package:customer/screen_ui/ecommarce/widgets/product_card.dart';
import 'package:customer/screen_ui/location_enable_screens/address_list_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/advertisement_screens/all_advertisement_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/cart_screen/cart_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/home_screen/category_restaurant_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/home_screen/restaurant_list_screen.dart' show RestaurantListScreen;
import 'package:customer/screen_ui/multi_vendor_service/home_screen/view_all_category_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/restaurant_details_screen/restaurant_details_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/search_screen/search_screen.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/widget/osm_map/map_picker_page.dart';
import 'package:customer/widget/place_picker/location_picker_screen.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:customer/widget/shop_widgets.dart';
import 'package:customer/widget/video_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// Archetype A – e-commerce storefront. Gradient hero (account + address +
/// cart) with the Delivery/TakeAway toggle in the overlap card, then category
/// rail, banners, highlights, new arrivals, brands, category shelves and
/// stores. The search bar stays docked at the bottom.
class HomeECommerceScreen extends StatelessWidget {
  const HomeECommerceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: HomeECommerceController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final bool isLoading = controller.isLoading.value;

        final List<VendorCategoryModel> categories = controller.vendorCategoryModel.toList();
        final List<BrandsModel> brands = controller.brandList.toList();
        final List<VendorModel> newArrivals = controller.newArrivalRestaurantList.toList();
        final List<VendorModel> stores = controller.allNearestRestaurant.toList();
        final List<VendorCategoryModel> shelves = controller.categoryWiseProductList.toList();
        final bool hasAds = controller.advertisementList.isNotEmpty;
        final bool hasBanner = controller.bannerModel.isNotEmpty;
        final bool hasBottomBanner = controller.bannerBottomModel.isNotEmpty;

        return DsScaffold.hero(
          onBack: () {
            Get.offAll(const ServiceListScreen());
          },
          onRefresh: controller.getData,
          actions: [
            Obx(
              () => DsIconButton(
                semanticLabel: 'Cart'.tr,
                badgeCount: cartItem.length,
                color: Colors.white,
                onPressed: () async {
                  (await Get.to(const CartScreen()));
                  controller.getCartData();
                },
                child: SvgPicture.asset("assets/icons/ic_shoping_cart.svg", height: 20, width: 20, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
              ),
            ),
          ],
          hero: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Constant.userModel == null
                  ? InkWell(
                    onTap: () {
                      Get.offAll(const LoginScreen());
                    },
                    child: Text("Login".tr, style: DsTypography.title.copyWith(color: Colors.white)),
                  )
                  : Text(Constant.userModel!.fullName(), maxLines: 1, overflow: TextOverflow.ellipsis, style: DsTypography.title.copyWith(color: Colors.white)),
              const DsGap(DsSpace.md),
              DsCard.glass(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
                onTap: () => _pickAddress(context, controller),
                semanticLabel: "Address".tr,
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Colors.white, size: 20),
                    const DsGap(DsSpace.sm),
                    Expanded(
                      child: Text.rich(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        TextSpan(
                          children: [
                            TextSpan(text: Constant.selectedLocation.getFullAddress(), style: DsTypography.bodyStrong.copyWith(color: Colors.white)),
                            WidgetSpan(child: SvgPicture.asset("assets/icons/ic_down.svg", colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Delivery / TakeAway toggles at the top; the search bar is at the bottom (spec 7.3).
          heroOverlap: DsCard(
            padding: const EdgeInsets.all(DsSpace.sm),
            child: Obx(
              () => OrderTypeToggle(value: controller.selectedOrderTypeValue.value, isDark: context.dsIsDark, onChanged: (value) => controller.changeOrderType(context, value)),
            ),
          ),
          bottomBar:
              isLoading
                  ? null
                  : BottomSearchBar(
                    isDark: context.dsIsDark,
                    hint: 'Search the store, item and more...'.tr,
                    onTap: () {
                      Get.to(const SearchScreen(), arguments: {"vendorList": controller.allNearestRestaurant});
                    },
                  ),
          slivers:
              isLoading
                  ? const [DsSliverResponsive(top: DsSpace.xl, sliver: SliverToBoxAdapter(child: _HomeSkeleton()))]
                  : [
                    // Categories
                    DsSliverResponsive(
                      top: DsSpace.sm,
                      sliver: SliverToBoxAdapter(
                        child: DsSectionHeader(
                          title: "Category".tr,
                          trailing: NextArrowButton(
                            onTap: () {
                              Get.to(const ViewAllCategoryScreen());
                            },
                          ),
                        ),
                      ),
                    ),
                    DsSliverResponsive(
                      maxWidth: DsLayout.wideMax,
                      sliver: SliverToBoxAdapter(
                        child: SizedBox(
                          height: 104,
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: categories.length,
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.zero,
                            itemBuilder: (context, index) {
                              VendorCategoryModel vendorCategoryModel = categories[index];
                              return DsFadeSlideIn(
                                index: index,
                                child: InkWell(
                                  borderRadius: DsRadius.brMd,
                                  onTap: () {
                                    Get.to(const CategoryRestaurantScreen(), arguments: {"vendorCategoryModel": vendorCategoryModel, "dineIn": false, "ecommerce": true});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsetsDirectional.only(end: DsSpace.lg),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          height: 64,
                                          width: 64,
                                          padding: const EdgeInsets.all(DsSpace.sm),
                                          decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle),
                                          child: ClipOval(child: DsImage(url: vendorCategoryModel.photo.toString(), radius: 0, fit: BoxFit.cover)),
                                        ),
                                        const DsGap(DsSpace.xs),
                                        SizedBox(
                                          width: 76,
                                          child: Text(vendorCategoryModel.title.toString(), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSm.withColor(c.textPrimary)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // Top banners
                    if (hasBanner)
                      DsSliverResponsive(
                        maxWidth: DsLayout.wideMax,
                        top: DsSpace.lg,
                        sliver: SliverToBoxAdapter(child: BannerView(controller: controller)),
                      ),

                    // Highlights (ads)
                    if (Constant.isEnableAdsFeature == true && hasAds)
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.only(top: DsSpace.lg),
                          color: c.brandSoft,
                          padding: const EdgeInsets.only(bottom: DsSpace.lg),
                          child: DsResponsive(
                            maxWidth: DsLayout.wideMax,
                            padded: true,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DsSectionHeader(
                                  title: "Highlights for you".tr,
                                  trailing: NextArrowButton(
                                    onTap: () {
                                      Get.to(AllAdvertisementScreen())?.then((value) {
                                        controller.getFavouriteRestaurant();
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(
                                  height: 250,
                                  child: ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: controller.advertisementList.length >= 10 ? 10 : controller.advertisementList.length,
                                    padding: EdgeInsets.all(0),
                                    itemBuilder: (BuildContext context, int index) {
                                      return DsFadeSlideIn(index: index, child: AdvertisementHomeCard(controller: controller, model: controller.advertisementList[index]));
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // New arrivals
                    DsSliverResponsive(
                      top: DsSpace.sm,
                      sliver: SliverToBoxAdapter(child: DsSectionHeader(title: "New Arrivals".tr, subtitle: "Fresh in your area".tr)),
                    ),
                    DsSliverResponsive(
                      maxWidth: DsLayout.wideMax,
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          children: [
                            GridView.count(
                              crossAxisCount: context.dsLayout.value(phone: 2, tablet: 3, desktop: 4),
                              mainAxisSpacing: DsSpace.lg,
                              crossAxisSpacing: DsSpace.lg,
                              childAspectRatio: 1 / 1.35,
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: newArrivals.take(4).map((item) => NewArrivalCard(item: item)).toList(),
                            ),
                            const DsGap(DsSpace.lg),
                            DsButton.secondary(
                              label: 'View All Arrivals'.tr,
                              trailingIcon: Icons.arrow_forward_rounded,
                              expand: true,
                              onPressed: () {
                                Get.to(RestaurantListScreen(), arguments: {"vendorList": controller.newArrivalRestaurantList, "title": "New Arrivals".tr});
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Brands
                    DsSliverResponsive(
                      top: DsSpace.sm,
                      sliver: SliverToBoxAdapter(child: DsSectionHeader(title: "Top Brands".tr)),
                    ),
                    DsSliverResponsive(
                      maxWidth: DsLayout.wideMax,
                      sliver: SliverToBoxAdapter(
                        child: GridView.builder(
                          padding: EdgeInsets.zero,
                          gridDelegate: DsLayout.gridDelegate(maxItemWidth: 110, mainAxisExtent: 76 + MediaQuery.textScalerOf(context).scale(32)),
                          itemCount: brands.length,
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            BrandsModel brandModel = brands[index];
                            return DsFadeSlideIn(
                              index: index,
                              child: InkWell(
                                borderRadius: DsRadius.brMd,
                                onTap: () {
                                  Get.to(AllBrandProductScreen(), arguments: {"brandModel": brandModel});
                                },
                                child: Column(
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(color: c.surface, borderRadius: DsRadius.brLg, border: Border.all(color: c.border)),
                                      child: Padding(padding: const EdgeInsets.all(DsSpace.sm), child: ClipOval(child: DsImage(url: brandModel.photo.toString(), radius: 0, fit: BoxFit.cover))),
                                    ),
                                    const DsGap(DsSpace.xs),
                                    Text('${brandModel.title}', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.labelSm.withColor(c.textPrimary)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Category shelves
                    SliverList.builder(
                      itemCount: shelves.length,
                      itemBuilder: (context, index) {
                        VendorCategoryModel item = shelves[index];
                        String imagePath = ["assets/images/ic_product_bg_1.png", "assets/images/ic_product_bg_2.png", "assets/images/ic_product_bg_3.png"][index % ["", "", ""].length];
                        return Container(
                          margin: const EdgeInsets.only(top: DsSpace.lg),
                          decoration: BoxDecoration(image: DecorationImage(image: AssetImage(imagePath), fit: BoxFit.fill)),
                          child: DsResponsive(
                            maxWidth: DsLayout.wideMax,
                            padded: true,
                            child: Padding(
                              padding: const EdgeInsets.only(top: DsSpace.lg, bottom: DsSpace.xl),
                              child: FutureBuilder<List<ProductModel>>(
                                future: FireStoreUtils.getProductListByCategoryId(item.id.toString()),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const DsSkeletonGrid(itemCount: 3, minItemWidth: 150, padding: EdgeInsets.zero);
                                  } else if ((snapshot.hasData || (snapshot.data?.isNotEmpty ?? false))) {
                                    List<ProductModel> productList = snapshot.data!;
                                    return snapshot.data!.isEmpty
                                        ? Container()
                                        : Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          children: [
                                            Text(item.title.toString(), textAlign: TextAlign.start, style: DsTypography.title.copyWith(color: DsColors.light.textPrimary)),
                                            const DsGap(DsSpace.xxs),
                                            Text(
                                              "Style up with the latest fits, now at unbeatable prices.".tr,
                                              textAlign: TextAlign.start,
                                              style: DsTypography.bodySm.copyWith(color: DsColors.light.textSecondary),
                                            ),
                                            const DsGap(DsSpace.lg),
                                            GridView.builder(
                                              shrinkWrap: true,
                                              gridDelegate: DsLayout.gridDelegate(maxItemWidth: 200, mainAxisExtent: EcommerceProductCard.gridExtent(context)),
                                              padding: EdgeInsets.zero,
                                              physics: const NeverScrollableScrollPhysics(),
                                              itemCount: productList.length > 6 ? 6 : productList.length,
                                              itemBuilder: (context, index) {
                                                ProductModel productModel = productList[index];
                                                return EcommerceProductCard(productModel: productModel);
                                              },
                                            ),
                                            const DsGap(DsSpace.lg),
                                            DsButton.secondary(
                                              label: 'View All Products'.tr,
                                              trailingIcon: Icons.arrow_forward_rounded,
                                              expand: true,
                                              onPressed: () {
                                                Get.to(AllCategoryProductScreen(), arguments: {"categoryModel": item});
                                              },
                                            ),
                                          ],
                                        );
                                  } else {
                                    return SizedBox();
                                  }
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Bottom banners
                    if (hasBottomBanner)
                      DsSliverResponsive(
                        maxWidth: DsLayout.wideMax,
                        top: DsSpace.lg,
                        sliver: SliverToBoxAdapter(child: BannerBottomView(controller: controller)),
                      ),

                    // All stores
                    DsSliverResponsive(
                      top: DsSpace.sm,
                      sliver: SliverToBoxAdapter(child: DsSectionHeader(title: "All Store".tr, subtitle: "${stores.length} ${'nearby'.tr}")),
                    ),
                    DsSliverResponsive(
                      maxWidth: DsLayout.wideMax,
                      bottom: DsSpace.xl,
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          children: [
                            ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: stores.length > 8 ? 8 : stores.length,
                              itemBuilder: (context, index) {
                                VendorModel item = stores[index];
                                return DsFadeSlideIn(index: index, child: _StoreRow(item: item));
                              },
                            ),
                            const DsGap(DsSpace.sm),
                            DsButton.secondary(
                              label: 'View All Stores'.tr,
                              trailingIcon: Icons.arrow_forward_rounded,
                              expand: true,
                              onPressed: () {
                                Get.to(const RestaurantListScreen(), arguments: {"vendorList": controller.allNearestRestaurant});
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
        );
      },
    );
  }

  /// Address picker – behaviour moved verbatim from the old app-bar row.
  Future<void> _pickAddress(BuildContext context, HomeECommerceController controller) async {
    if (Constant.userModel != null) {
      Get.to(AddressListScreen())!.then((value) {
        if (value != null) {
          ShippingAddress shippingAddress = value;
          Constant.selectedLocation = shippingAddress;
          controller.getData();
        }
      });
    } else {
      Constant.checkPermission(
        onTap: () async {
          ShowToastDialog.showLoader("Please wait...".tr);

          // ✅ declare it once here!
          ShippingAddress shippingAddress = ShippingAddress();

          try {
            await Geolocator.requestPermission();
            await Geolocator.getCurrentPosition();
            ShowToastDialog.closeLoader();

            if (Constant.selectedMapType == 'osm') {
              final result = await Get.to(() => MapPickerPage());
              if (result != null) {
                final firstPlace = result;
                final lat = firstPlace.coordinates.latitude;
                final lng = firstPlace.coordinates.longitude;
                final address = firstPlace.address;

                shippingAddress.addressAs = "Home";
                shippingAddress.locality = address.toString();
                shippingAddress.location = UserLocation(latitude: lat, longitude: lng);
                Constant.selectedLocation = shippingAddress;
                controller.getData();
                Get.back();
              }
            } else {
              Get.to(LocationPickerScreen())!.then((value) async {
                if (value != null) {
                  SelectedLocationModel selectedLocationModel = value;

                  shippingAddress.addressAs = "Home";
                  shippingAddress.location = UserLocation(latitude: selectedLocationModel.latLng!.latitude, longitude: selectedLocationModel.latLng!.longitude);
                  shippingAddress.locality = "Picked from Map"; // You can reverse-geocode

                  Constant.selectedLocation = shippingAddress;
                  controller.getData();
                }
              });
            }
          } catch (e) {
            await Geocoding().placemarkFromCoordinates(19.228825, 72.854118).then((valuePlaceMaker) {
              Placemark placeMark = valuePlaceMaker[0];
              shippingAddress.location = UserLocation(latitude: 19.228825, longitude: 72.854118);
              String currentLocation =
                  "${placeMark.name}, ${placeMark.subLocality}, ${placeMark.locality}, ${placeMark.administrativeArea}, ${placeMark.postalCode}, ${placeMark.country}";
              shippingAddress.locality = currentLocation;
            });

            Constant.selectedLocation = shippingAddress;
            ShowToastDialog.closeLoader();
            controller.getData();
          }
        },
        context: context,
      );
    }
  }
}

/// Store row of the "All Store" list.
class _StoreRow extends StatelessWidget {
  final VendorModel item;

  const _StoreRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.sm),
      semanticLabel: item.title.toString(),
      onTap: () {
        Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": item});
      },
      child: Row(
        children: [
          DsImage(url: item.photo.toString(), height: 84, width: 120, radius: DsRadius.md),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                const DsGap(DsSpace.xs),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: c.textMuted),
                    const DsGap(DsSpace.xs),
                    Expanded(child: Text(item.location.toString(), maxLines: 1, style: t.bodySm, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const DsGap(DsSpace.sm),
                DsBadge(
                  label: "${Constant.calculateReview(reviewCount: item.reviewsCount.toString(), reviewSum: item.reviewsSum.toString())} (${item.reviewsSum})",
                  tone: DsTone.warning,
                  icon: Icons.star_rounded,
                  small: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// New-arrival store tile.
class NewArrivalCard extends StatelessWidget {
  final VendorModel item;

  const NewArrivalCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      padding: EdgeInsets.zero,
      semanticLabel: item.title.toString(),
      onTap: () {
        Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": item});
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.5,
            child: DsImage(
              radius: 0,
              fit: BoxFit.cover,
              url: item.photo != null && item.photo!.isNotEmpty ? item.photo.toString() : Constant.placeHolderImage.toString(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DsSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyStrong),
                const DsGap(DsSpace.xxs),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: c.textMuted),
                    const DsGap(DsSpace.xxs),
                    Expanded(child: Text(item.location.toString(), maxLines: 1, style: t.caption, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const DsGap(DsSpace.xs),
                DsBadge(
                  label: "${Constant.calculateReview(reviewCount: item.reviewsCount.toString(), reviewSum: item.reviewsSum.toString())} (${item.reviewsSum})",
                  tone: DsTone.warning,
                  icon: Icons.star_rounded,
                  small: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Top banner carousel.
class BannerView extends StatelessWidget {
  final HomeECommerceController controller;

  const BannerView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PageView.builder(
            physics: const BouncingScrollPhysics(),
            controller: controller.pageController.value,
            scrollDirection: Axis.horizontal,
            itemCount: controller.bannerModel.length,
            padEnds: false,
            pageSnapping: true,
            allowImplicitScrolling: true,
            onPageChanged: (value) {
              controller.currentPage.value = value;
            },
            itemBuilder: (BuildContext context, int index) {
              BannerModel bannerModel = controller.bannerModel[index];
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: DsSpace.md),
                child: DsPressable(
                  onTap: () => openBanner(bannerModel),
                  child: DsImage(url: bannerModel.photo.toString(), radius: DsRadius.lg, fit: BoxFit.cover),
                ),
              );
            },
          ),
        ),
        const DsGap(DsSpace.md),
        _Dots(count: controller.bannerModel.length, current: () => controller.currentPage.value),
      ],
    );
  }
}

/// Bottom banner carousel.
class BannerBottomView extends StatelessWidget {
  final HomeECommerceController controller;

  const BannerBottomView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            physics: const BouncingScrollPhysics(),
            controller: controller.pageBottomController.value,
            scrollDirection: Axis.horizontal,
            itemCount: controller.bannerBottomModel.length,
            padEnds: false,
            pageSnapping: true,
            allowImplicitScrolling: true,
            onPageChanged: (value) {
              controller.currentBottomPage.value = value;
            },
            itemBuilder: (BuildContext context, int index) {
              BannerModel bannerModel = controller.bannerBottomModel[index];
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: DsSpace.md),
                child: DsPressable(
                  onTap: () => openBanner(bannerModel),
                  child: DsImage(url: bannerModel.photo.toString(), radius: DsRadius.lg, fit: BoxFit.cover),
                ),
              );
            },
          ),
        ),
        const DsGap(DsSpace.md),
        _Dots(count: controller.bannerBottomModel.length, current: () => controller.currentBottomPage.value),
      ],
    );
  }
}

/// Banner redirection – unchanged behaviour, shared by both carousels.
Future<void> openBanner(BannerModel bannerModel) async {
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
}

/// Animated page indicator for the banner carousels.
class _Dots extends StatelessWidget {
  final int count;
  final int Function() current;

  const _Dots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(count, (index) {
        return Obx(() {
          final bool active = current() == index;
          return AnimatedContainer(
            duration: DsMotion.of(context, DsMotion.fast),
            margin: const EdgeInsetsDirectional.only(end: DsSpace.xs),
            height: 6,
            width: active ? 20 : 6,
            decoration: BoxDecoration(color: active ? c.brand : c.border, borderRadius: DsRadius.brPill),
          );
        });
      }),
    );
  }
}

/// Promoted store / video advertisement card.
class AdvertisementHomeCard extends StatelessWidget {
  final AdvertisementModel model;
  final HomeECommerceController controller;

  const AdvertisementHomeCard({super.key, required this.controller, required this.model});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard(
      margin: const EdgeInsetsDirectional.only(end: DsSpace.lg),
      padding: EdgeInsets.zero,
      radius: DsRadius.lg,
      semanticLabel: model.title ?? '',
      onTap: () async {
        ShowToastDialog.showLoader("Please wait...".tr);
        VendorModel? vendorModel = await FireStoreUtils.getVendorById(model.vendorId!);
        ShowToastDialog.closeLoader();
        Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
      },
      child: SizedBox(
        width: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                model.type == 'restaurant_promotion'
                    ? DsImage(url: model.coverImage ?? '', height: 135, width: double.infinity, radius: 0, fit: BoxFit.cover)
                    : VideoAdvWidget(url: model.video ?? '', height: 135, width: double.infinity),
                if (model.type != 'video_promotion' && model.vendorId != null && (model.showRating == true || model.showReview == true))
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: FutureBuilder(
                      future: FireStoreUtils.getVendorById(model.vendorId!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox();
                        } else {
                          if (snapshot.hasError) {
                            return const SizedBox();
                          } else if (snapshot.data == null) {
                            return const SizedBox();
                          } else {
                            VendorModel vendorModel = snapshot.data!;
                            return DsBadge(
                              label:
                                  "${model.showRating == true ? Constant.calculateReview(reviewCount: vendorModel.reviewsCount!.toStringAsFixed(0), reviewSum: vendorModel.reviewsSum.toString()) : ''} ${model.showReview == true ? '(${vendorModel.reviewsCount!.toStringAsFixed(0)})' : ''}",
                              tone: DsTone.warning,
                              style: DsBadgeStyle.solid,
                              icon: model.showRating == true ? Icons.star_rounded : null,
                              small: true,
                            );
                          }
                        }
                      },
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DsSpace.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (model.type == 'restaurant_promotion') DsAvatar(imageUrl: model.profileImage ?? '', name: model.title, size: 44),
                    if (model.type == 'restaurant_promotion') const DsGap(DsSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(model.title ?? '', style: t.bodyStrong, overflow: TextOverflow.ellipsis),
                          const DsGap(DsSpace.xxs),
                          Text(model.description ?? '', style: t.bodySm, overflow: TextOverflow.ellipsis, maxLines: 2),
                        ],
                      ),
                    ),
                    model.type == 'restaurant_promotion'
                        ? Obx(
                          () => DsIconButton(
                            semanticLabel: 'Favourites'.tr,
                            size: 36,
                            onPressed: () async {
                              if (controller.favouriteList.where((p0) => p0.restaurantId == model.vendorId).isNotEmpty) {
                                FavouriteModel favouriteModel = FavouriteModel(restaurantId: model.vendorId, userId: FireStoreUtils.getCurrentUid());
                                controller.favouriteList.removeWhere((item) => item.restaurantId == model.vendorId);
                                await FireStoreUtils.removeFavouriteRestaurant(favouriteModel);
                              } else {
                                FavouriteModel favouriteModel = FavouriteModel(restaurantId: model.vendorId, userId: FireStoreUtils.getCurrentUid());
                                controller.favouriteList.add(favouriteModel);
                                await FireStoreUtils.setFavouriteRestaurant(favouriteModel);
                              }
                              controller.update();
                            },
                            child:
                                controller.favouriteList.where((p0) => p0.restaurantId == model.vendorId).isNotEmpty
                                    ? SvgPicture.asset("assets/icons/ic_like_fill.svg")
                                    : SvgPicture.asset("assets/icons/ic_like.svg", colorFilter: ColorFilter.mode(c.textMuted, BlendMode.srcIn)),
                          ),
                        )
                        : Container(
                          decoration: BoxDecoration(color: c.brandSoft, borderRadius: DsRadius.brSm),
                          child: Padding(padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.xs), child: Icon(Icons.arrow_forward, size: 20, color: c.brandStrong)),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Storefront loading state (categories, banner, highlights, grids).
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return DsShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: DsSkeleton.line(width: 110, height: 16)), DsSkeleton.line(width: 40, height: 12)]),
          const DsGap(DsSpace.lg),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              separatorBuilder: (_, _) => const DsGap(DsSpace.lg),
              itemBuilder: (_, _) => Column(children: [DsSkeleton.circle(size: 64), const DsGap(DsSpace.sm), DsSkeleton.line(width: 52, height: 10)]),
            ),
          ),
          const DsGap(DsSpace.lg),
          DsSkeleton.box(height: 170, radius: DsRadius.lg),
          const DsGap(DsSpace.xl),
          DsSkeleton.line(width: 130, height: 16),
          const DsGap(DsSpace.lg),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: DsSpace.lg,
            mainAxisSpacing: DsSpace.lg,
            childAspectRatio: 1 / 1.35,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: List.generate(4, (_) => DsSkeleton.box(radius: DsRadius.lg)),
          ),
          const DsGap(DsSpace.xl),
          DsSkeleton.line(width: 100, height: 16),
          const DsGap(DsSpace.lg),
          GridView.count(
            crossAxisCount: 4,
            crossAxisSpacing: DsSpace.md,
            mainAxisSpacing: DsSpace.md,
            childAspectRatio: 0.85,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: List.generate(8, (_) => Column(children: [DsSkeleton.box(width: 64, height: 64, radius: DsRadius.lg), const DsGap(DsSpace.xs), DsSkeleton.line(width: 40, height: 10)])),
          ),
        ],
      ),
    );
  }
}

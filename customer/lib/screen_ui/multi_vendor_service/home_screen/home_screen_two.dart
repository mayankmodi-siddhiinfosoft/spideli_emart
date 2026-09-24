import 'package:customer/utils/region_service.dart';
import 'dart:math';

import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/food_home_controller.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/story_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vendor_category_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/screen_ui/location_enable_screens/address_list_screen.dart';
import 'package:customer/screen_ui/location_enable_screens/location_permission_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/home_screen/restaurant_list_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/home_screen/story_view.dart';
import 'package:customer/screen_ui/multi_vendor_service/home_screen/view_all_category_screen.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:customer/widget/osm_map/map_picker_page.dart';
import 'package:customer/widget/place_picker/location_picker_screen.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/banner_model.dart';
import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../../../widget/gradiant_text.dart';
import '../../../widget/shop_widgets.dart';
import '../../auth_screens/login_screen.dart';
import '../advertisement_screens/all_advertisement_screen.dart';
import '../cart_screen/cart_screen.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';
import '../scan_qrcode_screen/scan_qr_code_screen.dart';
import '../search_screen/search_screen.dart';
import 'category_restaurant_screen.dart';
import 'discount_restaurant_list_screen.dart';
import 'home_screen.dart';
import 'widgets/store_widgets.dart';

/// Archetype A — food storefront (variant two, `SectionModel.theme ==
/// "theme_2"`). Same archetype as [HomeScreen] but a different hero rhythm:
/// banners lead, and each block is a distinct rounded "panel" with a
/// gradient headline instead of a plain section header.
class HomeScreenTwo extends StatelessWidget {
  const HomeScreenTwo({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: FoodHomeController(),
      builder: (controller) {
        final c = context.dsColors;
        final l = context.dsLayout;
        final gutter = EdgeInsets.symmetric(horizontal: l.gutter);
        // Read every observable unconditionally: a `||` short-circuit
        // would hide one of them from this GetX observer.
        final isLoading = controller.isLoading.value;
        final hasNoStores = controller.allNearestRestaurant.isEmpty;
        final hasStores = !(Constant.isZoneAvailable == false || hasNoStores);

        return Scaffold(
          backgroundColor: c.background,
          body: isLoading
              ? const FoodHomeSkeleton(bannerFirst: true)
              : !hasStores
              ? NoStoreInZoneView(
                  onChangeZone: () async {
                    Get.offAll(const LocationPermissionScreen());
                  },
                )
              : Padding(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).viewPadding.top),
                  child: controller.isListView.value == false
                      ? const MapView()
                      : Column(
                          children: [
                            DsResponsive(
                              maxWidth: DsLayout.wideMax,
                              child: Padding(
                                padding: gutter,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _HomeTwoHeaderBar(controller: controller),
                                    const DsGap(DsSpace.md),
                                    // Delivery / TakeAway toggles at the top; the search bar is at the bottom (spec 7.3).
                                    OrderTypeToggle(value: controller.selectedOrderTypeValue.value, isDark: c.isDark, onChanged: (value) => controller.changeOrderType(context, value)),
                                    const DsGap(DsSpace.xs),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: DsResponsive(
                                  maxWidth: DsLayout.wideMax,
                                  child: Column(
                                    children: [
                                      controller.bannerModel.isEmpty ? const SizedBox() : Padding(padding: gutter, child: BannerView(controller: controller)),
                                      const DsGap(DsSpace.xl),
                                      Padding(padding: gutter, child: CategoryView(controller: controller)),
                                      controller.couponRestaurantList.isEmpty
                                          ? const SizedBox()
                                          : Padding(padding: gutter, child: Column(children: [const DsGap(DsSpace.xl), OfferView(controller: controller)])),
                                      controller.storyList.isEmpty || Constant.storyEnable == false
                                          ? const SizedBox()
                                          : Padding(padding: gutter, child: Column(children: [const DsGap(DsSpace.xl), StoryView(controller: controller)])),
                                      Visibility(
                                        visible: Constant.isEnableAdsFeature == true,
                                        child: controller.advertisementList.isEmpty
                                            ? const SizedBox()
                                            : Column(
                                                children: [
                                                  const DsGap(DsSpace.xl),
                                                  Container(
                                                    margin: gutter,
                                                    padding: const EdgeInsets.all(DsSpace.lg),
                                                    decoration: BoxDecoration(borderRadius: DsRadius.brXl, color: c.brandSoft, border: Border.all(color: c.border)),
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.start,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        DsSectionHeader(
                                                          title: "Highlights for you".tr,
                                                          padding: EdgeInsets.zero,
                                                          trailing: NextArrowButton(
                                                            onTap: () {
                                                              Get.to(AllAdvertisementScreen())?.then((value) {
                                                                controller.getFavouriteRestaurant();
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                        const DsGap(DsSpace.lg),
                                                        SizedBox(
                                                          height: 240,
                                                          child: ListView.builder(
                                                            physics: const BouncingScrollPhysics(),
                                                            scrollDirection: Axis.horizontal,
                                                            itemCount: controller.advertisementList.length >= 10 ? 10 : controller.advertisementList.length,
                                                            padding: EdgeInsets.zero,
                                                            itemBuilder: (BuildContext context, int index) {
                                                              return DsFadeSlideIn(
                                                                index: index,
                                                                offset: const Offset(20, 0),
                                                                child: AdvertisementHomeCard(controller: controller, model: controller.advertisementList[index]),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                      controller.allNearestRestaurant.isEmpty ? const SizedBox() : Column(children: [const DsGap(DsSpace.xl), RestaurantView(controller: controller)]),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
          // Search bar at the bottom of the section home (spec 7.3).
          bottomNavigationBar: isLoading || !hasStores
              ? null
              : BottomSearchBar(
                  isDark: c.isDark,
                  hint: Constant.sectionConstantModel?.name?.toLowerCase().contains('restaurants') == true
                      ? 'Search the dish, food and more...'.tr
                      : 'Search the store, item and more...'.tr,
                  onTap: () {
                    Get.to(const SearchScreen(), arguments: {"vendorList": controller.allNearestRestaurant});
                  },
                ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: HomeToolFab(
            isListView: controller.isListView.value,
            onList: () {
              controller.isListView.value = true;
            },
            onMap: () {
              controller.isListView.value = false;
            },
            onScan: () {
              Get.to(const ScanQrCodeScreen());
            },
          ),
        );
      },
    );
  }
}

/// Back / account / delivery-address / cart row for variant two.
class _HomeTwoHeaderBar extends StatelessWidget {
  final FoodHomeController controller;
  const _HomeTwoHeaderBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Row(
      children: [
        DsIconButton(
          icon: Icons.arrow_back,
          semanticLabel: "Back".tr,
          onPressed: () {
            Get.offAll(const ServiceListScreen());
          },
        ),
        const DsGap(DsSpace.sm),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Constant.userModel == null
                  ? InkWell(
                      onTap: () {
                        Get.offAll(const LoginScreen());
                      },
                      child: Text("Login".tr, textAlign: TextAlign.center, style: t.caption.withColor(c.brandStrong).w600),
                    )
                  : Text(Constant.userModel!.fullName(), textAlign: TextAlign.center, style: t.caption.withColor(c.textSecondary)),
              InkWell(
                onTap: () async {
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

                        // ✅ declare once for whole method
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
                                shippingAddress.location = UserLocation(
                                  latitude: selectedLocationModel.latLng!.latitude,
                                  longitude: selectedLocationModel.latLng!.longitude,
                                );
                                shippingAddress.locality = "Picked from Map"; // You can reverse-geocode

                                Constant.selectedLocation = shippingAddress;
                                controller.getData();
                              }
                            });
                          }
                        } catch (e) {
                          await Geocoding().placemarkFromCoordinates(19.228825, 72.854118).then((valuePlaceMaker) {
                            Placemark placeMark = valuePlaceMaker[0];
                            shippingAddress.addressAs = "Home";
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
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.xxs),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 16, color: c.brandStrong),
                      const DsGap(DsSpace.xxs),
                      Flexible(
                        child: Text(Constant.selectedLocation.getFullAddress(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyStrong),
                      ),
                      SvgPicture.asset("assets/icons/ic_down.svg", width: 16, height: 16, colorFilter: ColorFilter.mode(c.textSecondary, BlendMode.srcIn)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const DsGap(DsSpace.xs),
        DsIconButton(
          semanticLabel: "Cart".tr,
          variant: DsIconButtonVariant.tonal,
          size: 42,
          child: SvgPicture.asset("assets/icons/ic_shoping_cart.svg", width: 20, height: 20),
          onPressed: () async {
            (await Get.to(const CartScreen()));
            controller.getCartData();
          },
        ),
      ],
    );
  }
}

/// Panel wrapper that gives variant two its "block" rhythm: a rounded
/// surface, a plain title with the forward arrow and a gradient strapline.
class _HomePanel extends StatelessWidget {
  final String title;
  final String strapline;
  final Gradient straplineGradient;
  final VoidCallback? onAction;
  final Widget child;
  final DecorationImage? backgroundImage;
  final Color? titleColor;

  const _HomePanel({
    required this.title,
    required this.strapline,
    required this.straplineGradient,
    required this.child,
    this.onAction,
    this.backgroundImage,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Container(
      decoration: BoxDecoration(
        color: backgroundImage == null ? c.surface : null,
        image: backgroundImage,
        borderRadius: DsRadius.brXxl,
        border: backgroundImage == null ? Border.all(color: c.border) : null,
        boxShadow: backgroundImage == null ? DsShadows.xs(context) : null,
      ),
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: t.titleSm.withColor(titleColor ?? c.textPrimary).w600)),
              if (onAction != null) NextArrowButton(color: titleColor, onTap: onAction!),
            ],
          ),
          GradientText(strapline, style: const TextStyle(fontSize: 24, fontFamily: 'Inter Tight', fontWeight: FontWeight.w800), gradient: straplineGradient),
          const DsGap(DsSpace.lg),
          child,
        ],
      ),
    );
  }
}

/// Category grid panel (up to 8 tiles).
class CategoryView extends StatelessWidget {
  final FoodHomeController controller;

  const CategoryView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return _HomePanel(
      title: "Our Categories".tr,
      strapline: 'Best Servings Items'.tr,
      straplineGradient: const LinearGradient(colors: [Color(0xFF3961F1), Color(0xFF11D0EA)]),
      onAction: () {
        Get.to(const ViewAllCategoryScreen());
      },
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: DsLayout.gridDelegate(maxItemWidth: 110, spacing: DsSpace.sm, mainAxisExtent: 116),
        itemCount: controller.vendorCategoryModel.length >= 8 ? 8 : controller.vendorCategoryModel.length,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemBuilder: (context, index) {
          VendorCategoryModel vendorCategoryModel = controller.vendorCategoryModel[index];
          return DsFadeSlideIn(
            index: index,
            child: Semantics(
              button: true,
              label: '${vendorCategoryModel.title}',
              child: InkWell(
                onTap: () {
                  Get.to(const CategoryRestaurantScreen(), arguments: {"vendorCategoryModel": vendorCategoryModel, "dineIn": false});
                },
                borderRadius: DsRadius.brMd,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: c.brandSoft, border: Border.all(color: c.border)),
                      child: ClipOval(child: NetworkImageWidget(imageUrl: vendorCategoryModel.photo.toString(), fit: BoxFit.cover)),
                    ),
                    const DsGap(DsSpace.sm),
                    Flexible(
                      child: Text("${vendorCategoryModel.title}", textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.labelSm.withColor(c.textPrimary)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Discount panel: square photo tiles with a coloured discount pill.
class OfferView extends StatelessWidget {
  final FoodHomeController controller;

  const OfferView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return _HomePanel(
      title: "Large Discounts".tr,
      strapline: 'Save Upto 50% Off'.tr,
      straplineGradient: const LinearGradient(colors: [Color(0xFF39F1C5), Color(0xFF97EA11)]),
      onAction: () {
        Get.to(const DiscountRestaurantListScreen(), arguments: {"vendorList": controller.couponRestaurantList, "couponList": controller.couponList, "title": "Discounts Stores"});
      },
      child: SizedBox(
        height: 150,
        child: ListView.builder(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          itemCount: controller.couponRestaurantList.length >= 15 ? 15 : controller.couponRestaurantList.length,
          itemBuilder: (context, index) {
            VendorModel vendorModel = controller.couponRestaurantList[index];
            CouponModel offerModel = controller.couponList[index];
            final Color pill = Colors.primaries[Random().nextInt(Colors.primaries.length)];
            return DsFadeSlideIn(
              index: index,
              offset: const Offset(20, 0),
              child: Padding(
                padding: const EdgeInsets.only(right: DsSpace.md),
                child: SizedBox(
                  width: 140,
                  child: DsPressable(
                    onTap: () {
                      Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
                    },
                    child: ClipRRect(
                      borderRadius: DsRadius.brLg,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          NetworkImageWidget(imageUrl: vendorModel.photo.toString(), fit: BoxFit.cover),
                          const StoreMediaScrim(height: double.infinity),
                          Positioned(
                            left: DsSpace.sm,
                            right: DsSpace.sm,
                            bottom: DsSpace.md,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(vendorModel.title.toString(), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyStrong.withColor(Colors.white)),
                                const DsGap(DsSpace.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: 5),
                                  decoration: BoxDecoration(color: pill, borderRadius: DsRadius.brPill),
                                  child: Text(
                                    "${offerModel.discountType == "Fix Price" ? (RegionService.currencyForVendorId(offerModel.vendorID) ?? Constant.currencyModel!).symbol : ""}${offerModel.discount}${offerModel.discountType == "Percentage" ? "% off".tr : "off".tr}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.labelSm.withColor(DsColors.onColor(pill)).tabular,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class BannerView extends StatelessWidget {
  final FoodHomeController controller;

  const BannerView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: PageView.builder(
        physics: const BouncingScrollPhysics(),
        controller: controller.pageController.value,
        scrollDirection: Axis.horizontal,
        itemCount: controller.bannerModel.length,
        padEnds: false,
        pageSnapping: true,
        onPageChanged: (value) {
          controller.currentPage.value = value;
        },
        itemBuilder: (BuildContext context, int index) {
          BannerModel bannerModel = controller.bannerModel[index];
          return Padding(
            padding: const EdgeInsets.only(right: DsSpace.lg),
            child: DsPressable(
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
              child: DecoratedBox(
                decoration: BoxDecoration(borderRadius: DsRadius.brLg, boxShadow: DsShadows.sm(context)),
                child: ClipRRect(borderRadius: DsRadius.brLg, child: NetworkImageWidget(imageUrl: bannerModel.photo.toString(), fit: BoxFit.cover)),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Story panel on the illustrated background.
class StoryView extends StatelessWidget {
  final FoodHomeController controller;

  const StoryView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return _HomePanel(
      title: "Stories".tr,
      strapline: 'Best Items Stories Ever'.tr,
      straplineGradient: const LinearGradient(colors: [Color(0xFFF1C839), Color(0xFFEA1111)]),
      titleColor: Colors.white,
      backgroundImage: const DecorationImage(image: AssetImage("assets/images/story_bg.png"), fit: BoxFit.cover),
      child: SizedBox(
        height: 160,
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          itemCount: controller.storyList.length,
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            StoryModel storyModel = controller.storyList[index];
            return DsFadeSlideIn(
              index: index,
              offset: const Offset(16, 0),
              child: Padding(
                padding: const EdgeInsets.only(right: DsSpace.md),
                child: DsPressable(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => MoreStories(storyList: controller.storyList, index: index)));
                  },
                  child: SizedBox(
                    width: 134,
                    child: ClipRRect(
                      borderRadius: DsRadius.brLg,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          NetworkImageWidget(imageUrl: storyModel.videoThumbnail.toString(), fit: BoxFit.cover),
                          IgnorePointer(child: Container(color: Colors.black.withValues(alpha: 0.30))),
                          Positioned(
                            left: DsSpace.sm,
                            right: DsSpace.sm,
                            top: DsSpace.sm,
                            child: _StoryTag(vendorId: storyModel.vendorID.toString()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StoryTag extends StatelessWidget {
  final String vendorId;
  const _StoryTag({required this.vendorId});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return FutureBuilder(
      future: FireStoreUtils.getVendorById(vendorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return DsShimmer(
            child: Row(children: [DsSkeleton.circle(size: 28), const DsGap(DsSpace.xs), Expanded(child: DsSkeleton.line(height: 10))]),
          );
        } else {
          if (snapshot.hasError) {
            return Center(child: Text('${"Error".tr}: ${snapshot.error}', style: t.caption.withColor(Colors.white)));
          } else if (snapshot.data == null) {
            return const SizedBox();
          } else {
            VendorModel vendorModel = snapshot.data!;
            return Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipOval(child: NetworkImageWidget(imageUrl: vendorModel.photo.toString(), width: 28, height: 28, fit: BoxFit.cover)),
                const DsGap(DsSpace.xs),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(vendorModel.title.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSm.withColor(Colors.white).w700),
                      Row(
                        children: [
                          SvgPicture.asset("assets/icons/ic_star.svg", width: 11, height: 11),
                          const DsGap(DsSpace.xxs),
                          Flexible(
                            child: Text(
                              "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount.toString(), reviewSum: vendorModel.reviewsSum!.toStringAsFixed(0))} ${'reviews'.tr}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.overline.withColor(c.warning).tabular,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
        }
      },
    );
  }
}

/// "Best Stores" — compact rows with a square photo and the best discount
/// stamped on it.
class RestaurantView extends StatelessWidget {
  final FoodHomeController controller;

  const RestaurantView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = context.dsLayout;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: l.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsSectionHeader(
            title: "Best Stores".tr,
            padding: const EdgeInsets.only(bottom: DsSpace.md),
            trailing: NextArrowButton(
              onTap: () {
                Get.to(const RestaurantListScreen(), arguments: {"vendorList": controller.allNearestRestaurant, "title": "Best Stores"});
              },
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: Axis.vertical,
            itemCount: controller.allNearestRestaurant.length,
            itemBuilder: (BuildContext context, int index) {
              VendorModel vendorModel = controller.allNearestRestaurant[index];
              List<CouponModel> tempList = [];
              List<double> discountAmountTempList = [];
              for (var element in controller.couponList) {
                if (vendorModel.id == element.vendorID && element.expiresAt!.toDate().isAfter(DateTime.now())) {
                  tempList.add(element);
                  discountAmountTempList.add(double.parse(element.discount.toString()));
                }
              }
              return DsFadeSlideIn(
                index: index,
                child: _BestStoreRow(vendorModel: vendorModel, discountAmountTempList: discountAmountTempList),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BestStoreRow extends StatelessWidget {
  final VendorModel vendorModel;
  final List<double> discountAmountTempList;
  const _BestStoreRow({required this.vendorModel, required this.discountAmountTempList});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
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
            child: SizedBox(
              width: 108,
              height: 108,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetworkImageWidget(imageUrl: vendorModel.photo.toString(), fit: BoxFit.cover),
                  if (discountAmountTempList.isNotEmpty) ...[
                    const StoreMediaScrim(height: double.infinity),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: DsSpace.sm,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text("Upto".tr, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.overline.withColor(Colors.white70)),
                          Text(
                            "${discountAmountTempList.reduce(min)}${"% OFF".tr}",
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleSm.withColor(Colors.white).w700.tabular,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const DsGap(DsSpace.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
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

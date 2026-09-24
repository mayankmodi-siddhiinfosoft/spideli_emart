import 'package:customer/utils/region_service.dart';
import 'dart:developer';

import 'package:badges/badges.dart' as badges;
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/map_view_controller.dart';
import 'package:customer/models/advertisement_model.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/product_model.dart';
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
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as location;
import 'package:url_launcher/url_launcher.dart';

import '../../../controllers/food_home_controller.dart';
import '../../../models/banner_model.dart';
import '../../../models/story_model.dart';
import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../../../widget/shop_widgets.dart';
import '../../../widget/video_widget.dart';
import '../../auth_screens/login_screen.dart';
import '../advertisement_screens/all_advertisement_screen.dart';
import '../cart_screen/cart_screen.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';
import '../scan_qrcode_screen/scan_qr_code_screen.dart';
import '../search_screen/search_screen.dart';
import 'category_restaurant_screen.dart';
import 'discount_restaurant_list_screen.dart';
import 'widgets/store_widgets.dart';

/// Archetype A — food storefront (variant one). Address header, story rail,
/// category rail, banners, discount rail, "New Arrivals" feature band, ads
/// and finally the Popular / All store list. Every rail loads behind a
/// shimmer skeleton and enters with a staggered fade.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
          body: Container(
            decoration: BoxDecoration(gradient: DsGradients.subtle(context)),
            child: isLoading
                ? const FoodHomeSkeleton()
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
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DsResponsive(
                                maxWidth: DsLayout.wideMax,
                                child: Padding(
                                  padding: gutter,
                                  child: Column(
                                    children: [
                                      const DsGap(DsSpace.sm),
                                      _HomeHeaderBar(controller: controller),
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
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        controller.storyList.isEmpty || Constant.storyEnable == false
                                            ? const SizedBox()
                                            : Padding(padding: gutter, child: StoryView(controller: controller)),
                                        SizedBox(height: controller.storyList.isEmpty ? 0 : DsSpace.xl),
                                        Padding(
                                          padding: gutter,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.start,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              DsSectionHeader(
                                                title: "Explore the Categories".tr,
                                                padding: EdgeInsets.zero,
                                                trailing: NextArrowButton(
                                                  onTap: () {
                                                    Get.to(const ViewAllCategoryScreen());
                                                  },
                                                ),
                                              ),
                                              const DsGap(DsSpace.md),
                                              CategoryView(controller: controller),
                                            ],
                                          ),
                                        ),
                                        const DsGap(DsSpace.xxxl),
                                        controller.bannerModel.isEmpty ? const SizedBox() : Padding(padding: gutter, child: BannerView(controller: controller)),
                                        controller.couponRestaurantList.isEmpty
                                            ? const SizedBox()
                                            : Padding(
                                                padding: gutter,
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.start,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    DsSectionHeader(
                                                      title: "Largest Discounts".tr,
                                                      padding: EdgeInsets.zero,
                                                      trailing: NextArrowButton(
                                                        onTap: () {
                                                          Get.to(
                                                            const DiscountRestaurantListScreen(),
                                                            arguments: {"vendorList": controller.couponRestaurantList, "couponList": controller.couponList, "title": "Discounts Stores"},
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                    const DsGap(DsSpace.lg),
                                                    OfferView(controller: controller),
                                                  ],
                                                ),
                                              ),
                                        const DsGap(DsSpace.xxl),
                                        controller.newArrivalRestaurantList.isEmpty
                                            ? const SizedBox()
                                            : Container(
                                                decoration: const BoxDecoration(image: DecorationImage(image: AssetImage("assets/images/ic_new_arrival_bg.png"), fit: BoxFit.cover)),
                                                child: Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: l.gutter, vertical: DsSpace.lg),
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.start,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(child: Text("New Arrivals".tr, textAlign: TextAlign.start, style: context.dsText.title.withColor(Colors.white).w700)),
                                                          NextArrowButton(
                                                            color: Colors.white,
                                                            onTap: () {
                                                              Get.to(const RestaurantListScreen(), arguments: {"vendorList": controller.newArrivalRestaurantList, "title": "New Arrival"})?.then((v) {
                                                                controller.getFavouriteRestaurant();
                                                              });
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                      const DsGap(DsSpace.lg),
                                                      NewArrival(controller: controller),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                        const DsGap(DsSpace.xl),
                                        controller.bannerBottomModel.isEmpty ? const SizedBox() : Padding(padding: gutter, child: BannerBottomView(controller: controller)),
                                        Visibility(visible: (Constant.isEnableAdsFeature == true && controller.advertisementList.isNotEmpty), child: const DsGap(DsSpace.xl)),
                                        Visibility(
                                          visible: Constant.isEnableAdsFeature == true,
                                          child: controller.advertisementList.isEmpty
                                              ? const SizedBox()
                                              : Container(
                                                  color: c.brandSoft,
                                                  child: Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: l.gutter, vertical: DsSpace.lg),
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
                                                ),
                                        ),
                                        const DsGap(DsSpace.xl),
                                        Padding(
                                          padding: gutter,
                                          child: DsSegmentedTabs(
                                            segments: [DsSegment("Popular Stores".tr), DsSegment("All Stores".tr)],
                                            index: controller.isPopular.value ? 0 : 1,
                                            onChanged: (i) {
                                              controller.isPopular.value = i == 0;
                                            },
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(horizontal: l.gutter, vertical: DsSpace.xl),
                                          child: controller.isPopular.value ? PopularRestaurant(controller: controller) : AllRestaurant(controller: controller),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
          ),
          // Search bar at the bottom of the section home (spec 7.3).
          bottomNavigationBar: isLoading || !hasStores
              ? null
              : BottomSearchBar(
                  isDark: c.isDark,
                  hint: Constant.sectionConstantModel?.name?.toLowerCase().contains('restaurants') == true
                      ? 'Search the restaurant, food and more...'.tr
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
              controller.update();
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

/// Back / account / delivery-address / cart row.
class _HomeHeaderBar extends StatelessWidget {
  final FoodHomeController controller;
  const _HomeHeaderBar({required this.controller});

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
            log(":: Login  :: 11");
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
                  padding: const EdgeInsets.only(top: DsSpace.xxs, bottom: DsSpace.xxs),
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
        Obx(
          () => badges.Badge(
            showBadge: cartItem.isEmpty ? false : true,
            badgeContent: Text("${cartItem.length}", style: t.labelSm.withColor(Colors.white).tabular),
            badgeStyle: badges.BadgeStyle(shape: badges.BadgeShape.circle, badgeColor: c.brand),
            child: DsIconButton(
              semanticLabel: "Cart".tr,
              variant: DsIconButtonVariant.outlined,
              size: 42,
              child: SvgPicture.asset("assets/icons/ic_shoping_cart.svg", width: 20, height: 20),
              onPressed: () async {
                (await Get.to(const CartScreen()));
                controller.getCartData();
              },
            ),
          ),
        ),
      ],
    );
  }
}

class PopularRestaurant extends StatelessWidget {
  final FoodHomeController controller;

  const PopularRestaurant({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      scrollDirection: Axis.vertical,
      itemCount: controller.popularRestaurantList.length,
      itemBuilder: (BuildContext context, int index) {
        VendorModel vendorModel = controller.popularRestaurantList[index];
        return DsFadeSlideIn(
          index: index,
          child: StoreShowcaseCard(
            vendorModel: vendorModel,
            margin: EdgeInsets.only(bottom: controller.popularRestaurantList.length - 1 == index ? 60 : DsSpace.xl),
            onTap: () {
              Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel})?.then((v) {
                controller.getFavouriteRestaurant();
              });
            },
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
    );
  }
}

class AllRestaurant extends StatelessWidget {
  final FoodHomeController controller;

  const AllRestaurant({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      scrollDirection: Axis.vertical,
      itemCount: controller.allNearestRestaurant.length,
      itemBuilder: (BuildContext context, int index) {
        VendorModel vendorModel = controller.allNearestRestaurant[index];
        return DsFadeSlideIn(
          index: index,
          child: StoreShowcaseCard(
            vendorModel: vendorModel,
            margin: EdgeInsets.only(bottom: controller.allNearestRestaurant.length - 1 == index ? 60 : DsSpace.xl),
            onTap: () {
              Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel})?.then((v) {
                controller.getFavouriteRestaurant();
              });
            },
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
    );
  }
}

/// Wide portrait cards on the "New Arrivals" band (white text over the photo).
class NewArrival extends StatelessWidget {
  final FoodHomeController controller;

  const NewArrival({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return SizedBox(
      height: 226,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: controller.newArrivalRestaurantList.length >= 10 ? 10 : controller.newArrivalRestaurantList.length,
        itemBuilder: (BuildContext context, int index) {
          VendorModel vendorModel = controller.newArrivalRestaurantList[index];
          return DsFadeSlideIn(
            index: index,
            offset: const Offset(20, 0),
            child: Padding(
              padding: const EdgeInsets.only(right: DsSpace.md),
              child: SizedBox(
                width: 250,
                child: DsPressable(
                  onTap: () {
                    Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel})?.then((v) {
                      controller.getFavouriteRestaurant();
                    });
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: DsRadius.brLg,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              NetworkImageWidget(imageUrl: vendorModel.photo.toString(), fit: BoxFit.cover),
                              const StoreMediaScrim(height: double.infinity),
                              Positioned(
                                right: DsSpace.xs,
                                top: DsSpace.xs,
                                child: Obx(
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
                              Positioned(
                                left: DsSpace.sm,
                                right: DsSpace.sm,
                                bottom: DsSpace.sm,
                                child: StoreMetaChips(
                                  vendorModel: vendorModel,
                                  showFreeDelivery: vendorModel.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true,
                                  small: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const DsGap(DsSpace.sm),
                      Text(vendorModel.title.toString(), textAlign: TextAlign.start, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm.withColor(Colors.white).w600),
                      Text(
                        vendorModel.location.toString(),
                        textAlign: TextAlign.start,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySm.withColor(Colors.white.withValues(alpha: 0.82)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Promoted store / video card on the home ads rail.
class AdvertisementHomeCard extends StatelessWidget {
  final AdvertisementModel model;
  final FoodHomeController controller;

  const AdvertisementHomeCard({super.key, required this.controller, required this.model});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return SizedBox(
      width: 280,
      child: DsCard(
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.only(right: DsSpace.lg),
        clipBehavior: Clip.antiAlias,
        semanticLabel: model.title ?? '',
        onTap: () async {
          ShowToastDialog.showLoader("Please wait...".tr);
          VendorModel? vendorModel = await FireStoreUtils.getVendorById(model.vendorId!);
          ShowToastDialog.closeLoader();
          Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                model.type == 'restaurant_promotion'
                    ? NetworkImageWidget(imageUrl: model.coverImage ?? '', height: 135, width: double.infinity, fit: BoxFit.cover)
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
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                              decoration: BoxDecoration(color: c.brandSoft, borderRadius: DsRadius.brPill),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (model.showRating == true) SvgPicture.asset("assets/icons/ic_star.svg", width: 13, height: 13, colorFilter: ColorFilter.mode(c.brandStrong, BlendMode.srcIn)),
                                  if (model.showRating == true) const DsGap(DsSpace.xs),
                                  Text(
                                    "${model.showRating == true ? Constant.calculateReview(reviewCount: vendorModel.reviewsCount!.toStringAsFixed(0), reviewSum: vendorModel.reviewsSum.toString()) : ''} ${model.showReview == true ? '(${vendorModel.reviewsCount!.toStringAsFixed(0)})' : ''}",
                                    style: t.labelSm.withColor(c.brandStrong).tabular,
                                  ),
                                ],
                              ),
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
                    if (model.type == 'restaurant_promotion') ...[
                      ClipOval(child: NetworkImageWidget(imageUrl: model.profileImage ?? '', height: 44, width: 44, fit: BoxFit.cover)),
                      const DsGap(DsSpace.sm),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(model.title ?? '', style: t.bodyStrong, overflow: TextOverflow.ellipsis, maxLines: 1),
                          const DsGap(DsSpace.xxs),
                          Text(model.description ?? '', style: t.caption, overflow: TextOverflow.ellipsis, maxLines: 2),
                        ],
                      ),
                    ),
                    model.type == 'restaurant_promotion'
                        ? Obx(
                            () => StoreFavouriteButton(
                              isFavourite: controller.favouriteList.where((p0) => p0.restaurantId == model.vendorId).isNotEmpty,
                              onTap: () async {
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
                            ),
                          )
                        : DsIconWell(icon: Icons.arrow_forward_rounded, size: 36),
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

/// Discount rail: portrait photo cards with the offer stamped on the image.
class OfferView extends StatelessWidget {
  final FoodHomeController controller;

  const OfferView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return SizedBox(
      height: 208,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: controller.couponRestaurantList.length >= 15 ? 15 : controller.couponRestaurantList.length,
        itemBuilder: (BuildContext context, int index) {
          VendorModel vendorModel = controller.couponRestaurantList[index];
          CouponModel offerModel = controller.couponList[index];
          return DsFadeSlideIn(
            index: index,
            offset: const Offset(20, 0),
            child: Padding(
              padding: const EdgeInsets.only(right: DsSpace.md),
              child: SizedBox(
                width: 168,
                child: DsPressable(
                  onTap: () {
                    Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
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
                                bottom: DsSpace.sm,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("Upto".tr, textAlign: TextAlign.start, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.withColor(Colors.white70)),
                                    Text(
                                      "${offerModel.discountType == "Fix Price" ? (RegionService.currencyForVendorId(offerModel.vendorID) ?? Constant.currencyModel!).symbol : ""}${offerModel.discount}${offerModel.discountType == "Percentage" ? "% off".tr : "off".tr}",
                                      textAlign: TextAlign.start,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: t.title.withColor(Colors.white).w700.tabular,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const DsGap(DsSpace.sm),
                      Text(vendorModel.title.toString(), textAlign: TextAlign.start, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyStrong),
                      const DsGap(DsSpace.xxs),
                      Row(
                        children: [
                          SvgPicture.asset("assets/icons/ic_star.svg", width: 13, height: 13, colorFilter: ColorFilter.mode(c.brandStrong, BlendMode.srcIn)),
                          const DsGap(DsSpace.xs),
                          Flexible(
                            child: Text(
                              "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount.toString(), reviewSum: vendorModel.reviewsSum.toString())} (${vendorModel.reviewsCount!.toStringAsFixed(0)})",
                              textAlign: TextAlign.start,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.caption.tabular,
                            ),
                          ),
                          if (vendorModel.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true) ...[
                            const DsGap(DsSpace.sm),
                            SvgPicture.asset("assets/icons/ic_free_delivery.svg", width: 13, height: 13, colorFilter: ColorFilter.mode(c.successStrong, BlendMode.srcIn)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class BannerView extends StatelessWidget {
  final FoodHomeController controller;

  const BannerView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
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
              return _BannerTile(
                bannerModel: bannerModel,
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
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(controller.bannerModel.length, (index) {
              return Obx(() => _BannerDot(active: controller.currentPage.value == index));
            }),
          ),
        ),
      ],
    );
  }
}

class BannerBottomView extends StatelessWidget {
  final FoodHomeController controller;

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
              return _BannerTile(
                bannerModel: bannerModel,
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
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(controller.bannerBottomModel.length, (index) {
              return Obx(() => _BannerDot(active: controller.currentBottomPage.value == index));
            }),
          ),
        ),
      ],
    );
  }
}

class _BannerTile extends StatelessWidget {
  final BannerModel bannerModel;
  final VoidCallback onTap;
  const _BannerTile({required this.bannerModel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: DsSpace.lg),
      child: DsPressable(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: DsRadius.brLg, boxShadow: DsShadows.sm(context)),
          child: ClipRRect(borderRadius: DsRadius.brLg, child: NetworkImageWidget(imageUrl: bannerModel.photo.toString(), fit: BoxFit.cover)),
        ),
      ),
    );
  }
}

class _BannerDot extends StatelessWidget {
  final bool active;
  const _BannerDot({required this.active});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return AnimatedContainer(
      duration: DsMotion.of(context, DsMotion.fast),
      curve: DsMotion.emphasized,
      margin: const EdgeInsets.only(right: DsSpace.xs),
      height: 7,
      width: active ? 20 : 7,
      decoration: BoxDecoration(borderRadius: DsRadius.brPill, color: active ? c.brand : c.borderStrong),
    );
  }
}

/// Circular category rail.
class CategoryView extends StatelessWidget {
  final FoodHomeController controller;

  const CategoryView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return SizedBox(
      height: 116,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        itemCount: controller.vendorCategoryModel.length,
        itemBuilder: (context, index) {
          VendorCategoryModel vendorCategoryModel = controller.vendorCategoryModel[index];
          return DsFadeSlideIn(
            index: index,
            offset: const Offset(16, 0),
            child: Semantics(
              button: true,
              label: '${vendorCategoryModel.title}',
              child: InkWell(
                onTap: () {
                  Get.to(const CategoryRestaurantScreen(), arguments: {"vendorCategoryModel": vendorCategoryModel, "dineIn": false});
                },
                borderRadius: DsRadius.brMd,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.xs, vertical: DsSpace.xxs),
                  child: SizedBox(
                    width: 82,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: c.brandSoft, border: Border.all(color: c.border)),
                          child: ClipOval(child: NetworkImageWidget(imageUrl: vendorCategoryModel.photo.toString(), fit: BoxFit.cover)),
                        ),
                        const DsGap(DsSpace.sm),
                        Flexible(
                          child: Text('${vendorCategoryModel.title}', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.labelSm.withColor(c.textPrimary)),
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
    );
  }
}

/// Story rail: tall thumbnails with the store identity over a scrim.
class StoryView extends StatelessWidget {
  final FoodHomeController controller;

  const StoryView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 186,
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
                          child: _StoryVendorTag(vendorId: storyModel.vendorID.toString()),
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
    );
  }
}

class _StoryVendorTag extends StatelessWidget {
  final String vendorId;
  const _StoryVendorTag({required this.vendorId});

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
                              "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount.toString(), reviewSum: vendorModel.reviewsSum!.toStringAsFixed(0))} reviews",
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

/// Map mode: the map stays edge-to-edge and untouched; the store carousel
/// floating above it is restyled as DS cards.
class MapView extends StatelessWidget {
  const MapView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: MapViewController(),
      builder: (controller) {
        return Stack(
          children: [
            Constant.selectedMapType == "osm"
                ? flutterMap.FlutterMap(
                  mapController: controller.osmMapController,
                  options: flutterMap.MapOptions(
                    initialCenter: location.LatLng(Constant.selectedLocation.location!.latitude ?? 0.0, Constant.selectedLocation.location!.longitude ?? 0.0),
                    initialZoom: 10,
                  ),
                  children: [
                    flutterMap.TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.spideli.customer'),
                    flutterMap.MarkerLayer(markers: controller.osmMarker),
                  ],
                )
                : GoogleMap(
                  mapType: MapType.terrain,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  markers: Set<Marker>.of(controller.markers.values),
                  onMapCreated: (GoogleMapController mapController) {
                    controller.mapController = mapController;
                  },
                  mapToolbarEnabled: true,
                  initialCameraPosition: CameraPosition(
                    zoom: 18,
                    target:
                        controller.homeController.allNearestRestaurant.isEmpty
                            ? LatLng(Constant.selectedLocation.location!.latitude ?? 45.521563, Constant.selectedLocation.location!.longitude ?? -122.677433)
                            : LatLng(controller.homeController.allNearestRestaurant.first.latitude ?? 45.521563, controller.homeController.allNearestRestaurant.first.longitude ?? -122.677433),
                  ),
                ),
            controller.homeController.allNearestRestaurant.isEmpty
                ? Container()
                : Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 80),
                    child: SizedBox(
                      height: 236,
                      child: PageView.builder(
                        pageSnapping: true,
                        controller: PageController(viewportFraction: 0.88),
                        onPageChanged: (value) async {
                          if (Constant.selectedMapType == "osm") {
                            controller.osmMapController.move(
                              location.LatLng(controller.homeController.allNearestRestaurant[value].latitude!, controller.homeController.allNearestRestaurant[value].longitude!),
                              16,
                            );
                          } else {
                            CameraUpdate cameraUpdate = CameraUpdate.newCameraPosition(
                              CameraPosition(
                                zoom: 18,
                                target: LatLng(controller.homeController.allNearestRestaurant[value].latitude!, controller.homeController.allNearestRestaurant[value].longitude!),
                              ),
                            );
                            controller.mapController!.animateCamera(cameraUpdate);
                          }
                        },
                        itemCount: controller.homeController.allNearestRestaurant.length,
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          VendorModel vendorModel = controller.homeController.allNearestRestaurant[index];
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: DsSpace.sm, horizontal: index == 0 ? 0 : DsSpace.sm),
                            child: DsCard(
                              padding: EdgeInsets.zero,
                              clipBehavior: Clip.antiAlias,
                              semanticLabel: vendorModel.title.toString(),
                              onTap: () {
                                Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel})?.then((v) {
                                  controller.homeController.getFavouriteRestaurant();
                                });
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomCenter,
                                    children: [
                                      NetworkImageWidget(imageUrl: vendorModel.photo.toString(), fit: BoxFit.cover, height: 120, width: double.infinity),
                                      const Positioned.fill(child: StoreMediaScrim(height: double.infinity)),
                                      Positioned(
                                        right: DsSpace.xs,
                                        top: DsSpace.xs,
                                        child: Obx(
                                          () => StoreFavouriteButton(
                                            onMedia: true,
                                            isFavourite: controller.homeController.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty,
                                            onTap: () async {
                                              if (controller.homeController.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty) {
                                                FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                                                controller.homeController.favouriteList.removeWhere((item) => item.restaurantId == vendorModel.id);
                                                await FireStoreUtils.removeFavouriteRestaurant(favouriteModel);
                                              } else {
                                                FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                                                controller.homeController.favouriteList.add(favouriteModel);
                                                await FireStoreUtils.setFavouriteRestaurant(favouriteModel);
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: DsSpace.sm,
                                        right: DsSpace.sm,
                                        bottom: DsSpace.sm,
                                        child: StoreMetaChips(
                                          vendorModel: vendorModel,
                                          showFreeDelivery: vendorModel.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true,
                                          small: true,
                                          alignment: WrapAlignment.end,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(DsSpace.md),
                                    child: StoreTitleBlock(vendorModel: vendorModel, compact: true),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

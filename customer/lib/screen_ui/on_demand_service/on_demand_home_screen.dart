import 'package:customer/utils/region_service.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/banner_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/screen_ui/location_enable_screens/address_list_screen.dart';
import 'package:customer/screen_ui/location_enable_screens/location_permission_screen.dart';
import 'package:customer/screen_ui/on_demand_service/view_all_popular_service_screen.dart';
import 'package:customer/screen_ui/on_demand_service/view_category_service_screen.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/widget/osm_map/map_picker_page.dart';
import 'package:customer/widget/place_picker/location_picker_screen.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../../controllers/on_demand_home_controller.dart';
import '../../models/category_model.dart';
import '../../models/provider_serivce_model.dart';
import 'on_demand_category_screen.dart';
import 'on_demand_details_screen.dart';

/// Archetype A – service home. Gradient hero (greeting + delivery address),
/// an overlapping category rail card, a banner carousel and the popular
/// services rail.
class OnDemandHomeScreen extends StatelessWidget {
  const OnDemandHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<OnDemandHomeController>(
      init: OnDemandHomeController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final l = context.dsLayout;

        final bool isLoading = controller.isLoading.value;
        final bool noZone = Constant.isZoneAvailable == false || controller.providerList.isEmpty;
        final List<CategoryModel> categories = controller.categories.toList();
        final List<BannerModel> banners = controller.bannerTopHome.toList();
        final List<ProviderServiceModel> providers = controller.providerList.toList();

        final List<Widget> slivers;
        if (isLoading) {
          slivers = const [
            DsSliverResponsive(sliver: SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: DsSpace.xl), child: DsSkeletonDashboard(tiles: 2))), top: DsSpace.lg),
          ];
        } else if (noZone) {
          slivers = [
            DsSliverResponsive(
              top: DsSpace.xxxl,
              sliver: SliverToBoxAdapter(
                child: DsEmptyState(
                  illustration: Image.asset("assets/images/location.gif", height: 120),
                  title: "No Store Found in Your Area".tr,
                  message: "Currently, there are no available store in your zone. Try changing your location to find nearby options.".tr,
                  actionLabel: "Change Zone".tr,
                  actionIcon: Icons.my_location_rounded,
                  onAction: () async {
                    Get.offAll(const LocationPermissionScreen());
                  },
                ),
              ),
            ),
          ];
        } else {
          slivers = [
            DsSliverResponsive(
              maxWidth: DsLayout.wideMax,
              top: DsSpace.xl,
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: DsFadeSlideIn.stagger([
                    if (banners.isNotEmpty) BannerView(bannerList: banners),
                    DsSectionHeader(
                      title: "Most Popular services".tr,
                      subtitle: "${providers.length} ${'services near you'.tr}",
                      actionLabel: "View all".tr,
                      onAction: () {
                        Get.to(() => ViewAllPopularServiceScreen());
                      },
                    ),
                  ]),
                ),
              ),
            ),
            if (providers.isEmpty)
              DsSliverResponsive(
                sliver: SliverToBoxAdapter(child: DsEmptyState(compact: true, icon: Icons.handyman_outlined, title: "No Services Found".tr)),
              )
            else
              DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                bottom: DsSpace.xl,
                sliver: SliverList.builder(
                  itemCount: providers.length >= 6 ? 6 : providers.length,
                  itemBuilder: (_, index) {
                    return DsFadeSlideIn(index: index, child: ServiceView(provider: providers[index], controller: controller));
                  },
                ),
              ),
          ];
        }

        return DsScaffold.hero(
          onBack: () => Get.offAll(const ServiceListScreen()),
          onRefresh: controller.getData,
          hero: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Hello".tr, style: DsTypography.caption.copyWith(color: Colors.white70)),
                        const DsGap(DsSpace.xxs),
                        Constant.userModel == null
                            ? InkWell(
                              onTap: () => Get.offAll(const LoginScreen()),
                              child: Text("Login".tr, style: DsTypography.title.copyWith(color: Colors.white)),
                            )
                            : Text(Constant.userModel!.fullName(), maxLines: 1, overflow: TextOverflow.ellipsis, style: DsTypography.title.copyWith(color: Colors.white)),
                      ],
                    ),
                  ),
                  DsIconWell(icon: DsSection.onDemand.icon, size: 44, circle: true, onBrand: true),
                ],
              ),
              const DsGap(DsSpace.lg),
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
          heroOverlap:
              isLoading || noZone
                  ? null
                  : DsCard(
                    padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                    child:
                        categories.isEmpty
                            ? Padding(padding: const EdgeInsets.all(DsSpace.sm), child: Constant.showEmptyView(message: "No Categories".tr))
                            : Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 96,
                                    child: ListView.builder(
                                      itemCount: categories.length > 3 ? 3 : categories.length,
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.xs),
                                      itemBuilder: (context, index) {
                                        final category = categories[index];
                                        return InkWell(
                                          borderRadius: DsRadius.brMd,
                                          onTap: () {
                                            Get.to(() => ViewCategoryServiceListScreen(), arguments: {'categoryId': category.id, 'categoryTitle': category.title});
                                          },
                                          child: CategoryView(category: category, index: index),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                if (categories.length > 3)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm),
                                    child: InkWell(
                                      borderRadius: DsRadius.brMd,
                                      onTap: () {
                                        Get.to(() => const OnDemandCategoryScreen());
                                      },
                                      child: Semantics(
                                        button: true,
                                        label: "View All".tr,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(shape: BoxShape.circle, color: c.brandSoft),
                                              child: Icon(Icons.chevron_right_rounded, color: c.brandStrong),
                                            ),
                                            const DsGap(DsSpace.xs),
                                            SizedBox(width: 64, child: Text("View All".tr, textAlign: TextAlign.center, maxLines: 1, style: t.labelSm.withColor(c.textPrimary))),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                  ),
          slivers: [
            if (!isLoading && !noZone && l.isWide) DsGap.sliver(DsSpace.sm),
            ...slivers,
          ],
        );
      },
    );
  }

  /// Address picker – behaviour moved verbatim from the old header row.
  Future<void> _pickAddress(BuildContext context, OnDemandHomeController controller) async {
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

/// Swipeable banner rail with a progress-bar style indicator.
class BannerView extends StatelessWidget {
  final List<BannerModel> bannerList;
  final RxInt currentPage = 0.obs;
  final ScrollController scrollController = ScrollController();

  BannerView({super.key, required this.bannerList});

  void onScroll(BuildContext context) {
    if (scrollController.hasClients && bannerList.isNotEmpty) {
      final screenWidth = MediaQuery.of(context).size.width;
      final itemWidth = screenWidth * 0.8 + 10; // banner width + spacing
      final offset = scrollController.offset;
      final index = (offset / itemWidth).round();

      if (index != currentPage.value && index < bannerList.length) {
        currentPage.value = index;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    scrollController.addListener(() {
      onScroll(context);
    });

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: ListView.separated(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: bannerList.length,
            separatorBuilder: (context, index) => const SizedBox(width: 15),
            itemBuilder: (context, index) {
              final banner = bannerList[index];
              return SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: DsImage(url: banner.photo ?? '', radius: DsRadius.lg, fit: BoxFit.cover),
              );
            },
          ),
        ),
        const DsGap(DsSpace.md),
        Obx(() {
          return Row(
            children: List.generate(bannerList.length, (index) {
              bool isSelected = currentPage.value == index;
              return Expanded(
                child: AnimatedContainer(
                  duration: DsMotion.of(context, DsMotion.fast),
                  margin: const EdgeInsets.symmetric(horizontal: DsSpace.xxs),
                  height: 4,
                  decoration: BoxDecoration(color: isSelected ? c.brand : c.border, borderRadius: DsRadius.brPill),
                ),
              );
            }),
          );
        }),
      ],
    );
  }
}

/// Circular category tile used by the home category rail.
class CategoryView extends StatelessWidget {
  final CategoryModel category;
  final int index;

  const CategoryView({super.key, required this.category, required this.index});

  static const List<DsTone> _tones = [DsTone.brand, DsTone.info, DsTone.success, DsTone.warning];

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final tone = c.tone(_tones[index % _tones.length]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 52,
            width: 52,
            padding: const EdgeInsets.all(DsSpace.md),
            decoration: BoxDecoration(color: tone.soft, shape: BoxShape.circle),
            child: DsImage(url: category.image.toString(), radius: 0, fit: BoxFit.contain, errorIcon: Icons.category_outlined),
          ),
          const DsGap(DsSpace.xs),
          SizedBox(
            width: 64,
            child: Text(category.title ?? "", textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSm.withColor(c.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// Service row shared by the home, category, popular and provider screens.
class ServiceView extends StatelessWidget {
  final ProviderServiceModel provider;
  final OnDemandHomeController? controller;

  const ServiceView({super.key, required this.provider, this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    double rating = 0;
    if (provider.reviewsCount != null && provider.reviewsCount != 0) {
      rating = (provider.reviewsSum ?? 0) / (provider.reviewsCount ?? 1);
    }

    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: EdgeInsets.zero,
      semanticLabel: provider.title ?? "",
      onTap: () {
        Get.to(() => OnDemandDetailsScreen(), arguments: {'providerModel': provider});
      },
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Left Image ---
            SizedBox(
              width: 118,
              child: DsImage(
                url: provider.photos.isNotEmpty ? provider.photos[0] : Constant.placeHolderImage,
                radius: 0,
                fit: BoxFit.cover,
                heroTag: 'service_${provider.id}',
              ),
            ),

            // --- Right Content ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.md, DsSpace.sm, DsSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title + Favourite icon
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(provider.title ?? "", maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSm)),
                        if (controller != null)
                          Obx(() {
                            final bool fav = controller!.lstFav.where((element) => element.service_id == provider.id).isNotEmpty;
                            return DsIconButton(
                              icon: fav ? Icons.favorite : Icons.favorite_border,
                              semanticLabel: 'Favourites'.tr,
                              size: 36,
                              color: fav ? c.brandStrong : c.textMuted,
                              onPressed: () => controller!.toggleFavourite(provider),
                            );
                          }),
                      ],
                    ),

                    // Category
                    if (controller != null)
                      FutureBuilder<CategoryModel?>(
                        future: controller!.getCategory(provider.categoryId ?? ""),
                        builder: (ctx, snap) {
                          if (!snap.hasData) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: DsSpace.xxs),
                            child: Text(snap.data?.title ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm),
                          );
                        },
                      ),

                    const DsGap(DsSpace.sm),

                    Row(
                      children: [
                        Expanded(child: _buildPrice(context)),
                        DsBadge(label: rating.toStringAsFixed(1), tone: DsTone.warning, icon: Icons.star_rounded, small: true),
                      ],
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

  Widget _buildPrice(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    if (provider.disPrice == "" || provider.disPrice == "0") {
      return Text(
        provider.priceUnit == 'Fixed' ? Constant.amountShow(amount: provider.price, currency: RegionService.currencyForService(regionId: provider.regionId)) : '${Constant.amountShow(amount: provider.price ?? "0", currency: RegionService.currencyForService(regionId: provider.regionId))}/${'hr'.tr}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.titleSm.withColor(c.brandStrong).tabular,
      );
    } else {
      return Row(
        children: [
          Flexible(
            child: Text(
              provider.priceUnit == 'Fixed' ? Constant.amountShow(amount: provider.disPrice ?? '0', currency: RegionService.currencyForService(regionId: provider.regionId)) : '${Constant.amountShow(amount: provider.disPrice, currency: RegionService.currencyForService(regionId: provider.regionId))}/${'hr'.tr}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.titleSm.withColor(c.brandStrong).tabular,
            ),
          ),
          const DsGap(DsSpace.xs),
          Flexible(
            child: Text(
              provider.priceUnit == 'Fixed' ? Constant.amountShow(amount: provider.price, currency: RegionService.currencyForService(regionId: provider.regionId)) : '${Constant.amountShow(amount: provider.price ?? "0", currency: RegionService.currencyForService(regionId: provider.regionId))}/hr',
              style: t.bodySm.strike.tabular,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
  }
}

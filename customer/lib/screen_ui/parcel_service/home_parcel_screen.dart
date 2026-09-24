import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../../controllers/home_parcel_controller.dart';
import '../../models/banner_model.dart';
import '../../models/parcel_category.dart';
import '../../models/user_model.dart';
import '../../themes/show_toast_dialog.dart';
import '../../widget/osm_map/map_picker_page.dart';
import '../../widget/place_picker/location_picker_screen.dart';
import '../../widget/place_picker/selected_location_model.dart';
import '../auth_screens/login_screen.dart';
import '../location_enable_screens/address_list_screen.dart';
import 'book_parcel_screen.dart';
import 'parcel_tracking_screen.dart';

/// Parcel home (archetype A — service home): a green gradient hero carrying the
/// greeting and the pickup address, an overlapping "Track a parcel" scan card,
/// then the promo rail and the "What are you sending?" category grid.
class HomeParcelScreen extends StatelessWidget {
  const HomeParcelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<HomeParcelController>(
      init: HomeParcelController(),
      builder: (controller) {
        final bool loading = controller.isLoading.value;
        final List<BannerModel> banners = controller.bannerTopHome.toList();
        final List<ParcelCategory> categories = controller.parcelCategory.toList();
        return DsScaffold.hero(
          onBack: () {
            Get.offAll(const ServiceListScreen());
          },
          hero: const _ParcelHero(),
          heroOverlap: const _TrackParcelCard(),
          slivers: [
            if (loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: DsSpace.xxl),
                  child: DsSkeletonDashboard(tiles: 4),
                ),
              )
            else
              DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                top: DsSpace.xl,
                bottom: DsSpace.xxl,
                sliver: SliverList.list(
                  children: DsFadeSlideIn.stagger([
                    if (banners.isNotEmpty) BannerView(bannerList: banners),
                    _CategoryBlock(categories: categories),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Greeting (or "Login") plus the delivery address, on the gradient.
class _ParcelHero extends StatelessWidget {
  const _ParcelHero();

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Constant.userModel == null
            ? InkWell(
                borderRadius: DsRadius.brXs,
                onTap: () {
                  Get.offAll(const LoginScreen());
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Login".tr, style: t.labelSm.withColor(Colors.white)),
                      const DsGap(DsSpace.xs),
                      const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                    ],
                  ),
                ),
              )
            : Text(Constant.userModel!.fullName(), style: t.labelSm.withColor(Colors.white.withValues(alpha: 0.88))),
        const DsGap(DsSpace.xs),
        InkWell(
          borderRadius: DsRadius.brSm,
          onTap: () async {
            if (Constant.userModel != null) {
              Get.to(AddressListScreen())!.then((value) {
                if (value != null) {
                  ShippingAddress shippingAddress = value;
                  Constant.selectedLocation = shippingAddress;
                }
              });
            } else {
              Constant.checkPermission(
                onTap: () async {
                  ShowToastDialog.showLoader("Please wait...".tr);

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
                        Get.back();
                      }
                    } else {
                      Get.to(LocationPickerScreen())!.then((value) async {
                        if (value != null) {
                          SelectedLocationModel selectedLocationModel = value;

                          shippingAddress.addressAs = "Home";
                          shippingAddress.location = UserLocation(latitude: selectedLocationModel.latLng!.latitude, longitude: selectedLocationModel.latLng!.longitude);
                          shippingAddress.locality = "Picked from Map";

                          Constant.selectedLocation = shippingAddress;
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
                  }
                },
                context: context,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.location_on_rounded, size: 18, color: Colors.white),
                ),
                const DsGap(DsSpace.sm),
                Expanded(
                  child: Text(Constant.selectedLocation.getFullAddress(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.headline.withColor(Colors.white)),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.expand_more_rounded, size: 20, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Spec 7.5: Track > scan QR / enter number. The overlapping hero card.
class _TrackParcelCard extends StatelessWidget {
  const _TrackParcelCard();

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard(
      padding: const EdgeInsets.all(DsSpace.lg),
      onTap: () => Get.to(() => const ParcelTrackingScreen()),
      semanticLabel: "Track a parcel".tr,
      child: Row(
        children: [
          const DsIconWell(icon: Icons.qr_code_scanner_rounded, size: 48),
          const DsGap(DsSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Track a parcel".tr, style: t.titleSm),
                const DsGap(DsSpace.xxs),
                Text("Scan the QR code or enter the tracking number".tr, style: t.bodySm),
              ],
            ),
          ),
          const DsGap(DsSpace.sm),
          Icon(Icons.arrow_forward_ios_rounded, size: 16, color: c.textMuted),
        ],
      ),
    );
  }
}

/// "What are you sending?" — the parcel categories as a tile grid.
class _CategoryBlock extends StatelessWidget {
  final List<ParcelCategory> categories;

  const _CategoryBlock({required this.categories});

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: DsSpace.xl),
        child: DsEmptyState(compact: true, icon: Icons.inventory_2_outlined, title: "What are you sending?".tr),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionHeader(title: "What are you sending?".tr, icon: Icons.local_shipping_outlined),
        DsAdaptiveGrid(
          minItemWidth: 160,
          children: [for (final item in categories) _CategoryTile(item: item)],
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final ParcelCategory item;

  const _CategoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      padding: const EdgeInsets.all(DsSpace.lg),
      semanticLabel: item.title ?? '',
      onTap: () {
        if (Constant.userModel == null) {
          Get.to(const LoginScreen());
        } else {
          Get.to(const BookParcelScreen(), arguments: {'parcelCategory': item});
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.brandSoft, borderRadius: DsRadius.brMd),
            child: DsImage(url: item.image ?? '', height: 32, width: 32, fit: BoxFit.contain, radius: DsRadius.xs, errorIcon: Icons.inventory_2_outlined),
          ),
          const DsGap(DsSpace.lg),
          Text(item.title ?? '', style: t.titleSm),
          const DsGap(DsSpace.xs),
          Row(
            children: [
              Text("Send now".tr, style: t.labelSm.withColor(c.brandStrong)),
              const DsGap(DsSpace.xs),
              Icon(Icons.arrow_forward_rounded, size: 14, color: c.brandStrong),
            ],
          ),
        ],
      ),
    );
  }
}

/// Promotional banner rail with a progress-style page indicator.
class BannerView extends StatefulWidget {
  final List<BannerModel> bannerList;

  const BannerView({super.key, required this.bannerList});

  @override
  State<BannerView> createState() => _BannerViewState();
}

class _BannerViewState extends State<BannerView> {
  final RxInt currentPage = 0.obs;
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.dispose();
  }

  /// Computes the visible item index from scroll offset
  void _onScroll() {
    if (scrollController.hasClients && widget.bannerList.isNotEmpty) {
      final screenWidth = MediaQuery.of(context).size.width;
      final itemWidth = screenWidth * 0.8 + 10; // banner width + spacing
      final offset = scrollController.offset;
      final index = (offset / itemWidth).round();

      if (index != currentPage.value && index < widget.bannerList.length) {
        currentPage.value = index;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l = context.dsLayout;
    if (widget.bannerList.isEmpty) return const SizedBox();
    final double bannerWidth = (MediaQuery.sizeOf(context).width * 0.8).clamp(240.0, 520.0);
    return Column(
      children: [
        SizedBox(
          height: l.value(phone: 150.0, tablet: 200.0),
          child: ListView.separated(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: widget.bannerList.length,
            separatorBuilder: (context, index) => const DsGap(DsSpace.lg),
            itemBuilder: (context, index) {
              final banner = widget.bannerList[index];
              return DsFadeSlideIn(
                index: index,
                child: SizedBox(
                  width: bannerWidth,
                  child: DsImage(url: banner.photo ?? '', radius: DsRadius.lg, fit: BoxFit.cover),
                ),
              );
            },
          ),
        ),
        const DsGap(DsSpace.md),
        Obx(() {
          return Row(
            children: List.generate(widget.bannerList.length, (index) {
              final bool isSelected = currentPage.value == index;
              return Expanded(
                child: AnimatedContainer(
                  duration: DsMotion.of(context, DsMotion.base),
                  curve: DsMotion.emphasized,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(color: isSelected ? c.brand : c.surfaceAlt, borderRadius: DsRadius.brPill),
                ),
              );
            }),
          );
        }),
      ],
    );
  }
}

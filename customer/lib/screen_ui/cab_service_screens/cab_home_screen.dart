import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cab_home_controller.dart';
import 'package:customer/models/banner_model.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'intercity_home_screen.dart';
import 'cab_booking_screen.dart';

/// Cab home (archetype A — service home): a brand-gradient hero with the
/// greeting and pickup address, an overlapping "Where are you going?" card
/// holding the Ride / Intercity choices, then the banner rail and the
/// driver-verification block.
class CabHomeScreen extends StatelessWidget {
  const CabHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: CabHomeController(),
      builder: (controller) {
        final loading = controller.isLoading.value;
        return DsScaffold.hero(
          onBack: () {
            Get.offAll(const ServiceListScreen());
          },
          hero: const _HomeHero(),
          heroOverlap: const _RideModePicker(),
          slivers: [
            if (loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: DsSpace.xxl),
                  child: DsSkeletonDashboard(tiles: 2),
                ),
              )
            else
              DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                top: DsSpace.xl,
                bottom: DsSpace.xxl,
                sliver: SliverList.list(children: DsFadeSlideIn.stagger([BannerView(bannerList: controller.bannerTopHome), const _SafetyBlock()])),
              ),
          ],
        );
      },
    );
  }
}

/// Greeting (or "Login") plus the current pickup address, on the gradient.
class _HomeHero extends StatelessWidget {
  const _HomeHero();

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Constant.userModel == null
            ? InkWell(
                onTap: () {
                  Get.offAll(const LoginScreen());
                },
                borderRadius: DsRadius.brXs,
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
        Row(
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
          ],
        ),
      ],
    );
  }
}

/// The overlapping card with the two ride modes the section allows.
class _RideModePicker extends StatelessWidget {
  const _RideModePicker();

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    final showRide = Constant.sectionConstantModel!.rideType == "both" || Constant.sectionConstantModel!.rideType == "ride";
    final showIntercity = Constant.sectionConstantModel!.rideType == "both" || Constant.sectionConstantModel!.rideType == "intercity";
    return DsCard(
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Where are you going for?".tr, style: t.titleSm),
          const DsGap(DsSpace.md),
          DsAdaptiveGrid(
            minItemWidth: 150,
            maxColumns: 2,
            children: [
              if (showRide)
                _RideModeTile(
                  asset: "assets/icons/ic_ride.svg",
                  title: "Ride".tr,
                  subtitle: "City rides, 24x7 availability".tr,
                  tone: DsTone.brand,
                  onTap: () {
                    Get.to(() => CabBookingScreen());
                  },
                ),
              if (showIntercity)
                _RideModeTile(
                  asset: "assets/icons/ic_intercity.svg",
                  title: "Intercity/Outstation".tr,
                  subtitle: "Long trips, prepaid options".tr,
                  tone: DsTone.info,
                  onTap: () {
                    Get.to(() => IntercityHomeScreen());
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RideModeTile extends StatelessWidget {
  final String asset;
  final String title;
  final String subtitle;
  final DsTone tone;
  final VoidCallback onTap;

  const _RideModeTile({required this.asset, required this.title, required this.subtitle, required this.tone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final accent = c.tone(tone);
    return DsCard.outlined(
      onTap: onTap,
      semanticLabel: title,
      color: accent.soft,
      borderColor: accent.main.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(asset, height: 38, width: 38),
          const DsGap(DsSpace.lg),
          Text(title, style: t.titleSm.withColor(accent.strong)),
          const DsGap(DsSpace.xxs),
          Text(subtitle, style: t.bodySm.withColor(c.textSecondary)),
        ],
      ),
    );
  }
}

/// "Every Ride. Every Driver. Verified." trust block.
class _SafetyBlock extends StatelessWidget {
  const _SafetyBlock();

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.xl),
      child: DsCard.tinted(
        tone: DsTone.success,
        padding: const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.xl, DsSpace.sm, DsSpace.xl),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_user_rounded, size: 18, color: context.dsColors.successStrong),
                      const DsGap(DsSpace.sm),
                      Text("Verified".tr.toUpperCase(), style: t.overline.withColor(context.dsColors.successStrong)),
                    ],
                  ),
                  const DsGap(DsSpace.sm),
                  Text("Every Ride. Every Driver. Verified.".tr, style: t.headline),
                  const DsGap(DsSpace.xs),
                  Text("All drivers go through ID checks and background verification for your safety.".tr, style: t.bodySecondary),
                ],
              ),
            ),
            const DsGap(DsSpace.sm),
            Expanded(child: Image.asset("assets/images/img_ride_driver.png", height: 118, fit: BoxFit.contain)),
          ],
        ),
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
    final bannerWidth = (MediaQuery.sizeOf(context).width * 0.8).clamp(240.0, 520.0);
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AnimatedContainer(
                    duration: DsMotion.of(context, DsMotion.base),
                    curve: DsMotion.standard,
                    height: 4,
                    decoration: BoxDecoration(color: isSelected ? c.brand : c.surfaceAlt, borderRadius: DsRadius.brPill),
                  ),
                ),
              );
            }),
          );
        }),
      ],
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:customer/constant/constant.dart';
import 'package:customer/models/section_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/screen_ui/location_enable_screens/address_list_screen.dart';
import 'package:customer/screen_ui/service_home_screen/more_services_sheet.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/home_services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/service_list_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../utils/network_image_widget.dart';

/// Customer home (spec 7.1, client mock-up): header with the Spideli logo and
/// the delivery location, top banner carousel, the 8 favourite services on a
/// circle around a round "More" button, then the lower banners (one full
/// width, the rest in a grid). "More" opens the full services panel (7.2).
///
/// Archetype A — service launcher. The chrome is deliberately neutral: this
/// screen is also shown *after* leaving a service, when `c.brand` still holds
/// that service's colour, so every tile is coloured from its own
/// `SectionModel.color` via [DsAccentScope].
class ServiceListScreen extends StatelessWidget {
  const ServiceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return GetX(
      init: ServiceListController(),
      builder: (controller) {
        final bool isDark = themeController.isDark.value;
        final c = context.dsColors;
        return Scaffold(
          backgroundColor: c.background,
          body: controller.isLoading.value
              ? const _HomeSkeleton()
              : RefreshIndicator(
                  onRefresh: controller.loadData,
                  color: c.brand,
                  backgroundColor: c.surface,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.only(bottom: DsSpace.xxxl),
                    children: [
                      _HomeHeader(controller: controller, isDark: isDark),
                      if (controller.topBanners.isNotEmpty) ...[
                        const DsGap(DsSpace.lg),
                        _TopBannerCarousel(banners: controller.topBanners.toList(), onTap: (b) => controller.onBannerTap(context, b), isDark: isDark),
                      ],
                      const DsGap(DsSpace.xl),
                      DsResponsive(
                        maxWidth: DsLayout.contentMax,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: context.dsLayout.gutter),
                          child: ServiceCircle(
                            services: controller.favouriteList.toList(),
                            isDark: isDark,
                            onServiceTap: (section) => controller.onServiceTap(context, section),
                            onMoreTap: () => MoreServicesSheet.show(context, controller: controller, isDark: isDark),
                          ),
                        ),
                      ),
                      if (controller.lowerBanners.isNotEmpty) ...[
                        const DsGap(DsSpace.xl),
                        _LowerBanners(banners: controller.lowerBanners.toList(), onTap: (b) => controller.onBannerTap(context, b)),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}

/// Brand-neutral loading state for the launcher: logo bar, banner, ring.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final l = context.dsLayout;
    return SafeArea(
      child: DsShimmer(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: l.gutter, vertical: DsSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DsSkeleton.box(width: 44, height: 44, radius: DsRadius.md),
                  const DsGap(DsSpace.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [DsSkeleton.line(width: 110), const DsGap(DsSpace.sm), DsSkeleton.line(width: 170, height: 10)],
                  ),
                ],
              ),
              const DsGap(DsSpace.xxl),
              DsSkeleton.box(height: 160, radius: DsRadius.lg),
              const DsGap(DsSpace.xxxl),
              Center(child: DsSkeleton.circle(size: 300)),
              const DsGap(DsSpace.xxxl),
              DsSkeleton.box(height: 150, radius: DsRadius.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final ServiceListController controller;
  final bool isDark;

  const _HomeHeader({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    final l = context.dsLayout;
    final String address = Constant.selectedLocation.getFullAddress().trim();
    return Container(
      decoration: BoxDecoration(gradient: DsGradients.brand(context)),
      child: SafeArea(
        bottom: false,
        child: DsResponsive(
          maxWidth: DsLayout.contentMax,
          child: Padding(
            padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.md, l.gutter, DsSpace.xl),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(DsSpace.xs),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: DsRadius.brMd),
                  child: ClipRRect(borderRadius: DsRadius.brSm, child: Image.asset('assets/images/ic_logo.png', height: 36, width: 36, fit: BoxFit.contain)),
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("spideli".tr, style: t.title.withColor(Colors.white).w700),
                      const DsGap(DsSpace.xxs),
                      DsPressable(
                        onTap: Constant.userModel == null ? null : () => _changeAddress(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: DsSpace.xxs),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 16, color: Colors.white),
                              const DsGap(DsSpace.xxs),
                              Flexible(
                                child: Text(
                                  address.isEmpty ? "Delivery location".tr : address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.bodySm.withColor(Colors.white.withValues(alpha: 0.92)),
                                ),
                              ),
                              if (Constant.userModel != null) const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white),
                            ],
                          ),
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
    );
  }

  /// Same address picker the section homes use. The services offered depend
  /// on the location's region, so the home reloads.
  Future<void> _changeAddress() async {
    final dynamic value = await Get.to(() => AddressListScreen());
    if (value is ShippingAddress) {
      Constant.selectedLocation = value;
      await controller.loadData();
    }
  }
}

// -----------------------------------------------------------------------------
// Circle of favourite services
// -----------------------------------------------------------------------------

/// Up to 8 services evenly spaced on a circle (first one at the top, going
/// clockwise) with a round "More" button in the centre.
class ServiceCircle extends StatelessWidget {
  final List<SectionModel> services;
  final bool isDark;
  final ValueChanged<SectionModel> onServiceTap;
  final VoidCallback onMoreTap;

  const ServiceCircle({super.key, required this.services, required this.isDark, required this.onServiceTap, required this.onMoreTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double size = math.min(constraints.maxWidth, 380);
        final double itemWidth = size * 0.25;
        final double iconSize = itemWidth * 0.62;
        final double itemHeight = iconSize + 34;
        final double radius = size / 2 - itemWidth / 2;
        final double moreSize = size * 0.28;
        final Offset center = Offset(size / 2, size / 2);
        final int count = services.length;

        return Center(
          child: SizedBox(
            width: size,
            // Room for the label of the bottom service.
            height: size + 16,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Decorative ring behind the services. Neutral, because the
                // services around it each carry their own colour.
                Positioned(
                  left: 0,
                  top: 0,
                  width: size,
                  height: size,
                  child: Padding(
                    padding: EdgeInsets.all(itemWidth / 2),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c.border, width: 1.5),
                        gradient: RadialGradient(colors: [c.surface, c.surfaceAlt.withValues(alpha: 0.7)]),
                      ),
                    ),
                  ),
                ),
                for (int i = 0; i < count; i++)
                  () {
                    final double angle = -math.pi / 2 + (2 * math.pi * i / count);
                    final Offset p = center + Offset(math.cos(angle), math.sin(angle)) * radius;
                    return Positioned(
                      left: p.dx - itemWidth / 2,
                      top: p.dy - iconSize / 2 - 4,
                      width: itemWidth,
                      height: itemHeight,
                      child: DsFadeSlideIn(
                        index: i,
                        offset: const Offset(0, 10),
                        child: ServiceBubble(section: services[i], iconSize: iconSize, isDark: isDark, onTap: () => onServiceTap(services[i])),
                      ),
                    );
                  }(),
                Positioned(
                  left: center.dx - moreSize / 2,
                  top: center.dy - moreSize / 2,
                  width: moreSize,
                  height: moreSize,
                  child: Semantics(
                    button: true,
                    label: "More".tr,
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: DsShadows.md(context)),
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: Ink(
                          decoration: BoxDecoration(shape: BoxShape.circle, gradient: DsGradients.brand(context)),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onMoreTap,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.apps_rounded, color: Colors.white, size: moreSize * 0.30),
                                const DsGap(DsSpace.xxs),
                                Text("More".tr, style: t.labelSm.withColor(Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A round service icon with its name underneath, tinted with that service's
/// own colour (never the last-opened service's brand).
class ServiceBubble extends StatelessWidget {
  final SectionModel section;
  final double iconSize;
  final bool isDark;
  final VoidCallback onTap;

  const ServiceBubble({super.key, required this.section, required this.iconSize, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final Color tint = DsColors.fromHex(section.color) ?? c.brand;
    final accent = c.accentFrom(tint);
    return DsAccentScope(
      color: tint,
      retheme: false,
      child: Semantics(
        button: true,
        label: (section.name ?? '').tr,
        child: InkWell(
          onTap: onTap,
          borderRadius: DsRadius.brMd,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.soft,
                  border: Border.all(color: tint.withValues(alpha: 0.55), width: 1.5),
                  boxShadow: DsShadows.sm(context),
                ),
                padding: EdgeInsets.all(iconSize * 0.18),
                child: ClipOval(
                  child: NetworkImageWidget(
                    imageUrl: section.sectionImage ?? '',
                    fit: BoxFit.contain,
                    showShimmer: false,
                    errorWidget: Icon(DsSection.fromServiceFlag(section.serviceTypeFlag).icon, color: accent.strong, size: iconSize * 0.4),
                  ),
                ),
              ),
              const DsGap(DsSpace.xs),
              Flexible(
                child: Text(
                  (section.name ?? '').tr,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.withColor(c.textPrimary).copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Banners
// -----------------------------------------------------------------------------

class _TopBannerCarousel extends StatefulWidget {
  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner> onTap;
  final bool isDark;

  const _TopBannerCarousel({required this.banners, required this.onTap, required this.isDark});

  @override
  State<_TopBannerCarousel> createState() => _TopBannerCarouselState();
}

class _TopBannerCarouselState extends State<_TopBannerCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!_pageController.hasClients) return;
        final int next = (_page + 1) % widget.banners.length;
        _pageController.animateToPage(next, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return DsResponsive(
      maxWidth: DsLayout.contentMax,
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.banners.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.xs),
                child: DsPressable(
                  onTap: () => widget.onTap(widget.banners[index]),
                  child: DecoratedBox(
                    decoration: BoxDecoration(borderRadius: DsRadius.brLg, boxShadow: DsShadows.sm(context)),
                    child: ClipRRect(
                      borderRadius: DsRadius.brLg,
                      child: NetworkImageWidget(imageUrl: widget.banners[index].imageUrl, fit: BoxFit.cover, width: double.infinity, height: 160),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.banners.length > 1) ...[
            const DsGap(DsSpace.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.banners.length,
                (i) => AnimatedContainer(
                  duration: DsMotion.of(context, DsMotion.fast),
                  curve: DsMotion.emphasized,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: i == _page ? 20 : 6,
                  decoration: BoxDecoration(color: i == _page ? c.brand : c.borderStrong, borderRadius: DsRadius.brPill),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One full-width banner, then the others in a two-column grid.
class _LowerBanners extends StatelessWidget {
  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner> onTap;

  const _LowerBanners({required this.banners, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = context.dsLayout;
    Widget tile(HomeBanner b, double height) => DsPressable(
      onTap: () => onTap(b),
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: DsRadius.brLg, boxShadow: DsShadows.xs(context)),
        child: ClipRRect(
          borderRadius: DsRadius.brLg,
          child: NetworkImageWidget(imageUrl: b.imageUrl, fit: BoxFit.cover, width: double.infinity, height: height),
        ),
      ),
    );
    final List<HomeBanner> rest = banners.skip(1).toList();
    return DsResponsive(
      maxWidth: DsLayout.contentMax,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: l.gutter),
        child: Column(
          children: [
            tile(banners.first, 150),
            if (rest.isNotEmpty) ...[
              const DsGap(DsSpace.md),
              GridView.builder(
                itemCount: rest.length,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: DsLayout.gridDelegate(maxItemWidth: 260, spacing: DsSpace.md, childAspectRatio: 1.4),
                itemBuilder: (context, index) => DsFadeSlideIn(index: index, child: tile(rest[index], double.infinity)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:customer/constant/constant.dart';
import 'package:customer/models/section_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/screen_ui/location_enable_screens/address_list_screen.dart';
import 'package:customer/screen_ui/service_home_screen/more_services_sheet.dart';
import 'package:customer/utils/home_services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/service_list_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../themes/app_them_data.dart';
import '../../utils/network_image_widget.dart';

/// Customer home (spec 7.1, client mock-up): header with the Spideli logo and
/// the delivery location, top banner carousel, the 8 favourite services on a
/// circle around a round "More" button, then the lower banners (one full
/// width, the rest in a grid). "More" opens the full services panel (7.2).
class ServiceListScreen extends StatelessWidget {
  const ServiceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return GetX(
      init: ServiceListController(),
      builder: (controller) {
        final bool isDark = themeController.isDark.value;
        return Scaffold(
          backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          body: SafeArea(
            child:
                controller.isLoading.value
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                      onRefresh: controller.loadData,
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          _HomeHeader(controller: controller, isDark: isDark),
                          if (controller.topBanners.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _TopBannerCarousel(banners: controller.topBanners.toList(), onTap: (b) => controller.onBannerTap(context, b), isDark: isDark),
                          ],
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ServiceCircle(
                              services: controller.favouriteList.toList(),
                              isDark: isDark,
                              onServiceTap: (section) => controller.onServiceTap(context, section),
                              onMoreTap: () => MoreServicesSheet.show(context, controller: controller, isDark: isDark),
                            ),
                          ),
                          if (controller.lowerBanners.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _LowerBanners(banners: controller.lowerBanners.toList(), onTap: (b) => controller.onBannerTap(context, b)),
                          ],
                        ],
                      ),
                    ),
          ),
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final ServiceListController controller;
  final bool isDark;

  const _HomeHeader({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final String address = Constant.selectedLocation.getFullAddress().trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/images/ic_logo.png', height: 40, width: 40, fit: BoxFit.contain)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("spideli".tr, style: AppThemeData.boldTextStyle(fontSize: 20, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
                InkWell(
                  onTap: Constant.userModel == null ? null : () => _changeAddress(),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: AppThemeData.primary300),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          address.isEmpty ? "Delivery location".tr : address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppThemeData.mediumTextStyle(fontSize: 13, color: isDark ? AppThemeData.grey300 : AppThemeData.grey700),
                        ),
                      ),
                      if (Constant.userModel != null) Icon(Icons.keyboard_arrow_down, size: 18, color: isDark ? AppThemeData.grey300 : AppThemeData.grey700),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
                // Decorative ring behind the services.
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
                        border: Border.all(color: (isDark ? AppThemeData.greyDark200 : AppThemeData.grey200), width: 1.5),
                        color: AppThemeData.primary300.withValues(alpha: isDark ? 0.06 : 0.04),
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
                      child: ServiceBubble(section: services[i], iconSize: iconSize, isDark: isDark, onTap: () => onServiceTap(services[i])),
                    );
                  }(),
                Positioned(
                  left: center.dx - moreSize / 2,
                  top: center.dy - moreSize / 2,
                  width: moreSize,
                  height: moreSize,
                  child: Material(
                    color: AppThemeData.primary300,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onMoreTap,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.apps_rounded, color: AppThemeData.surface, size: moreSize * 0.32),
                          Text("More".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: AppThemeData.surface)),
                        ],
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

/// A round service icon with its name underneath.
class ServiceBubble extends StatelessWidget {
  final SectionModel section;
  final double iconSize;
  final bool isDark;
  final VoidCallback onTap;

  const ServiceBubble({super.key, required this.section, required this.iconSize, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color tint = Color(int.tryParse(section.color?.replaceFirst("#", "0xff") ?? '') ?? AppThemeData.primary300.toARGB32());
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppThemeData.greyDark50 : AppThemeData.surface,
              border: Border.all(color: tint.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            padding: EdgeInsets.all(iconSize * 0.18),
            child: ClipOval(child: NetworkImageWidget(imageUrl: section.sectionImage ?? '', fit: BoxFit.contain, showShimmer: false)),
          ),
          const SizedBox(height: 4),
          Text(
            (section.name ?? '').tr,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppThemeData.mediumTextStyle(fontSize: 11, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
          ),
        ],
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
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder:
                (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => widget.onTap(widget.banners[index]),
                    child: ClipRRect(borderRadius: BorderRadius.circular(14), child: NetworkImageWidget(imageUrl: widget.banners[index].imageUrl, fit: BoxFit.cover, width: double.infinity, height: 160)),
                  ),
                ),
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.banners.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: i == _page ? 18 : 6,
                decoration: BoxDecoration(
                  color: i == _page ? AppThemeData.primary300 : (widget.isDark ? AppThemeData.greyDark300 : AppThemeData.grey300),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
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
    Widget tile(HomeBanner b, double height) =>
        GestureDetector(onTap: () => onTap(b), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: NetworkImageWidget(imageUrl: b.imageUrl, fit: BoxFit.cover, width: double.infinity, height: height)));
    final List<HomeBanner> rest = banners.skip(1).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          tile(banners.first, 150),
          if (rest.isNotEmpty) ...[
            const SizedBox(height: 12),
            GridView.builder(
              itemCount: rest.length,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.4),
              itemBuilder: (context, index) => tile(rest[index], double.infinity),
            ),
          ],
        ],
      ),
    );
  }
}

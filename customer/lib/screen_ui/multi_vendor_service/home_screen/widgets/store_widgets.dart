import 'package:customer/constant/constant.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/widget/restaurant_image_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

/// Small building blocks shared by the food (multi-vendor) home and its
/// list screens. They only render data — every tap handler and observable
/// read stays in the screen that owns it.

/// Rating + review-count pill. Uses the active section accent, so it reads
/// correctly in food red and in any other service colour.
class StoreRatingChip extends StatelessWidget {
  final VendorModel vendorModel;
  final bool small;
  const StoreRatingChip({super.key, required this.vendorModel, this.small = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final label =
        "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount!.toStringAsFixed(0), reviewSum: vendorModel.reviewsSum.toString())} (${vendorModel.reviewsCount!.toStringAsFixed(0)})";
    return _Pill(
      background: c.brandSoft,
      small: small,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset("assets/icons/ic_star.svg", width: small ? 12 : 14, height: small ? 12 : 14, colorFilter: ColorFilter.mode(c.brandStrong, BlendMode.srcIn)),
          const DsGap(DsSpace.xs),
          Text(label, style: (small ? t.labelSm : t.label).withColor(c.brandStrong).tabular),
        ],
      ),
    );
  }
}

/// Distance-from-you pill.
class StoreDistanceChip extends StatelessWidget {
  final VendorModel vendorModel;
  final bool small;
  const StoreDistanceChip({super.key, required this.vendorModel, this.small = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final info = c.tone(DsTone.info);
    final label =
        "${Constant.getDistance(lat1: vendorModel.latitude.toString(), lng1: vendorModel.longitude.toString(), lat2: Constant.selectedLocation.location!.latitude.toString(), lng2: Constant.selectedLocation.location!.longitude.toString())} ${Constant.distanceType}";
    return _Pill(
      background: info.soft,
      small: small,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset("assets/icons/ic_map_distance.svg", width: small ? 12 : 14, height: small ? 12 : 14, colorFilter: ColorFilter.mode(info.strong, BlendMode.srcIn)),
          const DsGap(DsSpace.xs),
          Text(label, style: (small ? t.labelSm : t.label).withColor(info.strong).tabular),
        ],
      ),
    );
  }
}

/// "Free Delivery" pill — the caller decides when it is visible.
class StoreFreeDeliveryChip extends StatelessWidget {
  final bool small;
  const StoreFreeDeliveryChip({super.key, this.small = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final ok = c.tone(DsTone.success);
    return _Pill(
      background: ok.soft,
      small: small,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset("assets/icons/ic_free_delivery.svg", width: small ? 12 : 14, height: small ? 12 : 14, colorFilter: ColorFilter.mode(ok.strong, BlendMode.srcIn)),
          const DsGap(DsSpace.xs),
          Text("Free Delivery".tr, style: (small ? t.labelSm : t.label).withColor(ok.strong)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget child;
  final Color background;
  final bool small;
  const _Pill({required this.child, required this.background, required this.small});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? DsSpace.sm : DsSpace.md, vertical: small ? 4 : 6),
      decoration: BoxDecoration(color: background, borderRadius: DsRadius.brPill),
      child: child,
    );
  }
}

/// Free delivery / rating / distance, wrapping instead of clipping at large
/// text scales.
class StoreMetaChips extends StatelessWidget {
  final VendorModel vendorModel;
  final bool showFreeDelivery;
  final bool small;
  final WrapAlignment alignment;
  const StoreMetaChips({super.key, required this.vendorModel, required this.showFreeDelivery, this.small = false, this.alignment = WrapAlignment.start});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DsSpace.sm,
      runSpacing: DsSpace.xs,
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showFreeDelivery) StoreFreeDeliveryChip(small: small),
        StoreRatingChip(vendorModel: vendorModel, small: small),
        StoreDistanceChip(vendorModel: vendorModel, small: small),
      ],
    );
  }
}

/// Heart button for a store. [isFavourite] must be read by the caller inside
/// its own `Obx`/`DsObserve` so the icon stays reactive.
class StoreFavouriteButton extends StatelessWidget {
  final bool isFavourite;
  final VoidCallback onTap;

  /// Places the button on a photo (adds a dark scrim behind it).
  final bool onMedia;
  const StoreFavouriteButton({super.key, required this.isFavourite, required this.onTap, this.onMedia = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final button = DsIconButton(
      semanticLabel: isFavourite ? "Remove from favourites".tr : "Add to favourites".tr,
      onPressed: onTap,
      child: isFavourite
          ? SvgPicture.asset("assets/icons/ic_like_fill.svg", width: 20, height: 20)
          : SvgPicture.asset("assets/icons/ic_like.svg", width: 20, height: 20, colorFilter: ColorFilter.mode(onMedia ? Colors.white : c.iconDefault, BlendMode.srcIn)),
    );
    if (!onMedia) return button;
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.32)),
      child: button,
    );
  }
}

/// Bottom-up scrim so white text and chips stay legible on store photos.
class StoreMediaScrim extends StatelessWidget {
  final double height;
  const StoreMediaScrim({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(gradient: DsGradients.imageScrim),
      ),
    );
  }
}

/// Title + location block used under or next to store media.
class StoreTitleBlock extends StatelessWidget {
  final VendorModel vendorModel;
  final bool compact;
  const StoreTitleBlock({super.key, required this.vendorModel, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(vendorModel.title.toString(), textAlign: TextAlign.start, maxLines: 1, overflow: TextOverflow.ellipsis, style: (compact ? t.titleSm : t.title).w600),
        const DsGap(DsSpace.xxs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_on_outlined, size: 15, color: c.textMuted),
            const DsGap(DsSpace.xs),
            Expanded(
              child: Text(vendorModel.location.toString(), textAlign: TextAlign.start, maxLines: compact ? 2 : 1, overflow: TextOverflow.ellipsis, style: t.bodySm),
            ),
          ],
        ),
      ],
    );
  }
}

/// Full-bleed "showcase" store card: the photo carousel is the hero, the meta
/// chips float over its bottom edge, the name sits underneath. [favourite] is
/// supplied by the caller (wrapped in its own `Obx`) so the heart stays
/// reactive without rebuilding the whole card.
class StoreShowcaseCard extends StatelessWidget {
  final VendorModel vendorModel;
  final VoidCallback onTap;
  final Widget? favourite;
  final EdgeInsetsGeometry? margin;

  /// Extra content drawn over the bottom-left of the media (e.g. "Upto x% off").
  final Widget? mediaOverlay;

  const StoreShowcaseCard({super.key, required this.vendorModel, required this.onTap, this.favourite, this.margin, this.mediaOverlay});

  @override
  Widget build(BuildContext context) {
    return DsCard(
      padding: EdgeInsets.zero,
      margin: margin ?? const EdgeInsets.only(bottom: DsSpace.xl),
      clipBehavior: Clip.antiAlias,
      semanticLabel: vendorModel.title.toString(),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              RestaurantImageView(vendorModel: vendorModel),
              const Positioned.fill(child: StoreMediaScrim(height: double.infinity)),
              if (mediaOverlay != null) Positioned(left: DsSpace.md, bottom: DsSpace.md, child: mediaOverlay!),
              if (favourite != null) Positioned(right: DsSpace.sm, top: DsSpace.sm, child: favourite!),
              Positioned(
                left: DsSpace.md,
                right: DsSpace.md,
                bottom: DsSpace.md,
                child: StoreMetaChips(
                  vendorModel: vendorModel,
                  showFreeDelivery: vendorModel.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true,
                  alignment: WrapAlignment.end,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.lg),
            child: StoreTitleBlock(vendorModel: vendorModel),
          ),
        ],
      ),
    );
  }
}

/// Empty state shown when the selected zone has no stores.
class NoStoreInZoneView extends StatelessWidget {
  final VoidCallback onChangeZone;
  const NoStoreInZoneView({super.key, required this.onChangeZone});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: context.dsLayout.gutter, vertical: DsSpace.xxl),
        child: DsResponsive(
          maxWidth: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: DsFadeSlideIn.stagger([
              Container(
                padding: const EdgeInsets.all(DsSpace.xl),
                decoration: BoxDecoration(shape: BoxShape.circle, color: c.brandSoft),
                child: Image.asset("assets/images/location.gif", height: 110),
              ),
              const DsGap(DsSpace.xxl),
              Text("No Store Found in Your Area".tr, textAlign: TextAlign.center, style: t.headline.w700),
              const DsGap(DsSpace.sm),
              Text(
                "Currently, there are no available store in your zone. Try changing your location to find nearby options.".tr,
                textAlign: TextAlign.center,
                style: t.body.withColor(c.textSecondary),
              ),
              const DsGap(DsSpace.xxl),
              DsButton.primary(label: "Change Zone".tr, icon: Icons.edit_location_alt_outlined, size: DsButtonSize.lg, onPressed: onChangeZone),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Floating list / map / scan control used by both food home variants.
class HomeToolFab extends StatelessWidget {
  final bool isListView;
  final VoidCallback onList;
  final VoidCallback onMap;
  final VoidCallback onScan;

  const HomeToolFab({super.key, required this.isListView, required this.onList, required this.onMap, required this.onScan});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      padding: const EdgeInsets.all(DsSpace.xs),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: DsRadius.brPill,
        border: Border.all(color: c.border),
        boxShadow: DsShadows.md(context),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolButton(asset: "assets/icons/ic_view_grid_list.svg", label: "List view".tr, active: isListView, onTap: onList),
          const DsGap(DsSpace.xxs),
          _ToolButton(asset: "assets/icons/ic_map_draw.svg", label: "Map view".tr, active: !isListView, onTap: onMap),
          const DsGap(DsSpace.sm),
          Container(width: 1, height: 24, color: c.divider),
          const DsGap(DsSpace.sm),
          _ToolButton(asset: "assets/icons/ic_scan_code.svg", label: "Scan QR Code".tr, active: false, onTap: onScan),
          const DsGap(DsSpace.xxs),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final String asset;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToolButton({required this.asset, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: DsMotion.of(context, DsMotion.fast),
          curve: DsMotion.standard,
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: active ? c.brand : Colors.transparent),
          child: SvgPicture.asset(asset, width: 20, height: 20, colorFilter: ColorFilter.mode(active ? c.onBrand : c.textMuted, BlendMode.srcIn)),
        ),
      ),
    );
  }
}

/// Shimmer placeholder for the food home. [bannerFirst] matches the
/// HomeScreenTwo order (banner before categories).
class FoodHomeSkeleton extends StatelessWidget {
  final bool bannerFirst;
  const FoodHomeSkeleton({super.key, this.bannerFirst = false});

  @override
  Widget build(BuildContext context) {
    final l = context.dsLayout;
    final banner = DsSkeleton.box(height: 160, radius: DsRadius.lg);
    final categories = SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, _) => const DsGap(DsSpace.md),
        itemBuilder: (_, _) => Column(children: [DsSkeleton.circle(size: 62), const DsGap(DsSpace.sm), DsSkeleton.line(width: 48, height: 10)]),
      ),
    );

    return SafeArea(
      child: DsShimmer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: l.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DsGap(DsSpace.md),
              Row(
                children: [
                  DsSkeleton.box(width: 24, height: 24, radius: DsRadius.xs),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [DsSkeleton.line(width: 100, height: 10), const DsGap(DsSpace.sm), DsSkeleton.line(width: 180)]),
                  ),
                  DsSkeleton.circle(size: 42),
                ],
              ),
              const DsGap(DsSpace.lg),
              DsSkeleton.box(height: 48, radius: DsRadius.md),
              const DsGap(DsSpace.xl),
              if (bannerFirst) ...[banner, const DsGap(DsSpace.xl), DsSkeleton.line(width: 140), const DsGap(DsSpace.md), categories] else ...[
                DsSkeleton.line(width: 140),
                const DsGap(DsSpace.md),
                categories,
                const DsGap(DsSpace.xl),
                banner,
              ],
              const DsGap(DsSpace.xl),
              DsSkeleton.line(width: 120),
              const DsGap(DsSpace.md),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 3,
                  separatorBuilder: (_, _) => const DsGap(DsSpace.md),
                  itemBuilder: (_, _) => DsSkeleton.box(width: 150, height: 160, radius: DsRadius.lg),
                ),
              ),
              const DsGap(DsSpace.xl),
              DsSkeleton.line(width: 120),
              const DsGap(DsSpace.md),
              ...List.generate(
                3,
                (_) => Padding(
                  padding: const EdgeInsets.only(bottom: DsSpace.lg),
                  child: Row(
                    children: [
                      DsSkeleton.box(width: 88, height: 88, radius: DsRadius.md),
                      const DsGap(DsSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [DsSkeleton.line(), const DsGap(DsSpace.sm), DsSkeleton.line(width: 120, height: 10), const DsGap(DsSpace.sm), DsSkeleton.line(width: 80, height: 10)],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const DsGap(DsSpace.xl),
            ],
          ),
        ),
      ),
    );
  }
}

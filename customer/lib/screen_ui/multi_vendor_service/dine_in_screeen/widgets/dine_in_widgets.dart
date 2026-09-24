import 'package:customer/constant/constant.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../../widget/restaurant_image_view.dart';

/// Private building blocks for the dine-in screens. They are composed only
/// from DS primitives; nothing here is a new design token.

/// Rating pill (star + average + count) on the section accent.
class DineInRatingChip extends StatelessWidget {
  final VendorModel vendorModel;
  final bool showCount;

  const DineInRatingChip({super.key, required this.vendorModel, this.showCount = true});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final String average = Constant.calculateReview(reviewCount: vendorModel.reviewsCount!.toStringAsFixed(0), reviewSum: vendorModel.reviewsSum.toString());
    return _Pill(
      background: c.brandSoft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset("assets/icons/ic_star.svg", width: 14, height: 14, colorFilter: ColorFilter.mode(c.brandStrong, BlendMode.srcIn)),
          const DsGap(DsSpace.xs),
          Text(
            showCount ? "$average (${vendorModel.reviewsCount!.toStringAsFixed(0)})" : average,
            style: t.labelSm.tabular.withColor(c.brandStrong),
          ),
        ],
      ),
    );
  }
}

/// Distance pill, in the informational tone.
class DineInDistanceChip extends StatelessWidget {
  final VendorModel vendorModel;

  const DineInDistanceChip({super.key, required this.vendorModel});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final tone = c.tone(DsTone.info);
    return _Pill(
      background: tone.soft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset("assets/icons/ic_map_distance.svg", width: 14, height: 14, colorFilter: ColorFilter.mode(tone.strong, BlendMode.srcIn)),
          const DsGap(DsSpace.xs),
          Text(
            "${Constant.getDistance(lat1: vendorModel.latitude.toString(), lng1: vendorModel.longitude.toString(), lat2: Constant.selectedLocation.location!.latitude.toString(), lng2: Constant.selectedLocation.location!.longitude.toString())} ${Constant.distanceType}",
            style: t.labelSm.tabular.withColor(tone.strong),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget child;
  final Color background;

  const _Pill({required this.child, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
      decoration: BoxDecoration(color: background, borderRadius: DsRadius.brPill),
      child: child,
    );
  }
}

/// Circular control that floats over media: a translucent dark disc with white
/// content, so it stays legible on any photo and in any section accent.
class DineInGlassIconButton extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final String semanticLabel;
  final VoidCallback onPressed;

  const DineInGlassIconButton({super.key, this.icon, this.child, required this.semanticLabel, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.34)),
      child: DsIconButton(
        icon: icon,
        semanticLabel: semanticLabel,
        color: Colors.white,
        size: 40,
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}

/// Heart button that floats over the store media. Keeps the brand SVGs.
class DineInFavouriteButton extends StatelessWidget {
  final bool isFavourite;
  final VoidCallback onTap;

  const DineInFavouriteButton({super.key, required this.isFavourite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DineInGlassIconButton(
      semanticLabel: isFavourite ? "Remove from favourites".tr : "Add to favourites".tr,
      onPressed: onTap,
      child: isFavourite ? SvgPicture.asset("assets/icons/ic_like_fill.svg", width: 20, height: 20) : SvgPicture.asset("assets/icons/ic_like.svg", width: 20, height: 20),
    );
  }
}

/// Showcase card used by every dine-in store list: photo carousel with a
/// scrim, floating heart, rating / distance pills on the media edge and the
/// name block on the card surface.
class DineInStoreCard extends StatelessWidget {
  final VendorModel vendorModel;
  final VoidCallback onTap;
  final Widget? favourite;
  final EdgeInsetsGeometry? margin;

  const DineInStoreCard({super.key, required this.vendorModel, required this.onTap, this.favourite, this.margin});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return DsCard.outlined(
      margin: margin ?? const EdgeInsets.only(bottom: DsSpace.lg),
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              RestaurantImageView(vendorModel: vendorModel),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(gradient: DsGradients.imageScrim),
                ),
              ),
              if (favourite != null) Positioned(right: DsSpace.sm, top: DsSpace.sm, child: favourite!),
              Positioned(
                left: DsSpace.md,
                bottom: DsSpace.md,
                right: DsSpace.md,
                child: Wrap(
                  spacing: DsSpace.sm,
                  runSpacing: DsSpace.sm,
                  children: [DineInRatingChip(vendorModel: vendorModel), DineInDistanceChip(vendorModel: vendorModel)],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vendorModel.title.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.title),
                const DsGap(DsSpace.xxs),
                Text(vendorModel.location.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular category tile (image + label) used by the dine-in rail and the
/// "all categories" grid.
class DineInCategoryTile extends StatelessWidget {
  final String? photo;
  final String title;
  final VoidCallback onTap;
  final int maxLines;

  const DineInCategoryTile({super.key, required this.photo, required this.title, required this.onTap, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsPressable(
      onTap: onTap,
      semanticLabel: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.surface, border: Border.all(color: c.border)),
            child: ClipOval(child: DsImage(url: photo, width: 62, height: 62, radius: 0, errorIcon: Icons.restaurant_menu_rounded)),
          ),
          const DsGap(DsSpace.sm),
          Text(title, textAlign: TextAlign.center, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: t.labelSm.withColor(c.textPrimary)),
        ],
      ),
    );
  }
}

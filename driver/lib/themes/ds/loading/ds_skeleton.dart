import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../foundation/ds_responsive.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_tokens.dart';

/// Shimmer wrapper using DS colors (light & dark aware). Wrap one or more
/// [DsSkeleton] blocks. Ready-made skeletons below already include it.
class DsShimmer extends StatelessWidget {
  final Widget child;
  final bool enabled;
  const DsShimmer({super.key, required this.child, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Semantics(
      label: 'Loading',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Shimmer.fromColors(
          baseColor: c.shimmerBase,
          highlightColor: c.shimmerHighlight,
          period: const Duration(milliseconds: 1300),
          enabled: enabled && !DsMotion.reduced(context),
          child: child,
        ),
      ),
    );
  }
}

/// Skeleton building blocks. They paint a solid base color; the enclosing
/// [DsShimmer] animates it.
///
/// ```dart
/// DsShimmer(child: Row(children: [DsSkeleton.circle(size: 40), DsGap.md, DsSkeleton.line(width: 120)]))
/// ```
class DsSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  final bool circle;

  const DsSkeleton._({this.width, this.height, this.radius = DsRadius.sm, this.circle = false});

  /// Rectangle (images, cards, buttons).
  factory DsSkeleton.box({double? width, double? height, double radius = DsRadius.md}) => DsSkeleton._(width: width, height: height, radius: radius);

  /// Text line.
  factory DsSkeleton.line({double? width, double height = 12}) => DsSkeleton._(width: width, height: height, radius: height / 2);

  /// Avatar / icon.
  factory DsSkeleton.circle({double size = 40}) => DsSkeleton._(width: size, height: size, circle: true);

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.shimmerBase,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// Non-scrolling container that clips overflow – lets skeletons sit in both
/// bounded (Expanded / body) and unbounded (Column / sliver) parents.
class _SkeletonFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _SkeletonFrame({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return DsShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Skeleton for list screens (orders, trips, transactions...).
///
/// ```dart
/// controller.isLoading.value ? const DsSkeletonList() : ListView(...)
/// ```
class DsSkeletonList extends StatelessWidget {
  final int itemCount;
  final bool leading;
  final bool trailing;

  /// Render each item inside a card surface (matches card-based lists).
  final bool carded;
  final EdgeInsetsGeometry? padding;

  const DsSkeletonList({super.key, this.itemCount = 6, this.leading = true, this.trailing = true, this.carded = true, this.padding});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final l = DsLayout.of(context);
    return _SkeletonFrame(
      padding: padding ?? EdgeInsets.symmetric(horizontal: l.gutter, vertical: DsSpace.lg),
      child: Column(
        children: [
          for (var i = 0; i < itemCount; i++)
            Container(
              margin: const EdgeInsets.only(bottom: DsSpace.md),
              padding: const EdgeInsets.all(DsSpace.lg),
              decoration: carded ? BoxDecoration(borderRadius: DsRadius.brLg, border: Border.all(color: c.shimmerBase)) : null,
              child: Row(
                children: [
                  if (leading) ...[DsSkeleton.box(width: 52, height: 52, radius: DsRadius.md), const DsGap(DsSpace.md)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DsSkeleton.line(width: i.isEven ? 180 : 140, height: 14),
                        const DsGap(DsSpace.sm),
                        DsSkeleton.line(width: i.isEven ? 110 : 150),
                        const DsGap(DsSpace.sm),
                        DsSkeleton.line(width: 80, height: 10),
                      ],
                    ),
                  ),
                  if (trailing) ...[const DsGap(DsSpace.md), DsSkeleton.box(width: 56, height: 24, radius: DsRadius.pill)],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Skeleton for grids (vehicles, documents, gallery).
class DsSkeletonGrid extends StatelessWidget {
  final int itemCount;
  final double minItemWidth;
  final double imageAspectRatio;
  final EdgeInsetsGeometry? padding;

  const DsSkeletonGrid({super.key, this.itemCount = 6, this.minItemWidth = 160, this.imageAspectRatio = 1.2, this.padding});

  @override
  Widget build(BuildContext context) {
    final l = DsLayout.of(context);
    return _SkeletonFrame(
      padding: padding ?? EdgeInsets.symmetric(horizontal: l.gutter, vertical: DsSpace.lg),
      child: DsAdaptiveGrid(
        minItemWidth: minItemWidth,
        equalHeight: false,
        children: [
          for (var i = 0; i < itemCount; i++)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(aspectRatio: imageAspectRatio, child: DsSkeleton.box(radius: DsRadius.lg)),
                const DsGap(DsSpace.sm),
                DsSkeleton.line(width: 120, height: 14),
                const DsGap(DsSpace.xs),
                DsSkeleton.line(width: 70),
              ],
            ),
        ],
      ),
    );
  }
}

/// Skeleton for a single content card (e.g. a summary card on a dashboard).
class DsSkeletonCard extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry? margin;
  const DsSkeletonCard({super.key, this.height = 140, this.margin});

  @override
  Widget build(BuildContext context) {
    return DsShimmer(
      child: Container(
        margin: margin,
        padding: const EdgeInsets.all(DsSpace.lg),
        height: height,
        decoration: BoxDecoration(borderRadius: DsRadius.brLg, border: Border.all(color: DsColors.of(context).shimmerBase)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [DsSkeleton.circle(size: 36), const DsGap(DsSpace.md), Expanded(child: DsSkeleton.line(height: 14))]),
            const Spacer(),
            DsSkeleton.line(width: 160, height: 22),
            const DsGap(DsSpace.sm),
            DsSkeleton.line(width: 100),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for dashboard screens: hero block + KPI tiles + list.
class DsSkeletonDashboard extends StatelessWidget {
  final int tiles;
  const DsSkeletonDashboard({super.key, this.tiles = 4});

  @override
  Widget build(BuildContext context) {
    final l = DsLayout.of(context);
    return _SkeletonFrame(
      padding: EdgeInsets.symmetric(horizontal: l.gutter, vertical: DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsSkeleton.box(height: 150, radius: DsRadius.xl),
          const DsGap(DsSpace.xl),
          DsAdaptiveGrid(
            minItemWidth: 150,
            children: [for (var i = 0; i < tiles; i++) DsSkeleton.box(height: 96, radius: DsRadius.lg)],
          ),
          const DsGap(DsSpace.xl),
          DsSkeleton.line(width: 140, height: 16),
          const DsGap(DsSpace.md),
          for (var i = 0; i < 3; i++) ...[DsSkeleton.box(height: 72, radius: DsRadius.lg), const DsGap(DsSpace.md)],
        ],
      ),
    );
  }
}

/// Skeleton for detail screens: media header, title block, info rows.
class DsSkeletonDetail extends StatelessWidget {
  final double mediaHeight;
  const DsSkeletonDetail({super.key, this.mediaHeight = 220});

  @override
  Widget build(BuildContext context) {
    final l = DsLayout.of(context);
    return _SkeletonFrame(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsSkeleton.box(height: mediaHeight, radius: 0),
          Padding(
            padding: EdgeInsets.all(l.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DsSkeleton.line(width: 220, height: 20),
                const DsGap(DsSpace.sm),
                DsSkeleton.line(width: 140),
                const DsGap(DsSpace.xl),
                Row(children: [for (var i = 0; i < 3; i++) ...[DsSkeleton.box(width: 80, height: 28, radius: DsRadius.pill), const DsGap(DsSpace.sm)]]),
                const DsGap(DsSpace.xl),
                for (var i = 0; i < 5; i++) ...[
                  Row(children: [DsSkeleton.circle(size: 32), const DsGap(DsSpace.md), Expanded(child: DsSkeleton.line(height: 14))]),
                  const DsGap(DsSpace.lg),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for form screens (label + field pairs).
class DsSkeletonForm extends StatelessWidget {
  final int fields;
  const DsSkeletonForm({super.key, this.fields = 5});

  @override
  Widget build(BuildContext context) {
    final l = DsLayout.of(context);
    return _SkeletonFrame(
      padding: EdgeInsets.symmetric(horizontal: l.gutter, vertical: DsSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < fields; i++) ...[
            DsSkeleton.line(width: 90, height: 12),
            const DsGap(DsSpace.sm),
            DsSkeleton.box(height: 50, radius: DsRadius.md),
            const DsGap(DsSpace.xl),
          ],
          DsSkeleton.box(height: 52, radius: DsRadius.md),
        ],
      ),
    );
  }
}

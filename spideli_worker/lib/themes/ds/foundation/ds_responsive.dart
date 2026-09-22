import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/ds_tokens.dart';

/// Device class derived from the available width.
enum DsBreakpoint { phone, tablet, desktop }

/// Snapshot of the responsive layout for the current [MediaQuery] size.
///
/// ```dart
/// final l = DsResponsive.of(context);            // or context.dsLayout
/// padding: l.pagePadding,
/// crossAxisCount: l.columns(phone: 2, tablet: 3, desktop: 4),
/// if (l.isWide) Row(...) else Column(...)
/// ```
@immutable
class DsLayout {
  /// Width below which we are on a phone.
  static const double phoneMax = 600;

  /// Width below which we are on a tablet (iPad portrait/landscape up to 1024).
  static const double tabletMax = 1024;

  /// Max width for reading-heavy screens (forms, details, settings, auth).
  static const double contentMax = 760;

  /// Max width for dashboards / grids on large screens.
  static const double wideMax = 1200;

  final Size size;
  final DsBreakpoint breakpoint;

  const DsLayout._(this.size, this.breakpoint);

  factory DsLayout.fromWidth(Size size) {
    final w = size.width;
    final bp = w < phoneMax
        ? DsBreakpoint.phone
        : w < tabletMax
        ? DsBreakpoint.tablet
        : DsBreakpoint.desktop;
    return DsLayout._(size, bp);
  }

  static DsLayout of(BuildContext context) => DsLayout.fromWidth(MediaQuery.sizeOf(context));

  double get width => size.width;
  bool get isPhone => breakpoint == DsBreakpoint.phone;
  bool get isTablet => breakpoint == DsBreakpoint.tablet;
  bool get isDesktop => breakpoint == DsBreakpoint.desktop;

  /// Tablet or larger – use to switch to two-pane / side-by-side layouts.
  bool get isWide => breakpoint != DsBreakpoint.phone;

  bool get isLandscape => size.width > size.height;

  /// Horizontal page gutter: 16 phone, 24 tablet, 32 desktop.
  double get gutter => value(phone: DsSpace.lg, tablet: DsSpace.xxl, desktop: DsSpace.xxxl);

  /// Symmetric horizontal page padding using [gutter].
  EdgeInsets get pagePadding => EdgeInsets.symmetric(horizontal: gutter);

  /// Pick a value per breakpoint; larger breakpoints fall back to smaller.
  T value<T>({required T phone, T? tablet, T? desktop}) {
    switch (breakpoint) {
      case DsBreakpoint.phone:
        return phone;
      case DsBreakpoint.tablet:
        return tablet ?? phone;
      case DsBreakpoint.desktop:
        return desktop ?? tablet ?? phone;
    }
  }

  /// Column count per breakpoint.
  int columns({int phone = 1, int? tablet, int? desktop}) => value(phone: phone, tablet: tablet ?? phone * 2, desktop: desktop ?? (tablet ?? phone * 2) + 1);

  /// Column count that fits items at least [minItemWidth] wide in [available]
  /// width (defaults to the screen width minus gutters).
  int columnsFor(double minItemWidth, {double? available, double spacing = DsSpace.md, int min = 1, int max = 6}) {
    final w = available ?? (math.min(width, wideMax) - gutter * 2);
    final n = ((w + spacing) / (minItemWidth + spacing)).floor();
    return n.clamp(min, max);
  }

  /// Horizontal inset that centers content at [maxWidth] (never below [gutter]).
  double horizontalInsetFor(double maxWidth) => math.max(gutter, (width - maxWidth) / 2);

  /// Grid delegate that adapts column count to width.
  ///
  /// Provide either [mainAxisExtent] (fixed tile height – preferred, it is
  /// text-scale safe when generous) or [childAspectRatio].
  static SliverGridDelegate gridDelegate({
    double maxItemWidth = 220,
    double spacing = DsSpace.md,
    double? mainAxisExtent,
    double childAspectRatio = 1,
  }) {
    return SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: maxItemWidth,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      mainAxisExtent: mainAxisExtent,
      childAspectRatio: childAspectRatio,
    );
  }
}

/// Centers [child] and constrains it to [maxWidth] on tablets / iPad, with
/// adaptive horizontal gutters. On phones it only applies the gutter.
///
/// ```dart
/// body: DsResponsive(child: ListView(...))                      // 760 max
/// body: DsResponsive(maxWidth: DsLayout.wideMax, padded: false, child: ...)
/// ```
class DsResponsive extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  /// Apply the adaptive horizontal gutter around the child.
  final bool padded;
  final AlignmentGeometry alignment;

  const DsResponsive({super.key, required this.child, this.maxWidth = DsLayout.contentMax, this.padded = false, this.alignment = Alignment.topCenter});

  /// Shortcut for [DsLayout.of].
  static DsLayout of(BuildContext context) => DsLayout.of(context);

  @override
  Widget build(BuildContext context) {
    final l = DsLayout.of(context);
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padded ? Padding(padding: l.pagePadding, child: child) : child,
      ),
    );
  }
}

/// Sliver version of [DsResponsive]: pads a sliver so its content is centered
/// at [maxWidth] (and at least the adaptive gutter from the edges).
///
/// ```dart
/// CustomScrollView(slivers: [DsSliverResponsive(sliver: SliverList.builder(...))])
/// ```
class DsSliverResponsive extends StatelessWidget {
  final Widget sliver;
  final double maxWidth;
  final double top;
  final double bottom;

  /// When false, no gutter is applied on phones (edge-to-edge content).
  final bool gutter;

  const DsSliverResponsive({super.key, required this.sliver, this.maxWidth = DsLayout.contentMax, this.top = 0, this.bottom = 0, this.gutter = true});

  @override
  Widget build(BuildContext context) {
    final l = DsLayout.of(context);
    final h = gutter ? l.horizontalInsetFor(maxWidth) : math.max(0.0, (l.width - maxWidth) / 2);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(h, top, h, bottom),
      sliver: sliver,
    );
  }
}

/// Rebuilds with the current [DsLayout].
class DsResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DsLayout layout) builder;
  const DsResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => builder(context, DsLayout.of(context));
}

/// Non-scrolling adaptive grid for a small number of tiles (KPIs, shortcuts,
/// menu cards). Column count comes from the *actual* available width, so it
/// works inside cards, split panes and scroll views.
///
/// ```dart
/// DsAdaptiveGrid(minItemWidth: 150, children: [DsStatTile(...), DsStatTile(...)])
/// ```
class DsAdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;
  final int maxColumns;

  /// Force a column count instead of computing it.
  final int? columns;

  /// Make every tile in a row as tall as the tallest one.
  final bool equalHeight;

  const DsAdaptiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 150,
    this.spacing = DsSpace.md,
    this.runSpacing = DsSpace.md,
    this.maxColumns = 4,
    this.columns,
    this.equalHeight = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
        final cols = columns ?? ((width + spacing) / (minItemWidth + spacing)).floor().clamp(1, maxColumns);
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          final cells = <Widget>[];
          for (var j = 0; j < cols; j++) {
            final idx = i + j;
            if (j > 0) cells.add(SizedBox(width: spacing));
            cells.add(Expanded(child: idx < children.length ? children[idx] : const SizedBox.shrink()));
          }
          Widget row = Row(crossAxisAlignment: equalHeight ? CrossAxisAlignment.stretch : CrossAxisAlignment.start, children: cells);
          if (equalHeight) row = IntrinsicHeight(child: row);
          if (rows.isNotEmpty) rows.add(SizedBox(height: runSpacing));
          rows.add(row);
        }
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
      },
    );
  }
}

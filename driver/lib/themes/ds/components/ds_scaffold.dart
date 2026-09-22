import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../foundation/ds_responsive.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_tokens.dart';
import '../tokens/ds_typography.dart';
import 'ds_buttons.dart';

/// Standard app bar: left-aligned title (+ optional subtitle), DS back
/// button, soft separator when content scrolls underneath.
///
/// The default back button calls `Navigator.maybePop` (same as Flutter's
/// default). Pass [onBack] to keep a screen's existing custom back logic.
///
/// ```dart
/// appBar: DsAppBar(title: 'Orders'.tr, actions: [DsIconButton(icon: Icons.tune, semanticLabel: 'Filter'.tr, onPressed: ...)])
/// ```
class DsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;

  /// Show a back button when the route can pop (default true).
  final bool showBack;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;

  /// Transparent bar with white icons – for use over hero media/gradients.
  final bool transparent;
  final bool centerTitle;

  const DsAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.actions,
    this.leading,
    this.showBack = true,
    this.onBack,
    this.bottom,
    this.backgroundColor,
    this.transparent = false,
    this.centerTitle = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (subtitle != null ? 8 : 0) + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final fg = transparent ? Colors.white : c.textPrimary;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    Widget? lead = leading;
    if (lead == null && showBack && (canPop || onBack != null)) {
      lead = DsBackButton(onPressed: onBack, color: fg, variant: DsIconButtonVariant.plain);
    }
    final t = titleWidget ??
        (title == null
            ? null
            : Column(
                crossAxisAlignment: centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsTypography.title.copyWith(color: fg)),
                  if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsTypography.caption.copyWith(color: transparent ? Colors.white70 : c.textMuted)),
                ],
              ));
    return AppBar(
      leading: lead,
      automaticallyImplyLeading: false,
      leadingWidth: lead != null ? 56 : null,
      titleSpacing: lead != null ? 0 : DsSpace.lg,
      title: t,
      centerTitle: centerTitle,
      toolbarHeight: kToolbarHeight + (subtitle != null ? 8 : 0),
      actions: [...?actions, const SizedBox(width: DsSpace.sm)],
      bottom: bottom,
      backgroundColor: transparent ? Colors.transparent : (backgroundColor ?? c.background),
      foregroundColor: fg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: transparent ? 0 : 0.6,
      shadowColor: c.shadow.withValues(alpha: 0.25),
      systemOverlayStyle: transparent || c.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
  }
}

/// DS back button (48dp, labelled, RTL-aware). Default action: `maybePop`.
class DsBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;
  final DsIconButtonVariant variant;
  const DsBackButton({super.key, this.onPressed, this.color, this.variant = DsIconButtonVariant.plain});

  @override
  Widget build(BuildContext context) {
    return DsIconButton(
      icon: Icons.arrow_back_ios_new_rounded,
      semanticLabel: 'Back'.tr,
      color: color,
      variant: variant,
      size: 40,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}

/// Sticky bottom action bar (submit / checkout / accept-reject). Adds a top
/// hairline + shadow, safe-area padding and keeps content centered on
/// tablets.
///
/// ```dart
/// bottomBar: DsStickyBar(child: DsButton.primary(label: 'Save'.tr, expand: true, onPressed: c.save))
/// bottomBar: DsStickyBar(child: Row(children: [Expanded(child: DsButton.dangerTonal(...)), DsGap.md, Expanded(child: DsButton.primary(...))]))
/// ```
class DsStickyBar extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const DsStickyBar({super.key, required this.child, this.maxWidth = DsLayout.contentMax});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final l = DsLayout.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.divider)),
        boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: c.isDark ? 0.3 : 0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.md, l.gutter, DsSpace.md),
          child: Center(heightFactor: 1, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child)),
        ),
      ),
    );
  }
}

enum _DsScaffoldKind { standard, collapsing, hero }

/// Page scaffold with DS background, responsive max-width body, optional
/// sticky bottom bar and three header styles:
///
/// * `DsScaffold(...)` – regular [DsAppBar] + [body].
/// * `DsScaffold.collapsing(...)` – large title that collapses into the app
///   bar on scroll; content given as [slivers].
/// * `DsScaffold.hero(...)` – brand-gradient header with custom [hero]
///   content (KPIs, balance, profile) and an optional [heroOverlap] card that
///   straddles the header edge; content given as [slivers].
///
/// ```dart
/// DsScaffold(title: 'Edit profile'.tr, body: ..., bottomBar: DsStickyBar(child: ...))
/// DsScaffold.collapsing(title: 'Trips'.tr, onRefresh: c.refresh, slivers: [...])
/// DsScaffold.hero(title: 'Wallet'.tr, hero: BalanceSummary(), slivers: [...])
/// ```
class DsScaffold extends StatelessWidget {
  final _DsScaffoldKind _kind;

  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;

  /// Custom app bar (standard variant only) – overrides [title].
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final List<Widget> slivers;
  final Widget? hero;
  final Widget? heroOverlap;
  final Gradient? heroGradient;

  /// Sticky bottom area, usually a [DsStickyBar].
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;

  /// Constrain & center the body on wide screens (standard variant). Set to
  /// `null` to let the body handle width itself (e.g. edge-to-edge maps).
  final double? maxContentWidth;

  /// Pull-to-refresh for sliver variants.
  final Future<void> Function()? onRefresh;
  final bool? resizeToAvoidBottomInset;
  final ScrollController? scrollController;

  const DsScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showBack = true,
    this.onBack,
    this.appBar,
    required this.body,
    this.bottomBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.maxContentWidth = DsLayout.wideMax,
    this.resizeToAvoidBottomInset,
  }) : _kind = _DsScaffoldKind.standard,
       slivers = const [],
       hero = null,
       heroOverlap = null,
       heroGradient = null,
       onRefresh = null,
       scrollController = null;

  const DsScaffold.collapsing({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showBack = true,
    this.onBack,
    required this.slivers,
    this.bottomBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.onRefresh,
    this.resizeToAvoidBottomInset,
    this.scrollController,
  }) : _kind = _DsScaffoldKind.collapsing,
       appBar = null,
       body = null,
       hero = null,
       heroOverlap = null,
       heroGradient = null,
       maxContentWidth = null;

  const DsScaffold.hero({
    super.key,
    this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showBack = true,
    this.onBack,
    required this.hero,
    this.heroOverlap,
    this.heroGradient,
    required this.slivers,
    this.bottomBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.onRefresh,
    this.resizeToAvoidBottomInset,
    this.scrollController,
  }) : _kind = _DsScaffoldKind.hero,
       appBar = null,
       body = null,
       maxContentWidth = null;

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    switch (_kind) {
      case _DsScaffoldKind.standard:
        Widget content = body!;
        if (maxContentWidth != null) content = DsResponsive(maxWidth: maxContentWidth!, child: content);
        return Scaffold(
          backgroundColor: backgroundColor ?? c.background,
          appBar: appBar ??
              (title != null || actions != null || leading != null
                  ? DsAppBar(title: title, subtitle: subtitle, actions: actions, leading: leading, showBack: showBack, onBack: onBack)
                  : null),
          body: content,
          bottomNavigationBar: bottomBar,
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: floatingActionButtonLocation,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        );
      case _DsScaffoldKind.collapsing:
        return _scrollScaffold(context, [_collapsingBar(context), ...slivers]);
      case _DsScaffoldKind.hero:
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: _scrollScaffold(context, [
            SliverToBoxAdapter(
              child: DsHeroHeader(
                title: title,
                subtitle: subtitle,
                actions: actions,
                leading: leading,
                showBack: showBack,
                onBack: onBack,
                gradient: heroGradient,
                overlap: heroOverlap,
                child: hero!,
              ),
            ),
            ...slivers,
          ]),
        );
    }
  }

  Widget _scrollScaffold(BuildContext context, List<Widget> all) {
    final c = DsColors.of(context);
    Widget scroll = CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [...all, const SliverToBoxAdapter(child: SizedBox(height: DsSpace.xxxl))],
    );
    if (onRefresh != null) {
      scroll = RefreshIndicator(onRefresh: onRefresh!, color: c.brand, backgroundColor: c.surface, edgeOffset: _kind == _DsScaffoldKind.collapsing ? 120 : 0, child: scroll);
    }
    return Scaffold(
      backgroundColor: backgroundColor ?? c.background,
      body: scroll,
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }

  Widget _collapsingBar(BuildContext context) {
    final c = DsColors.of(context);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final lead = leading ?? (showBack && (canPop || onBack != null) ? DsBackButton(onPressed: onBack) : null);
    return SliverAppBar.large(
      pinned: true,
      leading: lead,
      automaticallyImplyLeading: false,
      backgroundColor: backgroundColor ?? c.background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0.6,
      shadowColor: c.shadow.withValues(alpha: 0.25),
      foregroundColor: c.textPrimary,
      title: Text(title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: DsTypography.headline.copyWith(color: c.textPrimary)),
      actions: [...?actions, const SizedBox(width: DsSpace.sm)],
      bottom: subtitle == null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(24),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: DsSpace.lg, bottom: DsSpace.sm, end: DsSpace.lg),
                child: Align(alignment: AlignmentDirectional.centerStart, child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsTypography.bodySm.copyWith(color: c.textSecondary))),
              ),
            ),
    );
  }
}

/// Brand-gradient header used by [DsScaffold.hero]; usable on its own inside
/// any scroll view (e.g. a dashboard tab without its own route).
///
/// Content inside is white; use `DsStatTile(variant: DsStatTileVariant.onBrand)`
/// or `DsCard.glass` for blocks on it.
class DsHeroHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;
  final Gradient? gradient;
  final Widget child;

  /// Card that overlaps the bottom edge of the header.
  final Widget? overlap;

  /// Include the status-bar inset at the top (true when used as page top).
  final bool includeTopSafeArea;

  const DsHeroHeader({
    super.key,
    this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showBack = true,
    this.onBack,
    this.gradient,
    required this.child,
    this.overlap,
    this.includeTopSafeArea = true,
  });

  static const double _overlapDepth = 40;

  @override
  Widget build(BuildContext context) {
    final l = DsLayout.of(context);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final lead = leading ?? (showBack && (canPop || onBack != null) ? DsBackButton(onPressed: onBack, color: Colors.white) : null);
    final top = includeTopSafeArea ? MediaQuery.paddingOf(context).top : 0.0;
    final inset = l.horizontalInsetFor(DsLayout.wideMax);

    final header = Container(
      decoration: BoxDecoration(
        gradient: gradient ?? DsGradients.brand(context),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(DsRadius.xxl)),
      ),
      padding: EdgeInsets.fromLTRB(inset, top + DsSpace.sm, inset, overlap != null ? DsSpace.xxl + _overlapDepth : DsSpace.xxl),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: IconTheme.merge(
          data: const IconThemeData(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lead != null || title != null || (actions?.isNotEmpty ?? false))
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      if (lead != null) Transform.translate(offset: const Offset(-8, 0), child: lead),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (title != null) Semantics(header: true, child: Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsTypography.title.copyWith(color: Colors.white))),
                            if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsTypography.bodySm.copyWith(color: Colors.white.withValues(alpha: 0.82))),
                          ],
                        ),
                      ),
                      ...?actions,
                    ],
                  ),
                ),
              const DsGap(DsSpace.md),
              child,
            ],
          ),
        ),
      ),
    );

    if (overlap == null) return header;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        _PullUp(
          amount: _overlapDepth,
          child: Padding(padding: EdgeInsets.symmetric(horizontal: inset), child: overlap),
        ),
      ],
    );
  }
}

/// Lays out its child normally but pulls it up by [amount] (a "negative top
/// margin"): it paints and hit-tests the child shifted up and reports a
/// height reduced by [amount], so no gap is left below.
class _PullUp extends SingleChildRenderObjectWidget {
  final double amount;
  const _PullUp({required this.amount, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPullUp(amount);

  @override
  void updateRenderObject(BuildContext context, _RenderPullUp renderObject) => renderObject.amount = amount;
}

class _RenderPullUp extends RenderProxyBox {
  _RenderPullUp(this._amount);

  double _amount;
  set amount(double v) {
    if (v == _amount) return;
    _amount = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final c = child!;
    c.layout(constraints.loosen().copyWith(minWidth: constraints.minWidth), parentUsesSize: true);
    size = constraints.constrain(Size(c.size.width, (c.size.height - _amount).clamp(0.0, double.infinity)));
  }

  @override
  void paint(PaintingContext context, Offset offset) => context.paintChild(child!, offset.translate(0, -_amount));

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.translateByDouble(0, -_amount, 0, 1);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintOffset(
      offset: Offset(0, -_amount),
      position: position,
      hitTest: (result, transformed) => child!.hitTest(result, position: transformed),
    );
  }

  @override
  Rect get paintBounds => Offset(0, -_amount) & child!.size;
}

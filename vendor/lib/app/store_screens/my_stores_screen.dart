import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/app/add_restaurant_screen/add_restaurant_screen.dart';
import 'package:vendor/controller/my_stores_controller.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/themes/theme_controller.dart';

/// The stores this vendor account owns: switch between them, or add another.
/// Owners only - an employee always works on the one store they belong to.
///
/// Layout: a portfolio hero (consolidated figures across every store) over a
/// list of store cards, each with its own figures (2 columns on tablets).
class MyStoresScreen extends StatelessWidget {
  const MyStoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: MyStoresController(),
      builder: (controller) {
        // Read here so GetX rebuilds when the figures arrive (list items are
        // built lazily, outside this builder).
        final bool overviewLoading = controller.isOverviewLoading.value;
        final Map<String, StoreOverview> overviews = Map.of(controller.overviews);
        final bool isLoading = controller.isLoading.value;
        final List<VendorModel> stores = controller.stores.toList();
        final l = context.dsLayout;
        final int columns = l.isWide ? 2 : 1;

        return DsScaffold.hero(
          title: "My Stores".tr,
          subtitle: isLoading ? null : "${stores.length} ${stores.length == 1 ? "store".tr : "stores".tr}",
          onRefresh: !isLoading && stores.isNotEmpty ? controller.getStores : null,
          actions: [
            _HeroAction(
              icon: Icons.add_rounded,
              label: "Add Store".tr,
              onTap: () {
                Get.to(const AddRestaurantScreen(), arguments: {'newStore': true})?.then((_) => controller.getStores());
              },
            ),
          ],
          hero: isLoading
              ? const _HeroSkeleton()
              : stores.isEmpty
              ? const SizedBox.shrink()
              : _ConsolidatedOverview(controller: controller, loading: overviewLoading, isDark: isDark),
          slivers: [
            if (isLoading)
              const SliverToBoxAdapter(child: DsSkeletonList(itemCount: 4))
            else if (stores.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(icon: Icons.storefront_outlined, title: "No stores found".tr),
              )
            else
              DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                top: DsSpace.xl,
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, row) {
                    Widget tile(int index) {
                      final VendorModel store = stores[index];
                      final bool isCurrent = store.id == controller.currentStoreId;
                      return DsFadeSlideIn(
                        index: index,
                        child: StoreListTile(
                          store: store,
                          isCurrent: isCurrent,
                          isDark: isDark,
                          overview: overviews[store.id],
                          isOverviewLoading: overviewLoading,
                          onTap: isCurrent ? null : () => _confirmSwitch(context, controller, store, isDark),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: DsSpace.md),
                      child: columns == 1
                          ? tile(row)
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (int j = 0; j < columns; j++) ...[
                                  if (j > 0) DsGap.md,
                                  Expanded(child: row * columns + j < stores.length ? tile(row * columns + j) : const SizedBox.shrink()),
                                ],
                              ],
                            ),
                    );
                  }, childCount: (stores.length / columns).ceil()),
                ),
              ),
          ],
        );
      },
    );
  }

  void _confirmSwitch(BuildContext context, MyStoresController controller, VendorModel store, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogContext) => DsDialog(
        icon: Icons.swap_horiz_rounded,
        title: "Switch store".tr,
        message: "${"The app will reload to manage".tr} ${store.title ?? ''}.",
        secondaryLabel: "Cancel".tr,
        onSecondary: () => Navigator.of(dialogContext).pop(),
        primaryLabel: "Switch".tr,
        onPrimary: () {
          Navigator.of(dialogContext).pop();
          controller.switchTo(store);
        },
      ),
    );
  }
}

/// A store row: photo, name, address and a "Current" badge. With [overview]
/// (My Stores) it also shows that store's own figures. Also used by the store
/// selector after login, with [badgeLabel] "Last used".
class StoreListTile extends StatelessWidget {
  final VendorModel store;
  final bool isCurrent;
  final bool isDark;
  final VoidCallback? onTap;
  final StoreOverview? overview;
  final bool isOverviewLoading;
  final String? badgeLabel;

  const StoreListTile({
    super.key,
    required this.store,
    required this.isCurrent,
    required this.isDark,
    this.onTap,
    this.overview,
    this.isOverviewLoading = false,
    this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard(
      padding: const EdgeInsets.all(DsSpace.md),
      borderColor: isCurrent ? c.brand : null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DsImage(url: store.photo ?? '', height: 56, width: 56, radius: DsRadius.md, errorIcon: Icons.storefront_rounded),
              DsGap.md,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.title?.isNotEmpty == true ? store.title! : "Unnamed store".tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                    if ((store.location ?? '').isNotEmpty) ...[
                      const DsGap(DsSpace.xxs),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.location_on_outlined, size: 14, color: c.textMuted)),
                          const DsGap(DsSpace.xs),
                          Expanded(child: Text(store.location!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySm)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              DsGap.sm,
              isCurrent
                  ? DsBadge(label: badgeLabel ?? "Current".tr, tone: DsTone.brand, icon: Icons.check_circle_rounded)
                  : Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: c.textMuted),
            ],
          ),
          if (overview != null || isOverviewLoading) ...[
            DsGap.md,
            _StoreFigures(overview: overview, isDark: isDark),
          ],
        ],
      ),
    );
  }
}

/// Totals across every store the owner has (spec 8.1, consolidated view).
/// Balances are added up only when all stores share one currency; otherwise
/// each store's balance is listed in its own currency.
class _ConsolidatedOverview extends StatelessWidget {
  final MyStoresController controller;
  final bool loading;
  final bool isDark;

  const _ConsolidatedOverview({required this.controller, required this.loading, required this.isDark});

  @override
  Widget build(BuildContext context) {
    String count(int? Function(StoreOverview o) pick) {
      if (loading) return '...';
      final int? value = controller.totalOf(pick);
      return value == null ? '-' : value.toString();
    }

    final String? totalBalance = loading ? '...' : controller.totalBalanceText;
    final double scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final white = Colors.white;
    final muted = Colors.white.withValues(alpha: 0.8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: DsFadeSlideIn.stagger([
        Row(
          children: [
            Icon(Icons.dashboard_outlined, color: white, size: 18),
            DsGap.sm,
            Expanded(child: Text("All stores".tr.toUpperCase(), style: DsTypography.overline.copyWith(color: muted))),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: DsSpace.md),
          child: DsAdaptiveGrid(
            minItemWidth: 96 * scale,
            spacing: DsSpace.sm,
            runSpacing: DsSpace.sm,
            children: [
              _HeroFigure(label: "Orders today".tr, value: count((o) => o.ordersToday), loading: loading),
              _HeroFigure(label: "In progress".tr, value: count((o) => o.inProgress), loading: loading),
              _HeroFigure(label: "Completed today".tr, value: count((o) => o.completedToday), loading: loading),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: DsSpace.sm),
          child: DsCard.glass(
            padding: const EdgeInsets.all(DsSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DsIconWell(icon: Icons.account_balance_wallet_outlined, onBrand: true, size: 36),
                    DsGap.md,
                    Expanded(child: Text("Total store balance".tr, style: DsTypography.labelSm.copyWith(color: muted))),
                  ],
                ),
                DsGap.md,
                loading
                    ? const _GlassBar(width: 140, height: 28)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(totalBalance ?? "Mixed currencies".tr, maxLines: 1, style: DsTypography.metricLg.copyWith(color: white, fontSize: 30)),
                      ),
                if (totalBalance == null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final store in controller.stores)
                        if (controller.overviews[store.id] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: DsSpace.sm),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    store.title?.isNotEmpty == true ? store.title! : "Unnamed store".tr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DsTypography.bodySm.copyWith(color: muted),
                                  ),
                                ),
                                DsGap.sm,
                                Text(controller.overviews[store.id]!.balanceText, style: DsTypography.label.copyWith(color: white).tabular),
                              ],
                            ),
                          ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  final String label;
  final String value;
  final bool loading;

  const _HeroFigure({required this.label, required this.value, required this.loading});

  @override
  Widget build(BuildContext context) {
    return DsCard.glass(
      padding: const EdgeInsets.all(DsSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          loading
              ? const _GlassBar(width: 36, height: 24)
              : Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsTypography.metric.copyWith(color: Colors.white, fontSize: 22)),
          const DsGap(DsSpace.xs),
          Text(label, maxLines: 2, style: DsTypography.labelSm.copyWith(color: Colors.white.withValues(alpha: 0.82))),
        ],
      ),
    );
  }
}

/// Pulsing translucent placeholder for a figure that is still loading on the
/// gradient hero (a grey shimmer would look out of place there).
class _GlassBar extends StatelessWidget {
  final double width;
  final double height;
  const _GlassBar({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.12, end: 0.3),
      duration: DsMotion.of(context, DsMotion.slower),
      curve: Curves.easeInOut,
      builder: (_, v, _) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: v), borderRadius: DsRadius.brSm),
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _GlassBar(width: 90, height: 12),
        DsGap.md,
        Row(
          children: [
            for (int i = 0; i < 3; i++) ...[if (i > 0) DsGap.sm, const Expanded(child: _GlassBar(width: double.infinity, height: 72))],
          ],
        ),
        DsGap.sm,
        const _GlassBar(width: double.infinity, height: 96),
      ],
    );
  }
}

/// Glass pill button for the gradient header.
class _HeroAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeroAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DsPressable(
      onTap: onTap,
      semanticLabel: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(
          heightFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: DsRadius.brPill,
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const DsGap(DsSpace.xs),
                Text(label, style: DsTypography.label.copyWith(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One store's own figures, under its tile.
class _StoreFigures extends StatelessWidget {
  final StoreOverview? overview;
  final bool isDark;

  const _StoreFigures({required this.overview, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    String show(int? value) => overview == null ? '...' : (value == null ? '-' : value.toString());
    Widget divider() => Container(width: 1, height: 28, color: c.border);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
      child: Row(
        children: [
          Expanded(child: _MiniFigure(label: "Today".tr, value: show(overview?.ordersToday), loading: overview == null)),
          divider(),
          Expanded(child: _MiniFigure(label: "In progress".tr, value: show(overview?.inProgress), loading: overview == null)),
          divider(),
          Expanded(child: _MiniFigure(label: "Completed".tr, value: show(overview?.completedToday), loading: overview == null)),
          divider(),
          Expanded(flex: 2, child: _MiniFigure(label: "Balance".tr, value: overview?.balanceText ?? '...', alignEnd: true, loading: overview == null, strong: true)),
        ],
      ),
    );
  }
}

class _MiniFigure extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;
  final bool loading;
  final bool strong;

  const _MiniFigure({required this.label, required this.value, this.alignEnd = false, this.loading = false, this.strong = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.xs),
      child: Column(
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.center,
        children: [
          loading
              ? DsShimmer(child: DsSkeleton.line(width: 28, height: 14))
              : Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label.tabular.copyWith(color: strong ? c.brandStrong : c.textPrimary)),
          const DsGap(DsSpace.xxs),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption),
        ],
      ),
    );
  }
}

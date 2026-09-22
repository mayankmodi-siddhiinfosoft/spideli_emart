import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/app/add_restaurant_screen/add_restaurant_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/my_stores_controller.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/utils/network_image_widget.dart';

/// The stores this vendor account owns: switch between them, or add another.
/// Owners only - an employee always works on the one store they belong to.
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
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            iconTheme: IconThemeData(color: AppThemeData.grey50, size: 20),
            title: Text(
              "My Stores".tr,
              style: TextStyle(color: AppThemeData.grey50, fontSize: 18, fontFamily: AppThemeData.medium),
            ),
            actions: [
              InkWell(
                splashColor: Colors.transparent,
                onTap: () {
                  Get.to(const AddRestaurantScreen(), arguments: {'newStore': true})?.then((_) => controller.getStores());
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.add, color: AppThemeData.grey50),
                      const SizedBox(width: 5),
                      Text(
                        "Add Store".tr,
                        style: TextStyle(color: AppThemeData.grey50, fontSize: 18, fontFamily: AppThemeData.medium),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: controller.isLoading.value
              ? Constant.loader()
              : controller.stores.isEmpty
              ? Constant.showEmptyView(message: "No stores found".tr, isDark: isDark)
              : RefreshIndicator(
                  onRefresh: controller.getStores,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    // The consolidated overview first, then one tile per store.
                    itemCount: controller.stores.length + 1,
                    separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 18 : 10),
                    itemBuilder: (context, index) {
                      if (index == 0) return _ConsolidatedOverview(controller: controller, loading: overviewLoading, isDark: isDark);
                      final VendorModel store = controller.stores[index - 1];
                      final bool isCurrent = store.id == controller.currentStoreId;
                      return StoreListTile(
                        store: store,
                        isCurrent: isCurrent,
                        isDark: isDark,
                        overview: overviews[store.id],
                        isOverviewLoading: overviewLoading,
                        onTap: isCurrent ? null : () => _confirmSwitch(context, controller, store, isDark),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }

  void _confirmSwitch(BuildContext context, MyStoresController controller, VendorModel store, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
        title: Text(
          "Switch store".tr,
          style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontSize: 18),
        ),
        content: Text(
          "${"The app will reload to manage".tr} ${store.title ?? ''}.",
          style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontFamily: AppThemeData.regular),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text("Cancel".tr, style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              controller.switchTo(store);
            },
            child: Text("Switch".tr, style: TextStyle(color: AppThemeData.primary300, fontFamily: AppThemeData.semiBold)),
          ),
        ],
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: ShapeDecoration(
          color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isCurrent ? AppThemeData.primary300 : (isDark ? AppThemeData.grey800 : AppThemeData.grey200)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: NetworkImageWidget(imageUrl: store.photo ?? '', height: 52, width: 52, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.title?.isNotEmpty == true ? store.title! : "Unnamed store".tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontSize: 16),
                      ),
                      if ((store.location ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          store.location!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.regular, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                isCurrent
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: ShapeDecoration(
                          color: isDark ? AppThemeData.grey800 : AppThemeData.primary600,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text(
                          badgeLabel ?? "Current".tr,
                          style: TextStyle(color: AppThemeData.primary300, fontFamily: AppThemeData.semiBold, fontSize: 12),
                        ),
                      )
                    : Icon(Icons.chevron_right, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
              ],
            ),
            if (overview != null || isOverviewLoading) ...[
              const SizedBox(height: 12),
              _StoreFigures(overview: overview, isDark: isDark),
            ],
          ],
        ),
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
    final Color title = isDark ? AppThemeData.grey50 : AppThemeData.grey900;
    final Color muted = isDark ? AppThemeData.grey400 : AppThemeData.grey500;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(
        color: isDark ? AppThemeData.grey900 : AppThemeData.primary600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard_outlined, color: AppThemeData.primary300, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "All stores".tr,
                  style: TextStyle(color: title, fontSize: 16, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                "${controller.stores.length} ${controller.stores.length == 1 ? "store".tr : "stores".tr}",
                style: TextStyle(color: muted, fontSize: 13, fontFamily: AppThemeData.regular),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatBox(label: "Orders today".tr, value: count((o) => o.ordersToday), isDark: isDark)),
              const SizedBox(width: 8),
              Expanded(child: _StatBox(label: "In progress".tr, value: count((o) => o.inProgress), isDark: isDark)),
              const SizedBox(width: 8),
              Expanded(child: _StatBox(label: "Completed today".tr, value: count((o) => o.completedToday), isDark: isDark)),
            ],
          ),
          const SizedBox(height: 8),
          _StatBox(
            label: "Total store balance".tr,
            value: totalBalance ?? "Mixed currencies".tr,
            isDark: isDark,
            wide: true,
            footer: totalBalance == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final store in controller.stores)
                        if (controller.overviews[store.id] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    store.title?.isNotEmpty == true ? store.title! : "Unnamed store".tr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: muted, fontSize: 13, fontFamily: AppThemeData.regular),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  controller.overviews[store.id]!.balanceText,
                                  style: TextStyle(color: title, fontSize: 13, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                    ],
                  )
                : null,
          ),
        ],
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
    String show(int? value) => overview == null ? '...' : (value == null ? '-' : value.toString());
    return Row(
      children: [
        Expanded(child: _MiniFigure(label: "Today".tr, value: show(overview?.ordersToday), isDark: isDark)),
        Expanded(child: _MiniFigure(label: "In progress".tr, value: show(overview?.inProgress), isDark: isDark)),
        Expanded(child: _MiniFigure(label: "Completed".tr, value: show(overview?.completedToday), isDark: isDark)),
        Expanded(flex: 2, child: _MiniFigure(label: "Balance".tr, value: overview?.balanceText ?? '...', isDark: isDark, alignEnd: true)),
      ],
    );
  }
}

class _MiniFigure extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final bool alignEnd;

  const _MiniFigure({required this.label, required this.value, required this.isDark, this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 15, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontSize: 12, fontFamily: AppThemeData.regular),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final bool wide;
  final Widget? footer;

  const _StatBox({required this.label, required this.value, required this.isDark, this.wide = false, this.footer});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(10),
      decoration: ShapeDecoration(
        color: isDark ? AppThemeData.grey800 : AppThemeData.grey50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: wide ? 18 : 20, fontFamily: AppThemeData.bold, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontSize: 12, fontFamily: AppThemeData.regular),
          ),
          ?footer,
        ],
      ),
    );
  }
}

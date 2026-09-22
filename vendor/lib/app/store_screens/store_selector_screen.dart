import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/app/store_screens/my_stores_screen.dart';
import 'package:vendor/controller/store_selector_controller.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/themes/theme_controller.dart';

/// Full-screen store list shown after an owner with several stores logs in.
/// Picking one makes it the working store and continues to the dashboard.
///
/// Layout: a "choose your workspace" welcome hero, then the stores as large
/// tappable cards (2 columns on tablets).
class StoreSelectorScreen extends StatelessWidget {
  const StoreSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: StoreSelectorController(),
      builder: (controller) {
        final List<VendorModel> stores = controller.stores.toList();
        final String? lastStoreId = controller.lastStoreId.value;
        final l = context.dsLayout;
        final int columns = l.isWide ? 2 : 1;
        return DsScaffold.hero(
          showBack: false,
          title: "Choose a store".tr,
          hero: DsFadeSlideIn(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DsIconWell(icon: Icons.storefront_rounded, onBrand: true, size: 48),
                DsGap.lg,
                Expanded(
                  child: Text(
                    "You manage several stores. Pick the one to work on - you can switch any time from the store picker on the home screen.".tr,
                    style: DsTypography.body.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ),
              ],
            ),
          ),
          slivers: [
            DsSliverResponsive(
              maxWidth: DsLayout.wideMax,
              top: DsSpace.xl,
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, row) {
                  Widget tile(int index) {
                    final VendorModel store = stores[index];
                    return DsFadeSlideIn(
                      index: index,
                      child: StoreListTile(
                        store: store,
                        isCurrent: store.id == lastStoreId,
                        badgeLabel: "Last used".tr,
                        isDark: isDark,
                        onTap: () => controller.choose(store),
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
}

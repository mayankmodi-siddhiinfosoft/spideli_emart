import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/app/store_screens/my_stores_screen.dart';
import 'package:vendor/controller/store_selector_controller.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/theme_controller.dart';

/// Full-screen store list shown after an owner with several stores logs in.
/// Picking one makes it the working store and continues to the dashboard.
class StoreSelectorScreen extends StatelessWidget {
  const StoreSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: StoreSelectorController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            automaticallyImplyLeading: false,
            centerTitle: false,
            title: Text(
              "Choose a store".tr,
              style: TextStyle(color: AppThemeData.grey50, fontSize: 18, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
            ),
          ),
          body: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: controller.stores.length + 1,
            separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 16 : 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  "You manage several stores. Pick the one to work on - you can switch any time from the store picker on the home screen.".tr,
                  style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 14, height: 1.4, fontFamily: AppThemeData.regular),
                );
              }
              final VendorModel store = controller.stores[index - 1];
              return StoreListTile(
                store: store,
                isCurrent: store.id == controller.lastStoreId.value,
                badgeLabel: "Last used".tr,
                isDark: isDark,
                onTap: () => controller.choose(store),
              );
            },
          ),
        );
      },
    );
  }
}

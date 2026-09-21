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
                  Get.to(const AddRestaurantScreen(), arguments: {'newStore': true})?.then((value) {
                    if (value == true) {
                      controller.getStores();
                    }
                  });
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
                    itemCount: controller.stores.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final VendorModel store = controller.stores[index];
                      final bool isCurrent = store.id == controller.currentStoreId;
                      return _StoreTile(
                        store: store,
                        isCurrent: isCurrent,
                        isDark: isDark,
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

class _StoreTile extends StatelessWidget {
  final VendorModel store;
  final bool isCurrent;
  final bool isDark;
  final VoidCallback? onTap;

  const _StoreTile({required this.store, required this.isCurrent, required this.isDark, this.onTap});

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
        child: Row(
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
                      color: isDark ? AppThemeData.primary600 : AppThemeData.primary50,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(
                      "Current".tr,
                      style: TextStyle(color: AppThemeData.primary300, fontFamily: AppThemeData.semiBold, fontSize: 12),
                    ),
                  )
                : Icon(Icons.chevron_right, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
          ],
        ),
      ),
    );
  }
}

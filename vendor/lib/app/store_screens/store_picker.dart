import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/app/add_restaurant_screen/add_restaurant_screen.dart';
import 'package:vendor/app/store_screens/my_stores_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/my_stores_controller.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/utils/network_image_widget.dart';

/// The store picker in the home header (app-spec-multiple-stores: "Switch
/// store - a picker in the header. It writes the chosen id to users.vendorID
/// and reloads").
///
/// Shows the store being worked on; tapping it lists the owner's stores to
/// switch to, plus Add Store and Manage stores. Owners only: an employee
/// belongs to one store and never sees the picker.
class StorePickerChip extends StatelessWidget {
  final String? storeName;
  final bool isDark;

  const StorePickerChip({super.key, required this.storeName, required this.isDark});

  /// Owners only (anyone who isn't an employee), once there is a store to show.
  static bool get isAvailable =>
      Constant.userModel != null && Constant.userModel!.role != Constant.userRoleEmployee && (Constant.userModel!.vendorID ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!isAvailable) return const SizedBox();
    final Color textColor = isDark ? AppThemeData.grey900 : AppThemeData.grey50;
    // A pill button rather than plain text, so it reads as tappable.
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: textColor.withValues(alpha: 0.18),
        shape: StadiumBorder(side: BorderSide(color: textColor.withValues(alpha: 0.55))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showStorePicker(isDark),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_rounded, size: 17, color: textColor),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(
                    (storeName ?? '').isNotEmpty ? storeName! : "My Stores".tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textColor, fontSize: 14, fontFamily: AppThemeData.semiBold),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.swap_vert_rounded, size: 18, color: textColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void showStorePicker(bool isDark) {
    // onInit loads the owner's stores.
    final controller = Get.put(MyStoresController(), tag: 'storePicker');
    Get.bottomSheet(
      _StorePickerSheet(controller: controller, isDark: isDark),
      backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    ).whenComplete(() => Get.delete<MyStoresController>(tag: 'storePicker'));
  }
}

class _StorePickerSheet extends StatelessWidget {
  final MyStoresController controller;
  final bool isDark;

  const _StorePickerSheet({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final Color titleColor = isDark ? AppThemeData.grey50 : AppThemeData.grey900;
    final Color subColor = isDark ? AppThemeData.grey400 : AppThemeData.grey500;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text("Switch store".tr, style: TextStyle(color: titleColor, fontSize: 18, fontFamily: AppThemeData.semiBold)),
            ),
            Flexible(
              child: Obx(
                () => controller.isLoading.value
                    ? Padding(padding: const EdgeInsets.all(24), child: Constant.loader())
                    : ListView(
                        shrinkWrap: true,
                        children: controller.stores.map((VendorModel store) {
                          final bool isCurrent = store.id == controller.currentStoreId;
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: NetworkImageWidget(imageUrl: store.photo ?? '', height: 40, width: 40, fit: BoxFit.cover),
                            ),
                            title: Text(
                              (store.title ?? '').isNotEmpty ? store.title! : "Unnamed store".tr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: titleColor, fontFamily: AppThemeData.medium),
                            ),
                            subtitle: (store.location ?? '').isEmpty
                                ? null
                                : Text(store.location!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: subColor, fontSize: 12)),
                            trailing: isCurrent ? Icon(Icons.check_circle, color: AppThemeData.primary300) : null,
                            onTap: isCurrent
                                ? null
                                : () {
                                    Get.back();
                                    controller.switchTo(store);
                                  },
                          );
                        }).toList(),
                      ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.add_business_outlined, color: AppThemeData.primary300),
              title: Text("Add Store".tr, style: TextStyle(color: titleColor, fontFamily: AppThemeData.medium)),
              onTap: () {
                Get.back();
                Get.to(const AddRestaurantScreen(), arguments: {'newStore': true});
              },
            ),
            ListTile(
              leading: Icon(Icons.store_mall_directory_outlined, color: AppThemeData.primary300),
              title: Text("Manage stores".tr, style: TextStyle(color: titleColor, fontFamily: AppThemeData.medium)),
              onTap: () {
                Get.back();
                Get.to(const MyStoresScreen());
              },
            ),
          ],
        ),
      ),
    );
  }
}

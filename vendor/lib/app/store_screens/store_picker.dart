import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/app/add_restaurant_screen/add_restaurant_screen.dart';
import 'package:vendor/app/store_screens/my_stores_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/my_stores_controller.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/themes/ds/ds.dart';

/// The store picker in the home header (app-spec-multiple-stores: "Switch
/// store - a picker in the header. It writes the chosen id to users.vendorID
/// and reloads").
///
/// Shows the store being worked on. For owners, tapping it lists their stores
/// to switch to, plus Add Store and Manage stores. An employee belongs to one
/// store: they see its name, with no switch action.
class CurrentStoreCard extends StatelessWidget {
  final String? storeName;
  final String? storePhoto;
  final bool isDark;

  const CurrentStoreCard({super.key, required this.storeName, required this.storePhoto, required this.isDark});

  /// Owners can switch; anyone who isn't an employee, once there is a store.
  static bool get canSwitch =>
      Constant.userModel != null && Constant.userModel!.role != Constant.userRoleEmployee && (Constant.userModel!.vendorID ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bool canSwitch = CurrentStoreCard.canSwitch;
    final c = context.dsColors;
    final t = context.dsText;
    final String name = (storeName ?? '').isNotEmpty ? storeName! : "Unnamed store".tr;
    return DsCard(
      padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.md, DsSpace.md, DsSpace.md),
      radius: DsRadius.lg,
      semanticLabel: canSwitch ? "${"CURRENT STORE".tr}: $name. ${"Switch".tr}" : "${"CURRENT STORE".tr}: $name",
      onTap: canSwitch ? () => showStorePicker(isDark) : null,
      child: Row(
        children: [
          (storePhoto ?? '').isEmpty
              ? const DsIconWell(icon: Icons.storefront_rounded, size: 48)
              : DsImage(url: storePhoto!, width: 48, height: 48, radius: DsRadius.md, errorIcon: Icons.storefront_rounded),
          DsGap.md,
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("CURRENT STORE".tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.overline),
                const DsGap(DsSpace.xxs),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
              ],
            ),
          ),
          if (canSwitch) ...[
            DsGap.sm,
            ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                decoration: BoxDecoration(color: c.brandSoft, borderRadius: DsRadius.brPill),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 18, color: c.brandStrong),
                    const DsGap(DsSpace.xs),
                    Text("Switch".tr, style: t.label.copyWith(color: c.brandStrong)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static void showStorePicker(bool isDark) {
    // onInit loads the owner's stores.
    final controller = Get.put(MyStoresController(withOverview: false), tag: 'storePicker');
    Get.bottomSheet(
      _StorePickerSheet(controller: controller, isDark: isDark),
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
    ).whenComplete(() => Get.delete<MyStoresController>(tag: 'storePicker'));
  }
}

class _StorePickerSheet extends StatelessWidget {
  final MyStoresController controller;
  final bool isDark;

  const _StorePickerSheet({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsSheet(
      title: "Switch store".tr,
      showClose: true,
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(
            () => AnimatedSwitcher(
              duration: DsMotion.of(context, DsMotion.base),
              child: controller.isLoading.value
                  ? const _PickerSkeleton()
                  : Column(
                      key: const ValueKey('stores'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < controller.stores.length; i++)
                          Builder(
                            builder: (context) {
                              final VendorModel store = controller.stores[i];
                              final bool isCurrent = store.id == controller.currentStoreId;
                              return DsFadeSlideIn(
                                index: i,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: DsSpace.sm),
                                  child: DsCard.outlined(
                                    padding: const EdgeInsets.all(DsSpace.md),
                                    color: isCurrent ? c.brandSoft : null,
                                    borderColor: isCurrent ? c.brand : null,
                                    onTap: isCurrent
                                        ? null
                                        : () {
                                            Get.back();
                                            controller.switchTo(store);
                                          },
                                    child: Row(
                                      children: [
                                        DsImage(url: store.photo ?? '', width: 44, height: 44, radius: DsRadius.sm, errorIcon: Icons.storefront_rounded),
                                        DsGap.md,
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                (store.title ?? '').isNotEmpty ? store.title! : "Unnamed store".tr,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: t.bodyStrong,
                                              ),
                                              if ((store.location ?? '').isNotEmpty)
                                                Text(store.location!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption),
                                            ],
                                          ),
                                        ),
                                        DsGap.sm,
                                        isCurrent
                                            ? Icon(Icons.check_circle_rounded, color: c.brand)
                                            : Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: c.textMuted),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
            ),
          ),
          const DsGap(DsSpace.sm),
          DsTileGroup(
            dividerIndent: 64,
            children: [
              DsListTile(
                leadingIcon: Icons.add_business_outlined,
                leadingTone: DsTone.brand,
                title: "Add Store".tr,
                showChevron: true,
                onTap: () {
                  Get.back();
                  Get.to(const AddRestaurantScreen(), arguments: {'newStore': true});
                },
              ),
              DsListTile(
                leadingIcon: Icons.store_mall_directory_outlined,
                leadingTone: DsTone.brand,
                title: "Manage stores".tr,
                showChevron: true,
                onTap: () {
                  Get.back();
                  Get.to(const MyStoresScreen());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickerSkeleton extends StatelessWidget {
  const _PickerSkeleton();

  @override
  Widget build(BuildContext context) {
    return DsShimmer(
      child: Column(
        children: [
          for (int i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpace.sm),
              child: Row(
                children: [
                  DsSkeleton.box(width: 44, height: 44, radius: DsRadius.sm),
                  DsGap.md,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [DsSkeleton.line(width: 160, height: 14), DsGap.sm, DsSkeleton.line(width: 110)],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

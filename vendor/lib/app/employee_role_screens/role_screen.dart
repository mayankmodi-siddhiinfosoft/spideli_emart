import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/app/add_restaurant_screen/add_restaurant_screen.dart';
import 'package:vendor/app/employee_role_screens/add_edit_role_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/role_controller.dart';
import 'package:vendor/models/employee_role_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: RoleController(),
      builder: (controller) {
        final c = context.dsColors;
        return DsScaffold.collapsing(
          title: "Employee Role".tr,
          backgroundColor: c.background,
          slivers: [
            if (controller.isLoading.value)
              const DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                top: DsSpace.sm,
                sliver: SliverToBoxAdapter(child: DsSkeletonGrid(minItemWidth: 280, imageAspectRatio: 3, padding: EdgeInsets.zero)),
              )
            else if (Constant.userModel?.vendorID == null || Constant.userModel?.vendorID?.isEmpty == true)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(
                  illustration: Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      padding: const EdgeInsets.all(DsSpace.xxxl),
                      decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle, border: Border.all(color: c.brand.withValues(alpha: 0.2))),
                      child: SvgPicture.asset("assets/icons/ic_building_two.svg"),
                    ),
                  ),
                  title: "Add Your First Store".tr,
                  message: "Get started by adding your store details to manage your menu, orders.".tr,
                  actionLabel: "Add Store".tr,
                  actionIcon: Icons.storefront_outlined,
                  onAction: () async {
                    Get.to(const AddRestaurantScreen())?.then((value) {
                      controller.update();
                    });
                  },
                ),
              )
            else if (controller.employeeRolelList.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(icon: Icons.admin_panel_settings_outlined, title: "No employee role found".tr, compact: true),
              )
            else
              DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                top: DsSpace.sm,
                bottom: 96,
                sliver: SliverToBoxAdapter(
                  child: DsAdaptiveGrid(
                    minItemWidth: 280,
                    maxColumns: 3,
                    children: [
                      for (int index = 0; index < controller.employeeRolelList.length; index++)
                        DsFadeSlideIn(
                          index: index,
                          child: Builder(
                            builder: (context) {
                              EmployeeRoleModel model = controller.employeeRolelList[index];
                              return _RoleCard(
                                model: model,
                                onTap: () {
                                  Get.to(const AddEditRoleScreen(), arguments: {"employeeRoleModel": model})!.then((value) {
                                    if (value == true) {
                                      controller.getAllEmployeeRoles();
                                    }
                                  });
                                },
                                onDelete: () {
                                  FireStoreUtils.deleteEmployeeRole(model.id!);
                                  controller.employeeRolelList.remove(model);
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: c.brand,
            foregroundColor: c.onBrand,
            onPressed: () {
              if (Constant.userModel?.vendorID == null || Constant.userModel?.vendorID == '') {
                ShowToastDialog.showToast("Please add your restaurant details before creating a employee role.".tr);
              } else {
                Get.to(const AddEditRoleScreen())!.then((value) {
                  if (value == true) {
                    controller.getAllEmployeeRoles();
                  }
                });
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: Text("Create Role".tr),
          ),
        );
      },
    );
  }
}

/// Role card: key icon, title, status, permission coverage bar, edit/delete.
class _RoleCard extends StatelessWidget {
  final EmployeeRoleModel model;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _RoleCard({required this.model, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final permissions = model.permissions ?? [];
    final granted = permissions.where((p) => p.isActive == true).length;
    final isEnabled = model.isEnable ?? true;
    return DsCard.outlined(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.xs, DsSpace.lg),
      semanticLabel: model.title ?? '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsIconWell(icon: Icons.key_rounded, tone: isEnabled ? DsTone.brand : DsTone.neutral),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(model.title ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSm.withColor(c.textPrimary)),
                    const DsGap(DsSpace.xs),
                    DsStatusChip(label: isEnabled ? "Active".tr : "Inactive".tr, tone: isEnabled ? DsTone.success : DsTone.neutral),
                  ],
                ),
              ),
              DsIconButton(icon: Icons.edit_outlined, semanticLabel: 'Edit Role'.tr, onPressed: onTap),
              DsIconButton(icon: Icons.delete_outline_rounded, semanticLabel: 'Delete'.tr, color: c.danger, onPressed: onDelete),
            ],
          ),
          if (permissions.isNotEmpty) ...[
            const DsGap(DsSpace.md),
            Padding(
              padding: const EdgeInsets.only(right: DsSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text("Permissions".tr, style: t.caption)),
                      Text('$granted / ${permissions.length}', style: t.labelSm.withColor(c.textSecondary).tabular),
                    ],
                  ),
                  const DsGap(DsSpace.xs),
                  DsProgressBar(value: granted / permissions.length, height: 6, tone: isEnabled ? DsTone.brand : DsTone.neutral),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/controller/add_edit_role_controller.dart';
import 'package:vendor/themes/ds/ds.dart';

class AddEditRoleScreen extends StatelessWidget {
  const AddEditRoleScreen({super.key});

  /// Presentation-only grouping of the fixed permission titles. Anything not
  /// listed here falls into "Other" so nothing is ever hidden.
  static const Map<String, String> _groupOf = {
    "Store Information's": 'Store',
    'Working Hours': 'Store',
    'Add Story': 'Store',
    'Advertisement': 'Store',
    'Manage Products': 'Catalog & orders',
    'Manage Order': 'Catalog & orders',
    'Offers': 'Catalog & orders',
    'Special Discounts': 'Catalog & orders',
    'Add Dine in': 'Dine in',
    'Dine in Request': 'Dine in',
    'Manage Delivery Man': 'Team',
    'Employee Role': 'Team',
    'All Employee': 'Team',
    'Withdraw Method': 'Finance',
  };

  static const Map<String, IconData> _groupIcon = {
    'Store': Icons.storefront_outlined,
    'Catalog & orders': Icons.inventory_2_outlined,
    'Dine in': Icons.table_restaurant_outlined,
    'Team': Icons.groups_2_outlined,
    'Finance': Icons.account_balance_wallet_outlined,
    'Other': Icons.tune_rounded,
  };

  static const Map<String, IconData> _permissionIcon = {
    "Store Information's": Icons.info_outline_rounded,
    'Working Hours': Icons.schedule_rounded,
    'Add Story': Icons.amp_stories_outlined,
    'Advertisement': Icons.campaign_outlined,
    'Manage Products': Icons.inventory_2_outlined,
    'Manage Order': Icons.receipt_long_outlined,
    'Offers': Icons.local_offer_outlined,
    'Special Discounts': Icons.percent_rounded,
    'Add Dine in': Icons.table_restaurant_outlined,
    'Dine in Request': Icons.event_seat_outlined,
    'Manage Delivery Man': Icons.delivery_dining_outlined,
    'Employee Role': Icons.admin_panel_settings_outlined,
    'All Employee': Icons.badge_outlined,
    'Withdraw Method': Icons.account_balance_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: AddEditRoleController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final l = context.dsLayout;
        final title = Get.arguments == null ? "Create Role".tr : "Edit Role".tr;
        return DsScaffold(
          title: title,
          maxContentWidth: DsLayout.wideMax,
          body: controller.isLoading.value
              ? const DsResponsive(child: DsSkeletonForm(fields: 6))
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, DsSpace.xxl),
                  child: DsResponsive(
                    maxWidth: 960,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: DsFadeSlideIn.stagger([
                        // ── Role details ─────────────────────
                        DsFormSection(
                          title: title,
                          icon: Icons.key_rounded,
                          children: [
                            DsTextField(label: 'Role Name'.tr, controller: controller.nameController.value, hint: 'Role Name'.tr, prefixIcon: Icons.badge_outlined),
                            Padding(
                              padding: const EdgeInsets.only(bottom: DsSpace.md),
                              child: Container(
                                decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
                                child: DsListTile(
                                  title: "Active".tr,
                                  leadingIcon: controller.isActive.value ? Icons.toggle_on_outlined : Icons.toggle_off_outlined,
                                  leadingTone: controller.isActive.value ? DsTone.success : DsTone.neutral,
                                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                                  trailing: Switch.adaptive(
                                    value: controller.isActive.value,
                                    onChanged: (value) {
                                      controller.isActive.value = value;
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // ── Permission matrix ────────────────
                        Obx(() {
                          final total = controller.permissionList.length;
                          final granted = controller.permissionList.where((p) => p.isActive == true).length;
                          return DsCard(
                            margin: const EdgeInsets.only(bottom: DsSpace.xl),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const DsIconWell(icon: Icons.admin_panel_settings_outlined, size: 36),
                                    const DsGap(DsSpace.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Permissions".tr, style: t.titleSm.withColor(c.textPrimary)),
                                          Text('$granted / $total', style: t.bodySm.withColor(c.textSecondary).tabular),
                                        ],
                                      ),
                                    ),
                                    Text('All'.tr, style: t.label.withColor(c.textPrimary)),
                                    const DsGap(DsSpace.xs),
                                    Semantics(
                                      label: 'All'.tr,
                                      child: Switch.adaptive(
                                        value: controller.isAllPermission.value,
                                        onChanged: (bool value) {
                                          controller.isAllPermission.value = value;
                                          controller.setAllPermission(selectAll: value);
                                          controller.permissionList.refresh();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const DsGap(DsSpace.md),
                                DsProgressBar(value: total == 0 ? 0 : granted / total, height: 6),
                              ],
                            ),
                          );
                        }),
                        _PermissionMatrix(controller: controller),
                      ]),
                    ),
                  ),
                ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Save Role".tr,
              icon: Icons.check_rounded,
              expand: true,
              onPressed: () async {
                controller.saveEmployeeRole();
              },
            ),
          ),
        );
      },
    );
  }
}

class _PermissionMatrix extends StatelessWidget {
  final AddEditRoleController controller;
  const _PermissionMatrix({required this.controller});

  void _toggle(int index, bool? value) {
    bool selectAll = false;
    selectAll = value ?? false;
    controller.permissionList[index].isActive = selectAll;
    controller.permissionList.refresh();
    controller.isAllPermission.value = controller.permissionList.every((item) => item.isActive == true);
  }

  // Tracks permissionList in its own observer (a parent Obx cannot see reads
  // made in this child's build).
  @override
  Widget build(BuildContext context) => DsObserve(builder: _build);

  Widget _build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    // Group indices (not models) so every switch still writes to permissionList[index].
    final groups = <String, List<int>>{};
    for (int i = 0; i < controller.permissionList.length; i++) {
      final key = AddEditRoleScreen._groupOf[controller.permissionList[i].title] ?? 'Other';
      groups.putIfAbsent(key, () => []).add(i);
    }
    final order = ['Store', 'Catalog & orders', 'Dine in', 'Team', 'Finance', 'Other'].where(groups.containsKey).toList();

    return DsAdaptiveGrid(
      minItemWidth: 340,
      maxColumns: 2,
      equalHeight: false,
      runSpacing: DsSpace.lg,
      spacing: DsSpace.lg,
      children: [
        for (int g = 0; g < order.length; g++)
          DsFadeSlideIn(
            index: g,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: DsSpace.xs, bottom: DsSpace.sm),
                  child: Row(
                    children: [
                      Icon(AddEditRoleScreen._groupIcon[order[g]], size: 16, color: c.textMuted),
                      const DsGap(DsSpace.xs),
                      Expanded(child: Text(order[g].tr.toUpperCase(), style: t.overline.withColor(c.textMuted))),
                      Text(
                        '${groups[order[g]]!.where((i) => controller.permissionList[i].isActive == true).length}/${groups[order[g]]!.length}',
                        style: t.labelSm.withColor(c.textMuted).tabular,
                      ),
                    ],
                  ),
                ),
                DsTileGroup(
                  dividerIndent: 64,
                  children: [
                    for (final index in groups[order[g]]!)
                      DsListTile(
                        title: controller.permissionList[index].title?.tr ?? '',
                        leadingIcon: AddEditRoleScreen._permissionIcon[controller.permissionList[index].title] ?? Icons.lock_open_rounded,
                        leadingTone: controller.permissionList[index].isActive == true ? DsTone.brand : DsTone.neutral,
                        onTap: () => _toggle(index, !(controller.permissionList[index].isActive ?? false)),
                        trailing: Switch.adaptive(
                          value: controller.permissionList[index].isActive ?? false,
                          onChanged: (bool value) => _toggle(index, value),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

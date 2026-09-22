import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/app/add_restaurant_screen/add_restaurant_screen.dart';
import 'package:vendor/app/employee_screens/add_employee_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/employee_list_controller.dart';
import 'package:vendor/models/employee_role_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class EmployeeListScreen extends StatelessWidget {
  const EmployeeListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: EmployeeListController(),
      builder: (controller) {
        final c = context.dsColors;
        return DsScaffold.collapsing(
          title: "Manage Employees".tr,
          backgroundColor: c.background,
          actions: [
            DsButton.tonal(
              label: "Add".tr,
              icon: Icons.person_add_alt_1_rounded,
              size: DsButtonSize.sm,
              onPressed: () async {
                if (Constant.userModel?.vendorID?.isEmpty == true || Constant.userModel?.vendorID == null) {
                  ShowToastDialog.showToast("Please add your restaurant details before creating a employee user.".tr);
                } else {
                  ShowToastDialog.showLoader("Please wait".tr);
                  List<EmployeeRoleModel> employeeRolelList = await FireStoreUtils.getAllEmployeeRoles(isActive: true);
                  ShowToastDialog.closeLoader();
                  if (employeeRolelList.isEmpty == true) {
                    ShowToastDialog.showToast("Please add at least one active employee role before creating an employee user.".tr);
                  } else {
                    Get.to(const AddEmployeeScreen())?.then((value) {
                      if (value == true) {
                        Get.back();
                      }
                    });
                  }
                }
              },
            ),
          ],
          slivers: [
            if (controller.isLoading.value)
              DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                top: DsSpace.sm,
                sliver: SliverToBoxAdapter(
                  child: DsShimmer(
                    child: DsAdaptiveGrid(
                      minItemWidth: 300,
                      maxColumns: 3,
                      children: List.generate(6, (_) => DsSkeleton.box(height: 170, radius: DsRadius.lg)),
                    ),
                  ),
                ),
              )
            else if (Constant.userModel?.vendorID?.isEmpty == true || Constant.userModel?.vendorID == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(
                  illustration: _SvgHalo(asset: "assets/icons/ic_building_two.svg"),
                  title: "Add Your First Restaurant".tr,
                  message: "Get started by adding your restaurant details to manage your employee men.".tr,
                  actionLabel: "Add Store".tr,
                  actionIcon: Icons.storefront_outlined,
                  onAction: () async {
                    Get.to(const AddRestaurantScreen())?.then((value) {
                      controller.update();
                    });
                  },
                ),
              )
            else if (controller.employeeUserList.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(
                  illustration: Center(
                    child: SvgPicture.asset("assets/icons/ic_employee.svg", height: 96, colorFilter: ColorFilter.mode(c.textMuted, BlendMode.srcIn)),
                  ),
                  title: "No Employees Available".tr,
                  message: "No Employees found! Add your first employee to start managing your team.".tr,
                  actionLabel: "Add Employees".tr,
                  actionIcon: Icons.person_add_alt_1_rounded,
                  onAction: () async {
                    Get.to(const AddEmployeeScreen())?.then((value) {
                      if (value == true) {
                        Get.back();
                      }
                    });
                  },
                ),
              )
            else ...[
              DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                top: DsSpace.sm,
                sliver: SliverToBoxAdapter(
                  child: GetBuilder<EmployeeListController>(
                    builder: (controller) {
                      final total = controller.employeeUserList.length;
                      final active = controller.employeeUserList.where((e) => e.active == true).length;
                      return DsAdaptiveGrid(
                        minItemWidth: 150,
                        children: DsFadeSlideIn.stagger([
                          DsStatTile(label: "Total".tr, countTo: total, icon: Icons.groups_2_outlined, tone: DsTone.brand),
                          DsStatTile(label: "Active".tr, countTo: active, icon: Icons.how_to_reg_outlined, tone: DsTone.success, variant: DsStatTileVariant.tinted),
                        ]),
                      );
                    },
                  ),
                ),
              ),
              DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                top: DsSpace.xl,
                bottom: DsSpace.lg,
                sliver: SliverToBoxAdapter(
                  child: DsAdaptiveGrid(
                    minItemWidth: 300,
                    maxColumns: 3,
                    children: [
                      for (int index = 0; index < controller.employeeUserList.length; index++)
                        DsFadeSlideIn(
                          index: index,
                          child: _EmployeeCard(
                            employee: controller.employeeUserList[index],
                            onTap: () {
                              Get.to(const AddEmployeeScreen(), arguments: {"employeemodel": controller.employeeUserList[index]})?.then((value) {
                                if (value == true) {
                                  controller.getAllEmployeeList();
                                }
                              });
                            },
                            role: FutureBuilder<EmployeeRoleModel?>(
                              future: FireStoreUtils.getEmployeeRoleById(controller.employeeUserList[index].employeePermissionId!),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting || snapshot.hasError) {
                                  return const SizedBox(height: 18, width: 18, child: DsSpinner(size: 16));
                                }
                                if (!snapshot.hasData) {
                                  return const DsBadge(
                                    label: "Role not assigned.", // use actual field from EmployeeRoleModel
                                    tone: DsTone.warning,
                                    icon: Icons.help_outline_rounded,
                                    small: true,
                                  );
                                }

                                final role = snapshot.data;
                                return Semantics(
                                  button: true,
                                  label: "Permissions".tr,
                                  child: DsPressable(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return showListOfRoleDialog(context, role!);
                                        },
                                      );
                                    },
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(minHeight: 32),
                                      child: Center(
                                        widthFactor: 1,
                                        child: DsBadge(
                                          label: role?.title ?? "Unknown Role", // use actual field from EmployeeRoleModel
                                          tone: DsTone.brand,
                                          icon: Icons.verified_user_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            toggle: GetBuilder<EmployeeListController>(
                              builder: (controller) {
                                return _ActiveToggle(
                                  value: controller.employeeUserList[index].active ?? false,
                                  onChanged: (value) {
                                    controller.employeeUserList[index].active = value;
                                    controller.updateEmployee(controller.employeeUserList[index]);
                                    controller.update();
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget showListOfRoleDialog(BuildContext context, EmployeeRoleModel model) {
    final active = model.permissions!.where((e) => e.title != null && e.title!.isNotEmpty && e.isActive == true).map((e) => e.title!).toList();
    return DsDialog(
      title: "Permissions".tr,
      message: model.title,
      icon: Icons.admin_panel_settings_outlined,
      content: Wrap(
        alignment: WrapAlignment.center,
        spacing: DsSpace.sm,
        runSpacing: DsSpace.sm,
        children: active.map((e) => DsBadge(label: e, tone: DsTone.success, icon: Icons.check_rounded)).toList(),
      ),
      secondaryLabel: "Close".tr,
      onSecondary: () async {
        Get.back();
      },
    );
  }
}

/// Team member card: avatar + name + role on top, contact details, and a
/// footer with the live active switch.
class _EmployeeCard extends StatelessWidget {
  final UserModel employee;
  final VoidCallback onTap;
  final Widget role;
  final Widget toggle;
  const _EmployeeCard({required this.employee, required this.onTap, required this.role, required this.toggle});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final name = "${employee.firstName ?? ''} ${employee.lastName ?? ''}";
    return DsCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      semanticLabel: name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DsAvatar(
                  imageUrl: employee.profilePictureURL == null || employee.profilePictureURL == '' ? null : employee.profilePictureURL.toString(),
                  name: name,
                  size: 52,
                  ring: true,
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm.withColor(c.textPrimary)),
                      const DsGap(DsSpace.xs),
                      Align(alignment: AlignmentDirectional.centerStart, child: role),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
            child: Column(
              children: [
                _InfoLine(icon: Icons.phone_outlined, text: "${employee.countryCode} ${employee.phoneNumber}"),
                const DsGap(DsSpace.xs),
                _InfoLine(icon: Icons.mail_outline_rounded, text: employee.email.toString()),
              ],
            ),
          ),
          const Spacer(),
          const DsGap(DsSpace.md),
          Container(
            padding: const EdgeInsets.only(left: DsSpace.lg, right: DsSpace.sm),
            decoration: BoxDecoration(
              color: c.surfaceAlt.withValues(alpha: 0.5),
              border: Border(top: BorderSide(color: c.divider)),
            ),
            child: toggle,
          ),
        ],
      ),
    );
  }
}

class _ActiveToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ActiveToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedSwitcher(
              duration: DsMotion.of(context, DsMotion.fast),
              child: DsStatusChip(
                key: ValueKey(value),
                label: value ? "Active".tr : "Inactive".tr,
                tone: value ? DsTone.success : DsTone.neutral,
              ),
            ),
          ),
        ),
        Semantics(
          label: "Active".tr,
          child: Switch.adaptive(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Row(
      children: [
        DsIconWell(icon: icon, size: 28, tone: DsTone.neutral),
        const DsGap(DsSpace.sm),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm.withColor(c.textSecondary))),
      ],
    );
  }
}

class _SvgHalo extends StatelessWidget {
  final String asset;
  const _SvgHalo({required this.asset});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Center(
      child: Container(
        width: 120,
        height: 120,
        padding: const EdgeInsets.all(DsSpace.xxxl),
        decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle, border: Border.all(color: c.brand.withValues(alpha: 0.2))),
        child: SvgPicture.asset(asset),
      ),
    );
  }
}

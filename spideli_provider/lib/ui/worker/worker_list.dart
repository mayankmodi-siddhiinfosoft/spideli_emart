import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/all_workers_controller.dart';
import 'package:spideliprovider/controller/dashboard_controller.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/add_worker/add_or_update_worker.dart';
import 'package:spideliprovider/ui/dashboard/dashboard_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Workers directory (archetype G): avatar contact rows with an online status
/// dot, salary badge and a destructive action, in a 1/2/3 column adaptive
/// grid. This screen is a drawer tab of [DashBoardScreen], and it already had
/// its own Scaffold, so it keeps exactly one (as a [DsScaffold] without a bar).
class AllWorkersScreen extends StatelessWidget {
  const AllWorkersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes the page to theme changes.
    Provider.of<DarkThemeProvider>(context);
    return GetX<AllWorkersController>(
        init: AllWorkersController(),
        builder: (controller) {
          final l = context.dsLayout;
          return DsScaffold(
            maxContentWidth: DsLayout.wideMax,
            body: DsAsync(
              isLoading: false,
              isEmpty: controller.user.isEmpty,
              empty: DsEmptyState(
                icon: Icons.groups_outlined,
                title: 'Worker not available.'.tr,
                message: 'Add your team members so you can assign them to bookings.'.tr,
              ),
              builder: (_) => GridView.builder(
                padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.md, l.gutter, DsSpace.huge + DsSpace.xxl),
                gridDelegate: DsLayout.gridDelegate(maxItemWidth: 420, mainAxisExtent: 136),
                itemCount: controller.user.length,
                itemBuilder: (context, index) {
                  return DsFadeSlideIn(
                    index: index,
                    child: buildCategoryItem(controller.user[index], context, controller),
                  );
                },
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                Get.to(const AddOrUpdateWorkerScreen())!.then((value) {
                  if (value != null) {
                    controller.getData();
                  }
                });
              },
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text('Add Worker'.tr),
            ),
          );
        });
  }

  Widget buildCategoryItem(User model, BuildContext context, controller) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool isOnline = model.online == true;
    return DsCard.outlined(
      padding: const EdgeInsets.all(DsSpace.md),
      semanticLabel: model.fullName(),
      onTap: () async {
        Get.to(const AddOrUpdateWorkerScreen(), arguments: {
          "User": model,
        })!
            .then((value) {
          if (value != null) {
            controller.getData();
          }
        });
      },
      child: Row(
        children: [
          DsAvatar(
            imageUrl: model.profilePictureURL,
            name: model.fullName(),
            size: 54,
            ring: isOnline,
            statusTone: isOnline ? DsTone.success : DsTone.neutral,
          ),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  model.firstName + ' ' + model.lastName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSm,
                ),
                const DsGap(DsSpace.xxs),
                Text(
                  model.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySm,
                ),
                const DsGap(DsSpace.sm),
                Row(
                  children: [
                    DsStatusChip(
                      label: model.online == false ? "Offline".tr : "Online".tr,
                      tone: isOnline ? DsTone.success : DsTone.neutral,
                      pulse: isOnline,
                    ),
                    const DsGap(DsSpace.sm),
                    Flexible(
                      child: Text(
                        amountShow(amount: model.salary!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.labelSm.withColor(c.textSecondary).tabular,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          DsIconButton(
            icon: Icons.delete_outline_rounded,
            semanticLabel: 'Delete'.tr,
            variant: DsIconButtonVariant.tonal,
            color: c.dangerStrong,
            size: 36,
            onPressed: () {
              showWorkerDeleteDialog(model, context, controller);
            },
          ),
        ],
      ),
    );
  }

  showWorkerDeleteDialog(User User, BuildContext context, controller) {
    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DsDialog(
          title: User.fullName(),
          message: 'Are you sure you want to delete this worker?'.tr,
          icon: Icons.person_remove_alt_1_outlined,
          tone: DsTone.danger,
          destructive: true,
          primaryLabel: "Ok".tr,
          onPrimary: () async {
            ShowToastDialog.showLoader("Please wait".tr);

            FireStoreUtils.deleteWorker(User.id).then((value) async {
              ShowToastDialog.closeLoader();
              controller.getData();
              DashBoardController dashBoardController = Get.put(DashBoardController());
              dashBoardController.onSelectItem(2);
              await Get.to(const DashBoardScreen());
            });
          },
          secondaryLabel: "Cancel".tr,
          onSecondary: () {
            Get.back();
          },
        );
      },
    );
  }
}

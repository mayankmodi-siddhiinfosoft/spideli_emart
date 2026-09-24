import 'package:spideliprovider/services/provider_verification_gate.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/assign_worker_controller.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/send_notification.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class AssignWorkerList extends StatelessWidget {
  const AssignWorkerList({super.key});

  @override
  Widget build(BuildContext context) {
    // Keeps this widget subscribed to dark-mode changes; colors come from the DS.
    Provider.of<DarkThemeProvider>(context);
    return GetBuilder<AssignWorkerController>(
        init: AssignWorkerController(),
        builder: (controller) {
          final c = context.dsColors;
          final t = context.dsText;
          final l = context.dsLayout;

          return DsScaffold(
            title: "Worker List".tr,
            subtitle: controller.user.isEmpty ? null : '${controller.user.length} ${'online'.tr}',
            maxContentWidth: DsLayout.contentMax,
            body: controller.user.isEmpty
                ? DsEmptyState(
                    icon: Icons.groups_outlined,
                    title: "No online worker available".tr,
                    message: 'Workers appear here as soon as they come online.'.tr,
                  )
                : ListView.builder(
                    itemCount: controller.user.length,
                    padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
                    itemBuilder: (context, index) {
                      User worker = controller.user[index];
                      final bool selected = controller.selectedWorkerRadioTile.value == worker.id;

                      return DsFadeSlideIn(
                        index: index,
                        child: Semantics(
                          inMutuallyExclusiveGroup: true,
                          selected: selected,
                          child: DsCard.outlined(
                          margin: const EdgeInsets.only(bottom: DsSpace.md),
                          padding: const EdgeInsets.all(DsSpace.md),
                          borderColor: selected ? c.brand : null,
                          color: selected ? c.brandSoft : null,
                          semanticLabel: worker.fullName().toString(),
                          onTap: () {
                            controller.selectedWorkerRadioTile.value = worker.id;
                            controller.fcmToken.value = worker.fcmToken.toString();
                            controller.update();
                          },
                          child: Row(
                            children: [
                              DsAvatar(
                                imageUrl: worker.profilePictureURL != "" ? worker.profilePictureURL.toString() : placeholderImage,
                                name: worker.fullName().toString(),
                                size: 52,
                                ring: selected,
                                statusTone: DsTone.success,
                              ),
                              const DsGap(DsSpace.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      worker.fullName().toString(),
                                      style: t.titleSm,
                                    ),
                                    const DsGap(DsSpace.xs),
                                    DsStatusChip(label: "Online".tr, tone: DsTone.success, pulse: true),
                                  ],
                                ),
                              ),
                              const DsGap(DsSpace.sm),
                              Icon(
                                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                                color: selected ? c.brand : c.iconDefault,
                                size: 24,
                              ),
                            ],
                          ),
                          ),
                        ),
                      );
                    }),
            bottomBar: DsStickyBar(
              child: DsButton.primary(
                label: 'Assign'.tr,
                icon: Icons.person_add_alt_1_rounded,
                expand: true,
                onPressed: () async {
                  if (controller.selectedWorkerRadioTile.value.isEmpty) {
                    ShowToastDialog.showToast('Please select worker.'.tr);
                  } else {
                    if (await ProviderVerificationGate.blocks()) return;
                    ShowToastDialog.showLoader('Please wait...');
                    final String previousWorkerId = controller.onProviderOrder.value.workerId ?? '';
                    final String newWorkerId = controller.selectedWorkerRadioTile.value.toString();
                    final User? selected = controller.user.firstWhereOrNull((w) => w.id == newWorkerId);
                    controller.onProviderOrder.value.workerId = newWorkerId;
                    controller.onProviderOrder.value.status = ORDER_STATUS_ASSIGNED;
                    await FireStoreUtils.updateOrder(controller.onProviderOrder.value);
                    // Manual assignment log (spec 10), append-only.
                    if (previousWorkerId != newWorkerId) {
                      await FireStoreUtils.logWorkerAssignment(
                        orderId: controller.onProviderOrder.value.id,
                        workerId: newWorkerId,
                        workerName: selected?.fullName().trim() ?? '',
                        previousWorkerId: previousWorkerId,
                      );
                    }
                    Map<String, dynamic> payLoad = <String, dynamic>{"type": "provider_order", "orderId": controller.onProviderOrder.value.id};
                    await SendNotification.sendFcmMessage(workerBookingAssigned, controller.fcmToken.value, payLoad);

                    Get.back();
                    ShowToastDialog.closeLoader();
                  }
                },
              ),
            ),
          );
        });
  }
}

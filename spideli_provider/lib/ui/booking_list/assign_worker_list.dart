import 'dart:async';

import 'package:spideliprovider/services/provider_verification_gate.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/assign_worker_controller.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/model/worker_verification.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/booking_notifier.dart';
import 'package:spideliprovider/services/booking_push.dart';
import 'package:spideliprovider/services/worker_verification_service.dart';
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
            body: controller.isLoading.value
                ? const DsSkeletonList(itemCount: 4)
                : controller.user.isEmpty
                ? DsEmptyState(
                    icon: Icons.groups_outlined,
                    title: "No online worker available".tr,
                    message: 'Workers appear here as soon as they come online.'.tr,
                  )
                : ListView.builder(
                    itemCount: controller.user.length + (controller.hiddenUnverified > 0 ? 1 : 0),
                    padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
                    itemBuilder: (context, index) {
                      if (controller.hiddenUnverified > 0) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: DsSpace.md),
                            child: DsInlineAlert(
                              tone: DsTone.warning,
                              message: "Online workers whose documents are not approved cannot be assigned. Review them in Worker verification.".tr,
                            ),
                          );
                        }
                        index -= 1;
                      }
                      User worker = controller.user[index];
                      final bool selected = controller.selectedWorkerRadioTile.value == worker.id;
                      // Every required document uploaded and approved (or
                      // verification off); anyone else is greyed out with the
                      // reason and cannot be selected.
                      final bool assignable = controller.canAssign(worker);
                      final WorkerAssignmentRefusal? refusal = controller.refusalOf(worker);

                      return DsFadeSlideIn(
                        index: index,
                        child: Semantics(
                          inMutuallyExclusiveGroup: true,
                          selected: selected,
                          enabled: assignable,
                          child: DsCard.outlined(
                          margin: const EdgeInsets.only(bottom: DsSpace.md),
                          padding: const EdgeInsets.all(DsSpace.md),
                          borderColor: selected ? c.brand : null,
                          color: selected ? c.brandSoft : null,
                          semanticLabel: assignable || refusal == null
                              ? worker.fullName().toString()
                              : '${worker.fullName()}, ${WorkerVerificationRules.assignmentRefusalLabel(refusal).tr}',
                          onTap: () {
                            if (!assignable) {
                              ShowToastDialog.showToast(WorkerVerificationRules.assignmentRefusalMessage(refusal ?? WorkerAssignmentRefusal.unknown).tr);
                              return;
                            }
                            controller.selectedWorkerRadioTile.value = worker.id;
                            controller.fcmToken.value = worker.fcmToken.toString();
                            controller.update();
                          },
                          child: Opacity(
                          opacity: assignable ? 1 : 0.5,
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
                                    Wrap(
                                      spacing: DsSpace.sm,
                                      runSpacing: DsSpace.xs,
                                      children: [
                                        DsStatusChip(label: "Online".tr, tone: DsTone.success, pulse: true),
                                        if (!assignable)
                                          DsStatusChip(
                                            label: WorkerVerificationRules.assignmentRefusalLabel(refusal ?? WorkerAssignmentRefusal.unknown).tr,
                                            tone: refusal == WorkerAssignmentRefusal.pendingReview ? DsTone.warning : DsTone.danger,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const DsGap(DsSpace.sm),
                              Icon(
                                !assignable
                                    ? Icons.block_rounded
                                    : selected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                color: selected ? c.brand : c.iconDefault,
                                size: 24,
                              ),
                            ],
                          ),
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
                    final String previousStatus = controller.onProviderOrder.value.status;
                    final String newWorkerId = controller.selectedWorkerRadioTile.value.toString();
                    final User? selected = controller.user.firstWhereOrNull((w) => w.id == newWorkerId);
                    // Assignment and reassignment: the worker's documents are
                    // validated again at this moment, inside the write's
                    // transaction (live documents_verify record + required
                    // types read from the server, never the flag alone).
                    WorkerAssignmentRefusal? refusal;
                    try {
                      refusal = await WorkerVerificationService.assignWorker(
                        order: controller.onProviderOrder.value,
                        workerId: newWorkerId,
                        assignedStatus: ORDER_STATUS_ASSIGNED,
                      );
                    } catch (e) {
                      controller.onProviderOrder.value.workerId = previousWorkerId;
                      controller.onProviderOrder.value.status = previousStatus;
                      ShowToastDialog.closeLoader();
                      ShowToastDialog.showToast('Could not assign the worker. Check your connection and try again.'.tr);
                      return;
                    }
                    if (refusal != null) {
                      controller.onProviderOrder.value.workerId = previousWorkerId;
                      controller.onProviderOrder.value.status = previousStatus;
                      ShowToastDialog.closeLoader();
                      ShowToastDialog.showToast(WorkerVerificationRules.assignmentRefusalMessage(refusal).tr);
                      await controller.getData();
                      return;
                    }
                    // Manual assignment log (spec 10), append-only.
                    if (previousWorkerId != newWorkerId) {
                      await FireStoreUtils.logWorkerAssignment(
                        orderId: controller.onProviderOrder.value.id,
                        workerId: newWorkerId,
                        workerName: selected?.fullName().trim() ?? '',
                        previousWorkerId: previousWorkerId,
                      );
                    }
                    // The new worker (worker_assigned), the previous one on a
                    // reassignment (worker_unassigned) and the customer
                    // (worker_assigned_customer); nothing when the same worker
                    // was picked again. Never blocks the assignment.
                    unawaited(BookingNotifier.notify(
                      ProviderBookingAction.assignWorker,
                      controller.onProviderOrder.value,
                      previousWorkerId: previousWorkerId,
                      workerToken: controller.fcmToken.value,
                    ));

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

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:spideliprovider/controller/worker_verification_controller.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/model/worker_verification.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/worker/worker_document_review_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';

/// Label, tone and icon of a worker's overall status (Not submitted /
/// Pending / Action required / Verified).
extension WorkerOverallStatusUi on WorkerOverallStatus {
  String get label => WorkerVerificationStatusRules.overallLabel(this).tr;

  DsTone get tone {
    switch (this) {
      case WorkerOverallStatus.verified:
        return DsTone.success;
      case WorkerOverallStatus.pending:
        return DsTone.warning;
      case WorkerOverallStatus.actionRequired:
        return DsTone.danger;
      case WorkerOverallStatus.notSubmitted:
        return DsTone.neutral;
    }
  }

  IconData get icon {
    switch (this) {
      case WorkerOverallStatus.verified:
        return Icons.verified_user_outlined;
      case WorkerOverallStatus.pending:
        return Icons.hourglass_top_rounded;
      case WorkerOverallStatus.actionRequired:
        return Icons.gpp_bad_outlined;
      case WorkerOverallStatus.notSubmitted:
        return Icons.shield_outlined;
    }
  }
}

/// "Document type: Worker" -- the record type of the documents listed or
/// reviewed (`documents_verify.type == "worker"`).
class WorkerDocumentTypeBadge extends StatelessWidget {
  const WorkerDocumentTypeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DsBadge(
      label: '${'Document type'.tr}: ${WorkerVerificationStatusRules.recordTypeLabel(WorkerVerificationRules.workerType).tr}',
      icon: Icons.badge_outlined,
      tone: DsTone.info,
      small: true,
    );
  }
}

/// The provider's workers and their overall status (Not submitted / Pending /
/// Action required / Verified), with the counts per status (tap a count to
/// filter), all live. A worker opens their document review
/// ([WorkerDocumentReviewScreen]).
class WorkerVerificationScreen extends StatelessWidget {
  const WorkerVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Provider.of<DarkThemeProvider>(context);
    return GetX<WorkerVerificationController>(
      init: WorkerVerificationController(),
      global: false,
      builder: (controller) {
        final l = context.dsLayout;
        final c = context.dsColors;
        Widget body;
        if (controller.isLoading.value) {
          body = const DsSkeletonList(itemCount: 6);
        } else if (controller.loadFailed.value) {
          body = DsErrorState(
            title: 'Could not load the workers\' documents'.tr,
            message: 'Check your connection and try again.'.tr,
            onRetry: controller.load,
            retryLabel: 'Retry'.tr,
          );
        } else {
          final visible = controller.visible;
          body = RefreshIndicator(
            onRefresh: controller.load,
            color: c.brand,
            backgroundColor: c.surface,
            child: ListView(
              padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
              children: [
                if (controller.verificationRequired.value == false) ...[
                  DsInlineAlert(
                    tone: DsTone.info,
                    message: 'Worker verification is switched off by the administrator: your workers can receive jobs without approved documents.'.tr,
                  ),
                  const DsGap(DsSpace.lg),
                ],
                if (controller.types.isEmpty) ...[
                  DsInlineAlert(
                    tone: DsTone.info,
                    message: 'The administrator has not set up any worker documents yet.'.tr,
                  ),
                  const DsGap(DsSpace.lg),
                ],
                const Align(alignment: AlignmentDirectional.centerStart, child: WorkerDocumentTypeBadge()),
                const DsGap(DsSpace.md),
                DsAdaptiveGrid(
                  minItemWidth: 150,
                  children: WorkerOverallStatus.values
                      .map((state) => DsStatTile(
                            label: state.label,
                            value: '${controller.countOf(state)}',
                            icon: state.icon,
                            tone: state.tone,
                            variant: controller.filter.value == state ? DsStatTileVariant.tinted : DsStatTileVariant.surface,
                            onTap: () => controller.filter.value = controller.filter.value == state ? null : state,
                          ))
                      .toList(),
                ),
                const DsGap(DsSpace.lg),
                if (controller.filter.value != null) ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DsButton.ghost(
                      label: '${'Show all workers'.tr} (${controller.workers.length})',
                      icon: Icons.filter_alt_off_outlined,
                      onPressed: () => controller.filter.value = null,
                    ),
                  ),
                  const DsGap(DsSpace.sm),
                ],
                if (visible.isEmpty)
                  DsEmptyState(
                    compact: true,
                    icon: Icons.groups_outlined,
                    title: controller.workers.isEmpty ? 'Worker not available.'.tr : 'No worker in this state'.tr,
                  )
                else
                  ...visible.map((worker) => _WorkerRow(worker: worker, state: controller.stateOf(worker))),
              ],
            ),
          );
        }
        return DsScaffold(title: 'Worker verification'.tr, maxContentWidth: DsLayout.contentMax, body: body);
      },
    );
  }
}

class _WorkerRow extends StatelessWidget {
  final User worker;
  final WorkerOverallStatus state;

  const _WorkerRow({required this.worker, required this.state});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    final c = context.dsColors;
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.md),
      semanticLabel: '${worker.fullName()}, ${state.label}',
      // The list is live: a decision taken on the review screen shows here
      // without a reload.
      onTap: () => Get.to(() => WorkerDocumentReviewScreen(workerId: worker.id)),
      child: Row(
        children: [
          DsAvatar(imageUrl: worker.profilePictureURL, name: worker.fullName(), size: 48),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(worker.fullName(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                const DsGap(DsSpace.xs),
                DsStatusChip(label: state.label, tone: state.tone),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textMuted),
        ],
      ),
    );
  }
}

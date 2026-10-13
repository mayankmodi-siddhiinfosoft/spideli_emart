import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/worker_document_review_controller.dart';
import 'package:spideliprovider/model/document_model.dart';
import 'package:spideliprovider/model/worker_verification.dart';
import 'package:spideliprovider/services/worker_verification_service.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/worker/worker_verification_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';

/// The provider reviews one of ITS workers' documents: each required document
/// (admin `documents` types `worker`, enabled) with its images (full screen
/// on tap), number, expiry, status and the reason of a rejection; Approve /
/// Reject (reason required) per document and "Approve all uploaded".
/// The worker is verified once every required document is approved.
class WorkerDocumentReviewScreen extends StatelessWidget {
  final String workerId;

  const WorkerDocumentReviewScreen({super.key, required this.workerId});

  @override
  Widget build(BuildContext context) {
    Provider.of<DarkThemeProvider>(context);
    return GetX<WorkerDocumentReviewController>(
      init: WorkerDocumentReviewController(workerId),
      global: false,
      builder: (controller) {
        final l = context.dsLayout;
        Widget body;
        if (controller.isLoading.value) {
          body = const DsSkeletonList(itemCount: 4);
        } else if (controller.notYourWorker.value) {
          body = DsEmptyState(icon: Icons.lock_outline_rounded, tone: DsTone.warning, title: 'You can only review the documents of your own workers.'.tr);
        } else if (controller.typesLoadFailed.value) {
          body = DsErrorState(title: 'Could not load the documents to review'.tr, message: 'Check your connection and try again.'.tr, onRetry: controller.load, retryLabel: 'Retry'.tr);
        } else if (controller.types.isEmpty) {
          body = DsEmptyState(icon: Icons.folder_off_outlined, tone: DsTone.neutral, title: 'The administrator has not set up any worker documents yet.'.tr);
        } else {
          body = ListView(
            padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
            children: [
              _Summary(controller: controller),
              const DsGap(DsSpace.lg),
              ...controller.types.map((type) => _DocumentCard(controller: controller, type: type)),
            ],
          );
        }
        final bool showApproveAll = !controller.isLoading.value && !controller.notYourWorker.value && !controller.typesLoadFailed.value && controller.hasPending;
        return DsScaffold(
          title: controller.worker.value?.fullName() ?? 'Worker documents'.tr,
          subtitle: controller.isLoading.value || controller.notYourWorker.value ? null : controller.state.label,
          maxContentWidth: DsLayout.contentMax,
          body: body,
          bottomBar: showApproveAll
              ? DsStickyBar(
                  child: DsButton.primary(
                    label: 'Approve all uploaded'.tr,
                    icon: Icons.done_all_rounded,
                    size: DsButtonSize.lg,
                    expand: true,
                    loading: controller.busy.value,
                    onPressed: controller.canAct ? () => _approveAll(controller) : null,
                  ),
                )
              : null,
        );
      },
    );
  }

  static String _titles(List<DocumentType> types) => types.map((t) => t.title.tr).join(', ');

  /// Says what happened; false when nothing was written.
  static bool _report(WorkerReviewResult result) {
    if (result.failed) {
      ShowToastDialog.showToast('Could not save the decision. Check your connection and try again.'.tr);
      return false;
    }
    switch (result.outcome.refusal) {
      case WorkerReviewRefusal.notYourWorker:
        ShowToastDialog.showToast('You can only review the documents of your own workers.'.tr);
        return false;
      case WorkerReviewRefusal.notSent:
        ShowToastDialog.showToast('This document has not been uploaded yet.'.tr);
        return false;
      case WorkerReviewRefusal.expired:
        ShowToastDialog.showToast('This document has expired. The worker must upload a valid one.'.tr);
        return false;
      case WorkerReviewRefusal.reasonRequired:
        ShowToastDialog.showToast('Please enter the reason for the rejection.'.tr);
        return false;
      case WorkerReviewRefusal.typesUnknown:
        ShowToastDialog.showToast('Could not load the documents to review'.tr);
        return false;
      case WorkerReviewRefusal.nothingToApprove:
      case null:
        return true;
    }
  }

  static Future<void> _approve(WorkerDocumentReviewController controller, DocumentType type) async {
    final result = await controller.approve(type);
    if (!_report(result)) return;
    ShowToastDialog.showToast(result.outcome.setVerified == true ? 'Worker verified. They can now receive jobs.'.tr : 'Document approved.'.tr);
  }

  static Future<void> _reject(WorkerDocumentReviewController controller, DocumentType type) async {
    final String? reason = await _askReason(type);
    if (reason == null) return;
    final result = await controller.reject(type, reason);
    if (!_report(result)) return;
    ShowToastDialog.showToast('Document rejected. The worker has been asked to upload it again.'.tr);
  }

  static Future<void> _approveAll(WorkerDocumentReviewController controller) async {
    final result = await controller.approveAll();
    if (!_report(result)) return;
    final outcome = result.outcome;
    if (outcome.missing.isEmpty) {
      ShowToastDialog.showToast('Worker verified. They can now receive jobs.'.tr);
      return;
    }
    await DsDialog.show(DsDialog(
      title: outcome.refusal == WorkerReviewRefusal.nothingToApprove ? 'No uploaded document to approve'.tr : 'Uploaded documents approved'.tr,
      message: '${'The worker is verified once every required document is approved. Still missing:'.tr} ${_titles(outcome.missing)}',
      icon: Icons.info_outline_rounded,
      tone: DsTone.warning,
      primaryLabel: 'Ok'.tr,
      onPrimary: () => Get.back(),
    ));
  }

  /// The mandatory rejection reason, or null when cancelled.
  static Future<String?> _askReason(DocumentType type) {
    final TextEditingController text = TextEditingController();
    String? error;
    return Get.dialog<String>(StatefulBuilder(
      builder: (context, setState) => DsDialog(
        title: '${'Reject'.tr}: ${type.title.tr}',
        icon: Icons.gpp_bad_outlined,
        tone: DsTone.danger,
        destructive: true,
        content: DsTextField(
          controller: text,
          label: 'Reason'.tr,
          hint: 'Tell the worker what to correct'.tr,
          requiredMark: true,
          maxLines: 3,
          autofocus: true,
          errorText: error,
          bottomSpacing: 0,
        ),
        primaryLabel: 'Reject'.tr,
        onPrimary: () {
          final String reason = text.text.trim();
          if (reason.isEmpty) {
            setState(() => error = 'Please enter the reason for the rejection.'.tr);
            return;
          }
          Get.back(result: reason);
        },
        secondaryLabel: 'Cancel'.tr,
        onSecondary: () => Get.back(),
      ),
    ));
  }
}

DsTone _toneOf(DocumentStatus status) {
  switch (status) {
    case DocumentStatus.approved:
      return DsTone.success;
    case DocumentStatus.pendingReview:
      return DsTone.warning;
    case DocumentStatus.rejected:
    case DocumentStatus.expired:
      return DsTone.danger;
    case DocumentStatus.notSubmitted:
      return DsTone.neutral;
  }
}

class _Summary extends StatelessWidget {
  final WorkerDocumentReviewController controller;

  const _Summary({required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    final state = controller.state;
    final int total = controller.types.length;
    final int approved = total - controller.missing.length;
    final String message;
    switch (state) {
      case WorkerVerificationState.verified:
        message = 'This worker is verified and can receive jobs.'.tr;
      case WorkerVerificationState.pendingReview:
        message = 'Documents are waiting for your review.'.tr;
      case WorkerVerificationState.rejected:
        message = 'A document was rejected or has expired. The worker must upload it again.'.tr;
      case WorkerVerificationState.notSubmitted:
        message = 'The worker has not uploaded every required document yet.'.tr;
    }
    return DsCard.tinted(
      tone: state.tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsIconWell(icon: state.icon, tone: state.tone, size: 44, circle: true),
              const DsGap(DsSpace.md),
              Expanded(child: Text('Verification status'.tr, style: t.titleSm)),
              DsStatusChip(label: state.label, tone: state.tone),
            ],
          ),
          const DsGap(DsSpace.md),
          Text(message, style: t.bodySecondary),
          const DsGap(DsSpace.md),
          DsProgressBar(value: total == 0 ? 0 : approved / total, tone: state.tone, label: '$approved / $total ${'approved'.tr}'),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final WorkerDocumentReviewController controller;
  final DocumentType type;

  const _DocumentCard({required this.controller, required this.type});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    final c = context.dsColors;
    final UploadedDocument? doc = controller.uploads[type.id];
    final DocumentStatus status = controller.statusOf(type);
    final bool sent = doc?.hasFile == true;
    final bool canApprove = controller.canAct && sent && (status == DocumentStatus.pendingReview || status == DocumentStatus.rejected);
    final bool canReject = controller.canAct && sent && status != DocumentStatus.rejected;
    final DateFormat date = DateFormat('dd MMM yyyy');
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(type.title.tr, style: t.titleSm)),
              DsStatusChip(label: status.label, tone: _toneOf(status)),
            ],
          ),
          if (!sent) ...[
            const DsGap(DsSpace.sm),
            Text('Waiting for upload'.tr, style: t.bodySm.withColor(c.textSecondary)),
          ] else ...[
            const DsGap(DsSpace.md),
            Row(
              children: [
                if ((doc!.frontImage ?? '').isNotEmpty) Expanded(child: _Thumb(url: doc.frontImage!, label: 'Front side'.tr)),
                if ((doc.frontImage ?? '').isNotEmpty && (doc.backImage ?? '').isNotEmpty) const DsGap(DsSpace.md),
                if ((doc.backImage ?? '').isNotEmpty) Expanded(child: _Thumb(url: doc.backImage!, label: 'Back side'.tr)),
              ],
            ),
            if ((doc.number ?? '').trim().isNotEmpty) ...[
              const DsGap(DsSpace.sm),
              Text('${'Number'.tr}: ${doc.number!.trim()}', style: t.bodySm),
            ],
            if (doc.expireAt != null) ...[
              const DsGap(DsSpace.xs),
              Text('${'Expires on'.tr}: ${date.format(doc.expireAt!.toDate())}', style: t.bodySm.withColor(status == DocumentStatus.expired ? c.dangerStrong : c.textSecondary)),
            ],
            if (doc.submittedAt != null) ...[
              const DsGap(DsSpace.xs),
              Text('${'Submitted on'.tr}: ${date.format(doc.submittedAt!.toDate())}', style: t.caption),
            ],
          ],
          if (status == DocumentStatus.rejected && (doc?.rejectionReason ?? '').isNotEmpty) ...[
            const DsGap(DsSpace.sm),
            DsInlineAlert(tone: DsTone.danger, message: '${'Reason'.tr}: ${doc!.rejectionReason}'),
          ],
          if (canApprove || canReject) ...[
            const DsGap(DsSpace.md),
            Row(
              children: [
                if (canReject)
                  Expanded(
                    child: DsButton.dangerTonal(
                      label: 'Reject'.tr,
                      icon: Icons.close_rounded,
                      expand: true,
                      onPressed: () => WorkerDocumentReviewScreen._reject(controller, type),
                    ),
                  ),
                if (canReject && canApprove) const DsGap(DsSpace.md),
                if (canApprove)
                  Expanded(
                    child: DsButton.primary(
                      label: 'Approve'.tr,
                      icon: Icons.check_rounded,
                      expand: true,
                      color: c.success,
                      onPressed: () => WorkerDocumentReviewScreen._approve(controller, type),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String url;
  final String label;

  const _Thumb({required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: label,
          child: InkWell(
            borderRadius: DsRadius.brMd,
            onTap: () => Get.to(() => DocumentImageViewer(url: url, title: label)),
            child: DsImage(url: url, height: 120, width: double.infinity, radius: DsRadius.md),
          ),
        ),
        const DsGap(DsSpace.xs),
        Text(label, style: t.caption),
      ],
    );
  }
}

/// A document image full screen, zoomable. The Storage URL is used exactly as
/// stored (already percent-encoded; never re-encoded).
class DocumentImageViewer extends StatelessWidget {
  final String url;
  final String title;

  const DocumentImageViewer({super.key, required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(title)),
      body: SafeArea(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(child: DsImage(url: url, fit: BoxFit.contain, radius: 0)),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:spideliworker/controller/verification_controller.dart';
import 'package:spideliworker/model/document_model.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/services/document_service.dart';
import 'package:spideliworker/ui/documents/document_image_viewer.dart';
import 'package:spideliworker/ui/documents/document_upload_screen.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';

/// Tone of a verification status, shared by the summary card, the chips and
/// the icon wells.
DsTone verificationStatusTone(VerificationStatus status) {
  switch (status) {
    case VerificationStatus.approved:
      return DsTone.success;
    case VerificationStatus.pending:
      return DsTone.warning;
    case VerificationStatus.rejected:
    case VerificationStatus.expired:
      return DsTone.danger;
    case VerificationStatus.notSubmitted:
      return DsTone.neutral;
  }
}

class VerificationStatusChip extends StatelessWidget {
  final VerificationStatus status;

  const VerificationStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return DsBadge(label: status.label.tr, tone: verificationStatusTone(status), small: true);
  }
}

/// Tone of an overall status (Not submitted / Pending / Action required /
/// Verified).
DsTone overallStatusTone(WorkerOverallStatus status) {
  switch (status) {
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

/// The explanation of an overall status (a translation key).
String overallStatusMessage(WorkerOverallStatus status) {
  switch (status) {
    case WorkerOverallStatus.verified:
      return "Your documents are approved. You can receive jobs.";
    case WorkerOverallStatus.pending:
      return "Some documents are missing or waiting for review.";
    case WorkerOverallStatus.actionRequired:
      return "A document was rejected or has expired. Please check the reason and upload it again.";
    case WorkerOverallStatus.notSubmitted:
      return "Please upload your documents for verification.";
  }
}

/// The icon of an overall status.
IconData overallStatusIcon(WorkerOverallStatus status) {
  switch (status) {
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

/// "Document type: Worker" -- shown wherever the worker's documents are
/// uploaded or listed (the record type is `worker`).
class WorkerDocumentTypeBadge extends StatelessWidget {
  const WorkerDocumentTypeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DsBadge(
      label: '${'Document type'.tr}: ${WorkerVerificationStatusRules.recordTypeLabel(DocumentService.workerType).tr}',
      icon: Icons.badge_outlined,
      tone: DsTone.info,
      small: true,
    );
  }
}

/// Spec 11 "Documents": each required document with its status, the
/// rejection reason, the expiry date, and upload / re-upload.
///
/// Design: archetype N. A [VerificationSummaryCard] and a progress bar head
/// the page, then every document is a `DsCard.outlined` row with a tone icon
/// well, its status chip and a chevron into the upload screen.
class DocumentsScreen extends StatelessWidget {
  final bool isBack;

  const DocumentsScreen({super.key, this.isBack = false});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final bool dark = themeChange.getTheme();
    final VerificationController controller = Get.find<VerificationController>();
    final l = context.dsLayout;
    return DsScaffold(
      title: "Documents".tr,
      showBack: isBack,
      maxContentWidth: DsLayout.contentMax,
      body: Obx(() {
        if (controller.isLoading.value) {
          return const DsSkeletonList(itemCount: 5, leading: true, trailing: true);
        }
        final overall = controller.overallStatus;
        final List<DocumentModel> types = controller.documentTypes;
        final int approved = types.where((type) => controller.statusOf(type) == VerificationStatus.approved).length;
        return RefreshIndicator(
          onRefresh: controller.load,
          color: context.dsColors.brand,
          backgroundColor: context.dsColors.surface,
          child: ListView(
            padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
            children: DsFadeSlideIn.stagger([
              // Report Doc 36/41: no admin-created worker document type ->
              // nothing to upload against, so an empty state instead of a
              // built-in document.
              if (types.isEmpty && controller.typesLoadFailed.value)
                DsEmptyState(
                  icon: Icons.cloud_off_outlined,
                  tone: DsTone.warning,
                  title: "Could not load the documents to upload".tr,
                  message: "Check your connection and try again.".tr,
                  actionLabel: "Retry".tr,
                  actionIcon: Icons.refresh_rounded,
                  onAction: controller.load,
                )
              else if (types.isEmpty && overall != WorkerOverallStatus.verified)
                DsEmptyState(
                  icon: Icons.description_outlined,
                  title: "No documents to upload yet".tr,
                  message: "The administrator has not set up any worker documents. They will appear here when available.".tr,
                )
              else
                VerificationSummaryCard(status: overall, required: controller.verificationRequired.value != false, dark: dark),
              if (types.isNotEmpty) ...[
                const DsGap(DsSpace.lg),
                DsProgressBar(
                  value: approved / types.length,
                  label: 'Verification'.tr,
                  showPercent: true,
                  tone: overallStatusTone(overall),
                ),
              ],
              if (controller.recordTypeConflict.value) ...[
                const DsGap(DsSpace.lg),
                DsInlineAlert(
                  tone: DsTone.danger,
                  message: "This account already has documents of another type on file. Please contact support.".tr,
                ),
              ],
              const DsGap(DsSpace.xl),
              ...types.map((type) {
                final uploaded = controller.uploaded.value?.documentFor(type.id);
                final status = controller.statusOf(type);
                final bool canUpload = status == VerificationStatus.notSubmitted || status == VerificationStatus.rejected || status == VerificationStatus.expired;
                return _DocumentRow(
                  type: type,
                  status: status,
                  uploaded: uploaded,
                  canUpload: canUpload,
                );
              }),
            ]),
          ),
        );
      }),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  final DocumentModel type;
  final VerificationStatus status;
  final Documents? uploaded;
  final bool canUpload;

  const _DocumentRow({required this.type, required this.status, required this.uploaded, required this.canUpload});

  bool get _needsAction => status == VerificationStatus.rejected || status == VerificationStatus.expired;

  void _open() => Get.to(() => DocumentUploadScreen(documentType: type, existing: uploaded, readOnly: !canUpload));

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final DsTone tone = verificationStatusTone(status);
    final String action = canUpload ? (status == VerificationStatus.notSubmitted ? "Upload".tr : "Re-upload".tr) : "View".tr;
    final String front = (uploaded?.frontImage ?? '').trim();
    final String back = (uploaded?.backImage ?? '').trim();
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      // A rejected / expired document stands out: the worker must send it again.
      borderColor: _needsAction ? c.danger : null,
      onTap: _open,
      semanticLabel: '${(type.title ?? '').tr}, ${status.label.tr}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsIconWell(
                icon: status == VerificationStatus.approved
                    ? Icons.verified_outlined
                    : _needsAction
                        ? Icons.error_outline_rounded
                        : Icons.description_outlined,
                tone: tone,
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((type.title ?? '').tr, style: t.titleSm),
                    const DsGap(DsSpace.sm),
                    Align(alignment: AlignmentDirectional.centerStart, child: VerificationStatusChip(status: status)),
                  ],
                ),
              ),
              const DsGap(DsSpace.sm),
              if (!_needsAction) ...[
                Text(action, style: t.label.withColor(c.brandStrong)),
                Icon(Icons.chevron_right_rounded, color: c.brandStrong),
              ],
            ],
          ),
          // The uploaded file(s), full screen on tap (Storage URL as stored).
          if (front.isNotEmpty || back.isNotEmpty) ...[
            const DsGap(DsSpace.md),
            Row(
              children: [
                if (front.isNotEmpty) Expanded(child: DocumentThumb(url: front, label: "Front side".tr)),
                if (front.isNotEmpty && back.isNotEmpty) const DsGap(DsSpace.md),
                if (back.isNotEmpty) Expanded(child: DocumentThumb(url: back, label: "Back side".tr)),
              ],
            ),
          ],
          if (status == VerificationStatus.rejected && (uploaded?.rejectionReason ?? '').isNotEmpty) ...[
            const DsGap(DsSpace.md),
            DsInlineAlert(tone: DsTone.danger, message: "${"Reason".tr}: ${uploaded!.rejectionReason}"),
          ],
          if (uploaded?.expiryDate != null) ...[
            const DsGap(DsSpace.sm),
            Row(
              children: [
                Icon(Icons.event_busy_outlined, size: 16, color: c.textMuted),
                const DsGap(DsSpace.xs),
                Text("${"Expires on".tr}: ${DateFormat('dd MMM yyyy').format(uploaded!.expiryDate!.toDate())}", style: t.caption),
              ],
            ),
          ],
          if (_needsAction) ...[
            const DsGap(DsSpace.md),
            DsButton.danger(label: "Re-upload".tr, icon: Icons.upload_file_rounded, expand: true, onPressed: _open),
          ],
        ],
      ),
    );
  }
}

/// The worker's overall status (Not submitted / Pending / Action required /
/// Verified), on the Documents screen and the Jobs banner.
class VerificationSummaryCard extends StatelessWidget {
  final WorkerOverallStatus status;
  final bool required;
  final bool dark;

  const VerificationSummaryCard({super.key, required this.status, required this.required, required this.dark});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final DsTone tone = overallStatusTone(status);
    return DsCard.tinted(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsIconWell(icon: overallStatusIcon(status), tone: tone, size: 48, circle: true),
              const DsGap(DsSpace.md),
              Expanded(child: Text("Verification status".tr, style: t.titleSm)),
              DsBadge(label: status.label.tr, tone: tone, small: true),
            ],
          ),
          const DsGap(DsSpace.sm),
          const WorkerDocumentTypeBadge(),
          const DsGap(DsSpace.md),
          Text(overallStatusMessage(status).tr, style: t.bodySecondary),
          if (required && status != WorkerOverallStatus.verified)
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: c.dangerStrong),
                  const DsGap(DsSpace.xs),
                  Expanded(
                    child: Text("You will not receive jobs until your documents are approved.".tr, style: t.bodySm.withColor(c.dangerStrong)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

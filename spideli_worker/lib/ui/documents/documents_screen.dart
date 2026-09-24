import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:spideliworker/controller/verification_controller.dart';
import 'package:spideliworker/model/document_model.dart';
import 'package:spideliworker/themes/ds/ds.dart';
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
              VerificationSummaryCard(status: overall, required: controller.verificationRequired.value, dark: dark),
              if (types.isNotEmpty) ...[
                const DsGap(DsSpace.lg),
                DsProgressBar(
                  value: approved / types.length,
                  label: 'Verification'.tr,
                  showPercent: true,
                  tone: verificationStatusTone(overall),
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

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final DsTone tone = verificationStatusTone(status);
    final String action = canUpload ? (status == VerificationStatus.notSubmitted ? "Upload".tr : "Re-upload".tr) : "View".tr;
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      onTap: () => Get.to(() => DocumentUploadScreen(documentType: type, existing: uploaded, readOnly: !canUpload)),
      semanticLabel: (type.title ?? '').tr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsIconWell(
                icon: status == VerificationStatus.approved
                    ? Icons.verified_outlined
                    : status == VerificationStatus.rejected || status == VerificationStatus.expired
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
              Text(action, style: t.label.withColor(c.brandStrong)),
              Icon(Icons.chevron_right_rounded, color: c.brandStrong),
            ],
          ),
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
        ],
      ),
    );
  }
}

class VerificationSummaryCard extends StatelessWidget {
  final VerificationStatus status;
  final bool required;
  final bool dark;

  const VerificationSummaryCard({super.key, required this.status, required this.required, required this.dark});

  String get _message {
    switch (status) {
      case VerificationStatus.approved:
        return "Your documents are approved. You can receive jobs.";
      case VerificationStatus.pending:
        return "Your documents are pending review by the administrator.";
      case VerificationStatus.rejected:
        return "A document was rejected. Please check the reason and upload it again.";
      case VerificationStatus.expired:
        return "A document has expired. Please upload a valid one.";
      case VerificationStatus.notSubmitted:
        return "Please upload your documents for verification.";
    }
  }

  IconData get _icon {
    switch (status) {
      case VerificationStatus.approved:
        return Icons.verified_user_outlined;
      case VerificationStatus.pending:
        return Icons.hourglass_top_rounded;
      case VerificationStatus.rejected:
      case VerificationStatus.expired:
        return Icons.gpp_bad_outlined;
      case VerificationStatus.notSubmitted:
        return Icons.shield_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final DsTone tone = verificationStatusTone(status);
    return DsCard.tinted(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsIconWell(icon: _icon, tone: tone, size: 48, circle: true),
              const DsGap(DsSpace.md),
              Expanded(child: Text("Verification status".tr, style: t.titleSm)),
              VerificationStatusChip(status: status),
            ],
          ),
          const DsGap(DsSpace.md),
          Text(_message.tr, style: t.bodySecondary),
          if (required && status != VerificationStatus.approved)
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

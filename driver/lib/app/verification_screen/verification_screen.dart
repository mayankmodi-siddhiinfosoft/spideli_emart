import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/verification_controller.dart';
import 'package:driver/models/document_model.dart';
import 'package:driver/models/driver_document_model.dart';
import 'package:driver/services/driver_document_status.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'document_status_widgets.dart';
import 'verification_details_upload_screen.dart';

/// Archetype F – documents: a verification progress bar over one outlined
/// card per document (status chip, rejection reason, expiry, re-upload hint).
class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      // The theme observable read must stay inside this Obx: it is what
      // rebuilds this screen when the driver switches light / dark mode.
      themeController.isDark.value;
      return GetBuilder<VerificationController>(
          init: VerificationController(),
          builder: (controller) {
            final c = context.dsColors;
            final t = context.dsText;

            final List<DocumentModel> documents = controller.documentList;
            final DocumentOverallStatus overall = controller.overall;
            final int approved = controller.view.value?.approvedCount ?? 0;
            final double progress = documents.isEmpty ? 0 : approved / documents.length;
            final bool allApproved = overall == DocumentOverallStatus.verified;

            return Scaffold(
              backgroundColor: c.background,
              body: DsAsync(
                isLoading: controller.isLoading.value,
                skeleton: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xl),
                  child: DsSkeletonList(itemCount: 4, trailing: false),
                ),
                isEmpty: documents.isEmpty && !controller.loadFailed.value,
                empty: DsEmptyState(
                  icon: Icons.folder_open_rounded,
                  title: "Document Verification".tr,
                  message: "Upload your ID Proof to complete the verification process and ensure compliance.".tr,
                ),
                builder: (_) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.xl, DsSpace.lg, DsSpace.xxxl),
                  child: DsResponsive(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: DsFadeSlideIn.stagger([
                        Text("Document Verification".tr, style: t.headline),
                        const DsGap(DsSpace.xs),
                        Text(
                          "Upload your ID Proof to complete the verification process and ensure compliance.".tr,
                          style: t.bodySecondary,
                        ),
                        const DsGap(DsSpace.xl),
                        if (controller.loadFailed.value) ...[
                          DsInlineAlert(tone: DsTone.danger, message: "The documents could not be loaded. Please try again.".tr),
                          const DsGap(DsSpace.sm),
                          DsButton.primary(label: 'Retry'.tr, icon: Icons.refresh_rounded, size: DsButtonSize.sm, onPressed: controller.getDocument),
                          const DsGap(DsSpace.xl),
                        ],
                        DsCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  DsIconWell(
                                    icon: overallStatusIcon(overall),
                                    tone: overallStatusTone(overall),
                                    size: 44,
                                  ),
                                  const DsGap(DsSpace.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Verification status".tr, style: t.caption),
                                        const DsGap(DsSpace.xxs),
                                        DocumentOverallStatusChip(status: overall, small: false),
                                      ],
                                    ),
                                  ),
                                  Text("$approved/${documents.length}", style: t.titleSm.tabular),
                                ],
                              ),
                              const DsGap(DsSpace.lg),
                              DsProgressBar(
                                value: progress,
                                tone: allApproved ? DsTone.success : DsTone.brand,
                                label: "Document Verification".tr,
                                showPercent: true,
                              ),
                              if (overall == DocumentOverallStatus.actionRequired) ...[
                                const DsGap(DsSpace.md),
                                DsInlineAlert(
                                  tone: DsTone.danger,
                                  message: "A document was rejected or has expired. Upload it again to be verified.".tr,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const DsGap(DsSpace.xl),
                        for (var i = 0; i < documents.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: DsSpace.md),
                            child: _DocumentCard(
                              index: i,
                              documentModel: documents[i],
                              documents: controller.entryFor(documents[i]),
                              onTap: () {
                                // The list follows documents_verify live: it
                                // updates by itself after an upload.
                                Get.to(const VerificationDetailsUploadScreen(), arguments: {'documentModel': documents[i]});
                              },
                            ),
                          ),
                      ], offset: const Offset(0, 18)),
                    ),
                  ),
                ),
              ),
            );
          });
    });
  }
}

/// One document row: what it is (name, type), the uploaded file(s), its
/// status, the rejection reason, and a Re-upload action when it was rejected
/// or has expired (highlighted).
class _DocumentCard extends StatelessWidget {
  final int index;
  final DocumentModel documentModel;
  final Documents documents;
  final VoidCallback onTap;

  const _DocumentCard({
    required this.index,
    required this.documentModel,
    required this.documents,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final String status = DriverDocumentStatus.entryStatus(documents);
    final DsTone tone = entryStatusTone(status);
    final bool needsAction = status == DocumentEntryStatus.rejected || status == DocumentEntryStatus.expired;
    final String title = documentModel.title ?? '';

    return DsFadeSlideIn(
      index: index,
      child: DsCard.outlined(
        onTap: onTap,
        borderColor: needsAction ? c.danger : null,
        color: needsAction ? c.dangerSoft : null,
        semanticLabel: title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DsIconWell(
                  icon: status == DocumentEntryStatus.approved ? Icons.verified_user_outlined : Icons.description_outlined,
                  tone: tone,
                  size: 44,
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.titleSm),
                      const DsGap(DsSpace.xxs),
                      Text(
                        "${documentModel.frontSide == true ? "Front".tr : ""} ${documentModel.backSide == true ? "And Back".tr : ""} ${'Photo'.tr}",
                        style: t.bodySm,
                      ),
                    ],
                  ),
                ),
                const DsGap(DsSpace.sm),
                Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 22),
              ],
            ),
            const DsGap(DsSpace.md),
            Wrap(
              spacing: DsSpace.sm,
              runSpacing: DsSpace.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DocumentEntryStatusChip(status: status),
                DocumentTypeBadge(type: documentModel.type),
                if (documents.expiryDate != null)
                  DsBadge(
                    label: "${documents.isExpired ? 'Expired on'.tr : 'Expires on'.tr} ${Constant.timestampToDate(documents.expiryDate!)}",
                    tone: documents.isExpired ? DsTone.danger : DsTone.neutral,
                    icon: Icons.event_outlined,
                    small: true,
                  ),
              ],
            ),
            if (status != DocumentEntryStatus.notSubmitted) ...[
              const DsGap(DsSpace.md),
              DocumentFilesRow(
                frontImage: documents.frontImage,
                backImage: documents.backImage,
                frontSide: documentModel.frontSide == true,
                backSide: documentModel.backSide == true,
                title: title,
              ),
            ],
            if (status == DocumentEntryStatus.rejected && (documents.rejectReason ?? '').isNotEmpty) ...[
              const DsGap(DsSpace.md),
              DsInlineAlert(
                tone: DsTone.danger,
                message: 'Rejection reason: @reason'.trParams({'reason': documents.rejectReason ?? ''}),
              ),
            ],
            if (needsAction) ...[
              const DsGap(DsSpace.md),
              Align(
                alignment: Alignment.centerRight,
                child: DsButton.primary(
                  key: ValueKey('document-reupload-${documentModel.id}'),
                  label: "Re-upload".tr,
                  icon: Icons.upload_rounded,
                  size: DsButtonSize.sm,
                  onPressed: onTap,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

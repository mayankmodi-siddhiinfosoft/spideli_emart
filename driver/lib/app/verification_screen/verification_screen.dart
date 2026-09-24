import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/verification_controller.dart';
import 'package:driver/models/document_model.dart';
import 'package:driver/models/driver_document_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

            final List<DocumentModel> documents = controller.documentList.cast<DocumentModel>().toList();
            final List<Documents> driverDocuments = controller.driverDocumentList.cast<Documents>().toList();

            Documents statusOf(DocumentModel documentModel) {
              Documents documents = Documents();
              var contain = driverDocuments.where((element) => element.documentId == documentModel.id);
              if (contain.isNotEmpty) {
                documents = driverDocuments.firstWhere((itemToCheck) => itemToCheck.documentId == documentModel.id);
              }
              return documents;
            }

            final int approved = documents.where((d) => statusOf(d).verificationStatus == 'approved').length;
            final double progress = documents.isEmpty ? 0 : approved / documents.length;
            final bool allApproved = documents.isNotEmpty && approved == documents.length;

            return Scaffold(
              backgroundColor: c.background,
              body: DsAsync(
                isLoading: controller.isLoading.value,
                skeleton: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xl),
                  child: DsSkeletonList(itemCount: 4, trailing: false),
                ),
                isEmpty: documents.isEmpty,
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
                        DsCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  DsIconWell(
                                    icon: allApproved ? Icons.verified_rounded : Icons.badge_outlined,
                                    tone: allApproved ? DsTone.success : DsTone.brand,
                                    size: 44,
                                  ),
                                  const DsGap(DsSpace.md),
                                  Expanded(
                                    child: Text(
                                      allApproved ? "Approved".tr : "Pending review".tr,
                                      style: t.titleSm,
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
                              documents: statusOf(documents[i]),
                              onTap: () {
                                Get.to(const VerificationDetailsUploadScreen(), arguments: {'documentModel': documents[i]})!.then(
                                  (value) {
                                    if (value == true) {
                                      controller.getDocument();
                                    }
                                  },
                                );
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

/// One document row: what it is, what is needed, and where it stands.
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
    final status = documents.verificationStatus;
    final label = const {
          'approved': "Approved",
          'rejected': "Rejected",
          'expired': "Expired",
          'pending': "Pending review",
        }[status]?.tr ??
        "Not submitted".tr;
    final DsTone tone = status == 'approved'
        ? DsTone.success
        : (status == 'rejected' || status == 'expired')
            ? DsTone.danger
            : status == 'pending'
                ? DsTone.brand
                : DsTone.warning;
    final needsAction = status == 'rejected' || documents.isExpired;

    return DsFadeSlideIn(
      index: index,
      child: DsCard.outlined(
        onTap: onTap,
        borderColor: needsAction ? c.danger : null,
        semanticLabel: "${documentModel.title}",
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DsIconWell(
                  icon: status == 'approved' ? Icons.verified_user_outlined : Icons.description_outlined,
                  tone: tone,
                  size: 44,
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${documentModel.title}", style: t.titleSm),
                      const DsGap(DsSpace.xxs),
                      Text(
                        "${documentModel.frontSide == true ? "Front" : ""} ${documentModel.backSide == true ? "And Back" : ""} ${'Photo'.tr}",
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
                DsStatusChip(label: label, tone: tone),
                if (documents.expiryDate != null)
                  DsBadge(
                    label: "${documents.isExpired ? 'Expired on'.tr : 'Expires on'.tr} ${Constant.timestampToDate(documents.expiryDate!)}",
                    tone: documents.isExpired ? DsTone.danger : DsTone.neutral,
                    icon: Icons.event_outlined,
                    small: true,
                  ),
              ],
            ),
            if (status == 'rejected' && documents.rejectReason != null) ...[
              const DsGap(DsSpace.md),
              DsInlineAlert(
                tone: DsTone.danger,
                message: "${'Reason'.tr}: ${documents.rejectReason}",
              ),
            ],
            if (needsAction) ...[
              const DsGap(DsSpace.md),
              Text("Tap to upload again".tr, style: t.link),
            ],
          ],
        ),
      ),
    );
  }
}

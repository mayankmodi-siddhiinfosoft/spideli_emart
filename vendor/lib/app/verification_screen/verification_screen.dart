import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/controller/verification_controller.dart';
import 'package:vendor/models/document_model.dart';
import 'package:vendor/models/driver_document_model.dart';
import 'package:vendor/themes/ds/ds.dart';

import 'verification_details_upload_screen.dart';

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VerificationController>(
      init: VerificationController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final l = context.dsLayout;

        // Presentation-only summary of the existing document statuses.
        Documents documentFor(DocumentModel documentModel) {
          Documents documents = Documents();
          var contain = controller.driverDocumentList.where((element) => element.documentId == documentModel.id);
          if (contain.isNotEmpty) {
            documents = controller.driverDocumentList.firstWhere((itemToCheck) => itemToCheck.documentId == documentModel.id);
          }
          return documents;
        }

        final total = controller.documentList.length;
        final verified = controller.isLoading.value ? 0 : controller.documentList.where((d) => documentFor(d as DocumentModel).status == "approved").length;

        return DsScaffold(
          title: "Document Verification".tr,
          onBack: () {
            Get.back();
          },
          maxContentWidth: DsLayout.contentMax,
          body: controller.isLoading.value
              ? const SingleChildScrollView(
                  physics: NeverScrollableScrollPhysics(),
                  child: Column(children: [DsSkeletonCard(height: 132), DsSkeletonList(itemCount: 4)]),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, DsSpace.xxxl),
                  children: [
                    DsFadeSlideIn(
                      child: DsCard.gradient(
                        child: Row(
                          children: [
                            DsProgressRing(
                              value: total == 0 ? 0 : verified / total,
                              size: 84,
                              onBrand: true,
                              center: Text("$verified/$total", style: t.titleSm.tabular.withColor(Colors.white)),
                            ),
                            const DsGap(DsSpace.xl),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Verified'.tr, style: t.overline.withColor(Colors.white.withValues(alpha: 0.8))),
                                  const DsGap(DsSpace.xs),
                                  Text("Upload your ID Proof to complete the verification process and ensure compliance.".tr, style: t.body.withColor(Colors.white)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const DsGap(DsSpace.xl),
                    DsSectionHeader(
                      title: 'Documents'.tr,
                      icon: Icons.folder_copy_outlined,
                      padding: const EdgeInsets.only(bottom: DsSpace.sm),
                    ),
                    if (controller.documentList.isEmpty) DsEmptyState(icon: Icons.description_outlined, title: 'No documents found'.tr, compact: true),
                    for (int index = 0; index < controller.documentList.length; index++)
                      Builder(
                        builder: (context) {
                          DocumentModel documentModel = controller.documentList[index];
                          Documents documents = documentFor(documentModel);
                          final label = documents.status == "approved"
                              ? "Verified".tr
                              : documents.status == "rejected"
                              ? "Rejected".tr
                              : documents.status == "uploaded"
                              ? "Uploaded".tr
                              : "Pending".tr;
                          final tone = documents.status == "approved"
                              ? DsTone.success
                              : documents.status == "rejected"
                              ? DsTone.danger
                              : documents.status == "uploaded"
                              ? DsTone.info
                              : DsTone.warning;
                          final icon = documents.status == "approved"
                              ? Icons.verified_rounded
                              : documents.status == "rejected"
                              ? Icons.error_outline_rounded
                              : documents.status == "uploaded"
                              ? Icons.hourglass_top_rounded
                              : Icons.upload_file_rounded;
                          return DsFadeSlideIn(
                            index: index + 1,
                            child: DsCard.outlined(
                              margin: const EdgeInsets.only(bottom: DsSpace.md),
                              semanticLabel: "${documentModel.title}",
                              onTap: () {
                                Get.to(const VerificationDetailsUploadScreen(), arguments: {'documentModel': documentModel})!.then((value) {
                                  if (value == true) {
                                    controller.getDocument();
                                  }
                                });
                              },
                              child: Row(
                                children: [
                                  DsIconWell(icon: icon, tone: tone, size: 48),
                                  const DsGap(DsSpace.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("${documentModel.title}", style: t.titleSm.withColor(c.textPrimary)),
                                        const DsGap(DsSpace.xxs),
                                        Text(
                                          "${documentModel.frontSide == true ? "Front".tr : ""} ${documentModel.backSide == true ? "And Back".tr : ""} ${'Photo'.tr}",
                                          style: t.bodySm.withColor(c.textSecondary),
                                        ),
                                        const DsGap(DsSpace.sm),
                                        DsStatusChip(label: label, tone: tone),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: c.textMuted),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
        );
      },
    );
  }
}

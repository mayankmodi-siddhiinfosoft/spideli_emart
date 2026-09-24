import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:dotted_border/dotted_border.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/verification_details_upload_controller.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// Archetype F/H – document upload: a short brief, the review outcome, the
/// expiry field and one large picker tile per side, with Upload in a sticky
/// bar.
class VerificationDetailsUploadScreen extends StatelessWidget {
  const VerificationDetailsUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<DetailsUploadController>(
        init: DetailsUploadController(),
        builder: (controller) {
          final c = context.dsColors;
          final t = context.dsText;

          // Reads stay inside the tracked builder.
          final String title = "${controller.documentModel.value.title}";
          final bool frontSide = controller.documentModel.value.frontSide == true;
          final bool backSide = controller.documentModel.value.backSide == true;
          final String frontImage = controller.frontImage.value;
          final String backImage = controller.backImage.value;
          final String status = controller.documents.value.verificationStatus;
          final String? rejectReason = controller.documents.value.rejectReason;
          final DateTime? expiryDate = controller.expiryDate.value;
          final bool isExpired = controller.documents.value.isExpired;
          final bool canUpload = controller.canUpload;
          final bool showExpiry = controller.needsExpiryDate || expiryDate != null;

          return DsScaffold(
            title: title,
            onBack: () {
              Get.back();
            },
            body: DsAsync(
              isLoading: controller.isLoading.value,
              skeleton: const DsSkeletonDetail(mediaHeight: 180),
              builder: (_) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxxl),
                child: DsResponsive(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: DsFadeSlideIn.stagger([
                      Text(
                        "${'Upload'.tr} $title ${'for Verification'.tr}",
                        style: t.headline,
                      ),
                      const DsGap(DsSpace.xs),
                      Text(
                        "${'Please upload a valid'.tr} $title ${'to verify your identity complete the registration process.'.tr}".tr,
                        style: t.bodySecondary,
                      ),
                      const DsGap(DsSpace.lg),
                      if (status == 'rejected' && rejectReason != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: DsSpace.md),
                          child: DsInlineAlert(
                            tone: DsTone.danger,
                            message: "${'Rejected'.tr}: $rejectReason",
                          ),
                        ),
                      if (showExpiry)
                        Padding(
                          padding: const EdgeInsets.only(bottom: DsSpace.lg),
                          child: DsCard.outlined(
                            onTap: !canUpload
                                ? null
                                : () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: controller.expiryDate.value ?? DateTime.now().add(const Duration(days: 1)),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) controller.expiryDate.value = picked;
                                  },
                            child: Row(
                              children: [
                                DsIconWell(
                                  icon: Icons.event_outlined,
                                  tone: isExpired ? DsTone.danger : DsTone.brand,
                                  size: 44,
                                ),
                                const DsGap(DsSpace.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Expiry date".tr, style: t.titleSm),
                                      const DsGap(DsSpace.xxs),
                                      Text(
                                        expiryDate == null
                                            ? "Select the expiry date".tr
                                            : Constant.timestampToDate(Timestamp.fromDate(expiryDate)),
                                        style: isExpired ? t.bodySm.withColor(c.dangerStrong) : t.bodySm,
                                      ),
                                    ],
                                  ),
                                ),
                                if (canUpload) Icon(Icons.edit_calendar_outlined, size: 20, color: c.textMuted),
                              ],
                            ),
                          ),
                        ),
                      if (frontSide)
                        Padding(
                          padding: const EdgeInsets.only(bottom: DsSpace.lg),
                          child: _SidePicker(
                            title: "${'Front Side of'} $title",
                            image: frontImage,
                            onPick: () => buildBottomSheet(context, controller, "front"),
                            onTapExisting: () {
                              if (controller.documents.value.status != "uploaded" || controller.documents.value.status == "rejected") {
                                buildBottomSheet(context, controller, "front");
                              }
                            },
                          ),
                        ),
                      if (backSide)
                        Padding(
                          padding: const EdgeInsets.only(bottom: DsSpace.lg),
                          child: _SidePicker(
                            title: "${'Back side of'.tr} $title",
                            image: backImage,
                            onPick: () => buildBottomSheet(context, controller, "back"),
                            onTapExisting: () {
                              if (controller.documents.value.status != "uploaded" || controller.documents.value.status == "rejected") {
                                buildBottomSheet(context, controller, "back");
                              }
                            },
                          ),
                        ),
                    ], offset: const Offset(0, 18)),
                  ),
                ),
              ),
            ),
            bottomBar: !canUpload
                ? null
                : DsStickyBar(
                    child: DsButton.primary(
                      label: "Upload Document".tr,
                      icon: Icons.cloud_upload_outlined,
                      size: DsButtonSize.lg,
                      expand: true,
                      onPressed: () {
                        if (controller.needsExpiryDate && controller.expiryDate.value == null) {
                          ShowToastDialog.showToast("Please select the expiry date of the document.".tr);
                        } else if (controller.expiryDate.value != null && controller.expiryDate.value!.isBefore(DateTime.now())) {
                          ShowToastDialog.showToast("This document has expired. Please upload a valid document.".tr);
                        } else if (controller.documentModel.value.frontSide == true && controller.frontImage.value.isEmpty) {
                          ShowToastDialog.showToast("Please upload front side of document.".tr);
                        } else if (controller.documentModel.value.backSide == true && controller.backImage.value.isEmpty) {
                          ShowToastDialog.showToast("Please upload back side of document.".tr);
                        } else {
                          ShowToastDialog.showLoader("Please wait.".tr);
                          controller.uploadDocument();
                        }
                      },
                    ),
                  ),
          );
        });
  }

  Future buildBottomSheet(BuildContext context, DetailsUploadController controller, String type) {
    final c = DsColors.of(context);
    return showModalBottomSheet(
        context: context,
        backgroundColor: c.surfaceRaised,
        shape: const RoundedRectangleBorder(borderRadius: DsRadius.sheetTop),
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            final t = context.dsText;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.md, DsSpace.xl, DsSpace.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: c.borderStrong, borderRadius: DsRadius.brPill),
                      ),
                    ),
                    const DsGap(DsSpace.lg),
                    Text("Please Select".tr, textAlign: TextAlign.center, style: t.title),
                    const DsGap(DsSpace.xl),
                    Row(
                      children: [
                        Expanded(
                          child: _PickerTile(
                            icon: Icons.camera_alt_rounded,
                            label: "Camera".tr,
                            onTap: () => controller.pickFile(source: ImageSource.camera, type: type),
                          ),
                        ),
                        const DsGap(DsSpace.md),
                        Expanded(
                          child: _PickerTile(
                            icon: Icons.photo_library_rounded,
                            label: "Gallery".tr,
                            onTap: () => controller.pickFile(source: ImageSource.gallery, type: type),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          });
        });
  }
}

/// Upload tile for one side of a document: empty state is a dashed drop zone,
/// filled state shows the picture and can be replaced.
class _SidePicker extends StatelessWidget {
  final String title;
  final String image;
  final VoidCallback onPick;
  final VoidCallback onTapExisting;

  const _SidePicker({
    required this.title,
    required this.image,
    required this.onPick,
    required this.onTapExisting,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.titleSm),
        const DsGap(DsSpace.md),
        if (image.isNotEmpty)
          DsPressable(
            onTap: onTapExisting,
            child: ClipRRect(
              borderRadius: DsRadius.brLg,
              child: SizedBox(
                height: 190,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Constant().hasValidUrl(image) == false
                        ? Image.file(File(image), fit: BoxFit.cover)
                        : CachedNetworkImage(
                            imageUrl: image,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => DsShimmer(child: DsSkeleton.box(height: 190)),
                            errorWidget: (context, url, error) => Container(
                              color: c.surfaceAlt,
                              alignment: Alignment.center,
                              child: Icon(Icons.broken_image_outlined, color: c.textMuted),
                            ),
                          ),
                    PositionedDirectional(
                      bottom: DsSpace.sm,
                      end: DsSpace.sm,
                      child: DsBadge(
                        label: "Brows Image".tr,
                        tone: DsTone.brand,
                        style: DsBadgeStyle.solid,
                        icon: Icons.photo_camera_outlined,
                        small: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          DottedBorder(
            options: RoundedRectDottedBorderOptions(
              radius: const Radius.circular(DsRadius.lg),
              dashPattern: const [6, 6, 6, 6],
              color: c.borderStrong,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: DsRadius.brLg,
              ),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const DsIconWell(icon: Icons.folder_open_rounded, tone: DsTone.brand, size: 52, circle: true),
                  const DsGap(DsSpace.md),
                  Text(
                    "Choose a image and upload here".tr,
                    textAlign: TextAlign.center,
                    style: t.titleSm,
                  ),
                  const DsGap(DsSpace.xxs),
                  Text("JPEG, PNG".tr, style: t.caption),
                  const DsGap(DsSpace.lg),
                  DsButton.tonal(
                    label: "Brows Image".tr,
                    icon: Icons.add_photo_alternate_outlined,
                    size: DsButtonSize.sm,
                    onPressed: () async {
                      onPick();
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Camera / gallery choice inside the picker sheet.
class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return DsCard.outlined(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: DsSpace.xl),
      semanticLabel: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsIconWell(icon: icon, tone: DsTone.brand, size: 48, circle: true),
          const DsGap(DsSpace.md),
          Text(label, style: t.bodyStrong),
        ],
      ),
    );
  }
}

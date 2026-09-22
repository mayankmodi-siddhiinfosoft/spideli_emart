import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/verification_details_upload_controller.dart';
import 'package:vendor/themes/ds/ds.dart';

class VerificationDetailsUploadScreen extends StatelessWidget {
  const VerificationDetailsUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<DetailsUploadController>(
      init: DetailsUploadController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final l = context.dsLayout;
        final status = controller.documents.value.status;
        final showUpload = controller.documents.value.status == "approved" || controller.documents.value.status == "uploaded" ? false : true;

        final front = Visibility(
          visible: controller.documentModel.value.frontSide == true ? true : false,
          child: _DocumentSlot(
            title: "${'Front Side of'.tr} ${controller.documentModel.value.title.toString()}",
            icon: Icons.badge_outlined,
            imagePath: controller.frontImage.value,
            onTapImage: () {
              if (controller.documents.value.status == "rejected") {
                buildBottomSheet(context, controller, "front");
              }
            },
            onBrowse: () async {
              buildBottomSheet(context, controller, "front");
            },
          ),
        );
        final back = Visibility(
          visible: controller.documentModel.value.backSide == true ? true : false,
          child: _DocumentSlot(
            title: "${"Back side of".tr} ${controller.documentModel.value.title.toString()}",
            icon: Icons.flip_rounded,
            imagePath: controller.backImage.value,
            onTapImage: () {
              if (controller.documents.value.status == "rejected") {
                buildBottomSheet(context, controller, "back");
              }
            },
            onBrowse: () async {
              buildBottomSheet(context, controller, "back");
            },
          ),
        );

        return DsScaffold(
          title: "${controller.documentModel.value.title}",
          onBack: () {
            Get.back();
          },
          maxContentWidth: DsLayout.wideMax,
          bottomBar: controller.isLoading.value
              ? null
              : Visibility(
                  visible: showUpload,
                  child: DsStickyBar(
                    child: DsButton.primary(
                      label: "Upload Document".tr,
                      size: DsButtonSize.lg,
                      expand: true,
                      icon: Icons.cloud_upload_outlined,
                      onPressed: () {
                        if (controller.documentModel.value.frontSide == true && controller.frontImage.value.isEmpty) {
                          ShowToastDialog.showToast("Please upload front side of document.".tr);
                        } else if (controller.documentModel.value.backSide == true && controller.backImage.value.isEmpty) {
                          ShowToastDialog.showToast("Please upload back side of document.".tr);
                        } else {
                          ShowToastDialog.showLoader("Please wait..".tr);
                          controller.uploadDocument();
                        }
                      },
                    ),
                  ),
                ),
          body: controller.isLoading.value
              ? const SingleChildScrollView(physics: NeverScrollableScrollPhysics(), child: DsSkeletonDetail(mediaHeight: 200))
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, DsSpace.xxxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: DsFadeSlideIn.stagger([
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const DsIconWell(icon: Icons.verified_user_outlined, size: 52),
                          const DsGap(DsSpace.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${'Upload'.tr} ${controller.documentModel.value.title} ${'for Verification'.tr}", style: t.headline.withColor(c.textPrimary)),
                                const DsGap(DsSpace.xs),
                                Text(
                                  "${'Please upload a valid'.tr} ${controller.documentModel.value.title} ${'to verify your identity complete the registration process.'.tr}",
                                  style: t.body.withColor(c.textSecondary),
                                ),
                                if (status != null && status.isNotEmpty) ...[
                                  const DsGap(DsSpace.md),
                                  DsStatusChip(
                                    label: status == "approved"
                                        ? "Verified".tr
                                        : status == "rejected"
                                        ? "Rejected".tr
                                        : status == "uploaded"
                                        ? "Uploaded".tr
                                        : "Pending".tr,
                                    status: status,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const DsGap(DsSpace.xl),
                      if (status == "rejected")
                        Padding(
                          padding: const EdgeInsets.only(bottom: DsSpace.lg),
                          child: DsInlineAlert(tone: DsTone.danger, message: 'Tap an image to replace it and upload again.'.tr),
                        ),
                      // Tablets: front and back side by side.
                      l.isWide && controller.documentModel.value.frontSide == true && controller.documentModel.value.backSide == true
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: front),
                                const DsGap(DsSpace.lg),
                                Expanded(child: back),
                              ],
                            )
                          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [front, back]),
                    ]),
                  ),
                ),
        );
      },
    );
  }

  Future buildBottomSheet(BuildContext context, DetailsUploadController controller, String type) {
    return showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return _PickerSheet(
              title: "Please Select".tr,
              cameraLabel: "Camera".tr,
              galleryLabel: "Gallery".tr,
              onCamera: () => controller.pickFile(source: ImageSource.camera, type: type),
              onGallery: () => controller.pickFile(source: ImageSource.gallery, type: type),
            );
          },
        );
      },
    );
  }
}

/// One side of a document: preview when an image exists, dashed drop zone
/// with "Brows Image" otherwise.
class _DocumentSlot extends StatelessWidget {
  final String title;
  final IconData icon;
  final String imagePath;
  final VoidCallback onTapImage;
  final VoidCallback onBrowse;

  const _DocumentSlot({required this.title, required this.icon, required this.imagePath, required this.onTapImage, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    const double previewHeight = 200;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.lg),
      child: DsCard(
        padding: const EdgeInsets.all(DsSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DsIconWell(icon: icon, size: 36, tone: DsTone.neutral),
                const DsGap(DsSpace.md),
                Expanded(child: Text(title, style: t.titleSm.withColor(c.textPrimary))),
                if (imagePath.isNotEmpty) Icon(Icons.check_circle_rounded, color: c.success, size: 22),
              ],
            ),
            const DsGap(DsSpace.md),
            AnimatedSwitcher(
              duration: DsMotion.of(context, DsMotion.base),
              child: imagePath.isNotEmpty
                  ? InkWell(
                      key: const ValueKey('image'),
                      borderRadius: DsRadius.brMd,
                      onTap: onTapImage,
                      child: ClipRRect(
                        borderRadius: DsRadius.brMd,
                        child: SizedBox(
                          height: previewHeight,
                          width: double.infinity,
                          child: Constant().hasValidUrl(imagePath) == false
                              ? Image.file(File(imagePath), fit: BoxFit.cover)
                              : CachedNetworkImage(
                                  imageUrl: imagePath.toString(),
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => DsShimmer(
                                    child: DsSkeleton.box(height: previewHeight, radius: DsRadius.md),
                                  ),
                                  errorWidget: (context, url, error) => Image.network(
                                    'https://firebasestorage.googleapis.com/v0/b/goride-1a752.appspot.com/o/placeholderImages%2Fuser-placeholder.jpeg?alt=media&token=34a73d67-ba1d-4fe4-a29f-271d3e3ca115',
                                  ),
                                ),
                        ),
                      ),
                    )
                  : DottedBorder(
                      key: const ValueKey('empty'),
                      options: RoundedRectDottedBorderOptions(radius: const Radius.circular(DsRadius.md), dashPattern: const [6, 6, 6, 6], color: c.borderStrong),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: previewHeight),
                        padding: const EdgeInsets.all(DsSpace.lg),
                        decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset('assets/icons/ic_folder.svg', height: 44),
                            const DsGap(DsSpace.md),
                            Text("Choose a image and upload here".tr, textAlign: TextAlign.center, style: t.bodyStrong.withColor(c.textPrimary)),
                            const DsGap(DsSpace.xs),
                            Text("JPEG, PNG".tr, style: t.caption),
                            const DsGap(DsSpace.md),
                            DsButton.tonal(label: "Brows Image".tr, icon: Icons.add_photo_alternate_outlined, size: DsButtonSize.sm, onPressed: onBrowse),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Camera / Gallery chooser used by the image bottom sheet.
class _PickerSheet extends StatelessWidget {
  final String title;
  final String cameraLabel;
  final String galleryLabel;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _PickerSheet({required this.title, required this.cameraLabel, required this.galleryLabel, required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    Widget option(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: DsCard.outlined(
        onTap: onTap,
        semanticLabel: label,
        padding: const EdgeInsets.symmetric(vertical: DsSpace.xl, horizontal: DsSpace.md),
        child: Column(
          children: [
            DsIconWell(icon: icon, size: 52, circle: true),
            const DsGap(DsSpace.sm),
            Text(label, textAlign: TextAlign.center, style: t.label.withColor(c.textPrimary)),
          ],
        ),
      ),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.xl, DsSpace.xl, DsSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, textAlign: TextAlign.center, style: t.title.withColor(c.textPrimary)),
            const DsGap(DsSpace.lg),
            Row(children: [option(Icons.photo_camera_outlined, cameraLabel, onCamera), const DsGap(DsSpace.md), option(Icons.photo_library_outlined, galleryLabel, onGallery)]),
          ],
        ),
      ),
    );
  }
}

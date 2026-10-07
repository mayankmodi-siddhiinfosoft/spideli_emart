import 'dart:io';

import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/edit_profile_controller.dart';
import 'package:driver/app/chat_screens/full_screen_image_viewer.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/zone_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/company_profile.dart';
import 'package:driver/utils/network_image_widget.dart';
import 'package:driver/widget/zone_multi_select.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

/// Archetype K – profile: an identity hero (avatar + name) over grouped form
/// sections, with Save pinned in a sticky bar.
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
        init: EditProfileController(),
        builder: (controller) {
          final c = context.dsColors;
          final t = context.dsText;

          // Read every observable inside the tracked builder.
          final String profileImage = controller.profileImage.value;
          final bool hasLocalImage = profileImage.isNotEmpty && Constant().hasValidUrl(profileImage) == false;
          final String remoteImage = controller.userModel.value.profilePictureURL.toString();
          // A company picks several zones in its own section below.
          final bool hideZone = controller.userModel.value.isCompany ||
              (controller.userModel.value.vendorID != null && controller.userModel.value.vendorID!.isNotEmpty);
          final bool zoneLocked = controller.userModel.value.ownerId != null && controller.userModel.value.ownerId!.isNotEmpty;
          final ZoneModel selectedZone = controller.selectedZone.value;
          final List<ZoneModel> zones = controller.zoneList.toList();
          final String fullName = "${controller.firstNameController.value.text} ${controller.lastNameController.value.text}".trim();
          // Report Doc 38 / 43: a delivery company sees and keeps its own
          // company details and zones here.
          final bool isCompany = controller.userModel.value.isCompany;
          final UserModel profile = controller.userModel.value;
          final Map<String, String> pendingFiles = Map<String, String>.from(controller.pendingCompanyFiles);
          final List<String> companyZoneIds = controller.companyZoneIds.toList();
          final List<ZoneModel> companyZoneChoices = isCompany ? controller.companyZoneChoices : const <ZoneModel>[];

          return DsScaffold(
            title: "Edit Profile".tr,
            body: DsAsync(
              isLoading: controller.isLoading.value,
              skeleton: const Padding(
                padding: EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xl),
                child: DsSkeletonForm(fields: 5),
              ),
              builder: (_) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.xl, DsSpace.lg, DsSpace.xxxl),
                child: DsResponsive(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: DsFadeSlideIn.stagger([
                      DsCard.gradient(
                        child: Row(
                          children: [
                            _ProfileAvatar(
                              profileImage: profileImage,
                              hasLocalImage: hasLocalImage,
                              remoteImage: remoteImage,
                              onEdit: () => buildBottomSheet(context, controller),
                            ),
                            const DsGap(DsSpace.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName.isEmpty ? "Edit Profile".tr : fullName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: DsTypography.title.copyWith(color: Colors.white),
                                  ),
                                  const DsGap(DsSpace.xxs),
                                  Text(
                                    controller.emailController.value.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DsTypography.bodySm.copyWith(color: Colors.white.withValues(alpha: 0.82)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const DsGap(DsSpace.xl),
                      DsFormSection(
                        title: "Your details".tr,
                        icon: Icons.person_outline_rounded,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DsTextField(
                                  label: 'First Name'.tr,
                                  controller: controller.firstNameController.value,
                                  hint: 'First Name'.tr,
                                  textCapitalization: TextCapitalization.words,
                                ),
                              ),
                              const DsGap(DsSpace.md),
                              Expanded(
                                child: DsTextField(
                                  label: 'Last Name'.tr,
                                  controller: controller.lastNameController.value,
                                  hint: 'Last Name'.tr,
                                  textCapitalization: TextCapitalization.words,
                                ),
                              ),
                            ],
                          ),
                          DsTextField(
                            label: 'Email'.tr,
                            keyboardType: TextInputType.emailAddress,
                            controller: controller.emailController.value,
                            hint: 'Email'.tr,
                            enabled: false,
                            prefixIcon: Icons.mail_outline_rounded,
                          ),
                          DsTextField(
                            label: 'Phone Number'.tr,
                            keyboardType: TextInputType.emailAddress,
                            controller: controller.phoneNumberController.value,
                            hint: 'Phone Number'.tr,
                            enabled: false,
                            prefixIcon: Icons.smartphone_rounded,
                            bottomSpacing: 0,
                          ),
                        ],
                      ),
                      if (isCompany) ...[
                        const DsGap(DsSpace.lg),
                        DsFormSection(
                          title: "Company details".tr,
                          subtitle: "Registered numbers and documents are checked by the administrator. Contact them to change one.".tr,
                          icon: Icons.apartment_rounded,
                          children: [
                            DsTextField(
                              label: 'Company Name'.tr,
                              controller: controller.companyFields['companyName'],
                              hint: 'Enter Company Name'.tr,
                              requiredMark: true,
                              textCapitalization: TextCapitalization.words,
                            ),
                            DsTextField(
                              label: 'Company Address'.tr,
                              controller: controller.companyFields['companyAddress'],
                              hint: 'Enter Company Address'.tr,
                              requiredMark: true,
                              prefixIcon: Icons.location_on_outlined,
                              minLines: 1,
                              maxLines: 3,
                            ),
                            for (final field in CompanyProfile.numberFields)
                              DsTextField(
                                label: CompanyProfile.labels[field]!.tr,
                                controller: controller.companyFields[field],
                                hint: CompanyProfile.labels[field]!.tr,
                                enabled: !controller.numberLocked(field),
                                bottomSpacing: field == CompanyProfile.numberFields.last ? 0 : DsSpace.lg,
                              ),
                          ],
                        ),
                        const DsGap(DsSpace.lg),
                        DsFormSection(
                          title: "Company documents".tr,
                          icon: Icons.folder_open_rounded,
                          children: [
                            for (final field in CompanyProfile.fileFields)
                              _CompanyDocumentRow(
                                title: CompanyProfile.labels[field]!.tr,
                                storedUrl: CompanyProfile.valueOf(profile, field),
                                pickedPath: pendingFiles[field],
                                onPick: (source) => controller.pickCompanyFile(field, source),
                              ),
                          ],
                        ),
                        const DsGap(DsSpace.lg),
                        DsFormSection(
                          title: "Zones you serve".tr,
                          icon: Icons.map_outlined,
                          children: [
                            if (companyZoneChoices.isEmpty)
                              DsInlineAlert(
                                tone: DsTone.warning,
                                icon: Icons.map_outlined,
                                message: "No zone is available in this management zone yet.".tr,
                              )
                            else
                              ZoneMultiSelect(
                                zones: companyZoneChoices,
                                selectedIds: companyZoneIds,
                                onToggle: controller.toggleCompanyZone,
                              ),
                          ],
                        ),
                      ],
                      if (hideZone)
                        const SizedBox()
                      else ...[
                        const DsGap(DsSpace.lg),
                        DsFormSection(
                          title: "Zone".tr,
                          icon: Icons.map_outlined,
                          children: [
                            DsDropdown<ZoneModel>(
                              hint: 'Select zone'.tr,
                              value: selectedZone.id == null ? null : selectedZone,
                              onChanged: zoneLocked
                                  ? null
                                  : (value) {
                                      controller.selectedZone.value = value!;
                                      controller.update();
                                    },
                              items: zones.map((item) {
                                return DropdownMenuItem<ZoneModel>(
                                  value: item,
                                  child: Text(item.name.toString(), style: t.bodyStrong),
                                );
                              }).toList(),
                              bottomSpacing: 0,
                            ),
                            if (zoneLocked)
                              Padding(
                                padding: const EdgeInsets.only(top: DsSpace.sm),
                                child: Text(
                                  "Managed by your fleet owner".tr,
                                  style: t.caption.withColor(c.textMuted),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ], offset: const Offset(0, 18)),
                  ),
                ),
              ),
            ),
            bottomBar: DsStickyBar(
              child: DsButton.primary(
                label: "Save".tr,
                icon: Icons.check_rounded,
                size: DsButtonSize.lg,
                expand: true,
                onPressed: () async {
                  controller.saveData();
                },
              ),
            ),
          );
        });
  }

  Future buildBottomSheet(BuildContext context, EditProfileController controller) {
    final c = DsColors.of(context);
    return showModalBottomSheet(
      context: context,
      backgroundColor: c.surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: DsRadius.sheetTop),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                    Text("please select".tr, textAlign: TextAlign.center, style: t.title),
                    const DsGap(DsSpace.xl),
                    Row(
                      children: [
                        Expanded(
                          child: _PickerTile(
                            icon: Icons.camera_alt_rounded,
                            label: "camera".tr,
                            onTap: () => controller.pickFile(source: ImageSource.camera),
                          ),
                        ),
                        const DsGap(DsSpace.md),
                        Expanded(
                          child: _PickerTile(
                            icon: Icons.photo_library_rounded,
                            label: "gallery".tr,
                            onTap: () => controller.pickFile(source: ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Round profile picture with an edit badge (local file, network or the
/// bundled placeholder).
class _ProfileAvatar extends StatelessWidget {
  final String profileImage;
  final bool hasLocalImage;
  final String remoteImage;
  final VoidCallback onEdit;

  const _ProfileAvatar({
    required this.profileImage,
    required this.hasLocalImage,
    required this.remoteImage,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    const double size = 84;
    Widget picture;
    if (profileImage.isEmpty) {
      picture = Image.asset(Constant.userPlaceHolder, height: size, width: size, fit: BoxFit.cover);
    } else if (hasLocalImage) {
      picture = Image.file(File(profileImage), height: size, width: size, fit: BoxFit.cover);
    } else {
      picture = NetworkImageWidget(fit: BoxFit.cover, imageUrl: remoteImage, height: size, width: size);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.22),
          ),
          child: ClipOval(child: SizedBox(height: size, width: size, child: picture)),
        ),
        PositionedDirectional(
          bottom: -2,
          end: -2,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onEdit,
              child: Semantics(
                button: true,
                label: "Edit Profile".tr,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.photo_camera_rounded, size: 18, color: context.dsColors.brand),
                ),
              ),
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

/// One company document (report Doc 38): opens what is on file, or takes a
/// photo / picture for a document that is missing. A stored document is
/// replaced only through the administrator.
class _CompanyDocumentRow extends StatelessWidget {
  final String title;
  final String storedUrl;
  final String? pickedPath;
  final ValueChanged<ImageSource> onPick;

  const _CompanyDocumentRow({required this.title, required this.storedUrl, required this.pickedPath, required this.onPick});

  /// The stored URL is used exactly as saved: a Firebase Storage URL is
  /// already encoded, and encoding it again breaks its token.
  static Future<void> open(String url) async {
    final Uri? uri = CompanyProfile.fileUri(url);
    if (uri == null) {
      ShowToastDialog.showToast("This document cannot be opened.".tr);
      return;
    }
    if (CompanyProfile.isImage(url)) {
      Get.to(() => FullScreenImageViewer(imageUrl: url));
      return;
    }
    bool opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) ShowToastDialog.showToast("This document cannot be opened.".tr);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool onFile = CompanyProfile.fileUri(storedUrl) != null;
    final bool picked = (pickedPath ?? '').isNotEmpty;
    final String status = onFile
        ? 'Document on file'.tr
        : picked
            ? "${pickedPath!.split('/').last} · ${'Saved when you tap Save'.tr}"
            : 'Not uploaded'.tr;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: Row(
        children: [
          DsIconWell(
            icon: onFile || picked ? Icons.check_circle_outline_rounded : Icons.upload_file_rounded,
            tone: onFile ? DsTone.success : (picked ? DsTone.info : DsTone.warning),
            size: 40,
          ),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.bodyStrong),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.withColor(onFile ? c.successStrong : c.textMuted),
                ),
              ],
            ),
          ),
          if (onFile)
            DsButton.secondary(
              label: 'View'.tr,
              icon: Icons.visibility_outlined,
              size: DsButtonSize.sm,
              onPressed: () => open(storedUrl),
            )
          else
            PopupMenuButton<ImageSource>(
              icon: Icon(Icons.add_a_photo_outlined, color: c.brand),
              tooltip: "Upload".tr,
              onSelected: onPick,
              itemBuilder: (_) => [
                PopupMenuItem(value: ImageSource.camera, child: Text("Camera".tr)),
                PopupMenuItem(value: ImageSource.gallery, child: Text("Gallery".tr)),
              ],
            ),
        ],
      ),
    );
  }
}

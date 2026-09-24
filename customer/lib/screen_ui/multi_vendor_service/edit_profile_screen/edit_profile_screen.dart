import 'dart:io';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/edit_profile_controller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// Archetype **H — profile form**: an avatar hero with an edit affordance,
/// grouped form sections and the save action in a sticky bar.
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  static const double _avatarSize = 108;

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: EditProfileController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final l = context.dsLayout;
        final imagePath = controller.profileImage.value;
        final hasImage = controller.profileImage.isNotEmpty;
        final isRemote = Constant().hasValidUrl(imagePath) == true;

        final nameFields = [
          DsTextField(label: 'First Name'.tr, controller: controller.firstNameController.value, hint: 'First Name'.tr, textCapitalization: TextCapitalization.words),
          DsTextField(label: 'Last Name'.tr, controller: controller.lastNameController.value, hint: 'Last Name'.tr, textCapitalization: TextCapitalization.words),
        ];

        return DsScaffold(
          title: "Profile Information".tr,
          maxContentWidth: DsLayout.contentMax,
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Save Details".tr,
              size: DsButtonSize.lg,
              expand: true,
              icon: Icons.check_rounded,
              onPressed: () async {
                controller.saveData();
              },
            ),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, DsSpace.xxxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: DsFadeSlideIn.stagger([
                  Text("View and update your personal details, contact information, and preferences.".tr, style: t.bodySecondary),
                  const DsGap(DsSpace.xxl),
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(shape: BoxShape.circle, gradient: DsGradients.brand(context), boxShadow: DsShadows.glow(context)),
                          child: ClipOval(
                            child: SizedBox.square(
                              dimension: _avatarSize,
                              child: !hasImage
                                  ? Image.asset(Constant.userPlaceHolder, fit: BoxFit.cover)
                                  : !isRemote
                                  ? Image.file(File(imagePath), fit: BoxFit.cover)
                                  : NetworkImageWidget(
                                      fit: BoxFit.cover,
                                      imageUrl: imagePath,
                                      height: _avatarSize,
                                      width: _avatarSize,
                                      errorWidget: Image.asset(Constant.userPlaceHolder, fit: BoxFit.cover, height: _avatarSize, width: _avatarSize),
                                    ),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          bottom: -4,
                          end: -4,
                          child: Material(
                            color: c.surface,
                            shape: const CircleBorder(),
                            child: DsIconButton(
                              icon: Icons.photo_camera_outlined,
                              semanticLabel: "please select".tr,
                              variant: DsIconButtonVariant.filled,
                              size: 40,
                              onPressed: () {
                                buildBottomSheet(context, controller);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.xxl),
                  DsFormSection(
                    title: 'Profile Information'.tr,
                    icon: Icons.person_outline_rounded,
                    children: [
                      if (l.isTablet || l.isDesktop) DsAdaptiveGrid(minItemWidth: 200, equalHeight: false, children: nameFields) else ...nameFields,
                    ],
                  ),
                  DsFormSection(
                    title: 'Contact'.tr,
                    icon: Icons.contact_mail_outlined,
                    children: [
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
                  const DsGap(DsSpace.md),
                  Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 16, color: c.textMuted),
                      const DsGap(DsSpace.sm),
                      Expanded(child: Text("Email and phone number are verified and cannot be edited here.".tr, style: t.caption)),
                    ],
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  Future buildBottomSheet(BuildContext context, EditProfileController controller) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DsSheet(
              title: "please select".tr,
              child: Row(
                children: [
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.photo_camera_outlined,
                      label: "camera".tr,
                      onTap: () => controller.pickFile(source: ImageSource.camera),
                    ),
                  ),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.photo_library_outlined,
                      label: "gallery".tr,
                      onTap: () => controller.pickFile(source: ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// One source choice in the "please select" sheet.
class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return DsCard.outlined(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.xl, horizontal: DsSpace.md),
      onTap: onTap,
      semanticLabel: label,
      child: Column(
        children: [
          DsIconWell(icon: icon, tone: DsTone.brand, size: 52, circle: true),
          const DsGap(DsSpace.md),
          Text(label, textAlign: TextAlign.center, style: t.label),
        ],
      ),
    );
  }
}

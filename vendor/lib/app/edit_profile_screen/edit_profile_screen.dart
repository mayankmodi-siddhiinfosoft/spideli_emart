import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/edit_profile_controller.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/network_image_widget.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: EditProfileController(),
      builder: (controller) {
        final t = context.dsText;
        const double avatar = 104;

        Widget photo() => controller.profileImage.isEmpty
            ? Image.asset(Constant.userPlaceHolder, height: avatar, width: avatar, fit: BoxFit.cover)
            : Constant().hasValidUrl(controller.profileImage.value) == false
            ? Image.file(File(controller.profileImage.value), height: avatar, width: avatar, fit: BoxFit.cover)
            : NetworkImageWidget(
                fit: BoxFit.cover,
                imageUrl: controller.profileImage.value,
                height: avatar,
                width: avatar,
                errorWidget: Image.asset(Constant.userPlaceHolder, fit: BoxFit.cover, height: avatar, width: avatar),
              );

        return DsScaffold.hero(
          title: "Edit Profile".tr,
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
          hero: Center(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.28)),
                      child: ClipOval(
                        child: AnimatedSwitcher(
                          duration: DsMotion.of(context, DsMotion.base),
                          child: SizedBox.square(key: ValueKey(controller.profileImage.value), dimension: avatar, child: photo()),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      bottom: -4,
                      end: -4,
                      child: DsIconButton(
                        icon: Icons.photo_camera_rounded,
                        semanticLabel: 'Change photo'.tr,
                        variant: DsIconButtonVariant.filled,
                        size: 40,
                        onPressed: () {
                          buildBottomSheet(context, controller);
                        },
                      ),
                    ),
                  ],
                ),
                const DsGap(DsSpace.md),
                Text(
                  "${controller.firstNameController.value.text} ${controller.lastNameController.value.text}".trim(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.title.withColor(Colors.white),
                ),
                const DsGap(DsSpace.sm),
              ],
            ),
          ),
          slivers: [
            DsSliverResponsive(
              top: DsSpace.xl,
              sliver: SliverToBoxAdapter(
                child: controller.isLoading.value
                    ? const DsSkeletonForm(fields: 4)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: DsFadeSlideIn.stagger([
                          DsFormSection(
                            title: 'Personal details'.tr,
                            icon: Icons.person_outline_rounded,
                            children: [
                              DsAdaptiveGrid(
                                minItemWidth: 240,
                                equalHeight: false,
                                children: [
                                  DsTextField(
                                    label: 'First Name'.tr,
                                    controller: controller.firstNameController.value,
                                    hint: 'First Name'.tr,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  DsTextField(label: 'Last Name'.tr, controller: controller.lastNameController.value, hint: 'Last Name'.tr),
                                ],
                              ),
                            ],
                          ),
                          DsFormSection(
                            title: 'Contact'.tr,
                            subtitle: 'These details are linked to your account and can’t be edited here.'.tr,
                            icon: Icons.contact_mail_outlined,
                            children: [
                              DsTextField(
                                label: 'Email'.tr,
                                keyboardType: TextInputType.emailAddress,
                                controller: controller.emailController.value,
                                hint: 'Email'.tr,
                                enabled: false,
                                prefixIcon: Icons.mail_outline_rounded,
                                suffix: const Icon(Icons.lock_outline_rounded, size: 18),
                              ),
                              DsTextField(
                                label: 'Phone Number'.tr,
                                keyboardType: TextInputType.emailAddress,
                                controller: controller.phoneNumberController.value,
                                hint: 'Phone Number'.tr,
                                enabled: false,
                                prefixIcon: Icons.phone_outlined,
                                suffix: const Icon(Icons.lock_outline_rounded, size: 18),
                              ),
                            ],
                          ),
                        ]),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future buildBottomSheet(BuildContext context, EditProfileController controller) {
    return showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                    Text("please select".tr, textAlign: TextAlign.center, style: t.title.withColor(c.textPrimary)),
                    const DsGap(DsSpace.lg),
                    Row(
                      children: [
                        option(Icons.photo_camera_outlined, "camera".tr, () => controller.pickFile(source: ImageSource.camera)),
                        const DsGap(DsSpace.md),
                        option(Icons.photo_library_outlined, "gallery".tr, () => controller.pickFile(source: ImageSource.gallery)),
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

import 'dart:io';

import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/dashboard_controller.dart';
import 'package:spideliprovider/controller/profile_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class EditProfileScreen extends StatelessWidget {
  EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes this screen to theme changes (colors come from the DS).
    Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    return GetX<ProfileController>(
      init: ProfileController(),
      builder: (controller) {
        final bool loading = controller.isLoading.value;
        return DsScaffold(
          backgroundColor: c.background,
          appBar: const DsAppBar(title: "Edit Profile"),
          body: loading
              ? const DsSkeletonForm(fields: 4)
              : Form(
                  key: controller.key.value,
                  autovalidateMode: controller.validate,
                  child: SingleChildScrollView(
                    child: DsResponsive(
                      maxWidth: DsLayout.contentMax,
                      padded: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: DsFadeSlideIn.stagger([
                          const DsGap(DsSpace.xxl),
                          // Avatar plate: the picture is the hero of this
                          // form, with the camera affordance on its edge.
                          Center(
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                // displayCircleImage(MyAppState.currentUser!.profilePictureURL, 130, false),
                                DsAvatar(
                                  imageUrl: MyAppState.currentUser!.profilePictureURL.toString(),
                                  name: controller.firstName.value.text,
                                  size: 120,
                                  ring: true,
                                  onTap: () => _onCameraClick(context, controller),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 4, bottom: 4),
                                  child: DsIconButton(
                                    icon: Icons.camera_alt_rounded,
                                    semanticLabel: 'Add Profile Picture'.tr,
                                    variant: DsIconButtonVariant.brand,
                                    size: 44,
                                    onPressed: () => _onCameraClick(context, controller),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const DsGap(DsSpace.xxl),
                          DsFormSection(
                            title: 'Personal details'.tr,
                            icon: Icons.person_outline_rounded,
                            children: [
                              DsTextField(
                                label: 'First Name'.tr,
                                hint: 'First Name'.tr,
                                controller: controller.firstName.value,
                                validator: validateName,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                                prefixIcon: Icons.person_outline_rounded,
                              ),
                              DsTextField(
                                label: 'Last Name'.tr,
                                hint: 'Last Name'.tr,
                                controller: controller.lastName.value,
                                validator: validateName,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                                bottomSpacing: DsSpace.none,
                                prefixIcon: Icons.person_outline_rounded,
                              ),
                            ],
                          ),
                          DsFormSection(
                            title: 'Contact'.tr,
                            icon: Icons.contact_mail_outlined,
                            subtitle: 'Managed by your account – contact support to change these.'.tr,
                            children: [
                              DsTextField(
                                label: 'Phone Number'.tr,
                                hint: 'Phone Number'.tr,
                                controller: controller.mobile.value,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: validateEmail,
                                enabled: false,
                                prefixIcon: Icons.call_outlined,
                              ),
                              DsTextField(
                                label: 'Email Address'.tr,
                                hint: 'Email Address'.tr,
                                controller: controller.email.value,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: validateEmail,
                                enabled: false,
                                bottomSpacing: DsSpace.none,
                                prefixIcon: Icons.mail_outline_rounded,
                              ),
                            ],
                          ),
                          const DsGap(DsSpace.xxl),
                        ]),
                      ),
                    ),
                  ),
                ),
          bottomBar: loading
              ? null
              : DsStickyBar(
                  child: DsButton.primary(
                    label: 'Save'.tr,
                    icon: Icons.check_rounded,
                    expand: true,
                    size: DsButtonSize.lg,
                    onPressed: () {
                      _validateAndSave(controller, context);
                    },
                  ),
                ),
        );
      },
    );
  }

  final ImagePicker imagePicker = ImagePicker();

  _onCameraClick(context, controller) {
    final action = CupertinoActionSheet(
      message: const Text('Add Profile Picture', style: TextStyle(fontSize: 15.0)),
      actions: <Widget>[
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () async {
            Get.back();
            ShowToastDialog.showLoader('removingPicture'.tr);
            MyAppState.currentUser!.profilePictureURL = '';
            await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);
            ShowToastDialog.closeLoader();
            controller.update();
          },
          child: Text('Remove picture'.tr),
        ),
        CupertinoActionSheetAction(
          child: Text('Choose image from gallery'.tr),
          onPressed: () async {
            Get.back();
            XFile? image = await imagePicker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              await _imagePicked(File(image.path), controller, context);
            }
            controller.update();
          },
        ),
        CupertinoActionSheetAction(
          child: const Text('Take a picture'),
          onPressed: () async {
            Get.back();
            XFile? image = await imagePicker.pickImage(source: ImageSource.camera);
            if (image != null) {
              await _imagePicked(File(image.path), controller, context);
            }
            controller.update();
          },
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        child: const Text('Cancel'),
        onPressed: () {
          Get.back();
        },
      ),
    );
    showCupertinoModalPopup(context: context, builder: (context) => action);
  }

  Future<void> _imagePicked(File image, ProfileController controller, context) async {
    ShowToastDialog.showLoader('Uploading image...'.tr);
    MyAppState.currentUser!.profilePictureURL = await FireStoreUtils.uploadUserImageToFireStorage(image, MyAppState.currentUser!.id);
    await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);
    ShowToastDialog.closeLoader();
    controller.getData();
    DashBoardController dashBoardController = Get.put(DashBoardController());
    dashBoardController.getData();
    Get.back();
  }

  _validateAndSave(ProfileController controller, BuildContext context) async {
    if (controller.key.value.currentState!.validate()) {
      controller.key.value.currentState!.save();
      ShowToastDialog.showLoader('Saving details...'.tr);
      await _updateUser(controller);
    } else {
      controller.validate = AutovalidateMode.onUserInteraction;
    }
  }

  _updateUser(controller) async {
    MyAppState.currentUser!.firstName = controller.firstName.value.text.toString();
    MyAppState.currentUser!.lastName = controller.lastName.value.text.toString();
    MyAppState.currentUser!.email = controller.email.value.text.toString();
    MyAppState.currentUser!.phoneNumber = controller.mobile.value.text.toString();
    await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!).then((value) {
      if (value != null) {
        MyAppState.currentUser = value;
        controller.update();

        Get.showSnackbar(GetSnackBar(message: 'Details Saved Successfully'.tr));
      } else {
        Get.showSnackbar(GetSnackBar(message: 'Could Not Save Details Please Try Again'.tr));
      }
    });
    ShowToastDialog.closeLoader();
  }
}

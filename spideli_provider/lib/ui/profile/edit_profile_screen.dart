import 'dart:io';

import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/dashboard_controller.dart';
import 'package:spideliprovider/controller/profile_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/responsive.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/widgets/common_ui.dart';
import 'package:spideliprovider/widgets/network_image_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class EditProfileScreen extends StatelessWidget {
  EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<ProfileController>(
        init: ProfileController(),
        builder: (controller) {
          return Scaffold(
              appBar: CommonUI.customAppBar(context,
                  title: Text(
                    "Edit Profile",
                    style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontSize: 18, fontFamily: AppColors.semiBold),
                  ),
                  isBack: true),
              body: controller.isLoading.value
                  ? Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                      child: Form(
                        key: controller.key.value,
                        autovalidateMode: controller.validate,
                        child: SingleChildScrollView(
                          child: Column(children: [
                            Center(
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  // displayCircleImage(MyAppState.currentUser!.profilePictureURL, 130, false),
                                  ClipOval(
                                    child: NetworkImageWidget(
                                      imageUrl: MyAppState.currentUser!.profilePictureURL.toString(),
                                      height: Responsive.width(30, context),
                                      width: Responsive.width(30, context),
                                    ),
                                  ),
                                  Positioned(
                                    right: 5,
                                    child: InkWell(
                                      onTap: () => _onCameraClick(context, controller),
                                      child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.all(Radius.circular(30)),
                                            color: AppColors.colorPrimary,
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt,
                                            color: AppColors.colorWhite,
                                          )),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(
                              height: 20,
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: double.infinity),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 16.0, right: 8.0, left: 8.0),
                                child: TextFormField(
                                  controller: controller.firstName.value,
                                  cursorColor: AppColors.colorPrimary,
                                  textAlignVertical: TextAlignVertical.center,
                                  validator: validateName,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                    fillColor: Colors.white,
                                    hintText: 'First Name'.tr,
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(25.0),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(25.0),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(25.0),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: double.infinity),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 16.0, right: 8.0, left: 8.0),
                                child: TextFormField(
                                  controller: controller.lastName.value,
                                  validator: validateName,
                                  textAlignVertical: TextAlignVertical.center,
                                  cursorColor: AppColors.colorPrimary,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                    fillColor: Colors.white,
                                    hintText: 'Last Name'.tr,
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(25.0),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(25.0),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(25.0),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: double.infinity),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 16.0, right: 8.0, left: 8.0),
                                child: TextFormField(
                                  controller: controller.mobile.value,
                                  keyboardType: TextInputType.emailAddress,
                                  textAlignVertical: TextAlignVertical.center,
                                  textInputAction: TextInputAction.next,
                                  cursorColor: AppColors.colorPrimary,
                                  validator: validateEmail,
                                  enabled: false,
                                  onSaved: (String? val) {},
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                    fillColor: Colors.white,
                                    hintText: 'Phone Number'.tr,
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(25.0),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(25.0),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(25.0),
                                    ),
                                    disabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(25.0),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: double.infinity),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 16.0, right: 8.0, left: 8.0),
                                child: TextFormField(
                                  controller: controller.email.value,
                                  keyboardType: TextInputType.emailAddress,
                                  textAlignVertical: TextAlignVertical.center,
                                  textInputAction: TextInputAction.next,
                                  cursorColor: AppColors.colorPrimary,
                                  validator: validateEmail,
                                  enabled: false,
                                  onSaved: (String? val) {},
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                    fillColor: Colors.white,
                                    hintText: 'Email Address'.tr,
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(25.0),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                      borderRadius: BorderRadius.circular(25.0),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(25.0),
                                    ),
                                    disabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(25.0),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: 36,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 40.0, left: 40.0, top: 40.0),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: double.infinity),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.colorPrimary,
                                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25.0),
                                      side: BorderSide(
                                        color: AppColors.colorPrimary,
                                      ),
                                    ),
                                  ),
                                  onPressed: () {
                                    _validateAndSave(controller, context);
                                  },
                                  child: Text(
                                    'Save'.tr,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: themeChange.getTheme() ? Colors.black : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          ]),
                        ),
                      )));
        });
  }

  final ImagePicker imagePicker = ImagePicker();

  _onCameraClick(context, controller) {
    final action = CupertinoActionSheet(
      message: const Text(
        'Add Profile Picture',
        style: TextStyle(fontSize: 15.0),
      ),
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

        Get.showSnackbar(
          GetSnackBar(
            message: 'Details Saved Successfully'.tr,
          ),
        );
      } else {
        Get.showSnackbar(
          GetSnackBar(
            message: 'Could Not Save Details Please Try Again'.tr,
          ),
        );
      }
    });
    ShowToastDialog.closeLoader();
  }
}

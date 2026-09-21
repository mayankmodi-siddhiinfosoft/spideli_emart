import 'dart:io';

import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/controller/profile_controller.dart';
import 'package:spideliworker/main.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/themes/app_colors.dart';
import 'package:spideliworker/themes/responsive.dart';
import 'package:spideliworker/ui/chat_screen/inbox_screen.dart';
import 'package:spideliworker/ui/help_support_screen/help_support_screen.dart';
import 'package:spideliworker/ui/language_screen.dart';
import 'package:spideliworker/ui/login/login_screen.dart';
import 'package:spideliworker/ui/privacyPolicy/privacy_policy.dart';
import 'package:spideliworker/ui/termsAndCondition/terms_and_codition.dart';
import 'package:spideliworker/ui/theme_change_screen/theme_change_screen.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:spideliworker/widgets/common_ui.dart';
import 'package:spideliworker/widgets/network_image_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<ProfileController>(
        init: ProfileController(),
        builder: (controller) {
          return Scaffold(
              appBar: CommonUI.customAppBar(
                context,
                title: Text(
                  "Profile".tr,
                  style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontSize: 18, fontFamily: AppColors.semiBold),
                ),
                isBack: false,
                actions: [
                  InkWell(
                    onTap: () {
                      viewProviderInfo(controller, themeChange, context);
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.info_outline),
                    ),
                  )
                ],
              ),
              body: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: SingleChildScrollView(
                    child: Column(children: [
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                ClipOval(
                                  child: NetworkImageWidget(
                                    imageUrl: MyAppState.currentUser!.profilePictureURL.toString(),
                                    height: Responsive.width(30, context),
                                    width: Responsive.width(30, context),
                                    fit: BoxFit.cover,
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
                                          borderRadius: const BorderRadius.all(Radius.circular(30)),
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
                            Padding(
                              padding: const EdgeInsets.only(top: 15),
                              child: Text(
                                MyAppState.currentUser!.fullName(),
                                style: TextStyle(color: themeChange.getTheme() ? AppColors.colorWhite : AppColors.colorDark, fontSize: 16, fontFamily: AppColors.semiBold),
                              ),
                            ),
                            Text(
                              MyAppState.currentUser!.email.toString(),
                              style: TextStyle(color: themeChange.getTheme() ? AppColors.colorWhite : AppColors.colorDark, fontSize: 14, fontFamily: AppColors.medium),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: SizedBox()),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Available Status'.tr,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(
                                          color: themeChange.getTheme() ? AppColors.assetColorGrey100 : AppColors.assetColorGrey1000,
                                          fontSize: 16,
                                          fontFamily: AppColors.semiBold,
                                        ),
                                      ),
                                      MyAppState.currentUser?.online == true
                                          ? Text(
                                              'You are online'.tr,
                                              textAlign: TextAlign.start,
                                              style: TextStyle(
                                                color: AppColors.colorPrimary,
                                                fontSize: 14,
                                              ),
                                            )
                                          : Text(
                                              'You are offline'.tr,
                                              textAlign: TextAlign.start,
                                              style: const TextStyle(
                                                color: AppColors.colorDeepOrange,
                                                fontSize: 14,
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                                Transform.scale(
                                  scale: 0.8,
                                  child: CupertinoSwitch(
                                    activeTrackColor: AppColors.colorPrimary,
                                    value: controller.online.value,
                                    onChanged: (value) async {
                                      controller.online.value = value;
                                      MyAppState.currentUser!.online = controller.online.value;
                                      await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);
                                      controller.update();
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(
                                color: AppColors.assetColorGrey300,
                              ),
                            ),
                            InkWell(
                                onTap: () {
                                  Get.to(const InboxScreen());
                                },
                                child: profileView(title: "Inbox", context: context, themeChange: themeChange)),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(
                                color: AppColors.assetColorGrey300,
                              ),
                            ),
                            InkWell(
                                onTap: () {
                                  Get.to(const ThemeChangeScreen());
                                },
                                child: profileView(title: "App Theme", context: context, themeChange: themeChange)),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(
                                color: AppColors.assetColorGrey300,
                              ),
                            ),
                            InkWell(
                                onTap: () {
                                  Get.to(const LanguageScreen());
                                },
                                child: profileView(title: "App Language", context: context, themeChange: themeChange)),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(
                                color: AppColors.assetColorGrey300,
                              ),
                            ),
                            InkWell(
                                onTap: () {
                                  Get.to(HelpSupportScreen(isNavigateViaNotification: false));
                                },
                                child: profileView(title: "Help & Support", context: context, themeChange: themeChange)),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(
                                color: AppColors.assetColorGrey300,
                              ),
                            ),
                            InkWell(
                                onTap: () {
                                  Get.to(const TermsAndCondition());
                                },
                                child: profileView(title: "Terms & Condition", context: context, themeChange: themeChange)),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(
                                color: AppColors.assetColorGrey300,
                              ),
                            ),
                            InkWell(
                                onTap: () {
                                  Get.to(const PrivacyPolicy());
                                },
                                child: profileView(title: "Privacy policy", context: context, themeChange: themeChange)),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(
                                color: AppColors.assetColorGrey300,
                              ),
                            ),
                            InkWell(
                                onTap: () async {
                                  MyAppState.currentUser = null;
                                  await FirebaseAuth.instance.signOut();
                                  Get.offAll(const LoginScreen());
                                },
                                child: profileView(title: "Logout", context: context, themeChange: themeChange)),
                          ],
                        ),
                      )
                    ]),
                  )));
        });
  }

  void viewProviderInfo(ProfileController controller, themeChange, context) {
    Get.bottomSheet(
      Container(
        height: Responsive.height(33, context),
        color: themeChange.getTheme() ? AppColors.colorDark : AppColors.assetColorGrey100,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      'My Provider'.tr,
                      style: TextStyle(color: themeChange.getTheme() ? AppColors.colorWhite : AppColors.colorDark, fontSize: 18, fontFamily: AppColors.semiBold),
                    )),
                Container(
                  margin: const EdgeInsets.only(top: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: themeChange.getTheme() ? Colors.black : AppColors.colorWhite,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            controller.provider.value.profilePictureURL != ""
                                ? CircleAvatar(backgroundImage: NetworkImage(controller.provider.value.profilePictureURL.toString()), radius: 30.0)
                                : CircleAvatar(backgroundImage: NetworkImage(placeholderImage), radius: 30.0),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    controller.provider.value.fullName().toString(),
                                    style: TextStyle(color: themeChange.getTheme() ? AppColors.colorWhite : AppColors.colorDark, fontSize: 16, fontFamily: AppColors.medium),
                                  ),
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  RatingBar.builder(
                                    initialRating: double.parse(controller.provider.value.reviewsCount != 0
                                        ? (controller.provider.value.reviewsSum / controller.provider.value.reviewsCount).toStringAsFixed(1)
                                        : 0.toString()),
                                    direction: Axis.horizontal,
                                    itemSize: 20,
                                    ignoreGestures: true,
                                    itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    itemBuilder: (context, _) => Icon(
                                      Icons.star,
                                      color: AppColors.colorPrimary,
                                    ),
                                    onRatingUpdate: (double rate) {},
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: -4.0),
                          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                          leading: const Icon(Icons.email_outlined),
                          title: Text(controller.provider.value.email.toString()),
                        ),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: -4.0),
                          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                          leading: const Icon(Icons.phone_in_talk_outlined),
                          title: Text(controller.provider.value.phoneNumber.toString()),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: themeChange.getTheme() ? AppColors.colorDark : AppColors.colorWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  void showDeleteAccountAlertDialog(BuildContext context) {
    // set up the button
    Widget okButton = TextButton(
      child: Text("Ok".tr),
      onPressed: () async {
        ShowToastDialog.showLoader("Please wait".tr);
        await FireStoreUtils.deleteUser();
        MyAppState.currentUser = null;
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Account delete".tr);
        Get.offAll(const LoginScreen());
        // await FireStoreUtils.deleteUser().then((value) {
        //   ShowToastDialog.closeLoader();
        //   if (value == true) {
        //     ShowToastDialog.showToast("Account delete".tr);
        //     Get.offAll(const LoginScreen());
        //   }
        // });
      },
    );
    Widget cancel = TextButton(
      child: Text("Cancel".tr),
      onPressed: () {
        Get.back();
      },
    );

    Get.defaultDialog(
        title: "Account delete".tr,
        content: Text("Are you sure want to delete Account.".tr),
        actions: [
          okButton,
          cancel,
        ],
        radius: 10.0);
  }

  Widget profileView({required String title, required BuildContext context, themeChange}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.tr,
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: title == "Logout"
                      ? Colors.red
                      : themeChange.getTheme()
                          ? AppColors.assetColorGrey100
                          : AppColors.assetColorGrey1000,
                  fontSize: 16,
                  fontFamily: AppColors.semiBold,
                ),
              ),
            ],
          ),
        ),
        SvgPicture.asset("assets/icons/ic_right.svg"),
      ],
    );
  }

  final ImagePicker imagePicker = ImagePicker();

  void _onCameraClick(context, controller) {
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
            showProgress(context, 'removingPicture'.tr, false);
            MyAppState.currentUser!.profilePictureURL = '';
            await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);
            hideProgress();
            controller.update();
          },
          child: Text('Remove picture'.tr),
        ),
        CupertinoActionSheetAction(
          child: Text('Choose Image From Gallery'.tr),
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
          child: Text('Take a picture'.tr),
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
        child: Text('Cancel'.tr),
        onPressed: () {
          Get.back();
        },
      ),
    );
    showCupertinoModalPopup(context: context, builder: (context) => action);
  }

  Future<void> _imagePicked(File image, controller, context) async {
    showProgress(context, 'Uploading image...'.tr, false);
    MyAppState.currentUser!.profilePictureURL = await FireStoreUtils.uploadUserImageToFireStorage(image, MyAppState.currentUser!.id.toString());
    await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);
    hideProgress();
    controller.update();
  }
}

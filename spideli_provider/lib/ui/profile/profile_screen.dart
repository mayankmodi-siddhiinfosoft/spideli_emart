import 'package:http/http.dart' as http;
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/profile_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/responsive.dart';
import 'package:spideliprovider/ui/auth/auth_screen.dart';
import 'package:spideliprovider/ui/language_screen/language_screen.dart';
import 'package:spideliprovider/ui/profile/edit_profile_screen.dart';
import 'package:spideliprovider/ui/theme_change_screen/theme_change_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/widgets/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<ProfileController>(
        init: ProfileController(),
        builder: (controller) {
          return Scaffold(
              body: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                  child: Column(children: [
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
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
                              onTap: () {
                                Get.to(EditProfileScreen());
                              },
                              child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.all(Radius.circular(30)),
                                    color: AppColors.colorPrimary,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        controller.user.value.firstName.toString(),
                        style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        controller.user.value.email.toString(),
                        style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                        border: Border.all(color: themeChange.getTheme() ? AppColors.darkContainerBorderColor : Colors.grey.shade100, width: 1),
                        color: themeChange.getTheme() ? AppColors.darkContainerBorderColor : AppColors.colorLightGrey,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: SizedBox()),
                            InkWell(
                                onTap: () {
                                  Get.to(const ThemChangeScreen());
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
                                  showDeleteAccountAlertDialog(context);
                                },
                                child: profileView(title: "Delete Account", context: context, themeChange: themeChange)),
                            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: SizedBox()),
                          ],
                        ),
                      ),
                    ),
                  ])));
        });
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
                  color: themeChange.getTheme() ? AppColors.assetColorGrey100 : AppColors.assetColorGrey1000,
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

  Future<bool> deleteUserFromServer() async {
    var url = '${providerUrl}/api/delete-user';
    try {
      var response = await http.post(
        Uri.parse(url),
        body: {
          'uuid': auth.FirebaseAuth.instance.currentUser!.uid,
        },
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  showDeleteAccountAlertDialog(BuildContext context) {
    // set up the button
    Widget okButton = TextButton(
      child: Text("Ok".tr),
      onPressed: () async {
        ShowToastDialog.showLoader("Please wait".tr);
        await deleteUserFromServer();
        await FireStoreUtils.deleteUser();
        MyAppState.currentUser = null;
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Account delete".tr);
        Get.offAll(AuthScreen());
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

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("Account delete".tr),
      content: Text("Are you sure want to delete Account.".tr),
      actions: [
        okButton,
        cancel,
      ],
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }
}

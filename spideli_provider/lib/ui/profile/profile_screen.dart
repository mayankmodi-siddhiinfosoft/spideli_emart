import 'package:http/http.dart' as http;
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/profile_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/auth/auth_screen.dart';
import 'package:spideliprovider/ui/language_screen/language_screen.dart';
import 'package:spideliprovider/ui/profile/edit_profile_screen.dart';
import 'package:spideliprovider/ui/theme_change_screen/theme_change_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes this screen to theme changes (colors come from the DS).
    Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    final t = context.dsText;
    return GetX<ProfileController>(
      init: ProfileController(),
      builder: (controller) {
        // Read the observables here so the GetX observer tracks them.
        final String firstName = controller.user.value.firstName.toString();
        final String email = controller.user.value.email.toString();
        return Scaffold(
          backgroundColor: c.background,
          body: SingleChildScrollView(
            child: DsResponsive(
              maxWidth: DsLayout.contentMax,
              padded: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: DsFadeSlideIn.stagger([
                  const DsGap(DsSpace.xxl),
                  // Identity card: avatar over a brand gradient with
                  // the edit shortcut on the card itself.
                  DsCard.gradient(
                    padding: const EdgeInsets.all(DsSpace.xxl),
                    child: Column(
                      children: [
                        DsAvatar(
                          imageUrl: MyAppState.currentUser!.profilePictureURL.toString(),
                          name: firstName,
                          size: 104,
                          ring: true,
                          onTap: () {
                            Get.to(EditProfileScreen());
                          },
                        ),
                        const DsGap(DsSpace.lg),
                        Text(
                          firstName,
                          textAlign: TextAlign.center,
                          style: DsTypography.title.copyWith(color: Colors.white),
                        ),
                        const DsGap(DsSpace.xxs),
                        Text(
                          email,
                          textAlign: TextAlign.center,
                          style: DsTypography.body.copyWith(color: Colors.white.withValues(alpha: 0.86)),
                        ),
                        const DsGap(DsSpace.xl),
                        DsButton(
                          label: 'Edit Profile'.tr,
                          icon: Icons.edit_outlined,
                          variant: DsButtonVariant.primary,
                          color: Colors.white,
                          onPressed: () {
                            Get.to(EditProfileScreen());
                          },
                        ),
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.xl),
                  DsTileGroup(
                    title: 'Preferences'.tr,
                    children: [
                      DsListTile(
                        title: "App Theme".tr,
                        leadingIcon: Icons.dark_mode_outlined,
                        leadingTone: DsTone.info,
                        showChevron: true,
                        onTap: () {
                          Get.to(const ThemChangeScreen());
                        },
                      ),
                      DsListTile(
                        title: "App Language".tr,
                        leadingIcon: Icons.translate_rounded,
                        leadingTone: DsTone.brand,
                        showChevron: true,
                        onTap: () {
                          Get.to(const LanguageScreen());
                        },
                      ),
                    ],
                  ),
                  const DsGap(DsSpace.lg),
                  DsTileGroup(
                    title: 'Account'.tr,
                    children: [
                      DsListTile(
                        title: "Delete Account".tr,
                        subtitle: 'This permanently removes your provider account.'.tr,
                        leadingIcon: Icons.delete_outline_rounded,
                        leadingTone: DsTone.danger,
                        destructive: true,
                        showChevron: true,
                        onTap: () {
                          showDeleteAccountAlertDialog(context);
                        },
                      ),
                    ],
                  ),
                  const DsGap(DsSpace.xxxl),
                  Center(child: Text('spideli Provider'.tr, style: t.caption)),
                  const DsGap(DsSpace.xxl),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> deleteUserFromServer() async {
    var url = '${providerUrl}/api/delete-user';
    try {
      var response = await http.post(Uri.parse(url), body: {'uuid': auth.FirebaseAuth.instance.currentUser!.uid});
      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  void showDeleteAccountAlertDialog(BuildContext context) {
    // set up the AlertDialog
    final alert = DsDialog(
      title: "Account delete".tr,
      message: "Are you sure want to delete Account.".tr,
      icon: Icons.person_remove_outlined,
      tone: DsTone.danger,
      destructive: true,
      primaryLabel: "Ok".tr,
      onPrimary: () async {
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
      secondaryLabel: "Cancel".tr,
      onSecondary: () {
        Get.back();
      },
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

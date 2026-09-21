import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/controller/login_controller.dart';
import 'package:spideliworker/themes/app_colors.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../themes/app_them_data.dart';
import '../../widgets/text_field_widget.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<LoginController>(
        init: LoginController(),
        builder: (controller) {
          return Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 50.0),
                    child: Text(
                      'Log In'.tr,
                      style: TextStyle(color: AppColors.colorPrimary, fontSize: 25.0, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFieldWidget(
                    title: 'Email'.tr,
                    controller: controller.emailController.value,
                    hintText: 'Enter email address'.tr,
                    prefix: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.asset("assets/icons/ic_mail.svg",
                          colorFilter: ColorFilter.mode(themeChange.getTheme() ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                    ),
                  ),
                  TextFieldWidget(
                    title: 'Password'.tr,
                    controller: controller.passwordController.value,
                    hintText: 'Enter Password'.tr,
                    obscureText: controller.passwordVisible.value,
                    prefix: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.asset("assets/icons/ic_lock.svg",
                          colorFilter: ColorFilter.mode(themeChange.getTheme() ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                    ),
                    suffix: Padding(
                      padding: const EdgeInsets.all(12),
                      child: InkWell(
                        onTap: () {
                          controller.passwordVisible.value = !controller.passwordVisible.value;
                        },
                        child: controller.passwordVisible.value
                            ? SvgPicture.asset(
                                "assets/icons/ic_password_show.svg",
                                colorFilter: ColorFilter.mode(themeChange.getTheme() ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn),
                              )
                            : SvgPicture.asset(
                                "assets/icons/ic_password_close.svg",
                                colorFilter: ColorFilter.mode(themeChange.getTheme() ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn),
                              ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () {
                        showResetPwdAlertDialog(context, controller);
                      },
                      child: Text(
                        "Forgot Password".tr,
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          decorationColor: AppThemeData.primary300,
                          color: themeChange.getTheme() ? AppThemeData.primary300 : AppThemeData.primary300,
                          fontSize: 14,
                          fontFamily: AppThemeData.regular,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.only(top: 40), // Removed left/right padding
                    child: SizedBox(
                      width: double.infinity, // Ensures full screen width
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.colorPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14), // Consistent vertical padding
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25.0),
                            side: BorderSide(
                              color: AppColors.colorPrimary,
                            ),
                          ),
                        ),
                        child: Text(
                          'Log In'.tr,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: themeChange.getTheme() ? Colors.black : Colors.white,
                          ),
                        ),
                        onPressed: () async {
                          if (controller.emailController.value.text.trim().isEmpty) {
                            ShowToastDialog.showToast("Please enter valid email".tr);
                          } else if (controller.passwordController.value.text.trim().isEmpty) {
                            ShowToastDialog.showToast("Please enter valid password".tr);
                          } else {
                            controller.loginWithEmailAndPassword(
                              context: context,
                              email: controller.emailController.value.text.toLowerCase().trim(),
                              password: controller.passwordController.value.text.trim(),
                            );
                          }
                        },
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        });
  }

  void showResetPwdAlertDialog(BuildContext context, controller) {
    Get.defaultDialog(
        title: 'Reset Password',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: double.infinity),
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0, right: 16.0, left: 16.0),
                child: TextField(
                    controller: controller.emailController.value,
                    keyboardType: TextInputType.text,
                    maxLines: 1,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.only(left: 16, right: 16),
                      hintText: 'Email'.tr,
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
                        borderSide: BorderSide(color: Colors.grey.shade500),
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                    )),
              ),
            ),
            const SizedBox(
              height: 30.0,
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.colorPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                  textStyle: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              onPressed: () async {
                if (controller.emailController.value.text.toString().isNotEmpty) {
                  showProgress(context, 'Sending Email...'.tr, false);
                  await auth.FirebaseAuth.instance.sendPasswordResetEmail(email: controller.emailController.value.text.toString());
                  hideProgress();
                  Get.back();

                  ShowToastDialog.showToast('Please check your email.'.tr);
                }
              },
              child: Text(
                'Send Link'.tr,
                style: const TextStyle(color: Colors.white, fontSize: 16.0),
              ),
            )
          ],
        ),
        radius: 10.0);
  }
}

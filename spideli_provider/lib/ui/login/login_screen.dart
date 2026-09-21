import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/login_controller.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/ui/auth/phone_number_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../widgets/text_field_widget.dart';
import '../signUp/signup_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX(
      init: LoginController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(backgroundColor: themeChange.getTheme() ? AppThemeData.surfaceDark : AppThemeData.surface),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome Back! 👋".tr,
                    style: TextStyle(color: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 22, fontFamily: AppThemeData.semiBold),
                  ),
                  Text(
                    "Log in to continue managing your bookings and earnings.".tr,
                    style: TextStyle(color: themeChange.getTheme() ? AppThemeData.grey400 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.regular),
                  ),
                  const SizedBox(height: 32),
                  TextFieldWidget(
                    title: 'Email'.tr,
                    controller: controller.emailController.value,
                    hintText: 'Enter email address'.tr,
                    prefix: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.asset("assets/icons/ic_mail.svg", colorFilter: ColorFilter.mode(themeChange.getTheme() ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
                    ),
                  ),
                  TextFieldWidget(
                    title: 'Password'.tr,
                    controller: controller.passwordController.value,
                    hintText: 'Enter Password'.tr,
                    obscureText: controller.passwordVisible.value,
                    prefix: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.asset("assets/icons/ic_lock.svg", colorFilter: ColorFilter.mode(themeChange.getTheme() ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn)),
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
                          decorationColor: AppColors.colorPrimary,
                          color: AppColors.colorPrimary,
                          fontSize: 14,
                          fontFamily: AppThemeData.regular,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  RoundedButtonFill(
                    title: "Login".tr,
                    color: AppColors.colorPrimary,
                    textColor: AppThemeData.grey50,
                    onPress: () async {
                      if (controller.emailController.value.text.trim().isEmpty) {
                        ShowToastDialog.showToast("Please enter valid email".tr);
                      } else if (controller.passwordController.value.text.trim().isEmpty) {
                        ShowToastDialog.showToast("Please enter valid password".tr);
                      } else {
                        controller.loginWithEmailAndPassword(
                            context: context, email: controller.emailController.value.text.toLowerCase().trim(), password: controller.passwordController.value.text.trim());
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      children: [
                        const Expanded(child: Divider(thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                          child: Text(
                            "or".tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: themeChange.getTheme() ? AppThemeData.grey500 : AppThemeData.grey400,
                              fontSize: 16,
                              fontFamily: AppThemeData.medium,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
                  RoundedButtonFill(
                    title: "Continue with Mobile Number".tr,
                    textColor: themeChange.getTheme() ? AppThemeData.grey100 : AppThemeData.grey900,
                    color: themeChange.getTheme() ? AppThemeData.grey900 : AppThemeData.grey100,
                    icon: SvgPicture.asset("assets/icons/ic_phone.svg", colorFilter: const ColorFilter.mode(AppThemeData.grey900, BlendMode.srcIn)),
                    isRight: false,
                    onPress: () async {
                      // Get.to(const PhoneNumberScreen());
                      Get.to(const PhoneNumberScreen(), arguments: {
                        "login": true,
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: RoundedButtonFill(
                          title: "with Google".tr,
                          textColor: themeChange.getTheme() ? AppThemeData.grey100 : AppThemeData.grey900,
                          color: themeChange.getTheme() ? AppThemeData.grey900 : AppThemeData.grey100,
                          icon: SvgPicture.asset("assets/icons/ic_google.svg"),
                          isRight: false,
                          onPress: () async {
                            controller.loginWithGoogle();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Platform.isIOS
                          ? Expanded(
                              child: RoundedButtonFill(
                                title: "with Apple".tr,
                                textColor: themeChange.getTheme() ? AppThemeData.grey100 : AppThemeData.grey900,
                                color: themeChange.getTheme() ? AppThemeData.grey900 : AppThemeData.grey100,
                                icon: SvgPicture.asset("assets/icons/ic_apple.svg"),
                                isRight: false,
                                onPress: () async {
                                  controller.loginWithApple(context);
                                },
                              ),
                            )
                          : const SizedBox(),
                    ],
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Padding(
            padding: EdgeInsets.symmetric(vertical: Platform.isAndroid ? 10 : 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Didn’t have an account?'.tr,
                        style: TextStyle(color: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
                      ),
                      const WidgetSpan(child: SizedBox(width: 10)),
                      TextSpan(
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Get.to(SignupScreen());
                          },
                        text: 'Sign up'.tr,
                        style: TextStyle(
                          color: AppColors.colorPrimary,
                          fontFamily: AppThemeData.bold,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.colorPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  showResetPwdAlertDialog(BuildContext context, controller) {
    Get.defaultDialog(
        title: 'Reset Password',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
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
            const SizedBox(
              height: 30.0,
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.colorPrimary, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20), textStyle: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              onPressed: () async {
                if (controller.emailController.value.text.toString().isNotEmpty) {
                  ShowToastDialog.showLoader('Sending Email...'.tr);
                  await auth.FirebaseAuth.instance.sendPasswordResetEmail(email: controller.emailController.value.text.toString());
                  ShowToastDialog.closeLoader();
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

// class LoginUIScreen extends StatelessWidget {
//   const LoginUIScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final themeChange = Provider.of<DarkThemeProvider>(context);
//     return GetX<LoginController>(
//         init: LoginController(),
//         builder: (controller) {
//           return Scaffold(
//             appBar: CommonUI.customAppBar(context, isBack: true, backgroundColor: themeChange.getTheme() ? AppColors.assetColorGrey1000 : AppColors.assetColorLightGrey400),
//             body: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Form(
//                 key: controller.key.value,
//                 autovalidateMode: controller.validate,
//                 child: ListView(
//                   children: <Widget>[
//                     Padding(
//                       padding: const EdgeInsets.only(top: 32.0, right: 16.0, left: 16.0),
//                       child: Text(
//                         'Log In'.tr,
//                         style: TextStyle(color: AppColors.colorPrimary, fontSize: 25.0, fontWeight: FontWeight.bold),
//                       ),
//                     ),
//
//                     SizedBox(
//                       height: 30,
//                     ),
//                     TextFormField(
//                         textAlignVertical: TextAlignVertical.center,
//                         textInputAction: TextInputAction.next,
//                         validator: validateEmail,
//                         controller: controller.emailController.value,
//                         style: const TextStyle(fontSize: 18.0),
//                         keyboardType: TextInputType.emailAddress,
//                         cursorColor: AppColors.colorPrimary,
//                         decoration: InputDecoration(
//                           contentPadding: const EdgeInsets.only(left: 16, right: 16),
//                           hintText: 'Email Address'.tr,
//                           focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
//                           errorBorder: OutlineInputBorder(
//                             borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
//                             borderRadius: BorderRadius.circular(25.0),
//                           ),
//                           focusedErrorBorder: OutlineInputBorder(
//                             borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
//                             borderRadius: BorderRadius.circular(25.0),
//                           ),
//                           enabledBorder: OutlineInputBorder(
//                             borderSide: BorderSide(color: Colors.grey.shade200),
//                             borderRadius: BorderRadius.circular(25.0),
//                           ),
//                         )),
//
//                     SizedBox(
//                       height: 10,
//                     ),
//                     TextFormField(
//                         textAlignVertical: TextAlignVertical.center,
//                         controller: controller.passwordController.value,
//                         obscureText: true,
//                         validator: validatePassword,
//                         onFieldSubmitted: (password) => controller.login(context),
//                         textInputAction: TextInputAction.done,
//                         style: const TextStyle(fontSize: 18.0),
//                         cursorColor: AppColors.colorPrimary,
//                         decoration: InputDecoration(
//                           contentPadding: const EdgeInsets.only(left: 16, right: 16),
//                           hintText: 'Password'.tr,
//                           focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
//                           errorBorder: OutlineInputBorder(
//                             borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
//                             borderRadius: BorderRadius.circular(25.0),
//                           ),
//                           focusedErrorBorder: OutlineInputBorder(
//                             borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
//                             borderRadius: BorderRadius.circular(25.0),
//                           ),
//                           enabledBorder: OutlineInputBorder(
//                             borderSide: BorderSide(color: Colors.grey.shade200),
//                             borderRadius: BorderRadius.circular(25.0),
//                           ),
//                         )),
//
//                     /// forgot password text, navigates user to ResetPasswordScreen
//                     /// and this is only visible when logging with email and password
//                     Padding(
//                       padding: const EdgeInsets.only(top: 16, right: 24),
//                       child: Align(
//                         alignment: Alignment.centerRight,
//                         child: GestureDetector(
//                           onTap: () {
//                             showResetPwdAlertDialog(context, controller);
//                           },
//                           child: Text(
//                             'Forgot password?'.tr,
//                             style: const TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1),
//                           ),
//                         ),
//                       ),
//                     ),
//                     SizedBox(
//                       height: 40,
//                     ),
//                     ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: AppColors.colorPrimary,
//                         padding: const EdgeInsets.only(top: 10, bottom: 10),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(25.0),
//                           side: BorderSide(
//                             color: AppColors.colorPrimary,
//                           ),
//                         ),
//                       ),
//                       child: Text(
//                         'Log In'.tr,
//                         style: TextStyle(
//                           fontSize: 20,
//                           fontWeight: FontWeight.bold,
//                           color: themeChange.getTheme() ? Colors.black : Colors.white,
//                         ),
//                       ),
//                       onPressed: () => controller.login(context),
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 45),
//                       child: Center(
//                         child: Row(
//                           children: [
//                             Expanded(child: Divider()),
//                             Padding(
//                               padding: const EdgeInsets.symmetric(horizontal: 16),
//                               child: Text(
//                                 'OR'.tr,
//                                 style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black),
//                               ),
//                             ),
//                             Expanded(child: Divider()),
//                           ],
//                         ),
//                       ),
//                     ),
//
//                     /// switch between login with phone number and email login states
//                     InkWell(
//                       onTap: () {
//                         Get.to(const PhoneNumberInputScreen(), arguments: {
//                           "login": true,
//                         });
//                       },
//                       child: Container(
//                         decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), color: Colors.white, border: Border.all(color: AppColors.colorPrimary, width: 1)),
//                         child: Padding(
//                           padding: const EdgeInsets.all(10.0),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Icon(Icons.call, color: AppColors.colorPrimary),
//                               const SizedBox(
//                                 width: 10,
//                               ),
//                               Text(
//                                 'Login with phone number'.tr,
//                                 style: TextStyle(color: AppColors.colorPrimary, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     )
//                   ],
//                 ),
//               ),
//             ),
//           );
//         });
//   }
//
//   showResetPwdAlertDialog(BuildContext context, controller) {
//     Get.defaultDialog(
//         title: 'Reset Password',
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//                 controller: controller.emailController.value,
//                 keyboardType: TextInputType.text,
//                 maxLines: 1,
//                 decoration: InputDecoration(
//                   contentPadding: const EdgeInsets.only(left: 16, right: 16),
//                   hintText: 'Email'.tr,
//                   focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
//                   errorBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
//                     borderRadius: BorderRadius.circular(25.0),
//                   ),
//                   focusedErrorBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
//                     borderRadius: BorderRadius.circular(25.0),
//                   ),
//                   enabledBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Colors.grey.shade500),
//                     borderRadius: BorderRadius.circular(25.0),
//                   ),
//                 )),
//             const SizedBox(
//               height: 30.0,
//             ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                   backgroundColor: AppColors.colorPrimary,
//                   padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
//                   textStyle: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
//               onPressed: () async {
//                 if (controller.emailController.value.text.toString().isNotEmpty) {
//                   ShowToastDialog.showLoader('Sending Email...'.tr);
//                   await auth.FirebaseAuth.instance.sendPasswordResetEmail(email: controller.emailController.value.text.toString());
//                   ShowToastDialog.closeLoader();
//                   Get.back();
//
//                   ShowToastDialog.showToast('Please check your email.'.tr);
//                 }
//               },
//               child: Text(
//                 'Send Link'.tr,
//                 style: const TextStyle(color: Colors.white, fontSize: 16.0),
//               ),
//             )
//           ],
//         ),
//         radius: 10.0);
//   }
// }

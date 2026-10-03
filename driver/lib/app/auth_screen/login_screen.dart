import 'package:driver/app/auth_screen/phone_number_screen.dart';
import 'package:driver/app/auth_screen/signup_screen.dart';
import 'package:driver/app/auth_screen/widgets/auth_shell.dart';
import 'package:driver/app/forgot_password_screen/forgot_password_screen.dart';
import 'package:driver/controllers/login_controller.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

/// Archetype H – auth: focused card on phones, brand panel + form on tablets.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
        init: LoginController(),
        builder: (controller) {
          final c = context.dsColors;
          final t = context.dsText;

          // Read eagerly inside the tracked builder so the eye toggle and the
          // field / form errors rebuild.
          final bool obscurePassword = controller.passwordVisible.value;
          final String? emailError = controller.emailError.value;
          final String? passwordError = controller.passwordError.value;
          final String? formError = controller.formError.value;
          // Not dart:io Platform, which throws on the web; same result on
          // Android, iOS and desktop.
          final bool isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

          return DsScaffold(
            appBar: const DsAppBar(),
            body: AuthShell(
              icon: Icons.login_rounded,
              title: "Log In to Your Account".tr,
              subtitle: "Sign in to access your spideli account and manage your deliveries seamlessly.".tr,
              highlights: [
                "Manage your deliveries seamlessly".tr,
                "Track your earnings in real time".tr,
              ],
              link: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "Didn’t Have an account?".tr,
                      style: t.bodyStrong,
                    ),
                    const WidgetSpan(child: SizedBox(width: 6)),
                    TextSpan(
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Get.to(const SignupScreen());
                        },
                      text: 'Sign up'.tr,
                      style: t.link,
                    ),
                  ],
                ),
              ),
              children: [
                DsFormSection(
                  children: [
                    DsTextField(
                      label: 'Email Address'.tr,
                      controller: controller.emailEditingController.value,
                      hint: 'Enter email address'.tr,
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      errorText: emailError?.tr,
                      onChanged: controller.onEmailChanged,
                    ),
                    // Visibility lives on the controller, so this field is a
                    // raw TextFormField with the DS input decoration.
                    DsFieldLabel('Password'.tr),
                    TextFormField(
                      controller: controller.passwordEditingController.value,
                      obscureText: obscurePassword,
                      style: t.bodyStrong,
                      cursorColor: c.brand,
                      textInputAction: TextInputAction.done,
                      onChanged: controller.onPasswordChanged,
                      // Enter / Done signs in, as the button does (desktop
                      // and web keyboards too).
                      onFieldSubmitted: (_) => controller.loginWithEmailAndPassword(),
                      decoration: DsInputDecoration.of(
                        context,
                        hint: 'Enter password'.tr,
                        error: passwordError?.tr,
                        prefixIcon: Icons.lock_outline_rounded,
                        suffix: DsIconButton(
                          icon: obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          semanticLabel: 'Password'.tr,
                          onPressed: () {
                            controller.passwordVisible.value = !controller.passwordVisible.value;
                          },
                        ),
                      ),
                    ),
                    // A failed sign-in ("Invalid email or password.", no
                    // connection, ...) stays visible after the toast.
                    if (formError != null) ...[
                      const DsGap(DsSpace.md),
                      DsInlineAlert(tone: DsTone.danger, message: formError.tr),
                    ],
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: DsButton.ghost(
                        label: "Forgot Password".tr,
                        size: DsButtonSize.sm,
                        onPressed: () {
                          Get.to(const ForgotPasswordScreen());
                        },
                      ),
                    ),
                  ],
                ),
                const DsGap(DsSpace.xl),
                DsDivider(label: 'OR'.tr),
                const DsGap(DsSpace.lg),
                DsButton.secondary(
                  label: "Continue with Mobile Number".tr,
                  icon: Icons.smartphone_rounded,
                  size: DsButtonSize.lg,
                  expand: true,
                  onPressed: () async {
                    Get.to(const PhoneNumberScreen());
                  },
                ),
                const DsGap(DsSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: DsButton.secondary(
                        label: isIOS ? "with Google".tr : 'Continue with Google'.tr,
                        size: DsButtonSize.lg,
                        expand: true,
                        leading: SvgPicture.asset("assets/icons/ic_google.svg", height: 20, width: 20),
                        onPressed: () async {
                          controller.loginWithGoogle();
                        },
                      ),
                    ),
                    if (isIOS) const SizedBox(width: 10),
                    isIOS
                        ? Expanded(
                            child: DsButton.secondary(
                              label: isIOS ? "with Apple".tr : 'Continue with Apple'.tr,
                              size: DsButtonSize.lg,
                              expand: true,
                              leading: SvgPicture.asset("assets/icons/ic_apple.svg", height: 20, width: 20),
                              onPressed: () async {
                                controller.loginWithApple();
                              },
                            ),
                          )
                        : const SizedBox(),
                  ],
                ),
              ],
            ),
            bottomBar: DsStickyBar(
              child: DsButton.primary(
                label: "Log in".tr,
                icon: Icons.arrow_forward_rounded,
                size: DsButtonSize.lg,
                expand: true,
                // The controller checks the fields (empty, both empty, email
                // format) before sending anything.
                onPressed: controller.loginWithEmailAndPassword,
              ),
            ),
          );
        });
  }
}

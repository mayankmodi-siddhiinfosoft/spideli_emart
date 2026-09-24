import 'dart:io';

import 'package:customer/screen_ui/auth_screens/sign_up_screen.dart';
import 'package:customer/screen_ui/auth_screens/widgets/auth_shell.dart';
import 'package:customer/screen_ui/location_enable_screens/location_permission_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../controllers/login_controller.dart';
import 'package:get/get.dart';
import 'forgot_password_screen.dart';
import 'mobile_login_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<LoginController>(
      init: LoginController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final passwordHidden = controller.passwordVisible.value;
        return AuthScaffold(
          eyebrow: "Welcome back",
          title: "Log in to explore your all in one vendor app favourites and shop effortlessly.".tr,
          icon: Icons.lock_open_rounded,
          actions: [AuthSkipButton(onPressed: () => Get.to(() => LocationPermissionScreen()))],
          footer: AuthFooterLink(
            text: "Didn't have an account? ".tr,
            linkText: "Sign up".tr,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Get.offAll(() => const SignUpScreen());
              },
          ),
          children: [
            DsCard(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DsTextField(
                    label: "Email Address*".tr,
                    hint: "jerome014@gmail.com",
                    controller: controller.emailController.value,
                    focusNode: controller.emailFocusNode,
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                  ),
                  AuthPasswordField(
                    label: "Password*".tr,
                    hint: "Enter password".tr,
                    controller: controller.passwordController.value,
                    focusNode: controller.passwordFocusNode,
                    obscured: passwordHidden,
                    onToggle: () {
                      controller.passwordVisible.value = !controller.passwordVisible.value;
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Get.to(() => const ForgotPasswordScreen()),
                      style: TextButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: c.brandStrong),
                      child: Text("Forgot Password".tr, style: t.label.withColor(c.brandStrong)),
                    ),
                  ),
                ],
              ),
            ),
            const DsGap(DsSpace.xl),
            DsButton.primary(label: "Log in".tr, size: DsButtonSize.lg, expand: true, onPressed: controller.loginWithEmail),
            const DsGap(DsSpace.sm),
            DsDivider(label: "or continue with".tr, spacing: DsSpace.xl),
            AuthAltButton(
              label: "Mobile number".tr,
              icon: Icon(Icons.smartphone_rounded, size: 20, color: c.textPrimary),
              onPressed: () => Get.to(() => const MobileLoginScreen()),
            ),
            const DsGap(DsSpace.md),
            Row(
              children: [
                Expanded(
                  child: AuthAltButton(
                    label: "Continue with Google".tr,
                    icon: SvgPicture.asset("assets/icons/ic_google.svg", width: 20, height: 20),
                    onPressed: () async {
                      controller.loginWithGoogle();
                    },
                  ),
                ),
                Platform.isIOS ? const DsGap(DsSpace.md) : const SizedBox(),
                Platform.isIOS
                    ? Expanded(
                      child: AuthAltButton(
                        label: "Continue with Apple".tr,
                        icon: SvgPicture.asset("assets/icons/ic_apple.svg", width: 20, height: 20),
                        onPressed: () async {
                          controller.loginWithApple();
                        },
                      ),
                    )
                    : const SizedBox(),
              ],
            ),
          ],
        );
      },
    );
  }
}

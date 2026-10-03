import 'package:spideliprovider/controller/login_controller.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/auth/auth_layout.dart';
import 'package:spideliprovider/ui/auth/phone_number_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../signUp/signup_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes this screen to theme changes (colors come from the DS).
    Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    final t = context.dsText;
    return GetX(
      init: LoginController(),
      builder: (controller) {
        // Every observable is read here, inside the tracked builder, and the
        // values are handed to the (eagerly built) sub-trees below.
        final bool passwordVisible = controller.passwordVisible.value;
        final String? emailError = controller.emailError.value;
        final String? passwordError = controller.passwordError.value;
        final String? formError = controller.formError.value;
        final Widget form = AuthShell(
          children: [
            Text("Welcome Back! 👋".tr, style: t.display),
            const DsGap(DsSpace.xs),
            Text("Log in to continue managing your bookings and earnings.".tr, style: t.bodyLg.withColor(c.textSecondary)),
            const DsGap(DsSpace.xxl),
            DsTextField(
              label: 'Email'.tr,
              controller: controller.emailController.value,
              hint: 'Enter email address'.tr,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              bottomSpacing: DsSpace.lg,
              // Shown under the field; cleared as soon as the user types.
              errorText: emailError?.tr,
              onChanged: controller.onEmailChanged,
              prefix: Padding(
                padding: const EdgeInsets.all(12),
                child: SvgPicture.asset("assets/icons/ic_mail.svg", colorFilter: ColorFilter.mode(c.textMuted, BlendMode.srcIn)),
              ),
            ),
            AuthPasswordField(
              label: 'Password'.tr,
              hint: 'Enter Password'.tr,
              controller: controller.passwordController.value,
              obscure: passwordVisible,
              errorText: passwordError?.tr,
              onChanged: controller.onPasswordChanged,
              prefix: Padding(
                padding: const EdgeInsets.all(12),
                child: SvgPicture.asset("assets/icons/ic_lock.svg", colorFilter: ColorFilter.mode(c.textMuted, BlendMode.srcIn)),
              ),
              onToggle: () {
                controller.passwordVisible.value = !controller.passwordVisible.value;
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: DsButton.ghost(
                label: "Forgot Password".tr,
                size: DsButtonSize.sm,
                onPressed: () {
                  showResetPwdAlertDialog(context, controller);
                },
              ),
            ),
            const DsGap(DsSpace.xl),
            // A failed sign-in ("Invalid email or password.", no connection,
            // ...) stays here until a field is edited. Always one child, so
            // the staggered entrance of the rows below is not replayed.
            formError == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: DsSpace.lg),
                    child: DsInlineAlert(tone: DsTone.danger, message: formError.tr),
                  ),
            DsButton.primary(
              label: "Login".tr,
              expand: true,
              size: DsButtonSize.lg,
              // The controller checks the fields (empty, both empty, email
              // format) before sending anything.
              onPressed: () async {
                controller.loginWithEmailAndPassword(context: context, email: controller.emailController.value.text.toLowerCase().trim(), password: controller.passwordController.value.text.trim());
              },
            ),
            const DsGap(DsSpace.sm),
            DsDivider(label: "or".tr, spacing: DsSpace.xl),
            const DsGap(DsSpace.sm),
            DsButton.secondary(
              label: "Continue with Mobile Number".tr,
              expand: true,
              leading: SvgPicture.asset("assets/icons/ic_phone.svg", colorFilter: ColorFilter.mode(c.textPrimary, BlendMode.srcIn), width: 18, height: 18),
              onPressed: () async {
                // Get.to(const PhoneNumberScreen());
                Get.to(const PhoneNumberScreen(), arguments: {"login": true});
              },
            ),
            const DsGap(DsSpace.md),
            Row(
              children: [
                Expanded(
                  child: DsButton.secondary(
                    label: "with Google".tr,
                    expand: true,
                    leading: SvgPicture.asset("assets/icons/ic_google.svg", width: 18, height: 18),
                    onPressed: () async {
                      controller.loginWithGoogle();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // Not dart:io's Platform, which throws on the web.
                !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
                    ? Expanded(
                        child: DsButton.secondary(
                          label: "with Apple".tr,
                          expand: true,
                          leading: SvgPicture.asset("assets/icons/ic_apple.svg", width: 18, height: 18),
                          onPressed: () async {
                            controller.loginWithApple(context);
                          },
                        ),
                      )
                    : const SizedBox(),
              ],
            ),
          ],
        );

        return DsScaffold(
          backgroundColor: c.background,
          appBar: DsAppBar(backgroundColor: c.background),
          maxContentWidth: null,
          body: form,
          bottomBar: DsStickyBar(
            child: Text.rich(
              textAlign: TextAlign.center,
              TextSpan(
                children: [
                  TextSpan(text: 'Didn’t have an account?'.tr, style: t.bodyStrong),
                  const WidgetSpan(child: SizedBox(width: 10)),
                  TextSpan(
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Get.to(SignupScreen());
                      },
                    text: 'Sign up'.tr,
                    style: t.label.withColor(c.brandStrong).copyWith(decoration: TextDecoration.underline, decorationColor: c.brandStrong),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void showResetPwdAlertDialog(BuildContext context, LoginController controller) {
    final c = context.dsColors;
    controller.resetEmailError.value = null;
    Get.defaultDialog(
      title: 'Reset Password'.tr,
      titleStyle: DsTypography.title.copyWith(color: c.textPrimary),
      backgroundColor: c.surfaceRaised,
      radius: DsRadius.lg,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'We will email you a link to set a new password.'.tr,
            textAlign: TextAlign.center,
            style: DsTypography.body.copyWith(color: c.textSecondary),
          ),
          const DsGap(DsSpace.xl),
          // The same checks as the login form (empty, format) before any
          // request; the message is shown under the field.
          Obx(() {
            final String? error = controller.resetEmailError.value;
            return TextField(
              controller: controller.emailController.value,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              maxLines: 1,
              onChanged: controller.onEmailChanged,
              style: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
              cursorColor: c.brand,
              decoration: DsInputDecoration.of(context, hint: 'Email'.tr, prefixIcon: Icons.mail_outline_rounded, error: error?.tr),
            );
          }),
          const SizedBox(height: 30.0),
          DsButton.primary(
            label: 'Send Link'.tr,
            expand: true,
            onPressed: controller.sendPasswordResetEmail,
          ),
        ],
      ),
    );
  }
}

import 'package:customer/screen_ui/auth_screens/widgets/auth_shell.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/forgot_password_controller.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<ForgotPasswordController>(
      init: ForgotPasswordController(),
      builder: (controller) {
        return AuthScaffold(
          eyebrow: "Password reset",
          title: "Enter your registered email to receive a reset link.".tr,
          icon: Icons.mark_email_read_outlined,
          showBack: true,
          actions: [AuthSkipButton(onPressed: () {})],
          footer: AuthFooterLink(
            text: "Remember Password?".tr,
            linkText: "Log in".tr,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Get.offAll(() => const LoginScreen());
              },
          ),
          children: [
            DsCard(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xs),
              child: DsTextField(
                label: "Email Address*".tr,
                hint: "jerome014@gmail.com",
                controller: controller.emailEditingController.value,
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
              ),
            ),
            const DsGap(DsSpace.lg),
            DsInlineAlert(tone: DsTone.info, icon: Icons.info_outline_rounded, message: "We will email you a secure link to set a new password.".tr),
            const DsGap(DsSpace.xl),
            DsButton.primary(label: "Send Link".tr, size: DsButtonSize.lg, expand: true, icon: Icons.send_rounded, onPressed: controller.forgotPassword),
          ],
        );
      },
    );
  }
}

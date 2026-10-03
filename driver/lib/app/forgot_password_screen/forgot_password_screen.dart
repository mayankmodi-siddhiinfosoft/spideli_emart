import 'package:driver/app/auth_screen/widgets/auth_shell.dart';
import 'package:driver/controllers/forgot_password_controller.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Archetype H – auth recovery: one field, one reassuring line, one action.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
        init: ForgotPasswordController(),
        builder: (controller) {
          // Read inside the tracked builder so the field error rebuilds.
          final String? emailError = controller.emailError.value;
          return DsScaffold(
            appBar: const DsAppBar(),
            body: AuthShell(
              icon: Icons.lock_reset_rounded,
              title: "Forgot Password".tr,
              subtitle: "No worries!! We’ll send you reset instructions".tr,
              highlights: [
                "A secure reset link lands in your inbox".tr,
              ],
              children: [
                DsFormSection(
                  children: [
                    DsTextField(
                      label: 'Email Address'.tr,
                      controller: controller.emailEditingController.value,
                      hint: 'Enter email address'.tr,
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      errorText: emailError?.tr,
                      onChanged: controller.onEmailChanged,
                      onSubmitted: (_) => controller.forgotPassword(),
                      bottomSpacing: 0,
                    ),
                  ],
                ),
                const DsGap(DsSpace.lg),
                DsInlineAlert(
                  tone: DsTone.info,
                  icon: Icons.info_outline_rounded,
                  message: "Open the link in your inbox and follow the steps to create a new password.".tr,
                ),
              ],
            ),
            bottomBar: DsStickyBar(
              child: DsButton.primary(
                label: "Forgot Password".tr,
                icon: Icons.send_rounded,
                size: DsButtonSize.lg,
                expand: true,
                // The controller checks the address (empty, format) before
                // sending anything.
                onPressed: controller.forgotPassword,
              ),
            ),
          );
        });
  }
}

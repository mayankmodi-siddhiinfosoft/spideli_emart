import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/app/auth_screen/widgets/auth_layout.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/forgot_password_controller.dart';
import 'package:vendor/themes/ds/ds.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: ForgotPasswordController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final steps = <(IconData, String)>[
          (Icons.alternate_email_rounded, 'Enter your account email'.tr),
          (Icons.mark_email_read_outlined, 'Open the reset link we send you'.tr),
          (Icons.password_rounded, 'Choose a new password'.tr),
        ];
        return AuthLayout(
          heroIcon: Icons.lock_reset_rounded,
          title: "Forgot Password".tr,
          subtitle: "No worries!! We’ll send you reset instructions".tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthField(
                label: 'Email Address'.tr,
                controller: controller.emailEditingController.value,
                hint: 'Enter email address'.tr,
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
              ),
              const DsGap(DsSpace.sm),
              DsButton.primary(
                label: "Forgot Password".tr,
                size: DsButtonSize.lg,
                expand: true,
                icon: Icons.send_rounded,
                onPressed: () async {
                  if (controller.emailEditingController.value.text.trim().isEmpty) {
                    ShowToastDialog.showToast("Please enter valid email".tr);
                  } else {
                    controller.forgotPassword();
                  }
                },
              ),
              const DsGap(DsSpace.xxxl),
              // Small "how it works" strip – purely informational.
              for (var i = 0; i < steps.length; i++)
                DsFadeSlideIn(
                  index: i + 2,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: DsSpace.md),
                    child: Row(
                      children: [
                        DsIconWell(icon: steps[i].$1, size: 36, circle: true, tone: DsTone.neutral),
                        const DsGap(DsSpace.md),
                        Expanded(child: Text(steps[i].$2, style: t.bodySm.withColor(c.textSecondary))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:driver/controllers/change_password_controller.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Archetype K/H – security form: a single focused card (lock hero, what will
/// happen, one field) with the action pinned to the bottom of the screen.
class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
        init: ChangePasswordController(),
        builder: (controller) {
          final c = context.dsColors;
          final t = context.dsText;
          return Scaffold(
            backgroundColor: c.background,
            body: DsAsync(
              isLoading: controller.isLoading.value,
              skeleton: const Padding(
                padding: EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xl),
                child: DsSkeletonForm(fields: 2),
              ),
              builder: (_) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.xl, DsSpace.lg, DsSpace.xxxl),
                child: DsResponsive(
                  maxWidth: 520,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: DsFadeSlideIn.stagger([
                      Row(
                        children: [
                          const DsIconWell(icon: Icons.lock_outline_rounded, tone: DsTone.brand, size: 52),
                          const DsGap(DsSpace.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Change Password".tr, style: t.headline),
                                const DsGap(DsSpace.xxs),
                                Text(
                                  "Update your password to keep your account secure.".tr,
                                  style: t.bodySecondary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const DsGap(DsSpace.xl),
                      DsInlineAlert(
                        tone: DsTone.info,
                        icon: Icons.mark_email_read_outlined,
                        message:
                            "Enter your registered email address and we’ll send you a secure link to reset your password. Open the link in your inbox and follow the steps to create a new password."
                                .tr,
                      ),
                      const DsGap(DsSpace.xl),
                      DsFormSection(
                        title: 'Email Address'.tr,
                        icon: Icons.alternate_email_rounded,
                        children: [
                          DsTextField(
                            hint: 'Enter Email Address'.tr,
                            keyboardType: TextInputType.emailAddress,
                            controller: controller.emailEditingController.value,
                            prefixIcon: Icons.mail_outline_rounded,
                            bottomSpacing: 0,
                          ),
                        ],
                      ),
                    ], offset: const Offset(0, 18)),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: DsStickyBar(
              child: DsButton.primary(
                label: "Change Password".tr,
                icon: Icons.send_rounded,
                size: DsButtonSize.lg,
                expand: true,
                onPressed: () async {
                  controller.forgotPassword();
                },
              ),
            ),
          );
        });
  }
}

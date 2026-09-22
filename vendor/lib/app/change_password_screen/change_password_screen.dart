import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/controller/change_password_controller.dart';
import 'package:vendor/themes/ds/ds.dart';

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: ChangePasswordController(),
      builder: (controller) {
        final t = context.dsText;
        final l = context.dsLayout;
        return DsScaffold(
          title: "Change Password".tr,
          maxContentWidth: DsLayout.contentMax,
          bottomBar: controller.isLoading.value
              ? null
              : DsStickyBar(
                  child: DsButton.primary(
                    label: "Change Password".tr,
                    size: DsButtonSize.lg,
                    expand: true,
                    icon: Icons.lock_reset_rounded,
                    onPressed: () async {
                      controller.forgotPassword();
                    },
                  ),
                ),
          body: controller.isLoading.value
              ? const DsSkeletonForm(fields: 1)
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, DsSpace.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: DsFadeSlideIn.stagger([
                      // Security hero
                      DsCard.gradient(
                        gradient: DsGradients.deep(context),
                        child: Row(
                          children: [
                            const DsIconWell(icon: Icons.shield_outlined, onBrand: true, size: 56),
                            const DsGap(DsSpace.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Account security'.tr, style: t.overline.withColor(Colors.white.withValues(alpha: 0.75))),
                                  const DsGap(DsSpace.xs),
                                  Text("Update your password to keep your account secure.".tr, style: t.titleSm.withColor(Colors.white)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const DsGap(DsSpace.lg),
                      DsInlineAlert(
                        tone: DsTone.warning,
                        icon: Icons.mark_email_unread_outlined,
                        message: "Enter your registered email address and we’ll send you a secure link to reset your password. Open the link in your inbox and follow the steps to create a new password."
                            .tr,
                      ),
                      const DsGap(DsSpace.lg),
                      DsFormSection(
                        title: 'Email Address'.tr,
                        icon: Icons.alternate_email_rounded,
                        children: [
                          DsTextField(
                            label: 'Email Address'.tr,
                            keyboardType: TextInputType.emailAddress,
                            controller: controller.emailEditingController.value,
                            hint: 'Enter Email Address'.tr,
                            prefixIcon: Icons.mail_outline_rounded,
                          ),
                        ],
                      ),
                    ]),
                  ),
                ),
        );
      },
    );
  }
}

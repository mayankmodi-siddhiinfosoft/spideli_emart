import 'package:customer/controllers/change_password_controller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

/// Archetype **H — settings detail**: a single-purpose security form with a
/// tinted explanation panel and the action pinned to a sticky bar.
class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: ChangePasswordController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final loading = controller.isLoading.value;
        return DsScaffold(
          title: "Change Password".tr,
          maxContentWidth: DsLayout.contentMax,
          bottomBar: loading
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
          body: DsAsync(
            isLoading: loading,
            skeleton: const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 2)),
            builder: (_) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, DsSpace.xxxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: DsFadeSlideIn.stagger([
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DsIconWell(icon: Icons.shield_outlined, tone: DsTone.brand, size: 52),
                      const DsGap(DsSpace.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Change Password".tr, style: t.headline),
                            const DsGap(DsSpace.xs),
                            Text("Update your password to keep your account secure.".tr, style: t.bodySecondary),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const DsGap(DsSpace.xl),
                  DsInlineAlert(
                    tone: DsTone.warning,
                    icon: Icons.mark_email_unread_outlined,
                    message:
                        "Enter your registered email address and we’ll send you a secure link to reset your password. Open the link in your inbox and follow the steps to create a new password."
                            .tr,
                  ),
                  const DsGap(DsSpace.xl),
                  DsCard(
                    padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xs),
                    child: DsTextField(
                      label: 'Email Address'.tr,
                      keyboardType: TextInputType.emailAddress,
                      controller: controller.emailEditingController.value,
                      hint: 'Enter Email Address'.tr,
                      autofillHints: const [AutofillHints.email],
                      prefix: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SvgPicture.asset("assets/icons/ic_mail.svg", colorFilter: ColorFilter.mode(c.textMuted, BlendMode.srcIn)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

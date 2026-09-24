import 'package:customer/controllers/forgot_password_controller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../themes/show_toast_dialog.dart';

/// Archetype **I — auth**: a compact recovery screen built around a gradient
/// "mail" hero so it reads differently from the settings forms.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: ForgotPasswordController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        return DsScaffold(
          maxContentWidth: DsLayout.contentMax,
          appBar: const DsAppBar(),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
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
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, DsSpace.xxxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: DsFadeSlideIn.stagger([
                DsCard.gradient(
                  padding: const EdgeInsets.all(DsSpace.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(DsSpace.md),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: DsRadius.brLg),
                        child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 28),
                      ),
                      const DsGap(DsSpace.xl),
                      Text("Forgot Password".tr, style: DsTypography.headline.copyWith(color: Colors.white)),
                      const DsGap(DsSpace.xs),
                      Text(
                        "No worries!! We’ll send you reset instructions".tr,
                        style: DsTypography.body.copyWith(color: Colors.white.withValues(alpha: 0.88)),
                      ),
                    ],
                  ),
                ),
                const DsGap(DsSpace.xxl),
                DsCard(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xs),
                  child: DsTextField(
                    label: 'Email Address'.tr,
                    controller: controller.emailEditingController.value,
                    hint: 'Enter email address'.tr,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    prefix: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.asset("assets/icons/ic_mail.svg", colorFilter: ColorFilter.mode(c.textMuted, BlendMode.srcIn)),
                    ),
                  ),
                ),
                const DsGap(DsSpace.md),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 16, color: c.textMuted),
                    const DsGap(DsSpace.sm),
                    Expanded(child: Text("The reset link stays valid for a short time.".tr, style: t.caption)),
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

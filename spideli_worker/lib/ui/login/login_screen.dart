import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/controller/login_controller.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Log in (archetype F). Phones get a brand mark, a large display title and a
/// focused form; tablets and iPad split the screen into a brand-gradient
/// panel and a 440-wide form card. Every validation and the controller call
/// are unchanged.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes the page to theme changes.
    Provider.of<DarkThemeProvider>(context);
    return GetX<LoginController>(
        init: LoginController(),
        builder: (controller) {
          // Read synchronously so this GetX tracks the reveal toggle.
          final bool passwordVisible = controller.passwordVisible.value;
          final c = context.dsColors;
          final l = context.dsLayout;

          final Widget form = _LoginForm(
            controller: controller,
            passwordVisible: passwordVisible,
            onForgot: () => showResetPwdAlertDialog(context, controller),
            onSubmit: () async {
              if (controller.emailController.value.text.trim().isEmpty) {
                ShowToastDialog.showToast("Please enter valid email".tr);
              } else if (controller.passwordController.value.text.trim().isEmpty) {
                ShowToastDialog.showToast("Please enter valid password".tr);
              } else {
                controller.loginWithEmailAndPassword(
                  context: context,
                  email: controller.emailController.value.text.toLowerCase().trim(),
                  password: controller.passwordController.value.text.trim(),
                );
              }
            },
          );

          if (l.isWide) {
            return Scaffold(
              backgroundColor: c.background,
              body: Row(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: DsGradients.brand(context)),
                      child: SafeArea(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(DsSpace.huge),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: DsFadeSlideIn.stagger([
                                Image.asset("assets/images/app_logo.png", width: 220),
                                const DsGap(DsSpace.xxl),
                                Text(
                                  'Log In'.tr,
                                  textAlign: TextAlign.center,
                                  style: DsTypography.displayLg.copyWith(color: Colors.white),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SafeArea(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(DsSpace.xxxl),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: DsCard(padding: const EdgeInsets.all(DsSpace.xxl), child: form),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            backgroundColor: c.background,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.xxxl, l.gutter, DsSpace.xxxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: DsFadeSlideIn.stagger([
                    Center(child: Image.asset("assets/images/app_logo.png", width: 180)),
                    const DsGap(DsSpace.xxxl),
                    form,
                  ]),
                ),
              ),
            ),
          );
        });
  }

  void showResetPwdAlertDialog(BuildContext context, controller) {
    Get.defaultDialog(
        title: 'Reset Password',
        titleStyle: DsTypography.title.copyWith(color: DsColors.of(context).textPrimary),
        backgroundColor: DsColors.of(context).surfaceRaised,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: double.infinity),
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0, right: 16.0, left: 16.0),
                child: TextField(
                  controller: controller.emailController.value,
                  keyboardType: TextInputType.text,
                  maxLines: 1,
                  style: DsTypography.bodyStrong.copyWith(color: DsColors.of(context).textPrimary),
                  decoration: DsInputDecoration.of(context, hint: 'Email'.tr, prefixIcon: Icons.mail_outline_rounded),
                ),
              ),
            ),
            const DsGap(DsSpace.xxl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DsButton.primary(
                label: 'Send Link'.tr,
                icon: Icons.send_rounded,
                expand: true,
                onPressed: () async {
                  if (controller.emailController.value.text.toString().isNotEmpty) {
                    showProgress(context, 'Sending Email...'.tr, false);
                    await auth.FirebaseAuth.instance.sendPasswordResetEmail(email: controller.emailController.value.text.toString());
                    hideProgress();
                    Get.back();

                    ShowToastDialog.showToast('Please check your email.'.tr);
                  }
                },
              ),
            )
          ],
        ),
        radius: DsRadius.xl);
  }
}

class _LoginForm extends StatelessWidget {
  final LoginController controller;
  final bool passwordVisible;
  final VoidCallback onForgot;
  final VoidCallback onSubmit;

  const _LoginForm({
    required this.controller,
    required this.passwordVisible,
    required this.onForgot,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    ColorFilter tint() => ColorFilter.mode(c.textMuted, BlendMode.srcIn);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Log In'.tr, style: t.displayLg.withColor(c.brandStrong)),
        ),
        const DsGap(DsSpace.sm),
        Text('Sign in to see the jobs assigned to you.'.tr, style: t.bodySecondary),
        const DsGap(DsSpace.xxl),
        DsTextField(
          label: 'Email'.tr,
          hint: 'Enter email address'.tr,
          controller: controller.emailController.value,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          prefix: Padding(
            padding: const EdgeInsets.all(12),
            child: SvgPicture.asset("assets/icons/ic_mail.svg", colorFilter: tint()),
          ),
        ),
        DsTextField(
          label: 'Password'.tr,
          hint: 'Enter Password'.tr,
          controller: controller.passwordController.value,
          obscureText: passwordVisible,
          autofillHints: const [AutofillHints.password],
          prefix: Padding(
            padding: const EdgeInsets.all(12),
            child: SvgPicture.asset("assets/icons/ic_lock.svg", colorFilter: tint()),
          ),
          suffix: Padding(
            padding: const EdgeInsets.all(12),
            child: Semantics(
              button: true,
              label: 'Password'.tr,
              child: InkWell(
                onTap: () {
                  controller.passwordVisible.value = !controller.passwordVisible.value;
                },
                child: passwordVisible
                    ? SvgPicture.asset("assets/icons/ic_password_show.svg", colorFilter: tint())
                    : SvgPicture.asset("assets/icons/ic_password_close.svg", colorFilter: tint()),
              ),
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: DsButton.ghost(
            label: "Forgot Password".tr,
            size: DsButtonSize.sm,
            onPressed: onForgot,
          ),
        ),
        const DsGap(DsSpace.xxl),
        DsButton.primary(
          label: 'Log In'.tr,
          icon: Icons.login_rounded,
          size: DsButtonSize.lg,
          expand: true,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

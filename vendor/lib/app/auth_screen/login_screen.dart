import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/app/auth_screen/widgets/auth_layout.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/app/auth_screen/phone_number_screen.dart';
import 'package:vendor/app/auth_screen/signup_screen.dart';
import 'package:vendor/app/forgot_password_screen/forgot_password_screen.dart';
import 'package:vendor/controller/login_controller.dart';
import 'package:vendor/themes/ds/ds.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder(
      init: LoginController(),
      builder: (controller) {
        return AuthLayout(
          title: "Welcome Back! 👋".tr,
          subtitle: "Log in to continue managing your Store’s orders and reservations seamlessly.".tr,
          footer: AuthFooterPrompt(
            question: 'Didn’t have an account?'.tr,
            action: 'Sign up'.tr,
            onTap: () {
              Get.to(const SignupScreen());
            },
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (Constant.isEmployeeManagement == true)
                Obx(
                  () => DsSegmentedTabs(
                    segments: [
                      DsSegment("Owner Login".tr, icon: Icons.storefront_outlined),
                      DsSegment("Employee Login".tr, icon: Icons.badge_outlined),
                    ],
                    index: controller.selectedTabbar.value,
                    onChanged: (value) {
                      controller.selectedTabbar.value = value;
                    },
                  ),
                )
              else
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DsBadge(label: "Owner Login".tr, icon: Icons.storefront_outlined, tone: DsTone.brand),
                ),
              const DsGap(DsSpace.xxl),
              Obx(() {
                // Read the observable unconditionally so the Obx always has a
                // dependency (short-circuiting on the flag left it with none).
                final selectedTab = controller.selectedTabbar.value;
                final showEmployee = Constant.isEmployeeManagement == true && selectedTab == 1;
                return AnimatedSwitcher(
                  duration: DsMotion.of(context, DsMotion.base),
                  switchInCurve: DsMotion.emphasized,
                  switchOutCurve: DsMotion.accelerate,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                  child: showEmployee
                      ? EmployeeLoginForm(key: const ValueKey('employee'), controller: controller)
                      : OwnerLoginForm(key: const ValueKey('owner'), controller: controller),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

/// Apple sign-in and the shorter Google label are for the iOS app only.
/// `defaultTargetPlatform` (not `dart:io` Platform) keeps this screen working
/// on the web and desktop too.
bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Why the last sign-in failed ("Invalid email or password." ...), above the
/// Login button until a field is edited. [message] is a translation key.
class LoginFailureAlert extends StatelessWidget {
  final String? message;
  const LoginFailureAlert({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.lg),
      child: DsInlineAlert(tone: DsTone.danger, message: text.tr),
    );
  }
}

class OwnerLoginForm extends StatelessWidget {
  final LoginController controller;
  const OwnerLoginForm({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(
            label: 'Email'.tr,
            controller: controller.emailEditingControllerOwner.value,
            hint: 'Enter email address'.tr,
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            errorText: controller.ownerErrors.email.value?.tr,
            onChanged: (_) => controller.ownerErrors.emailEdited(),
          ),
          AuthField(
            label: 'Password'.tr,
            controller: controller.passwordEditingControllerOwner.value,
            hint: 'Enter Password'.tr,
            obscureText: controller.passwordVisible.value,
            prefixIcon: Icons.lock_outline_rounded,
            autofillHints: const [AutofillHints.password],
            suffix: AuthVisibilityToggle(obscured: controller.passwordVisible.value, onTap: () => controller.passwordVisible.value = !controller.passwordVisible.value),
            errorText: controller.ownerErrors.password.value?.tr,
            onChanged: (_) => controller.ownerErrors.passwordEdited(),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: DsButton.ghost(label: "Forgot Password".tr, size: DsButtonSize.sm, onPressed: () => Get.to(const ForgotPasswordScreen())),
          ),
          const DsGap(DsSpace.lg),
          LoginFailureAlert(message: controller.ownerErrors.form.value),
          DsButton.primary(
            label: "Login".tr,
            size: DsButtonSize.lg,
            expand: true,
            trailingIcon: Icons.arrow_forward_rounded,
            // The controller checks the fields (empty, both empty, email
            // format) before sending anything.
            onPressed: controller.onwerloginWithEmailAndPassword,
          ),
          DsDivider(label: "or".tr, spacing: DsSpace.xxl),
          DsButton.secondary(label: "Continue with Mobile Number".tr, expand: true, icon: Icons.phone_iphone_rounded, onPressed: () => Get.to(const PhoneNumberScreen())),
          const DsGap(DsSpace.md),
          Row(
            children: [
              Expanded(
                child: DsButton.secondary(
                  label: _isIOS ? "with Google".tr : 'Continue with Google'.tr,
                  expand: true,
                  leading: SvgPicture.asset("assets/icons/ic_google.svg", width: 20, height: 20),
                  onPressed: () => controller.loginWithGoogle(),
                ),
              ),
              if (_isIOS) const DsGap(DsSpace.md),
              if (_isIOS)
                Expanded(
                  child: DsButton.secondary(
                    label: "with Apple".tr,
                    expand: true,
                    leading: SvgPicture.asset("assets/icons/ic_apple.svg", width: 20, height: 20, colorFilter: ColorFilter.mode(c.textPrimary, BlendMode.srcIn)),
                    onPressed: () => controller.loginWithApple(),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class EmployeeLoginForm extends StatelessWidget {
  final LoginController controller;
  const EmployeeLoginForm({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsInlineAlert(tone: DsTone.info, icon: Icons.badge_outlined, message: 'Use the email and password shared by your store owner.'.tr),
          const DsGap(DsSpace.xl),
          AuthField(
            label: 'Email'.tr,
            controller: controller.emailEditingControllerEmployee.value,
            hint: 'Enter email address'.tr,
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            errorText: controller.employeeErrors.email.value?.tr,
            onChanged: (_) => controller.employeeErrors.emailEdited(),
          ),
          AuthField(
            label: 'Password'.tr,
            controller: controller.passwordEditingControllerEmployee.value,
            hint: 'Enter Password'.tr,
            obscureText: controller.passwordVisible.value,
            prefixIcon: Icons.lock_outline_rounded,
            autofillHints: const [AutofillHints.password],
            suffix: AuthVisibilityToggle(obscured: controller.passwordVisible.value, onTap: () => controller.passwordVisible.value = !controller.passwordVisible.value),
            errorText: controller.employeeErrors.password.value?.tr,
            onChanged: (_) => controller.employeeErrors.passwordEdited(),
          ),
          const DsGap(DsSpace.lg),
          LoginFailureAlert(message: controller.employeeErrors.form.value),
          DsButton.primary(
            label: "Login".tr,
            size: DsButtonSize.lg,
            expand: true,
            trailingIcon: Icons.arrow_forward_rounded,
            // The controller checks the fields (empty, both empty, email
            // format) before sending anything.
            onPressed: controller.employeeloginWithEmailAndPassword,
          ),
        ],
      ),
    );
  }
}

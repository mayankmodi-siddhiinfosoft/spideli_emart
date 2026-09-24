import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/login/login_screen.dart';
import 'package:spideliprovider/ui/signUp/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l = context.dsLayout;

    return Scaffold(backgroundColor: c.background, body: l.isWide ? _wide(context) : _compact(context));
  }

  // ---------------------------------------------------------------- phones
  /// Full-bleed brand gradient with the logo crest and the two entry points.
  Widget _compact(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: DsGradients.brand(context)),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: DsFadeSlideIn.stagger([_brandBlock(context), const DsGap(DsSpace.huge), ..._actions(context), const DsGap(DsSpace.xl)]),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------- tablets / iPad
  /// Split layout: brand panel on the left, action card on the right.
  Widget _wide(BuildContext context) {
    final c = context.dsColors;
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: DsGradients.brand(context)),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(DsSpace.huge),
                  child: DsFadeSlideIn(child: _brandBlock(context)),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.all(DsSpace.xxxl),
                  child: DsCard(
                    padding: const EdgeInsets.all(DsSpace.xxl),
                    color: c.surface,
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: DsFadeSlideIn.stagger(_actions(context, onGradient: false))),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _brandBlock(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(DsSpace.xl),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: DsRadius.brXxl,
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Image.asset(
            'assets/images/app_logo.png',
            // color: Color(COLOR_PRIMARY),
            fit: BoxFit.cover,
            height: 140,
          ),
        ),
        const DsGap(DsSpace.xxxl),
        Text(
          'Welcome to Provider App'.tr,
          textAlign: TextAlign.center,
          style: DsTypography.display.copyWith(color: Colors.white),
        ),
        const DsGap(DsSpace.md),
        Text(
          'Manage your bookings, services and earnings in one place.'.tr,
          textAlign: TextAlign.center,
          style: DsTypography.bodyLg.copyWith(color: Colors.white.withValues(alpha: 0.86)),
        ),
      ],
    );
  }

  List<Widget> _actions(BuildContext context, {bool onGradient = true}) {
    final c = context.dsColors;
    if (onGradient) {
      return [
        // White pill on the gradient: the primary entry point.
        DsButton(
          label: 'Log In'.tr,
          size: DsButtonSize.lg,
          expand: true,
          variant: DsButtonVariant.primary,
          color: Colors.white,
          onPressed: () {
            Get.to(const LoginScreen());
          },
        ),
        const DsGap(DsSpace.lg),
        // Frosted outline on the gradient (a plain secondary button would use
        // the opaque surface color and break the hero).
        DsCard.glass(
          semanticLabel: 'Sign Up'.tr,
          padding: const EdgeInsets.symmetric(vertical: DsSpace.lg, horizontal: DsSpace.xl),
          onTap: () {
            Get.to(SignupScreen());
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 24),
            child: Center(
              child: Text(
                'Sign Up'.tr,
                textAlign: TextAlign.center,
                style: DsTypography.label.copyWith(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
      ];
    }
    return [
      Text('Get started'.tr, style: DsTypography.title.copyWith(color: c.textPrimary)),
      const DsGap(DsSpace.xs),
      Text('Log in to your provider account or create a new one.'.tr, style: DsTypography.body.copyWith(color: c.textSecondary)),
      const DsGap(DsSpace.xxl),
      DsButton.primary(
        label: 'Log In'.tr,
        size: DsButtonSize.lg,
        expand: true,
        onPressed: () {
          Get.to(const LoginScreen());
        },
      ),
      const DsGap(DsSpace.lg),
      DsButton.secondary(
        label: 'Sign Up'.tr,
        size: DsButtonSize.lg,
        expand: true,
        onPressed: () {
          Get.to(SignupScreen());
        },
      ),
    ];
  }
}

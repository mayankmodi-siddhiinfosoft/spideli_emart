import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spideliprovider/themes/ds/ds.dart';

/// Shared shell for the authentication flow (login, signup, phone, OTP).
///
/// * Phones – one focused, scrollable column capped at the reading width.
/// * Tablets / iPad – a split layout: brand gradient panel on the leading
///   side, the form (optionally in a raised card) on the trailing side.
///
/// It only arranges widgets that the caller already built, so controller
/// observables stay read inside the caller's `Obx`/`GetX` builder.
class AuthShell extends StatelessWidget {
  /// Form rows; they are staggered in on first appearance.
  final List<Widget> children;

  /// Wrap the column in a raised card on wide screens.
  final bool cardOnWide;

  /// Max width of the form column on wide screens.
  final double maxFormWidth;

  const AuthShell({super.key, required this.children, this.cardOnWide = true, this.maxFormWidth = 440});

  @override
  Widget build(BuildContext context) {
    final l = context.dsLayout;
    final column = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: DsFadeSlideIn.stagger(children));

    if (!l.isWide) {
      return SingleChildScrollView(
        child: DsResponsive(
          maxWidth: DsLayout.contentMax,
          padded: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.xxl),
            child: column,
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(flex: 4, child: AuthBrandPanel()),
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(DsSpace.xxxl, DsSpace.xl, DsSpace.xxxl, DsSpace.xxxl),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxFormWidth),
                child: cardOnWide ? DsCard(padding: const EdgeInsets.all(DsSpace.xxl), child: column) : column,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Brand gradient column shown beside the form on tablets and iPad.
class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: DsGradients.brand(context)),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DsSpace.huge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(DsSpace.xl),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: DsRadius.brXxl,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Image.asset('assets/images/app_logo.png', height: 120),
              ),
              const DsGap(DsSpace.xxxl),
              Text(
                'Welcome to Provider App'.tr,
                textAlign: TextAlign.center,
                style: DsTypography.headline.copyWith(color: Colors.white),
              ),
              const DsGap(DsSpace.md),
              Text(
                'Manage your bookings, services and earnings in one place.'.tr,
                textAlign: TextAlign.center,
                style: DsTypography.bodyLg.copyWith(color: Colors.white.withValues(alpha: 0.86)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Password row whose visibility is driven by a controller observable
/// (DsTextField keeps that state internally, which the auth screens must not
/// do because the controller owns it).
class AuthPasswordField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final Widget? prefix;
  final double bottomSpacing;

  const AuthPasswordField({super.key, required this.label, required this.hint, required this.controller, required this.obscure, required this.onToggle, this.prefix, this.bottomSpacing = DsSpace.lg});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsFieldLabel(label),
          TextField(
            controller: controller,
            obscureText: obscure,
            obscuringCharacter: '●',
            maxLines: 1,
            style: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
            cursorColor: c.brand,
            decoration: DsInputDecoration.of(
              context,
              hint: hint,
              prefix: prefix,
              suffix: DsIconButton(
                icon: obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                semanticLabel: obscure ? 'Show password'.tr : 'Hide password'.tr,
                size: 40,
                onPressed: onToggle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

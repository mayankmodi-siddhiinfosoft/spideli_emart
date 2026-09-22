import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/ds/ds.dart';

/// Shared presentation shell for the auth flow (login, signup, phone, OTP,
/// forgot password).
///
/// * Phones: a focused single column – brand mark, large title, form, and an
///   optional footer pinned to the bottom.
/// * Tablets / iPad (`isWide`): split screen – a brand gradient panel with
///   logo and tagline on the left, the form in a card (max 440) on the right.
///
/// Presentation only: it never navigates on its own except the standard
/// back button (`maybePop`, same as the old implicit AppBar back button).
class AuthLayout extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Optional custom subtitle widget (overrides [subtitle]).
  final Widget? subtitleWidget;

  /// Main form content.
  final Widget child;

  /// Bottom content (e.g. "Don't have an account? Sign up").
  final Widget? footer;

  /// Shown instead of the logo in the phone header (e.g. OTP, reset).
  final IconData? heroIcon;

  const AuthLayout({super.key, required this.title, this.subtitle, this.subtitleWidget, required this.child, this.footer, this.heroIcon});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l = context.dsLayout;
    return Scaffold(
      backgroundColor: c.background,
      resizeToAvoidBottomInset: true,
      appBar: l.isWide ? null : const DsAppBar(),
      body: l.isWide ? _wide(context) : _phone(context),
      bottomNavigationBar: l.isWide || footer == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, DsSpace.lg), child: footer),
            ),
    );
  }

  Widget _header(BuildContext context, {required bool compact}) {
    final c = context.dsColors;
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[heroIcon != null ? DsIconWell(icon: heroIcon, size: 64, tone: DsTone.brand) : const AuthBrandMark(size: 64), const DsGap(DsSpace.xxl)],
        Semantics(header: true, child: Text(title, style: (compact ? t.headline : t.display).withColor(c.textPrimary))),
        const DsGap(DsSpace.sm),
        if (subtitleWidget != null) subtitleWidget! else if (subtitle != null) Text(subtitle!, style: t.bodyLg.withColor(c.textSecondary)),
      ],
    );
  }

  Widget _phone(BuildContext context) {
    final l = context.dsLayout;
    return Stack(
      children: [
        // Soft brand wash behind the header.
        Positioned(
          top: -140,
          right: -100,
          child: IgnorePointer(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [context.dsColors.brandSoft, context.dsColors.background.withValues(alpha: 0)]),
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, DsSpace.xxl),
          child: DsResponsive(
            maxWidth: 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: DsFadeSlideIn.stagger([
                _header(context, compact: false),
                Padding(
                  padding: const EdgeInsets.only(top: DsSpace.xxxl),
                  child: child,
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _wide(BuildContext context) {
    final c = context.dsColors;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(flex: 5, child: AuthBrandPanel()),
        Expanded(
          flex: 6,
          child: SafeArea(
            left: false,
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.xxxl, vertical: DsSpace.huge),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: DsFadeSlideIn(
                        child: DsCard(
                          padding: const EdgeInsets.all(DsSpace.xxxl),
                          radius: DsRadius.xl,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _header(context, compact: true),
                              const DsGap(DsSpace.xxl),
                              child,
                              if (footer != null) ...[Divider(height: DsSpace.xxxl, color: c.divider), footer!],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (canPop)
                  const Positioned(
                    top: DsSpace.sm,
                    left: DsSpace.sm,
                    child: DsBackButton(variant: DsIconButtonVariant.tonal),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// App logo in a raised rounded tile.
class AuthBrandMark extends StatelessWidget {
  final double size;
  final bool onBrand;
  const AuthBrandMark({super.key, this.size = 64, this.onBrand = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        color: onBrand ? Colors.white : c.surface,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: onBrand ? DsShadows.lg(context) : DsShadows.glow(context, color: c.brand),
      ),
      child: Image.asset("assets/images/ic_logo.png", fit: BoxFit.contain, semanticLabel: 'Logo'.tr),
    );
  }
}

/// Left panel of the tablet split layout.
class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    final points = <(IconData, String)>[
      (Icons.receipt_long_rounded, 'Real-time orders'.tr),
      (Icons.inventory_2_outlined, 'Products & inventory'.tr),
      (Icons.account_balance_wallet_outlined, 'Secure payouts'.tr),
    ];
    return Container(
      decoration: BoxDecoration(gradient: DsGradients.brand(context)),
      child: Stack(
        children: [
          Positioned(
            bottom: -120,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
          ),
          Positioned(
            top: -60,
            left: -60,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
          ),
          SafeArea(
            right: false,
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: const EdgeInsets.all(DsSpace.huge),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: (box.maxHeight - DsSpace.huge * 2).clamp(0, double.infinity)),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AuthBrandMark(size: 72, onBrand: true),
                        const Spacer(),
                        Text('Your store, beautifully managed.'.tr, style: t.displayLg.withColor(Colors.white)),
                        const DsGap(DsSpace.md),
                        Text('Manage orders, products and payouts in one place.'.tr, style: t.bodyLg.withColor(Colors.white.withValues(alpha: 0.85))),
                        const DsGap(DsSpace.xxl),
                        ...DsFadeSlideIn.stagger([
                          for (final p in points)
                            Padding(
                              padding: const EdgeInsets.only(bottom: DsSpace.md),
                              child: Row(
                                children: [
                                  DsIconWell(icon: p.$1, onBrand: true, size: 40, circle: true),
                                  const DsGap(DsSpace.md),
                                  Expanded(child: Text(p.$2, style: t.label.withColor(Colors.white))),
                                ],
                              ),
                            ),
                        ]),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text field with the DS look whose obscure state is driven from outside
/// (the controllers own `passwordVisible` flags, so the field must follow
/// them on every rebuild – [DsTextField] keeps its own state instead).
class AuthField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final bool obscureText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;

  const AuthField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.prefixIcon,
    this.prefix,
    this.suffix,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsFieldLabel(label),
          TextFormField(
            controller: controller,
            enabled: enabled,
            obscureText: obscureText,
            obscuringCharacter: '●',
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            inputFormatters: inputFormatters,
            autofillHints: autofillHints,
            cursorColor: c.brand,
            style: context.dsText.bodyStrong.withColor(enabled ? c.textPrimary : c.textSecondary),
            decoration: DsInputDecoration.of(context, hint: hint, prefixIcon: prefixIcon, prefix: prefix, suffix: suffix, enabled: enabled),
          ),
        ],
      ),
    );
  }
}

/// Eye toggle used as the suffix of password [AuthField]s.
class AuthVisibilityToggle extends StatelessWidget {
  /// Current `passwordVisible` value of the controller (true = obscured).
  final bool obscured;
  final VoidCallback onTap;
  const AuthVisibilityToggle({super.key, required this.obscured, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DsIconButton(
      icon: obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      semanticLabel: obscured ? 'Show password'.tr : 'Hide password'.tr,
      size: 40,
      onPressed: onTap,
    );
  }
}

/// "Question? Action" footer line with a 48dp tappable action.
class AuthFooterPrompt extends StatelessWidget {
  final String question;
  final String action;
  final VoidCallback onTap;
  const AuthFooterPrompt({super.key, required this.question, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(question, style: t.body.withColor(c.textSecondary)),
        DsButton.ghost(label: action, size: DsButtonSize.sm, onPressed: onTap),
      ],
    );
  }
}

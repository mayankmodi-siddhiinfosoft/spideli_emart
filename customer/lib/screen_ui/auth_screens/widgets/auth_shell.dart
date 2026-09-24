import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shared chrome for the authentication flow (DS archetype **I — Auth**).
///
/// Phones show a focused card: brand blob with the logo, an overline, a
/// `display` title and the form on the page background. Tablets / iPad show a
/// split layout: a brand gradient panel with the logo and tagline on the left,
/// a 460-wide form column on the right.
///
/// This widget holds no state and reads no observable, so it is safe to build
/// inside a `GetX` / `Obx` builder.
class AuthScaffold extends StatelessWidget {
  /// Small caps line above the title.
  final String eyebrow;

  /// The screen's headline (kept verbatim from the old screen).
  final String title;

  /// Icon shown inside the brand blob on phones.
  final IconData icon;

  /// App-bar actions (the "Skip" button).
  final List<Widget>? actions;

  /// Custom app-bar leading (back button with the screen's own handler).
  final Widget? leading;
  final bool showBack;

  /// Form content.
  final List<Widget> children;

  /// Bottom line ("Didn't have an account? Sign up").
  final Widget? footer;

  const AuthScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.icon,
    required this.children,
    this.actions,
    this.leading,
    this.showBack = false,
    this.footer,
  });

  static const String logoAsset = 'assets/images/ic_logo.png';

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l = context.dsLayout;

    if (l.isWide) {
      return Scaffold(
        backgroundColor: c.background,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(flex: 5, child: AuthBrandPanel()),
            Expanded(
              flex: 6,
              child: SafeArea(
                child: Column(
                  children: [
                    _WideBar(actions: actions, leading: leading, showBack: showBack),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(DsSpace.xxxl, DsSpace.lg, DsSpace.xxxl, DsSpace.xxxl),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: DsFadeSlideIn.stagger([_Heading(eyebrow: eyebrow, title: title, icon: icon, compact: true), ...children]),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (footer != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(DsSpace.xxxl, 0, DsSpace.xxxl, DsSpace.lg),
                        child: Center(child: footer),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DsScaffold(
      appBar: DsAppBar(actions: actions, leading: leading, showBack: showBack, backgroundColor: c.background),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, DsSpace.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: DsFadeSlideIn.stagger([_Heading(eyebrow: eyebrow, title: title, icon: icon, compact: false), ...children]),
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: EdgeInsets.fromLTRB(l.gutter, 0, l.gutter, DsSpace.md),
                child: Center(child: footer),
              ),
          ],
        ),
      ),
      maxContentWidth: 560,
    );
  }
}

/// The gradient brand panel used on tablets / iPad.
class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: DsGradients.brand(context)),
      child: Stack(
        children: [
          const Positioned(top: -70, right: -50, child: _Blob(size: 240, opacity: 0.14)),
          const Positioned(bottom: -60, left: -70, child: _Blob(size: 280, opacity: 0.10)),
          Positioned(top: 120, left: -30, child: _Blob(size: 110, opacity: 0.08)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(DsSpace.huge),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(DsSpace.lg),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: DsRadius.brXl),
                    child: Image.asset(AuthScaffold.logoAsset, height: 48, width: 48),
                  ),
                  const DsGap(DsSpace.xxxl),
                  Text('Everything in one app'.tr, style: DsTypography.displayLg.copyWith(color: Colors.white)),
                  const DsGap(DsSpace.md),
                  Text(
                    'Food, groceries, rides, parcels and more — one account for every service.'.tr,
                    style: DsTypography.bodyLg.copyWith(color: Colors.white.withValues(alpha: 0.86)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final double opacity;
  const _Blob({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: opacity)),
    );
  }
}

class _WideBar extends StatelessWidget {
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  const _WideBar({this.actions, this.leading, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          const DsGap(DsSpace.md),
          if (leading != null) leading! else if (showBack && canPop) const DsBackButton(),
          const Spacer(),
          ...?actions,
          const DsGap(DsSpace.lg),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final IconData icon;
  final bool compact;
  const _Heading({required this.eyebrow, required this.title, required this.icon, required this.compact});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: EdgeInsets.only(bottom: DsSpace.xxl, top: compact ? DsSpace.xxl : DsSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(gradient: DsGradients.brand(context), borderRadius: DsRadius.brXl, boxShadow: DsShadows.glow(context)),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const DsGap(DsSpace.xl),
          ],
          Text(eyebrow.tr.toUpperCase(), style: t.overline.withColor(c.brandStrong)),
          const DsGap(DsSpace.sm),
          Text(title, style: t.display),
        ],
      ),
    );
  }
}

/// "Already have an account? Log in" style footer line.
class AuthFooterLink extends StatelessWidget {
  final String text;
  final String linkText;
  final GestureRecognizer recognizer;

  const AuthFooterLink({super.key, required this.text, required this.linkText, required this.recognizer});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Text.rich(
      TextSpan(
        text: text,
        style: t.bodyStrong.withColor(c.textSecondary),
        children: [
          TextSpan(
            text: linkText,
            style: t.label.withColor(c.brandStrong).copyWith(decoration: TextDecoration.underline, decorationColor: c.brandStrong),
            recognizer: recognizer,
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// The "Skip" app-bar action shared by the auth screens.
class AuthSkipButton extends StatelessWidget {
  final VoidCallback onPressed;
  const AuthSkipButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.md),
        minimumSize: const Size(0, 48),
        foregroundColor: c.textSecondary,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Skip".tr, style: t.label.withColor(c.textSecondary)),
          const DsGap(DsSpace.xs),
          Icon(Icons.arrow_forward_rounded, size: 16, color: c.textSecondary),
        ],
      ),
    );
  }
}

/// Password field whose visibility is driven by a controller observable, so it
/// cannot use `DsTextField(obscurable: true)` (that keeps its own state).
/// Read `obscured` in the tracked GetX/Obx builder and pass it down.
class AuthPasswordField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool obscured;
  final VoidCallback onToggle;

  const AuthPasswordField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.obscured,
    required this.onToggle,
    this.focusNode,
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
          DsFieldLabel(label, required: true),
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscured,
            obscuringCharacter: '●',
            cursorColor: c.brand,
            style: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
            decoration: DsInputDecoration.of(
              context,
              hint: hint,
              prefixIcon: Icons.lock_outline_rounded,
              suffix: DsIconButton(
                icon: obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                semanticLabel: obscured ? 'Show password'.tr : 'Hide password'.tr,
                size: 36,
                onPressed: onToggle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Social / alternate sign-in button (Google, Apple, mobile, email).
class AuthAltButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onPressed;

  const AuthAltButton({super.key, required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Material(
      color: c.surface,
      borderRadius: DsRadius.brMd,
      child: InkWell(
        onTap: onPressed,
        borderRadius: DsRadius.brMd,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
          decoration: BoxDecoration(borderRadius: DsRadius.brMd, border: Border.all(color: c.border)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 22, height: 22, child: Center(child: icon)),
              const DsGap(DsSpace.md),
              Flexible(child: Text(label, style: t.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Legacy confirmation dialog (kept for existing screens and controllers).
/// Visuals follow the design system; the constructor API, texts and
/// callbacks are unchanged (the positive button shows [positiveString], falling back to 'Confirm', and
/// keeps its success tone). New code should use [DsDialog].
class CustomDialogBox extends StatelessWidget {
  final String title, descriptions, positiveString, negativeString;
  final Widget? img;
  final Function() positiveClick;
  final Function() negativeClick;

  const CustomDialogBox({
    super.key,
    required this.title,
    required this.descriptions,
    required this.img,
    required this.positiveClick,
    required this.negativeClick,
    required this.positiveString,
    required this.negativeString,
  });

  @override
  Widget build(BuildContext context) {
    // Theme brightness follows ThemeController through GetMaterialApp.themeMode.
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: DsRadius.brXl),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: DsSpace.xxl, vertical: DsSpace.xxl),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: contentBox(context, context.dsIsDark)),
    );
  }

  Widget contentBox(BuildContext context, bool isDark) {
    final c = DsColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: DsRadius.brXl,
        border: isDark ? Border.all(color: c.border) : null,
        boxShadow: DsShadows.lg(context),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DsSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (img != null)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.7, end: 1),
                duration: DsMotion.of(context, DsMotion.slow),
                curve: DsMotion.spring,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: img!,
              ),
            const SizedBox(height: DsSpace.lg),
            if (title.isNotEmpty)
              Semantics(
                header: true,
                child: Text(title.tr, textAlign: TextAlign.center, style: DsTypography.title.copyWith(color: c.textPrimary)),
              ),
            const SizedBox(height: DsSpace.sm),
            if (descriptions.isNotEmpty) Text(descriptions.tr, textAlign: TextAlign.center, style: DsTypography.body.copyWith(color: c.textSecondary)),
            const SizedBox(height: DsSpace.xxl),
            Row(
              children: [
                Expanded(child: DsButton.secondary(label: negativeString.tr, expand: true, onPressed: () => negativeClick())),
                const SizedBox(width: DsSpace.md),
                Expanded(child: DsButton.primary(label: positiveString.isEmpty ? 'Confirm'.tr : positiveString.tr, color: c.success, expand: true, onPressed: () => positiveClick())),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

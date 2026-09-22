import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Legacy confirmation dialog (kept for existing screens). Visuals follow
/// the design system; the constructor API and callbacks are unchanged.
///
/// With a negative action (all current two-button uses are log-out / delete
/// account confirmations) the positive action is styled as destructive.
/// Without one ("Alert" / "Okay") it is a single primary button.
/// New code should use [DsDialog].
class CustomDialogBox extends StatelessWidget {
  final String title, descriptions, positiveString;
  final String? negativeString;
  final Widget? widget;
  final Widget? img;
  final Function() positiveClick;
  final Function()? negativeClick;

  const CustomDialogBox({
    super.key,
    required this.title,
    required this.descriptions,
    this.widget,
    this.img,
    required this.positiveClick,
    this.negativeClick,
    required this.positiveString,
    this.negativeString,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: DsRadius.brXl),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: DsSpace.xxl, vertical: DsSpace.xxl),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: contentBox(context)),
    );
  }

  Container contentBox(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    final c = DsColors.resolve(isDark, highContrast: MediaQuery.maybeHighContrastOf(context) ?? false);
    final hasNegative = negativeString != null && negativeString != '';
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
            Visibility(
              visible: title.isNotEmpty,
              child: Semantics(
                header: true,
                child: Text(title, textAlign: TextAlign.center, style: DsTypography.title.copyWith(color: c.textPrimary)),
              ),
            ),
            const SizedBox(height: DsSpace.sm),
            Visibility(
              visible: descriptions.isNotEmpty,
              child: Text(descriptions, style: DsTypography.body.copyWith(color: c.textSecondary), textAlign: TextAlign.center),
            ),
            const SizedBox(height: DsSpace.xxl),
            if (widget != null) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [widget!, const SizedBox(height: 10)]),
            Row(
              children: [
                if (hasNegative) ...[
                  Expanded(
                    child: DsButton.secondary(label: negativeString.toString(), expand: true, onPressed: () => negativeClick!()),
                  ),
                  const SizedBox(width: DsSpace.md),
                ],
                Expanded(
                  child: hasNegative
                      ? DsButton.danger(label: positiveString.toString(), expand: true, onPressed: () => positiveClick())
                      : DsButton.primary(label: positiveString.toString(), expand: true, onPressed: () => positiveClick()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/themes/responsive.dart';
import 'package:flutter/material.dart';

/// Legacy filled button (kept for existing screens). Visuals follow the
/// design system (DS radius, ripple, press feedback, brand glow, scale-down
/// label); the constructor API and sizing behaviour are unchanged.
/// New code should use [DsButton].
class RoundedButtonFill extends StatelessWidget {
  final String title;
  final double? width;
  final double? height;
  final double? fontSizes;
  final double? radius;
  final Color? color;
  final Color? textColor;
  final Widget? icon;
  final bool? isRight;
  final Function()? onPress;

  const RoundedButtonFill({super.key, required this.title, this.height, required this.onPress, this.width, this.color, this.icon, this.fontSizes, this.textColor, this.isRight, this.radius});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final br = BorderRadius.circular(radius ?? DsRadius.md);
    final fg = textColor ?? c.textPrimary;
    final isBrand = color != null && color == c.brand;
    final label = Text(
      title.toString(),
      textAlign: TextAlign.center,
      maxLines: 1,
      style: DsTypography.label.copyWith(color: fg, fontSize: fontSizes ?? 14, letterSpacing: 0.1),
    );

    return Semantics(
      button: true,
      enabled: onPress != null,
      child: DsPressable(
        child: Container(
          width: Responsive.width(width ?? 100, context),
          height: Responsive.height(height ?? 6, context),
          decoration: BoxDecoration(
            borderRadius: br,
            boxShadow: isBrand ? DsShadows.glow(context, color: color).take(1).toList() : null,
          ),
          child: Material(
            color: color ?? Colors.transparent,
            borderRadius: br,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                onPress!();
              },
              splashColor: fg.withValues(alpha: 0.14),
              highlightColor: fg.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (isRight == false) Padding(padding: const EdgeInsets.only(right: 6), child: icon),
                    // Scale the label down instead of clipping at large text
                    // sizes, since the height is a fixed fraction of the screen.
                    Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: label)),
                    if (isRight == true) Padding(padding: const EdgeInsets.only(left: 6), child: icon),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

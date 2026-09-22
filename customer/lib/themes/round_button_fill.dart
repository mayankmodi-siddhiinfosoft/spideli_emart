import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/responsive.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_them_data.dart';

/// Legacy filled button (kept for existing screens). Visuals follow the
/// design system; the constructor API, sizing and tap behaviour are
/// unchanged. New code should use [DsButton].
class RoundedButtonFill extends StatelessWidget {
  final String title;
  final double? width;
  final double? height;
  final double? fontSizes;
  final double? borderRadius;
  final Color? color;
  final Color? textColor;
  final Widget? icon;
  final bool? isRight;
  final bool? isCenter;
  final VoidCallback? onPress;

  // final Function()? onPress;

  const RoundedButtonFill({
    super.key,
    required this.title,
    this.borderRadius,
    this.height,
    required this.onPress,
    this.width,
    this.color,
    this.isCenter,
    this.icon,
    this.fontSizes,
    this.textColor,
    this.isRight,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(borderRadius ?? DsRadius.md);
    final fill = color;
    // Brand / section-colored fills get the soft glow of DsButton.primary.
    final isBrand = fill != null && fill == AppThemeData.primary300;
    // Default label color: readable ink on the fill (white on red / blue /
    // orange, dark on amber / green / cyan section accents).
    final fg = textColor ?? (fill != null && fill.a > 0.5 ? DsColors.onColor(fill) : AppThemeData.grey50);
    final label = Text(
      title.tr,
      textAlign: TextAlign.center,
      maxLines: 1,
      style: AppThemeData.semiBoldTextStyle(fontSize: fontSizes ?? 16, color: fg).copyWith(letterSpacing: 0.1),
    );
    // Scale the label down instead of clipping at large text sizes, since
    // the height is a fixed fraction of the screen.
    final fitted = FittedBox(fit: BoxFit.scaleDown, child: label);

    return Semantics(
      button: true,
      child: DsPressable(
        child: Container(
          width: Responsive.width(width ?? 100, context),
          height: Responsive.height(height ?? 6, context),
          decoration: BoxDecoration(borderRadius: br, boxShadow: isBrand ? DsShadows.glow(context, color: fill).take(1).toList() : null),
          child: Material(
            color: fill ?? Colors.transparent,
            borderRadius: br,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                onPress?.call();
              },
              splashColor: fg.withValues(alpha: 0.14),
              highlightColor: fg.withValues(alpha: 0.06),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isRight == false) Padding(padding: const EdgeInsets.only(right: 10, left: 10), child: icon),
                  isCenter == true
                      ? Flexible(child: fitted)
                      : Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: isRight == null ? 0 : 30),
                            child: Center(child: fitted),
                          ),
                        ),
                  if (isRight == true) Padding(padding: const EdgeInsets.only(left: 10, right: 10), child: icon),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/responsive.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_them_data.dart';

/// Legacy outlined button (kept for existing screens). Visuals follow the
/// design system; the constructor API, sizing and tap behaviour are
/// unchanged. New code should use `DsButton.secondary` / `DsButton.tonal`.
class RoundedButtonBorder extends StatelessWidget {
  final String title;
  final double? width;
  final double? height;
  final double? fontSizes;
  final double? radius;
  final Color? color;
  final Color? borderColor;
  final Color? textColor;
  final Widget? icon;
  final bool? isRight;
  final bool? isCenter;
  final Function()? onPress;

  const RoundedButtonBorder({
    super.key,
    required this.title,
    this.height,
    required this.onPress,
    this.width,
    this.radius,
    this.color,
    this.icon,
    this.fontSizes,
    this.textColor,
    this.isRight,
    this.borderColor,
    this.isCenter,
  });

  @override
  Widget build(BuildContext context) {
    // Theme brightness follows ThemeController through GetMaterialApp.themeMode.
    final c = DsColors.of(context);
    final fg = textColor ?? (isCenter == true ? AppThemeData.grey800 : (c.isDark ? AppThemeData.grey100 : AppThemeData.grey700));
    final accent = borderColor ?? AppThemeData.danger300;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius ?? DsRadius.md), side: BorderSide(color: accent, width: 1.2));
    final fitted = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(title.tr, textAlign: TextAlign.center, maxLines: 1, style: AppThemeData.semiBoldTextStyle(fontSize: fontSizes ?? 14, color: fg)),
    );

    return Semantics(
      button: true,
      child: DsPressable(
        child: SizedBox(
          width: Responsive.width(width ?? 100, context),
          height: Responsive.height(height ?? 6, context),
          child: Material(
            color: color ?? Colors.transparent,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                onPress?.call();
              },
              splashColor: accent.withValues(alpha: 0.10),
              highlightColor: accent.withValues(alpha: 0.05),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isRight == false) Padding(padding: const EdgeInsets.only(right: 10, left: 0), child: icon),
                  isCenter == true
                      ? Flexible(child: fitted)
                      : Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: isRight == null ? 0 : 30),
                            child: Center(child: fitted),
                          ),
                        ),
                  if (isRight == true) Padding(padding: const EdgeInsets.only(left: 10, right: 20), child: icon),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

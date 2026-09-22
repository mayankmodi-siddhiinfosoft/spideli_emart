import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/responsive.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_them_data.dart';

/// Legacy outlined button (kept for existing screens). Visuals follow the
/// design system; the constructor API and sizing behaviour are unchanged.
/// New code should use `DsButton.secondary` / `DsButton.tonal`.
class RoundedButtonBorder extends StatelessWidget {
  final String title;
  final double? width;
  final double? height;
  final double? fontSizes;
  final Color? color;
  final Color? borderColor;
  final Color? textColor;
  final Widget? icon;
  final bool isRight;
  final bool isCenter;
  final double iconSpacing;
  final Function()? onPress;

  const RoundedButtonBorder({
    super.key,
    required this.title,
    required this.onPress,
    this.width,
    this.height,
    this.fontSizes,
    this.color,
    this.borderColor,
    this.textColor,
    this.icon,
    this.isRight = false,
    this.isCenter = false,
    this.iconSpacing = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final fg = textColor ?? AppThemeData.grey800;
    final text = Flexible(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          title.tr,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: AppThemeData.semiBoldTextStyle(fontSize: fontSizes ?? 14, color: fg),
        ),
      ),
    );

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: isRight
          ? [
              text,
              if (icon != null) ...[SizedBox(width: iconSpacing), icon!],
            ]
          : [
              if (icon != null) ...[icon!, SizedBox(width: iconSpacing)],
              text,
            ],
    );

    final shape = RoundedRectangleBorder(
      borderRadius: DsRadius.brMd,
      side: BorderSide(color: borderColor ?? AppThemeData.danger300, width: 1.2),
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
              splashColor: (borderColor ?? c.brand).withValues(alpha: 0.10),
              highlightColor: (borderColor ?? c.brand).withValues(alpha: 0.05),
              child: isCenter
                  ? Center(child: content)
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: content,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

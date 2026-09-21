import 'package:driver/themes/responsive.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_them_data.dart';

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
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: isRight
          ? [
              Text(
                title.tr,
                textAlign: TextAlign.center,
                style: AppThemeData.semiBoldTextStyle(fontSize: fontSizes ?? 14, color: textColor ?? AppThemeData.grey800),
              ),
              if (icon != null) ...[
                SizedBox(width: iconSpacing),
                icon!,
              ]
            ]
          : [
              if (icon != null) ...[
                icon!,
                SizedBox(width: iconSpacing),
              ],
              Text(
                title.tr,
                textAlign: TextAlign.center,
                style: AppThemeData.semiBoldTextStyle(fontSize: fontSizes ?? 14, color: textColor ?? AppThemeData.grey800),
              ),
            ],
    );

    return InkWell(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        onPress?.call();
      },
      child: Container(
        width: Responsive.width(width ?? 100, context),
        height: Responsive.height(height ?? 6, context),
        decoration: ShapeDecoration(
          color: color ?? Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
            side: BorderSide(color: borderColor ?? AppThemeData.danger300),
          ),
        ),
        child: isCenter
            ? Center(child: content)
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: content,
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/themes/theme_controller.dart';

/// Legacy labelled text field (kept for existing screens). Visuals follow
/// the design system; the constructor API and behaviour are unchanged.
/// New code should use [DsTextField].
class TextFieldWidget extends StatelessWidget {
  final String? title;
  final String? initialValue;
  final String hintText;
  final TextEditingController? controller;
  final Widget? prefix;
  final Widget? suffix;
  final bool? enable;
  final bool? readOnly;
  final bool? obscureText;
  final int? maxLine;
  final int? maxLength;
  final TextInputType? textInputType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onchange;
  final Function()? onClick;
  final TextInputAction? textInputAction;
  final String? fontFamilyTitle;
  final double? fontSizeTitle;

  const TextFieldWidget({
    super.key,
    this.textInputType,
    this.initialValue,
    this.enable,
    this.obscureText,
    this.prefix,
    this.suffix,
    this.title,
    required this.hintText,
    this.controller,
    this.maxLine,
    this.maxLength,
    this.inputFormatters,
    this.readOnly,
    this.onchange,
    this.textInputAction,
    this.onClick,
    this.fontFamilyTitle,
    this.fontSizeTitle,
  });

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    final c = DsColors.resolve(isDark);
    final enabled = enable ?? true;

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(borderRadius: DsRadius.brMd, borderSide: BorderSide(color: color, width: width));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Visibility(
            visible: title != null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? "".tr,
                  style: TextStyle(
                    fontFamily: fontFamilyTitle ?? AppThemeData.medium,
                    fontSize: fontSizeTitle ?? 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: DsSpace.sm),
              ],
            ),
          ),
          TextFormField(
            cursorColor: AppThemeData.primary300,
            readOnly: readOnly ?? false,
            onTap: onClick,
            initialValue: initialValue,
            keyboardType: textInputType ?? TextInputType.text,
            textCapitalization: TextCapitalization.sentences,
            controller: controller,
            maxLines: maxLine ?? 1,
            textInputAction: textInputAction ?? TextInputAction.done,
            inputFormatters: inputFormatters,
            obscureText: obscureText ?? false,
            obscuringCharacter: '●',
            onChanged: onchange,
            maxLength: maxLength,
            style: TextStyle(fontSize: 14, height: 1.4, color: enabled ? c.textPrimary : c.textSecondary, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              errorStyle: DsTypography.caption.copyWith(color: c.danger),
              errorMaxLines: 3,
              filled: true,
              enabled: enabled,
              isDense: false,
              contentPadding: EdgeInsets.symmetric(vertical: prefix != null ? 16 : 14, horizontal: DsSpace.lg),
              fillColor: enabled ? c.surfaceAlt : Color.alphaBlend(c.surfaceAlt.withValues(alpha: 0.5), c.surface),
              prefixIcon: prefix,
              suffixIcon: suffix,
              prefixIconColor: c.textMuted,
              suffixIconColor: c.textMuted,
              disabledBorder: border(Colors.transparent),
              focusedBorder: border(AppThemeData.primary300, 1.6),
              enabledBorder: border(isDark ? c.border : c.surfaceAlt),
              errorBorder: border(c.danger),
              focusedErrorBorder: border(c.danger, 1.6),
              border: border(isDark ? c.border : c.surfaceAlt),
              hintText: hintText.tr,
              hintStyle: TextStyle(fontSize: 14, height: 1.4, color: c.textMuted, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}

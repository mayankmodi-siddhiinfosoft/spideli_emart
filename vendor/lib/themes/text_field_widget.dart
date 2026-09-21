import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/theme_controller.dart';

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
                  style: TextStyle(fontFamily: fontFamilyTitle ?? AppThemeData.medium, fontSize: fontSizeTitle ?? 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                ),
                const SizedBox(height: 5),
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
            style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium),
            decoration: InputDecoration(
              errorStyle: const TextStyle(color: Colors.red),
              filled: true,
              enabled: enable ?? true,
              contentPadding: EdgeInsets.symmetric(
                vertical: title == null
                    ? 12
                    : prefix != null
                    ? 16
                    : enable == false
                    ? 14
                    : 8,
                horizontal: 10,
              ),
              fillColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
              prefixIcon: prefix,
              suffixIcon: suffix,
              disabledBorder: UnderlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1),
              ),
              border: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1),
              ),
              hintText: hintText.tr,
              hintStyle: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey600 : AppThemeData.grey400, fontFamily: AppThemeData.regular),
            ),
          ),
        ],
      ),
    );
  }
}

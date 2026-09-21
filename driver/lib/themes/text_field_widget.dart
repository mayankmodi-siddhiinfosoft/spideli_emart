import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'app_them_data.dart';

class TextFieldWidget extends StatefulWidget {
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
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final Function()? onClick;

  const TextFieldWidget({
    super.key,
    this.textInputType,
    this.initialValue,
    this.enable,
    this.readOnly,
    this.obscureText,
    this.prefix,
    this.suffix,
    this.title,
    required this.hintText,
    required this.controller,
    this.maxLine,
    this.maxLength,
    this.inputFormatters,
    this.onchange,
    this.textInputAction,
    this.focusNode,
    this.onClick,
    this.onFieldSubmitted,
  });

  @override
  State<TextFieldWidget> createState() => _TextFieldWidgetState();
}

class _TextFieldWidgetState extends State<TextFieldWidget> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    // Theme-aware colors
    final borderColor = _focusNode.hasFocus ? (isDark ? AppThemeData.greyDark400 : AppThemeData.grey400) : (isDark ? AppThemeData.greyDark200 : AppThemeData.grey200);

    final fillColor = isDark ? (AppThemeData.greyDark100) : (AppThemeData.grey100);

    final textColor = isDark ? AppThemeData.greyDark900 : AppThemeData.grey900;

    final hintColor = isDark ? AppThemeData.greyDark400 : AppThemeData.grey400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Text(widget.title!.tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
          const SizedBox(height: 5),
        ],
        TextFormField(
          keyboardType: widget.textInputType ?? TextInputType.text,
          onTap: widget.onClick,
          initialValue: widget.initialValue,
          textCapitalization: TextCapitalization.sentences,
          controller: widget.controller,
          maxLines: widget.maxLine ?? 1,
          focusNode: _focusNode,
          textInputAction: widget.textInputAction ?? TextInputAction.done,
          inputFormatters: widget.inputFormatters,
          obscureText: widget.obscureText ?? false,
          obscuringCharacter: '●',
          onChanged: widget.onchange,
          maxLength: widget.maxLength,
          readOnly: widget.readOnly ?? false,
          onFieldSubmitted: widget.onFieldSubmitted,
          style: AppThemeData.semiBoldTextStyle(color: textColor),
          decoration: InputDecoration(
            errorStyle: const TextStyle(color: Colors.red),
            filled: true,
            enabled: widget.enable ?? true,
            fillColor: fillColor,
            contentPadding: EdgeInsets.symmetric(vertical: widget.title == null ? 15 : (widget.enable == false ? 13 : 8), horizontal: 10),
            prefixIcon: widget.prefix,
            suffixIcon: widget.suffix,
            prefixIconConstraints: const BoxConstraints(minHeight: 20, minWidth: 20),
            suffixIconConstraints: const BoxConstraints(minHeight: 20, minWidth: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor, width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor, width: 1.2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor, width: 1.2),
            ),
            hintText: widget.hintText.tr,
            hintStyle: AppThemeData.regularTextStyle(fontSize: 14, color: hintColor),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

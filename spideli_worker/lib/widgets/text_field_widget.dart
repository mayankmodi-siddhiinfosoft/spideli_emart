import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:provider/provider.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';

/// Legacy labelled text field (kept for existing screens). Visuals follow
/// the design system; the constructor API and behaviour are unchanged.
/// New code should use [DsTextField].
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
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final isDark = themeChange.getTheme();
    final c = DsColors.resolve(isDark);
    final enabled = widget.enable ?? true;
    final focused = _focusNode.hasFocus;

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(borderRadius: DsRadius.brMd, borderSide: BorderSide(color: color, width: width));

    final restBorder = isDark ? c.border : c.surfaceAlt;
    final fillColor = !enabled
        ? Color.alphaBlend(c.surfaceAlt.withValues(alpha: 0.5), c.surface)
        : (focused ? c.surface : c.surfaceAlt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Text(widget.title!.tr, style: DsTypography.labelSm.copyWith(fontSize: 13, color: c.textSecondary)),
          const SizedBox(height: DsSpace.sm),
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
          cursorColor: c.brand,
          style: DsTypography.bodyStrong.copyWith(color: enabled ? c.textPrimary : c.textSecondary),
          decoration: InputDecoration(
            errorStyle: DsTypography.caption.copyWith(color: c.danger),
            errorMaxLines: 3,
            filled: true,
            enabled: enabled,
            isDense: false,
            fillColor: fillColor,
            contentPadding: EdgeInsets.symmetric(vertical: widget.prefix != null ? 16 : 14, horizontal: DsSpace.lg),
            prefixIcon: widget.prefix,
            suffixIcon: widget.suffix,
            prefixIconColor: c.textMuted,
            suffixIconColor: c.textMuted,
            prefixIconConstraints: const BoxConstraints(minHeight: 20, minWidth: 20),
            suffixIconConstraints: const BoxConstraints(minHeight: 20, minWidth: 20),
            border: border(restBorder),
            enabledBorder: border(restBorder),
            focusedBorder: border(c.brand, 1.6),
            errorBorder: border(c.danger),
            focusedErrorBorder: border(c.danger, 1.6),
            disabledBorder: border(Colors.transparent),
            hintText: widget.hintText.tr,
            hintStyle: DsTypography.body.copyWith(color: c.textMuted),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

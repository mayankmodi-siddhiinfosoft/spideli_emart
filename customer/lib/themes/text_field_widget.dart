import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'app_them_data.dart';

/// Legacy labelled text field (kept for existing screens). Visuals follow
/// the design system; the constructor API and behaviour are unchanged.
/// New code should use [DsTextField].
class TextFieldWidget extends StatefulWidget {
  final String? title;
  final String hintText;
  final TextEditingController? controller;
  final Widget? prefix;
  final Widget? suffix;
  final bool? enable;
  final bool? readOnly;
  final bool? obscureText;
  final int? maxLine;
  final TextInputType? textInputType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onchange;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final Color? hintColor;
  final Color? backgroundColor;
  final Color? borderColor;

  const TextFieldWidget({
    super.key,
    this.textInputType,
    this.enable,
    this.readOnly,
    this.obscureText,
    this.prefix,
    this.suffix,
    this.title,
    required this.hintText,
    required this.controller,
    this.maxLine,
    this.inputFormatters,
    this.onchange,
    this.textInputAction,
    this.focusNode,
    this.onFieldSubmitted,
    this.borderColor,
    this.hintColor,
    this.backgroundColor,
  });

  @override
  State<TextFieldWidget> createState() => _TextFieldWidgetState();
}

class _TextFieldWidgetState extends State<TextFieldWidget> {
  FocusNode? _ownFocusNode;

  FocusNode get _focusNode => widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant TextFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocusChange);
      _focusNode.addListener(_onFocusChange);
    }
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Theme brightness follows ThemeController through GetMaterialApp.themeMode.
    final c = DsColors.of(context);
    final focused = _focusNode.hasFocus;
    final enabled = widget.enable ?? true;

    final idleBorder = widget.borderColor ?? (c.isDark ? c.border : c.surfaceAlt);
    final focusBorder = widget.borderColor ?? c.brand;
    final fillColor = widget.backgroundColor ?? (enabled ? (focused ? c.surface : c.surfaceAlt) : Color.alphaBlend(c.surfaceAlt.withValues(alpha: 0.5), c.surface));
    final hintColor = widget.hintColor ?? c.textMuted;

    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(borderRadius: DsRadius.brMd, borderSide: BorderSide(color: color, width: width));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Text(widget.title!.tr, style: DsTypography.label.copyWith(fontSize: 13, color: c.textSecondary)),
          const SizedBox(height: DsSpace.sm),
        ],
        TextFormField(
          keyboardType: widget.textInputType ?? TextInputType.text,
          textCapitalization: TextCapitalization.sentences,
          controller: widget.controller,
          maxLines: widget.maxLine ?? 1,
          focusNode: _focusNode,
          textInputAction: widget.textInputAction ?? TextInputAction.done,
          inputFormatters: widget.inputFormatters,
          obscureText: widget.obscureText ?? false,
          obscuringCharacter: '●',
          onChanged: widget.onchange,
          readOnly: widget.readOnly ?? false,
          onFieldSubmitted: widget.onFieldSubmitted,
          cursorColor: c.brand,
          style: AppThemeData.mediumTextStyle(fontSize: 14, color: enabled ? c.textPrimary : c.textSecondary).copyWith(height: 1.4),
          decoration: InputDecoration(
            errorStyle: DsTypography.caption.copyWith(color: c.danger),
            errorMaxLines: 3,
            filled: true,
            enabled: enabled,
            fillColor: fillColor,
            contentPadding: EdgeInsets.symmetric(vertical: widget.prefix != null ? 16 : 14, horizontal: DsSpace.lg),
            prefixIcon: widget.prefix,
            suffixIcon: widget.suffix,
            prefixIconColor: c.textMuted,
            suffixIconColor: c.textMuted,
            prefixIconConstraints: const BoxConstraints(minHeight: 20, minWidth: 20),
            suffixIconConstraints: const BoxConstraints(minHeight: 20, minWidth: 20),
            border: border(idleBorder),
            enabledBorder: border(idleBorder),
            focusedBorder: border(focusBorder, 1.6),
            errorBorder: border(c.danger),
            focusedErrorBorder: border(c.danger, 1.6),
            disabledBorder: border(widget.borderColor ?? Colors.transparent),
            hintText: widget.hintText.tr,
            hintStyle: AppThemeData.regularTextStyle(fontSize: 14, color: hintColor).copyWith(height: 1.4),
          ),
        ),
      ],
    );
  }
}

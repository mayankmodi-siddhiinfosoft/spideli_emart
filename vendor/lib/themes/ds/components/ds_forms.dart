import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../motion/ds_motion_widgets.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_tokens.dart';
import '../tokens/ds_typography.dart';
import 'ds_surfaces.dart';

/// The DS input look as a plain [InputDecoration] – use it to style any
/// field you cannot replace (pickers, `DropdownButtonFormField`, third
/// party fields, `TextFormField` with special behaviour).
///
/// ```dart
/// TextFormField(controller: c.nameController, decoration: DsInputDecoration.of(context, hint: 'Name'.tr, prefixIcon: Icons.person_outline))
/// ```
abstract final class DsInputDecoration {
  static InputDecoration of(
    BuildContext context, {
    String? hint,
    String? helper,
    String? error,
    IconData? prefixIcon,
    Widget? prefix,
    Widget? suffix,
    String? counterText,
    bool enabled = true,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final c = DsColors.of(context);
    OutlineInputBorder b(Color color, [double w = 1]) => OutlineInputBorder(borderRadius: DsRadius.brMd, borderSide: BorderSide(color: color, width: w));
    return InputDecoration(
      hintText: hint,
      helperText: helper,
      errorText: error,
      counterText: counterText,
      enabled: enabled,
      filled: true,
      isDense: false,
      fillColor: enabled ? c.surfaceAlt : Color.alphaBlend(c.surfaceAlt.withValues(alpha: 0.5), c.surface),
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: 14),
      hintStyle: DsTypography.body.copyWith(color: c.textMuted),
      helperStyle: DsTypography.caption.copyWith(color: c.textMuted),
      errorStyle: DsTypography.caption.copyWith(color: c.danger),
      errorMaxLines: 3,
      prefixIcon: prefix ?? (prefixIcon != null ? Icon(prefixIcon, size: 20) : null),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      prefixIconColor: c.textMuted,
      suffixIconColor: c.textMuted,
      border: b(c.surfaceAlt),
      enabledBorder: b(c.isDark ? c.border : c.surfaceAlt),
      disabledBorder: b(Colors.transparent),
      focusedBorder: b(c.brand, 1.6),
      errorBorder: b(c.danger),
      focusedErrorBorder: b(c.danger, 1.6),
    );
  }
}

/// Field label with optional required marker and trailing hint.
class DsFieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  final Widget? trailing;
  const DsFieldLabel(this.text, {super.key, this.required = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: Row(
        children: [
          Flexible(
            child: Text.rich(
              TextSpan(
                text: text,
                children: [if (required) TextSpan(text: ' *', style: TextStyle(color: c.danger))],
              ),
              style: DsTypography.labelSm.copyWith(color: c.textSecondary, fontSize: 13),
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

/// Labelled text field with the DS look. Thin wrapper around
/// [TextFormField] – every behavioural parameter is passed through
/// unchanged, so you can swap it in for existing fields.
///
/// ```dart
/// DsTextField(label: 'Email'.tr, hint: 'you@store.com', controller: c.emailController, keyboardType: TextInputType.emailAddress, prefixIcon: Icons.mail_outline)
/// DsTextField(label: 'Password'.tr, controller: c.passwordController, obscurable: true)
/// ```
class DsTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final bool requiredMark;
  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final IconData? prefixIcon;
  final Widget? prefix;
  final Widget? suffix;

  /// Adds an eye toggle and starts obscured (passwords).
  final bool obscurable;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final bool autofocus;

  /// Bottom spacing after the field (so forms can be a simple Column).
  final double bottomSpacing;

  const DsTextField({
    super.key,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.requiredMark = false,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.prefixIcon,
    this.prefix,
    this.suffix,
    this.obscurable = false,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.validator,
    this.autofocus = false,
    this.bottomSpacing = DsSpace.lg,
  });

  @override
  State<DsTextField> createState() => _DsTextFieldState();
}

class _DsTextFieldState extends State<DsTextField> {
  late bool _obscured = widget.obscurable || widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    Widget? suffix = widget.suffix;
    if (widget.obscurable) {
      suffix = IconButton(
        tooltip: _obscured ? 'Show password'.tr : 'Hide password'.tr,
        icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
        onPressed: () => setState(() => _obscured = !_obscured),
      );
    }
    final field = TextFormField(
      controller: widget.controller,
      initialValue: widget.controller == null ? widget.initialValue : null,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: _obscured,
      obscuringCharacter: '●',
      maxLines: _obscured ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      validator: widget.validator,
      autofocus: widget.autofocus,
      cursorColor: c.brand,
      style: DsTypography.bodyStrong.copyWith(color: widget.enabled ? c.textPrimary : c.textSecondary),
      decoration: DsInputDecoration.of(
        context,
        hint: widget.hint,
        helper: widget.helper,
        error: widget.errorText,
        prefixIcon: widget.prefixIcon,
        prefix: widget.prefix,
        suffix: suffix,
        enabled: widget.enabled,
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) DsFieldLabel(widget.label!, required: widget.requiredMark),
          field,
        ],
      ),
    );
  }
}

/// Labelled dropdown with the DS input look.
///
/// ```dart
/// DsDropdown<String>(
///   label: 'Category'.tr,
///   value: c.selectedCategory.value,
///   items: c.categories.map((e) => DropdownMenuItem(value: e.id, child: Text(e.title ?? ''))).toList(),
///   onChanged: (v) => c.selectedCategory.value = v,
/// )
/// ```
class DsDropdown<T> extends StatelessWidget {
  final String? label;
  final String? hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final IconData? prefixIcon;
  final bool requiredMark;
  final bool isExpanded;
  final double bottomSpacing;

  const DsDropdown({
    super.key,
    this.label,
    this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.prefixIcon,
    this.requiredMark = false,
    this.isExpanded = true,
    this.bottomSpacing = DsSpace.lg,
  });

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) DsFieldLabel(label!, required: requiredMark),
          DropdownButtonFormField<T>(
            // Re-key so an externally changed value is reflected.
            key: ValueKey<T?>(value),
            initialValue: value,
            items: items,
            onChanged: onChanged,
            validator: validator,
            isExpanded: isExpanded,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
            borderRadius: DsRadius.brMd,
            dropdownColor: c.surfaceRaised,
            style: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
            decoration: DsInputDecoration.of(context, hint: hint, prefixIcon: prefixIcon, enabled: onChanged != null),
          ),
        ],
      ),
    );
  }
}

/// Form section: titled group of fields in a card (sectioned forms and
/// wizard steps).
///
/// ```dart
/// DsFormSection(title: 'Basic info'.tr, icon: Icons.storefront_outlined, children: [DsTextField(...), DsTextField(...)])
/// ```
class DsFormSection extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;
  final Widget? trailing;

  /// Render without the card surface (just header + fields).
  final bool plain;
  final EdgeInsetsGeometry? margin;

  const DsFormSection({super.key, this.title, this.subtitle, this.icon, required this.children, this.trailing, this.plain = false, this.margin});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final header = title == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.lg),
            child: Row(
              children: [
                if (icon != null) ...[DsIconWell(icon: icon, size: 36), const DsGap(DsSpace.md)],
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title!, style: DsTypography.titleSm.copyWith(color: c.textPrimary)),
                        if (subtitle != null) Text(subtitle!, style: DsTypography.bodySm.copyWith(color: c.textSecondary)),
                      ],
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          );
    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [?header, ...children]);
    final m = margin ?? const EdgeInsets.only(bottom: DsSpace.lg);
    if (plain) return Padding(padding: m, child: body);
    return DsCard.outlined(margin: m, padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xs), child: body);
  }
}

/// Rounded search field with clear button.
///
/// ```dart
/// DsSearchBar(hint: 'Search products'.tr, onChanged: c.search, trailing: DsIconButton(icon: Icons.tune, semanticLabel: 'Filters'.tr, onPressed: ...))
/// ```
class DsSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;
  final Widget? trailing;

  /// When set the bar is read-only and acts as a button (e.g. opens a search page).
  final VoidCallback? onTap;

  const DsSearchBar({super.key, this.controller, this.hint, this.onChanged, this.onSubmitted, this.onClear, this.autofocus = false, this.trailing, this.onTap});

  @override
  State<DsSearchBar> createState() => _DsSearchBarState();
}

class _DsSearchBarState extends State<DsSearchBar> {
  TextEditingController? _own;
  TextEditingController get _ctrl => widget.controller ?? (_own ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onText);
  }

  @override
  void didUpdateWidget(covariant DsSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _own)?.removeListener(_onText);
      _ctrl.addListener(_onText);
    }
  }

  void _onText() => setState(() {});

  @override
  void dispose() {
    _ctrl.removeListener(_onText);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final field = TextField(
      controller: _ctrl,
      autofocus: widget.autofocus,
      readOnly: widget.onTap != null,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textInputAction: TextInputAction.search,
      cursorColor: c.brand,
      style: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
      decoration: DsInputDecoration.of(
        context,
        hint: widget.hint ?? 'Search'.tr,
        prefixIcon: Icons.search_rounded,
        contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: 12),
        suffix: _ctrl.text.isEmpty || widget.onTap != null
            ? null
            : IconButton(
                tooltip: 'Clear'.tr,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _ctrl.clear();
                  widget.onChanged?.call('');
                  widget.onClear?.call();
                },
              ),
      ).copyWith(border: OutlineInputBorder(borderRadius: DsRadius.brPill, borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: DsRadius.brPill, borderSide: BorderSide(color: c.isDark ? c.border : Colors.transparent)), focusedBorder: OutlineInputBorder(borderRadius: DsRadius.brPill, borderSide: BorderSide(color: c.brand, width: 1.4))),
    );
    if (widget.trailing == null) return field;
    return Row(children: [Expanded(child: field), const DsGap(DsSpace.sm), widget.trailing!]);
  }
}

/// A segment for [DsSegmentedTabs].
class DsSegment {
  final String label;
  final IconData? icon;

  /// Optional count shown as a small pill.
  final int? count;
  const DsSegment(this.label, {this.icon, this.count});
}

/// Pill-style segmented control with a sliding thumb. Controlled: pass the
/// selected [index] and update it in [onChanged] (e.g. an Rx int).
///
/// ```dart
/// Obx(() => DsSegmentedTabs(
///   segments: [DsSegment('New'.tr, count: c.newOrders.length), DsSegment('Accepted'.tr), DsSegment('Completed'.tr)],
///   index: c.selectedTab.value,
///   onChanged: (i) => c.selectedTab.value = i,
/// ))
/// ```
class DsSegmentedTabs extends StatelessWidget {
  final List<DsSegment> segments;
  final int index;
  final ValueChanged<int> onChanged;

  /// Scroll horizontally instead of splitting the width equally (many tabs).
  final bool scrollable;

  const DsSegmentedTabs({super.key, required this.segments, required this.index, required this.onChanged, this.scrollable = false});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < segments.length; i++)
              Padding(
                padding: EdgeInsetsDirectional.only(end: i == segments.length - 1 ? 0 : DsSpace.sm),
                child: _ChipSegment(segment: segments[i], selected: i == index, onTap: () => onChanged(i)),
              ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brPill),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth / segments.length;
          final rtl = Directionality.of(context) == TextDirection.rtl;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: DsMotion.of(context, DsMotion.base),
                curve: DsMotion.emphasized,
                top: 0,
                bottom: 0,
                left: rtl ? null : w * index,
                right: rtl ? w * index : null,
                width: w,
                child: Container(
                  decoration: BoxDecoration(color: c.surface, borderRadius: DsRadius.brPill, boxShadow: DsShadows.sm(context)),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < segments.length; i++)
                    Expanded(child: _PillSegment(segment: segments[i], selected: i == index, onTap: () => onChanged(i))),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PillSegment extends StatelessWidget {
  final DsSegment segment;
  final bool selected;
  final VoidCallback onTap;
  const _PillSegment({required this.segment, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final fg = selected ? c.textPrimary : c.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: DsRadius.brPill,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (segment.icon != null) ...[Icon(segment.icon, size: 16, color: fg), const DsGap(6)],
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: DsMotion.of(context, DsMotion.fast),
                    style: DsTypography.label.copyWith(color: fg, fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
                    child: Text(segment.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                if (segment.count != null) ...[const DsGap(6), _Count(count: segment.count!, selected: selected)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipSegment extends StatelessWidget {
  final DsSegment segment;
  final bool selected;
  final VoidCallback onTap;
  const _ChipSegment({required this.segment, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final fg = selected ? c.onBrand : c.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      child: DsPressable(
        child: AnimatedContainer(
          duration: DsMotion.of(context, DsMotion.base),
          curve: DsMotion.standard,
          decoration: BoxDecoration(
            color: selected ? c.brand : c.surface,
            borderRadius: DsRadius.brPill,
            border: Border.all(color: selected ? c.brand : c.border),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: DsRadius.brPill,
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (segment.icon != null) ...[Icon(segment.icon, size: 16, color: fg), const DsGap(6)],
                      Text(segment.label, style: DsTypography.label.copyWith(color: fg, fontSize: 13)),
                      if (segment.count != null) ...[const DsGap(6), _Count(count: segment.count!, selected: selected, onBrand: true)],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final int count;
  final bool selected;
  final bool onBrand;
  const _Count({required this.count, required this.selected, this.onBrand = false});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final bg = selected ? (onBrand ? Colors.white.withValues(alpha: 0.24) : c.brand) : c.border;
    final fg = selected ? (onBrand ? c.onBrand : c.onBrand) : c.textSecondary;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: DsRadius.brPill),
      child: Text(count > 99 ? '99+' : '$count', textAlign: TextAlign.center, style: DsTypography.labelSm.copyWith(color: fg, fontSize: 11)),
    );
  }
}

/// Material [TabBar] styled as a DS pill switcher – use when the screen
/// already drives tabs with a `TabController` / `DefaultTabController`.
///
/// ```dart
/// appBar: DsAppBar(title: 'Orders'.tr, bottom: DsTabBar(controller: c.tabController, tabs: ['New'.tr, 'Completed'.tr]))
/// ```
class DsTabBar extends StatelessWidget implements PreferredSizeWidget {
  final List<String> tabs;
  final TabController? controller;
  final ValueChanged<int>? onTap;
  final bool scrollable;

  const DsTabBar({super.key, required this.tabs, this.controller, this.onTap, this.scrollable = false});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.xs, DsSpace.lg, DsSpace.sm),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brPill),
        child: TabBar(
          controller: controller,
          onTap: onTap,
          isScrollable: scrollable,
          tabAlignment: scrollable ? TabAlignment.start : TabAlignment.fill,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(color: c.surface, borderRadius: DsRadius.brPill, boxShadow: DsShadows.sm(context)),
          labelColor: c.textPrimary,
          unselectedLabelColor: c.textSecondary,
          labelStyle: DsTypography.label.copyWith(fontSize: 13),
          unselectedLabelStyle: DsTypography.label.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
          splashBorderRadius: DsRadius.brPill,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          tabs: [for (final t in tabs) Tab(text: t, height: 40)],
        ),
      ),
    );
  }
}

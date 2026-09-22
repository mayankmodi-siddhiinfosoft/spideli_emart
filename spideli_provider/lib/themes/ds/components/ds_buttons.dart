import 'package:flutter/material.dart';

import '../loading/ds_loaders.dart';
import '../motion/ds_motion_widgets.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_tokens.dart';
import '../tokens/ds_typography.dart';

enum DsButtonVariant {
  /// Solid brand fill. One per screen area (the main action).
  primary,

  /// Outlined, neutral. Secondary actions next to a primary.
  secondary,

  /// Soft brand tint. Frequent, non-dominant actions.
  tonal,

  /// Text-only. Tertiary actions, "See all", "Skip".
  ghost,

  /// Solid danger fill. Destructive confirmations.
  danger,

  /// Soft danger tint. Destructive but not final ("Remove", "Reject").
  dangerTonal,
}

enum DsButtonSize {
  /// 40 visual / 48 hit target.
  sm,

  /// 48 – default.
  md,

  /// 56 – hero CTAs and sticky submit bars.
  lg,
}

/// The one button of the design system.
///
/// * `onPressed: null` → disabled look.
/// * `loading: true` → spinner, keeps width, ignores taps.
/// * `expand: true` → full width.
///
/// ```dart
/// DsButton.primary(label: 'Save'.tr, icon: Icons.check_rounded, expand: true, loading: c.isSaving.value, onPressed: c.save)
/// DsButton.secondary(label: 'Cancel'.tr, onPressed: () => Get.back())
/// DsButton.danger(label: 'Delete'.tr, icon: Icons.delete_outline, onPressed: ...)
/// DsButton.ghost(label: 'See all'.tr, trailingIcon: Icons.chevron_right, size: DsButtonSize.sm, onPressed: ...)
/// ```
class DsButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final DsButtonVariant variant;
  final DsButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;

  /// Custom leading widget (e.g. an SvgPicture) – overrides [icon].
  final Widget? leading;
  final bool loading;
  final bool expand;

  /// Override the fill color of primary/tonal variants (rare – e.g. success).
  final Color? color;
  final String? semanticLabel;

  const DsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DsButtonVariant.primary,
    this.size = DsButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.leading,
    this.loading = false,
    this.expand = false,
    this.color,
    this.semanticLabel,
  });

  const DsButton.primary({super.key, required this.label, required this.onPressed, this.size = DsButtonSize.md, this.icon, this.trailingIcon, this.leading, this.loading = false, this.expand = false, this.color, this.semanticLabel})
    : variant = DsButtonVariant.primary;

  const DsButton.secondary({super.key, required this.label, required this.onPressed, this.size = DsButtonSize.md, this.icon, this.trailingIcon, this.leading, this.loading = false, this.expand = false, this.color, this.semanticLabel})
    : variant = DsButtonVariant.secondary;

  const DsButton.tonal({super.key, required this.label, required this.onPressed, this.size = DsButtonSize.md, this.icon, this.trailingIcon, this.leading, this.loading = false, this.expand = false, this.color, this.semanticLabel})
    : variant = DsButtonVariant.tonal;

  const DsButton.ghost({super.key, required this.label, required this.onPressed, this.size = DsButtonSize.md, this.icon, this.trailingIcon, this.leading, this.loading = false, this.expand = false, this.color, this.semanticLabel})
    : variant = DsButtonVariant.ghost;

  const DsButton.danger({super.key, required this.label, required this.onPressed, this.size = DsButtonSize.md, this.icon, this.trailingIcon, this.leading, this.loading = false, this.expand = false, this.color, this.semanticLabel})
    : variant = DsButtonVariant.danger;

  const DsButton.dangerTonal({super.key, required this.label, required this.onPressed, this.size = DsButtonSize.md, this.icon, this.trailingIcon, this.leading, this.loading = false, this.expand = false, this.color, this.semanticLabel})
    : variant = DsButtonVariant.dangerTonal;

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final enabled = onPressed != null && !loading;
    final disabledLook = onPressed == null;

    late Color bg;
    late Color fg;
    BorderSide side = BorderSide.none;
    switch (variant) {
      case DsButtonVariant.primary:
        bg = color ?? c.brand;
        fg = color != null ? (color!.computeLuminance() > 0.6 ? Colors.black : Colors.white) : c.onBrand;
      case DsButtonVariant.secondary:
        bg = c.surface;
        fg = color ?? c.textPrimary;
        side = BorderSide(color: c.borderStrong);
      case DsButtonVariant.tonal:
        bg = color != null ? Color.alphaBlend(color!.withValues(alpha: 0.12), c.surface) : c.brandSoft;
        fg = color ?? c.brandStrong;
      case DsButtonVariant.ghost:
        bg = Colors.transparent;
        fg = color ?? c.brandStrong;
      case DsButtonVariant.danger:
        bg = c.tone(DsTone.danger).main;
        fg = Colors.white;
      case DsButtonVariant.dangerTonal:
        bg = c.dangerSoft;
        fg = c.dangerStrong;
    }
    if (disabledLook) {
      bg = variant == DsButtonVariant.ghost ? Colors.transparent : c.surfaceAlt;
      fg = c.textDisabled;
      side = side == BorderSide.none ? side : BorderSide(color: c.border);
    }

    final double height = switch (size) {
      DsButtonSize.sm => 40,
      DsButtonSize.md => 48,
      DsButtonSize.lg => 56,
    };
    final double hPad = switch (size) {
      DsButtonSize.sm => DsSpace.md,
      DsButtonSize.md => DsSpace.xl,
      DsButtonSize.lg => DsSpace.xxl,
    };
    final double iconSize = size == DsButtonSize.sm ? 18 : 20;
    final textStyle = (size == DsButtonSize.sm ? DsTypography.label.copyWith(fontSize: 13) : DsTypography.label.copyWith(fontSize: size == DsButtonSize.lg ? 16 : 15)).copyWith(color: fg);

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[IconTheme(data: IconThemeData(color: fg, size: iconSize), child: leading!), const DsGap(DsSpace.sm)]
        else if (icon != null) ...[Icon(icon, size: iconSize, color: fg), const DsGap(DsSpace.sm)],
        Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: textStyle)),
        if (trailingIcon != null) ...[const DsGap(DsSpace.sm), Icon(trailingIcon, size: iconSize, color: fg)],
      ],
    );

    final radius = BorderRadius.circular(size == DsButtonSize.lg ? DsRadius.lg : DsRadius.md);
    Widget button = Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: radius, side: side),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled
            ? () {
                FocusManager.instance.primaryFocus?.unfocus();
                onPressed!();
              }
            : null,
        splashColor: fg.withValues(alpha: 0.12),
        highlightColor: fg.withValues(alpha: 0.06),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height, minWidth: height),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: DsSpace.sm),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedOpacity(opacity: loading ? 0 : 1, duration: DsMotion.of(context, DsMotion.fast), child: content),
                if (loading) DsSpinner(size: iconSize, color: fg),
              ],
            ),
          ),
        ),
      ),
    );

    if (variant == DsButtonVariant.primary && !disabledLook) {
      button = DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: DsShadows.glow(context, color: bg).take(1).toList()),
        child: button,
      );
    }

    button = DsPressable(enabled: enabled, child: button);
    if (expand) button = SizedBox(width: double.infinity, child: button);
    if (size == DsButtonSize.sm) {
      // Keep a 48dp touch target without growing the visual.
      button = ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: Center(widthFactor: 1, heightFactor: 1, child: button));
    }
    return Semantics(button: true, enabled: enabled, label: semanticLabel, excludeSemantics: semanticLabel != null, child: button);
  }
}

enum DsIconButtonVariant {
  /// Transparent background.
  plain,

  /// Soft neutral circle (app bars on content).
  tonal,

  /// Soft brand circle.
  brand,

  /// Outlined circle.
  outlined,

  /// Solid brand circle.
  filled,
}

/// Icon-only button with a guaranteed 48dp touch target, tooltip and
/// screen-reader label.
///
/// ```dart
/// DsIconButton(icon: Icons.tune_rounded, semanticLabel: 'Filters'.tr, onPressed: openFilters)
/// DsIconButton(icon: Icons.notifications_none_rounded, semanticLabel: 'Notifications'.tr, badgeCount: 3, onPressed: ...)
/// ```
class DsIconButton extends StatelessWidget {
  final IconData? icon;

  /// Custom icon widget (e.g. SvgPicture) – overrides [icon].
  final Widget? child;
  final VoidCallback? onPressed;

  /// Required for accessibility – read by screen readers and shown as tooltip.
  final String semanticLabel;
  final DsIconButtonVariant variant;

  /// Visual diameter (the hit target is always at least 48).
  final double size;
  final Color? color;

  /// Shows a badge: 0 → hidden, >0 → count ("9+" above 9). Use [showDot] for
  /// a plain dot.
  final int badgeCount;
  final bool showDot;

  const DsIconButton({
    super.key,
    this.icon,
    this.child,
    required this.onPressed,
    required this.semanticLabel,
    this.variant = DsIconButtonVariant.plain,
    this.size = 40,
    this.color,
    this.badgeCount = 0,
    this.showDot = false,
  }) : assert(icon != null || child != null);

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    late Color bg;
    late Color fg;
    BorderSide side = BorderSide.none;
    switch (variant) {
      case DsIconButtonVariant.plain:
        bg = Colors.transparent;
        fg = color ?? c.textPrimary;
      case DsIconButtonVariant.tonal:
        bg = c.surfaceAlt;
        fg = color ?? c.textPrimary;
      case DsIconButtonVariant.brand:
        bg = c.brandSoft;
        fg = color ?? c.brandStrong;
      case DsIconButtonVariant.outlined:
        bg = c.surface;
        fg = color ?? c.textPrimary;
        side = BorderSide(color: c.border);
      case DsIconButtonVariant.filled:
        bg = color ?? c.brand;
        fg = c.onBrand;
    }
    if (onPressed == null) fg = c.textDisabled;

    Widget iconW = child != null ? IconTheme(data: IconThemeData(color: fg, size: size * 0.55), child: child!) : Icon(icon, color: fg, size: size * 0.55);
    if (badgeCount > 0 || showDot) {
      iconW = Badge(
        isLabelVisible: true,
        backgroundColor: c.danger,
        smallSize: 8,
        label: badgeCount > 0 ? Text(badgeCount > 9 ? '9+' : '$badgeCount') : null,
        child: iconW,
      );
    }

    return Tooltip(
      message: semanticLabel,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: semanticLabel,
        child: SizedBox.square(
          dimension: size < 48 ? 48 : size,
          child: Center(
            child: DsPressable(
              enabled: onPressed != null,
              pressedScale: 0.92,
              child: Material(
                color: bg,
                shape: CircleBorder(side: side),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  child: SizedBox.square(dimension: size, child: Center(child: iconW)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

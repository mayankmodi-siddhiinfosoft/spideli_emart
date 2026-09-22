import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../motion/ds_motion_widgets.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_tokens.dart';
import '../tokens/ds_typography.dart';

enum DsCardVariant {
  /// Surface + soft layered shadow (+ hairline border in dark mode).
  elevated,

  /// Surface + 1px border, no shadow. Dense lists, forms.
  outlined,

  /// Soft tone-tinted background ([DsCard.tone]). Highlights, tips.
  tinted,

  /// Brand (or custom) gradient with white content. Heroes, balances.
  gradient,

  /// Frosted translucent surface. Only on top of imagery / gradients.
  glass,
}

/// The base container of the design system.
///
/// ```dart
/// DsCard(child: ...)                                   // elevated
/// DsCard.outlined(onTap: open, child: ...)
/// DsCard.tinted(tone: DsTone.warning, child: ...)
/// DsCard.gradient(child: ...)                          // text should be white
/// ```
class DsCard extends StatelessWidget {
  final Widget child;
  final DsCardVariant variant;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;

  /// Tone for [DsCardVariant.tinted].
  final DsTone tone;

  /// Custom gradient for [DsCardVariant.gradient] (defaults to brand).
  final Gradient? gradient;

  /// Override background color (rare).
  final Color? color;

  /// Accent border color (e.g. brand when selected).
  final Color? borderColor;
  final String? semanticLabel;
  final Clip clipBehavior;

  const DsCard({
    super.key,
    required this.child,
    this.variant = DsCardVariant.elevated,
    this.padding = const EdgeInsets.all(DsSpace.lg),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.radius = DsRadius.lg,
    this.tone = DsTone.brand,
    this.gradient,
    this.color,
    this.borderColor,
    this.semanticLabel,
    this.clipBehavior = Clip.antiAlias,
  });

  const DsCard.outlined({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DsSpace.lg),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.radius = DsRadius.lg,
    this.color,
    this.borderColor,
    this.semanticLabel,
    this.clipBehavior = Clip.antiAlias,
  }) : variant = DsCardVariant.outlined,
       tone = DsTone.neutral,
       gradient = null;

  const DsCard.tinted({
    super.key,
    required this.child,
    this.tone = DsTone.brand,
    this.padding = const EdgeInsets.all(DsSpace.lg),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.radius = DsRadius.lg,
    this.borderColor,
    this.semanticLabel,
    this.clipBehavior = Clip.antiAlias,
  }) : variant = DsCardVariant.tinted,
       gradient = null,
       color = null;

  const DsCard.gradient({
    super.key,
    required this.child,
    this.gradient,
    this.padding = const EdgeInsets.all(DsSpace.xl),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.radius = DsRadius.xl,
    this.semanticLabel,
    this.clipBehavior = Clip.antiAlias,
  }) : variant = DsCardVariant.gradient,
       tone = DsTone.brand,
       color = null,
       borderColor = null;

  const DsCard.glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DsSpace.lg),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.radius = DsRadius.lg,
    this.semanticLabel,
    this.clipBehavior = Clip.antiAlias,
  }) : variant = DsCardVariant.glass,
       tone = DsTone.brand,
       gradient = null,
       color = null,
       borderColor = null;

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final br = BorderRadius.circular(radius);
    BoxDecoration deco;
    switch (variant) {
      case DsCardVariant.elevated:
        deco = BoxDecoration(
          color: color ?? c.surface,
          borderRadius: br,
          boxShadow: DsShadows.sm(context),
          border: borderColor != null ? Border.all(color: borderColor!, width: 1.4) : (c.isDark ? Border.all(color: c.border) : null),
        );
      case DsCardVariant.outlined:
        deco = BoxDecoration(color: color ?? c.surface, borderRadius: br, border: Border.all(color: borderColor ?? c.border, width: borderColor != null ? 1.4 : 1));
      case DsCardVariant.tinted:
        final t = c.tone(tone);
        deco = BoxDecoration(color: t.soft, borderRadius: br, border: borderColor != null ? Border.all(color: borderColor!) : null);
      case DsCardVariant.gradient:
        deco = BoxDecoration(gradient: gradient ?? DsGradients.brand(context), borderRadius: br, boxShadow: DsShadows.glow(context));
      case DsCardVariant.glass:
        deco = BoxDecoration(
          color: (c.isDark ? Colors.black : Colors.white).withValues(alpha: c.isDark ? 0.28 : 0.18),
          borderRadius: br,
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        );
    }

    Widget content = Padding(padding: padding, child: child);
    if (variant == DsCardVariant.gradient || variant == DsCardVariant.glass) {
      content = DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: IconTheme.merge(data: const IconThemeData(color: Colors.white), child: content),
      );
    }

    Widget card;
    if (onTap != null || onLongPress != null) {
      card = DsPressable(
        pressedScale: 0.985,
        child: Container(
          decoration: deco,
          child: Material(
            type: MaterialType.transparency,
            borderRadius: br,
            clipBehavior: clipBehavior,
            child: InkWell(onTap: onTap, onLongPress: onLongPress, borderRadius: br, child: content),
          ),
        ),
      );
    } else {
      card = Container(decoration: deco, clipBehavior: clipBehavior, child: content);
    }

    if (variant == DsCardVariant.glass) {
      card = ClipRRect(borderRadius: br, child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: card));
    }
    if (semanticLabel != null) card = Semantics(container: true, label: semanticLabel, button: onTap != null, child: card);
    if (margin != null) card = Padding(padding: margin!, child: card);
    return card;
  }
}

/// Rounded, tone-tinted icon container ("icon well"). Used by tiles, list
/// rows, empty states.
///
/// ```dart
/// DsIconWell(icon: Icons.shopping_bag_outlined, tone: DsTone.info)
/// ```
class DsIconWell extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final DsTone tone;
  final double size;
  final bool circle;

  /// Use on gradient/brand surfaces: white translucent well + white icon.
  final bool onBrand;

  const DsIconWell({super.key, this.icon, this.child, this.tone = DsTone.brand, this.size = 44, this.circle = false, this.onBrand = false});

  @override
  Widget build(BuildContext context) {
    final t = DsColors.of(context).tone(tone);
    final fg = onBrand ? Colors.white : t.strong;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onBrand ? Colors.white.withValues(alpha: 0.18) : t.soft,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.3),
      ),
      child: IconTheme(
        data: IconThemeData(color: fg, size: size * 0.5),
        child: child ?? Icon(icon),
      ),
    );
  }
}

enum DsStatTileVariant {
  /// Elevated surface card.
  surface,

  /// Tone-tinted card.
  tinted,

  /// For use on a gradient hero (white text, glass background).
  onBrand,
}

/// KPI tile: icon + label + big value (+ optional delta / caption).
///
/// Pass [countTo] to animate the number (DsAnimatedCounter) and [format] to
/// render it (currency etc.). Otherwise [value] is shown as-is.
///
/// ```dart
/// DsStatTile(icon: Icons.receipt_long_rounded, label: 'Total orders'.tr, value: '${c.totalOrder.value}', tone: DsTone.info)
/// DsStatTile(label: 'Earnings'.tr, countTo: earnings, format: (v) => Constant.amountShow(amount: '$v'), delta: '+12%', deltaPositive: true)
/// ```
class DsStatTile extends StatelessWidget {
  final String label;
  final String? value;
  final num? countTo;
  final String Function(num value)? format;
  final IconData? icon;
  final Widget? iconWidget;
  final DsTone tone;
  final DsStatTileVariant variant;
  final String? caption;
  final String? delta;
  final bool? deltaPositive;
  final VoidCallback? onTap;

  const DsStatTile({
    super.key,
    required this.label,
    this.value,
    this.countTo,
    this.format,
    this.icon,
    this.iconWidget,
    this.tone = DsTone.brand,
    this.variant = DsStatTileVariant.surface,
    this.caption,
    this.delta,
    this.deltaPositive,
    this.onTap,
  }) : assert(value != null || countTo != null);

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final onBrand = variant == DsStatTileVariant.onBrand;
    final primary = onBrand ? Colors.white : c.textPrimary;
    final secondary = onBrand ? Colors.white.withValues(alpha: 0.82) : c.textSecondary;
    final valueStyle = DsTypography.metric.copyWith(color: primary, fontSize: 24);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null || iconWidget != null) ...[
              DsIconWell(icon: icon, tone: tone, size: 36, onBrand: onBrand, child: iconWidget),
              const DsGap(DsSpace.sm),
            ],
            Expanded(
              child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: DsTypography.labelSm.copyWith(color: secondary)),
            ),
          ],
        ),
        const DsGap(DsSpace.md),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: countTo != null ? DsAnimatedCounter(value: countTo!, format: format, style: valueStyle) : Text(value!, style: valueStyle, maxLines: 1),
        ),
        if (delta != null || caption != null) ...[
          const DsGap(DsSpace.xs),
          Row(
            children: [
              if (delta != null) ...[
                _Delta(text: delta!, positive: deltaPositive, onBrand: onBrand),
                const DsGap(DsSpace.xs),
              ],
              if (caption != null)
                Expanded(child: Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsTypography.caption.copyWith(color: secondary))),
            ],
          ),
        ],
      ],
    );

    return switch (variant) {
      DsStatTileVariant.surface => DsCard(onTap: onTap, padding: const EdgeInsets.all(DsSpace.lg), child: body),
      DsStatTileVariant.tinted => DsCard.tinted(tone: tone, onTap: onTap, padding: const EdgeInsets.all(DsSpace.lg), child: body),
      DsStatTileVariant.onBrand => DsCard.glass(onTap: onTap, padding: const EdgeInsets.all(DsSpace.md), child: body),
    };
  }
}

class _Delta extends StatelessWidget {
  final String text;
  final bool? positive;
  final bool onBrand;
  const _Delta({required this.text, required this.positive, required this.onBrand});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final tone = positive == null ? DsTone.neutral : (positive! ? DsTone.success : DsTone.danger);
    final t = c.tone(tone);
    final fg = onBrand ? Colors.white : t.strong;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: onBrand ? Colors.white.withValues(alpha: 0.18) : t.soft, borderRadius: DsRadius.brPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (positive != null) Icon(positive! ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 12, color: fg),
          Text(text, style: DsTypography.labelSm.copyWith(color: fg, fontSize: 11)),
        ],
      ),
    );
  }
}

/// List row with leading icon / avatar, title, subtitle, trailing and chevron.
/// Minimum height 56 and grows with text scale.
///
/// ```dart
/// DsListTile(leadingIcon: Icons.person_outline, title: 'Profile'.tr, showChevron: true, onTap: ...)
/// DsListTile(leading: DsAvatar(name: user.fullName()), title: user.fullName(), subtitle: user.email, trailing: DsStatusChip(...))
/// ```
class DsListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final IconData? leadingIcon;
  final DsTone leadingTone;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  /// Red title/icon for destructive rows (Logout, Delete account).
  final bool destructive;
  final EdgeInsetsGeometry padding;
  final int subtitleMaxLines;

  const DsListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.leadingIcon,
    this.leadingTone = DsTone.neutral,
    this.trailing,
    this.showChevron = false,
    this.onTap,
    this.destructive = false,
    this.padding = const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
    this.subtitleMaxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final titleColor = destructive ? c.dangerStrong : c.textPrimary;
    Widget? lead = leading;
    if (lead == null && leadingIcon != null) {
      lead = DsIconWell(icon: leadingIcon, tone: destructive ? DsTone.danger : leadingTone, size: 40);
    }
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (lead != null) ...[lead, const DsGap(DsSpace.md)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: DsTypography.bodyStrong.copyWith(color: titleColor)),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const DsGap(DsSpace.xxs),
                    Text(subtitle!, maxLines: subtitleMaxLines, overflow: TextOverflow.ellipsis, style: DsTypography.bodySm.copyWith(color: c.textSecondary)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const DsGap(DsSpace.sm),
              // Cap the trailing width so long labels (translations, large
              // text scale) ellipsize instead of overflowing the row.
              ConstrainedBox(constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.42), child: trailing!),
            ],
            if (showChevron) ...[
              const DsGap(DsSpace.xs),
              Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: c.textMuted),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Material(type: MaterialType.transparency, child: InkWell(onTap: onTap, child: row));
  }
}

/// Grouped settings-style list: optional header + tiles in one card with
/// inset dividers.
///
/// ```dart
/// DsTileGroup(title: 'Account'.tr, children: [DsListTile(...), DsListTile(...)])
/// ```
class DsTileGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  /// Left inset of dividers (aligns with text after a 40px leading).
  final double dividerIndent;

  const DsTileGroup({super.key, this.title, required this.children, this.margin, this.dividerIndent = 68});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(Divider(height: 1, thickness: 1, indent: dividerIndent, color: c.divider));
      items.add(children[i]);
    }
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: DsSpace.xs, bottom: DsSpace.sm),
              child: Text(title!.toUpperCase(), style: DsTypography.overline.copyWith(color: c.textMuted)),
            ),
          DsCard(padding: EdgeInsets.zero, child: Column(children: items)),
        ],
      ),
    );
  }
}

/// Section title with optional subtitle, leading icon and trailing action.
///
/// ```dart
/// DsSectionHeader(title: 'Recent orders'.tr, actionLabel: 'See all'.tr, onAction: ...)
/// ```
class DsSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const DsSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.only(top: DsSpace.xl, bottom: DsSpace.md),
  });

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 20, color: c.brand), const DsGap(DsSpace.sm)],
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DsTypography.titleSm.copyWith(color: c.textPrimary)),
                  if (subtitle != null) ...[const DsGap(DsSpace.xxs), Text(subtitle!, style: DsTypography.bodySm.copyWith(color: c.textSecondary))],
                ],
              ),
            ),
          ),
          ?trailing,
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm), minimumSize: const Size(48, 40)),
              child: Text(actionLabel!, style: DsTypography.label.copyWith(color: c.brandStrong, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

/// Divider with optional centered label ("OR"). [vertical] for rows.
class DsDivider extends StatelessWidget {
  final String? label;
  final double indent;
  final double spacing;
  final bool vertical;

  const DsDivider({super.key, this.label, this.indent = 0, this.spacing = DsSpace.lg, this.vertical = false});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    if (vertical) return VerticalDivider(width: spacing, thickness: 1, color: c.divider, indent: indent, endIndent: indent);
    if (label == null) return Divider(height: spacing, thickness: 1, color: c.divider, indent: indent, endIndent: indent);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing / 2),
      child: Row(
        children: [
          Expanded(child: Divider(color: c.divider, thickness: 1, indent: indent)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: DsSpace.md), child: Text(label!, style: DsTypography.caption.copyWith(color: c.textMuted))),
          Expanded(child: Divider(color: c.divider, thickness: 1, endIndent: indent)),
        ],
      ),
    );
  }
}

enum DsBadgeStyle { soft, solid, outline }

/// Compact label (counts, tags, "NEW", "Veg").
///
/// ```dart
/// DsBadge(label: 'New'.tr, tone: DsTone.brand)
/// DsBadge(label: '3', tone: DsTone.danger, style: DsBadgeStyle.solid)
/// ```
class DsBadge extends StatelessWidget {
  final String label;
  final DsTone tone;
  final DsBadgeStyle style;
  final IconData? icon;
  final bool small;

  const DsBadge({super.key, required this.label, this.tone = DsTone.neutral, this.style = DsBadgeStyle.soft, this.icon, this.small = false});

  @override
  Widget build(BuildContext context) {
    final t = DsColors.of(context).tone(tone);
    final (bg, fg, border) = switch (style) {
      DsBadgeStyle.soft => (t.soft, t.strong, null),
      DsBadgeStyle.solid => (t.main, t.onMain, null),
      DsBadgeStyle.outline => (Colors.transparent, t.strong, t.main),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 10, vertical: small ? 2 : 4),
      decoration: BoxDecoration(color: bg, borderRadius: DsRadius.brPill, border: border != null ? Border.all(color: border) : null),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: small ? 12 : 14, color: fg), const DsGap(DsSpace.xs)],
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsTypography.labelSm.copyWith(color: fg, fontSize: small ? 11 : 12)),
          ),
        ],
      ),
    );
  }
}

/// Status pill with a colored dot. Tone is inferred from the status text
/// when not given (see [DsTone.fromStatus]). Set [pulse] for live states
/// ("Preparing", "Online").
///
/// ```dart
/// DsStatusChip(label: order.status!.tr, status: order.status)
/// DsStatusChip(label: 'Online'.tr, tone: DsTone.success, pulse: true)
/// ```
class DsStatusChip extends StatelessWidget {
  final String label;

  /// Raw status value used to infer the tone (ignored when [tone] is set).
  final String? status;
  final DsTone? tone;
  final bool pulse;

  const DsStatusChip({super.key, required this.label, this.status, this.tone, this.pulse = false});

  @override
  Widget build(BuildContext context) {
    final resolved = tone ?? DsTone.fromStatus(status ?? label);
    final t = DsColors.of(context).tone(resolved);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: t.soft, borderRadius: DsRadius.brPill),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(color: t.main, pulse: pulse),
            const DsGap(6),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsTypography.labelSm.copyWith(color: t.strong))),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const _Dot({required this.color, required this.pulse});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _Dot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final animate = widget.pulse && !DsMotion.reduced(context);
    if (animate && _c == null) {
      _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    } else if (!animate && _c != null) {
      _c!.dispose();
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(width: 7, height: 7, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle));
    if (_c == null) return dot;
    return SizedBox.square(
      dimension: 7,
      child: AnimatedBuilder(
        animation: _c!,
        builder: (_, _) => Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: 1 + _c!.value * 1.6,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: widget.color.withValues(alpha: (1 - _c!.value) * 0.5), shape: BoxShape.circle),
              ),
            ),
            dot,
          ],
        ),
      ),
    );
  }
}

/// Circular avatar: network image → initials fallback, optional ring,
/// status dot and hero tag.
///
/// ```dart
/// DsAvatar(imageUrl: user.profilePictureURL, name: user.fullName(), size: 48, statusTone: DsTone.success)
/// ```
class DsAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final bool ring;
  final DsTone? statusTone;
  final Object? heroTag;
  final VoidCallback? onTap;
  final IconData fallbackIcon;

  const DsAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 44,
    this.ring = false,
    this.statusTone,
    this.heroTag,
    this.onTap,
    this.fallbackIcon = Icons.person_rounded,
  });

  String get _initials {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    Widget fallback() => Container(
      color: c.brandSoft,
      alignment: Alignment.center,
      child: _initials.isEmpty
          ? Icon(fallbackIcon, color: c.brandStrong, size: size * 0.5)
          : Text(_initials, style: DsTypography.label.copyWith(color: c.brandStrong, fontSize: size * 0.36, height: 1)),
    );

    final hasUrl = imageUrl != null && imageUrl!.startsWith('http');
    Widget img = ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: hasUrl
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: c.shimmerBase),
                errorWidget: (_, _, _) => fallback(),
              )
            : fallback(),
      ),
    );
    if (heroTag != null) img = Hero(tag: heroTag!, child: img);
    if (ring) {
      img = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: DsGradients.brand(context)),
        child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, color: c.surface), child: img),
      );
    }
    if (statusTone != null) {
      final dot = size * 0.26;
      img = Stack(
        clipBehavior: Clip.none,
        children: [
          img,
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(color: c.tone(statusTone!).main, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
            ),
          ),
        ],
      );
    }
    img = Semantics(image: true, label: name, child: img);
    if (onTap != null) img = DsPressable(onTap: onTap, semanticLabel: name, child: img);
    return img;
  }
}

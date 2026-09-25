// Shared order-surface pieces used by every order screen of the Store app
// (the six order feeds, the order detail, its bill dialogs and the dine-in
// reservations), so the surfaces cannot drift apart.
//
// Presentation only: every widget here renders values it is given. Nothing
// computes, formats or re-derives an amount.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/themes/ds/ds.dart';

/// Order / booking identity: one heading, one value, never wrapped.
///
/// The short id is rendered at label size with tabular figures and stays on a
/// single line; the full id is available on tap-to-copy. The status chip sits
/// on the same row, aligned to the first line of the heading, and never wraps.
class OrderIdHeader extends StatelessWidget {
  /// Heading, e.g. `"Order".tr`. Never repeated inside [shortId].
  final String label;

  /// Short, display form of the id (e.g. `#1234567890`).
  final String shortId;

  /// Full id, copied to the clipboard when [copyable] is true.
  final String fullId;

  /// Status chip, aligned to the heading's first line.
  final Widget? statusChip;

  /// White treatment for gradient / brand surfaces.
  final bool onGradient;

  /// Tap-to-copy. Off on list cards, where the card tap opens the detail.
  final bool copyable;

  /// Toast shown after a copy.
  final String copiedMessage;

  const OrderIdHeader({
    super.key,
    required this.label,
    required this.shortId,
    required this.fullId,
    this.statusChip,
    this.onGradient = false,
    this.copyable = true,
    this.copiedMessage = 'Order ID Copied',
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final Color labelColor = onGradient ? Colors.white.withValues(alpha: 0.85) : c.textMuted;
    final Color idColor = onGradient ? Colors.white : c.textSecondary;

    final Widget identity = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.overline.withColor(labelColor)),
        const DsGap(DsSpace.xxs),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(shortId, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: t.label.tabular.withColor(idColor)),
            ),
            if (copyable) ...[DsGap.xs, Icon(Icons.copy_rounded, size: 14, color: idColor)],
          ],
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: copyable
              ? Semantics(
                  button: true,
                  label: label,
                  child: InkWell(
                    borderRadius: DsRadius.brSm,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: fullId));
                      ShowToastDialog.showToast(copiedMessage);
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(padding: const EdgeInsets.symmetric(vertical: DsSpace.xs), child: identity),
                    ),
                  ),
                )
              : Padding(padding: const EdgeInsets.symmetric(vertical: DsSpace.xs), child: identity),
        ),
        if (statusChip != null) ...[
          DsGap.sm,
          Flexible(child: Padding(padding: const EdgeInsets.only(top: DsSpace.xs), child: statusChip!)),
        ],
      ],
    );
  }
}

/// One bill / summary line: label left (muted, one step smaller than the
/// value), value right-aligned with tabular figures so every amount in a block
/// lines up in a column.
class OrderMoneyRow extends StatelessWidget {
  final String label;

  /// Already formatted by the caller. Ignored when [valueWidget] is given.
  final String? value;

  /// Custom trailing (a link, a button) instead of a plain amount.
  final Widget? valueWidget;

  final Color? valueColor;
  final Color? labelColor;
  final IconData? icon;

  /// Underlines the label (rows that open a bifurcation dialog).
  final bool underlineLabel;

  final EdgeInsetsGeometry padding;

  const OrderMoneyRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.valueColor,
    this.labelColor,
    this.icon,
    this.underlineLabel = false,
    this.padding = const EdgeInsets.symmetric(vertical: DsSpace.sm),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final Color resolvedLabel = labelColor ?? c.textSecondary;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: c.iconDefault), DsGap.sm],
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.bodySm.copyWith(
                color: resolvedLabel,
                decoration: underlineLabel ? TextDecoration.underline : TextDecoration.none,
                decorationColor: resolvedLabel,
              ),
            ),
          ),
          DsGap.md,
          valueWidget ??
              Flexible(
                child: Text(
                  value ?? '',
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyStrong.tabular.copyWith(color: valueColor ?? c.textPrimary),
                ),
              ),
        ],
      ),
    );
  }
}

/// The closing line of a money block: a hairline, then the label and the
/// amount one weight heavier, in the same family and only one step larger.
class OrderTotalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Color? background;
  final BorderRadiusGeometry? borderRadius;

  /// Hairline above the row.
  final bool divider;

  final EdgeInsetsGeometry padding;

  const OrderTotalRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.background,
    this.borderRadius,
    this.divider = true,
    this.padding = const EdgeInsets.all(DsSpace.md),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (divider)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
            child: Divider(height: 1, thickness: 1, color: c.divider),
          ),
        Container(
          padding: padding,
          decoration: background == null && borderRadius == null ? null : BoxDecoration(color: background, borderRadius: borderRadius),
          child: Row(
            children: [
              Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSm)),
              DsGap.md,
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.title.tabular.withColor(valueColor ?? c.brandStrong),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One ordered line: name at body weight (with an optional compact quantity
/// chip at the end of the name row), price aligned right, and the original
/// price struck through one step smaller and muted beside it.
class OrderItemRow extends StatelessWidget {
  final String name;

  /// Compact chip at the end of the name row, e.g. `×2`.
  final String? quantityLabel;

  /// Small muted line under the name (unit price × quantity, variants...).
  final String? meta;

  /// Already formatted by the caller.
  final String price;

  /// Already formatted by the caller; struck through, smaller and muted.
  final String? originalPrice;

  /// Extra content under the name (tags).
  final Widget? subtitle;

  /// Extra content under the price (a link).
  final Widget? trailing;

  const OrderItemRow({
    super.key,
    required this.name,
    required this.price,
    this.quantityLabel,
    this.meta,
    this.originalPrice,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyStrong)),
                  if (quantityLabel != null) ...[
                    DsGap.sm,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: 1),
                      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brPill, border: Border.all(color: c.border)),
                      child: Text(quantityLabel!, style: t.labelSm.tabular),
                    ),
                  ],
                ],
              ),
              if (meta != null)
                Padding(
                  padding: const EdgeInsets.only(top: DsSpace.xxs),
                  child: Text(meta!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.tabular),
                ),
              ?subtitle,
            ],
          ),
        ),
        DsGap.md,
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (originalPrice != null) ...[
                  Text(originalPrice!, maxLines: 1, style: t.caption.tabular.strike),
                  DsGap.xs,
                ],
                Text(price, maxLines: 1, textAlign: TextAlign.end, style: t.bodyStrong.tabular),
              ],
            ),
            ?trailing,
          ],
        ),
      ],
    );
  }
}

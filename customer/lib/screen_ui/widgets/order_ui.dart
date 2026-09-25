import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Shared presentation pieces for every order / booking surface (food,
/// e-commerce, cab, parcel, rental, on-demand, dine-in and the cart bill).
///
/// They exist so the receipt, the checkout and the history rows cannot drift
/// apart: one order-identity header, one money row, one total row and one item
/// row. Everything is built from DS tokens (`context.dsText`, `DsSpace`,
/// `context.dsColors`), so each screen keeps its own section accent through
/// `c.brand` / `c.brandStrong`.
///
/// These widgets are presentation only — they never compute a figure, never
/// translate a string and never own an action. Callers pass the value they
/// already computed and, where a screen had one, its existing copy handler.
class OrderUi {
  const OrderUi._();

  /// Widest a value column may get before it wraps. Keeps every amount in the
  /// same column and stops a long value from squeezing its label away.
  static const double valueMaxWidth = 180;

  /// Short, never-wrapping form of an order id: `#` + the last 8 characters.
  /// The full id stays available through tap-to-copy.
  static String shortId(String? id) {
    final String raw = (id ?? '').trim();
    if (raw.isEmpty) return '#--';
    return '#${raw.length <= 8 ? raw : raw.substring(raw.length - 8)}';
  }
}

/// One line with the short order id, in tabular figures at label size, muted.
/// Tapping copies the full id.
class OrderIdLine extends StatelessWidget {
  /// The full id. It is what gets copied; only [OrderUi.shortId] is shown.
  final String id;

  /// Set to false for a read-only id (no copy affordance, no touch target).
  final bool copyable;

  /// An existing copy handler from the screen. When null and [copyable] is
  /// true, the id is copied and [copiedMessage] is shown as a toast.
  final VoidCallback? onCopy;
  final String? copiedMessage;

  /// Accessible name of the copy action.
  final String? semanticLabel;

  /// Smaller variant used inside history rows.
  final bool compact;

  const OrderIdLine({super.key, required this.id, this.copyable = true, this.onCopy, this.copiedMessage, this.semanticLabel, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final TextStyle style = (compact ? t.caption : t.label).tabular.withColor(compact ? c.textMuted : c.textSecondary);

    final Widget text = Text(OrderUi.shortId(id), maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    if (!copyable || id.trim().isEmpty) return text;

    return Semantics(
      button: true,
      label: semanticLabel ?? "Copy".tr,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: DsRadius.brSm,
          onTap:
              onCopy ??
              () {
                Clipboard.setData(ClipboardData(text: id));
                ShowToastDialog.showToast(copiedMessage ?? "Copied".tr);
              },
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 32 : 48),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: text),
                  const DsGap(DsSpace.xs),
                  Icon(Icons.copy_rounded, size: compact ? 13 : 15, color: c.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Order identity block: one heading, the status chip on the same row, the
/// short id underneath (tap to copy) and an optional meta line.
///
/// The id never wraps and the word for "order" is printed once, in [title].
class OrderIdHeader extends StatelessWidget {
  /// The single heading, e.g. `'Order Id:'.tr`.
  final String title;

  /// Full order / booking id.
  final String id;

  /// Date or any other single meta line under the id.
  final String? subtitle;

  /// Status chip, aligned with the first line of the heading. Omit [statusLabel]
  /// when the screen already shows the status elsewhere.
  final String? statusLabel;
  final String? status;
  final bool pulse;

  final bool copyable;
  final VoidCallback? onCopy;
  final String? copiedMessage;
  final String? copySemanticLabel;

  const OrderIdHeader({
    super.key,
    required this.title,
    required this.id,
    this.subtitle,
    this.statusLabel,
    this.status,
    this.pulse = false,
    this.copyable = true,
    this.onCopy,
    this.copiedMessage,
    this.copySemanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.overline)),
            if (statusLabel != null) ...[
              const DsGap(DsSpace.sm),
              // Capped so a long translated status ellipsises inside the chip
              // instead of pushing the heading out of the row.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: DsStatusChip(label: statusLabel!, status: status, pulse: pulse),
              ),
            ],
          ],
        ),
        OrderIdLine(id: id, copyable: copyable, onCopy: onCopy, copiedMessage: copiedMessage, semanticLabel: copySemanticLabel ?? title),
        if (subtitle != null && subtitle!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.xxs),
            child: Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.caption),
          ),
      ],
    );
  }
}

/// One bill / fare / detail line: label left, value right.
///
/// The label is muted and one size smaller than the value, capped at two lines.
/// The value is right aligned with tabular figures, so every row of a block
/// lines up in the same column.
class OrderMoneyRow extends StatelessWidget {
  final String label;
  final String value;

  /// Explicit value colour (discounts, free delivery...). Wins over [tone].
  final Color? valueColor;
  final DsTone? tone;

  /// Underlines the label — used by rows that open a breakdown.
  final bool underline;

  /// Kept as-is from the screen: the row becomes tappable and gets an info icon.
  final VoidCallback? onTap;

  /// Extra muted text after the label, e.g. an applied coupon code.
  final String? labelSuffix;

  /// Widget under the label, e.g. the "Remove tip" action.
  final Widget? labelExtra;

  /// Replaces the value text (a button, a chip...).
  final Widget? valueWidget;

  /// Primary-coloured, medium-weight label for a highlighted line.
  final bool strongLabel;

  final EdgeInsetsGeometry? padding;

  const OrderMoneyRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.tone,
    this.underline = false,
    this.onTap,
    this.labelSuffix,
    this.labelExtra,
    this.valueWidget,
    this.strongLabel = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;

    final TextStyle labelStyle = (strongLabel ? t.bodySm.w600.withColor(c.textPrimary) : t.bodySm).copyWith(
      decoration: underline ? TextDecoration.underline : TextDecoration.none,
      decorationColor: c.textSecondary,
    );

    Widget labelBlock = Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: labelStyle);
    final bool hasSuffix = labelSuffix != null && labelSuffix!.isNotEmpty;
    if (hasSuffix || onTap != null) {
      labelBlock = Row(
        children: [
          Flexible(child: labelBlock),
          if (hasSuffix) ...[
            const DsGap(DsSpace.xs),
            Flexible(child: Text(labelSuffix!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSm.withColor(c.brandStrong))),
          ],
          if (onTap != null) ...[const DsGap(DsSpace.xs), Icon(Icons.info_outline_rounded, size: 14, color: c.textMuted)],
        ],
      );
    }
    if (labelExtra != null) {
      labelBlock = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [labelBlock, labelExtra!],
      );
    }

    final Widget row = Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: DsSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: labelBlock),
          const DsGap(DsSpace.md),
          valueWidget ??
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: OrderUi.valueMaxWidth),
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyStrong.tabular.withColor(valueColor ?? (tone == null ? c.textPrimary : c.tone(tone!).strong)),
                ),
              ),
        ],
      ),
    );

    if (onTap == null) return row;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(borderRadius: DsRadius.brSm, onTap: onTap, child: row),
    );
  }
}

/// The closing line of a bill block: separated by a divider, one step heavier
/// than the rows above it and in the section accent — never a bigger family or
/// a much larger size.
class OrderTotalRow extends StatelessWidget {
  final String label;
  final String value;

  /// Draws the separating divider. Pass false when the screen already has one.
  final bool divider;

  /// Defaults to the active section accent (`c.brandStrong`).
  final Color? valueColor;

  final EdgeInsetsGeometry? padding;

  const OrderTotalRow({super.key, required this.label, required this.value, this.divider = true, this.valueColor, this.padding});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final Widget row = Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: DsSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSm)),
          const DsGap(DsSpace.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: OrderUi.valueMaxWidth),
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.titleSm.w700.tabular.withColor(valueColor ?? c.brandStrong),
            ),
          ),
        ],
      ),
    );
    if (!divider) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [const DsDivider(spacing: DsSpace.md), row],
    );
  }
}

/// One ordered item: optional thumbnail, name with a compact quantity chip,
/// the charged price right aligned and the original price struck through
/// beside it — smaller and muted, never competing with the charged price.
class OrderItemRow extends StatelessWidget {
  /// Thumbnail or any leading widget.
  final Widget? leading;

  final String name;

  /// Rendered as a compact `x2` chip. Null hides it.
  final String? quantity;

  /// Puts the quantity chip before the name (ledger-style history rows).
  final bool quantityLeading;

  /// Use the surface colour for the chip when the row sits on `surfaceAlt`.
  final bool onAltSurface;

  final String price;

  /// Struck-through original price, shown next to [price].
  final String? originalPrice;

  /// Extra content under the name (badges, tax note, variants).
  final Widget? footer;

  /// Denser type for history rows.
  final bool compact;

  const OrderItemRow({
    super.key,
    this.leading,
    required this.name,
    this.quantity,
    this.quantityLeading = false,
    this.onAltSurface = false,
    required this.price,
    this.originalPrice,
    this.footer,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;

    final Widget? quantityChip = quantity == null || quantity!.isEmpty
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: 2),
            decoration: BoxDecoration(
              color: onAltSurface ? c.surface : c.surfaceAlt,
              borderRadius: DsRadius.brXs,
              border: Border.all(color: c.border),
            ),
            child: Text("x$quantity", maxLines: 1, style: t.labelSm.tabular.withColor(c.textSecondary)),
          );

    final Widget nameText = Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: compact ? t.body : t.bodyLg);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[leading!, const DsGap(DsSpace.md)],
        if (quantityLeading && quantityChip != null) ...[
          Padding(padding: const EdgeInsets.only(top: 1), child: quantityChip),
          const DsGap(DsSpace.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!quantityLeading && quantityChip != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(child: nameText),
                    const DsGap(DsSpace.sm),
                    quantityChip,
                  ],
                )
              else
                nameText,
              if (footer != null) footer!,
            ],
          ),
        ),
        const DsGap(DsSpace.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: OrderUi.valueMaxWidth),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (originalPrice != null && originalPrice!.isNotEmpty) ...[
                Flexible(
                  child: Text(originalPrice!, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: t.caption.tabular.strike),
                ),
                const DsGap(DsSpace.xs),
              ],
              Flexible(
                child: Text(
                  price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: (compact ? t.bodyStrong : t.titleSm).tabular,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

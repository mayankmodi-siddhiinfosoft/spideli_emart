import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared building blocks for every order / booking / job surface (delivery,
/// cab, parcel, rental and the owner's fleet list).
///
/// The five surfaces used to hand-roll their own header rows, bill rows and
/// item rows, which is how the order id ended up wrapping over three lines
/// under a duplicated "Order" label while the amounts drifted out of column.
/// Everything here is presentation only: callers keep their own controllers,
/// conditions, `.tr` strings and money calculations and just hand over the
/// finished text.
abstract final class OrderUi {
  /// Minimum width of the value column so every amount in a block lines up.
  static const double valueColumnMin = 88;

  /// Upper bound for the value column; long amounts ellipsise instead of
  /// squeezing the label away.
  static const double valueColumnMax = 200;

  /// Short, never-wrapping form of an order id: `#` + the last 8 characters.
  /// The full id stays available through copy / semantics.
  static String shortId(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return '';
    final core = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
    if (core.length <= 10) return '#$core';
    return '#${core.substring(core.length - 8)}';
  }

  /// The one price style used for item / package prices across the surfaces.
  static TextStyle price(BuildContext context) => context.dsText.titleSm.w700.tabular;
}

/// Order identity on a single line: a muted heading, the short id in tabular
/// figures at label size and an optional tap-to-copy action.
///
/// ```dart
/// OrderIdLine(label: "Order".tr, id: order.id.toString())
/// ```
class OrderIdLine extends StatelessWidget {
  /// Heading shown before the id (already translated by the caller).
  final String label;

  /// Full order id. Displayed short, copied in full.
  final String id;

  /// Shows the copy affordance. Turn it off inside tappable list rows.
  final bool copyable;

  /// Toast shown after copying (already translated by the caller).
  final String copiedMessage;

  /// Foreground colour on tinted / gradient headers (defaults to DS text).
  final Color? onColor;

  /// Tooltip / screen-reader label for the copy affordance.
  final String? copySemanticLabel;

  const OrderIdLine({
    super.key,
    required this.label,
    required this.id,
    this.copyable = true,
    required this.copiedMessage,
    this.onColor,
    this.copySemanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final Color labelColor = onColor?.withValues(alpha: 0.85) ?? c.textMuted;
    final Color valueColor = onColor ?? c.textPrimary;
    final String short = OrderUi.shortId(id);

    final Widget line = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.caption.withColor(labelColor),
          ),
        ),
        const DsGap(DsSpace.xs),
        Flexible(
          child: Text(
            short,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.label.tabular.withColor(valueColor),
          ),
        ),
      ],
    );

    if (!copyable) {
      return Semantics(
        label: '$label $id',
        excludeSemantics: true,
        child: line,
      );
    }

    return Semantics(
      label: copySemanticLabel == null ? '$label $id' : '$label $id, ${copySemanticLabel!}',
      excludeSemantics: true,
      button: true,
      child: Tooltip(
        message: copySemanticLabel ?? id,
        excludeFromSemantics: true,
        // Own ink layer: the surrounding card is a plain decorated container,
        // so the ripple would otherwise paint behind it.
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: DsRadius.brSm,
            onTap: _copy,
            // 48dp tap target for the copy action.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: line),
                  const DsGap(DsSpace.xs),
                  Icon(Icons.copy_rounded, size: 16, color: onColor ?? c.iconDefault),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: id));
    ShowToastDialog.showToast(copiedMessage);
  }
}

/// Header row shared by every order card: a title block on the left and a
/// status chip on the right, aligned to the first line and never wrapping.
class OrderHeaderRow extends StatelessWidget {
  /// First line of the header (heading, id line, date…).
  final Widget title;

  /// Optional second line under the title.
  final Widget? subtitle;

  /// Status chip (or any trailing marker). Kept on the title's first line.
  final Widget? trailing;

  const OrderHeaderRow({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final Widget titleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: title),
        if (trailing != null) ...[
          const DsGap(DsSpace.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: trailing!,
          ),
        ],
      ],
    );
    if (subtitle == null) return titleRow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titleRow,
        const DsGap(DsSpace.xxs),
        subtitle!,
      ],
    );
  }
}

/// Order identity + status chip on one row — the canonical order header.
///
/// ```dart
/// OrderIdHeader(
///   label: "Order".tr,
///   id: order.id.toString(),
///   copiedMessage: "Order ID copied to clipboard".tr,
///   trailing: DsStatusChip(label: status.tr, status: status),
/// )
/// ```
class OrderIdHeader extends StatelessWidget {
  final String label;
  final String id;
  final Widget? trailing;
  final Widget? subtitle;
  final bool copyable;
  final String copiedMessage;
  final Color? onColor;
  final String? copySemanticLabel;

  const OrderIdHeader({
    super.key,
    required this.label,
    required this.id,
    this.trailing,
    this.subtitle,
    this.copyable = true,
    required this.copiedMessage,
    this.onColor,
    this.copySemanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return OrderHeaderRow(
      title: Align(
        alignment: AlignmentDirectional.centerStart,
        child: OrderIdLine(
          label: label,
          id: id,
          copyable: copyable,
          copiedMessage: copiedMessage,
          onColor: onColor,
          copySemanticLabel: copySemanticLabel,
        ),
      ),
      subtitle: subtitle,
      trailing: trailing,
    );
  }
}

/// One line of a bill / fare / earnings block: muted label on the left, the
/// amount right aligned in tabular figures inside a fixed value column so
/// every row of the block lines up.
class OrderMoneyRow extends StatelessWidget {
  final String label;
  final String? value;

  /// Custom value widget (overrides [value]); it still sits in the value
  /// column, so amounts keep lining up.
  final Widget? valueWidget;

  /// Small icon after the label (e.g. the tax breakdown hint). Kept on the
  /// label side so the value column stays intact.
  final IconData? labelIcon;

  /// Tones the amount (discounts, commission…).
  final DsTone? valueTone;
  final bool divider;

  /// Amounts stay on one line; descriptive values (package names, distances)
  /// may use two.
  final int valueMaxLines;

  const OrderMoneyRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.labelIcon,
    this.valueTone,
    this.divider = false,
    this.valueMaxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final Color valueColor = valueTone != null ? c.tone(valueTone!).strong : c.textPrimary;

    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySm),
                ),
                if (labelIcon != null) ...[
                  const DsGap(DsSpace.xs),
                  Icon(labelIcon, size: 16, color: c.brandStrong),
                ],
              ],
            ),
          ),
          const DsGap(DsSpace.md),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: OrderUi.valueColumnMin, maxWidth: OrderUi.valueColumnMax),
            child: valueWidget ??
                Text(
                  value ?? '',
                  textAlign: TextAlign.end,
                  maxLines: valueMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyStrong.withColor(valueColor).tabular,
                ),
          ),
        ],
      ),
    );

    if (!divider) return row;
    return Column(mainAxisSize: MainAxisSize.min, children: [row, const DsDivider(spacing: 1)]);
  }
}

/// The emphasised closing line of a bill block: separated by a divider,
/// heavier weight, same value column as the rows above it.
class OrderTotalRow extends StatelessWidget {
  final String label;
  final String value;

  /// Colours the total (brand by default, `null` keeps text primary).
  final DsTone? tone;

  /// Draws the separating divider above the row.
  final bool divider;

  const OrderTotalRow({
    super.key,
    required this.label,
    required this.value,
    this.tone = DsTone.brand,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final Color valueColor = tone != null ? c.tone(tone!).strong : c.textPrimary;

    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSm),
          ),
          const DsGap(DsSpace.md),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: OrderUi.valueColumnMin, maxWidth: OrderUi.valueColumnMax),
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.titleSm.w700.withColor(valueColor).tabular,
            ),
          ),
        ],
      ),
    );

    if (!divider) return row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [const DsDivider(spacing: DsSpace.sm), row],
    );
  }
}

/// One product / manifest line: photo, name at body weight, the quantity as a
/// compact chip at the end of the name row and — when the screen shows money —
/// the charged price right aligned with the original struck through smaller
/// and muted beside it.
class OrderItemRow extends StatelessWidget {
  final String name;
  final String? imageUrl;

  /// Quantity chip label (e.g. "x 2"); already formatted by the caller.
  final String? quantityLabel;
  final DsTone quantityTone;

  /// Charged price, already formatted with the record's currency.
  final String? price;

  /// Original price, struck through next to [price].
  final String? originalPrice;

  /// Variants / addons blocks rendered full width under the row.
  final List<Widget> details;

  const OrderItemRow({
    super.key,
    required this.name,
    this.imageUrl,
    this.quantityLabel,
    this.quantityTone = DsTone.neutral,
    this.price,
    this.originalPrice,
    this.details = const [],
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (imageUrl != null) ...[
                DsImage(url: imageUrl!, width: 64, height: 64, radius: DsRadius.md),
                const DsGap(DsSpace.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyStrong),
                        ),
                        if (quantityLabel != null) ...[
                          const DsGap(DsSpace.sm),
                          DsBadge(label: quantityLabel!, tone: quantityTone, small: true),
                        ],
                      ],
                    ),
                    if (price != null) ...[
                      const DsGap(DsSpace.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (originalPrice != null) ...[
                            Flexible(
                              child: Text(
                                originalPrice!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySm.strike.withColor(c.textMuted).tabular,
                              ),
                            ),
                            const DsGap(DsSpace.sm),
                          ],
                          Flexible(
                            child: Text(
                              price!,
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: OrderUi.price(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          ...details,
        ],
      ),
    );
  }
}

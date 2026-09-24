import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';

/// Small shared building blocks for the subscription / account screens,
/// built on the design system. They carry no state and read no observable.
class SubUi {
  SubUi._();

  /// Section card. Pass [tone] for a tinted status surface.
  static Widget card(BuildContext context, Widget child, {EdgeInsets margin = const EdgeInsets.only(bottom: DsSpace.md), DsTone? tone, Color? borderColor}) {
    if (tone != null) {
      return DsCard.tinted(tone: tone, margin: margin, padding: const EdgeInsets.all(DsSpace.lg), child: child);
    }
    return DsCard(margin: margin, padding: const EdgeInsets.all(DsSpace.lg), borderColor: borderColor, child: child);
  }

  static Widget heading(BuildContext context, String value, {IconData? icon, String? actionLabel, VoidCallback? onAction}) =>
      DsSectionHeader(title: value, icon: icon, actionLabel: actionLabel, onAction: onAction, padding: const EdgeInsets.only(top: DsSpace.lg, bottom: DsSpace.md));

  static Widget title(BuildContext context, String value) => Text(value, style: DsTypography.titleSm.copyWith(color: DsColors.of(context).textPrimary));

  static Widget body(BuildContext context, String value) => Text(value, style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary));

  /// Label / value line used inside the detail cards.
  static Widget row(BuildContext context, String label, String value) {
    final c = DsColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 128, child: Text(label, style: DsTypography.bodySm.copyWith(color: c.textMuted))),
          const DsGap(DsSpace.sm),
          Expanded(child: Text(value, style: DsTypography.bodySm.copyWith(color: c.textPrimary, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  static Widget chip(String label, DsTone tone) => DsBadge(label: label, tone: tone, style: DsBadgeStyle.soft);

  static Widget empty(BuildContext context, String value, {IconData icon = Icons.inbox_outlined, String? title}) =>
      DsEmptyState(icon: icon, title: title ?? value, message: title == null ? null : value, compact: true);

  /// Price line ("12 000 XOF / month").
  static Widget price(BuildContext context, String value) => Text(value, style: DsTypography.titleSm.copyWith(color: DsColors.of(context).brandStrong).tabular);
}

/// Spideli Finance design system: the finance layer on top of the app DS
/// (`lib/themes/ds`). Every finance screen is built from these pieces so the
/// module reads as one institutional product, whatever service section the
/// user came from. Documented in `.claude/FINANCE-DESIGN-SYSTEM.md`.
///
/// Principles: one deep-navy identity; flat, bordered surfaces instead of
/// stacked cards; hairline dividers; tabular figures right-aligned for money;
/// semantic color only for states; one status catalogue for every module.
library;

import 'dart:math' as math;

import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ------------------------------------------------------------------- tokens

/// The finance palette. Navy carries identity and primary actions; neutrals
/// carry content; semantic tones (DS) carry states only.
abstract final class FinColors {
  static const Color navy = Color(0xFF0B2A4A);
  static const Color navyDark = Color(0xFF8DB4FF);
  static const Color heroLight = Color(0xFF0B2A4A);
  static const Color heroDark = Color(0xFF14263F);

  /// The accent for buttons, selections and links.
  static Color brand(BuildContext context) => DsColors.of(context).isDark ? navyDark : navy;

  /// The background of the balance panel.
  static Color hero(BuildContext context) => DsColors.of(context).isDark ? heroDark : heroLight;

  /// A navy tint for icon squares and markers.
  static Color soft(BuildContext context) => DsColors.of(context).isDark ? DsColors.of(context).surfaceAlt : const Color(0xFFE8EEF6);

  /// Page background: a cool neutral that lets white surfaces read as content.
  static Color page(BuildContext context) => DsColors.of(context).isDark ? DsColors.of(context).background : const Color(0xFFF4F6F9);
}

abstract final class FinSpace {
  /// Horizontal page gutter.
  static const double page = DsSpace.lg;

  /// Between sections.
  static const double section = DsSpace.xxl;

  /// Surface corner radius: restrained, not pill-shaped.
  static const double radius = 12;
  static const BorderRadius br = BorderRadius.all(Radius.circular(radius));
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(page, DsSpace.lg, page, DsSpace.huge);
}

abstract final class FinText {
  /// The amount of a balance panel.
  static TextStyle heroAmount(Color color) => DsTypography.metricLg.copyWith(color: color, fontSize: 32, height: 38 / 32);

  /// A headline amount on a detail screen.
  static const TextStyle amount = TextStyle(
    fontFamily: DsTypography.family,
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Section headers: small, tracked, quiet.
  static TextStyle sectionTitle(BuildContext context) => DsTypography.overline.copyWith(color: DsColors.of(context).textSecondary);
}

// ------------------------------------------------------------- status

/// The status catalogue of every finance record: its tone, and whether it is
/// final. Labels stay with each module (their wording differs: a "rejected"
/// loan is "Not approved", a rejected order "Not accepted").
abstract final class FinStatus {
  static const Set<String> _success = {
    'active', 'completed', 'settled', 'succeeded', 'paid', 'approved', 'funded', 'accepted', 'repaid', 'verified', 'posted', 'received', 'resolved',
  };
  static const Set<String> _info = {
    'submitted', 'under_review', 'processing', 'settling', 'pending_activation', 'requested', 'disbursing', 'quoted', 'frozen', 'reversed', 'collecting', 'uploaded', 'forming',
  };
  static const Set<String> _warning = {
    'pending', 'pending_payment', 'awaiting_confirmation', 'due', 'voting', 'funding', 'agreement_pending', 'info_requested', 'additional_info_required',
    'renewal_due', 'cancellation_requested', 'partially_paid', 'draft', 'payout_pending', 'pending_approval', 'invited', 'open',
  };
  static const Set<String> _danger = {
    'failed', 'rejected', 'overdue', 'defaulted', 'lapsed', 'payment_failed', 'declined', 'restricted', 'suspended',
  };

  static DsTone tone(String? s) {
    if (_success.contains(s)) return DsTone.success;
    if (_danger.contains(s)) return DsTone.danger;
    if (_warning.contains(s)) return DsTone.warning;
    if (_info.contains(s)) return DsTone.info;
    return DsTone.neutral;
  }

  static IconData icon(String? s) => switch (tone(s)) {
        DsTone.success => Icons.check_circle_rounded,
        DsTone.danger => Icons.error_rounded,
        DsTone.warning => Icons.schedule_rounded,
        DsTone.info => Icons.autorenew_rounded,
        _ => Icons.remove_circle_outline_rounded,
      };
}

/// A status label: tinted, small, with an icon so color is never the only cue.
class FinStatusChip extends StatelessWidget {
  final String status;
  final String label;
  final bool icon;

  const FinStatusChip({super.key, required this.status, required this.label, this.icon = false});

  @override
  Widget build(BuildContext context) =>
      DsBadge(label: label, tone: FinStatus.tone(status), small: true, icon: icon ? FinStatus.icon(status) : null);
}

// --------------------------------------------------------------- scaffold

/// Every finance screen: the navy identity, the finance page background and
/// a constrained content width on tablets.
class FinScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? body;
  final Widget? bottomBar;

  const FinScaffold({super.key, required this.title, this.subtitle, this.actions, this.body, this.bottomBar});

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (context) {
      final bool dark = Theme.of(context).brightness == Brightness.dark;
      return DsAccentScope(
        color: dark ? FinColors.navyDark : FinColors.navy,
        child: Builder(
          builder: (context) => DsScaffold(
            title: title,
            subtitle: subtitle,
            actions: actions,
            maxContentWidth: DsLayout.contentMax,
            backgroundColor: FinColors.page(context),
            bottomBar: bottomBar,
            body: body,
          ),
        ),
      );
    });
  }
}

/// The standard scrolling body of a finance screen.
class FinBody extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;

  const FinBody({super.key, required this.children, this.padding = FinSpace.pagePadding});

  @override
  Widget build(BuildContext context) => ListView(padding: padding, children: children);
}

// ------------------------------------------------------------------- hero

/// The one focal point of a screen: a flat navy panel with what the amount
/// is, the amount, an optional supporting line and actions.
class FinHero extends StatelessWidget {
  final String label;
  final String amount;
  final String? caption;
  final Widget? trailing;
  final Widget? footer;
  final List<FinHeroStat> stats;

  const FinHero({super.key, required this.label, required this.amount, this.caption, this.trailing, this.footer, this.stats = const []});

  @override
  Widget build(BuildContext context) {
    const onHero = Colors.white;
    final muted = Colors.white.withValues(alpha: 0.72);
    return Semantics(
      container: true,
      label: '$label: $amount${caption == null ? '' : '. $caption'}',
      child: Container(
        decoration: BoxDecoration(color: FinColors.hero(context), borderRadius: const BorderRadius.all(Radius.circular(16))),
        padding: const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.xl, DsSpace.xl, DsSpace.lg),
        child: ExcludeSemantics(
          excluding: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(label, style: DsTypography.labelSm.copyWith(color: muted))),
                ?trailing,
              ]),
              const DsGap(DsSpace.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(amount, style: FinText.heroAmount(onHero)),
              ),
              if (caption != null) ...[
                const DsGap(DsSpace.xxs),
                Text(caption!, style: DsTypography.bodySm.copyWith(color: muted)),
              ],
              if (stats.isNotEmpty) ...[
                const DsGap(DsSpace.lg),
                Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
                const DsGap(DsSpace.md),
                Row(children: [
                  for (final (i, s) in stats.indexed) ...[
                    if (i > 0) Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.12), margin: const EdgeInsets.symmetric(horizontal: DsSpace.md)),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.label, style: DsTypography.caption.copyWith(color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const DsGap(DsSpace.xxs),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(s.value, style: DsTypography.bodyStrong.copyWith(color: s.color ?? onHero).tabular),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ],
              if (footer != null) ...[const DsGap(DsSpace.lg), footer!],
            ],
          ),
        ),
      ),
    );
  }
}

class FinHeroStat {
  final String label;
  final String value;
  final Color? color;

  const FinHeroStat(this.label, this.value, {this.color});
}

/// A headline block for a detail screen: what it is, the amount, the status.
class FinHeader extends StatelessWidget {
  final String? overline;
  final String title;
  final String? subtitle;
  final String? status;
  final String? statusLabel;
  final IconData? icon;
  final Widget? below;

  /// The title's color (e.g. money received in green); default text color.
  final Color? titleColor;

  const FinHeader({super.key, this.overline, required this.title, this.subtitle, this.status, this.statusLabel, this.icon, this.below, this.titleColor});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return FinSurface(
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                DsIconWell(icon: icon, tone: status == null ? DsTone.brand : FinStatus.tone(status), size: 40),
                const DsGap(DsSpace.md),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (overline != null) Text(overline!, style: DsTypography.caption.copyWith(color: c.textSecondary)),
                  Text(title, style: FinText.amount.copyWith(color: titleColor ?? c.textPrimary)),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const DsGap(DsSpace.xxs),
                    Text(subtitle!, style: DsTypography.bodySm.copyWith(color: c.textSecondary)),
                  ],
                ]),
              ),
              if (status != null && statusLabel != null) ...[const DsGap(DsSpace.sm), FinStatusChip(status: status!, label: statusLabel!, icon: true)],
            ],
          ),
          if (below != null) ...[const DsGap(DsSpace.md), below!],
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- surfaces

/// A flat content surface: white (dark: raised), hairline border, 12 radius.
class FinSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const FinSurface({super.key, required this.child, this.padding = const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xs), this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final box = Container(
      decoration: BoxDecoration(color: c.isDark ? c.surfaceRaised : c.surface, borderRadius: FinSpace.br, border: Border.all(color: c.border)),
      padding: padding,
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: FinSpace.br, onTap: onTap, child: box),
    );
  }
}

/// A titled group of content: quiet uppercase title (+ optional action),
/// then one surface whose children are separated by hairlines.
class FinSection extends StatelessWidget {
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<Widget> children;
  final bool divided;
  final EdgeInsetsGeometry? padding;
  final String? footnote;

  /// Space above the section (0 for the first one).
  final double top;

  const FinSection({
    super.key,
    this.title,
    this.actionLabel,
    this.onAction,
    required this.children,
    this.divided = false,
    this.padding,
    this.footnote,
    this.top = FinSpace.section,
  });

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final items = children.where((w) => w is! SizedBox || (w.height ?? 1) > 0 || (w.child != null)).toList();
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || actionLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpace.sm, left: DsSpace.xxs, right: DsSpace.xxs),
              child: Row(children: [
                Expanded(child: Semantics(header: true, child: Text((title ?? '').toUpperCase(), style: FinText.sectionTitle(context)))),
                if (actionLabel != null)
                  InkWell(
                    onTap: onAction,
                    borderRadius: DsRadius.brSm,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.xs, vertical: DsSpace.xxs),
                      child: Text(actionLabel!, style: DsTypography.labelSm.copyWith(color: FinColors.brand(context))),
                    ),
                  ),
              ]),
            ),
          FinSurface(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, w) in items.indexed) ...[
                  if (divided && i > 0) Divider(height: 1, thickness: 1, color: c.divider),
                  w,
                ],
              ],
            ),
          ),
          if (footnote != null)
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.sm, left: DsSpace.xxs, right: DsSpace.xxs),
              child: Text(footnote!, style: DsTypography.caption.copyWith(color: c.textSecondary)),
            ),
        ],
      ),
    );
  }
}

/// A label / value line, the value right-aligned in tabular figures.
class FinRow extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? valueColor;
  final bool strong;
  final Widget? trailing;

  const FinRow(this.label, this.value, {super.key, this.sub, this.valueColor, this.strong = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Text(label, style: (strong ? DsTypography.bodyStrong : DsTypography.body).copyWith(color: strong ? c.textPrimary : c.textSecondary)),
            ),
            const DsGap(DsSpace.md),
            Flexible(
              flex: 6,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    value,
                    textAlign: TextAlign.end,
                    style: (strong ? DsTypography.titleSm : DsTypography.bodyStrong).copyWith(color: valueColor ?? c.textPrimary).tabular,
                  ),
                  if (sub != null) Text(sub!, textAlign: TextAlign.end, style: DsTypography.caption.copyWith(color: c.textSecondary)),
                ]),
              ),
            ),
            if (trailing != null) ...[const DsGap(DsSpace.sm), trailing!],
          ],
        ),
      ),
    );
  }
}

/// A list row: icon, title and supporting line, trailing amount and status.
class FinListTile extends StatelessWidget {
  final IconData icon;
  final DsTone iconTone;
  final String title;
  final String? subtitle;
  final String? amount;
  final Color? amountColor;
  final String? status;
  final String? statusLabel;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;

  const FinListTile({
    super.key,
    required this.icon,
    this.iconTone = DsTone.neutral,
    required this.title,
    this.subtitle,
    this.amount,
    this.amountColor,
    this.status,
    this.statusLabel,
    this.trailing,
    this.onTap,
    this.chevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        borderRadius: DsRadius.brSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: c.tone(iconTone).soft, borderRadius: DsRadius.brSm),
                child: Icon(icon, size: 20, color: iconTone == DsTone.neutral ? c.textSecondary : c.tone(iconTone).strong),
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const DsGap(DsSpace.xxs),
                    Text(subtitle!, style: DsTypography.caption.copyWith(color: c.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ]),
              ),
              if (amount != null || statusLabel != null) ...[
                const DsGap(DsSpace.sm),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (amount != null) Text(amount!, style: DsTypography.bodyStrong.copyWith(color: amountColor ?? c.textPrimary).tabular),
                  if (statusLabel != null && status != null) ...[
                    if (amount != null) const DsGap(DsSpace.xxs),
                    FinStatusChip(status: status!, label: statusLabel!),
                  ],
                ]),
              ],
              if (trailing != null) ...[const DsGap(DsSpace.sm), trailing!],
              if (chevron) ...[const DsGap(DsSpace.xs), Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: c.textMuted)],
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- metrics

class FinMetric {
  final String label;
  final String value;
  final String? sub;
  final Color? color;

  const FinMetric(this.label, this.value, {this.sub, this.color});
}

/// Two-column key figures inside one surface, divided by hairlines.
class FinMetrics extends StatelessWidget {
  final List<FinMetric> items;

  const FinMetrics({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final rows = <List<FinMetric>>[for (int i = 0; i < items.length; i += 2) items.sublist(i, math.min(i + 2, items.length))];
    Widget cell(FinMetric m) => MergeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.label, style: DsTypography.caption.copyWith(color: c.textSecondary), maxLines: 2),
              const DsGap(DsSpace.xxs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(m.value, style: DsTypography.titleSm.copyWith(color: m.color ?? c.textPrimary).tabular),
              ),
              if (m.sub != null) Text(m.sub!, style: DsTypography.caption.copyWith(color: c.textSecondary)),
            ]),
          ),
        );
    return FinSurface(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
      child: Column(children: [
        for (final (i, r) in rows.indexed) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: c.divider),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: cell(r[0])),
              VerticalDivider(width: DsSpace.xxl, thickness: 1, color: c.divider),
              Expanded(child: r.length > 1 ? cell(r[1]) : const SizedBox()),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------- progress

/// A labelled progress bar: what is measured, how far, of what.
class FinProgress extends StatelessWidget {
  final double value;
  final String? label;
  final String? trailing;
  final DsTone tone;

  const FinProgress({super.key, required this.value, this.label, this.trailing, this.tone = DsTone.brand});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final v = value.clamp(0.0, 1.0);
    final color = tone == DsTone.brand ? FinColors.brand(context) : c.tone(tone).main;
    return Semantics(
      value: '${(v * 100).round()}%',
      label: label,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (label != null || trailing != null)
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.xs),
            child: Row(children: [
              Expanded(child: Text(label ?? '', style: DsTypography.caption.copyWith(color: c.textSecondary))),
              Text(trailing ?? '${(v * 100).round()}%', style: DsTypography.caption.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600).tabular),
            ]),
          ),
        ClipRRect(
          borderRadius: DsRadius.brPill,
          child: SizedBox(
            height: 6,
            child: Stack(children: [
              Container(color: c.surfaceAlt),
              FractionallySizedBox(widthFactor: v, child: Container(color: color)),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Where a record is in its workflow: a segmented bar and the current step,
/// compact enough for long workflows (an 8-step loan).
class FinTrack extends StatelessWidget {
  final List<String> steps;
  final int current;

  /// The record ended outside the normal path (rejected, cancelled...).
  final bool ended;
  final String? endedLabel;

  const FinTrack({super.key, required this.steps, required this.current, this.ended = false, this.endedLabel});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final brand = FinColors.brand(context);
    final bool done = !ended && current >= steps.length - 1;
    final String now = ended ? (endedLabel ?? '') : (current >= 0 && current < steps.length ? steps[current] : '');
    final String? next = !ended && current + 1 < steps.length ? steps[current + 1] : null;
    return Semantics(
      label: '${"Status".tr}: $now${next == null ? '' : '. ${"Next".tr}: $next'}',
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            for (int i = 0; i < steps.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: DsRadius.brPill,
                    color: ended ? (i <= current ? c.textMuted : c.surfaceAlt) : (i <= current ? (done ? c.success : brand) : c.surfaceAlt),
                  ),
                ),
              ),
            ],
          ]),
          const DsGap(DsSpace.sm),
          Row(children: [
            Expanded(child: Text(now, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary))),
            if (!ended) Text('${"Step".tr} ${math.min(current + 1, steps.length)}/${steps.length}', style: DsTypography.caption.copyWith(color: c.textSecondary)),
          ]),
          if (next != null) Text('${"Next".tr}: $next', style: DsTypography.caption.copyWith(color: c.textSecondary)),
        ]),
      ),
    );
  }
}

// --------------------------------------------------------------- actions

class FinAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const FinAction(this.icon, this.label, this.onTap);
}

/// Up to four primary actions in a row (more wrap), each a square icon and a label.
class FinActions extends StatelessWidget {
  final List<FinAction> actions;
  final bool onHero;

  const FinActions({super.key, required this.actions, this.onHero = false});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final fg = onHero ? Colors.white : FinColors.brand(context);
    final bg = onHero ? Colors.white.withValues(alpha: 0.12) : FinColors.soft(context);
    final text = onHero ? Colors.white : c.textPrimary;
    return LayoutBuilder(builder: (context, box) {
      const int perRow = 4;
      final double w = (box.maxWidth - DsSpace.sm * (perRow - 1)) / perRow;
      return Wrap(
        spacing: DsSpace.sm,
        runSpacing: DsSpace.md,
        children: [
          for (final a in actions)
            SizedBox(
              width: w,
              child: Semantics(
                button: true,
                enabled: a.onTap != null,
                label: a.label,
                onTap: a.onTap,
                child: ExcludeSemantics(
                  child: InkWell(
                    onTap: a.onTap,
                    borderRadius: DsRadius.brMd,
                    child: Opacity(
                      opacity: a.onTap == null ? 0.45 : 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                        child: Column(children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(color: bg, borderRadius: DsRadius.brMd),
                            child: Icon(a.icon, color: fg, size: 22),
                          ),
                          const DsGap(DsSpace.xs),
                          Text(a.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: DsTypography.caption.copyWith(color: text, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

// --------------------------------------------------------------- feedback

/// A slim notice: disclosures, estimates, requirements. Tone carries meaning.
class FinNotice extends StatelessWidget {
  final String message;
  final String? title;
  final DsTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  const FinNotice(this.message, {super.key, this.title, this.tone = DsTone.info, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: DsSpace.md),
        child: DsInlineAlert(tone: tone, title: title, message: message, actionLabel: actionLabel, onAction: onAction),
      );
}

/// Loading / error / empty for a section, same footprint so layouts stay still.
abstract final class FinState {
  static Widget loading({int rows = 3}) => Padding(padding: const EdgeInsets.only(top: FinSpace.section), child: DsSkeletonList(itemCount: rows));

  static Widget error(String message, {VoidCallback? onRetry}) =>
      Padding(padding: const EdgeInsets.only(top: FinSpace.section), child: DsErrorState(message: message, compact: true, onRetry: onRetry));

  static Widget empty(IconData icon, String title, {String? message, String? actionLabel, VoidCallback? onAction}) => Padding(
        padding: const EdgeInsets.only(top: FinSpace.section),
        child: DsEmptyState(icon: icon, title: title, message: message, actionLabel: actionLabel, onAction: onAction, compact: true),
      );
}

/// A bottom sheet in the finance identity. Sheets open in the app's overlay,
/// outside [FinScaffold]'s accent scope, so every finance sheet goes through
/// this instead of `DsBottomSheet.show` (same parameters).
Future<T?> finSheet<T>({
  required Widget child,
  String? title,
  String? subtitle,
  Widget? actions,
  bool showClose = true,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  final bool dark = Get.isDarkMode;
  return Get.bottomSheet<T>(
    DsAccentScope(
      color: dark ? FinColors.navyDark : FinColors.navy,
      child: DsSheet(title: title, subtitle: subtitle, actions: actions, showClose: showClose, child: child),
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    barrierColor: DsColors.resolve(dark).scrim,
  );
}

/// A confirmation sheet: what will happen, the figures, then one action.
/// Returns true when confirmed.
Future<bool> finConfirm({
  required String title,
  String? message,
  List<(String, String)> lines = const [],
  (String, String)? total,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final ok = await finSheet<bool>(
    title: title,
    child: Builder(builder: (context) {
      final c = DsColors.of(context);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null) Padding(padding: const EdgeInsets.only(bottom: DsSpace.md), child: Text(message, style: DsTypography.body.copyWith(color: c.textSecondary))),
          for (final (l, v) in lines) FinRow(l, v),
          if (total != null) ...[
            Divider(height: DsSpace.lg, color: c.divider),
            FinRow(total.$1, total.$2, strong: true),
          ],
          const DsGap(DsSpace.lg),
          DsButton.primary(label: confirmLabel, expand: true, color: destructive ? c.danger : null, onPressed: () => Get.back(result: true)),
          DsButton.ghost(label: cancelLabel ?? "Keep it".tr, expand: true, onPressed: () => Get.back(result: false)),
        ],
      );
    }),
  );
  return ok == true;
}

// ---------------------------------------------------------------- charts

/// Grouped bars per period (money in / out), with a value read-out on tap.
class FinBarChart extends StatefulWidget {
  final List<String> labels;
  final List<double> a;
  final List<double> b;
  final String aLabel;
  final String bLabel;
  final Color aColor;
  final Color bColor;
  final String Function(double) format;
  final double height;

  const FinBarChart({
    super.key,
    required this.labels,
    required this.a,
    required this.b,
    required this.aLabel,
    required this.bLabel,
    required this.aColor,
    required this.bColor,
    required this.format,
    this.height = 140,
  });

  @override
  State<FinBarChart> createState() => _FinBarChartState();
}

class _FinBarChartState extends State<FinBarChart> {
  late int _selected = widget.labels.length - 1;

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final double maxV = [...widget.a, ...widget.b, 1.0].reduce(math.max);
    final int n = widget.labels.length;
    final int sel = _selected.clamp(0, n - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: Text(widget.labels[sel], style: DsTypography.labelSm.copyWith(color: c.textSecondary))),
          _legendValue(context, widget.aColor, widget.aLabel, widget.format(widget.a[sel])),
          const DsGap(DsSpace.lg),
          _legendValue(context, widget.bColor, widget.bLabel, widget.format(widget.b[sel])),
        ]),
        const DsGap(DsSpace.md),
        SizedBox(
          height: widget.height,
          child: Stack(children: [
            // Gridlines at 0, 50 and 100 %.
            for (final f in const [0.0, 0.5, 1.0])
              Positioned(left: 0, right: 0, bottom: f * (widget.height - 20) + 20, child: Container(height: 1, color: c.divider)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < n; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: '${widget.labels[i]}: ${widget.aLabel} ${widget.format(widget.a[i])}, ${widget.bLabel} ${widget.format(widget.b[i])}',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _selected = i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _bar(widget.a[i] / maxV, widget.aColor, i == sel),
                                const SizedBox(width: 3),
                                _bar(widget.b[i] / maxV, widget.bColor, i == sel),
                              ],
                            ),
                            const DsGap(DsSpace.xs),
                            SizedBox(
                              height: 16,
                              child: Text(widget.labels[i].split(' ').first,
                                  style: DsTypography.caption.copyWith(color: i == sel ? c.textPrimary : c.textSecondary, fontWeight: i == sel ? FontWeight.w700 : FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ]),
        ),
      ],
    );
  }

  Widget _bar(double f, Color color, bool selected) => AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : DsMotion.base,
        width: 10,
        height: math.max(2, f * (widget.height - 24)),
        decoration: BoxDecoration(color: selected ? color : color.withValues(alpha: 0.45), borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
      );

  Widget _legendValue(BuildContext context, Color color, String label, String value) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const DsGap(DsSpace.xs),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary)),
          Text(value, style: DsTypography.labelSm.copyWith(color: DsColors.of(context).textPrimary).tabular),
        ]),
      ]);
}

/// A stacked share bar with a legend: allocation, budget splits.
class FinShareBar extends StatelessWidget {
  final List<(String, double, String)> parts;

  const FinShareBar({super.key, required this.parts});

  static List<Color> palette(BuildContext context) {
    final c = DsColors.of(context);
    return [FinColors.brand(context), c.info, c.success, c.warning, const Color(0xFF7C5CBF), c.textMuted];
  }

  @override
  Widget build(BuildContext context) {
    final colors = palette(context);
    final total = parts.fold<double>(0, (s, p) => s + p.$2);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: DsRadius.brPill,
        child: SizedBox(
          height: 10,
          child: Row(children: [
            for (final (i, p) in parts.indexed)
              if (p.$2 > 0) Expanded(flex: math.max(1, (p.$2 / (total == 0 ? 1 : total) * 1000).round()), child: Container(color: colors[i % colors.length])),
          ]),
        ),
      ),
      const DsGap(DsSpace.sm),
      for (final (i, p) in parts.indexed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
            const DsGap(DsSpace.sm),
            Expanded(child: Text(p.$1, style: DsTypography.body)),
            Text(p.$3, style: DsTypography.bodyStrong.tabular),
          ]),
        ),
    ]);
  }
}

/// A money amount in its sign color: green in, default out.
Color finAmountColor(BuildContext context, num signed) => signed > 0 ? DsColors.of(context).successStrong : DsColors.of(context).textPrimary;

/// "Updated 13 Oct, 21:03"-style freshness line.
Widget finFreshness(BuildContext context, String text) =>
    Text(text, style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary));

/// Re-exported for convenience in screens.
String finMoney(num minor, String currency) => FinanceMoney.format(minor, currency);

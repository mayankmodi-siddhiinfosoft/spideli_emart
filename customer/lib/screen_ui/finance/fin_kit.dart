import 'dart:math' as math;

import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// The premium pieces of the Finance dashboard, on top of `fin_ds.dart`:
/// a greeting, calendar date badges, the money in / out comparison, the
/// portfolio tiles, the service tiles and the spending breakdown. Every one
/// adapts to small phones, large text, right-to-left text and dark mode.

/// "Good evening, Awa": the first line of the dashboard.
class FinGreeting extends StatelessWidget {
  final String? firstName;
  final DateTime? now;

  const FinGreeting({super.key, this.firstName, this.now});

  static String partOfDay(DateTime t) => t.hour < 12 ? "Good morning" : (t.hour < 18 ? "Good afternoon" : "Good evening");

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final DateTime t = now ?? DateTime.now();
    final String name = (firstName ?? '').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.lg, left: DsSpace.xxs, right: DsSpace.xxs),
      child: Semantics(
        header: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ltr(DateFormat('EEEE d MMMM').format(t)).toUpperCase(), style: FinText.sectionTitle(context)),
          const DsGap(DsSpace.xxs),
          Text(name.isEmpty ? partOfDay(t).tr : '${partOfDay(t).tr}, $name', style: DsTypography.headline.copyWith(color: c.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

/// A calendar leaf for a due date: the month on top, the day large. Urgent
/// (overdue) in the danger tone, today in brass.
class FinDateBadge extends StatelessWidget {
  final DateTime date;
  final bool urgent;
  final DateTime? today;

  const FinDateBadge(this.date, {super.key, this.urgent = false, this.today});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final DateTime t = today ?? DateTime.now();
    final bool isToday = date.year == t.year && date.month == t.month && date.day == t.day;
    final Color top = urgent ? c.dangerStrong : (isToday ? FinColors.brass(context) : FinColors.brand(context));
    final Color bg = urgent ? c.tone(DsTone.danger).soft : (isToday ? FinColors.brassSoft(context) : FinColors.soft(context));
    return ExcludeSemantics(
      child: Container(
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
        decoration: BoxDecoration(color: bg, borderRadius: DsRadius.brSm),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(DateFormat('MMM').format(date).toUpperCase(), style: DsTypography.caption.copyWith(color: top, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.8)),
          Text('${date.day}', style: DsTypography.title.copyWith(color: c.textPrimary, height: 1.1).tabular),
        ]),
      ),
    );
  }
}

/// Money in and money out of a period side by side as bars, the net result
/// and how it compares with the period before. [format] turns minor units
/// into text.
class FinInOut extends StatelessWidget {
  final int moneyIn;
  final int moneyOut;
  final int? previousIn;
  final int? previousOut;
  final String? previousLabel;
  final String Function(num minor) format;
  final String Function(num minor) signed;

  const FinInOut({
    super.key,
    required this.moneyIn,
    required this.moneyOut,
    this.previousIn,
    this.previousOut,
    this.previousLabel,
    required this.format,
    required this.signed,
  });

  @override
  Widget build(BuildContext context) => FinPrivacy.watch((hidden) => _inOut(context, hidden));

  Widget _inOut(BuildContext context, bool hidden) {
    // With the eye closed the figures go; the bars keep their proportions.
    String format(num v) => hidden ? FinPrivacy.mask(this.format(v)) : this.format(v);
    String signed(num v) => hidden ? FinPrivacy.mask(this.signed(v)) : this.signed(v);
    final c = DsColors.of(context);
    final int net = moneyIn - moneyOut;
    final int top = math.max(1, math.max(moneyIn, moneyOut));
    Widget bar(String label, IconData icon, int value, int? previous, Color color) {
      final double share = (value / top).clamp(0.0, 1.0);
      // "↓ 90 % vs Sep 2026 (500 000 XAF)": an arrow and words, never the
      // colour alone.
      String? delta;
      if (previous != null && previousLabel != null && (previous > 0 || value > 0)) {
        if (previous == 0) {
          delta = '${"New compared with".tr} $previousLabel';
        } else {
          final int pct = ((value - previous) * 100 / previous).round();
          final String arrow = pct == 0 ? '=' : (pct > 0 ? '↑' : '↓');
          delta = '$arrow ${ltr('${pct.abs()} %')} ${"vs".tr} $previousLabel (${format(previous)})';
        }
      }
      return MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(icon, size: 16, color: color),
              const DsGap(DsSpace.xs),
              Expanded(child: Text(label, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary))),
              Flexible(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(format(value), style: DsTypography.bodyStrong.copyWith(color: c.textPrimary).tabular),
                  ),
                ),
              ),
            ]),
            const DsGap(DsSpace.xs),
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: DsRadius.brPill,
                child: Stack(children: [
                  Container(height: 8, color: c.surfaceAlt),
                  FractionallySizedBox(widthFactor: share, child: Container(height: 8, color: color)),
                ]),
              ),
            ),
            if (delta != null) ...[const DsGap(DsSpace.xxs), Text(delta, style: DsTypography.caption.copyWith(color: c.textSecondary))],
          ]),
        ),
      );
    }

    return FinSurface(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MergeSemantics(
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Text("Net".tr, style: DsTypography.labelSm.copyWith(color: c.textSecondary))),
            Flexible(
              flex: 3,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: FinAmountText(signed(net), style: DsTypography.metric.copyWith(color: net >= 0 ? c.successStrong : c.textPrimary)),
                ),
              ),
            ),
          ]),
        ),
        const DsGap(DsSpace.xs),
        Divider(height: 1, color: c.divider),
        bar("Money in".tr, Icons.south_west_rounded, moneyIn, previousIn, c.success),
        bar("Money out".tr, Icons.north_east_rounded, moneyOut, previousOut, FinColors.brand(context)),
      ]),
    );
  }
}

/// One product of the portfolio: what it is, its value, one line about it
/// and an optional progress.
class FinProductTile {
  final IconData icon;
  final FinAccent accent;
  final String title;
  final String value;
  final String? meta;
  final double? progress;
  final bool alert;
  final VoidCallback? onTap;

  const FinProductTile({required this.icon, this.accent = FinAccent.ink, required this.title, required this.value, this.meta, this.progress, this.alert = false, this.onTap});
}

/// The portfolio as tiles: two per row, one per row on a narrow screen or
/// with large text.
class FinTileGrid extends StatelessWidget {
  final List<FinProductTile> tiles;

  const FinTileGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) => FinPrivacy.watch((hidden) => _grid(context, hidden));

  Widget _grid(BuildContext context, bool hidden) {
    final c = DsColors.of(context);
    return LayoutBuilder(builder: (context, box) {
      final double scale = MediaQuery.textScalerOf(context).scale(1);
      final int perRow = box.maxWidth / 2 >= 150 * scale ? 2 : 1;
      final double w = (box.maxWidth - DsSpace.md * (perRow - 1)) / perRow;
      return Wrap(
        spacing: DsSpace.md,
        runSpacing: DsSpace.md,
        children: [
          for (final t in tiles)
            SizedBox(
              width: w,
              child: MergeSemantics(
                child: Semantics(
                  button: t.onTap != null,
                  child: FinSurface(
                    onTap: t.onTap,
                    padding: const EdgeInsets.all(DsSpace.md),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        _AccentIcon(t.icon, t.alert ? null : t.accent, size: 36, danger: t.alert),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded, size: 20, color: c.textMuted),
                      ]),
                      const DsGap(DsSpace.sm),
                      Text(t.title, style: DsTypography.caption.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const DsGap(DsSpace.xxs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: FinAmountText(hidden ? FinPrivacy.maskAll(t.value) : t.value, style: DsTypography.title.copyWith(color: c.textPrimary)),
                      ),
                      if (t.progress != null) ...[
                        const DsGap(DsSpace.xs),
                        ClipRRect(
                          borderRadius: DsRadius.brPill,
                          child: LinearProgressIndicator(
                            value: t.progress!.clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: c.surfaceAlt,
                            color: FinColors.accent(context, t.accent).$1,
                          ),
                        ),
                      ],
                      if (t.meta != null) ...[
                        const DsGap(DsSpace.xs),
                        Text(hidden ? FinPrivacy.maskAll(t.meta!) : t.meta!, style: DsTypography.caption.copyWith(color: t.alert ? c.dangerStrong : c.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// An icon on the soft tint of its family's colour.
class _AccentIcon extends StatelessWidget {
  final IconData icon;
  final FinAccent? accent;
  final double size;
  final bool danger;

  const _AccentIcon(this.icon, this.accent, {this.size = 40, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final (Color fg, Color bg) = danger ? (c.dangerStrong, c.tone(DsTone.danger).soft) : FinColors.accent(context, accent ?? FinAccent.ink);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(icon, size: size * 0.5, color: fg),
    );
  }
}

/// A service of the Services tab.
class FinService {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const FinService(this.icon, this.title, this.subtitle, this.onTap);
}

/// A family of services: its title with a coloured mark, then the services
/// as tiles (two per row; one per row when narrow).
class FinServiceGroup extends StatelessWidget {
  final String title;
  final FinAccent accent;
  final List<FinService> services;

  const FinServiceGroup({super.key, required this.title, required this.accent, required this.services});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final (Color main, _) = FinColors.accent(context, accent);
    return Padding(
      padding: const EdgeInsets.only(top: FinSpace.section),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: DsSpace.sm, left: DsSpace.xxs, right: DsSpace.xxs),
          child: Row(children: [
            Container(width: 4, height: 14, decoration: BoxDecoration(color: main, borderRadius: DsRadius.brPill)),
            const DsGap(DsSpace.sm),
            Expanded(child: Semantics(header: true, child: Text(title.toUpperCase(), style: FinText.sectionTitle(context)))),
          ]),
        ),
        LayoutBuilder(builder: (context, box) {
          final double scale = MediaQuery.textScalerOf(context).scale(1);
          final int perRow = box.maxWidth / 2 >= 150 * scale ? 2 : 1;
          final double w = (box.maxWidth - DsSpace.md * (perRow - 1)) / perRow;
          return Wrap(
            spacing: DsSpace.md,
            runSpacing: DsSpace.md,
            children: [
              for (final s in services)
                SizedBox(
                  width: w,
                  child: MergeSemantics(
                    child: Semantics(
                      button: true,
                      child: FinSurface(
                        onTap: s.onTap,
                        padding: const EdgeInsets.all(DsSpace.md),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _AccentIcon(s.icon, accent),
                          const DsGap(DsSpace.sm),
                          Text(s.title, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const DsGap(DsSpace.xxs),
                          Text(s.subtitle, style: DsTypography.caption.copyWith(color: c.textSecondary), maxLines: 3, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
      ]),
    );
  }
}

/// Where the money went: one line per kind with its share as a bar, the
/// largest first.
class FinBreakdown extends StatelessWidget {
  final List<(IconData, String, int)> items;
  final String Function(num minor) format;
  final String? emptyText;

  const FinBreakdown({super.key, required this.items, required this.format, this.emptyText});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final sorted = [...items]..sort((a, b) => b.$3.compareTo(a.$3));
    final int top = sorted.isEmpty ? 1 : math.max(1, sorted.first.$3);
    if (sorted.every((i) => i.$3 == 0)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
        child: Text(emptyText ?? "Nothing moved in this period.".tr, style: DsTypography.body.copyWith(color: c.textSecondary)),
      );
    }
    return Column(children: [
      for (final (icon, label, value) in sorted)
        MergeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
            child: Row(children: [
              _AccentIcon(icon, FinAccent.ink, size: 32),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(label, style: DsTypography.body.copyWith(color: c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(format(value), style: DsTypography.bodyStrong.copyWith(color: value == 0 ? c.textMuted : c.textPrimary).tabular),
                  ]),
                  const DsGap(DsSpace.xxs),
                  ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: DsRadius.brPill,
                      child: Stack(children: [
                        Container(height: 4, color: c.surfaceAlt),
                        FractionallySizedBox(widthFactor: (value / top).clamp(0.0, 1.0), child: Container(height: 4, color: FinColors.brand(context))),
                      ]),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
    ]);
  }
}

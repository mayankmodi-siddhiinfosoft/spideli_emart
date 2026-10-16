/// Spideli Finance design system: the finance layer on top of the app DS
/// (`lib/themes/ds`). Every finance screen is built from these pieces so the
/// module reads as one institutional product, whatever service section the
/// user came from. Documented in `.claude/FINANCE-DESIGN-SYSTEM.md`.
///
/// Principles: one deep-navy identity; flat, bordered surfaces instead of
/// stacked cards; hairline dividers; tabular figures right-aligned for money;
/// semantic color only for states; one status catalogue for every module.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:customer/service/finance_region_service.dart';
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

  /// Brass: the premium touch, used sparingly (verified, active, highlights).
  /// Readable on white (4.6:1) and on the dark page.
  static Color brass(BuildContext context) => DsColors.of(context).isDark ? const Color(0xFFE3C17A) : const Color(0xFF8A6A2F);
  static Color brassSoft(BuildContext context) => DsColors.of(context).isDark ? const Color(0xFF3A3222) : const Color(0xFFF6EEDD);

  /// The colour of a family of services, (main, soft): icons on their soft
  /// tint keep at least 4.5:1.
  static (Color, Color) accent(BuildContext context, FinAccent a) {
    final bool dark = DsColors.of(context).isDark;
    return switch (a) {
      FinAccent.pay => dark ? (const Color(0xFF8DB4FF), const Color(0xFF1C2A45)) : (const Color(0xFF1D4ED8), const Color(0xFFE6EDFD)),
      FinAccent.save => dark ? (const Color(0xFF5EEAD4), const Color(0xFF11302C)) : (const Color(0xFF0F766E), const Color(0xFFDFF3F0)),
      FinAccent.borrow => dark ? (const Color(0xFFF2C14E), const Color(0xFF33291A)) : (const Color(0xFF8A5A00), const Color(0xFFFBF0D9)),
      FinAccent.help => dark ? (const Color(0xFFC4B5FD), const Color(0xFF2A2142)) : (const Color(0xFF6D28D9), const Color(0xFFEFE8FD)),
      FinAccent.ink => dark ? (const Color(0xFF8DB4FF), const Color(0xFF1C2A45)) : (navy, const Color(0xFFE8EEF6)),
    };
  }
}

/// The families of services, each with its colour ([FinColors.accent]).
enum FinAccent { pay, save, borrow, help, ink }

abstract final class FinSpace {
  /// Horizontal page gutter.
  static const double page = DsSpace.lg;

  /// Between sections.
  static const double section = DsSpace.xxl;

  /// Surface corner radius: restrained, not pill-shaped.
  static const double radius = 12;
  static const BorderRadius br = BorderRadius.all(Radius.circular(radius));

  /// The ink cards (balance, profile): rounder than the content surfaces.
  static const BorderRadius brHero = BorderRadius.all(Radius.circular(22));
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

  /// On by default: the icon, with the text, keeps colour from being the
  /// only cue.
  const FinStatusChip({super.key, required this.status, required this.label, this.icon = true});

  @override
  Widget build(BuildContext context) => DsBadge(label: label, tone: FinStatus.tone(status), small: true, icon: icon ? FinStatus.icon(status) : null);
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

  /// False on a tab of the Finance dashboard: no back arrow.
  final bool showBack;

  const FinScaffold({super.key, required this.title, this.subtitle, this.actions, this.body, this.bottomBar, this.showBack = true});

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
            showBack: showBack,
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

/// The one focal point of a screen: an ink-navy card with a fine engraved
/// pattern (guilloche, like a banknote), what the amount is, the amount with
/// its currency set smaller, an optional supporting line, key figures in an
/// inset panel and actions. With [privacy] an eye hides the figures (shared
/// by every card: [FinPrivacy]).
class FinHero extends StatelessWidget {
  final String label;
  final String amount;
  final String? caption;
  final Widget? trailing;
  final Widget? footer;
  final List<FinHeroStat> stats;

  /// Shows the eye that hides the amounts.
  final bool privacy;

  const FinHero({super.key, required this.label, required this.amount, this.caption, this.trailing, this.footer, this.stats = const [], this.privacy = false});

  @override
  Widget build(BuildContext context) {
    if (!privacy) return _card(context, false);
    return ValueListenableBuilder<bool>(valueListenable: FinPrivacy.hidden, builder: (context, hidden, _) => _card(context, hidden));
  }

  Widget _card(BuildContext context, bool hidden) {
    const onHero = Colors.white;
    final muted = Colors.white.withValues(alpha: 0.72);
    final Color line = Colors.white.withValues(alpha: 0.14);
    String shown(String v) => hidden ? FinPrivacy.mask(v) : v;
    // Read once by a screen reader: the label, the amount, the caption and
    // the figures; the actions below stay separate buttons.
    final String spoken = hidden
        ? '$label: ${"Hidden".tr}'
        : ['$label: $amount', ?caption, for (final s in stats) '${s.label}: ${s.value}'].join('. ');
    Widget statValue(FinHeroStat s) => Text(shown(s.value), style: DsTypography.bodyStrong.copyWith(color: s.color ?? onHero).tabular);
    return ClipRRect(
      borderRadius: FinSpace.brHero,
      child: Container(
        color: FinColors.hero(context),
        child: Stack(
          children: [
            const Positioned.fill(child: FinPattern()),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.xl, DsSpace.xl, DsSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          container: true,
                          label: spoken,
                          child: ExcludeSemantics(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(label, style: DsTypography.labelSm.copyWith(color: muted)),
                                const DsGap(DsSpace.xs),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: AlignmentDirectional.centerStart,
                                  child: FinAmountText(shown(amount), style: FinText.heroAmount(onHero)),
                                ),
                                if (caption != null) ...[const DsGap(DsSpace.xxs), Text(shown(caption!), style: DsTypography.bodySm.copyWith(color: muted))],
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (privacy || trailing != null)
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          if (privacy)
                            IconButton(
                              onPressed: FinPrivacy.toggle,
                              tooltip: (hidden ? "Show amounts" : "Hide amounts").tr,
                              icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: muted, size: 22),
                            ),
                          ?trailing,
                        ]),
                    ],
                  ),
                  if (stats.isNotEmpty) ...[
                    const DsGap(DsSpace.lg),
                    ExcludeSemantics(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: FinSpace.br,
                          border: Border.all(color: line),
                        ),
                        child: LayoutBuilder(
                          builder: (context, box) {
                            // Side by side while each figure keeps ~84dp
                            // (scaled with the text); else one per line.
                            final bool rows = box.maxWidth / stats.length < 84 * MediaQuery.textScalerOf(context).scale(1);
                            if (rows) {
                              return Column(
                                children: [
                                  for (final (i, s) in stats.indexed)
                                    Padding(
                                      padding: EdgeInsets.only(top: i == 0 ? 0 : DsSpace.xs),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(s.label, style: DsTypography.caption.copyWith(color: muted))),
                                          const DsGap(DsSpace.sm),
                                          Flexible(
                                            child: Align(
                                              alignment: AlignmentDirectional.centerEnd,
                                              child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerEnd, child: statValue(s)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            }
                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final (i, s) in stats.indexed) ...[
                                    if (i > 0) Container(width: 1, color: line, margin: const EdgeInsets.symmetric(horizontal: DsSpace.md)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(s.label, style: DsTypography.caption.copyWith(color: muted), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          const DsGap(DsSpace.xxs),
                                          FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: statValue(s)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  if (footer != null) ...[const DsGap(DsSpace.lg), footer!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hides the amounts of the cards that offer it (an eye on the card), for
/// the time the app is open.
abstract final class FinPrivacy {
  static final ValueNotifier<bool> hidden = ValueNotifier<bool>(false);

  static void toggle() => hidden.value = !hidden.value;

  /// Every amount inside [text] masked ("Return +4.3 % · +4 300 XAF" ->
  /// "Return •• % · •••••• XAF"): captions and list lines follow the eye too.
  static String maskAll(String text) {
    final String plain = text.replaceAll(RegExp('[\u2066-\u2069]'), '');
    return plain
        .replaceAllMapped(RegExp(r'[+\-−]?\d[\d\s\u00a0\u202f.,]*\s?([A-Z]{3})\b'), (m) => '•••••• ${m.group(1)}')
        .replaceAllMapped(RegExp(r'[+\-−]?\d+(?:[.,]\d+)?\s?%'), (_) => '•• %');
  }

  /// [child] rebuilt when the eye is toggled ([hidden] is its state).
  static Widget watch(Widget Function(bool hidden) child) => ValueListenableBuilder<bool>(valueListenable: hidden, builder: (_, h, __) => child(h));

  /// "245 000 XAF" -> "•••••• XAF": the currency stays, the figures go.
  static String mask(String value) {
    final String plain = value.replaceAll(RegExp('[\u2066-\u2069]'), '');
    final m = RegExp(r'^(.*?)\s([A-Z]{3})$').firstMatch(plain.trim());
    return m == null ? '••••••' : ltr('•••••• ${m.group(2)}');
  }
}

/// An amount with its currency code set smaller and lighter: "245 000"
/// then "XAF". Any other text is shown as it is.
class FinAmountText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const FinAmountText(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    final String plain = text.replaceAll(RegExp('[\u2066-\u2069]'), '');
    final m = RegExp(r'^(.*\S)\s([A-Z]{3})$').firstMatch(plain);
    if (m == null) return Text(text, style: style.tabular, maxLines: 1);
    final double size = style.fontSize ?? 32;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: m.group(1), style: style.tabular),
        TextSpan(
          text: ' ${m.group(2)}',
          style: style.copyWith(fontSize: size * 0.5, fontWeight: FontWeight.w600, color: style.color?.withValues(alpha: 0.72), letterSpacing: 0.6),
        ),
      ]),
      // The digits keep their order in right-to-left text.
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
  }
}

/// The engraved line pattern of the ink cards (a guilloche: overlapping
/// waves, very faint), drawn once and kept in its own layer.
class FinPattern extends StatelessWidget {
  final double opacity;

  const FinPattern({super.key, this.opacity = 0.07});

  @override
  Widget build(BuildContext context) => IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: _GuillochePainter(Colors.white.withValues(alpha: opacity)))));
}

class _GuillochePainter extends CustomPainter {
  final Color color;

  _GuillochePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    // Waves across the right part of the card, each a little shifted: the
    // interference gives the engraved look of banknotes.
    final double left = size.width * 0.35;
    final double w = size.width - left;
    final double cy = size.height * 0.42;
    final double amp = size.height * 0.22;
    for (int i = 0; i < 16; i++) {
      final path = Path();
      for (int x = 0; x <= w.ceil(); x += 4) {
        final double t = x / w;
        final double y = cy + amp * math.sin(t * math.pi * 2.2 + i * 0.38) * (0.55 + 0.45 * math.cos(t * math.pi * 1.3 + i * 0.12)) + (i - 8) * 3.2;
        if (x == 0) {
          path.moveTo(left + x, y);
        } else {
          path.lineTo(left + x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
    // A faint rosette in the corner.
    final Offset c = Offset(size.width * 0.92, size.height * 0.08);
    for (int r = 18; r <= 90; r += 9) {
      canvas.drawCircle(c, r.toDouble(), paint);
    }
  }

  @override
  bool shouldRepaint(_GuillochePainter old) => old.color != color;
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
    final Widget content = Padding(padding: padding, child: child);
    // Its own (transparent) Material inside the coloured box: list tiles,
    // checkbox / switch / radio tiles and the surface's own tap paint their
    // ink here, not on a Material the box would hide (a debug assertion).
    return Container(
      decoration: BoxDecoration(color: c.isDark ? c.surfaceRaised : c.surface, borderRadius: FinSpace.br, border: Border.all(color: c.border)),
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null ? content : InkWell(borderRadius: FinSpace.br, onTap: onTap, child: content),
      ),
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

  /// False for children that are surfaces of their own (FinMetrics, a
  /// chart card): they are not put on a second one.
  final bool surface;

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
    this.surface = true,
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
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(header: true, child: Text((title ?? '').toUpperCase(), style: FinText.sectionTitle(context))),
                  ),
                  if (actionLabel != null)
                    Semantics(
                      button: true,
                      child: InkWell(
                        onTap: onAction,
                        borderRadius: DsRadius.brSm,
                        // A comfortable target (48dp) for "See all" and the like.
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: DsSpace.xs),
                            child: Center(
                              widthFactor: 1,
                              child: Text(actionLabel!, style: DsTypography.labelSm.copyWith(color: FinColors.brand(context))),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (surface)
            FinSurface(
              padding: padding ?? const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, w) in items.indexed) ...[if (divided && i > 0) Divider(height: 1, thickness: 1, color: c.divider), w],
                ],
              ),
            )
          else
            ...items,
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

  /// Replaces the icon square (a date badge, an avatar).
  final Widget? leading;

  /// The amount and the amounts in the subtitle follow the privacy eye of
  /// the balance card (rows of the Home and Wallet tabs).
  final bool private;

  const FinListTile({
    super.key,
    this.leading,
    this.private = false,
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

  /// Narrower than this (scaled with the text size), the amount and status
  /// go under the title instead of beside it: a small phone or large text
  /// would otherwise squeeze the title or overflow the row.
  static const double _sideBySideWidth = 300;

  @override
  Widget build(BuildContext context) => private ? FinPrivacy.watch((hidden) => _tile(context, hidden)) : _tile(context, false);

  Widget _tile(BuildContext context, bool hidden) {
    final String? amount = this.amount == null ? null : (hidden ? FinPrivacy.maskAll(this.amount!) : this.amount);
    final String? subtitle = this.subtitle == null ? null : (hidden ? FinPrivacy.maskAll(this.subtitle!) : this.subtitle);
    final c = DsColors.of(context);
    final bool hasStatus = statusLabel != null && status != null;
    final bool hasFigures = amount != null || hasStatus;
    Widget figures(CrossAxisAlignment align) => Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (amount != null)
          Text(
            amount!,
            style: DsTypography.bodyStrong.copyWith(color: amountColor ?? c.textPrimary).tabular,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (hasStatus) ...[if (amount != null) const DsGap(DsSpace.xxs), FinStatusChip(status: status!, label: statusLabel!)],
      ],
    );
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        borderRadius: DsRadius.brSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
          child: LayoutBuilder(
            builder: (context, box) {
              final bool stacked = hasFigures && box.maxWidth < _sideBySideWidth * MediaQuery.textScalerOf(context).scale(1);
              return Row(
                children: [
                  leading ??
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: c.tone(iconTone).soft, borderRadius: DsRadius.brSm),
                        child: Icon(icon, size: 20, color: iconTone == DsTone.neutral ? c.textSecondary : c.tone(iconTone).strong),
                      ),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const DsGap(DsSpace.xxs),
                          // Three lines: a row's subtitle often ends with the
                          // detail that matters (a date, what is left to repay).
                          Text(
                            subtitle!,
                            style: DsTypography.caption.copyWith(color: c.textSecondary),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (stacked) ...[const DsGap(DsSpace.xs), figures(CrossAxisAlignment.start)],
                      ],
                    ),
                  ),
                  if (hasFigures && !stacked) ...[
                    const DsGap(DsSpace.sm),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: box.maxWidth * 0.45),
                      child: figures(CrossAxisAlignment.end),
                    ),
                  ],
                  if (trailing != null) ...[const DsGap(DsSpace.sm), trailing!],
                  // chevron_right mirrors itself in right-to-left text.
                  if (chevron) ...[const DsGap(DsSpace.xs), Icon(Icons.chevron_right_rounded, color: c.textMuted)],
                ],
              );
            },
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
              Text(m.label, style: DsTypography.caption.copyWith(color: c.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
              const DsGap(DsSpace.xxs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(m.value, style: DsTypography.titleSm.copyWith(color: m.color ?? c.textPrimary).tabular),
              ),
              if (m.sub != null) Text(m.sub!, style: DsTypography.caption.copyWith(color: c.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
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
    // Round buttons: translucent on the ink card, raised white on the page.
    final BoxDecoration circle = onHero
        ? BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.12), border: Border.all(color: Colors.white.withValues(alpha: 0.18)))
        : BoxDecoration(
            shape: BoxShape.circle,
            color: c.isDark ? c.surfaceRaised : c.surface,
            border: Border.all(color: c.border),
            boxShadow: c.isDark ? null : [BoxShadow(color: FinColors.navy.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
          );
    final text = onHero ? Colors.white : c.textPrimary;
    return LayoutBuilder(builder: (context, box) {
      // Four per row while each keeps 72 dp (scaled with the text), else
      // three, else two; four actions go two by two rather than 3 + 1.
      final double min = 72 * MediaQuery.textScalerOf(context).scale(1);
      double width(int n) => (box.maxWidth - DsSpace.sm * (n - 1)) / n;
      int perRow = [4, 3].firstWhere((n) => width(n) >= min, orElse: () => 2);
      if (perRow == 3 && actions.length == 4) perRow = 2;
      final double w = width(perRow);
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
                    customBorder: const StadiumBorder(),
                    child: Opacity(
                      opacity: a.onTap == null ? 0.45 : 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                        child: Column(children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: circle,
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

// ----------------------------------------------------------------- reload

/// Builds [builder] again from scratch when it calls retry: the streams it
/// creates subscribe anew (a failed Firestore stream does not recover).
class FinReload extends StatefulWidget {
  final Widget Function(BuildContext context, VoidCallback retry) builder;

  const FinReload({super.key, required this.builder});

  @override
  State<FinReload> createState() => _FinReloadState();
}

class _FinReloadState extends State<FinReload> {
  int _attempt = 0;

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: ValueKey(_attempt), child: widget.builder(context, () => setState(() => _attempt++)));
}

// ---------------------------------------------------------------- pickers

/// The date pickers in the finance navy wherever they are opened from: a
/// screen's own context sits above its FinScaffold's accent.
Widget _finAccent(BuildContext context, Widget? child) =>
    DsAccentScope(color: Theme.of(context).brightness == Brightness.dark ? FinColors.navyDark : FinColors.navy, child: child!);

Future<DateTime?> finPickDate(BuildContext context, {required DateTime initial, required DateTime first, required DateTime last}) =>
    showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last, builder: _finAccent);

Future<DateTimeRange?> finPickDateRange(BuildContext context, {DateTimeRange? initial, required DateTime first, required DateTime last}) =>
    showDateRangePicker(context: context, firstDate: first, lastDate: last, initialDateRange: initial, builder: _finAccent);

/// Loading / error / empty for a section, same footprint so layouts stay still.
abstract final class FinState {
  static Widget loading({int rows = 3}) => Padding(
    padding: const EdgeInsets.only(top: FinSpace.section),
    child: DsSkeletonList(itemCount: rows),
  );

  /// One record read live (a stream of a document): a skeleton until the
  /// first answer, an error with [onRetry], or [gone] when the record does
  /// not exist (deleted, never created) - never a skeleton for ever. Null
  /// when there is data to show.
  static Widget? of<T>(AsyncSnapshot<T?> snap, {String gone = "This is no longer available.", VoidCallback? onRetry}) {
    if (snap.hasError) return error("Could not load this. Check your connection and try again.".tr, onRetry: onRetry);
    if (snap.connectionState == ConnectionState.waiting && !snap.hasData) return loading();
    if (snap.data == null) return empty(Icons.search_off_rounded, gone.tr);
    return null;
  }

  static Widget error(String message, {VoidCallback? onRetry}) => Padding(
    padding: const EdgeInsets.only(top: FinSpace.section),
    child: DsErrorState(message: message, compact: true, onRetry: onRetry),
  );

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

// ------------------------------------------------------------- loaders

/// The state of a configuration loaded by [FinConfig].
class FinConfigState<T> {
  final T? config;
  final bool loading;
  final bool failed;
  final VoidCallback retry;

  const FinConfigState._({required this.config, required this.loading, required this.failed, required this.retry});

  bool get ready => !loading && !failed && config != null;

  /// What a screen shows instead of its content until [ready]: a skeleton,
  /// an error with Retry (offline, refused), or [unavailable] when the
  /// admin has not turned the service on. Null when ready.
  Widget? placeholder(IconData icon, String unavailable) {
    if (loading) return FinState.loading();
    if (failed) return FinState.error("Could not load this service. Check your connection and try again.".tr, onRetry: retry);
    if (config == null) return FinState.empty(icon, unavailable);
    return null;
  }
}

/// Loads a service's configuration (`finance_settings/{regionId}_*`) and builds
/// with its state; Retry loads it again, and so does a change the admin makes
/// to the customer's region or its settings (FinanceRegion.changes), keeping
/// the screen as it is while the new values load. A failed read is never
/// shown as "not available".
class FinConfig<T> extends StatefulWidget {
  final Future<T?> Function() load;
  final Widget Function(BuildContext context, FinConfigState<T> state) builder;

  const FinConfig({super.key, required this.load, required this.builder});

  @override
  State<FinConfig<T>> createState() => _FinConfigState<T>();
}

class _FinConfigState<T> extends State<FinConfig<T>> {
  late Future<T?> _future = widget.load();
  StreamSubscription<void>? _changes;

  @override
  void initState() {
    super.initState();
    _changes = FinanceRegion.changes.listen((_) {
      if (mounted) _retry();
    });
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  void _retry() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) => FutureBuilder<T?>(
    future: _future,
    builder: (context, snap) {
      // Reloading after a change keeps the values shown until the new ones arrive.
      final bool waiting = snap.connectionState == ConnectionState.waiting;
      final bool keep = waiting && snap.hasData;
      return widget.builder(
        context,
        FinConfigState<T>._(config: snap.data, loading: waiting && !keep, failed: !keep && snap.hasError, retry: _retry),
      );
    },
  );
}

/// Why the action below is not available yet - "To continue: amount,
/// signature" - so a disabled button is never a dead end. [items] are
/// already translated; nothing is shown when empty.
class FinMissing extends StatelessWidget {
  final List<String> items;

  const FinMissing(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final c = DsColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: c.textSecondary),
            const DsGap(DsSpace.xs),
            Expanded(
              child: Text('${"To continue".tr}: ${items.join(', ')}', style: DsTypography.caption.copyWith(color: c.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
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
  /// The tapped period (index into the full series); null = the latest.
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final int total = math.min(widget.labels.length, math.min(widget.a.length, widget.b.length));
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpace.lg),
        child: Text("No figures for this period yet.".tr, style: DsTypography.caption.copyWith(color: c.textSecondary)),
      );
    }
    final double maxV = [...widget.a.take(total), ...widget.b.take(total), 1.0].reduce(math.max);
    final double labelHeight = MediaQuery.textScalerOf(context).scale(16) + 4;
    return LayoutBuilder(
      builder: (context, box) {
        // As many recent periods as fit (>= 40dp each): 12 months on a tablet,
        // the last 6 or 7 on a small phone. The latest is always shown.
        final int fit = math.max(3, (box.maxWidth / 40).floor());
        final int start = math.max(0, total - fit);
        final int sel = (_selected ?? total - 1).clamp(start, total - 1);
        return Semantics(
          container: true,
          label: '${widget.aLabel} / ${widget.bLabel}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.labels[sel], style: DsTypography.labelSm.copyWith(color: c.textSecondary)),
              const DsGap(DsSpace.xs),
              Wrap(
                spacing: DsSpace.lg,
                runSpacing: DsSpace.xs,
                children: [
                  _legendValue(context, widget.aColor, widget.aLabel, widget.format(widget.a[sel])),
                  _legendValue(context, widget.bColor, widget.bLabel, widget.format(widget.b[sel])),
                ],
              ),
              const DsGap(DsSpace.md),
              SizedBox(
                height: widget.height + labelHeight,
                child: Stack(
                  children: [
                    // Gridlines at 0, 50 and 100 %.
                    for (final f in const [0.0, 0.5, 1.0])
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: f * (widget.height - 4) + labelHeight,
                        child: Container(height: 1, color: c.divider),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (int i = start; i < total; i++)
                          Expanded(
                            child: Semantics(
                              button: true,
                              selected: i == sel,
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
                                    SizedBox(
                                      height: labelHeight,
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Text(
                                          widget.labels[i].split(' ').first,
                                          maxLines: 1,
                                          overflow: TextOverflow.clip,
                                          softWrap: false,
                                          style: DsTypography.caption.copyWith(
                                            color: i == sel ? c.textPrimary : c.textSecondary,
                                            fontWeight: i == sel ? FontWeight.w700 : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bar(double f, Color color, bool selected) => AnimatedContainer(
    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : DsMotion.base,
    width: 10,
    height: math.max(2, f * (widget.height - 4)),
    decoration: BoxDecoration(
      color: selected ? color : color.withValues(alpha: 0.45),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
    ),
  );

  Widget _legendValue(BuildContext context, Color color, String label, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const DsGap(DsSpace.xs),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary)),
          Text(value, style: DsTypography.labelSm.copyWith(color: DsColors.of(context).textPrimary).tabular),
        ],
      ),
    ],
  );
}

/// A stacked share bar with a legend: allocation, budget splits.
class FinShareBar extends StatelessWidget {
  final List<(String, double, String)> parts;

  /// Adds each part's share of the total to its label; off when the label
  /// already carries the share the server worked out.
  final bool percent;

  const FinShareBar({super.key, required this.parts, this.percent = false});

  /// Eight distinct hues, each readable on the page in light and in dark.
  /// The legend names every part next to its colour and amount, so the
  /// colours are never the only way to tell the parts apart.
  static const List<Color> _light = [
    FinColors.navy, Color(0xFF0F766E), Color(0xFFB45309), Color(0xFF7C3AED), Color(0xFF0369A1), Color(0xFFBE123C), Color(0xFF15803D), Color(0xFF64748B),
  ];
  static const List<Color> _dark = [
    FinColors.navyDark, Color(0xFF2DD4BF), Color(0xFFFBBF24), Color(0xFFC4B5FD), Color(0xFF7DD3FC), Color(0xFFFDA4AF), Color(0xFF86EFAC), Color(0xFFCBD5E1),
  ];

  static List<Color> palette(BuildContext context) => DsColors.of(context).isDark ? _dark : _light;

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final colors = palette(context);
    final total = parts.fold<double>(0, (s, p) => s + p.$2);
    String label(String name, double v) => !percent ? name : '$name · ${ltr('${total <= 0 ? 0 : (v / total * 100).round()} %')}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ExcludeSemantics(
        child: ClipRRect(
          borderRadius: DsRadius.brPill,
          child: SizedBox(
            height: 10,
            child: Row(children: [
              for (final (i, p) in parts.indexed)
                if (p.$2 > 0) Expanded(flex: math.max(1, (p.$2 / (total == 0 ? 1 : total) * 1000).round()), child: Container(color: colors[i % colors.length])),
            ]),
          ),
        ),
      ),
      const DsGap(DsSpace.sm),
      for (final (i, p) in parts.indexed)
        MergeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
              const DsGap(DsSpace.sm),
              Expanded(
                child: Text(label(p.$1, p.$2), style: DsTypography.body.copyWith(color: c.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const DsGap(DsSpace.sm),
              Flexible(
                child: Text(p.$3, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary).tabular, textAlign: TextAlign.end, maxLines: 2),
              ),
            ]),
          ),
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

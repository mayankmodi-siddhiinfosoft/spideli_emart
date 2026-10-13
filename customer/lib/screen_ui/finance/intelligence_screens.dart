import 'dart:math' as math;

import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/service/finance_intel_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_financing_rules.dart';
import 'package:customer/utils/finance_intel_rules.dart';
import 'package:customer/utils/finance_investment_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

String _date(DateTime? d) => d == null ? '-' : ltr(DateFormat('dd MMM yyyy').format(d));

String _dateTime(DateTime? d) => d == null ? '-' : ltr(DateFormat('dd MMM yyyy, HH:mm').format(d));

Widget _caption(BuildContext context, String text) => Text(text, style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary));

/// Form sections: every field carries its own bottom spacing.
const EdgeInsets _formPadding = EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, 0);

/// List sections: rows carry their own vertical padding.
const EdgeInsets _listPadding = EdgeInsets.symmetric(horizontal: DsSpace.lg);

/// Where the text of a list row starts (icon 40 + gap 12), for lines under a row.
const double _rowTextStart = 52;

/// Sheets open above the screen (outside its accent scope): keep them navy.
Widget _navy(Widget child) => Builder(
      builder: (context) => DsAccentScope(color: Theme.of(context).brightness == Brightness.dark ? FinColors.navyDark : FinColors.navy, child: child),
    );

/// The direction of an indicator since its previous value.
IconData _trend(Indicator i) => switch (i.direction) {
      'up' => Icons.arrow_upward_rounded,
      'down' => Icons.arrow_downward_rounded,
      'flat' => Icons.arrow_forward_rounded,
      _ => Icons.insights_outlined,
    };

/// The previous value of an indicator, in its unit.
String _previous(Indicator i) => ltr('${formatNumber(i.previousValue!)}${i.unit == '%' ? ' %' : (i.unit.isEmpty ? '' : ' ${i.unit}')}');

String _kind(FxRate r) => (r.kind == 'official' ? "Official" : "Indicative").tr;

/// A history chart with its first and last points, read out for screen readers.
Widget _history(BuildContext context, List<double> values, String first, String last, String firstValue, String lastValue) => FinSection(
      title: "History".tr,
      children: [
        const DsGap(DsSpace.sm),
        Semantics(
          container: true,
          label: '${"History".tr}: $first $firstValue – $last $lastValue',
          child: ExcludeSemantics(child: FinanceLineChart(values: values)),
        ),
        const DsGap(DsSpace.xs),
        Row(children: [Expanded(child: _caption(context, first)), _caption(context, last)]),
        const DsGap(DsSpace.sm),
      ],
    );

abstract final class IntelLabels {
  static String country(String c) => const {
        'CM': 'Cameroon',
        'GA': 'Gabon',
        'GN': 'Guinea',
        'CI': "Côte d'Ivoire",
        'SN': 'Senegal',
        'RW': 'Rwanda',
        'CG': 'Congo',
        'TD': 'Chad',
        'CF': 'Central African Republic',
        'GQ': 'Equatorial Guinea',
      }[c] ??
      c;

  static String type(String t) => const {
        'equity': 'Shares',
        'loan': 'Loan',
        'revenue_share': 'Revenue share',
        'fund': 'Fund',
        'bond': 'Bond',
      }[t] ??
      t;

  static String reason(String k) => const {
        'sector': 'Your sectors',
        'country': 'Your countries',
        'type': 'Your types of investment',
        'ticket': 'Your amount',
        'horizon': 'Your time horizon',
      }[k] ??
      k;
}

/// Spideli Finance > Economic intelligence: indicators, exchange rates and
/// investment opportunities. `platform_settings/intelligence` must exist (admin).
class IntelligenceScreen extends StatefulWidget {
  const IntelligenceScreen({super.key});

  @override
  State<IntelligenceScreen> createState() => _IntelligenceScreenState();
}

class _IntelligenceScreenState extends State<IntelligenceScreen> {
  int _tab = 0;
  final Future<IntelligenceConfig?> _config = FinanceIntelService.config();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IntelligenceConfig?>(
      future: _config,
      builder: (context, cfgSnap) {
        final cfg = cfgSnap.data;
        final tabs = <(String, Widget Function())>[
          if (cfg?.indicators != null) ("Indicators", () => _Indicators(config: cfg!.indicators!)),
          if (cfg?.fx != null) ("Exchange rates", () => _Rates(config: cfg!.fx!)),
          if (cfg?.matching != null) ("Opportunities", () => _Opportunities(config: cfg!.matching!)),
        ];
        final int tab = tabs.isEmpty ? 0 : math.min(_tab, tabs.length - 1);
        return FinScaffold(
          title: "Economic intelligence".tr,
          body: FinBody(children: [
            if (cfgSnap.connectionState == ConnectionState.waiting)
              FinState.loading()
            else if (tabs.isEmpty)
              FinState.empty(Icons.insights_outlined, "Economic intelligence is not available yet.".tr)
            else ...[
              if (tabs.length > 1) DsSegmentedTabs(segments: [for (final t in tabs) DsSegment(t.$1.tr)], index: tab, onChanged: (i) => setState(() => _tab = i)),
              tabs[tab].$2(),
            ],
          ]),
        );
      },
    );
  }
}

// --------------------------------------------------------------- indicators

class _Indicators extends StatefulWidget {
  final IndicatorsConfig config;

  const _Indicators({required this.config});

  @override
  State<_Indicators> createState() => _IndicatorsState();
}

class _IndicatorsState extends State<_Indicators> {
  late String _country = widget.config.countries.first;

  @override
  Widget build(BuildContext context) {
    final bool choice = widget.config.countries.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (choice)
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.lg),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final c in widget.config.countries)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: DsSpace.sm),
                    child: ChoiceChip(label: Text(IntelLabels.country(c).tr), selected: _country == c, onSelected: (_) => setState(() => _country = c)),
                  ),
              ]),
            ),
          ),
        StreamBuilder<List<Indicator>>(
          key: ValueKey(_country),
          stream: FinanceIntelService.indicators(_country),
          builder: (context, snap) {
            if (snap.hasError) return FinState.error("Could not load the indicators.".tr);
            if (!snap.hasData) return FinState.loading(rows: 4);
            if (snap.data!.isEmpty) return FinState.empty(Icons.insights_outlined, "No indicator is published for this country yet.".tr);
            return FinSection(
              top: choice ? DsSpace.md : FinSpace.section,
              divided: true,
              padding: _listPadding,
              children: [for (final i in snap.data!) _IndicatorRow(indicator: i)],
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: DsSpace.sm, left: DsSpace.xxs, right: DsSpace.xxs),
          child: _caption(context, "Figures as published by the source shown on each one. Spideli does not modify them.".tr),
        ),
      ],
    );
  }
}

/// One indicator: name, value and trend, then where it comes from (always shown in full).
class _IndicatorRow extends StatelessWidget {
  final Indicator indicator;

  const _IndicatorRow({required this.indicator});

  @override
  Widget build(BuildContext context) {
    final i = indicator;
    return MergeSemantics(
      child: InkWell(
        onTap: () => Get.to(() => IndicatorScreen(indicator: i)),
        borderRadius: DsRadius.brSm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinListTile(
              icon: _trend(i),
              title: i.name,
              subtitle: [ltr(i.period), if (i.previousValue != null) '${"Previous".tr}: ${_previous(i)}'].join(' · '),
              amount: ltr(i.display),
              chevron: true,
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: _rowTextStart, bottom: DsSpace.md),
              child: _caption(context, '${"Source".tr}: ${i.source} · ${"Updated".tr} ${_date(i.updatedAt)}'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One indicator: value, change, history and its source.
class IndicatorScreen extends StatelessWidget {
  final Indicator indicator;

  const IndicatorScreen({super.key, required this.indicator});

  @override
  Widget build(BuildContext context) {
    final i = indicator;
    return FinScaffold(
      title: i.name,
      body: FinBody(children: [
        FinHeader(
          overline: '${IntelLabels.country(i.country).tr} · ${ltr(i.period)}',
          title: ltr(i.display),
          subtitle: i.previousValue == null ? null : '${"Previous".tr}: ${_previous(i)}',
          icon: _trend(i),
        ),
        StreamBuilder<List<(String, double)>>(
          stream: FinanceIntelService.indicatorHistory(i.id),
          builder: (context, snap) {
            final h = snap.data ?? const <(String, double)>[];
            if (h.length < 2) return const SizedBox.shrink();
            return _history(context, [for (final p in h) p.$2], ltr(h.first.$1), ltr(h.last.$1), ltr(formatNumber(h.first.$2)), ltr(formatNumber(h.last.$2)));
          },
        ),
        FinSection(
          title: "Source".tr,
          children: [
            FinRow("Published by".tr, i.source),
            FinRow("Period".tr, ltr(i.period)),
            FinRow("Updated".tr, _dateTime(i.updatedAt)),
            if (i.sourceUrl.isNotEmpty)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: DsButton.ghost(label: "Open the source".tr, icon: Icons.open_in_new_rounded, onPressed: () => Constant().launchURL(Uri.parse(i.sourceUrl))),
              ),
          ],
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------ exchange rates

class _Rates extends StatefulWidget {
  final FxConfig config;

  const _Rates({required this.config});

  @override
  State<_Rates> createState() => _RatesState();
}

class _RatesState extends State<_Rates> {
  final _amount = TextEditingController(text: '1');
  late String _from = widget.config.quotes.first;
  late String _to = widget.config.base;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _fmt(double v, String currency) => '${formatNumber(v, decimals: math.max(2, FinanceMoney.exponent(currency)))} $currency';

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final cfg = widget.config;
    final all = [cfg.base, ...cfg.quotes];
    return StreamBuilder<List<FxRate>>(
      stream: FinanceIntelService.rates(cfg.base),
      builder: (context, snap) {
        if (snap.hasError) return FinState.error("Could not load the exchange rates.".tr);
        if (!snap.hasData) return FinState.loading(rows: 4);
        final latest = FxConverter.latest(snap.data!, cfg.base);
        final double? amount = double.tryParse(_amount.text.replaceAll(',', '.').replaceAll(' ', ''));
        final double? result = amount == null ? null : FxConverter.convert(amount, _from, _to, cfg.base, latest);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinSection(
              title: "Converter".tr,
              padding: _formPadding,
              footnote: "Indicative rates for information. The rate applied to a payment or transfer is the one shown when you confirm it.".tr,
              children: [
                DsTextField(
                  label: "Amount".tr,
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: DsDropdown<String>(
                      label: "From".tr,
                      value: _from,
                      items: [for (final cur in all) DropdownMenuItem(value: cur, child: Text(cur))],
                      onChanged: (v) => setState(() => _from = v ?? _from),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(DsSpace.xs, 0, DsSpace.xs, DsSpace.lg),
                    child: DsIconButton(
                      icon: Icons.swap_horiz_rounded,
                      semanticLabel: "Swap".tr,
                      variant: DsIconButtonVariant.outlined,
                      onPressed: () => setState(() {
                        final f = _from;
                        _from = _to;
                        _to = f;
                      }),
                    ),
                  ),
                  Expanded(
                    child: DsDropdown<String>(
                      label: "To".tr,
                      value: _to,
                      items: [for (final cur in all) DropdownMenuItem(value: cur, child: Text(cur))],
                      onChanged: (v) => setState(() => _to = v ?? _to),
                    ),
                  ),
                ]),
                Divider(height: 1, thickness: 1, color: c.divider),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                  child: Semantics(
                    liveRegion: true,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _caption(context, amount == null ? '-' : ltr('${_fmt(amount, _from)} =')),
                      const DsGap(DsSpace.xxs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(result == null ? '-' : ltr(_fmt(result, _to)), style: FinText.amount.copyWith(color: c.textPrimary)),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
            FinSection(
              title: "Latest rates".tr,
              divided: true,
              padding: _listPadding,
              children: [
                if (latest.isEmpty)
                  Padding(padding: const EdgeInsets.symmetric(vertical: DsSpace.lg), child: _caption(context, "No exchange rate is published yet.".tr)),
                for (final q in cfg.quotes)
                  if (latest[q] != null)
                    FinListTile(
                      icon: Icons.currency_exchange_rounded,
                      iconTone: DsTone.brand,
                      title: ltr('1 $q'),
                      subtitle: '${"Source".tr}: ${latest[q]!.source} · ${_dateTime(latest[q]!.observedAt)}',
                      amount: ltr(_fmt(latest[q]!.rate, cfg.base)),
                      status: latest[q]!.kind,
                      statusLabel: _kind(latest[q]!),
                      chevron: true,
                      onTap: () => Get.to(() => RateScreen(from: q, to: cfg.base)),
                    ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class RateScreen extends StatelessWidget {
  final String from;
  final String to;

  const RateScreen({super.key, required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    return FinScaffold(
      title: ltr('$from / $to'),
      body: StreamBuilder<List<FxRate>>(
        stream: FinanceIntelService.rateHistory(from, to),
        builder: (context, snap) {
          if (snap.hasError) return FinBody(children: [FinState.error("Could not load the exchange rates.".tr)]);
          if (!snap.hasData) return FinBody(children: [FinState.loading(rows: 3)]);
          final h = snap.data!;
          if (h.isEmpty) return FinBody(children: [FinState.empty(Icons.currency_exchange_rounded, "No exchange rate is published yet.".tr)]);
          final last = h.last;
          return FinBody(children: [
            FinHeader(
              overline: ltr('1 $from'),
              title: ltr('${formatNumber(last.rate, decimals: 4)} $to'),
              status: last.kind,
              statusLabel: _kind(last),
              icon: Icons.currency_exchange_rounded,
            ),
            if (h.length > 1)
              _history(
                context,
                [for (final r in h) r.rate],
                _date(h.first.observedAt),
                _date(h.last.observedAt),
                ltr(formatNumber(h.first.rate, decimals: 4)),
                ltr(formatNumber(h.last.rate, decimals: 4)),
              ),
            FinSection(
              title: "Source".tr,
              footnote: "Indicative rates for information. The rate applied to a payment or transfer is the one shown when you confirm it.".tr,
              children: [
                FinRow("Published by".tr, last.source),
                FinRow("Updated".tr, _dateTime(last.observedAt)),
              ],
            ),
          ]);
        },
      ),
    );
  }
}

// ------------------------------------------------------------ opportunities

class _Opportunities extends StatelessWidget {
  final MatchingConfig config;

  const _Opportunities({required this.config});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FinanceIntelService.investorProfile(),
      builder: (context, ps) {
        final profile = InvestorProfile.fromMap(ps.data);
        return StreamBuilder<List<Opportunity>>(
          stream: FinanceIntelService.opportunities(),
          builder: (context, snap) {
            if (snap.hasError) return FinState.error("Could not load the opportunities.".tr);
            if (!snap.hasData) return FinState.loading();
            final now = DateTime.now();
            final open = snap.data!.where((o) => o.isOpen(now)).toList();
            final scored = [
              for (final o in open) (o, profile == null ? null : (MatchRules.eligible(profile, o, now) ? MatchRules.score(profile, o, config.weights) : null)),
            ];
            final suggested = scored.where((s) => s.$2 != null && s.$2!.score >= config.minScore).toList()..sort((a, b) => b.$2!.score.compareTo(a.$2!.score));
            final others = scored.where((s) => !suggested.contains(s)).toList()
              ..sort((a, b) => (a.$1.closingDate ?? DateTime(9999)).compareTo(b.$1.closingDate ?? DateTime(9999)));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FinSection(
                  padding: _listPadding,
                  children: [
                    FinListTile(
                      icon: Icons.tune_rounded,
                      iconTone: profile == null ? DsTone.warning : DsTone.brand,
                      title: "My investor preferences".tr,
                      subtitle: profile == null
                          ? "Tell us what you look for to see the opportunities that fit you.".tr
                          : '${FinanceMoney.format(profile.minTicket, profile.currency)} - ${FinanceMoney.format(profile.maxTicket, profile.currency)} · ${"Risk up to".tr} ${ltr('${profile.maxRisk}/7')}',
                      chevron: true,
                      onTap: () => Get.to(() => InvestorProfileScreen(config: config, profile: ps.data)),
                    ),
                  ],
                ),
                if (config.eligibility.isNotEmpty) FinNotice(config.eligibility, title: "Who can invest".tr),
                if (suggested.isNotEmpty)
                  FinSection(
                    title: "Suggested for you".tr,
                    divided: true,
                    padding: _listPadding,
                    children: [for (final (o, m) in suggested) _OpportunityRow(opportunity: o, match: m)],
                  ),
                if (others.isEmpty && suggested.isEmpty)
                  FinState.empty(Icons.lightbulb_outline_rounded, "No opportunity is open right now.".tr)
                else if (others.isNotEmpty)
                  FinSection(
                    title: (suggested.isEmpty ? "Open opportunities" : "Other opportunities").tr,
                    divided: true,
                    padding: _listPadding,
                    children: [for (final (o, _) in others) _OpportunityRow(opportunity: o, match: null)],
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: DsSpace.md, left: DsSpace.xxs, right: DsSpace.xxs),
                  child: _caption(
                    context,
                    "Opportunities are presented by their owners after a review by Spideli. Investing carries risks, including the loss of the money invested. Targets are not guarantees."
                        .tr,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// An opportunity: what it is, the smallest ticket, how well it matches and how much is raised.
class _OpportunityRow extends StatelessWidget {
  final Opportunity opportunity;
  final MatchResult? match;

  const _OpportunityRow({required this.opportunity, required this.match});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final o = opportunity;
    final m = match;
    final bool extra = m != null || o.targetAmount > 0;
    return MergeSemantics(
      child: InkWell(
        onTap: () => Get.to(() => OpportunityScreen(opportunityId: o.id, match: m)),
        borderRadius: DsRadius.brSm,
        child: Padding(
          padding: EdgeInsets.only(bottom: extra ? DsSpace.md : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FinListTile(
                icon: m != null ? Icons.auto_awesome_rounded : Icons.lightbulb_outline_rounded,
                iconTone: m != null ? DsTone.success : DsTone.brand,
                title: o.title,
                subtitle: [FinancingLabels.sector(o.sector).tr, IntelLabels.country(o.country).tr, IntelLabels.type(o.type).tr].join(' · '),
                amount: '${"From".tr} ${FinanceMoney.format(o.minTicket, o.currency)}',
                chevron: true,
              ),
              if (m != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: _rowTextStart),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    DsBadge(label: ltr('${m.score} %'), tone: DsTone.success, small: true),
                    const DsGap(DsSpace.sm),
                    Expanded(
                      child: Text(m.reasons.map((r) => IntelLabels.reason(r).tr).join(', '), style: DsTypography.caption.copyWith(color: c.textSecondary)),
                    ),
                  ]),
                ),
              if (o.targetAmount > 0)
                Padding(
                  padding: EdgeInsetsDirectional.only(start: _rowTextStart, top: m != null ? DsSpace.sm : 0),
                  child: FinProgress(value: o.progress, label: "Raised".tr),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One opportunity, and the user's interest (no investment happens here).
class OpportunityScreen extends StatelessWidget {
  final String opportunityId;
  final MatchResult? match;

  const OpportunityScreen({super.key, required this.opportunityId, this.match});

  Future<void> _interested(BuildContext context, Opportunity o) async {
    final message = TextEditingController();
    final ok = await finSheet<bool>(
      title: "I am interested".tr,
      child: _navy(Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Your name and email are shared with the project owner so they can contact you. No money is committed.".tr,
              style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary),
            ),
            const DsGap(DsSpace.md),
            DsTextField(label: "Message (optional)".tr, controller: message, maxLines: 3, maxLength: 500),
            DsButton.primary(label: "Share my interest".tr, expand: true, onPressed: () => Get.back(result: true)),
          ],
        ),
      )),
    );
    if (ok == true) await FinanceUi.run(() => FinanceIntelService.respond(o.id, true, message: message.text.trim()), success: "Interest sent");
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Opportunity?>(
      stream: FinanceIntelService.opportunity(opportunityId),
      builder: (context, snap) {
        final o = snap.data;
        final bool open = o != null && o.isOpen(DateTime.now());
        return FinScaffold(
          title: "Opportunity".tr,
          bottomBar: !open
              ? null
              : DsStickyBar(
                  child: FinanceKycGate(
                    builder: (context, verified) => Row(children: [
                      Expanded(child: DsButton.secondary(label: "Not for me".tr, onPressed: () => FinanceUi.run(() => FinanceIntelService.respond(o.id, false), success: "Hidden"))),
                      const DsGap(DsSpace.sm),
                      Expanded(child: DsButton.primary(label: "I am interested".tr, onPressed: verified ? () => _interested(context, o) : null)),
                    ]),
                  ),
                ),
          body: snap.hasError
              ? FinBody(children: [FinState.error("Could not load this opportunity.".tr)])
              : o == null
                  ? FinBody(children: [FinState.loading(rows: 4)])
                  : FinBody(children: [
                      FinHeader(
                        overline: o.ownerName.isEmpty ? null : '${"Presented by".tr} ${o.ownerName}',
                        title: o.title,
                        subtitle: o.summary.isEmpty ? null : o.summary,
                        status: open ? null : 'closed',
                        statusLabel: open ? null : "Closed".tr,
                        icon: Icons.lightbulb_outline_rounded,
                        below: o.targetAmount > 0
                            ? FinProgress(
                                value: o.progress,
                                label: '${"Raised".tr} ${FinanceMoney.format(o.raisedAmount, o.currency)} / ${FinanceMoney.format(o.targetAmount, o.currency)}',
                              )
                            : null,
                      ),
                      if (match != null)
                        FinNotice(
                          match!.reasons.map((r) => IntelLabels.reason(r).tr).join(', '),
                          title: '${"Matches your preferences".tr}: ${ltr('${match!.score} %')}',
                          tone: DsTone.success,
                        ),
                      FinSection(
                        title: "Key facts".tr,
                        children: [
                          FinRow("Sector".tr, FinancingLabels.sector(o.sector).tr),
                          FinRow("Country".tr, IntelLabels.country(o.country).tr),
                          FinRow("Type".tr, IntelLabels.type(o.type).tr),
                          FinRow("Minimum ticket".tr, FinanceMoney.format(o.minTicket, o.currency)),
                          if (o.targetAmount > 0) FinRow("Raised".tr, '${FinanceMoney.format(o.raisedAmount, o.currency)} / ${FinanceMoney.format(o.targetAmount, o.currency)}'),
                          if (o.horizonMonths > 0) FinRow("Horizon".tr, '${o.horizonMonths} ${"months".tr}'),
                          FinRow("Risk level".tr, '${RiskScale.label(o.riskLevel).tr} · ${ltr('${o.riskLevel}/7')}'),
                          if (o.targetReturnPercent != null) FinRow("Target return (not guaranteed)".tr, InvestmentLabels.percent(o.targetReturnPercent)),
                          if (o.closingDate != null) FinRow("Closes on".tr, _date(o.closingDate)),
                        ],
                      ),
                      FinNotice(
                        "Investing in a company is risky: you can lose all the money invested, and it can be hard to sell your stake. Only invest what you can afford to lose, and read the documents the owner provides."
                            .tr,
                        tone: DsTone.warning,
                      ),
                    ]),
        );
      },
    );
  }
}

/// What the investor looks for; the server uses it to suggest matches.
class InvestorProfileScreen extends StatefulWidget {
  final MatchingConfig config;
  final Map<String, dynamic>? profile;

  const InvestorProfileScreen({super.key, required this.config, this.profile});

  @override
  State<InvestorProfileScreen> createState() => _InvestorProfileScreenState();
}

class _InvestorProfileScreenState extends State<InvestorProfileScreen> {
  late final Map<String, dynamic> _p = widget.profile ?? const {};
  late final Set<String> _sectors = {...(_p['sectors'] is List ? (_p['sectors'] as List).map((e) => e.toString()) : const <String>[])};
  late final Set<String> _countries = {...(_p['countries'] is List ? (_p['countries'] as List).map((e) => e.toString()) : const <String>[])};
  late final Set<String> _types = {...(_p['types'] is List ? (_p['types'] as List).map((e) => e.toString()) : const <String>[])};
  late String _currency = widget.config.currencies.contains(_p['currency']) ? _p['currency'].toString() : widget.config.currencies.first;
  late final _min = TextEditingController(text: _p['minTicket'] is num && FinanceMoney.exponent(_currency) == 0 ? '${(_p['minTicket'] as num).round()}' : '');
  late final _max = TextEditingController(text: _p['maxTicket'] is num && FinanceMoney.exponent(_currency) == 0 ? '${(_p['maxTicket'] as num).round()}' : '');
  late double _risk = (FinanceSummary.intOf(_p['maxRisk']) == 0 ? 4 : FinanceSummary.intOf(_p['maxRisk'])).clamp(1, 7).toDouble();
  late int _horizon = FinanceSummary.intOf(_p['maxHorizonMonths']);

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final int min = _min.text.trim().isEmpty ? 0 : (FinanceAmount.parse(_min.text, _currency) ?? -1);
    final int? max = FinanceAmount.parse(_max.text, _currency);
    if (min < 0 || max == null || max < min) return ShowToastDialog.showToast("Check the amounts.".tr);
    final ok = await FinanceUi.run(
      () => FinanceIntelService.saveInvestorProfile({
        'currency': _currency,
        'sectors': _sectors.toList(),
        'countries': _countries.toList(),
        'types': _types.toList(),
        'minTicket': min,
        'maxTicket': max,
        'maxRisk': _risk.round(),
        'maxHorizonMonths': _horizon,
      }),
      success: "Preferences saved",
    );
    if (ok) Get.back();
  }

  Widget _chips(Iterable<String> options, Set<String> selected, String Function(String) label) => Wrap(
        spacing: DsSpace.sm,
        runSpacing: DsSpace.xs,
        children: [
          for (final o in options)
            FilterChip(
              label: Text(label(o).tr),
              selected: selected.contains(o),
              onSelected: (v) => setState(() => v ? selected.add(o) : selected.remove(o)),
            ),
        ],
      );

  /// A group of choices; none selected means all.
  Widget _choices(String title, Iterable<String> options, Set<String> selected, String Function(String) label) => FinSection(
        title: title,
        footnote: "None selected = all.".tr,
        padding: const EdgeInsets.all(DsSpace.lg),
        children: [_chips(options, selected, label)],
      );

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final cfg = widget.config;
    return FinScaffold(
      title: "My investor preferences".tr,
      bottomBar: DsStickyBar(child: DsButton.primary(label: "Save".tr, size: DsButtonSize.lg, expand: true, onPressed: _save)),
      body: FinBody(children: [
        FinSection(
          title: "Amount per investment".tr,
          top: 0,
          padding: _formPadding,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: DsTextField(label: "From".tr, controller: _min, keyboardType: TextInputType.number)),
              const DsGap(DsSpace.sm),
              Expanded(child: DsTextField(label: "Up to".tr, controller: _max, keyboardType: TextInputType.number, requiredMark: true)),
              if (cfg.currencies.length > 1) ...[
                const DsGap(DsSpace.sm),
                SizedBox(
                  width: 100,
                  child: DsDropdown<String>(
                    label: "Currency".tr,
                    value: _currency,
                    items: [for (final cur in cfg.currencies) DropdownMenuItem(value: cur, child: Text(cur))],
                    onChanged: (v) => setState(() => _currency = v ?? _currency),
                  ),
                ),
              ],
            ]),
          ],
        ),
        FinSection(
          title: "Risk and horizon".tr,
          padding: _formPadding,
          children: [
            Text(
              '${"Highest risk I accept".tr}: ${ltr('${_risk.round()}/7')} · ${RiskScale.label(_risk.round()).tr}',
              style: DsTypography.label.copyWith(color: c.textPrimary),
            ),
            Slider(value: _risk, min: 1, max: 7, divisions: 6, label: '${_risk.round()}', onChanged: (v) => setState(() => _risk = v)),
            const DsGap(DsSpace.sm),
            DsDropdown<int>(
              label: "Longest time I can invest for".tr,
              value: _horizon,
              items: [
                DropdownMenuItem(value: 0, child: Text("No limit".tr)),
                for (final m in const [12, 24, 36, 60, 120]) DropdownMenuItem(value: m, child: Text('$m ${"months".tr}')),
              ],
              onChanged: (v) => setState(() => _horizon = v ?? 0),
            ),
          ],
        ),
        if (cfg.sectors.isNotEmpty) _choices("Sectors".tr, cfg.sectors, _sectors, FinancingLabels.sector),
        if (cfg.countries.isNotEmpty) _choices("Countries".tr, cfg.countries, _countries, IntelLabels.country),
        if (cfg.types.isNotEmpty) _choices("Types of investment".tr, cfg.types, _types, IntelLabels.type),
      ]),
    );
  }
}

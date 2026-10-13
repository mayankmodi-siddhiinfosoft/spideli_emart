import 'dart:math' as math;

import 'package:customer/constant/constant.dart';
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

Widget _row(BuildContext context, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary))),
          const DsGap(DsSpace.sm),
          Flexible(child: Align(alignment: AlignmentDirectional.centerEnd, child: Text(value, textAlign: TextAlign.end, style: DsTypography.bodyStrong.tabular))),
        ],
      ),
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
        return DsScaffold(
          title: "Economic intelligence".tr,
          maxContentWidth: DsLayout.contentMax,
          body: cfgSnap.connectionState == ConnectionState.waiting
              ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonList(itemCount: 3))
              : tabs.isEmpty
                  ? DsEmptyState(icon: Icons.insights_outlined, title: "Economic intelligence is not available yet.".tr)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                      children: [
                        if (tabs.length > 1) ...[
                          DsSegmentedTabs(segments: [for (final t in tabs) DsSegment(t.$1.tr)], index: tab, onChanged: (i) => setState(() => _tab = i)),
                          const DsGap(DsSpace.lg),
                        ],
                        tabs[tab].$2(),
                      ],
                    ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.config.countries.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final c in widget.config.countries)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: DsSpace.sm),
                  child: ChoiceChip(label: Text(IntelLabels.country(c).tr), selected: _country == c, onSelected: (_) => setState(() => _country = c)),
                ),
            ]),
          ),
        const DsGap(DsSpace.md),
        StreamBuilder<List<Indicator>>(
          key: ValueKey(_country),
          stream: FinanceIntelService.indicators(_country),
          builder: (context, snap) {
            if (snap.hasError) return DsErrorState(message: "Could not load the indicators.".tr, compact: true);
            if (!snap.hasData) return const DsSkeletonList(itemCount: 4);
            if (snap.data!.isEmpty) return DsEmptyState(icon: Icons.insights_outlined, title: "No indicator is published for this country yet.".tr, compact: true);
            return Column(children: [for (final i in snap.data!) _IndicatorCard(indicator: i)]);
          },
        ),
        const DsGap(DsSpace.sm),
        _caption(context, "Figures as published by the source shown on each one. Spideli does not modify them.".tr),
      ],
    );
  }
}

class _IndicatorCard extends StatelessWidget {
  final Indicator indicator;

  const _IndicatorCard({required this.indicator});

  @override
  Widget build(BuildContext context) {
    final i = indicator;
    final c = DsColors.of(context);
    final IconData? arrow = switch (i.direction) {
      'up' => Icons.arrow_upward_rounded,
      'down' => Icons.arrow_downward_rounded,
      'flat' => Icons.arrow_forward_rounded,
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: DsCard.outlined(
        onTap: () => Get.to(() => IndicatorScreen(indicator: i)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text(i.name, style: DsTypography.titleSm)),
              Text(i.display, style: DsTypography.titleSm.tabular),
              if (arrow != null) ...[const DsGap(DsSpace.xs), Icon(arrow, size: 18, color: c.textSecondary)],
            ]),
            const DsGap(DsSpace.xs),
            _caption(context, '${i.period} · ${"Source".tr}: ${i.source} · ${"Updated".tr} ${_date(i.updatedAt)}'),
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
    return DsScaffold(
      title: i.name,
      maxContentWidth: DsLayout.contentMax,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        children: [
          DsCard.tinted(
            tone: DsTone.brand,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _caption(context, '${IntelLabels.country(i.country).tr} · ${i.period}'),
              Text(i.display, style: DsTypography.title.tabular),
              if (i.previousValue != null) _caption(context, '${"Previous".tr}: ${formatNumber(i.previousValue!)}${i.unit == '%' ? ' %' : (i.unit.isEmpty ? '' : ' ${i.unit}')}'),
            ]),
          ),
          StreamBuilder<List<(String, double)>>(
            stream: FinanceIntelService.indicatorHistory(i.id),
            builder: (context, snap) {
              final h = snap.data ?? const <(String, double)>[];
              if (h.length < 2) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: DsSpace.md),
                child: DsFormSection(
                  title: "History".tr,
                  icon: Icons.show_chart_rounded,
                  children: [
                    FinanceLineChart(values: [for (final p in h) p.$2]),
                    const DsGap(DsSpace.xs),
                    Row(children: [Expanded(child: _caption(context, h.first.$1)), _caption(context, h.last.$1)]),
                  ],
                ),
              );
            },
          ),
          const DsGap(DsSpace.md),
          DsFormSection(
            title: "Source".tr,
            icon: Icons.verified_outlined,
            children: [
              _row(context, "Published by".tr, i.source),
              _row(context, "Period".tr, i.period),
              _row(context, "Updated".tr, _dateTime(i.updatedAt)),
              if (i.sourceUrl.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DsButton.ghost(label: "Open the source".tr, icon: Icons.open_in_new_rounded, onPressed: () => Constant().launchURL(Uri.parse(i.sourceUrl))),
                ),
            ],
          ),
        ],
      ),
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
    final cfg = widget.config;
    final all = [cfg.base, ...cfg.quotes];
    return StreamBuilder<List<FxRate>>(
      stream: FinanceIntelService.rates(cfg.base),
      builder: (context, snap) {
        if (snap.hasError) return DsErrorState(message: "Could not load the exchange rates.".tr, compact: true);
        if (!snap.hasData) return const DsSkeletonList(itemCount: 4);
        final latest = FxConverter.latest(snap.data!, cfg.base);
        final double? amount = double.tryParse(_amount.text.replaceAll(',', '.').replaceAll(' ', ''));
        final double? result = amount == null ? null : FxConverter.convert(amount, _from, _to, cfg.base, latest);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsFormSection(
              title: "Converter".tr,
              icon: Icons.currency_exchange_rounded,
              children: [
                Row(children: [
                  Expanded(
                    child: DsTextField(
                      label: "Amount".tr,
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const DsGap(DsSpace.sm),
                  SizedBox(
                    width: 100,
                    child: DsDropdown<String>(
                      label: "From".tr,
                      value: _from,
                      items: [for (final c in all) DropdownMenuItem(value: c, child: Text(c))],
                      onChanged: (v) => setState(() => _from = v ?? _from),
                    ),
                  ),
                ]),
                Row(children: [
                  Expanded(
                    child: Text(result == null ? '-' : _fmt(result, _to), style: DsTypography.title.tabular),
                  ),
                  DsIconButton(
                    icon: Icons.swap_vert_rounded,
                    semanticLabel: "Swap".tr,
                    onPressed: () => setState(() {
                      final f = _from;
                      _from = _to;
                      _to = f;
                    }),
                  ),
                  const DsGap(DsSpace.sm),
                  SizedBox(
                    width: 100,
                    child: DsDropdown<String>(
                      label: "To".tr,
                      value: _to,
                      items: [for (final c in all) DropdownMenuItem(value: c, child: Text(c))],
                      onChanged: (v) => setState(() => _to = v ?? _to),
                    ),
                  ),
                ]),
                _caption(context, "Indicative rates for information. The rate applied to a payment or transfer is the one shown when you confirm it.".tr),
              ],
            ),
            const DsGap(DsSpace.md),
            DsFormSection(
              title: "Latest rates".tr,
              icon: Icons.table_rows_outlined,
              children: [
                if (latest.isEmpty) _caption(context, "No exchange rate is published yet.".tr),
                for (final q in cfg.quotes)
                  if (latest[q] != null)
                    DsListTile(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      leadingIcon: Icons.currency_exchange_rounded,
                      title: '1 $q = ${_fmt(latest[q]!.rate, cfg.base)}',
                      subtitle: '${"Source".tr}: ${latest[q]!.source} · ${_dateTime(latest[q]!.observedAt)}',
                      trailing: DsBadge(label: (latest[q]!.kind == 'official' ? "Official" : "Indicative").tr, small: true),
                      showChevron: true,
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
    return DsScaffold(
      title: '$from / $to',
      maxContentWidth: DsLayout.contentMax,
      body: StreamBuilder<List<FxRate>>(
        stream: FinanceIntelService.rateHistory(from, to),
        builder: (context, snap) {
          if (snap.hasError) return DsErrorState(message: "Could not load the exchange rates.".tr);
          if (!snap.hasData) return const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 3));
          final h = snap.data!;
          if (h.isEmpty) return DsEmptyState(icon: Icons.currency_exchange_rounded, title: "No exchange rate is published yet.".tr);
          final last = h.last;
          return ListView(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
            children: [
              DsCard.tinted(
                tone: DsTone.brand,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('1 $from = ${formatNumber(last.rate, decimals: 4)} $to', style: DsTypography.title.tabular),
                  _caption(context, '${"Source".tr}: ${last.source} · ${_dateTime(last.observedAt)}'),
                ]),
              ),
              if (h.length > 1) ...[
                const DsGap(DsSpace.md),
                DsFormSection(
                  title: "History".tr,
                  icon: Icons.show_chart_rounded,
                  children: [
                    FinanceLineChart(values: [for (final r in h) r.rate]),
                    const DsGap(DsSpace.xs),
                    Row(children: [Expanded(child: _caption(context, _date(h.first.observedAt))), _caption(context, _date(h.last.observedAt))]),
                  ],
                ),
              ],
            ],
          );
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
            if (snap.hasError) return DsErrorState(message: "Could not load the opportunities.".tr, compact: true);
            if (!snap.hasData) return const DsSkeletonList(itemCount: 3);
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
                DsCard.outlined(
                  onTap: () => Get.to(() => InvestorProfileScreen(config: config, profile: ps.data)),
                  child: Row(children: [
                    DsIconWell(icon: Icons.tune_rounded, tone: profile == null ? DsTone.warning : DsTone.brand),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("My investor preferences".tr, style: DsTypography.titleSm),
                        _caption(
                          context,
                          profile == null
                              ? "Tell us what you look for to see the opportunities that fit you.".tr
                              : '${FinanceMoney.format(profile.minTicket, profile.currency)} - ${FinanceMoney.format(profile.maxTicket, profile.currency)} · ${"Risk up to".tr} ${profile.maxRisk}/7',
                        ),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ]),
                ),
                if (config.eligibility.isNotEmpty) ...[
                  const DsGap(DsSpace.sm),
                  DsInlineAlert(tone: DsTone.info, title: "Who can invest".tr, message: config.eligibility),
                ],
                if (suggested.isNotEmpty) ...[
                  const DsGap(DsSpace.lg),
                  Text("Suggested for you".tr, style: DsTypography.titleSm),
                  const DsGap(DsSpace.sm),
                  for (final (o, m) in suggested) _OpportunityCard(opportunity: o, match: m),
                ],
                const DsGap(DsSpace.lg),
                Text((suggested.isEmpty ? "Open opportunities" : "Other opportunities").tr, style: DsTypography.titleSm),
                const DsGap(DsSpace.sm),
                if (others.isEmpty && suggested.isEmpty) DsEmptyState(icon: Icons.lightbulb_outline_rounded, title: "No opportunity is open right now.".tr, compact: true),
                for (final (o, _) in others) _OpportunityCard(opportunity: o, match: null),
                const DsGap(DsSpace.sm),
                _caption(context, "Opportunities are presented by their owners after a review by Spideli. Investing carries risks, including the loss of the money invested. Targets are not guarantees.".tr),
              ],
            );
          },
        );
      },
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  final Opportunity opportunity;
  final MatchResult? match;

  const _OpportunityCard({required this.opportunity, required this.match});

  @override
  Widget build(BuildContext context) {
    final o = opportunity;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: DsCard.outlined(
        onTap: () => Get.to(() => OpportunityScreen(opportunityId: o.id, match: match)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text(o.title, style: DsTypography.titleSm)),
              if (match != null) DsBadge(label: '${match!.score} %', tone: DsTone.success, icon: Icons.auto_awesome_rounded, small: true),
            ]),
            _caption(context, [FinancingLabels.sector(o.sector).tr, IntelLabels.country(o.country).tr, IntelLabels.type(o.type).tr].join(' · ')),
            const DsGap(DsSpace.sm),
            _row(context, "From".tr, FinanceMoney.format(o.minTicket, o.currency)),
            if (o.targetAmount > 0) ...[
              const DsGap(DsSpace.xs),
              DsProgressBar(value: o.progress, showPercent: true),
            ],
          ],
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
    final ok = await DsBottomSheet.show<bool>(
      title: "I am interested".tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Your name and email are shared with the project owner so they can contact you. No money is committed.".tr, style: DsTypography.body),
          const DsGap(DsSpace.md),
          DsTextField(label: "Message (optional)".tr, controller: message, maxLines: 3, maxLength: 500),
          DsButton.primary(label: "Share my interest".tr, expand: true, onPressed: () => Get.back(result: true)),
        ],
      ),
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
        return DsScaffold(
          title: "Opportunity".tr,
          maxContentWidth: DsLayout.contentMax,
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
              ? DsErrorState(message: "Could not load this opportunity.".tr)
              : o == null
                  ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 4))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                      children: [
                        Text(o.title, style: DsTypography.title),
                        if (o.ownerName.isNotEmpty) _caption(context, '${"Presented by".tr} ${o.ownerName}'),
                        if (o.summary.isNotEmpty) Padding(padding: const EdgeInsets.only(top: DsSpace.sm), child: Text(o.summary, style: DsTypography.body)),
                        if (match != null) ...[
                          const DsGap(DsSpace.md),
                          DsInlineAlert(
                            tone: DsTone.success,
                            title: '${"Matches your preferences".tr}: ${match!.score} %',
                            message: match!.reasons.map((r) => IntelLabels.reason(r).tr).join(', '),
                          ),
                        ],
                        const DsGap(DsSpace.md),
                        DsFormSection(
                          title: "Key facts".tr,
                          icon: Icons.fact_check_outlined,
                          children: [
                            _row(context, "Sector".tr, FinancingLabels.sector(o.sector).tr),
                            _row(context, "Country".tr, IntelLabels.country(o.country).tr),
                            _row(context, "Type".tr, IntelLabels.type(o.type).tr),
                            _row(context, "Minimum ticket".tr, FinanceMoney.format(o.minTicket, o.currency)),
                            if (o.targetAmount > 0) _row(context, "Raised".tr, '${FinanceMoney.format(o.raisedAmount, o.currency)} / ${FinanceMoney.format(o.targetAmount, o.currency)}'),
                            if (o.horizonMonths > 0) _row(context, "Horizon".tr, '${o.horizonMonths} ${"months".tr}'),
                            _row(context, "Risk level".tr, '${RiskScale.label(o.riskLevel).tr} · ${o.riskLevel}/7'),
                            if (o.targetReturnPercent != null) _row(context, "Target return (not guaranteed)".tr, InvestmentLabels.percent(o.targetReturnPercent)),
                            if (o.closingDate != null) _row(context, "Closes on".tr, _date(o.closingDate)),
                          ],
                        ),
                        const DsGap(DsSpace.md),
                        DsInlineAlert(
                          tone: DsTone.warning,
                          message: "Investing in a company is risky: you can lose all the money invested, and it can be hard to sell your stake. Only invest what you can afford to lose, and read the documents the owner provides.".tr,
                        ),
                      ],
                    ),
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

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    return DsScaffold(
      title: "My investor preferences".tr,
      maxContentWidth: DsLayout.contentMax,
      bottomBar: DsStickyBar(child: DsButton.primary(label: "Save".tr, size: DsButtonSize.lg, expand: true, onPressed: _save)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        children: [
          DsFormSection(
            title: "Amount per investment".tr,
            icon: Icons.payments_outlined,
            children: [
              Row(children: [
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
                      items: [for (final c in cfg.currencies) DropdownMenuItem(value: c, child: Text(c))],
                      onChanged: (v) => setState(() => _currency = v ?? _currency),
                    ),
                  ),
                ],
              ]),
            ],
          ),
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "Risk and horizon".tr,
            icon: Icons.speed_outlined,
            children: [
              Text('${"Highest risk I accept".tr}: ${_risk.round()}/7 · ${RiskScale.label(_risk.round()).tr}', style: DsTypography.label),
              Slider(value: _risk, min: 1, max: 7, divisions: 6, label: '${_risk.round()}', onChanged: (v) => setState(() => _risk = v)),
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
          if (cfg.sectors.isNotEmpty) ...[
            const DsGap(DsSpace.lg),
            DsFormSection(title: "Sectors".tr, subtitle: "None selected = all.".tr, icon: Icons.category_outlined, children: [_chips(cfg.sectors, _sectors, FinancingLabels.sector)]),
          ],
          if (cfg.countries.isNotEmpty) ...[
            const DsGap(DsSpace.lg),
            DsFormSection(title: "Countries".tr, subtitle: "None selected = all.".tr, icon: Icons.public_rounded, children: [_chips(cfg.countries, _countries, IntelLabels.country)]),
          ],
          if (cfg.types.isNotEmpty) ...[
            const DsGap(DsSpace.lg),
            DsFormSection(title: "Types of investment".tr, subtitle: "None selected = all.".tr, icon: Icons.account_tree_outlined, children: [_chips(cfg.types, _types, IntelLabels.type)]),
          ],
        ],
      ),
    );
  }
}

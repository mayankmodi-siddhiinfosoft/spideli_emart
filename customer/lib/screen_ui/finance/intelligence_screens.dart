import 'dart:math' as math;

import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/investment_screens.dart';
import 'package:customer/service/finance_intel_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_financing_rules.dart';
import 'package:customer/utils/finance_intel_rules.dart';
import 'package:customer/utils/finance_investment_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;

String _date(DateTime? d) => d == null ? '-' : ltr(DateFormat('dd MMM yyyy').format(d));

/// The messages of this module's own refusals; the others are the shared ones.
const Map<String, String> _errors = {
  'permission_denied': 'You are not allowed to do this.',
  'state_changed': 'This action is no longer possible. Please refresh.',
  'watchlist_full': 'Your watchlist is full. Remove a security first.',
};

/// A step behind the loader; a refusal is said in words.
Future<bool> _run(Future<void> Function() action, {String? success}) async {
  ShowToastDialog.showLoader("Please wait...".tr);
  try {
    await action();
    ShowToastDialog.closeLoader();
    if (success != null) ShowToastDialog.showToast(success.tr);
    return true;
  } on FinanceException catch (e) {
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast((_errors[e.reason] ?? FinanceErrors.messageKey(e.reason)).tr);
    return false;
  } catch (_) {
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast(FinanceErrors.messageKey(null).tr);
    return false;
  }
}

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

/// The change since the previous value in words, in the indicator's unit
/// ("Up 0.3 %"), so the arrow is never the only cue. Null without a previous value.
String? _trendText(Indicator i) {
  final double? change = i.change;
  if (change == null) return null;
  final String amount = ltr('${formatNumber(change.abs())}${i.unit == '%' ? ' %' : (i.unit.isEmpty ? '' : ' ${i.unit}')}');
  return switch (i.direction) {
    'up' => '${"Up".tr} $amount',
    'down' => '${"Down".tr} $amount',
    _ => "Unchanged".tr,
  };
}

/// The previous value of an indicator, in its unit.
String _previous(Indicator i) => ltr('${formatNumber(i.previousValue!)}${i.unit == '%' ? ' %' : (i.unit.isEmpty ? '' : ' ${i.unit}')}');

String _kind(FxRate r) => (r.kind == 'official' ? "Official" : "Indicative").tr;

/// A history chart with its first and last points, read out for screen
/// readers, and its highest and lowest values ([format] writes a value).
Widget _history(BuildContext context, List<double> values, String first, String last, String Function(double) format) {
  final String high = format(values.reduce(math.max));
  final String low = format(values.reduce(math.min));
  return FinSection(
    title: "History".tr,
    children: [
      const DsGap(DsSpace.sm),
      Semantics(
        container: true,
        label: '${"History".tr}: $first ${format(values.first)} – $last ${format(values.last)}. ${"High".tr} $high, ${"Low".tr} $low',
        child: ExcludeSemantics(child: FinanceLineChart(values: values)),
      ),
      const DsGap(DsSpace.xs),
      ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Under the line, which runs left to right in every language.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(children: [Expanded(child: _caption(context, first)), _caption(context, last)]),
          ),
          const DsGap(DsSpace.sm),
          Row(children: [
            Expanded(child: _caption(context, '${"High".tr} $high')),
            _caption(context, '${"Low".tr} $low'),
          ]),
        ]),
      ),
      const DsGap(DsSpace.sm),
    ],
  );
}

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

  static String securityType(String t) => const {
        'stock': 'Company share',
        'etf': 'ETF',
        'bond': 'Bond',
        'index': 'Market index',
      }[t] ??
      t;

  static String ipoStatus(String s) => const {
        'upcoming': 'Upcoming',
        'open': 'Open for subscription',
        'closed': 'Subscription closed',
        'listed': 'Listed',
        'withdrawn': 'Withdrawn',
      }[s] ??
      s;

  static String newsCategory(String c) => const {
        'news': 'News',
        'analysis': 'Analyses',
        'markets': 'Markets',
        'economy': 'Economy',
        'companies': 'Companies',
      }[c] ??
      (c.isEmpty ? c : c[0].toUpperCase() + c.substring(1));

  static String reason(String k) => const {
        'sector': 'Your sectors',
        'country': 'Your countries',
        'type': 'Your types of investment',
        'ticket': 'Your amount',
        'horizon': 'Your time horizon',
      }[k] ??
      k;
}

/// Spideli Finance > Economic intelligence: indicators, exchange rates,
/// markets (stocks and market indices, bonds, IPOs, stock collections,
/// news and analyses) and investment opportunities.
/// `platform_settings/intelligence` must exist (admin).
/// What [IntelligenceScreen] shows: everything, the markets (indicators,
/// exchange rates and market data, under Investment) or the projects open
/// to investors (funding, under Investment).
enum IntelligenceView { all, markets, funding }

class IntelligenceScreen extends StatefulWidget {
  final IntelligenceView view;

  const IntelligenceScreen({super.key, this.view = IntelligenceView.all});

  @override
  State<IntelligenceScreen> createState() => _IntelligenceScreenState();
}

class _IntelligenceScreenState extends State<IntelligenceScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return FinConfig<IntelligenceConfig>(
      load: FinanceIntelService.config,
      builder: (context, st) {
        final cfg = st.config;
        final IntelligenceView view = widget.view;
        final bool markets = view != IntelligenceView.funding, funding = view != IntelligenceView.markets;
        final mk = markets ? cfg?.markets : null;
        final tabs = <(String, Widget Function())>[
          if (markets && cfg?.indicators != null) ("Indicators", () => _Indicators(config: cfg!.indicators!)),
          if (markets && cfg?.fx != null) ("Exchange rates", () => _Rates(config: cfg!.fx!)),
          if (mk?.stocks == true) ("Stocks", () => const _Stocks()),
          if (mk?.bonds == true) ("Bonds", () => const _Bonds()),
          if (mk?.ipos == true) ("IPOs", () => const _Ipos()),
          if (mk?.collections == true) ("Collections", () => const _Collections()),
          if (mk?.news == true) ("News", () => const _News()),
          if (funding && cfg?.matching != null) ("Opportunities", () => _Opportunities(config: cfg!.matching!)),
        ];
        final String title = switch (view) {
          IntelligenceView.all => "Economic intelligence",
          IntelligenceView.markets => "Markets",
          IntelligenceView.funding => "Invest in projects",
        };
        final int tab = tabs.isEmpty ? 0 : math.min(_tab, tabs.length - 1);
        final IconData icon = view == IntelligenceView.funding ? Icons.lightbulb_outline_rounded : Icons.insights_outlined;
        final String unavailable = (view == IntelligenceView.funding
                ? "No project is open to investors yet."
                : view == IntelligenceView.markets
                    ? "Market information is not available yet."
                    : "Economic intelligence is not available yet.")
            .tr;
        // Loading, unreadable (with Retry), or not offered by the admin.
        final Widget? waiting = st.placeholder(icon, unavailable);
        return FinScaffold(
          title: title.tr,
          body: FinBody(children: [
            if (waiting != null)
              waiting
            else if (tabs.isEmpty)
              FinState.empty(icon, unavailable)
            else ...[
              if (tabs.length > 1)
                DsSegmentedTabs(
                  scrollable: tabs.length > 3,
                  segments: [for (final t in tabs) DsSegment(t.$1.tr)],
                  index: tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              KeyedSubtree(key: ValueKey(tabs[tab].$1), child: tabs[tab].$2()),
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
            // Retry builds again, which subscribes again.
            if (snap.hasError) return FinState.error("Could not load the indicators.".tr, onRetry: () => setState(() {}));
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
              subtitle: [ltr(i.period), ?_trendText(i), if (i.previousValue != null) '${"Previous".tr}: ${_previous(i)}'].join(' · '),
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
    final Uri? source = i.sourceUrl.isEmpty ? null : Uri.tryParse(i.sourceUrl);
    return FinScaffold(
      title: i.name,
      body: FinBody(children: [
        FinHeader(
          overline: '${IntelLabels.country(i.country).tr} · ${ltr(i.period)}',
          title: ltr(i.display),
          subtitle: i.previousValue == null ? null : '${_trendText(i)} · ${"Previous".tr}: ${_previous(i)}',
          icon: _trend(i),
        ),
        // Retry subscribes again: a failed stream does not recover by itself.
        StatefulBuilder(
          builder: (context, refresh) => StreamBuilder<List<(String, double)>>(
            stream: FinanceIntelService.indicatorHistory(i.id),
            builder: (context, snap) {
              if (snap.hasError) return FinState.error("Could not load the history.".tr, onRetry: () => refresh(() {}));
              if (!snap.hasData) return FinState.loading(rows: 2);
              final h = snap.data!;
              if (h.length < 2) return const SizedBox.shrink();
              return _history(context, [for (final p in h) p.$2], ltr(h.first.$1), ltr(h.last.$1), (v) => ltr(formatNumber(v)));
            },
          ),
        ),
        FinSection(
          title: "Source".tr,
          children: [
            FinRow("Published by".tr, i.source),
            FinRow("Period".tr, ltr(i.period)),
            FinRow("Updated".tr, _dateTime(i.updatedAt)),
            if (source != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: DsButton.ghost(label: "Open the source".tr, icon: Icons.open_in_new_rounded, onPressed: () => Constant().launchURL(source)),
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

  /// Held here: the converter rebuilds at every typed digit.
  late Stream<List<FxRate>> _rates = FinanceIntelService.rates(widget.config.base);

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
      stream: _rates,
      builder: (context, snap) {
        if (snap.hasError) return FinState.error("Could not load the exchange rates.".tr, onRetry: () => setState(() => _rates = FinanceIntelService.rates(cfg.base)));
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
                // The amount with its currency, digits only.
                DsTextField(
                  label: "Amount".tr,
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]'))],
                  suffix: Padding(
                    padding: const EdgeInsetsDirectional.only(end: DsSpace.xs),
                    child: Text(_from, style: DsTypography.bodyStrong.copyWith(color: c.textSecondary)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                LayoutBuilder(builder: (context, box) {
                  Widget picker(String label, String value, ValueChanged<String> onChanged) => DsDropdown<String>(
                        label: label,
                        value: value,
                        items: [for (final cur in all) DropdownMenuItem(value: cur, child: Text(cur))],
                        onChanged: (v) => v == null ? null : setState(() => onChanged(v)),
                      );
                  final Widget from = picker("From".tr, _from, (v) => _from = v);
                  final Widget to = picker("To".tr, _to, (v) => _to = v);
                  final Widget swap = DsIconButton(
                    icon: Icons.swap_horiz_rounded,
                    semanticLabel: "Swap".tr,
                    variant: DsIconButtonVariant.outlined,
                    onPressed: () => setState(() {
                      final f = _from;
                      _from = _to;
                      _to = f;
                    }),
                  );
                  // A small phone or large text: one picker under the other,
                  // never two squeezed boxes.
                  if (box.maxWidth < 300 * MediaQuery.textScalerOf(context).scale(1)) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      from,
                      Padding(padding: const EdgeInsets.only(bottom: DsSpace.sm), child: Align(alignment: AlignmentDirectional.centerStart, child: swap)),
                      to,
                    ]);
                  }
                  return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(child: from),
                    Padding(padding: const EdgeInsets.fromLTRB(DsSpace.xs, 0, DsSpace.xs, DsSpace.lg), child: swap),
                    Expanded(child: to),
                  ]);
                }),
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
      // Retry subscribes again: a failed stream does not recover by itself.
      body: StatefulBuilder(
        builder: (context, refresh) => StreamBuilder<List<FxRate>>(
          stream: FinanceIntelService.rateHistory(from, to),
          builder: (context, snap) {
            if (snap.hasError) return FinBody(children: [FinState.error("Could not load the exchange rates.".tr, onRetry: () => refresh(() {}))]);
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
              if (h.length > 1) _history(context, [for (final r in h) r.rate], _date(h.first.observedAt), _date(h.last.observedAt), (v) => ltr(formatNumber(v, decimals: 4))),
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
      ),
    );
  }
}

// ------------------------------------------------------------ opportunities

class _Opportunities extends StatefulWidget {
  final MatchingConfig config;

  const _Opportunities({required this.config});

  @override
  State<_Opportunities> createState() => _OpportunitiesState();
}

class _OpportunitiesState extends State<_Opportunities> {
  late Stream<Map<String, dynamic>?> _profile = FinanceIntelService.investorProfile();
  late Stream<List<Opportunity>> _opportunities = FinanceIntelService.opportunities();

  void _retry() => setState(() {
        _profile = FinanceIntelService.investorProfile();
        _opportunities = FinanceIntelService.opportunities();
      });

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _profile,
      builder: (context, ps) {
        final profile = InvestorProfile.fromMap(ps.data);
        return StreamBuilder<List<Opportunity>>(
          stream: _opportunities,
          builder: (context, snap) {
            if (snap.hasError) return FinState.error("Could not load the opportunities.".tr, onRetry: _retry);
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
              // The smallest ticket goes in the text, which wraps: beside the
              // chevron it squeezed the title on a small phone. First, so a
              // long sector line never cuts it off.
              FinListTile(
                icon: m != null ? Icons.auto_awesome_rounded : Icons.lightbulb_outline_rounded,
                iconTone: m != null ? DsTone.success : DsTone.brand,
                title: o.title,
                subtitle: [
                  '${"From".tr} ${FinanceMoney.format(o.minTicket, o.currency)}',
                  [FinancingLabels.sector(o.sector).tr, IntelLabels.country(o.country).tr, IntelLabels.type(o.type).tr].join(' · '),
                ].join('\n'),
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
class OpportunityScreen extends StatefulWidget {
  final String opportunityId;
  final MatchResult? match;

  const OpportunityScreen({super.key, required this.opportunityId, this.match});

  @override
  State<OpportunityScreen> createState() => _OpportunityScreenState();
}

class _OpportunityScreenState extends State<OpportunityScreen> {
  late Stream<Opportunity?> _opportunity = FinanceIntelService.opportunity(widget.opportunityId);

  /// The interest was sent from this screen: not sent twice.
  bool _sent = false;

  /// Hides the opportunity, then goes back to the list it no longer belongs to.
  Future<void> _notForMe(Opportunity o) async {
    final ok = await _run(() => FinanceIntelService.respond(o.id, false), success: "Hidden");
    if (ok && mounted) Get.back();
  }

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
            DsTextField(label: "Message (optional)".tr, controller: message, maxLines: 3, maxLength: IntelPlans.maxMessage),
            DsButton.primary(label: "Share my interest".tr, expand: true, onPressed: () => Get.back(result: true)),
          ],
        ),
      )),
    );
    if (ok != true) return;
    final sent = await _run(() => FinanceIntelService.respond(o.id, true, message: message.text.trim()), success: "Interest sent");
    if (sent && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Opportunity?>(
      stream: _opportunity,
      builder: (context, snap) {
        final o = snap.data;
        final bool open = o != null && o.isOpen(DateTime.now());
        final Widget? state = FinState.of(snap, onRetry: () => setState(() => _opportunity = FinanceIntelService.opportunity(widget.opportunityId)));
        return FinScaffold(
          title: "Opportunity".tr,
          bottomBar: !open
              ? null
              : DsStickyBar(
                  child: FinanceKycGate(
                    builder: (context, verified) => Row(children: [
                      Expanded(child: DsButton.secondary(label: "Not for me".tr, onPressed: _sent ? null : () => _notForMe(o))),
                      const DsGap(DsSpace.sm),
                      Expanded(
                        child: DsButton.primary(
                          label: (_sent ? "Interest sent" : "I am interested").tr,
                          icon: _sent ? Icons.check_rounded : null,
                          onPressed: verified && !_sent ? () => _interested(context, o) : null,
                        ),
                      ),
                    ]),
                  ),
                ),
          body: state != null ? FinBody(children: [state]) : _body(context, o!, open),
        );
      },
    );
  }

  Widget _body(BuildContext context, Opportunity o, bool open) {
    final match = widget.match;
    return FinBody(children: [
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
      if (_sent) FinNotice("The project owner has your name and email and can contact you. No money is committed.".tr, title: "Interest sent".tr, tone: DsTone.success),
      if (match != null)
        FinNotice(
          match.reasons.map((r) => IntelLabels.reason(r).tr).join(', '),
          title: '${"Matches your preferences".tr}: ${ltr('${match.score} %')}',
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
          if (o.horizonMonths > 0) FinRow("Horizon".tr, FinanceUi.count(o.horizonMonths, "month", "months")),
          FinRow("Risk level".tr, '${RiskScale.label(o.riskLevel).tr} · ${ltr('${o.riskLevel}/7')}'),
          if (o.targetReturnPercent != null) FinRow("Target return (not guaranteed)".tr, InvestmentLabels.percent(o.targetReturnPercent)),
          if (o.closingDate != null) FinRow("Closes on".tr, _date(o.closingDate)),
        ],
      ),
      // The documents are with the owner, not on this screen.
      FinNotice(
        "Investing in a company is risky: you can lose all the money invested, and it can be hard to sell your stake. Only invest what you can afford to lose, and ask the owner for the project's documents before you decide."
            .tr,
        tone: DsTone.warning,
      ),
    ]);
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
  // Saved amounts in any currency ("12.50" USD); no minimum stays empty.
  late final _min = TextEditingController(text: _p['minTicket'] is num && (_p['minTicket'] as num) > 0 ? FinanceAmount.input(_p['minTicket'] as num, _currency) : '');
  late final _max = TextEditingController(text: _p['maxTicket'] is num && (_p['maxTicket'] as num) > 0 ? FinanceAmount.input(_p['maxTicket'] as num, _currency) : '');
  late double _risk = (FinanceSummary.intOf(_p['maxRisk']) == 0 ? 4 : FinanceSummary.intOf(_p['maxRisk'])).clamp(1, 7).toDouble();
  late int _horizon = FinanceSummary.intOf(_p['maxHorizonMonths']);

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  /// The smallest ticket: 0 when empty, -1 when not a valid amount.
  int get _minTicket => _min.text.trim().isEmpty ? 0 : (FinanceAmount.parse(_min.text, _currency) ?? -1);

  /// The amounts can be saved (the fields explain what is wrong as it is typed).
  bool get _amountsValid {
    final int min = _minTicket;
    final int? max = FinanceAmount.parse(_max.text, _currency);
    return min >= 0 && max != null && max >= min;
  }

  Future<void> _save() async {
    final int min = _minTicket;
    final int? max = FinanceAmount.parse(_max.text, _currency);
    if (!_amountsValid || max == null) return;
    final ok = await _run(
      () => FinanceIntelService.saveInvestorProfile(
        widget.config,
        currency: _currency,
        sectors: _sectors.toList(),
        countries: _countries.toList(),
        types: _types.toList(),
        minTicket: min,
        maxTicket: max,
        maxRisk: _risk.round(),
        maxHorizonMonths: _horizon,
      ),
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
    final bool valid = _amountsValid;
    final int min = _minTicket;
    final Widget from = FinAmountField(
      label: "From".tr,
      controller: _min,
      currency: _currency,
      requiredMark: false,
      onChanged: (_) => setState(() {}),
    );
    // Below "From" it says the minimum it must reach.
    final Widget upTo = FinAmountField(
      label: "Up to".tr,
      controller: _max,
      currency: _currency,
      min: min > 0 ? min : null,
      onChanged: (_) => setState(() {}),
    );
    return FinScaffold(
      title: "My investor preferences".tr,
      bottomBar: DsStickyBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinMissing([if (!valid) "a valid amount".tr]),
            DsButton.primary(label: "Save".tr, size: DsButtonSize.lg, expand: true, onPressed: valid ? _save : null),
          ],
        ),
      ),
      body: FinBody(children: [
        FinSection(
          title: "Amount per investment".tr,
          top: 0,
          padding: _formPadding,
          children: [
            if (cfg.currencies.length > 1)
              DsDropdown<String>(
                label: "Currency".tr,
                value: _currency,
                items: [for (final cur in cfg.currencies) DropdownMenuItem(value: cur, child: Text(cur))],
                onChanged: (v) => setState(() => _currency = v ?? _currency),
              ),
            // Side by side when there is room, one under the other on a
            // small phone or with large text.
            LayoutBuilder(
              builder: (context, box) => box.maxWidth < 340 * MediaQuery.textScalerOf(context).scale(1)
                  ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [from, upTo])
                  : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: from), const DsGap(DsSpace.sm), Expanded(child: upTo)]),
            ),
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
            Slider(
              value: _risk,
              min: 1,
              max: 7,
              divisions: 6,
              label: '${_risk.round()}',
              // Read out as the risk level, not as a share of the track.
              semanticFormatterCallback: (v) => '${ltr('${v.round()}/7')}, ${RiskScale.label(v.round()).tr}',
              onChanged: (v) => setState(() => _risk = v),
            ),
            const DsGap(DsSpace.sm),
            DsDropdown<int>(
              label: "Longest time I can invest for".tr,
              value: _horizon,
              items: [
                DropdownMenuItem(value: 0, child: Text("No limit".tr)),
                for (final m in const [12, 24, 36, 60, 120]) DropdownMenuItem(value: m, child: Text(FinanceUi.count(m, "month", "months"))),
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

// ------------------------------------------------------------------ markets

/// The trend icon of a security (its change since the previous close).
IconData _secTrend(MarketSecurity s) => switch (s.direction) {
      'up' => Icons.trending_up_rounded,
      'down' => Icons.trending_down_rounded,
      'flat' => Icons.trending_flat_rounded,
      _ => s.isBond ? Icons.receipt_long_outlined : Icons.show_chart_rounded,
    };

DsTone _secTone(MarketSecurity s) => switch (s.direction) {
      'up' => DsTone.success,
      'down' => DsTone.danger,
      _ => DsTone.brand,
    };

/// "Up 1.25 %", "Down 0.4 %", "Unchanged": the arrow and the colour are
/// never the only cue. Null without a change.
String? _changeText(MarketSecurity s) {
  final double? v = s.changePercent ?? s.change;
  if (v == null) return null;
  final String amount = ltr('${formatNumber(v.abs())}${s.changePercent != null ? ' %' : ''}');
  return switch (s.direction) {
    'up' => '${"Up".tr} $amount',
    'down' => '${"Down".tr} $amount',
    _ => "Unchanged".tr,
  };
}

String _percent(double v) => ltr('${formatNumber(v)} %');

/// "Updated 14 Oct 2026, 14:32 · Delayed".
String _freshness(MarketSecurity s) => ['${"Updated".tr} ${_dateTime(s.updatedAt)}', if (s.delayed) "Delayed".tr].join(' · ');

/// Buying or subscribing needs a licensed broker: Spideli's regulated funds instead.
class _FundsNotice extends StatelessWidget {
  final String message;

  const _FundsNotice(this.message);

  @override
  Widget build(BuildContext context) => FinNotice(
        message,
        title: "Want to invest?".tr,
        actionLabel: "Invest through the funds".tr,
        onAction: () => Get.to(() => const InvestmentsScreen()),
      );
}

/// The line under market data.
Widget _marketsCaption(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: DsSpace.md, left: DsSpace.xxs, right: DsSpace.xxs),
      child: _caption(context, "Market data as published by the source shown on each line, for information only. It is not investment advice.".tr),
    );

/// Choice chips in a scrolling row ("All" first).
Widget _chips(BuildContext context, List<String> values, String? selected, String Function(String) label, ValueChanged<String?> onSelected) => Padding(
      padding: const EdgeInsets.only(top: DsSpace.lg),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final v in <String?>[null, ...values])
            Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpace.sm),
              child: ChoiceChip(label: Text(v == null ? "All".tr : label(v)), selected: selected == v, onSelected: (_) => onSelected(v)),
            ),
        ]),
      ),
    );

/// One security in a list: name, change, symbol and exchange, price, and
/// when it was updated (with "Delayed" when the feed says so).
class _SecurityRow extends StatelessWidget {
  final MarketSecurity security;

  const _SecurityRow({required this.security});

  @override
  Widget build(BuildContext context) {
    final s = security;
    final String facts = s.isBond
        ? [
            if (s.couponPercent != null) '${"Coupon rate".tr} ${_percent(s.couponPercent!)}',
            if (s.yieldPercent != null) '${"Yield".tr} ${_percent(s.yieldPercent!)}',
            if (s.maturityDate != null) '${"Matures".tr} ${_date(s.maturityDate)}',
          ].join(' · ')
        : (_changeText(s) ?? '');
    return FinListTile(
      icon: _secTrend(s),
      iconTone: _secTone(s),
      title: s.title,
      subtitle: [
        if (facts.isNotEmpty) facts,
        [if (s.symbol.isNotEmpty) ltr(s.symbol), if (s.exchange.isNotEmpty) s.exchange, if (s.type == 'etf') "ETF".tr].join(' · '),
        _freshness(s),
      ].where((x) => x.isNotEmpty).join('\n'),
      amount: s.price == null ? null : ltr(s.priceDisplay),
      chevron: true,
      onTap: () => Get.to(() => SecurityScreen(securityId: s.id)),
    );
  }
}

/// Stocks and the stock markets: the user's watchlist, the market indices,
/// then the shares and ETFs by exchange. Live: prices change on screen as
/// the admin's feed publishes them.
class _Stocks extends StatefulWidget {
  const _Stocks();

  @override
  State<_Stocks> createState() => _StocksState();
}

class _StocksState extends State<_Stocks> {
  late Stream<List<MarketSecurity>> _all = FinanceIntelService.securities();
  late Stream<List<String>> _watch = FinanceIntelService.watchlist();
  String? _exchange;

  void _retry() => setState(() {
        _all = FinanceIntelService.securities();
        _watch = FinanceIntelService.watchlist();
      });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: _watch,
      builder: (context, ws) => StreamBuilder<List<MarketSecurity>>(
        stream: _all,
        builder: (context, snap) {
          if (snap.hasError) return FinState.error("Could not load the market data.".tr, onRetry: _retry);
          if (!snap.hasData) return FinState.loading(rows: 5);
          final all = snap.data!;
          final indices = all.where((s) => s.isIndex).toList();
          final shares = all.where((s) => s.type == 'stock' || s.type == 'etf').toList();
          if (indices.isEmpty && shares.isEmpty) return FinState.empty(Icons.show_chart_rounded, "No market data is published yet.".tr);
          final byId = {for (final s in all) s.id: s};
          final mine = [for (final id in ws.data ?? const <String>[]) ?byId[id]];
          final exchanges = {for (final s in shares) if (s.exchange.isNotEmpty) s.exchange}.toList()..sort();
          final String? exchange = exchanges.contains(_exchange) ? _exchange : null;
          final list = shares.where((s) => exchange == null || s.exchange == exchange).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mine.isNotEmpty)
                FinSection(title: "My watchlist".tr, divided: true, padding: _listPadding, children: [for (final s in mine) _SecurityRow(security: s)]),
              if (indices.isNotEmpty)
                FinSection(title: "Market indices".tr, divided: true, padding: _listPadding, children: [for (final s in indices) _SecurityRow(security: s)]),
              if (shares.isNotEmpty) ...[
                if (exchanges.length > 1) _chips(context, exchanges, exchange, (e) => e, (v) => setState(() => _exchange = v)),
                FinSection(
                  title: "Shares".tr,
                  top: exchanges.length > 1 ? DsSpace.md : FinSpace.section,
                  divided: true,
                  padding: _listPadding,
                  children: [for (final s in list) _SecurityRow(security: s)],
                ),
              ],
              _FundsNotice("Spideli does not buy or sell shares: that needs a licensed broker. You can invest in regulated funds instead.".tr),
              _marketsCaption(context),
            ],
          );
        },
      ),
    );
  }
}

/// Bonds: coupon, yield and maturity, soonest maturity first.
class _Bonds extends StatefulWidget {
  const _Bonds();

  @override
  State<_Bonds> createState() => _BondsState();
}

class _BondsState extends State<_Bonds> {
  late Stream<List<MarketSecurity>> _all = FinanceIntelService.securities();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MarketSecurity>>(
      stream: _all,
      builder: (context, snap) {
        if (snap.hasError) return FinState.error("Could not load the market data.".tr, onRetry: () => setState(() => _all = FinanceIntelService.securities()));
        if (!snap.hasData) return FinState.loading(rows: 4);
        final bonds = snap.data!.where((s) => s.isBond).toList()
          ..sort((a, b) => (a.maturityDate ?? DateTime(9999)).compareTo(b.maturityDate ?? DateTime(9999)));
        if (bonds.isEmpty) return FinState.empty(Icons.receipt_long_outlined, "No bond is published yet.".tr);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinSection(divided: true, padding: _listPadding, children: [for (final s in bonds) _SecurityRow(security: s)]),
            _FundsNotice("Spideli does not buy or sell bonds: that needs a licensed broker. You can invest in regulated funds instead.".tr),
            _marketsCaption(context),
          ],
        );
      },
    );
  }
}

/// One security, live: price and change, its history, key facts, source
/// and update time; added to or removed from the user's watchlist.
class SecurityScreen extends StatefulWidget {
  final String securityId;

  const SecurityScreen({super.key, required this.securityId});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  late Stream<MarketSecurity?> _security = FinanceIntelService.security(widget.securityId);
  late final Stream<List<String>> _watch = FinanceIntelService.watchlist();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MarketSecurity?>(
      stream: _security,
      builder: (context, snap) {
        final s = snap.data;
        final Widget? state = FinState.of(
          snap,
          gone: "This security is no longer available.",
          onRetry: () => setState(() => _security = FinanceIntelService.security(widget.securityId)),
        );
        return FinScaffold(
          title: s?.title ?? "Market".tr,
          actions: s == null || FinanceService.uid.isEmpty
              ? null
              : [
                  StreamBuilder<List<String>>(
                    stream: _watch,
                    builder: (context, ws) {
                      final bool on = (ws.data ?? const <String>[]).contains(s.id);
                      return DsIconButton(
                        icon: on ? Icons.star_rounded : Icons.star_border_rounded,
                        semanticLabel: (on ? "Remove from my watchlist" : "Add to my watchlist").tr,
                        onPressed: !ws.hasData
                            ? null
                            : () => _run(() => FinanceIntelService.setWatched(s.id, !on), success: on ? "Removed from your watchlist" : "Added to your watchlist"),
                      );
                    },
                  ),
                ],
          body: state != null || s == null ? FinBody(children: [state ?? FinState.loading(rows: 4)]) : _body(context, s),
        );
      },
    );
  }

  Widget _body(BuildContext context, MarketSecurity s) {
    final bool live = s.isLive(DateTime.now());
    String n(double v) => ltr(formatNumber(v));
    final facts = <Widget>[
      if (s.isBond) ...[
        if (s.couponPercent != null) FinRow("Coupon rate".tr, _percent(s.couponPercent!)),
        if (s.yieldPercent != null) FinRow("Yield".tr, _percent(s.yieldPercent!)),
        if (s.maturityDate != null) FinRow("Maturity".tr, _date(s.maturityDate)),
      ],
      if (s.open != null) FinRow("Opening price".tr, n(s.open!)),
      if (s.high != null) FinRow("High".tr, n(s.high!)),
      if (s.low != null) FinRow("Low".tr, n(s.low!)),
      if (s.volume != null) FinRow("Volume".tr, ltr(formatNumber(s.volume!, decimals: 0))),
      if (s.sector.isNotEmpty) FinRow("Sector".tr, s.sector),
      if (s.country.isNotEmpty) FinRow("Country".tr, IntelLabels.country(s.country).tr),
      if (s.currency.isNotEmpty && !s.isIndex) FinRow("Currency".tr, s.currency),
    ];
    return FinBody(children: [
      FinHeader(
        overline: [if (s.symbol.isNotEmpty) ltr(s.symbol), if (s.exchange.isNotEmpty) s.exchange, IntelLabels.securityType(s.type).tr].join(' · '),
        title: s.price == null ? '-' : ltr(s.priceDisplay),
        subtitle: [?_changeText(s), if (s.isBond && s.yieldPercent != null) '${"Yield".tr} ${_percent(s.yieldPercent!)}'].join(' · '),
        status: s.delayed ? 'delayed' : (live ? 'active' : null),
        statusLabel: s.delayed ? "Delayed".tr : (live ? "Live".tr : null),
        icon: _secTrend(s),
      ),
      // Retry subscribes again: a failed stream does not recover by itself.
      StatefulBuilder(
        builder: (context, refresh) => StreamBuilder<List<(DateTime, double)>>(
          stream: FinanceIntelService.priceHistory(s.id),
          builder: (context, snap) {
            if (snap.hasError) return FinState.error("Could not load the history.".tr, onRetry: () => refresh(() {}));
            if (!snap.hasData) return FinState.loading(rows: 2);
            final h = snap.data!;
            if (h.length < 2) return const SizedBox.shrink();
            return _history(context, [for (final p in h) p.$2], _date(h.first.$1), _date(h.last.$1), (v) => ltr(formatNumber(v)));
          },
        ),
      ),
      if (facts.isNotEmpty) FinSection(title: "Key facts".tr, children: facts),
      FinSection(
        title: "Source".tr,
        footnote: (s.delayed ? "Prices are delayed by the exchange or the data provider." : "Prices update here as the source publishes them.").tr,
        children: [
          FinRow("Published by".tr, s.source),
          FinRow("Updated".tr, _dateTime(s.updatedAt)),
        ],
      ),
      if (!s.isIndex)
        _FundsNotice((s.isBond
                ? "Spideli does not buy or sell bonds: that needs a licensed broker. You can invest in regulated funds instead."
                : "Spideli does not buy or sell shares: that needs a licensed broker. You can invest in regulated funds instead.")
            .tr),
    ]);
  }
}

/// IPO tracking: open for subscription, upcoming, then recent ones.
class _Ipos extends StatefulWidget {
  const _Ipos();

  @override
  State<_Ipos> createState() => _IposState();
}

class _IposState extends State<_Ipos> {
  late Stream<List<IpoListing>> _ipos = FinanceIntelService.ipos();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<IpoListing>>(
      stream: _ipos,
      builder: (context, snap) {
        if (snap.hasError) return FinState.error("Could not load the IPOs.".tr, onRetry: () => setState(() => _ipos = FinanceIntelService.ipos()));
        if (!snap.hasData) return FinState.loading(rows: 4);
        final all = snap.data!;
        if (all.isEmpty) return FinState.empty(Icons.rocket_launch_outlined, "No IPO is published yet.".tr);
        Widget part(String title, List<IpoListing> list) =>
            FinSection(title: title, divided: true, padding: _listPadding, children: [for (final i in list) _IpoRow(ipo: i)]);
        final open = all.where((i) => i.status == 'open').toList();
        final upcoming = all.where((i) => i.status == 'upcoming').toList();
        final recent = all.where((i) => i.rank > 1).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (open.isNotEmpty) part("Open for subscription".tr, open),
            if (upcoming.isNotEmpty) part("Upcoming".tr, upcoming),
            if (recent.isNotEmpty) part("Recent".tr, recent),
            _FundsNotice("Spideli does not take IPO subscriptions: that needs a licensed broker. You can invest in regulated funds instead.".tr),
            _marketsCaption(context),
          ],
        );
      },
    );
  }
}

/// The date that matters for an IPO's status, in words.
String? _ipoWhen(IpoListing i) => switch (i.status) {
      'open' when i.closeDate != null => '${"Closes on".tr} ${_date(i.closeDate)}',
      'upcoming' when i.openDate != null => '${"Opens on".tr} ${_date(i.openDate)}',
      'listed' when i.listingDate != null => '${"Listed on".tr} ${_date(i.listingDate)}',
      'closed' when i.listingDate != null => '${"Listing on".tr} ${_date(i.listingDate)}',
      _ => null,
    };

class _IpoRow extends StatelessWidget {
  final IpoListing ipo;

  const _IpoRow({required this.ipo});

  @override
  Widget build(BuildContext context) {
    final i = ipo;
    return FinListTile(
      icon: Icons.rocket_launch_outlined,
      iconTone: i.status == 'open' ? DsTone.warning : DsTone.brand,
      title: i.company,
      subtitle: [
        [if (i.symbol.isNotEmpty) ltr(i.symbol), if (i.exchange.isNotEmpty) i.exchange].join(' · '),
        ?_ipoWhen(i),
      ].where((x) => x.isNotEmpty).join('\n'),
      amount: i.priceDisplay == null ? null : ltr(i.priceDisplay!),
      status: i.status,
      statusLabel: IntelLabels.ipoStatus(i.status).tr,
      chevron: true,
      onTap: () => Get.to(() => IpoScreen(ipoId: i.id)),
    );
  }
}

/// One IPO: its terms and dates, the prospectus, its source.
class IpoScreen extends StatefulWidget {
  final String ipoId;

  const IpoScreen({super.key, required this.ipoId});

  @override
  State<IpoScreen> createState() => _IpoScreenState();
}

class _IpoScreenState extends State<IpoScreen> {
  late Stream<IpoListing?> _ipo = FinanceIntelService.ipo(widget.ipoId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<IpoListing?>(
      stream: _ipo,
      builder: (context, snap) {
        final i = snap.data;
        final Widget? state = FinState.of(snap, gone: "This IPO is no longer available.", onRetry: () => setState(() => _ipo = FinanceIntelService.ipo(widget.ipoId)));
        final Uri? prospectus = i == null || i.prospectusUrl.isEmpty ? null : Uri.tryParse(i.prospectusUrl);
        return FinScaffold(
          title: "IPO".tr,
          bottomBar: prospectus == null
              ? null
              : DsStickyBar(
                  child: DsButton.secondary(
                    label: "Read the prospectus".tr,
                    icon: Icons.open_in_new_rounded,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () => Constant().launchURL(prospectus),
                  ),
                ),
          body: state != null || i == null
              ? FinBody(children: [state ?? FinState.loading(rows: 4)])
              : FinBody(children: [
                  FinHeader(
                    overline: [if (i.symbol.isNotEmpty) ltr(i.symbol), if (i.exchange.isNotEmpty) i.exchange].join(' · '),
                    title: i.company,
                    subtitle: i.priceDisplay == null ? null : ltr(i.priceDisplay!),
                    status: i.status,
                    statusLabel: IntelLabels.ipoStatus(i.status).tr,
                    icon: Icons.rocket_launch_outlined,
                  ),
                  FinSection(
                    title: "Key facts".tr,
                    children: [
                      if (i.offerPrice != null)
                        FinRow("Offer price".tr, ltr(i.priceDisplay!))
                      else if (i.priceDisplay != null)
                        FinRow("Price range".tr, ltr(i.priceDisplay!)),
                      if (i.exchange.isNotEmpty) FinRow("Exchange".tr, i.exchange),
                      if (i.country.isNotEmpty) FinRow("Country".tr, IntelLabels.country(i.country).tr),
                      if (i.sector.isNotEmpty) FinRow("Sector".tr, i.sector),
                      if (i.openDate != null) FinRow("Subscription opens".tr, _date(i.openDate)),
                      if (i.closeDate != null) FinRow("Subscription closes".tr, _date(i.closeDate)),
                      if (i.listingDate != null) FinRow("Listing date".tr, _date(i.listingDate)),
                    ],
                  ),
                  FinSection(
                    title: "Source".tr,
                    children: [
                      FinRow("Published by".tr, i.source),
                      FinRow("Updated".tr, _dateTime(i.updatedAt)),
                    ],
                  ),
                  _FundsNotice("Spideli does not take IPO subscriptions: that needs a licensed broker. You can invest in regulated funds instead.".tr),
                ]),
        );
      },
    );
  }
}

/// Stock collections: themed selections published by the admin.
class _Collections extends StatefulWidget {
  const _Collections();

  @override
  State<_Collections> createState() => _CollectionsState();
}

class _CollectionsState extends State<_Collections> {
  late Stream<List<StockCollection>> _collections = FinanceIntelService.collections();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StockCollection>>(
      stream: _collections,
      builder: (context, snap) {
        if (snap.hasError) return FinState.error("Could not load the collections.".tr, onRetry: () => setState(() => _collections = FinanceIntelService.collections()));
        if (!snap.hasData) return FinState.loading(rows: 3);
        final list = snap.data!;
        if (list.isEmpty) return FinState.empty(Icons.collections_bookmark_outlined, "No collection is published yet.".tr);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinSection(
              divided: true,
              padding: _listPadding,
              children: [
                for (final c in list)
                  FinListTile(
                    icon: Icons.collections_bookmark_outlined,
                    iconTone: DsTone.brand,
                    title: c.title,
                    subtitle: [
                      if (c.summary.isNotEmpty) c.summary,
                      [
                        FinanceUi.count(c.securityIds.length, "security", "securities"),
                        if (c.riskLevel != null) '${"Risk".tr} ${ltr('${c.riskLevel}/7')}',
                      ].join(' · '),
                    ].join('\n'),
                    chevron: true,
                    onTap: () => Get.to(() => CollectionScreen(collection: c)),
                  ),
              ],
            ),
            _marketsCaption(context),
          ],
        );
      },
    );
  }
}

/// One collection and its securities, live.
class CollectionScreen extends StatefulWidget {
  final StockCollection collection;

  const CollectionScreen({super.key, required this.collection});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late Stream<List<MarketSecurity>> _all = FinanceIntelService.securities();

  @override
  Widget build(BuildContext context) {
    final c = widget.collection;
    return FinScaffold(
      title: "Collection".tr,
      body: FinBody(children: [
        FinHeader(
          overline: c.theme.isEmpty ? null : c.theme,
          title: c.title,
          subtitle: c.summary.isEmpty ? null : c.summary,
          icon: Icons.collections_bookmark_outlined,
        ),
        if (c.riskLevel != null)
          FinSection(children: [FinRow("Risk level".tr, '${RiskScale.label(c.riskLevel!).tr} · ${ltr('${c.riskLevel}/7')}')]),
        StreamBuilder<List<MarketSecurity>>(
          stream: _all,
          builder: (context, snap) {
            if (snap.hasError) return FinState.error("Could not load the market data.".tr, onRetry: () => setState(() => _all = FinanceIntelService.securities()));
            if (!snap.hasData) return FinState.loading(rows: 4);
            final list = c.of(snap.data!);
            if (list.isEmpty) return FinState.empty(Icons.show_chart_rounded, "No security of this collection is published right now.".tr);
            return FinSection(title: "Securities".tr, divided: true, padding: _listPadding, children: [for (final s in list) _SecurityRow(security: s)]);
          },
        ),
        FinNotice("A collection is a themed selection for information. It is not a recommendation to buy or sell.".tr, tone: DsTone.warning),
        _FundsNotice("Spideli does not buy or sell shares: that needs a licensed broker. You can invest in regulated funds instead.".tr),
      ]),
    );
  }
}

/// Financial news and analyses, newest first, by category.
class _News extends StatefulWidget {
  const _News();

  @override
  State<_News> createState() => _NewsState();
}

class _NewsState extends State<_News> {
  late Stream<List<FinanceNews>> _news = FinanceIntelService.news();
  String? _category;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FinanceNews>>(
      stream: _news,
      builder: (context, snap) {
        if (snap.hasError) return FinState.error("Could not load the news.".tr, onRetry: () => setState(() => _news = FinanceIntelService.news()));
        if (!snap.hasData) return FinState.loading(rows: 4);
        final all = snap.data!;
        if (all.isEmpty) return FinState.empty(Icons.article_outlined, "No news is published yet.".tr);
        final categories = {for (final n in all) n.category}.toList();
        final String? category = categories.contains(_category) ? _category : null;
        final list = all.where((n) => category == null || n.category == category).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (categories.length > 1) _chips(context, categories, category, (c) => IntelLabels.newsCategory(c).tr, (v) => setState(() => _category = v)),
            FinSection(
              top: categories.length > 1 ? DsSpace.md : FinSpace.section,
              divided: true,
              padding: _listPadding,
              children: [
                for (final n in list)
                  FinListTile(
                    icon: n.category == 'analysis' ? Icons.analytics_outlined : Icons.article_outlined,
                    iconTone: DsTone.brand,
                    title: n.title,
                    subtitle: [n.source, _date(n.publishedAt), if (n.country.isNotEmpty) IntelLabels.country(n.country).tr].join(' · '),
                    chevron: true,
                    onTap: () => Get.to(() => NewsScreen(news: n)),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.md, left: DsSpace.xxs, right: DsSpace.xxs),
              child: _caption(context, "News and analyses from the sources shown, for information only. They are not investment advice.".tr),
            ),
          ],
        );
      },
    );
  }
}

/// One news item or analysis: its summary, source and date, and the full
/// article at its source.
class NewsScreen extends StatelessWidget {
  final FinanceNews news;

  const NewsScreen({super.key, required this.news});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final n = news;
    final Uri? url = n.url.isEmpty ? null : Uri.tryParse(n.url);
    return FinScaffold(
      title: IntelLabels.newsCategory(n.category).tr,
      bottomBar: url == null
          ? null
          : DsStickyBar(
              child: DsButton.primary(
                label: "Read the full article".tr,
                icon: Icons.open_in_new_rounded,
                size: DsButtonSize.lg,
                expand: true,
                onPressed: () => Constant().launchURL(url),
              ),
            ),
      body: FinBody(children: [
        FinSurface(
          padding: const EdgeInsets.all(DsSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(n.title, style: DsTypography.title.copyWith(color: c.textPrimary))),
              const DsGap(DsSpace.xs),
              finFreshness(context, [n.source, _dateTime(n.publishedAt), if (n.country.isNotEmpty) IntelLabels.country(n.country).tr].join(' · ')),
              if (n.summary.isNotEmpty) ...[
                const DsGap(DsSpace.md),
                SelectableText(n.summary, style: DsTypography.body.copyWith(color: c.textPrimary, height: 1.5)),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: DsSpace.md, left: DsSpace.xxs, right: DsSpace.xxs),
          child: _caption(context, "Published by @source. Spideli does not modify it. For information only, not investment advice.".trParams({'source': n.source})),
        ),
      ]),
    );
  }
}

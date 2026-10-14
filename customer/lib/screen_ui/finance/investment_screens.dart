import 'dart:math' as math;

import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/screen_ui/finance/financing_screens.dart';
import 'package:customer/screen_ui/finance/intelligence_screens.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_investment_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_investment_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;

String _date(DateTime? d) => d == null ? '-' : ltr(DateFormat('dd MMM yyyy').format(d));

/// Sections of list rows: the rows carry their own vertical padding.
const EdgeInsets _listPad = EdgeInsets.symmetric(horizontal: DsSpace.lg);

DsTone _riskTone(int level) => switch (RiskScale.band(level)) {
      'low' => DsTone.success,
      'medium' => DsTone.warning,
      _ => DsTone.danger,
    };

/// Performance (gains, returns) in its sign colour: green up, red down,
/// default when flat. This is performance, not money leaving the account.
Color? _gainColor(BuildContext context, num v) {
  final c = DsColors.of(context);
  return v > 0 ? c.successStrong : (v < 0 ? c.dangerStrong : null);
}

IconData _assetIcon(String? assetClass) => switch (assetClass) {
      'money_market' => Icons.account_balance_outlined,
      'bonds' => Icons.request_quote_outlined,
      'equities' => Icons.show_chart_rounded,
      'real_estate' => Icons.apartment_outlined,
      'agriculture' => Icons.agriculture_outlined,
      'infrastructure' => Icons.foundation_outlined,
      'mixed' => Icons.donut_small_outlined,
      _ => Icons.trending_up_rounded,
    };

String _fundStatus(String s) => const {'open': 'Open', 'closed': 'Closed to new investments', 'suspended': 'Suspended'}[s] ?? s;

Widget _caption(BuildContext context, String text) => Text(text, style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary));

Future<void> _open({String? storagePath, String? url}) async {
  ShowToastDialog.showLoader("Please wait...".tr);
  try {
    await FinanceInvestmentService.open(storagePath: storagePath, url: url);
    ShowToastDialog.closeLoader();
  } catch (_) {
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast("Could not open this document.".tr);
  }
}

/// A section title above a bare surface (FinMetrics), styled like FinSection's.
class _Overline extends StatelessWidget {
  final String text;

  const _Overline(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: FinSpace.section, bottom: DsSpace.sm, left: DsSpace.xxs, right: DsSpace.xxs),
        child: Semantics(header: true, child: Text(text.toUpperCase(), style: FinText.sectionTitle(context))),
      );
}

/// The asset class as a 40 px icon square, like the leading icon of FinListTile.
class _AssetWell extends StatelessWidget {
  final String assetClass;

  const _AssetWell({required this.assetClass});

  @override
  Widget build(BuildContext context) {
    final t = DsColors.of(context).tone(DsTone.brand);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: t.soft, borderRadius: DsRadius.brSm),
      child: Icon(_assetIcon(assetClass), size: 20, color: t.strong),
    );
  }
}

/// A current value with its change in percent below it (performance, coloured by sign).
class _ValueChange extends StatelessWidget {
  final String value;
  final double? percent;
  final num gains;

  const _ValueChange({required this.value, required this.percent, required this.gains});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(value, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary).tabular),
        if (percent != null) ...[
          const DsGap(DsSpace.xxs),
          Text(
            InvestmentLabels.percent(percent, signed: true),
            style: DsTypography.caption.copyWith(color: _gainColor(context, gains) ?? c.textSecondary, fontWeight: FontWeight.w600).tabular,
          ),
        ],
      ],
    );
  }
}

/// Spideli Finance > Investments: portfolio, fund catalog and orders.
/// `platform_settings/investments` must exist (admin).
class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  int _tab = 0;
  final Future<InvestmentConfig?> _config = FinanceInvestmentService.config();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InvestmentConfig?>(
      future: _config,
      builder: (context, cfgSnap) {
        final cfg = cfgSnap.data;
        return FinScaffold(
          title: "Investment".tr,
          actions: [
            if (cfg != null)
              DsIconButton(
                icon: Icons.calculate_outlined,
                semanticLabel: "Return simulator".tr,
                onPressed: () => Get.to(() => ReturnSimulatorScreen(config: cfg)),
              ),
          ],
          body: cfgSnap.connectionState == ConnectionState.waiting
              ? FinBody(children: [FinState.loading()])
              : cfg == null
                  ? FinBody(children: [FinState.empty(Icons.trending_up_rounded, "Investments are not available yet.".tr), const _FundingAndMarkets()])
                  : FinBody(
                      children: [
                        const _PortfolioHero(),
                        DsSegmentedTabs(
                          segments: [DsSegment("Portfolio".tr), DsSegment("Funds".tr), DsSegment("Orders".tr)],
                          index: _tab,
                          onChanged: (i) => setState(() => _tab = i),
                        ),
                        switch (_tab) {
                          0 => _Portfolio(config: cfg, onBrowse: () => setState(() => _tab = 1)),
                          1 => _Catalog(config: cfg),
                          _ => const _Orders(),
                        },
                        if (_tab == 0) const _FundingAndMarkets(),
                      ],
                    ),
        );
      },
    );
  }
}

/// Funding (projects open to investors, and financing for one's own project)
/// and the markets (indicators and exchange rates): the rest of the
/// Investment circle of the finance workflow.
class _FundingAndMarkets extends StatelessWidget {
  const _FundingAndMarkets();

  @override
  Widget build(BuildContext context) {
    return FinSection(
      title: "Funding and markets".tr,
      divided: true,
      children: [
        FinListTile(
          icon: Icons.lightbulb_outline_rounded,
          iconTone: DsTone.brand,
          title: "Invest in projects".tr,
          subtitle: "Back a project reviewed by Spideli".tr,
          chevron: true,
          onTap: () => Get.to(() => const IntelligenceScreen(view: IntelligenceView.funding)),
        ),
        FinListTile(
          icon: Icons.business_center_outlined,
          iconTone: DsTone.brand,
          title: "Finance my project".tr,
          subtitle: "Apply for funding for your business or project".tr,
          chevron: true,
          onTap: () => Get.to(() => const FinancingScreen()),
        ),
        FinListTile(
          icon: Icons.insights_outlined,
          iconTone: DsTone.brand,
          title: "Markets".tr,
          subtitle: "Economic indicators and exchange rates".tr,
          chevron: true,
          onTap: () => Get.to(() => const IntelligenceScreen(view: IntelligenceView.markets)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- portfolio

/// The focal point: the portfolio value and the server's totals. Shown once
/// the user has a portfolio (finance_summaries/{uid}.investments).
class _PortfolioHero extends StatelessWidget {
  const _PortfolioHero();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FinanceInvestmentService.portfolio(),
      builder: (context, snap) {
        final p = snap.data;
        final String cur = p?['currency']?.toString() ?? '';
        if (p == null || cur.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: FinSpace.section),
          child: FinHero(
            label: "Portfolio value".tr,
            amount: FinanceMoney.format(FinanceSummary.intOf(p['currentValuation']), cur),
            caption: "At the latest unit prices. Unrealized gains become final only when you redeem.".tr,
            stats: [
              FinHeroStat("Invested".tr, FinanceMoney.format(FinanceSummary.intOf(p['investedCapital']), cur)),
              FinHeroStat("Unrealized".tr, FinanceMoney.signed(FinanceSummary.intOf(p['unrealizedGains']), cur)),
              FinHeroStat("Realized".tr, FinanceMoney.signed(FinanceSummary.intOf(p['realizedGains']), cur)),
            ],
          ),
        );
      },
    );
  }
}

class _Portfolio extends StatelessWidget {
  final InvestmentConfig config;
  final VoidCallback onBrowse;

  const _Portfolio({required this.config, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<Map<String, dynamic>?>(
          stream: FinanceInvestmentService.portfolio(),
          builder: (context, snap) {
            final p = snap.data;
            final String cur = p?['currency']?.toString() ?? '';
            if (p == null || cur.isEmpty) return const SizedBox.shrink();
            final shares = Allocation.shares(p['allocation'] is Map ? Map<String, dynamic>.from(p['allocation'] as Map) : null);
            if (shares.isEmpty) return const SizedBox.shrink();
            return FinSection(
              title: "Asset allocation".tr,
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.sm),
              children: [
                FinShareBar(parts: [
                  for (final s in shares)
                    (InvestmentLabels.assetClass(s.assetClass).tr, s.value.toDouble(), '${FinanceMoney.format(s.value, cur)} · ${ltr('${s.percent} %')}'),
                ]),
              ],
            );
          },
        ),
        StreamBuilder<List<Holding>>(
          stream: FinanceInvestmentService.holdings(),
          builder: (context, snap) {
            if (snap.hasError) return FinState.error("Could not load your investments.".tr);
            if (!snap.hasData) return FinState.loading(rows: 2);
            if (snap.data!.isEmpty) {
              return FinState.empty(
                Icons.trending_up_rounded,
                "You have no investment yet.".tr,
                message: "Browse the funds, compare their risk and fees, and invest from the amount that suits you.".tr,
                actionLabel: "Browse the funds".tr,
                onAction: onBrowse,
              );
            }
            return FinSection(
              title: "My funds".tr,
              divided: true,
              padding: _listPad,
              children: [
                for (final h in snap.data!)
                  FinListTile(
                    icon: _assetIcon(h.assetClass),
                    iconTone: DsTone.brand,
                    title: h.fundName,
                    subtitle: '${InvestmentLabels.units(h.units)} ${"units".tr} · ${InvestmentLabels.assetClass(h.assetClass).tr}',
                    trailing: _ValueChange(value: FinanceMoney.format(h.currentValue, h.currency), percent: h.unrealizedPercent, gains: h.unrealizedGains),
                    chevron: true,
                    onTap: () => Get.to(() => HoldingScreen(fundId: h.fundId, config: config)),
                  ),
              ],
            );
          },
        ),
        const _Reports(),
        FinSection(
          padding: _listPad,
          children: [
            FinListTile(
              icon: Icons.calculate_outlined,
              iconTone: DsTone.brand,
              title: "Return simulator".tr,
              subtitle: "See how an amount could grow over time.".tr,
              chevron: true,
              onTap: () => Get.to(() => ReturnSimulatorScreen(config: config)),
            ),
          ],
        ),
      ],
    );
  }
}

class _Reports extends StatelessWidget {
  const _Reports();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceInvestmentService.reports(),
      builder: (context, snap) {
        final list = (snap.data ?? const []).where((r) => (r['storagePath'] ?? '').toString().isNotEmpty).toList();
        if (list.isEmpty) return const SizedBox.shrink();
        final c = DsColors.of(context);
        return FinSection(
          title: "Statements and reports".tr,
          divided: true,
          padding: _listPad,
          children: [
            for (final r in list)
              FinListTile(
                icon: Icons.picture_as_pdf_outlined,
                title: r['title']?.toString() ?? "Statement".tr,
                subtitle: FinanceUi.day(r['createdAt']),
                trailing: Icon(Icons.download_rounded, size: 20, color: c.textMuted),
                onTap: () => _open(storagePath: r['storagePath'].toString()),
              ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------ catalog

class _Catalog extends StatefulWidget {
  final InvestmentConfig config;

  const _Catalog({required this.config});

  @override
  State<_Catalog> createState() => _CatalogState();
}

class _CatalogState extends State<_Catalog> {
  String? _assetClass;
  String? _risk;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Fund>>(
      stream: FinanceInvestmentService.funds(),
      builder: (context, snap) {
        if (snap.hasError) return FinState.error("Could not load the funds.".tr);
        if (!snap.hasData) return FinState.loading();
        final all = snap.data!;
        final classes = {...widget.config.assetClasses.where((c) => all.any((f) => f.assetClass == c)), ...all.map((f) => f.assetClass)}.toList();
        final funds = all.where((f) => (_assetClass == null || f.assetClass == _assetClass) && (_risk == null || RiskScale.band(f.riskLevel) == _risk)).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DsGap(DsSpace.lg),
            if (classes.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final c in [null, ...classes])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: DsSpace.sm),
                      child: ChoiceChip(
                        label: Text(c == null ? "All".tr : InvestmentLabels.assetClass(c).tr),
                        selected: _assetClass == c,
                        onSelected: (_) => setState(() => _assetClass = c),
                      ),
                    ),
                ]),
              ),
            const DsGap(DsSpace.xs),
            Wrap(
              spacing: DsSpace.sm,
              children: [
                for (final b in RiskScale.bands)
                  FilterChip(
                    label: Text(RiskScale.bandLabel(b).tr),
                    selected: _risk == b,
                    onSelected: (v) => setState(() => _risk = v ? b : null),
                  ),
              ],
            ),
            if (funds.isEmpty)
              FinState.empty(Icons.search_off_rounded, (all.isEmpty ? "No fund is open yet." : "No fund matches these filters.").tr)
            else
              FinSection(
                top: DsSpace.md,
                divided: true,
                padding: _listPad,
                footnote: "Past performance does not predict future returns.".tr,
                children: [for (final f in funds) _FundRow(fund: f, config: widget.config)],
              ),
          ],
        );
      },
    );
  }
}

/// A fund of the catalog: asset class, risk on the 1-7 scale, minimum and
/// the past 1-year return.
class _FundRow extends StatelessWidget {
  final Fund fund;
  final InvestmentConfig config;

  const _FundRow({required this.fund, required this.config});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final f = fund;
    final double? oneYear = f.performance['oneYear'];
    return MergeSemantics(
      child: InkWell(
        onTap: () => Get.to(() => FundScreen(fundId: f.id, config: config)),
        borderRadius: DsRadius.brSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AssetWell(assetClass: f.assetClass),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.name, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const DsGap(DsSpace.xxs),
                    Text(
                      [InvestmentLabels.assetClass(f.assetClass).tr, if (f.manager.isNotEmpty) f.manager].join(' · '),
                      style: DsTypography.caption.copyWith(color: c.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const DsGap(DsSpace.sm),
                    _RiskMeter(level: f.riskLevel),
                    if (f.status != 'open') ...[
                      const DsGap(DsSpace.sm),
                      FinStatusChip(status: f.status, label: _fundStatus(f.status).tr),
                    ],
                    const DsGap(DsSpace.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _Figure(label: "Minimum".tr, value: FinanceMoney.format(f.minInvestment, f.currency))),
                        if (oneYear != null)
                          Expanded(
                            child: _Figure(
                              label: "Past 1-year return".tr,
                              value: InvestmentLabels.percent(oneYear, signed: true),
                              color: _gainColor(context, oneYear),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const DsGap(DsSpace.xs),
              Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small label / value pair inside a row.
class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Figure({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DsTypography.caption.copyWith(color: c.textSecondary)),
        const DsGap(DsSpace.xxs),
        Text(value, style: DsTypography.bodyStrong.copyWith(color: color ?? c.textPrimary).tabular),
      ],
    );
  }
}

/// The 1-7 risk scale, compact: the fund's level highlighted, and its label.
class _RiskMeter extends StatelessWidget {
  final int level;

  const _RiskMeter({required this.level});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final active = c.tone(_riskTone(level)).main;
    return Semantics(
      label: '${"Risk level".tr} $level / 7, ${RiskScale.label(level).tr}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (int i = 1; i <= 7; i++)
              Container(
                width: 10,
                height: 6,
                margin: const EdgeInsetsDirectional.only(end: 2),
                decoration: BoxDecoration(color: i == level ? active : c.surfaceAlt, borderRadius: BorderRadius.circular(2)),
              ),
            const DsGap(DsSpace.sm),
            Flexible(
              child: Text(
                '${RiskScale.label(level).tr} · ${ltr('$level/7')}',
                style: DsTypography.caption.copyWith(color: c.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- fund

/// A fund: objective, risk, fees, terms, performance, price history and documents.
class FundScreen extends StatelessWidget {
  final String fundId;
  final InvestmentConfig config;

  const FundScreen({super.key, required this.fundId, required this.config});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Fund?>(
      stream: FinanceInvestmentService.fund(fundId),
      builder: (context, snap) {
        final f = snap.data;
        return StreamBuilder<Holding?>(
          stream: FinanceInvestmentService.holding(fundId),
          builder: (context, hs) {
            final h = hs.data;
            final bool holder = h?.hasUnits == true;
            return FinScaffold(
              title: "Fund".tr,
              bottomBar: f == null || !f.acceptsSubscriptions
                  ? null
                  : DsStickyBar(
                      child: FinanceKycGate(
                        builder: (context, verified) => DsButton.primary(
                          label: (holder ? "Invest more" : "Invest").tr,
                          icon: Icons.add_rounded,
                          size: DsButtonSize.lg,
                          expand: true,
                          onPressed: verified ? () => Get.to(() => SubscribeScreen(fund: f, config: config, holder: holder)) : null,
                        ),
                      ),
                    ),
              body: snap.hasError
                  ? FinBody(children: [FinState.error("Could not load this fund.".tr)])
                  : f == null
                      ? const FinBody(children: [DsSkeletonForm(fields: 5)])
                      : _FundBody(fund: f, holding: h, config: config),
            );
          },
        );
      },
    );
  }
}

class _FundBody extends StatelessWidget {
  final Fund fund;
  final Holding? holding;
  final InvestmentConfig config;

  const _FundBody({required this.fund, required this.holding, required this.config});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final f = fund;
    final h = holding;
    String pct(double v) => InvestmentLabels.percent(v);
    final periods = [for (final p in InvestmentLabels.periods) if (f.performance[p] != null) p];
    return FinBody(
      children: [
        FinHeader(
          icon: _assetIcon(f.assetClass),
          overline: InvestmentLabels.assetClass(f.assetClass).tr,
          title: f.name,
          subtitle: f.manager.isEmpty ? null : '${"Managed by".tr} ${f.manager}',
          status: f.status == 'open' ? null : f.status,
          statusLabel: f.status == 'open' ? null : _fundStatus(f.status).tr,
          below: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Divider(height: 1, thickness: 1, color: c.divider),
              const DsGap(DsSpace.md),
              _RiskScaleView(level: f.riskLevel),
            ],
          ),
        ),
        if (h != null && h.hasUnits)
          FinSection(
            title: "Your position".tr,
            padding: _listPad,
            children: [
              FinListTile(
                icon: Icons.account_balance_wallet_outlined,
                iconTone: DsTone.brand,
                title: "Current value".tr,
                subtitle: '${InvestmentLabels.units(h.units)} ${"units".tr} · ${"Invested capital".tr} ${FinanceMoney.format(h.investedAmount, h.currency)}',
                trailing: _ValueChange(value: FinanceMoney.format(h.currentValue, h.currency), percent: h.unrealizedPercent, gains: h.unrealizedGains),
                chevron: true,
                onTap: () => Get.to(() => HoldingScreen(fundId: f.id, config: config)),
              ),
            ],
          ),
        if (f.objective.isNotEmpty || f.description.isNotEmpty)
          FinSection(
            title: "Objective".tr,
            padding: const EdgeInsets.all(DsSpace.lg),
            children: [
              if (f.objective.isNotEmpty) Text(f.objective, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary)),
              if (f.description.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: f.objective.isNotEmpty ? DsSpace.xs : 0),
                  child: Text(f.description, style: DsTypography.body.copyWith(color: c.textSecondary)),
                ),
            ],
          ),
        FinSection(
          title: "Key facts".tr,
          divided: true,
          children: [
            FinRow("Unit price".tr, f.navPerUnit == null ? '-' : FinanceMoney.format(f.navPerUnit!, f.currency)),
            if (f.navDate != null) FinRow("Price date".tr, _date(f.navDate)),
            FinRow("Minimum investment".tr, FinanceMoney.format(f.minInvestment, f.currency)),
            if (f.minAdditional != f.minInvestment) FinRow("Minimum further investment".tr, FinanceMoney.format(f.minAdditional, f.currency)),
            FinRow("Subscription fee".tr, pct(f.subscriptionFeePercent)),
            FinRow("Management fee".tr, '${pct(f.managementFeePercent)} ${"a year".tr}'),
            FinRow("Redemption fee".tr, pct(f.redemptionFeePercent)),
            if (f.performanceFeePercent > 0) FinRow("Performance fee".tr, pct(f.performanceFeePercent)),
            FinRow("Lock-up period".tr, f.lockUpDays == 0 ? "None".tr : '${f.lockUpDays} ${"days".tr}'),
            FinRow("Redemptions".tr, !f.redemptionAllowed ? "Not possible".tr : (f.partialRedemption ? "Partial or full" : "Full only").tr),
            FinRow("Paid out within".tr, '${f.settlementDays} ${"business days".tr}'),
          ],
        ),
        if (f.eligibility.isNotEmpty) FinNotice(f.eligibility, title: "Who can invest".tr),
        if (periods.isNotEmpty)
          FinSection(
            title: "Past performance".tr,
            divided: true,
            footnote: "Past performance does not predict future returns.".tr,
            children: [
              for (final p in periods)
                FinRow(
                  InvestmentLabels.period(p).tr,
                  InvestmentLabels.percent(f.performance[p], signed: true),
                  valueColor: _gainColor(context, f.performance[p]!),
                ),
            ],
          ),
        StreamBuilder<List<NavPoint>>(
          stream: FinanceInvestmentService.valuations(f.id),
          builder: (context, snap) {
            final points = snap.data ?? const <NavPoint>[];
            if (points.length < 2) return const SizedBox.shrink();
            return FinSection(
              title: "Unit price history".tr,
              padding: const EdgeInsets.all(DsSpace.lg),
              children: [_NavChart(points: points, currency: f.currency)],
            );
          },
        ),
        if (f.documents.isNotEmpty)
          FinSection(
            title: "Documents".tr,
            divided: true,
            padding: _listPad,
            children: [
              for (final d in f.documents)
                FinListTile(
                  icon: Icons.description_outlined,
                  title: d.name,
                  trailing: Icon(Icons.open_in_new_rounded, size: 20, color: c.textMuted),
                  onTap: () => _open(storagePath: d.storagePath, url: d.url),
                ),
            ],
          ),
        if (f.terms.isNotEmpty)
          FinSection(
            title: "Terms".tr,
            padding: const EdgeInsets.all(DsSpace.lg),
            footnote: '${"Version".tr} ${f.termsVersion}',
            children: [Text(f.terms, style: DsTypography.body.copyWith(color: c.textPrimary))],
          ),
        FinSection(
          padding: _listPad,
          children: [
            FinListTile(
              icon: Icons.calculate_outlined,
              iconTone: DsTone.brand,
              title: "Simulate a return".tr,
              subtitle: "See how an amount could grow over time.".tr,
              chevron: true,
              onTap: () => Get.to(() => ReturnSimulatorScreen(config: config, currency: f.currency, annualPercent: f.performance['oneYear'])),
            ),
          ],
        ),
      ],
    );
  }
}

/// The 1-7 risk scale with the fund's level highlighted.
class _RiskScaleView extends StatelessWidget {
  final int level;

  const _RiskScaleView({required this.level});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final active = c.tone(_riskTone(level)).main;
    return Semantics(
      label: '${"Risk level".tr} $level / 7, ${RiskScale.label(level).tr}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text("Risk level".tr, style: DsTypography.labelSm.copyWith(color: c.textSecondary))),
              Text(RiskScale.label(level).tr, style: DsTypography.bodyStrong.copyWith(color: c.tone(_riskTone(level)).strong)),
            ]),
            const DsGap(DsSpace.sm),
            Row(children: [
              for (int i = 1; i <= 7; i++)
                Expanded(
                  child: Container(
                    height: 28,
                    margin: EdgeInsetsDirectional.only(end: i < 7 ? 4 : 0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: i == level ? active : c.surfaceAlt, borderRadius: DsRadius.brSm),
                    child: Text('$i', style: DsTypography.labelSm.copyWith(color: i == level ? Colors.white : c.textSecondary).tabular),
                  ),
                ),
            ]),
            const DsGap(DsSpace.xs),
            Row(children: [
              Expanded(child: _caption(context, "Lower risk, lower potential return".tr)),
              const DsGap(DsSpace.sm),
              Expanded(child: Text("Higher risk, higher potential return".tr, textAlign: TextAlign.end, style: DsTypography.caption.copyWith(color: c.textSecondary))),
            ]),
          ],
        ),
      ),
    );
  }
}

/// The unit price over time, as a line, with its change over the period.
class _NavChart extends StatelessWidget {
  final List<NavPoint> points;
  final String currency;

  const _NavChart({required this.points, required this.currency});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final double lo = points.map((p) => p.nav).reduce(math.min);
    final double hi = points.map((p) => p.nav).reduce(math.max);
    final double? change = navChangePercent(points);
    return Semantics(
      label:
          '${"Unit price".tr}: ${FinanceMoney.format(points.first.nav, currency)} ${_date(points.first.date)}, ${FinanceMoney.format(points.last.nav, currency)} ${_date(points.last.date)}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _caption(context, "Unit price".tr),
                    const DsGap(DsSpace.xxs),
                    Text(FinanceMoney.format(points.last.nav, currency), style: DsTypography.titleSm.copyWith(color: c.textPrimary).tabular),
                  ]),
                ),
                if (change != null)
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    _caption(context, "Change".tr),
                    const DsGap(DsSpace.xxs),
                    Text(
                      InvestmentLabels.percent(change, signed: true),
                      style: DsTypography.titleSm.copyWith(color: _gainColor(context, change) ?? c.textPrimary).tabular,
                    ),
                  ]),
              ],
            ),
            const DsGap(DsSpace.md),
            FinanceLineChart(values: points.map((p) => p.nav).toList()),
            const DsGap(DsSpace.xs),
            Row(children: [
              Expanded(child: _caption(context, _date(points.first.date))),
              _caption(context, _date(points.last.date)),
            ]),
            const DsGap(DsSpace.sm),
            Row(children: [
              Expanded(child: _caption(context, '${"High".tr} ${FinanceMoney.format(hi, currency)}')),
              _caption(context, '${"Low".tr} ${FinanceMoney.format(lo, currency)}'),
            ]),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- subscribe

/// Investing in a fund: amount, estimate, risk disclosure, terms and the
/// electronic signature, then the payment.
class SubscribeScreen extends StatefulWidget {
  final Fund fund;
  final InvestmentConfig config;
  final bool holder;

  const SubscribeScreen({super.key, required this.fund, required this.config, required this.holder});

  @override
  State<SubscribeScreen> createState() => _SubscribeScreenState();
}

class _SubscribeScreenState extends State<SubscribeScreen> {
  final _amount = TextEditingController();
  final _signature = TextEditingController();
  bool _termsAccepted = false;
  bool _riskAccepted = false;

  @override
  void dispose() {
    _amount.dispose();
    _signature.dispose();
    super.dispose();
  }

  Future<void> _continue(int amount) async {
    final f = widget.fund;
    final key = FinanceGroupService.newRequestKey();
    bool sent = false;
    await FinancePaySheet.show(
      context,
      title: "${"Invest in".tr} ${f.name}",
      amount: amount,
      currency: f.currency,
      methods: widget.config.paymentMethods,
      submit: (payment) async {
        final reply = await FinanceInvestmentService.subscribe(
          fundId: f.id,
          amount: amount,
          currency: f.currency,
          termsVersion: f.termsVersion,
          signatureName: _signature.text.trim(),
          payment: payment,
          requestKey: key,
        );
        sent = true;
        return reply;
      },
    );
    if (sent && mounted) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final f = widget.fund;
    final int min = f.minimumFor(holder: widget.holder);
    final int? amount = FinanceAmount.parse(_amount.text, f.currency);
    final bool tooLow = amount != null && amount < min;
    final estimate = amount == null || tooLow ? null : InvestmentCalculator.subscription(f, amount);
    final bool ready = estimate != null && _termsAccepted && _riskAccepted && _signature.text.trim().length >= 3;
    return FinScaffold(
      title: "Invest".tr,
      bottomBar: DsStickyBar(
        child: FinanceKycGate(
          builder: (context, verified) => DsButton.primary(
            label: "Continue to payment".tr,
            icon: Icons.lock_outline_rounded,
            size: DsButtonSize.lg,
            expand: true,
            onPressed: verified && ready ? () => _continue(amount!) : null,
          ),
        ),
      ),
      body: FinBody(
        children: [
          FinSection(
            top: 0,
            title: "Fund".tr,
            padding: _listPad,
            children: [
              FinListTile(
                icon: _assetIcon(f.assetClass),
                iconTone: DsTone.brand,
                title: f.name,
                subtitle: '${InvestmentLabels.assetClass(f.assetClass).tr} · ${RiskScale.label(f.riskLevel).tr} · ${ltr('${f.riskLevel}/7')}',
              ),
            ],
          ),
          FinSection(
            title: "Amount".tr,
            padding: const EdgeInsets.all(DsSpace.lg),
            children: [
              DsTextField(
                label: "${"Amount".tr} (${f.currency})",
                controller: _amount,
                requiredMark: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                helper: '${"Minimum".tr}: ${FinanceMoney.format(min, f.currency)}',
                errorText: tooLow ? '${"Minimum".tr}: ${FinanceMoney.format(min, f.currency)}' : null,
                bottomSpacing: 0,
              ),
            ],
          ),
          if (estimate != null) ...[
            FinSection(
              title: "Estimate".tr,
              divided: true,
              children: [
                FinRow("You pay".tr, FinanceMoney.format(estimate.gross, f.currency), strong: true),
                FinRow("Subscription fee".tr, '${FinanceMoney.format(estimate.fee, f.currency)} (${InvestmentLabels.percent(f.subscriptionFeePercent)})'),
                FinRow("Invested in the fund".tr, FinanceMoney.format(estimate.net, f.currency)),
                if (estimate.units != null) FinRow("Estimated units".tr, InvestmentLabels.units(estimate.units!)),
                if (f.navPerUnit != null) FinRow("Last unit price".tr, FinanceMoney.format(f.navPerUnit!, f.currency), sub: f.navDate == null ? null : _date(f.navDate)),
                if (f.lockUpDays > 0) FinRow("Lock-up period".tr, '${f.lockUpDays} ${"days".tr}'),
              ],
            ),
            FinNotice(
              "Units are bought at the unit price of the processing date, after your payment is confirmed. The final number of units can differ from this estimate.".tr,
            ),
          ],
          FinSection(
            title: "Risks".tr,
            children: [
              FinNotice(widget.config.riskDisclosure, tone: DsTone.warning),
              _Consent(
                value: _riskAccepted,
                onChanged: (v) => setState(() => _riskAccepted = v),
                text: "I understand that the value of my investment can go down as well as up, and that I may lose part of the money invested.".tr,
              ),
            ],
          ),
          FinSection(
            title: "Fund terms".tr,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: DsSpace.sm, bottom: DsSpace.xs),
                child: _caption(context, '${"Version".tr} ${f.termsVersion}'),
              ),
              if (f.terms.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  margin: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                  padding: const EdgeInsets.all(DsSpace.md),
                  decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brSm),
                  child: Scrollbar(child: SingleChildScrollView(child: Text(f.terms, style: DsTypography.body.copyWith(color: c.textPrimary)))),
                ),
              for (final d in f.documents)
                FinListTile(
                  icon: Icons.description_outlined,
                  title: d.name,
                  trailing: Icon(Icons.open_in_new_rounded, size: 20, color: c.textMuted),
                  onTap: () => _open(storagePath: d.storagePath, url: d.url),
                ),
              _Consent(
                value: _termsAccepted,
                onChanged: (v) => setState(() => _termsAccepted = v),
                text: "I have read the fund terms and documents, and I accept them.".tr,
              ),
            ],
          ),
          FinSection(
            title: "Electronic signature".tr,
            padding: const EdgeInsets.all(DsSpace.lg),
            children: [
              Text(
                "Type your full name to sign the subscription. It is recorded with the date and the terms version.".tr,
                style: DsTypography.bodySm.copyWith(color: c.textSecondary),
              ),
              const DsGap(DsSpace.md),
              DsTextField(
                label: "Full name".tr,
                controller: _signature,
                requiredMark: true,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                bottomSpacing: 0,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A consent line: checkbox first, then what the user agrees to.
class _Consent extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;

  const _Consent({required this.value, required this.onChanged, required this.text});

  @override
  Widget build(BuildContext context) => CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        title: Text(text, style: DsTypography.body.copyWith(color: DsColors.of(context).textPrimary)),
      );
}

// ------------------------------------------------------------------ holding

/// The user's position in one fund, its history and redemptions.
class HoldingScreen extends StatelessWidget {
  final String fundId;
  final InvestmentConfig config;

  const HoldingScreen({super.key, required this.fundId, required this.config});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Fund?>(
      stream: FinanceInvestmentService.fund(fundId),
      builder: (context, fs) => StreamBuilder<Holding?>(
        stream: FinanceInvestmentService.holding(fundId),
        builder: (context, hs) {
          final pageContext = context;
          final f = fs.data;
          final h = hs.data;
          final Holding? shown = !hs.hasError && hs.connectionState != ConnectionState.waiting && h != null && h.hasUnits ? h : null;
          Widget? bar;
          if (shown != null && f != null && f.redemptionAllowed && f.status != 'suspended' && shown.redeemableValue > 0) {
            bar = DsStickyBar(
              child: FinanceKycGate(
                builder: (context, verified) => DsButton.secondary(
                  label: "Redeem".tr,
                  icon: Icons.south_west_rounded,
                  size: DsButtonSize.lg,
                  expand: true,
                  onPressed: verified ? () => _redeem(pageContext, shown, f, config) : null,
                ),
              ),
            );
          }
          return FinScaffold(
            title: h?.fundName ?? f?.name ?? "My investment".tr,
            actions: [
              if (f != null) DsIconButton(icon: Icons.info_outline_rounded, semanticLabel: "Fund details".tr, onPressed: () => Get.to(() => FundScreen(fundId: fundId, config: config))),
            ],
            bottomBar: bar,
            body: hs.hasError
                ? FinBody(children: [FinState.error("Could not load your investment.".tr)])
                : hs.connectionState == ConnectionState.waiting
                    ? const FinBody(children: [DsSkeletonForm(fields: 4)])
                    : shown == null
                        ? FinBody(children: [FinState.empty(Icons.trending_up_rounded, "You hold no units of this fund.".tr)])
                        : _HoldingBody(holding: shown, fund: f),
          );
        },
      ),
    );
  }
}

/// Redeeming part or all of a holding: what, the estimate, then where to receive it.
Future<void> _redeem(BuildContext context, Holding h, Fund f, InvestmentConfig config) async {
  bool full = !f.partialRedemption;
  int? amount;
  if (f.partialRedemption) {
    final choice = await finSheet<String>(
      title: "Redeem".tr,
      child: Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinListTile(
              icon: Icons.pie_chart_outline_rounded,
              title: "Part of my investment".tr,
              subtitle: "Choose an amount".tr,
              chevron: true,
              onTap: () => Get.back(result: 'partial'),
            ),
            Divider(height: 1, thickness: 1, color: DsColors.of(context).divider),
            FinListTile(
              icon: Icons.account_balance_wallet_outlined,
              title: "All that can be redeemed".tr,
              subtitle: '≈ ${FinanceMoney.format(h.redeemableValue, h.currency)}',
              chevron: true,
              onTap: () => Get.back(result: 'full'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    full = choice == 'full';
    if (!full) {
      amount = await askAmount(context, title: "How much do you redeem?".tr, currency: h.currency, max: h.redeemableValue);
      if (amount == null || !context.mounted) return;
    }
  }
  final int gross = amount ?? h.redeemableValue;
  final estimate = InvestmentCalculator.redemption(f, gross);
  final ok = await finConfirm(
    title: "Redemption estimate".tr,
    message: "The final amount uses the unit price of the processing date.".tr,
    lines: [
      ((full ? "Whole redeemable position" : "Amount redeemed").tr, FinanceMoney.format(gross, h.currency)),
      if (estimate.units != null) ("Estimated units".tr, InvestmentLabels.units(full ? h.redeemableUnits : estimate.units!)),
      ("Redemption fee".tr, '${FinanceMoney.format(estimate.fee, h.currency)} (${InvestmentLabels.percent(f.redemptionFeePercent)})'),
      ("Paid out within".tr, '${f.settlementDays} ${"business days".tr}'),
    ],
    total: ("You receive about".tr, FinanceMoney.format(estimate.net, h.currency)),
    confirmLabel: "Continue".tr,
  );
  if (!ok || !context.mounted) return;
  final key = FinanceGroupService.newRequestKey();
  await FinancePaySheet.show(
    context,
    title: "Redeem".tr,
    amount: gross,
    currency: h.currency,
    methods: config.paymentMethods,
    payout: true,
    submit: (destination) => FinanceInvestmentService.redeem(fundId: h.fundId, full: full, amount: amount, destination: destination, requestKey: key),
  );
}

class _HoldingBody extends StatelessWidget {
  final Holding holding;
  final Fund? fund;

  const _HoldingBody({required this.holding, required this.fund});

  @override
  Widget build(BuildContext context) {
    final h = holding;
    final f = fund;
    final double? unrealizedPercent = h.unrealizedPercent;
    return FinBody(
      children: [
        FinHeader(
          icon: _assetIcon(h.assetClass),
          overline: "Current value".tr,
          title: FinanceMoney.format(h.currentValue, h.currency),
          subtitle: h.valuedAt == null ? null : '${"Valued on".tr} ${_date(h.valuedAt)}',
        ),
        const DsGap(DsSpace.md),
        FinMetrics(items: [
          FinMetric("Units".tr, InvestmentLabels.units(h.units)),
          FinMetric("Invested capital".tr, FinanceMoney.format(h.investedAmount, h.currency)),
          FinMetric(
            "Unrealized gains".tr,
            FinanceMoney.signed(h.unrealizedGains, h.currency),
            sub: unrealizedPercent == null ? null : InvestmentLabels.percent(unrealizedPercent, signed: true),
            color: _gainColor(context, h.unrealizedGains),
          ),
          FinMetric("Realized gains".tr, FinanceMoney.signed(h.realizedGains, h.currency), color: _gainColor(context, h.realizedGains)),
          if (f?.navPerUnit != null) FinMetric("Unit price".tr, FinanceMoney.format(f!.navPerUnit!, f.currency), sub: f.navDate == null ? null : _date(f.navDate)),
        ]),
        if (h.partlyLocked)
          FinNotice(
            '${"Redeemable now".tr}: ${InvestmentLabels.units(h.redeemableUnits)} ${"units".tr} (${FinanceMoney.format(h.redeemableValue, h.currency)}).${h.lockedUntil == null ? '' : ' ${"The rest from".tr} ${_date(h.lockedUntil)}.'}',
            title: "Lock-up period".tr,
          ),
        if (f != null && !f.redemptionAllowed) FinNotice("This fund does not accept redemptions at the moment.".tr, tone: DsTone.neutral),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FinanceInvestmentService.transactions(h.fundId),
          builder: (context, snap) {
            if (!snap.hasData && !snap.hasError) return FinState.loading(rows: 2);
            final list = snap.data ?? const [];
            if (list.isEmpty) return const SizedBox.shrink();
            return FinSection(
              title: "History".tr,
              divided: true,
              padding: _listPad,
              children: [
                for (final t in list)
                  Builder(builder: (context) {
                    final String? type = t['type']?.toString();
                    final bool back = type == 'redemption' || type == 'distribution';
                    final int amount = FinanceSummary.intOf(t['amount']);
                    return FinListTile(
                      icon: back ? Icons.south_west_rounded : Icons.north_east_rounded,
                      iconTone: back ? DsTone.success : DsTone.neutral,
                      title: InvestmentLabels.transaction(type).tr,
                      subtitle: [
                        FinanceUi.day(t['createdAt']),
                        if (t['units'] is num) '${InvestmentLabels.units((t['units'] as num).toDouble())} ${"units".tr}',
                        if (t['navPerUnit'] is num) '@ ${FinanceMoney.format(t['navPerUnit'] as num, h.currency)}',
                      ].join(' · '),
                      amount: FinanceMoney.format(amount, h.currency),
                      amountColor: back ? finAmountColor(context, amount) : null,
                    );
                  }),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- orders

/// Subscriptions and redemptions, newest first.
class _Orders extends StatelessWidget {
  const _Orders();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceInvestmentService.subscriptions(),
      builder: (context, ss) => StreamBuilder<List<Map<String, dynamic>>>(
        stream: FinanceInvestmentService.redemptions(),
        builder: (context, rs) {
          if (ss.hasError || rs.hasError) return FinState.error("Could not load your orders.".tr);
          if (!ss.hasData || !rs.hasData) return FinState.loading();
          final orders = [
            for (final o in ss.data!) ('investment_subscriptions', o),
            for (final o in rs.data!) ('investment_redemptions', o),
          ]..sort((a, b) => (FinanceGroupService.toDate(b.$2['createdAt']) ?? DateTime(0)).compareTo(FinanceGroupService.toDate(a.$2['createdAt']) ?? DateTime(0)));
          if (orders.isEmpty) return FinState.empty(Icons.receipt_long_outlined, "You have no investment order yet.".tr);
          return FinSection(
            divided: true,
            padding: _listPad,
            children: [
              for (final (collection, o) in orders)
                Builder(builder: (context) {
                  final bool redemption = collection == 'investment_redemptions';
                  final String? status = o['status']?.toString();
                  final String type = (redemption ? "Redemption" : "Investment").tr;
                  final String fund = (o['fundName'] ?? '').toString();
                  return FinListTile(
                    icon: redemption ? Icons.south_west_rounded : Icons.north_east_rounded,
                    iconTone: redemption ? DsTone.success : DsTone.neutral,
                    title: fund.isNotEmpty ? fund : type,
                    subtitle: [if (fund.isNotEmpty) type, FinanceUi.day(o['createdAt'])].join(' · '),
                    amount: o['full'] == true && o['amount'] == null
                        ? "All".tr
                        : FinanceMoney.format(FinanceSummary.intOf(o['amount']), o['currency']?.toString() ?? ''),
                    status: status ?? '',
                    statusLabel: InvestmentOrders.label(status).tr,
                    onTap: () => Get.to(() => InvestmentOrderScreen(collection: collection, orderId: o['id'].toString())),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

/// One subscription or redemption and its processing and settlement.
class InvestmentOrderScreen extends StatelessWidget {
  final String collection;
  final String orderId;

  const InvestmentOrderScreen({super.key, required this.collection, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final bool redemption = collection == 'investment_redemptions';
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FinanceInvestmentService.order(collection, orderId),
      builder: (context, snap) {
        final o = snap.data;
        return FinScaffold(
          title: (redemption ? "Redemption" : "Investment").tr,
          body: snap.hasError
              ? FinBody(children: [FinState.error("Could not load this order.".tr)])
              : o == null
                  ? const FinBody(children: [DsSkeletonForm(fields: 4)])
                  : _orderBody(context, o, redemption),
        );
      },
    );
  }

  Widget _orderBody(BuildContext context, Map<String, dynamic> o, bool redemption) {
    final c = DsColors.of(context);
    final String status = o['status']?.toString() ?? '';
    final String cur = o['currency']?.toString() ?? '';
    final String fund = (o['fundName'] ?? '').toString();
    final steps = redemption ? InvestmentOrders.redemptionSteps : InvestmentOrders.subscriptionSteps;
    final int at = steps.indexOf(status);
    String m(dynamic v) => FinanceMoney.format(FinanceSummary.intOf(v), cur);
    final String amount = o['amount'] == null ? "All that can be redeemed".tr : m(o['amount']);
    return FinBody(
      children: [
        FinHeader(
          icon: redemption ? Icons.south_west_rounded : Icons.north_east_rounded,
          overline: fund.isNotEmpty ? fund : null,
          title: amount,
          status: status.isEmpty ? null : status,
          statusLabel: InvestmentOrders.label(status).tr,
          below: !InvestmentOrders.ended(status) && at >= 0
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Divider(height: 1, thickness: 1, color: c.divider),
                    const DsGap(DsSpace.md),
                    FinTrack(steps: [for (final s in steps) InvestmentOrders.label(s).tr], current: at),
                  ],
                )
              : null,
        ),
        if ((o['reason'] ?? '').toString().isNotEmpty) FinNotice(o['reason'].toString(), title: "Reason".tr, tone: FinStatus.tone(status)),
        FinSection(
          title: "Details".tr,
          divided: true,
          children: [
            if (o['fee'] != null) FinRow("Fee".tr, m(o['fee'])),
            if (o['netAmount'] != null) FinRow((redemption ? "Paid out" : "Invested in the fund").tr, m(o['netAmount'])),
            if (o['units'] is num) FinRow("Units".tr, InvestmentLabels.units((o['units'] as num).toDouble())),
            if (o['navPerUnit'] is num) FinRow("Unit price".tr, FinanceMoney.format(o['navPerUnit'] as num, cur)),
            if (o['termsVersion'] != null) FinRow("Terms version".tr, '${o['termsVersion']}'),
            FinRow("Requested on".tr, FinanceUi.date(o['createdAt'])),
            if (o['tradeDate'] != null) FinRow("Processed on".tr, FinanceUi.date(o['tradeDate'])),
            if (o['expectedSettlementDate'] != null && o['settledAt'] == null) FinRow("Expected payment".tr, FinanceUi.day(o['expectedSettlementDate'])),
            if (o['settledAt'] != null) FinRow("Paid out on".tr, FinanceUi.date(o['settledAt'])),
            if ((o['reference'] ?? '').toString().isNotEmpty) FinRow("Reference".tr, ltrRef(o['reference'])),
          ],
        ),
        if (redemption && InvestmentOrders.canCancelRedemption(status))
          Padding(
            padding: const EdgeInsets.only(top: FinSpace.section),
            child: DsButton.ghost(
              label: "Cancel this redemption".tr,
              icon: Icons.close_rounded,
              expand: true,
              onPressed: () async {
                final ok = await finConfirm(
                  title: "Cancel this redemption?".tr,
                  lines: [
                    if (fund.isNotEmpty) ("Fund".tr, fund),
                    ("Amount redeemed".tr, amount),
                  ],
                  confirmLabel: "Cancel this redemption".tr,
                  destructive: true,
                );
                if (ok) await FinanceUi.run(() => FinanceInvestmentService.cancelRedemption(o['id'].toString()), success: "Redemption cancelled");
              },
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- simulator

/// Compound growth of an amount plus monthly additions: an illustration.
class ReturnSimulatorScreen extends StatefulWidget {
  final InvestmentConfig config;
  final String? currency;
  final double? annualPercent;

  const ReturnSimulatorScreen({super.key, required this.config, this.currency, this.annualPercent});

  @override
  State<ReturnSimulatorScreen> createState() => _ReturnSimulatorScreenState();
}

class _ReturnSimulatorScreenState extends State<ReturnSimulatorScreen> {
  final _initial = TextEditingController();
  final _monthly = TextEditingController();
  late String _currency = widget.currency != null && widget.config.currencies.contains(widget.currency) ? widget.currency! : widget.config.currencies.first;
  late double _rate = (widget.annualPercent ?? 5).clamp(-10, 25).roundToDouble();
  late int _years = math.min(10, widget.config.simulatorMaxYears);

  @override
  void dispose() {
    _initial.dispose();
    _monthly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int initial = FinanceAmount.parse(_initial.text, _currency) ?? 0;
    final int monthly = FinanceAmount.parse(_monthly.text, _currency) ?? 0;
    final years = initial + monthly == 0 ? const <SimulationYear>[] : ReturnSimulator.project(initial: initial, monthly: monthly, annualPercent: _rate, years: _years);
    final last = years.isEmpty ? null : years.last;
    return FinScaffold(
      title: "Return simulator".tr,
      body: FinBody(
        children: [
          FinSection(
            top: 0,
            title: "Your plan".tr,
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.sm),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DsTextField(
                      label: "Starting amount".tr,
                      controller: _initial,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (widget.config.currencies.length > 1) ...[
                    const DsGap(DsSpace.sm),
                    SizedBox(
                      width: 110,
                      child: DsDropdown<String>(
                        label: "Currency".tr,
                        value: _currency,
                        items: [for (final cur in widget.config.currencies) DropdownMenuItem(value: cur, child: Text(cur))],
                        onChanged: (v) => setState(() => _currency = v ?? _currency),
                      ),
                    ),
                  ],
                ],
              ),
              DsTextField(
                label: "Added every month".tr,
                controller: _monthly,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              _SliderLabel(label: "Yearly return".tr, value: InvestmentLabels.percent(_rate, signed: true)),
              Slider(value: _rate, min: -10, max: 25, divisions: 70, label: InvestmentLabels.percent(_rate), onChanged: (v) => setState(() => _rate = v)),
              _SliderLabel(label: "Duration".tr, value: '$_years ${"years".tr}'),
              Slider(
                value: _years.toDouble(),
                min: 1,
                max: widget.config.simulatorMaxYears.toDouble(),
                divisions: math.max(1, widget.config.simulatorMaxYears - 1),
                label: '$_years',
                onChanged: (v) => setState(() => _years = v.round()),
              ),
            ],
          ),
          if (last == null)
            FinState.empty(Icons.calculate_outlined, "Enter an amount to see a projection.".tr)
          else ...[
            _Overline("Projection".tr),
            FinMetrics(items: [
              FinMetric("You put in".tr, FinanceMoney.format(last.contributed, _currency)),
              FinMetric("Estimated value".tr, FinanceMoney.format(last.value, _currency), sub: '${"after".tr} $_years ${"years".tr}'),
              FinMetric("Estimated gains".tr, FinanceMoney.signed(last.gains, _currency), color: _gainColor(context, last.gains)),
              FinMetric("Yearly return".tr, InvestmentLabels.percent(_rate, signed: true)),
            ]),
            const DsGap(DsSpace.md),
            FinSurface(padding: const EdgeInsets.all(DsSpace.lg), child: _ProjectionChart(years: years, currency: _currency)),
          ],
          FinNotice(
            "This is an illustration with a constant yearly return, before fees and taxes. Real returns vary from year to year, can be negative, and are not guaranteed.".tr,
          ),
        ],
      ),
    );
  }
}

class _SliderLabel extends StatelessWidget {
  final String label;
  final String value;

  const _SliderLabel({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.xs),
      child: Row(children: [
        Expanded(child: Text(label, style: DsTypography.label.copyWith(color: c.textPrimary))),
        Text(value, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary).tabular),
      ]),
    );
  }
}

/// The projection per year: the money put in, and the estimated gain (or
/// loss) on top of it.
class _ProjectionChart extends StatelessWidget {
  final List<SimulationYear> years;
  final String currency;

  const _ProjectionChart({required this.years, required this.currency});

  @override
  Widget build(BuildContext context) {
    const double height = 120;
    final c = DsColors.of(context);
    final brand = FinColors.brand(context);
    final last = years.last;
    final int maxValue = math.max(1, years.map((y) => math.max(y.value, y.contributed)).reduce(math.max));
    final Color change = (last.gains >= 0 ? c.success : c.danger).withValues(alpha: 0.5);
    Widget key(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const DsGap(DsSpace.xs),
          _caption(context, label),
        ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: '${"Estimated value".tr} ${FinanceMoney.format(last.value, currency)} ${"after".tr} ${years.length} ${"years".tr}',
          child: ExcludeSemantics(
            child: SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final y in years)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              height: height * math.max(y.value, y.contributed) / maxValue,
                              decoration: BoxDecoration(color: change, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
                            ),
                            Container(height: height * math.min(y.value, y.contributed) / maxValue, color: brand),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const DsGap(DsSpace.xs),
        Row(children: [
          Expanded(child: _caption(context, '1 ${"year".tr}')),
          _caption(context, '${years.length} ${"years".tr}'),
        ]),
        const DsGap(DsSpace.md),
        Wrap(spacing: DsSpace.lg, runSpacing: DsSpace.xs, children: [
          key(brand, (last.gains >= 0 ? "Money put in" : "Estimated value").tr),
          key(change, "Estimated gains".tr),
        ]),
      ],
    );
  }
}

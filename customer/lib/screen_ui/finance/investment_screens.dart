import 'dart:math' as math;

import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/finance_widgets.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_investment_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_investment_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

String _date(DateTime? d) => d == null ? '-' : ltr(DateFormat('dd MMM yyyy').format(d));

DsTone _tone(String? s) => switch (s) {
      'completed' || 'settled' || 'succeeded' => DsTone.success,
      'payment_failed' || 'rejected' || 'failed' => DsTone.danger,
      'pending_payment' || 'submitted' => DsTone.warning,
      'paid' || 'processing' || 'settling' => DsTone.info,
      _ => DsTone.neutral,
    };

DsTone _riskTone(int level) => switch (RiskScale.band(level)) {
      'low' => DsTone.success,
      'medium' => DsTone.warning,
      _ => DsTone.danger,
    };

DsTone _gainTone(num v) => v > 0 ? DsTone.success : (v < 0 ? DsTone.danger : DsTone.neutral);

String _signed(int minor, String currency) => FinanceMoney.signed(minor, currency);

Widget _row(BuildContext context, String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary))),
          const DsGap(DsSpace.sm),
          Flexible(child: Align(alignment: AlignmentDirectional.centerEnd, child: Text(value, textAlign: TextAlign.end, style: DsTypography.bodyStrong.copyWith(color: color).tabular))),
        ],
      ),
    );

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
        return DsScaffold(
          title: "Investments".tr,
          maxContentWidth: DsLayout.contentMax,
          actions: [
            if (cfg != null)
              DsIconButton(
                icon: Icons.calculate_outlined,
                semanticLabel: "Return simulator".tr,
                onPressed: () => Get.to(() => ReturnSimulatorScreen(config: cfg)),
              ),
          ],
          body: cfgSnap.connectionState == ConnectionState.waiting
              ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonList(itemCount: 3))
              : cfg == null
                  ? DsEmptyState(icon: Icons.trending_up_rounded, title: "Investments are not available yet.".tr)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                      children: [
                        DsSegmentedTabs(
                          segments: [DsSegment("Portfolio".tr), DsSegment("Funds".tr), DsSegment("Orders".tr)],
                          index: _tab,
                          onChanged: (i) => setState(() => _tab = i),
                        ),
                        const DsGap(DsSpace.lg),
                        switch (_tab) {
                          0 => _Portfolio(config: cfg, onBrowse: () => setState(() => _tab = 1)),
                          1 => _Catalog(config: cfg),
                          _ => const _Orders(),
                        },
                      ],
                    ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- portfolio

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
            final int value = FinanceSummary.intOf(p['currentValuation']);
            final int realized = FinanceSummary.intOf(p['realizedGains']);
            final int unrealized = FinanceSummary.intOf(p['unrealizedGains']);
            final shares = Allocation.shares(p['allocation'] is Map ? Map<String, dynamic>.from(p['allocation'] as Map) : null);
            return Padding(
              padding: const EdgeInsets.only(bottom: DsSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DsCard.tinted(
                    tone: DsTone.brand,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _caption(context, "Portfolio value".tr),
                        Text(FinanceMoney.format(value, cur), style: DsTypography.title.tabular),
                        const DsGap(DsSpace.sm),
                        _row(context, "Invested capital".tr, FinanceMoney.format(FinanceSummary.intOf(p['investedCapital']), cur)),
                        _row(context, "Unrealized gains".tr, _signed(unrealized, cur), color: DsColors.of(context).tone(_gainTone(unrealized)).main),
                        _row(context, "Realized gains".tr, _signed(realized, cur), color: DsColors.of(context).tone(_gainTone(realized)).main),
                      ],
                    ),
                  ),
                  if (shares.isNotEmpty) ...[
                    const DsGap(DsSpace.md),
                    DsFormSection(title: "Asset allocation".tr, icon: Icons.pie_chart_outline_rounded, children: [_AllocationBar(shares: shares, currency: cur)]),
                  ],
                ],
              ),
            );
          },
        ),
        StreamBuilder<List<Holding>>(
          stream: FinanceInvestmentService.holdings(),
          builder: (context, snap) {
            if (snap.hasError) return DsErrorState(message: "Could not load your investments.".tr, compact: true);
            if (!snap.hasData) return const DsSkeletonList(itemCount: 2);
            if (snap.data!.isEmpty) {
              return DsEmptyState(
                icon: Icons.trending_up_rounded,
                title: "You have no investment yet.".tr,
                message: "Browse the funds, compare their risk and fees, and invest from the amount that suits you.".tr,
                actionLabel: "Browse the funds".tr,
                onAction: onBrowse,
                compact: true,
              );
            }
            return DsFormSection(
              title: "My funds".tr,
              icon: Icons.account_balance_outlined,
              children: [
                for (final h in snap.data!)
                  DsListTile(
                    padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                    leadingIcon: Icons.trending_up_rounded,
                    leadingTone: _gainTone(h.unrealizedGains),
                    title: h.fundName,
                    subtitle: '${InvestmentLabels.units(h.units)} ${"units".tr} · ${InvestmentLabels.assetClass(h.assetClass).tr}',
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(FinanceMoney.format(h.currentValue, h.currency), style: DsTypography.bodyStrong.tabular),
                        Text(InvestmentLabels.percent(h.unrealizedPercent, signed: true),
                            style: DsTypography.caption.copyWith(color: DsColors.of(context).tone(_gainTone(h.unrealizedGains)).main)),
                      ],
                    ),
                    onTap: () => Get.to(() => HoldingScreen(fundId: h.fundId, config: config)),
                  ),
              ],
            );
          },
        ),
        const DsGap(DsSpace.lg),
        const _Reports(),
        const DsGap(DsSpace.lg),
        DsTileGroup(
          children: [
            DsListTile(
              leadingIcon: Icons.calculate_outlined,
              leadingTone: DsTone.brand,
              title: "Return simulator".tr,
              subtitle: "See how an amount could grow over time.".tr,
              showChevron: true,
              onTap: () => Get.to(() => ReturnSimulatorScreen(config: config)),
            ),
          ],
        ),
      ],
    );
  }
}

/// The allocation as one stacked bar and a legend (server values).
class _AllocationBar extends StatelessWidget {
  final List<AllocationShare> shares;
  final String currency;

  const _AllocationBar({required this.shares, required this.currency});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final palette = [c.brand, c.info, c.success, c.warning, c.danger, c.textMuted];
    Color color(int i) => palette[i % palette.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(DsRadius.sm),
          child: SizedBox(
            height: 14,
            child: Row(children: [
              for (final (i, s) in shares.indexed)
                if (s.percent > 0) Expanded(flex: s.percent, child: Container(color: color(i))),
            ]),
          ),
        ),
        const DsGap(DsSpace.sm),
        for (final (i, s) in shares.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color(i), shape: BoxShape.circle)),
              const DsGap(DsSpace.sm),
              Expanded(child: Text(InvestmentLabels.assetClass(s.assetClass).tr, style: DsTypography.body)),
              Text('${FinanceMoney.format(s.value, currency)} · ${s.percent} %', style: DsTypography.bodyStrong.tabular),
            ]),
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
        return DsFormSection(
          title: "Statements and reports".tr,
          icon: Icons.picture_as_pdf_outlined,
          children: [
            for (final r in list)
              DsListTile(
                padding: const EdgeInsets.symmetric(vertical: 2),
                leadingIcon: Icons.picture_as_pdf_outlined,
                title: r['title']?.toString() ?? "Statement".tr,
                subtitle: FinanceUi.day(r['createdAt']),
                trailing: const Icon(Icons.download_rounded),
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
        if (snap.hasError) return DsErrorState(message: "Could not load the funds.".tr, compact: true);
        if (!snap.hasData) return const DsSkeletonList(itemCount: 3);
        final all = snap.data!;
        final classes = {...widget.config.assetClasses.where((c) => all.any((f) => f.assetClass == c)), ...all.map((f) => f.assetClass)}.toList();
        final funds = all.where((f) => (_assetClass == null || f.assetClass == _assetClass) && (_risk == null || RiskScale.band(f.riskLevel) == _risk)).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const DsGap(DsSpace.md),
            if (funds.isEmpty)
              DsEmptyState(icon: Icons.search_off_rounded, title: (all.isEmpty ? "No fund is open yet." : "No fund matches these filters.").tr, compact: true)
            else
              for (final f in funds) _FundCard(fund: f, config: widget.config),
          ],
        );
      },
    );
  }
}

class _FundCard extends StatelessWidget {
  final Fund fund;
  final InvestmentConfig config;

  const _FundCard({required this.fund, required this.config});

  @override
  Widget build(BuildContext context) {
    final f = fund;
    final double? oneYear = f.performance['oneYear'];
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: DsCard.outlined(
        onTap: () => Get.to(() => FundScreen(fundId: f.id, config: config)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text(f.name, style: DsTypography.titleSm)),
              if (f.status != 'open') DsBadge(label: _fundStatus(f.status).tr, small: true),
            ]),
            if (f.manager.isNotEmpty) _caption(context, f.manager),
            const DsGap(DsSpace.sm),
            Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
              DsBadge(label: InvestmentLabels.assetClass(f.assetClass).tr, tone: DsTone.info, small: true),
              DsBadge(label: '${RiskScale.label(f.riskLevel).tr} · ${f.riskLevel}/7', tone: _riskTone(f.riskLevel), small: true),
            ]),
            const DsGap(DsSpace.sm),
            _row(context, "From".tr, FinanceMoney.format(f.minInvestment, f.currency)),
            if (oneYear != null)
              _row(context, "1-year return".tr, InvestmentLabels.percent(oneYear, signed: true), color: DsColors.of(context).tone(_gainTone(oneYear)).main),
          ],
        ),
      ),
    );
  }
}

String _fundStatus(String s) => const {'open': 'Open', 'closed': 'Closed to new investments', 'suspended': 'Suspended'}[s] ?? s;

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
            return DsScaffold(
              title: f?.name ?? "Fund".tr,
              maxContentWidth: DsLayout.contentMax,
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
                  ? DsErrorState(message: "Could not load this fund.".tr)
                  : f == null
                      ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 5))
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
    final f = fund;
    final h = holding;
    String pct(double v) => InvestmentLabels.percent(v);
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
      children: [
        DsCard.tinted(
          tone: DsTone.brand,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(f.name, style: DsTypography.title)),
                if (f.status != 'open') DsBadge(label: _fundStatus(f.status).tr, tone: DsTone.warning),
              ]),
              if (f.manager.isNotEmpty) _caption(context, '${"Managed by".tr} ${f.manager}'),
              const DsGap(DsSpace.sm),
              Align(alignment: AlignmentDirectional.centerStart, child: DsBadge(label: InvestmentLabels.assetClass(f.assetClass).tr, tone: DsTone.info, small: true)),
              const DsGap(DsSpace.md),
              _RiskScaleView(level: f.riskLevel),
            ],
          ),
        ),
        if (h != null && h.hasUnits) ...[
          const DsGap(DsSpace.md),
          DsCard.outlined(
            onTap: () => Get.to(() => HoldingScreen(fundId: f.id, config: config)),
            child: Row(children: [
              DsIconWell(icon: Icons.account_balance_wallet_outlined, tone: _gainTone(h.unrealizedGains)),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Your position".tr, style: DsTypography.titleSm),
                  _caption(context, '${InvestmentLabels.units(h.units)} ${"units".tr} · ${InvestmentLabels.percent(h.unrealizedPercent, signed: true)}'),
                ]),
              ),
              Text(FinanceMoney.format(h.currentValue, h.currency), style: DsTypography.bodyStrong.tabular),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
        ],
        if (f.objective.isNotEmpty || f.description.isNotEmpty) ...[
          const DsGap(DsSpace.md),
          DsFormSection(
            title: "Objective".tr,
            icon: Icons.flag_outlined,
            children: [
              if (f.objective.isNotEmpty) Text(f.objective, style: DsTypography.bodyStrong),
              if (f.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: DsSpace.xs), child: Text(f.description, style: DsTypography.body)),
            ],
          ),
        ],
        const DsGap(DsSpace.md),
        DsFormSection(
          title: "Key facts".tr,
          icon: Icons.fact_check_outlined,
          children: [
            _row(context, "Unit price".tr, f.navPerUnit == null ? '-' : FinanceMoney.format(f.navPerUnit!, f.currency)),
            if (f.navDate != null) _row(context, "Price date".tr, _date(f.navDate)),
            _row(context, "Minimum investment".tr, FinanceMoney.format(f.minInvestment, f.currency)),
            if (f.minAdditional != f.minInvestment) _row(context, "Minimum further investment".tr, FinanceMoney.format(f.minAdditional, f.currency)),
            _row(context, "Subscription fee".tr, pct(f.subscriptionFeePercent)),
            _row(context, "Management fee".tr, '${pct(f.managementFeePercent)} ${"a year".tr}'),
            _row(context, "Redemption fee".tr, pct(f.redemptionFeePercent)),
            if (f.performanceFeePercent > 0) _row(context, "Performance fee".tr, pct(f.performanceFeePercent)),
            _row(context, "Lock-up period".tr, f.lockUpDays == 0 ? "None".tr : '${f.lockUpDays} ${"days".tr}'),
            _row(context, "Redemptions".tr, !f.redemptionAllowed ? "Not possible".tr : (f.partialRedemption ? "Partial or full" : "Full only").tr),
            _row(context, "Paid out within".tr, '${f.settlementDays} ${"business days".tr}'),
            if (f.eligibility.isNotEmpty) Padding(padding: const EdgeInsets.only(top: DsSpace.sm), child: DsInlineAlert(tone: DsTone.info, title: "Who can invest".tr, message: f.eligibility)),
          ],
        ),
        if (f.performance.isNotEmpty) ...[
          const DsGap(DsSpace.md),
          DsFormSection(
            title: "Past performance".tr,
            icon: Icons.show_chart_rounded,
            children: [
              for (final p in InvestmentLabels.periods)
                if (f.performance[p] != null)
                  _row(context, InvestmentLabels.period(p).tr, InvestmentLabels.percent(f.performance[p], signed: true),
                      color: DsColors.of(context).tone(_gainTone(f.performance[p]!)).main),
              _caption(context, "Past performance does not predict future returns.".tr),
            ],
          ),
        ],
        StreamBuilder<List<NavPoint>>(
          stream: FinanceInvestmentService.valuations(f.id),
          builder: (context, snap) {
            final points = snap.data ?? const <NavPoint>[];
            if (points.length < 2) return const SizedBox.shrink();
            final double? change = navChangePercent(points);
            return Padding(
              padding: const EdgeInsets.only(top: DsSpace.md),
              child: DsFormSection(
                title: "Unit price history".tr,
                icon: Icons.timeline_rounded,
                trailing: change == null ? null : DsBadge(label: InvestmentLabels.percent(change, signed: true), tone: _gainTone(change), small: true),
                children: [_NavChart(points: points, currency: f.currency)],
              ),
            );
          },
        ),
        if (f.documents.isNotEmpty) ...[
          const DsGap(DsSpace.md),
          DsFormSection(
            title: "Documents".tr,
            icon: Icons.folder_open_outlined,
            children: [
              for (final d in f.documents)
                DsListTile(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  leadingIcon: Icons.description_outlined,
                  title: d.name,
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => _open(storagePath: d.storagePath, url: d.url),
                ),
            ],
          ),
        ],
        if (f.terms.isNotEmpty) ...[
          const DsGap(DsSpace.md),
          DsFormSection(
            title: "Terms".tr,
            subtitle: '${"Version".tr} ${f.termsVersion}',
            icon: Icons.gavel_rounded,
            children: [Text(f.terms, style: DsTypography.body)],
          ),
        ],
        const DsGap(DsSpace.md),
        DsButton.secondary(
          label: "Simulate a return".tr,
          icon: Icons.calculate_outlined,
          expand: true,
          onPressed: () => Get.to(() => ReturnSimulatorScreen(config: config, currency: f.currency, annualPercent: f.performance['oneYear'])),
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
              Expanded(child: Text("Risk level".tr, style: DsTypography.label)),
              Text(RiskScale.label(level).tr, style: DsTypography.bodyStrong.copyWith(color: active)),
            ]),
            const DsGap(DsSpace.xs),
            Row(children: [
              for (int i = 1; i <= 7; i++)
                Expanded(
                  child: Container(
                    height: 28,
                    margin: const EdgeInsetsDirectional.only(end: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: i == level ? active : c.surfaceAlt, borderRadius: BorderRadius.circular(DsRadius.sm)),
                    child: Text('$i', style: DsTypography.label.copyWith(color: i == level ? Colors.white : c.textSecondary)),
                  ),
                ),
            ]),
            const DsGap(DsSpace.xs),
            Row(children: [
              Expanded(child: _caption(context, "Lower risk, lower potential return".tr)),
              Expanded(child: Text("Higher risk, higher potential return".tr, textAlign: TextAlign.end, style: DsTypography.caption.copyWith(color: c.textSecondary))),
            ]),
          ],
        ),
      ),
    );
  }
}

/// The unit price over time, as a line.
class _NavChart extends StatelessWidget {
  final List<NavPoint> points;
  final String currency;

  const _NavChart({required this.points, required this.currency});

  @override
  Widget build(BuildContext context) {
    final double lo = points.map((p) => p.nav).reduce(math.min);
    final double hi = points.map((p) => p.nav).reduce(math.max);
    return Semantics(
      label: '${"Unit price".tr}: ${FinanceMoney.format(points.first.nav, currency)} ${_date(points.first.date)}, ${FinanceMoney.format(points.last.nav, currency)} ${_date(points.last.date)}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: _caption(context, '${"High".tr} ${FinanceMoney.format(hi, currency)}')),
              _caption(context, '${"Low".tr} ${FinanceMoney.format(lo, currency)}'),
            ]),
            const DsGap(DsSpace.xs),
            FinanceLineChart(values: points.map((p) => p.nav).toList()),
            const DsGap(DsSpace.xs),
            Row(children: [
              Expanded(child: _caption(context, _date(points.first.date))),
              _caption(context, _date(points.last.date)),
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
    final f = widget.fund;
    final int min = f.minimumFor(holder: widget.holder);
    final int? amount = FinanceAmount.parse(_amount.text, f.currency);
    final bool tooLow = amount != null && amount < min;
    final estimate = amount == null || tooLow ? null : InvestmentCalculator.subscription(f, amount);
    final bool ready = estimate != null && _termsAccepted && _riskAccepted && _signature.text.trim().length >= 3;
    return DsScaffold(
      title: "Invest".tr,
      maxContentWidth: DsLayout.contentMax,
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        children: [
          DsFormSection(
            title: f.name,
            subtitle: '${RiskScale.label(f.riskLevel).tr} · ${f.riskLevel}/7',
            icon: Icons.trending_up_rounded,
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
            const DsGap(DsSpace.lg),
            DsFormSection(
              title: "Estimate".tr,
              icon: Icons.calculate_outlined,
              children: [
                _row(context, "You pay".tr, FinanceMoney.format(estimate.gross, f.currency)),
                _row(context, "Subscription fee".tr, '${FinanceMoney.format(estimate.fee, f.currency)} (${InvestmentLabels.percent(f.subscriptionFeePercent)})'),
                _row(context, "Invested in the fund".tr, FinanceMoney.format(estimate.net, f.currency)),
                if (estimate.units != null) _row(context, "Estimated units".tr, InvestmentLabels.units(estimate.units!)),
                if (f.navPerUnit != null) _row(context, "Last unit price".tr, '${FinanceMoney.format(f.navPerUnit!, f.currency)} · ${_date(f.navDate)}'),
                if (f.lockUpDays > 0) _row(context, "Lock-up period".tr, '${f.lockUpDays} ${"days".tr}'),
                _caption(context, "Units are bought at the unit price of the processing date, after your payment is confirmed. The final number of units can differ from this estimate.".tr),
              ],
            ),
          ],
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "Risks".tr,
            icon: Icons.warning_amber_rounded,
            children: [
              DsInlineAlert(tone: DsTone.warning, message: widget.config.riskDisclosure),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _riskAccepted,
                onChanged: (v) => setState(() => _riskAccepted = v ?? false),
                title: Text("I understand that the value of my investment can go down as well as up, and that I may lose part of the money invested.".tr),
              ),
            ],
          ),
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "Fund terms".tr,
            subtitle: '${"Version".tr} ${f.termsVersion}',
            icon: Icons.gavel_rounded,
            children: [
              if (f.terms.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: Scrollbar(child: SingleChildScrollView(child: Text(f.terms, style: DsTypography.body))),
                ),
              for (final d in f.documents)
                DsListTile(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  leadingIcon: Icons.description_outlined,
                  title: d.name,
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => _open(storagePath: d.storagePath, url: d.url),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _termsAccepted,
                onChanged: (v) => setState(() => _termsAccepted = v ?? false),
                title: Text("I have read the fund terms and documents, and I accept them.".tr),
              ),
            ],
          ),
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "Electronic signature".tr,
            subtitle: "Type your full name to sign the subscription. It is recorded with the date and the terms version.".tr,
            icon: Icons.draw_outlined,
            children: [
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
          final f = fs.data;
          final h = hs.data;
          return DsScaffold(
            title: h?.fundName ?? f?.name ?? "My investment".tr,
            maxContentWidth: DsLayout.contentMax,
            actions: [
              if (f != null) DsIconButton(icon: Icons.info_outline_rounded, semanticLabel: "Fund details".tr, onPressed: () => Get.to(() => FundScreen(fundId: fundId, config: config))),
            ],
            body: hs.hasError
                ? DsErrorState(message: "Could not load your investment.".tr)
                : hs.connectionState == ConnectionState.waiting
                    ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 4))
                    : h == null || !h.hasUnits
                        ? DsEmptyState(icon: Icons.trending_up_rounded, title: "You hold no units of this fund.".tr)
                        : _HoldingBody(holding: h, fund: f, config: config),
          );
        },
      ),
    );
  }
}

class _HoldingBody extends StatelessWidget {
  final Holding holding;
  final Fund? fund;
  final InvestmentConfig config;

  const _HoldingBody({required this.holding, required this.fund, required this.config});

  Future<void> _redeem(BuildContext context) async {
    final h = holding;
    final f = fund!;
    bool full = !f.partialRedemption;
    int? amount;
    if (f.partialRedemption) {
      final choice = await DsBottomSheet.show<String>(
        title: "Redeem".tr,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsListTile(
              padding: EdgeInsets.zero,
              leadingIcon: Icons.pie_chart_outline_rounded,
              title: "Part of my investment".tr,
              subtitle: "Choose an amount".tr,
              showChevron: true,
              onTap: () => Get.back(result: 'partial'),
            ),
            DsListTile(
              padding: EdgeInsets.zero,
              leadingIcon: Icons.circle_outlined,
              title: "All that can be redeemed".tr,
              subtitle: '${"About".tr} ${FinanceMoney.format(h.redeemableValue, h.currency)}',
              showChevron: true,
              onTap: () => Get.back(result: 'full'),
            ),
          ],
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
    final ok = await DsBottomSheet.show<bool>(
      title: "Redemption estimate".tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row(context, (full ? "Whole redeemable position" : "Amount redeemed").tr, FinanceMoney.format(gross, h.currency)),
          if (estimate.units != null) _row(context, "Estimated units".tr, InvestmentLabels.units(full ? h.redeemableUnits : estimate.units!)),
          _row(context, "Redemption fee".tr, '${FinanceMoney.format(estimate.fee, h.currency)} (${InvestmentLabels.percent(f.redemptionFeePercent)})'),
          _row(context, "You receive about".tr, FinanceMoney.format(estimate.net, h.currency)),
          _row(context, "Paid out within".tr, '${f.settlementDays} ${"business days".tr}'),
          const DsGap(DsSpace.sm),
          _caption(context, "The final amount uses the unit price of the processing date.".tr),
          const DsGap(DsSpace.md),
          DsButton.primary(label: "Continue".tr, expand: true, onPressed: () => Get.back(result: true)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final h = holding;
    final f = fund;
    final bool canRedeem = f != null && f.redemptionAllowed && f.status != 'suspended' && h.redeemableValue > 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
      children: [
        DsCard.tinted(
          tone: DsTone.brand,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _caption(context, "Current value".tr),
              Text(FinanceMoney.format(h.currentValue, h.currency), style: DsTypography.title.tabular),
              if (h.valuedAt != null) _caption(context, '${"Valued on".tr} ${_date(h.valuedAt)}'),
              const DsGap(DsSpace.sm),
              _row(context, "Units".tr, InvestmentLabels.units(h.units)),
              _row(context, "Invested capital".tr, FinanceMoney.format(h.investedAmount, h.currency)),
              _row(context, "Unrealized gains".tr, '${_signed(h.unrealizedGains, h.currency)} (${InvestmentLabels.percent(h.unrealizedPercent, signed: true)})',
                  color: DsColors.of(context).tone(_gainTone(h.unrealizedGains)).main),
              _row(context, "Realized gains".tr, _signed(h.realizedGains, h.currency), color: DsColors.of(context).tone(_gainTone(h.realizedGains)).main),
              if (f?.navPerUnit != null) _row(context, "Unit price".tr, '${FinanceMoney.format(f!.navPerUnit!, f.currency)} · ${_date(f.navDate)}'),
            ],
          ),
        ),
        const DsGap(DsSpace.md),
        if (h.partlyLocked)
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.md),
            child: DsInlineAlert(
              tone: DsTone.info,
              title: "Lock-up period".tr,
              message:
                  '${"Redeemable now".tr}: ${InvestmentLabels.units(h.redeemableUnits)} ${"units".tr} (${FinanceMoney.format(h.redeemableValue, h.currency)}).${h.lockedUntil == null ? '' : ' ${"The rest from".tr} ${_date(h.lockedUntil)}.'}',
            ),
          ),
        if (canRedeem)
          FinanceKycGate(
            builder: (context, verified) => DsButton.secondary(
              label: "Redeem".tr,
              icon: Icons.south_west_rounded,
              expand: true,
              onPressed: verified ? () => _redeem(context) : null,
            ),
          )
        else if (f != null && !f.redemptionAllowed)
          DsInlineAlert(tone: DsTone.neutral, message: "This fund does not accept redemptions at the moment.".tr),
        const DsGap(DsSpace.lg),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: FinanceInvestmentService.transactions(h.fundId),
          builder: (context, snap) {
            final list = snap.data ?? const [];
            if (list.isEmpty) return const SizedBox.shrink();
            return DsFormSection(
              title: "History".tr,
              icon: Icons.receipt_long_outlined,
              children: [
                for (final t in list)
                  DsListTile(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    leadingIcon: t['type'] == 'redemption' ? Icons.south_west_rounded : Icons.north_east_rounded,
                    leadingTone: t['type'] == 'redemption' || t['type'] == 'distribution' ? DsTone.success : DsTone.brand,
                    title: '${InvestmentLabels.transaction(t['type']?.toString()).tr} · ${FinanceMoney.format(FinanceSummary.intOf(t['amount']), h.currency)}',
                    subtitle: [
                      FinanceUi.day(t['createdAt']),
                      if (t['units'] is num) '${InvestmentLabels.units((t['units'] as num).toDouble())} ${"units".tr}',
                      if (t['navPerUnit'] is num) '@ ${FinanceMoney.format(t['navPerUnit'] as num, h.currency)}',
                    ].join(' · '),
                  ),
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
          if (ss.hasError || rs.hasError) return DsErrorState(message: "Could not load your orders.".tr, compact: true);
          if (!ss.hasData || !rs.hasData) return const DsSkeletonList(itemCount: 3);
          final orders = [
            for (final o in ss.data!) ('investment_subscriptions', o),
            for (final o in rs.data!) ('investment_redemptions', o),
          ]..sort((a, b) => (FinanceGroupService.toDate(b.$2['createdAt']) ?? DateTime(0)).compareTo(FinanceGroupService.toDate(a.$2['createdAt']) ?? DateTime(0)));
          if (orders.isEmpty) return DsEmptyState(icon: Icons.receipt_long_outlined, title: "You have no investment order yet.".tr, compact: true);
          return Column(
            children: [
              for (final (collection, o) in orders)
                Padding(
                  padding: const EdgeInsets.only(bottom: DsSpace.sm),
                  child: DsCard.outlined(
                    onTap: () => Get.to(() => InvestmentOrderScreen(collection: collection, orderId: o['id'].toString())),
                    child: Row(children: [
                      DsIconWell(
                        icon: collection == 'investment_redemptions' ? Icons.south_west_rounded : Icons.north_east_rounded,
                        tone: _tone(o['status']?.toString()),
                      ),
                      const DsGap(DsSpace.md),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            '${(collection == 'investment_redemptions' ? "Redemption" : "Investment").tr} · ${o['full'] == true && o['amount'] == null ? "All".tr : FinanceMoney.format(FinanceSummary.intOf(o['amount']), o['currency']?.toString() ?? '')}',
                            style: DsTypography.titleSm.tabular,
                          ),
                          _caption(context, '${o['fundName'] ?? ''} · ${FinanceUi.day(o['createdAt'])}'),
                        ]),
                      ),
                      DsBadge(label: InvestmentOrders.label(o['status']?.toString()).tr, tone: _tone(o['status']?.toString()), small: true),
                    ]),
                  ),
                ),
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
        return DsScaffold(
          title: (redemption ? "Redemption" : "Investment").tr,
          maxContentWidth: DsLayout.contentMax,
          body: snap.hasError
              ? DsErrorState(message: "Could not load this order.".tr)
              : o == null
                  ? const Padding(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 4))
                  : _orderBody(context, o, redemption),
        );
      },
    );
  }

  Widget _orderBody(BuildContext context, Map<String, dynamic> o, bool redemption) {
    final String status = o['status']?.toString() ?? '';
    final String cur = o['currency']?.toString() ?? '';
    final steps = redemption ? InvestmentOrders.redemptionSteps : InvestmentOrders.subscriptionSteps;
    final int at = steps.indexOf(status);
    String m(dynamic v) => FinanceMoney.format(FinanceSummary.intOf(v), cur);
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
      children: [
        DsCard.tinted(
          tone: _tone(status),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(o['amount'] == null ? "All that can be redeemed".tr : m(o['amount']), style: DsTypography.title.tabular)),
                DsBadge(label: InvestmentOrders.label(status).tr, tone: _tone(status)),
              ]),
              if ((o['fundName'] ?? '').toString().isNotEmpty) _caption(context, o['fundName'].toString()),
              if ((o['reason'] ?? '').toString().isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: DsSpace.sm), child: DsInlineAlert(tone: _tone(status), title: "Reason".tr, message: o['reason'].toString())),
            ],
          ),
        ),
        const DsGap(DsSpace.md),
        if (!InvestmentOrders.ended(status) && at >= 0)
          DsTimeline(
            steps: [
              for (final (i, s) in steps.indexed)
                DsTimelineStep(
                  title: InvestmentOrders.label(s).tr,
                  state: i < at || (i == at && i == steps.length - 1) ? DsStepState.done : (i == at ? DsStepState.current : DsStepState.upcoming),
                ),
            ],
          ),
        const DsGap(DsSpace.md),
        DsFormSection(
          title: "Details".tr,
          icon: Icons.receipt_long_outlined,
          children: [
            if (o['fee'] != null) _row(context, "Fee".tr, m(o['fee'])),
            if (o['netAmount'] != null) _row(context, (redemption ? "Paid out" : "Invested in the fund").tr, m(o['netAmount'])),
            if (o['units'] is num) _row(context, "Units".tr, InvestmentLabels.units((o['units'] as num).toDouble())),
            if (o['navPerUnit'] is num) _row(context, "Unit price".tr, FinanceMoney.format(o['navPerUnit'] as num, cur)),
            if (o['termsVersion'] != null) _row(context, "Terms version".tr, '${o['termsVersion']}'),
            _row(context, "Requested on".tr, FinanceUi.date(o['createdAt'])),
            if (o['tradeDate'] != null) _row(context, "Processed on".tr, FinanceUi.date(o['tradeDate'])),
            if (o['expectedSettlementDate'] != null && o['settledAt'] == null) _row(context, "Expected payment".tr, FinanceUi.day(o['expectedSettlementDate'])),
            if (o['settledAt'] != null) _row(context, "Paid out on".tr, FinanceUi.date(o['settledAt'])),
            if ((o['reference'] ?? '').toString().isNotEmpty) _row(context, "Reference".tr, o['reference'].toString()),
          ],
        ),
        if (redemption && InvestmentOrders.canCancelRedemption(status))
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.lg),
            child: DsButton.ghost(
              label: "Cancel this redemption".tr,
              icon: Icons.close_rounded,
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text("Cancel this redemption?".tr),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: Text("Keep it".tr)),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: Text("Cancel it".tr)),
                    ],
                  ),
                );
                if (ok == true) await FinanceUi.run(() => FinanceInvestmentService.cancelRedemption(o['id'].toString()), success: "Redemption cancelled");
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
    final c = DsColors.of(context);
    final int initial = FinanceAmount.parse(_initial.text, _currency) ?? 0;
    final int monthly = FinanceAmount.parse(_monthly.text, _currency) ?? 0;
    final years = initial + monthly == 0 ? const <SimulationYear>[] : ReturnSimulator.project(initial: initial, monthly: monthly, annualPercent: _rate, years: _years);
    final last = years.isEmpty ? null : years.last;
    final int maxValue = years.isEmpty ? 1 : math.max(1, years.map((y) => math.max(y.value, y.contributed)).reduce(math.max));
    return DsScaffold(
      title: "Return simulator".tr,
      maxContentWidth: DsLayout.contentMax,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        children: [
          DsFormSection(
            title: "Your plan".tr,
            icon: Icons.tune_rounded,
            children: [
              Row(children: [
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
              ]),
              DsTextField(
                label: "Added every month".tr,
                controller: _monthly,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              Text('${"Yearly return".tr}: ${InvestmentLabels.percent(_rate, signed: true)}', style: DsTypography.label),
              Slider(value: _rate, min: -10, max: 25, divisions: 70, label: InvestmentLabels.percent(_rate), onChanged: (v) => setState(() => _rate = v)),
              Text('${"Duration".tr}: $_years ${"years".tr}', style: DsTypography.label),
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
          const DsGap(DsSpace.lg),
          if (last == null)
            DsEmptyState(icon: Icons.calculate_outlined, title: "Enter an amount to see a projection.".tr, compact: true)
          else
            DsFormSection(
              title: "Projection".tr,
              icon: Icons.insights_outlined,
              children: [
                _row(context, "You put in".tr, FinanceMoney.format(last.contributed, _currency)),
                _row(context, "Estimated value".tr, FinanceMoney.format(last.value, _currency)),
                _row(context, "Estimated gains".tr, _signed(last.gains, _currency), color: c.tone(_gainTone(last.gains)).main),
                const DsGap(DsSpace.md),
                Semantics(
                  label: '${"Estimated value".tr} ${FinanceMoney.format(last.value, _currency)} ${"after".tr} $_years ${"years".tr}',
                  child: ExcludeSemantics(
                    child: SizedBox(
                      height: 120,
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
                                    Container(height: 120 * y.value / maxValue, color: c.tone(_gainTone(y.gains)).main.withValues(alpha: 0.5)),
                                    Container(height: 120 * math.min(y.contributed, y.value) / maxValue, color: c.brand),
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
                  _caption(context, '$_years ${"years".tr}'),
                ]),
                const DsGap(DsSpace.sm),
                Row(children: [
                  Container(width: 10, height: 10, color: c.brand),
                  const DsGap(DsSpace.xs),
                  _caption(context, "Money put in".tr),
                  const DsGap(DsSpace.lg),
                  Container(width: 10, height: 10, color: c.tone(_gainTone(last.gains)).main.withValues(alpha: 0.5)),
                  const DsGap(DsSpace.xs),
                  _caption(context, "Growth".tr),
                ]),
              ],
            ),
          const DsGap(DsSpace.md),
          DsInlineAlert(
            tone: DsTone.info,
            message: "This is an illustration with a constant yearly return, before fees and taxes. Real returns vary from year to year, can be negative, and are not guaranteed.".tr,
          ),
        ],
      ),
    );
  }
}

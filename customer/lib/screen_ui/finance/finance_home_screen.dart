import 'package:customer/screen_ui/finance/bill_screens.dart';
import 'package:customer/screen_ui/finance/card_screens.dart';
import 'package:customer/screen_ui/finance/coach_screens.dart';
import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/financing_screens.dart';
import 'package:customer/screen_ui/finance/insurance_screens.dart';
import 'package:customer/screen_ui/finance/intelligence_screens.dart';
import 'package:customer/screen_ui/finance/investment_screens.dart';
import 'package:customer/screen_ui/finance/kyc_screen.dart';
import 'package:customer/screen_ui/finance/lending_screens.dart';
import 'package:customer/screen_ui/finance/savings_screens.dart';
import 'package:customer/screen_ui/finance/tontine_screens.dart';
import 'package:customer/screen_ui/finance/transactions_screen.dart';
import 'package:customer/screen_ui/finance/transfer_screens.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Profile > Spideli Finance: the financial overview. Everything shown is
/// what the server recorded (.claude/FINANCE-APP-CONTRACT.md):
///  - verification: users/{uid} `kycStatus` / `kycLevel`;
///  - balance: financial_accounts (the wallet);
///  - products, obligations and cash flow: finance_summaries/{uid};
///  - activity and statements: ledger_transactions.
/// The app never adds amounts up into a balance or a total of its own.
class FinanceHomeScreen extends StatelessWidget {
  const FinanceHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FinScaffold(
      title: "Spideli Finance".tr,
      actions: [
        DsIconButton(icon: Icons.picture_as_pdf_outlined, semanticLabel: "Download statement".tr, onPressed: () => shareFinanceStatement(context)),
      ],
      body: StreamBuilder<FinanceSummary?>(
        stream: FinanceService.summary(),
        builder: (context, sumSnap) {
          final s = sumSnap.data;
          return FinBody(children: [
            const _VerificationNotice(),
            _BalanceHero(summary: s),
            if (s != null) _Upcoming(summary: s),
            _Products(summary: s, loading: sumSnap.connectionState == ConnectionState.waiting, error: sumSnap.hasError),
            FinSection(
              title: "Recent activity".tr,
              actionLabel: "See all".tr,
              onAction: () => Get.to(() => const TransactionsScreen()),
              padding: EdgeInsets.zero,
              children: const [_RecentActivity()],
            ),
            if (s != null && s.monthly.isNotEmpty) _CashFlow(summary: s),
            const _Services(),
            const _Account(),
          ]);
        },
      ),
    );
  }
}

/// Shown only when something is needed: verification missing or in progress.
class _VerificationNotice extends StatelessWidget {
  const _VerificationNotice();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: FinanceService.myProfile(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final String? status = snap.data?['kycStatus']?.toString();
        final bool verified = (snap.data?['kycLevel']?.toString() ?? '').isNotEmpty;
        if (verified) return const SizedBox.shrink();
        final (String text, String action, DsTone tone) = switch (status) {
          null => ("Verify your identity to use Spideli Finance services.", "Verify my identity", DsTone.warning),
          KycStatus.additionalInfo => ("Your verification needs more information.", "Open verification", DsTone.warning),
          KycStatus.rejected => ("Your verification was not approved. You can submit it again.", "Open verification", DsTone.danger),
          KycStatus.draft => ("Finish your verification and submit it.", "Open verification", DsTone.warning),
          _ => ("Your documents are being reviewed.", "Open verification", DsTone.info),
        };
        return Padding(
          padding: const EdgeInsets.only(bottom: DsSpace.lg),
          child: DsInlineAlert(tone: tone, title: "Identity verification".tr, message: text.tr, actionLabel: action.tr, onAction: () => Get.to(() => const KycScreen())),
        );
      },
    );
  }
}

/// The focal point: the available wallet balance, three server totals and
/// the most used actions.
class _BalanceHero extends StatelessWidget {
  final FinanceSummary? summary;

  const _BalanceHero({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceService.myAccounts(),
      builder: (context, snap) {
        if (snap.hasError) return FinState.error("Could not load your balances.".tr);
        final wallets = activeWallets(snap.data ?? const []);
        final preferred = wallets.where((w) => w['currency'] == s?.currency).firstOrNull ?? wallets.firstOrNull;
        final String cur = preferred?['currency']?.toString() ?? s?.currency ?? 'XAF';
        final others = wallets.where((w) => w != preferred).toList();
        String m(dynamic v) => FinanceMoney.format(FinanceSummary.intOf(v), s?.currency ?? cur);
        final stats = <FinHeroStat>[
          if (s?.investments != null) FinHeroStat("Invested".tr, m(s!.investments!['currentValuation'])),
          if (s?.savings != null) FinHeroStat("Saved so far".tr, m(s!.savings!['savedAmount'])),
          if (s?.loans != null) FinHeroStat("Still to repay".tr, m(s!.loans!['borrowedOutstanding'])),
        ];
        return FinHero(
          label: "Available balance".tr,
          amount: !snap.hasData ? '…' : FinanceMoney.format(preferred == null ? 0 : ((preferred['balance'] as num?) ?? 0), cur),
          caption: !snap.hasData
              ? null
              : preferred == null
                  ? "Your wallet opens with your first deposit.".tr
                  : others.isEmpty
                      ? "Spideli Finance wallet".tr
                      : '${"Also".tr}: ${others.map((w) => FinanceMoney.format((w['balance'] as num?) ?? 0, w['currency']?.toString() ?? '')).join(' · ')}',
          stats: stats,
          footer: FinActions(onHero: true, actions: [
            FinAction(Icons.north_east_rounded, "Send".tr, () => Get.to(() => const TransfersScreen())),
            FinAction(Icons.receipt_outlined, "Pay bills".tr, () => Get.to(() => const BillsScreen())),
            FinAction(Icons.savings_outlined, "Save".tr, () => Get.to(() => const SavingsListScreen())),
            FinAction(Icons.history_rounded, "History".tr, () => Get.to(() => const TransactionsScreen())),
          ]),
        );
      },
    );
  }
}

/// What is due next, soonest first, from the server's summary.
class _Upcoming extends StatelessWidget {
  final FinanceSummary summary;

  const _Upcoming({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    String m(dynamic v) => FinanceMoney.format(FinanceSummary.intOf(v), s.currency);
    final DateTime now = DateTime.now();
    DateTime? d(dynamic v) => FinanceUi.toDate(v);
    final bool overdue = FinanceSummary.intOf(s.loans?['overdueCount']) > 0;
    final items = <(DateTime?, Widget)>[
      if (overdue)
        (
          DateTime(1970),
          FinListTile(
            icon: Icons.warning_amber_rounded,
            iconTone: DsTone.danger,
            title: "Loan repayment overdue".tr,
            subtitle: "Repay now to avoid late payment penalties.".tr,
            status: 'overdue',
            statusLabel: "Overdue".tr,
            chevron: true,
            onTap: () => Get.to(() => const LoansScreen()),
          ),
        ),
      if (!overdue && d(s.loans?['nextRepaymentDate']) != null)
        (
          d(s.loans?['nextRepaymentDate']),
          FinListTile(
            icon: Icons.handshake_outlined,
            iconTone: DsTone.brand,
            title: "Loan repayment".tr,
            subtitle: _when(d(s.loans?['nextRepaymentDate'])!, now),
            amount: m(s.loans?['nextRepaymentAmount']),
            chevron: true,
            onTap: () => Get.to(() => const LoansScreen()),
          ),
        ),
      if (d(s.tontines?['nextContributionDate']) != null)
        (
          d(s.tontines?['nextContributionDate']),
          FinListTile(
            icon: Icons.groups_2_outlined,
            iconTone: DsTone.brand,
            title: "Tontine contribution".tr,
            subtitle: _when(d(s.tontines?['nextContributionDate'])!, now),
            amount: s.tontines?['nextContributionAmount'] == null ? null : m(s.tontines?['nextContributionAmount']),
            chevron: true,
            onTap: () => Get.to(() => const TontineListScreen()),
          ),
        ),
      if (d(s.insurance?['nextRenewalDate']) != null)
        (
          d(s.insurance?['nextRenewalDate']),
          FinListTile(
            icon: Icons.health_and_safety_outlined,
            iconTone: DsTone.brand,
            title: "Insurance renewal".tr,
            subtitle: _when(d(s.insurance?['nextRenewalDate'])!, now),
            chevron: true,
            onTap: () => Get.to(() => const InsuranceScreen()),
          ),
        ),
    ]..sort((a, b) => (a.$1 ?? DateTime(9999)).compareTo(b.$1 ?? DateTime(9999)));
    if (items.isEmpty) return const SizedBox.shrink();
    return FinSection(title: "Coming up".tr, divided: true, children: [for (final i in items.take(4)) i.$2]);
  }

  static String _when(DateTime date, DateTime now) {
    final int days = DateTime(date.year, date.month, date.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    final String day = ltr(DateFormat('dd MMM yyyy').format(date));
    if (days < 0) return '$day · ${"Past due".tr}';
    if (days == 0) return '$day · ${"Today".tr}';
    if (days == 1) return '$day · ${"Tomorrow".tr}';
    return '$day · ${"In".tr} $days ${"days".tr}';
  }
}

/// Every product the user holds, one aligned list (server totals).
class _Products extends StatelessWidget {
  final FinanceSummary? summary;
  final bool loading;
  final bool error;

  const _Products({required this.summary, required this.loading, required this.error});

  @override
  Widget build(BuildContext context) {
    if (error) return FinState.error("Could not load your overview.".tr);
    if (loading) return FinState.loading(rows: 3);
    final s = summary;
    if (s == null) {
      return FinState.empty(Icons.insights_outlined, "Your overview appears here once you use Spideli Finance services.".tr);
    }
    final c = DsColors.of(context);
    String m(dynamic v) => FinanceMoney.format(FinanceSummary.intOf(v), s.currency);
    final rows = <Widget>[
      if (s.savings != null)
        FinListTile(
          icon: Icons.savings_outlined,
          iconTone: DsTone.brand,
          title: "Savings goals".tr,
          subtitle: '${FinanceSummary.intOf(s.savings!['activeGoals'])} ${"active".tr} · ${((s.savingsProgress ?? 0) * 100).round()}% ${"of the target".tr} ${m(s.savings!['targetAmount'])}',
          amount: m(s.savings!['savedAmount']),
          chevron: true,
          onTap: () => Get.to(() => const SavingsListScreen()),
        ),
      if (s.investments != null)
        FinListTile(
          icon: Icons.trending_up_rounded,
          iconTone: DsTone.brand,
          title: "Investments".tr,
          subtitle: '${"Gains and losses".tr} ${FinanceMoney.signed(s.totalGains, s.currency)} · ${"invested".tr} ${m(s.investments!['investedCapital'])}',
          amount: m(s.investments!['currentValuation']),
          chevron: true,
          onTap: () => Get.to(() => const InvestmentsScreen()),
        ),
      if (s.loans != null)
        FinListTile(
          icon: Icons.handshake_outlined,
          iconTone: FinanceSummary.intOf(s.loans!['overdueCount']) > 0 ? DsTone.danger : DsTone.brand,
          title: "Loans".tr,
          subtitle: '${"Lent, outstanding".tr} ${m(s.loans!['lentOutstanding'])}',
          amount: m(s.loans!['borrowedOutstanding']),
          chevron: true,
          onTap: () => Get.to(() => const LoansScreen()),
        ),
      if (s.tontines != null)
        FinListTile(
          icon: Icons.groups_2_outlined,
          iconTone: DsTone.brand,
          title: "Tontines".tr,
          subtitle: '${FinanceSummary.intOf(s.tontines!['active'])} ${"active".tr}',
          amount: s.tontines!['nextContributionAmount'] == null ? null : m(s.tontines!['nextContributionAmount']),
          chevron: true,
          onTap: () => Get.to(() => const TontineListScreen()),
        ),
      if (s.insurance != null)
        FinListTile(
          icon: Icons.health_and_safety_outlined,
          iconTone: DsTone.brand,
          title: "Insurance".tr,
          subtitle:
              '${FinanceSummary.intOf(s.insurance!['activePolicies'])} ${"active policies".tr} · ${FinanceSummary.intOf(s.insurance!['openClaims'])} ${"open claims".tr}',
          chevron: true,
          onTap: () => Get.to(() => const InsuranceScreen()),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FinSection(title: "Your money".tr, divided: true, padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg), children: rows),
      if (s.updatedAt != null)
        Padding(
          padding: const EdgeInsets.only(top: DsSpace.sm, left: DsSpace.xxs),
          child: Text('${"Totals recorded by Spideli Finance".tr} · ${"Updated".tr} ${ltr(DateFormat('dd MMM, HH:mm').format(s.updatedAt!))}',
              style: DsTypography.caption.copyWith(color: c.textSecondary)),
        ),
    ]);
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context) => const TransactionList(limit: 5, paged: false);
}

/// Money in and out per month, and the last 30 days by kind (server totals).
class _CashFlow extends StatelessWidget {
  final FinanceSummary summary;

  const _CashFlow({required this.summary});

  static String _kind(String key) => const {
        'deposits': 'Deposits',
        'withdrawals': 'Withdrawals',
        'transfers': 'Transfers',
        'cardPayments': 'Card payments',
        'billPayments': 'Bill payments',
      }[key] ??
      key;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final c = DsColors.of(context);
    return FinSection(
      title: "Cash flow".tr,
      footnote: "Money in and out of your Spideli Finance accounts, as recorded. Tap a month to read it.".tr,
      children: [
        const DsGap(DsSpace.sm),
        FinBarChart(
          labels: [for (final f in s.monthly) DateFormat('MMM yyyy').format(DateTime.parse('${f.month}-01'))],
          a: [for (final f in s.monthly) f.moneyIn.toDouble()],
          b: [for (final f in s.monthly) f.moneyOut.toDouble()],
          aLabel: "Money in".tr,
          bLabel: "Money out".tr,
          aColor: c.success,
          bColor: FinColors.brand(context),
          format: (v) => FinanceMoney.format(v, s.currency),
        ),
        if (s.last30Days.isNotEmpty) ...[
          const DsGap(DsSpace.md),
          Divider(height: 1, color: c.divider),
          const DsGap(DsSpace.xs),
          Text("Last 30 days".tr, style: DsTypography.labelSm.copyWith(color: c.textSecondary)),
          for (final e in s.last30Days.entries) FinRow(_kind(e.key).tr, FinanceMoney.format(e.value, s.currency)),
        ],
      ],
    );
  }
}

/// Every Spideli Finance service, grouped by purpose.
class _Services extends StatelessWidget {
  const _Services();

  @override
  Widget build(BuildContext context) {
    final groups = <(String, List<(IconData, String, Widget Function())>)>[
      (
        "Pay and transfer",
        [
          (Icons.north_east_rounded, "Send money", () => const TransfersScreen()),
          (Icons.receipt_outlined, "Pay bills", () => const BillsScreen()),
          (Icons.credit_card_outlined, "Virtual cards", () => const CardsScreen()),
        ]
      ),
      (
        "Save and invest",
        [
          (Icons.savings_outlined, "Savings goals", () => const SavingsListScreen()),
          (Icons.groups_2_outlined, "Tontines", () => const TontineListScreen()),
          (Icons.trending_up_rounded, "Investments", () => const InvestmentsScreen()),
        ]
      ),
      (
        "Borrow and protect",
        [
          (Icons.handshake_outlined, "Loans", () => const LoansScreen()),
          (Icons.health_and_safety_outlined, "Insurance", () => const InsuranceScreen()),
          (Icons.business_center_outlined, "Project financing", () => const FinancingScreen()),
        ]
      ),
      (
        "Insights",
        [
          (Icons.insights_outlined, "Economic intelligence", () => const IntelligenceScreen()),
          (Icons.support_agent_rounded, "Financial coach", () => const CoachScreen()),
        ]
      ),
    ];
    final c = DsColors.of(context);
    return FinSection(
      title: "Services".tr,
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.lg),
      children: [
        for (final (gi, (name, items)) in groups.indexed) ...[
          if (gi > 0) const DsGap(DsSpace.md),
          Text(name.tr, style: DsTypography.labelSm.copyWith(color: c.textSecondary)),
          const DsGap(DsSpace.sm),
          FinActions(actions: [for (final (icon, label, page) in items) FinAction(icon, label.tr, () => Get.to(page))]),
        ],
      ],
    );
  }
}

/// Identity, statements and history.
class _Account extends StatelessWidget {
  const _Account();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: FinanceService.myProfile(),
      builder: (context, snap) {
        final String? status = snap.data?['kycStatus']?.toString();
        final bool verified = (snap.data?['kycLevel']?.toString() ?? '').isNotEmpty;
        final String shown = verified ? KycStatus.approved : (status ?? 'none');
        return FinSection(
          title: "Account".tr,
          divided: true,
          children: [
            FinListTile(
              icon: verified ? Icons.verified_user_outlined : Icons.badge_outlined,
              iconTone: verified ? DsTone.success : DsTone.warning,
              title: "Identity verification".tr,
              status: shown == KycStatus.approved ? 'verified' : shown,
              statusLabel: KycStatus.label(verified ? KycStatus.approved : status).tr,
              chevron: true,
              onTap: () => Get.to(() => const KycScreen()),
            ),
            FinListTile(
              icon: Icons.picture_as_pdf_outlined,
              title: "Account statement".tr,
              subtitle: "PDF of your transactions for a period".tr,
              chevron: true,
              onTap: () => shareFinanceStatement(context),
            ),
            FinListTile(
              icon: Icons.history_rounded,
              title: "Transaction history".tr,
              chevron: true,
              onTap: () => Get.to(() => const TransactionsScreen()),
            ),
          ],
        );
      },
    );
  }
}

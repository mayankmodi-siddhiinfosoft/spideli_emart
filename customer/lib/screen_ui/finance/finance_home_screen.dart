import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/finance/bill_screens.dart';
import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/fin_kit.dart';
import 'package:customer/screen_ui/finance/finance_actions_screen.dart';
import 'package:customer/screen_ui/finance/finance_chat_screens.dart';
import 'package:customer/screen_ui/finance/finance_dashboard_screen.dart';
import 'package:customer/screen_ui/finance/finance_restriction.dart';
import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/insurance_screens.dart';
import 'package:customer/screen_ui/finance/investment_screens.dart';
import 'package:customer/screen_ui/finance/kyc_screen.dart';
import 'package:customer/screen_ui/finance/lending_screens.dart';
import 'package:customer/screen_ui/finance/savings_screens.dart';
import 'package:customer/screen_ui/finance/tontine_screens.dart';
import 'package:customer/screen_ui/finance/transactions_screen.dart';
import 'package:customer/screen_ui/finance/transfer_screens.dart';
import 'package:customer/screen_ui/finance/wallet_screens.dart';
import 'package:customer/service/finance_region_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/service/finance_wallet_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:customer/utils/finance_wallet_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Spideli Finance > Home (the dashboard's first tab): the wallet, what is
/// due, the totals per service and the latest activity. The services, the
/// insights and the profile have their own tabs (FinanceDashboardScreen).
/// Everything shown is what the server recorded
/// (.claude/FINANCE-APP-CONTRACT.md):
///  - verification: users/{uid} `kycStatus` / `kycLevel`;
///  - balance: financial_accounts (the wallet);
///  - products, obligations and cash flow: the user's own records, totalled
///    on the device (FinanceSummaryService);
///  - activity and statements: ledger_transactions.
/// The app never adds amounts up into a balance or a total of its own.
class FinanceHomeScreen extends StatelessWidget {
  const FinanceHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FinScaffold(
      title: "Spideli Finance".tr,
      actions: [
        const FinanceChatsButton(),
        DsIconButton(icon: Icons.picture_as_pdf_outlined, semanticLabel: "Download statement".tr, onPressed: () => shareFinanceStatement(context)),
      ],
      body: StreamBuilder<FinanceSummary?>(
        stream: FinanceService.summary(),
        builder: (context, sumSnap) {
          final s = sumSnap.data;
          return FinBody(children: [
            FinGreeting(firstName: Constant.userModel?.firstName),
            const FinanceRestrictionNotice(),
            const _VerificationNotice(),
            _BalanceHero(summary: s),
            const FinanceActionsSection(),
            if (s != null) _Upcoming(summary: s),
            if (s != null) _ThisMonth(summary: s),
            FinanceProducts(summary: s, loading: sumSnap.connectionState == ConnectionState.waiting, error: sumSnap.hasError),
            FinSection(
              title: "Recent activity".tr,
              actionLabel: "See all".tr,
              onAction: () => FinanceDashboardController.showTab(FinanceTab.wallet, orOpen: () => const TransactionsScreen()),
              padding: EdgeInsets.zero,
              children: const [_RecentActivity()],
            ),
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

  /// The wallet settings of the customer's region, live (which money actions to offer).
  static final Stream<WalletConfig?> _walletConfig = FinanceRegion.live(() => FinanceWalletService.config().catchError((Object _) => null));

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceService.myAccounts(),
      builder: (context, snap) {
        // On a failure the actions stay: sending or paying does not need the
        // balance on screen.
        final bool failed = snap.hasError;
        final wallets = activeWallets(snap.data ?? const []);
        final preferred = preferredWallet(wallets, s?.currency);
        final String cur = preferred?['currency']?.toString() ?? s?.currency ?? 'XAF';
        final others = wallets.where((w) => w != preferred).toList();
        String m(dynamic v) => FinanceMoney.format(FinanceSummary.intOf(v), s?.currency ?? cur);
        final stats = <FinHeroStat>[
          if (s?.investments != null) FinHeroStat("Invested".tr, m(s!.investments!['currentValuation'])),
          if (s?.savings != null) FinHeroStat("Saved so far".tr, m(s!.savings!['savedAmount'])),
          if (s?.loans != null) FinHeroStat("Still to repay".tr, m(s!.loans!['borrowedOutstanding'])),
        ];
        final hero = FinHero(
          privacy: true,
          label: "Available balance".tr,
          amount: failed ? '—' : (!snap.hasData ? '…' : FinanceMoney.format(preferred == null ? 0 : ((preferred['balance'] as num?) ?? 0), cur)),
          caption: failed
              ? "Could not load your balances.".tr
              : !snap.hasData
                  ? null
                  : preferred == null
                      ? "Your wallet opens with your first deposit.".tr
                      : others.isEmpty
                          ? "Spideli Finance wallet".tr
                          : '${"Also".tr}: ${others.map((w) => FinanceMoney.format((w['balance'] as num?) ?? 0, w['currency']?.toString() ?? '')).join(' · ')}',
          stats: stats,
        );
        // The actions sit under the card, as round buttons on the page.
        final actions = StreamBuilder<WalletConfig?>(
            stream: _walletConfig,
            builder: (context, cfg) {
              final w = cfg.data;
              final String main = preferred?['currency']?.toString() ?? cur;
              // Four actions: adding and withdrawing money when the wallet
              // settings offer them, then saving and investing.
              final actions = <FinAction>[
                if (w?.deposit.enabled == true) FinAction(Icons.add_card_rounded, "Add money".tr, () => Get.to(() => WalletAddMoneyScreen(currency: main))),
                FinAction(Icons.north_east_rounded, "Send".tr, () => Get.to(() => const TransfersScreen())),
                FinAction(Icons.receipt_outlined, "Pay bills".tr, () => Get.to(() => const BillsScreen())),
                if (w?.withdraw.enabled == true) FinAction(Icons.account_balance_outlined, "Withdraw".tr, () => Get.to(() => WalletWithdrawScreen(currency: main))),
                FinAction(Icons.savings_outlined, "Save".tr, () => Get.to(() => const SavingsListScreen())),
                FinAction(Icons.trending_up_rounded, "Invest".tr, () => Get.to(() => const InvestmentsScreen())),
              ];
              return FinActions(actions: [
                if (failed) FinAction(Icons.refresh_rounded, "Retry".tr, FinanceService.retry),
                ...actions.take(4),
              ]);
            },
          );
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [hero, const DsGap(DsSpace.lg), actions]);
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
            private: true,
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
            private: true,
            leading: FinDateBadge(d(s.loans?['nextRepaymentDate'])!),
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
            private: true,
            leading: FinDateBadge(d(s.tontines?['nextContributionDate'])!),
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
            private: true,
            leading: FinDateBadge(d(s.insurance?['nextRenewalDate'])!),
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

  /// The date is on the badge: the line says how far it is.
  static String _when(DateTime date, DateTime now) {
    final int days = DateTime(date.year, date.month, date.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    final String weekday = DateFormat('EEEE').format(date);
    if (days < 0) return "Past due".tr;
    if (days == 0) return "Today".tr;
    if (days == 1) return "Tomorrow".tr;
    if (days < 7) return '$weekday · ${"In".tr} $days ${"days".tr}';
    return '${"In".tr} $days ${"days".tr}';
  }
}

/// The latest month's money in and out (server totals), next to the month
/// before, and the way to the full cash flow in Insights.
class _ThisMonth extends StatelessWidget {
  final FinanceSummary summary;

  const _ThisMonth({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    if (s.monthly.isEmpty) return const SizedBox.shrink();
    final last = s.monthly.last;
    final prev = s.monthly.length > 1 ? s.monthly[s.monthly.length - 2] : null;
    String m(int v) => FinanceMoney.format(v, s.currency);
    String month(String key) => ltr(DateFormat('MMM yyyy').format(DateTime.parse('$key-01')));
    final bool current = last.month == DateFormat('yyyy-MM').format(DateTime.now());
    return FinSection(
      title: current ? "This month".tr : month(last.month),
      actionLabel: "Insights".tr,
      onAction: () => FinanceDashboardController.showTab(FinanceTab.insights, orOpen: () => const FinanceDashboardScreen(initialTab: FinanceTab.insights)),
      surface: false,
      children: [
        FinInOut(
          moneyIn: last.moneyIn,
          moneyOut: last.moneyOut,
          previousIn: prev?.moneyIn,
          previousOut: prev?.moneyOut,
          previousLabel: prev == null ? null : month(prev.month),
          format: (v) => m(v.round()),
          signed: (v) => FinanceMoney.signed(v, s.currency),
        ),
      ],
    );
  }
}

/// Every product the user holds, one aligned list (server totals).
class FinanceProducts extends StatelessWidget {
  final FinanceSummary? summary;
  final bool loading;
  final bool error;

  const FinanceProducts({super.key, required this.summary, required this.loading, required this.error});

  @override
  Widget build(BuildContext context) {
    if (error) return FinState.error("Could not load your overview.".tr, onRetry: FinanceService.retry);
    if (loading) return FinState.loading(rows: 3);
    final s = summary;
    if (s == null) {
      return FinState.empty(Icons.insights_outlined, "Your overview appears here once you use Spideli Finance services.".tr);
    }
    final c = DsColors.of(context);
    String m(dynamic v) => FinanceMoney.format(FinanceSummary.intOf(v), s.currency);
    final int lent = FinanceSummary.intOf(s.loans?['lentOutstanding']);
    final int policies = FinanceSummary.intOf(s.insurance?['activePolicies']);
    final int claims = FinanceSummary.intOf(s.insurance?['openClaims']);
    final bool overdue = FinanceSummary.intOf(s.loans?['overdueCount']) > 0;
    final double? ret = s.investmentReturnPercent;
    final tiles = <FinProductTile>[
      if (s.savings != null)
        FinProductTile(
          icon: Icons.savings_outlined,
          accent: FinAccent.save,
          title: "Collective savings".tr,
          value: m(s.savings!['savedAmount']),
          progress: s.savingsProgress,
          meta: '${((s.savingsProgress ?? 0) * 100).round()}% ${"of the target".tr} · ${FinanceSummary.intOf(s.savings!['activeGoals'])} ${"active".tr}',
          onTap: () => Get.to(() => const SavingsListScreen()),
        ),
      if (s.investments != null)
        FinProductTile(
          icon: Icons.trending_up_rounded,
          accent: FinAccent.save,
          title: "Investment".tr,
          value: m(s.investments!['currentValuation']),
          meta: [
            if (ret != null) '${"Return".tr} ${ltr('${ret >= 0 ? '+' : '−'}${ret.abs().toStringAsFixed(1)} %')}',
            FinanceMoney.signed(s.totalGains, s.currency),
          ].join(' · '),
          onTap: () => Get.to(() => const InvestmentsScreen()),
        ),
      if (s.loans != null)
        FinProductTile(
          icon: Icons.handshake_outlined,
          accent: FinAccent.borrow,
          title: "Loan".tr,
          value: m(s.loans!['borrowedOutstanding']),
          alert: overdue,
          // What the customer still owes; what they lent only when there is some.
          meta: overdue ? "Repayment overdue".tr : (lent > 0 ? '${"Lent, outstanding".tr} ${m(lent)}' : "Still to repay".tr),
          onTap: () => Get.to(() => const LoansScreen()),
        ),
      if (s.tontines != null)
        FinProductTile(
          icon: Icons.groups_2_outlined,
          accent: FinAccent.save,
          title: "Tontine".tr,
          value: s.tontines!['nextContributionAmount'] == null ? FinanceUi.count(FinanceSummary.intOf(s.tontines!['active']), "active", "active") : m(s.tontines!['nextContributionAmount']),
          meta: '${FinanceSummary.intOf(s.tontines!['active'])} ${"active".tr}${s.tontines!['nextContributionAmount'] == null ? '' : ' · ${"next contribution".tr}'}',
          onTap: () => Get.to(() => const TontineListScreen()),
        ),
      if (s.insurance != null)
        FinProductTile(
          icon: Icons.health_and_safety_outlined,
          accent: FinAccent.borrow,
          title: "Online insurance".tr,
          value: '$policies ${(policies == 1 ? "policy" : "policies").tr}',
          meta: '$claims ${(claims == 1 ? "open claim" : "open claims").tr}',
          onTap: () => Get.to(() => const InsuranceScreen()),
        ),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FinSection(title: "Your money".tr, surface: false, children: [FinTileGrid(tiles: tiles)]),
      if (s.updatedAt != null)
        Padding(
          padding: const EdgeInsets.only(top: DsSpace.sm, left: DsSpace.xxs),
          child: Text('${"From your Spideli Finance records".tr} · ${"Updated".tr} ${ltr(DateFormat('dd MMM, HH:mm').format(s.updatedAt!))}',
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
class FinanceCashFlow extends StatelessWidget {
  final FinanceSummary summary;

  const FinanceCashFlow({super.key, required this.summary});

  static (IconData, String) _kind(String key) => switch (key) {
        'deposits' => (Icons.add_card_rounded, 'Deposits'),
        'withdrawals' => (Icons.account_balance_outlined, 'Withdrawals'),
        'transfers' => (Icons.north_east_rounded, 'Transfers'),
        'cardPayments' => (Icons.credit_card_outlined, 'Card payments'),
        'billPayments' => (Icons.receipt_outlined, 'Bill payments'),
        _ => (Icons.swap_horiz_rounded, key),
      };

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final c = DsColors.of(context);
    String m(num v) => FinanceMoney.format(v, s.currency);
    final last = s.monthly.isEmpty ? null : s.monthly.last;
    final prev = s.monthly.length > 1 ? s.monthly[s.monthly.length - 2] : null;
    String month(String key) => ltr(DateFormat('MMM yyyy').format(DateTime.parse('$key-01')));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (last != null)
        FinSection(
          title: last.month == DateFormat('yyyy-MM').format(DateTime.now()) ? "This month".tr : month(last.month),
          top: 0,
          surface: false,
          children: [
            FinInOut(
              moneyIn: last.moneyIn,
              moneyOut: last.moneyOut,
              previousIn: prev?.moneyIn,
              previousOut: prev?.moneyOut,
              previousLabel: prev == null ? null : month(prev.month),
              format: m,
              signed: (v) => FinanceMoney.signed(v, s.currency),
            ),
          ],
        ),
      FinSection(
        title: "Cash flow".tr,
        top: last == null ? 0 : FinSpace.section,
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
            format: (v) => m(v),
          ),
        ],
      ),
      if (s.last30Days.isNotEmpty)
        FinSection(
          title: "Last 30 days".tr,
          children: [
            FinBreakdown(
              items: [for (final e in s.last30Days.entries) (_kind(e.key).$1, _kind(e.key).$2.tr, e.value)],
              format: m,
            ),
          ],
        ),
    ]);
  }
}

/// Profile > Groups: the groups the user saves, rotates and lends with.
class FinanceGroupsScreen extends StatelessWidget {
  const FinanceGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FinScaffold(
      title: "Groups".tr,
      body: StreamBuilder<FinanceSummary?>(
        stream: FinanceService.summary(),
        builder: (context, snap) {
          final int tontines = FinanceSummary.intOf(snap.data?.tontines?['active']);
          return FinBody(children: [
            FinSection(
              divided: true,
              children: [
                FinListTile(
                  icon: Icons.groups_2_outlined,
                  iconTone: DsTone.brand,
                  title: "Tontines".tr,
                  subtitle: tontines > 0 ? '$tontines ${"active".tr}' : "Save together and take turns receiving the pot".tr,
                  chevron: true,
                  onTap: () => Get.to(() => const TontineListScreen()),
                ),
                FinListTile(
                  icon: Icons.savings_outlined,
                  iconTone: DsTone.brand,
                  title: "Collective savings".tr,
                  subtitle: "Goals you save for with other members".tr,
                  chevron: true,
                  onTap: () => Get.to(() => const SavingsListScreen()),
                ),
                FinListTile(
                  icon: Icons.handshake_outlined,
                  iconTone: DsTone.brand,
                  title: "Loan groups".tr,
                  subtitle: "Loan requests from your groups to vote on and fund".tr,
                  chevron: true,
                  onTap: () => Get.to(() => const LoansScreen(initialTab: 1)),
                ),
              ],
            ),
          ]);
        },
      ),
    );
  }
}

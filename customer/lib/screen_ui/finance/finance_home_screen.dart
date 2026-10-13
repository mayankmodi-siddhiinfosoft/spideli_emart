import 'package:customer/screen_ui/finance/finance_ui.dart';
import 'package:customer/screen_ui/finance/kyc_screen.dart';
import 'package:customer/screen_ui/finance/transactions_screen.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Profile > Spideli Finance: the financial dashboard. Everything shown is
/// what the server recorded (.claude/FINANCE-APP-CONTRACT.md):
///  - verification: users/{uid} `kycStatus` / `kycLevel`;
///  - balances: financial_accounts;
///  - overview: finance_summaries/{uid} (server-maintained totals);
///  - activity and statements: ledger_transactions.
/// The app never adds amounts up into a balance or a total of its own.
class FinanceHomeScreen extends StatelessWidget {
  const FinanceHomeScreen({super.key});

  Future<void> _statement(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: DateTimeRange(start: DateTime(now.year, now.month - 1, now.day), end: now),
    );
    if (range == null) return;
    ShowToastDialog.showLoader("Please wait...".tr);
    try {
      final result = await FinanceService.statementRows(range.start, range.end);
      ShowToastDialog.closeLoader();
      if (result.rows.isEmpty) {
        ShowToastDialog.showToast("No transactions in this period.".tr);
        return;
      }
      if (result.truncated) {
        ShowToastDialog.showToast("This period has too many transactions for one statement. Only the first ones are included; choose a shorter period.".tr);
      }
      await FinanceService.shareStatement(range.start, range.end, result.rows);
    } catch (_) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Could not create the statement. Please try again.".tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DsScaffold(
      title: "Spideli Finance".tr,
      maxContentWidth: DsLayout.contentMax,
      actions: [
        DsIconButton(icon: Icons.picture_as_pdf_outlined, semanticLabel: "Download statement".tr, onPressed: () => _statement(context)),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        children: [
          const _VerificationCard(),
          const DsGap(DsSpace.lg),
          const _Balances(),
          const DsGap(DsSpace.lg),
          const _Overview(),
          const DsGap(DsSpace.lg),
          DsFormSection(
            title: "Recent activity".tr,
            icon: Icons.receipt_long_outlined,
            trailing: DsButton.ghost(label: "See all".tr, size: DsButtonSize.sm, onPressed: () => Get.to(() => const TransactionsScreen())),
            children: const [TransactionList(limit: 5, paged: false)],
          ),
          const DsGap(DsSpace.md),
          DsButton.secondary(label: "Download statement".tr, icon: Icons.picture_as_pdf_outlined, expand: true, onPressed: () => _statement(context)),
        ],
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: FinanceService.myProfile(),
      builder: (context, snap) {
        final String? status = snap.data?['kycStatus']?.toString();
        final String? level = snap.data?['kycLevel']?.toString();
        final bool verified = (level ?? '').isNotEmpty;
        final DsTone tone = verified ? DsTone.success : FinanceUi.tone(KycStatus.tone(status));
        final String text = verified
            ? "Your identity is verified. Finance services that need verification are available to you.".tr
            : status == null
                ? "Verify your identity to use Spideli Finance services.".tr
                : status == KycStatus.additionalInfo
                    ? "Your verification needs more information.".tr
                    : status == KycStatus.rejected
                        ? "Your verification was not approved. You can submit it again.".tr
                        : status == KycStatus.draft
                            ? "Finish your verification and submit it.".tr
                            : "Your documents are being reviewed.".tr;
        return DsCard.tinted(
          tone: tone,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  DsIconWell(icon: verified ? Icons.verified_user_rounded : Icons.badge_outlined, tone: tone),
                  const DsGap(DsSpace.md),
                  Expanded(child: Text("Identity verification".tr, style: DsTypography.titleSm.copyWith(color: DsColors.of(context).textPrimary))),
                  FinanceUi.kycBadge(verified ? KycStatus.approved : status),
                ],
              ),
              const DsGap(DsSpace.sm),
              Text(text, style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary)),
              const DsGap(DsSpace.md),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: DsButton.tonal(
                  label: (verified ? "View verification" : status == null ? "Verify my identity" : "Open verification").tr,
                  icon: Icons.arrow_forward_rounded,
                  size: DsButtonSize.sm,
                  onPressed: () => Get.to(() => const KycScreen()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Balances extends StatelessWidget {
  const _Balances();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FinanceService.myAccounts(),
      builder: (context, snap) {
        if (snap.hasError) return DsErrorState(message: "Could not load your balances.".tr, compact: true);
        if (!snap.hasData) return const DsSkeletonList(itemCount: 1);
        final accounts = snap.data!.where((a) => a['status'] == 'active').toList();
        return DsFormSection(
          title: "Balances".tr,
          icon: Icons.account_balance_wallet_outlined,
          children: [
            if (accounts.isEmpty)
              Text("You have no finance account yet. It opens with your first deposit.".tr, style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary))
            else
              for (final a in accounts)
                DsListTile(
                  padding: EdgeInsets.zero,
                  leadingIcon: Icons.account_balance_wallet_rounded,
                  leadingTone: DsTone.brand,
                  title: "${(a['kind'] == 'wallet' ? 'Wallet' : 'Account').tr} · ${a['currency']}",
                  trailing: Text(
                    FinanceMoney.format((a['balance'] as num?) ?? 0, a['currency']?.toString() ?? ''),
                    style: DsTypography.titleSm.copyWith(color: DsColors.of(context).textPrimary).tabular,
                  ),
                ),
          ],
        );
      },
    );
  }
}

/// The module overview from finance_summaries/{uid}.
class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FinanceSummary?>(
      stream: FinanceService.summary(),
      builder: (context, snap) {
        if (snap.hasError) return DsErrorState(message: "Could not load your overview.".tr, compact: true);
        if (snap.connectionState == ConnectionState.waiting) return const DsSkeletonList(itemCount: 3);
        final s = snap.data;
        if (s == null) {
          return DsEmptyState(
            icon: Icons.insights_outlined,
            title: "Your overview appears here once you use Spideli Finance services.".tr,
            compact: true,
          );
        }
        String m(dynamic v) => FinanceMoney.format(FinanceSummary.intOf(v), s.currency);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text("Overview".tr, style: DsTypography.titleSm.copyWith(color: DsColors.of(context).textPrimary))),
                if (s.updatedAt != null)
                  Text("${"Updated".tr} ${DateFormat('dd MMM, HH:mm').format(s.updatedAt!)}", style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary)),
              ],
            ),
            const DsGap(DsSpace.sm),
            _ModuleCard(
              icon: Icons.trending_up_rounded,
              title: "Investments".tr,
              rows: s.investments == null
                  ? null
                  : [
                      ("Invested capital".tr, m(s.investments!['investedCapital'])),
                      ("Current value".tr, m(s.investments!['currentValuation'])),
                      ("Gains and losses".tr, '${s.totalGains > 0 ? '+' : ''}${m(s.totalGains)}'),
                    ],
            ),
            _ModuleCard(
              icon: Icons.savings_outlined,
              title: "Savings goals".tr,
              rows: s.savings == null
                  ? null
                  : [
                      ("Active goals".tr, '${FinanceSummary.intOf(s.savings!['activeGoals'])}'),
                      ("Saved".tr, '${m(s.savings!['savedAmount'])} / ${m(s.savings!['targetAmount'])}'),
                    ],
              progress: s.savingsProgress,
            ),
            _ModuleCard(
              icon: Icons.groups_2_outlined,
              title: "Tontines".tr,
              rows: s.tontines == null
                  ? null
                  : [
                      ("Active tontines".tr, '${FinanceSummary.intOf(s.tontines!['active'])}'),
                      if (s.tontines!['nextContributionAmount'] != null)
                        ("Next contribution".tr, '${m(s.tontines!['nextContributionAmount'])} · ${FinanceUi.date(s.tontines!['nextContributionDate']).split(',').first}'),
                      if (s.tontines!['nextPayoutDate'] != null) ("Next payout".tr, FinanceUi.date(s.tontines!['nextPayoutDate']).split(',').first),
                    ],
            ),
            _ModuleCard(
              icon: Icons.handshake_outlined,
              title: "Loans".tr,
              rows: s.loans == null
                  ? null
                  : [
                      ("Borrowed, outstanding".tr, m(s.loans!['borrowedOutstanding'])),
                      ("Lent, outstanding".tr, m(s.loans!['lentOutstanding'])),
                      if (s.loans!['nextRepaymentAmount'] != null)
                        ("Next repayment".tr, '${m(s.loans!['nextRepaymentAmount'])} · ${FinanceUi.date(s.loans!['nextRepaymentDate']).split(',').first}'),
                    ],
              alert: FinanceSummary.intOf(s.loans?['overdueCount']) > 0 ? "A repayment is overdue.".tr : null,
            ),
            _ModuleCard(
              icon: Icons.health_and_safety_outlined,
              title: "Insurance".tr,
              rows: s.insurance == null
                  ? null
                  : [
                      ("Active policies".tr, '${FinanceSummary.intOf(s.insurance!['activePolicies'])}'),
                      if (s.insurance!['nextRenewalDate'] != null) ("Next renewal".tr, FinanceUi.date(s.insurance!['nextRenewalDate']).split(',').first),
                      ("Open claims".tr, '${FinanceSummary.intOf(s.insurance!['openClaims'])}'),
                    ],
            ),
            if (s.last30Days.isNotEmpty) ...[
              const DsGap(DsSpace.sm),
              DsFormSection(
                title: "Last 30 days".tr,
                icon: Icons.swap_vert_rounded,
                children: [
                  for (final e in s.last30Days.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(child: Text(_paymentLabel(e.key).tr, style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary))),
                          Text(m(e.value), style: DsTypography.bodyStrong.copyWith(color: DsColors.of(context).textPrimary).tabular),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            if (s.monthly.isNotEmpty) ...[
              const DsGap(DsSpace.lg),
              DsFormSection(
                title: "Money in and out".tr,
                icon: Icons.bar_chart_rounded,
                children: [_MonthlyChart(summary: s)],
              ),
            ],
          ],
        );
      },
    );
  }

  static String _paymentLabel(String key) => const {
        'deposits': 'Deposits',
        'withdrawals': 'Withdrawals',
        'transfers': 'Transfers',
        'cardPayments': 'Card payments',
        'billPayments': 'Bill payments',
      }[key] ??
      key;
}

/// A module of the overview; [rows] null = the user has not used it yet.
class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<(String, String)>? rows;
  final double? progress;
  final String? alert;

  const _ModuleCard({required this.icon, required this.title, required this.rows, this.progress, this.alert});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: DsCard.outlined(
        padding: const EdgeInsets.all(DsSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DsIconWell(icon: icon, tone: rows == null ? DsTone.neutral : DsTone.brand, size: 36),
                const DsGap(DsSpace.md),
                Expanded(child: Text(title, style: DsTypography.titleSm.copyWith(color: c.textPrimary))),
                if (rows == null) DsBadge(label: "Not started yet".tr, small: true),
              ],
            ),
            if (rows != null) ...[
              const DsGap(DsSpace.sm),
              for (final (label, value) in rows!)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text(label, style: DsTypography.body.copyWith(color: c.textSecondary))),
                      Text(value, style: DsTypography.bodyStrong.copyWith(color: c.textPrimary).tabular),
                    ],
                  ),
                ),
              if (progress != null) ...[
                const DsGap(DsSpace.sm),
                DsProgressBar(value: progress, showPercent: true),
              ],
              if (alert != null) ...[
                const DsGap(DsSpace.sm),
                DsInlineAlert(tone: DsTone.danger, message: alert!),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Money in / money out per month, as bars (server totals).
class _MonthlyChart extends StatelessWidget {
  final FinanceSummary summary;

  const _MonthlyChart({required this.summary});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    const double height = 120;
    final int max = summary.chartMax;
    Widget bar(int value, Color color) => Container(
          width: 10,
          height: value <= 0 ? 2 : (value / max * height).clamp(2, height).toDouble(),
          decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height + 22,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final f in summary.monthly)
                Semantics(
                  label: '${f.month}: ${"Money in".tr} ${FinanceMoney.format(f.moneyIn, summary.currency)}, ${"Money out".tr} ${FinanceMoney.format(f.moneyOut, summary.currency)}',
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [bar(f.moneyIn, c.success), const SizedBox(width: 3), bar(f.moneyOut, c.danger)]),
                      const DsGap(DsSpace.xs),
                      Text(DateFormat('MMM').format(DateTime.parse('${f.month}-01')), style: DsTypography.caption.copyWith(color: c.textSecondary)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const DsGap(DsSpace.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 10, height: 10, color: c.success),
            const DsGap(DsSpace.xs),
            Text("Money in".tr, style: DsTypography.caption),
            const DsGap(DsSpace.lg),
            Container(width: 10, height: 10, color: c.danger),
            const DsGap(DsSpace.xs),
            Text("Money out".tr, style: DsTypography.caption),
          ],
        ),
      ],
    );
  }
}

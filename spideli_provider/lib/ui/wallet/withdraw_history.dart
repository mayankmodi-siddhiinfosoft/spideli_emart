import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/controller/wallet_controller.dart';
import 'package:spideliprovider/model/withdrawHistoryModel.dart';
import 'package:spideliprovider/services/region_service.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Payout history (archetype H – finance). A payout-ledger route: requested /
/// paid-out summary tiles over a list of status-chipped payout cards, each one
/// opening a receipt sheet.
class WithdrawHistoryScreen extends StatelessWidget {
  const WithdrawHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<WalletController>(
      init: WalletController(),
      builder: (controller) {
        // Read synchronously so this GetX tracks the list: the item builder
        // below runs later and would not be observed.
        final List<WithdrawHistoryModel> rows = controller.withdrawHistoryQuery.toList();
        return DsScaffold.collapsing(
          title: "Withdraw History".tr,
          slivers: rows.isEmpty
              ? [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: DsEmptyState(icon: Icons.account_balance_outlined, title: 'No Withdraw history found'.tr, message: "Your payout requests and their status will show up here.".tr),
                  ),
                ]
              : [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.lg, DsSpace.xs),
                      child: DsFadeSlideIn(child: _PayoutSummary(rows: rows)),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, 0),
                    sliver: SliverList.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const DsGap(DsSpace.md),
                      itemBuilder: (context, index) {
                        return DsFadeSlideIn(
                          index: index,
                          child: buildTransactionCard(context, withdrawHistory: rows[index], date: rows[index].paidDate.toDate()),
                        );
                      },
                    ),
                  ),
                ],
        );
      },
    );
  }

  Widget buildTransactionCard(BuildContext context, {required WithdrawHistoryModel withdrawHistory, required DateTime date}) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool paid = withdrawHistory.paymentStatus == "Success";
    final DsTone tone = paid ? DsTone.success : DsTone.warning;
    return DsCard.outlined(
      onTap: () => showWithdrawalModelSheet(context, withdrawHistory),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsIconWell(icon: Icons.account_balance_wallet_rounded, tone: tone, size: 44, circle: true),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "- ${amountShow(currency: RegionService.currencyForBooking(withdrawHistory.regionId), amount: (withdrawHistory.amount.toString()))}",
                      style: t.title.tabular.withColor(c.tone(tone).strong),
                    ),
                    const DsGap(DsSpace.xxs),
                    Text(DateFormat('MMM dd, yyyy, KK:mma').format(withdrawHistory.paidDate.toDate()).toUpperCase(), style: t.caption),
                  ],
                ),
              ),
              const DsGap(DsSpace.sm),
              DsStatusChip(label: withdrawHistory.paymentStatus, status: withdrawHistory.paymentStatus, pulse: !paid),
            ],
          ),
          if (withdrawHistory.note.isNotEmpty) ...[
            const DsDivider(spacing: DsSpace.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sticky_note_2_outlined, size: 16, color: c.textMuted),
                const DsGap(DsSpace.sm),
                Expanded(
                  child: Text(withdrawHistory.note, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySm),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  showWithdrawalModelSheet(BuildContext context, WithdrawHistoryModel withdrawHistoryModel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // ignore: unused_local_variable
        final themeChange = Provider.of<DarkThemeProvider>(context);
        final c = context.dsColors;
        final t = context.dsText;
        final bool paid = withdrawHistoryModel.paymentStatus == "Success";
        final DsTone tone = paid ? DsTone.success : DsTone.warning;
        return DsSheet(
          title: 'Withdrawal Details'.tr,
          showClose: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DsCard.tinted(
                tone: tone,
                child: Column(
                  children: [
                    DsIconWell(icon: Icons.account_balance_wallet_rounded, tone: tone, size: 52, circle: true),
                    const DsGap(DsSpace.md),
                    Text(
                      amountShow(currency: RegionService.currencyForBooking(withdrawHistoryModel.regionId), amount: withdrawHistoryModel.amount.toString()),
                      textAlign: TextAlign.center,
                      style: t.metric.tabular.withColor(c.tone(tone).strong),
                    ),
                    const DsGap(DsSpace.sm),
                    DsStatusChip(label: withdrawHistoryModel.paymentStatus, status: withdrawHistoryModel.paymentStatus),
                  ],
                ),
              ),
              const DsGap(DsSpace.lg),
              DsTileGroup(
                dividerIndent: DsSpace.lg,
                children: [
                  DsListTile(title: "Transaction ID".tr, subtitle: withdrawHistoryModel.id),
                  DsListTile(title: "Date".tr, subtitle: DateFormat('MMM dd, yyyy, KK:mma').format(withdrawHistoryModel.paidDate.toDate()).toUpperCase()),
                ],
              ),
              Visibility(
                visible: withdrawHistoryModel.note.isNotEmpty,
                child: Padding(
                  padding: const EdgeInsets.only(top: DsSpace.lg),
                  child: DsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Note".tr, style: t.labelSm),
                        const DsGap(DsSpace.xs),
                        Text(withdrawHistoryModel.note, style: t.body),
                      ],
                    ),
                  ),
                ),
              ),
              Visibility(
                visible: withdrawHistoryModel.adminNote.isNotEmpty,
                child: Padding(
                  padding: const EdgeInsets.only(top: DsSpace.lg),
                  child: DsInlineAlert(tone: DsTone.info, title: "Admin Note".tr, message: withdrawHistoryModel.adminNote, icon: Icons.support_agent_rounded),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Requested / paid-out totals derived from the payouts already loaded.
class _PayoutSummary extends StatelessWidget {
  final List<WithdrawHistoryModel> rows;

  const _PayoutSummary({required this.rows});

  @override
  Widget build(BuildContext context) {
    num paidOut = 0;
    num pending = 0;
    for (final WithdrawHistoryModel row in rows) {
      final num amount = double.tryParse(row.amount.toString()) ?? 0;
      if (row.paymentStatus == "Success") {
        paidOut += amount;
      } else {
        pending += amount;
      }
    }
    return DsAdaptiveGrid(
      minItemWidth: 150,
      children: [
        DsStatTile(
          label: "Paid out".tr,
          countTo: paidOut,
          format: (v) => amountShow(amount: v.toString()),
          icon: Icons.task_alt_rounded,
          tone: DsTone.success,
          variant: DsStatTileVariant.tinted,
        ),
        DsStatTile(
          label: "Pending".tr,
          countTo: pending,
          format: (v) => amountShow(amount: v.toString()),
          icon: Icons.hourglass_bottom_rounded,
          tone: DsTone.warning,
          variant: DsStatTileVariant.tinted,
        ),
      ],
    );
  }
}

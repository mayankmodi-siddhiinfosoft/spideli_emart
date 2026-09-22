import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:vendor/app/Home_screen/order_details_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/wallet_controller.dart';
import 'package:vendor/models/currency_model.dart';
import 'package:vendor/models/wallet_transaction_model.dart';
import 'package:vendor/models/withdrawal_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/fire_store_utils.dart';

/// Pull-to-refresh wrapper whose empty state still scrolls (so it can refresh).
class _RefreshableList extends StatelessWidget {
  const _RefreshableList({
    required this.controller,
    required this.isDark,
    required this.header,
    required this.itemCount,
    required this.itemBuilder,
    required this.emptyMessage,
    this.emptyIcon = Icons.receipt_long_outlined,
    this.grouped = true,
  });

  final WalletController controller;
  final bool isDark;
  final Widget? header;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final String emptyMessage;
  final IconData emptyIcon;

  /// Rows share one card with hairline dividers (ledger look). When false,
  /// every row renders as its own card.
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return RefreshIndicator(
      color: c.brand,
      backgroundColor: c.surface,
      onRefresh: controller.refreshAll,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final l = context.dsLayout;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.xs, l.gutter, DsSpace.xxxl),
            children: [
              if (header != null) ...[DsFadeSlideIn(child: header!), const DsGap(DsSpace.lg)],
              if (itemCount == 0)
                SizedBox(
                  height: constraints.maxHeight * 0.5,
                  child: Center(
                    child: DsEmptyState(icon: emptyIcon, title: emptyMessage, compact: true),
                  ),
                )
              else if (grouped)
                DsCard(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                  child: Column(
                    children: [for (var i = 0; i < itemCount; i++) DsFadeSlideIn(index: i, child: itemBuilder(context, i))],
                  ),
                )
              else
                for (var i = 0; i < itemCount; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: DsSpace.md),
                    child: DsFadeSlideIn(index: i, child: itemBuilder(context, i)),
                  ),
            ],
          );
        },
      ),
    );
  }
}

/// Today / This week / This month selector plus one headline figure.
class _PeriodSummary extends StatelessWidget {
  const _PeriodSummary({
    required this.controller,
    required this.isDark,
    required this.label,
    required this.value,
    this.caption,
    this.icon = Icons.trending_up_rounded,
    this.tone = DsTone.success,
  });

  final WalletController controller;
  final bool isDark;
  final String label;
  final String value;
  final String? caption;
  final IconData icon;
  final DsTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final periods = {WalletPeriod.today: "Today".tr, WalletPeriod.week: "This week".tr, WalletPeriod.month: "This month".tr};
    final keys = periods.keys.toList();
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsSegmentedTabs(
            segments: [for (final e in periods.values) DsSegment(e)],
            index: keys.indexOf(controller.selectedPeriod.value).clamp(0, keys.length - 1),
            onChanged: (i) => controller.selectedPeriod.value = keys[i],
          ),
          const DsGap(DsSpace.lg),
          Row(
            children: [
              DsIconWell(icon: icon, tone: tone, size: 48),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: t.labelSm.withColor(c.textSecondary)),
                    const DsGap(DsSpace.xxs),
                    AnimatedSwitcher(
                      duration: DsMotion.of(context, DsMotion.base),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(anim),
                          child: child,
                        ),
                      ),
                      layoutBuilder: (current, previous) => Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
                      child: FittedBox(
                        key: ValueKey(value),
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(value, style: t.metric.withColor(c.textPrimary)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (caption != null) ...[const DsGap(DsSpace.sm), Text(caption!, style: t.caption)],
        ],
      ),
    );
  }
}

/// Day header used to group ledger rows ("Mon, 12 Aug 2026").
class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xs),
      child: Text(label.toUpperCase(), style: context.dsText.overline.withColor(c.textMuted)),
    );
  }
}

Widget _iconWell(String asset, DsTone tone) {
  return Builder(
    builder: (context) {
      final tc = context.dsColors.tone(tone);
      return DsIconWell(
        tone: tone,
        size: 44,
        child: SvgPicture.asset(asset, height: 18, width: 18, colorFilter: ColorFilter.mode(tc.strong, BlendMode.srcIn)),
      );
    },
  );
}

// ---------------------------------------------------------------- Earnings

class WalletEarningsTab extends StatelessWidget {
  const WalletEarningsTab({super.key, required this.controller, required this.isDark});

  final WalletController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = controller.walletTransactionList;
      final count = controller.periodEarningsCount;
      return _RefreshableList(
        controller: controller,
        isDark: isDark,
        header: _PeriodSummary(
          controller: controller,
          isDark: isDark,
          label: "Earnings".tr,
          value: Constant.amountShow(amount: controller.periodEarnings.toString(), currency: controller.periodEarningsCurrency),
          caption: "@count orders, net of tax and reversals".trParams({'count': count.toString()}),
        ),
        itemCount: rows.length,
        emptyMessage: "Transaction history not found".tr,
        emptyIcon: Icons.account_balance_wallet_outlined,
        itemBuilder: (context, index) {
          final row = rows[index];
          final day = row.date == null ? null : DateFormat('EEE, d MMM yyyy').format(row.date!.toDate());
          final prev = index == 0 || rows[index - 1].date == null ? null : DateFormat('EEE, d MMM yyyy').format(rows[index - 1].date!.toDate());
          final showHeader = day != null && (index == 0 || day != prev);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHeader) ...[if (index != 0) Divider(height: DsSpace.sm, thickness: 1, color: context.dsColors.divider), _DayHeader(day)],
              _transactionCard(context, row),
            ],
          );
        },
      );
    });
  }

  Widget _transactionCard(BuildContext context, WalletTransactionModel transactionModel) {
    final c = context.dsColors;
    final t = context.dsText;
    final hasOrder = (transactionModel.orderId ?? '').isNotEmpty && transactionModel.orderId != 'null';
    final amount = Constant.amountShow(amount: transactionModel.amount.toString(), currency: controller.currencyForTransaction(transactionModel));
    final isCredit = transactionModel.isTopup == true;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: hasOrder
            ? () async {
                await FireStoreUtils.getOrderByOrderId(transactionModel.orderId.toString()).then((value) {
                  if (value != null) {
                    Get.to(const OrderDetailsScreen(), arguments: {"orderModel": value});
                  }
                });
              }
            : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
            child: Row(
              children: [
                _iconWell(
                  transactionModel.isTopup == false ? "assets/icons/ic_debit.svg" : "assets/icons/ic_credit.svg",
                  isCredit ? DsTone.success : DsTone.danger,
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(transactionModel.note.toString(), style: t.bodyStrong),
                      const DsGap(DsSpace.xxs),
                      Wrap(
                        spacing: DsSpace.sm,
                        runSpacing: DsSpace.xxs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (transactionModel.date != null) Text(Constant.timestampToDateTime(transactionModel.date!), style: t.caption),
                          if (hasOrder) Text(WalletController.orderLabel(transactionModel.orderId), style: t.caption.withColor(c.textSecondary)),
                          if (controller.isAccountRow(transactionModel)) DsBadge(label: "Account".tr, small: true),
                        ],
                      ),
                    ],
                  ),
                ),
                const DsGap(DsSpace.sm),
                Text(transactionModel.isTopup == false ? "-$amount" : amount, style: t.titleSm.tabular.withColor(isCredit ? c.successStrong : c.dangerStrong)),
                if (hasOrder) ...[const DsGap(DsSpace.xxs), Icon(Icons.chevron_right_rounded, size: 18, color: c.textMuted)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- Commissions

class WalletCommissionsTab extends StatelessWidget {
  const WalletCommissionsTab({super.key, required this.controller, required this.isDark});

  final WalletController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = controller.commissionList;
      final periodRows = controller.periodCommissionRows;
      return _RefreshableList(
        controller: controller,
        isDark: isDark,
        grouped: false,
        header: _PeriodSummary(
          controller: controller,
          isDark: isDark,
          icon: Icons.pie_chart_outline_rounded,
          tone: DsTone.warning,
          label: "Total commission".tr,
          value: Constant.amountShow(amount: controller.periodCommission.toString(), currency: controller.periodCommissionCurrency),
          caption: "@count completed orders".trParams({'count': periodRows.length.toString()}),
        ),
        itemCount: rows.length,
        emptyMessage: "No completed orders yet".tr,
        emptyIcon: Icons.pie_chart_outline_rounded,
        itemBuilder: (context, index) => _commissionCard(context, rows[index]),
      );
    });
  }

  Widget _line(BuildContext context, String label, String value, {Color? color, bool bold = false}) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: t.bodySm.withColor(c.textSecondary))),
          const DsGap(DsSpace.sm),
          Text(value, style: (bold ? t.label : t.bodyStrong).tabular.withColor(color ?? c.textPrimary)),
        ],
      ),
    );
  }

  Widget _commissionCard(BuildContext context, OrderCommissionRow row) {
    final c = context.dsColors;
    final t = context.dsText;
    final CurrencyModel? currency = controller.currencyForOrder(row.order);
    String money(double v) => Constant.amountShow(amount: v.toString(), currency: currency);
    final percent = row.commissionPercent % 1 == 0 ? row.commissionPercent.toStringAsFixed(0) : row.commissionPercent.toStringAsFixed(2);
    final commissionLabel = row.commissionApplied ? "${"Admin commission".tr} ($percent%)" : "Admin commission".tr;
    return DsCard.outlined(
      onTap: () => Get.to(const OrderDetailsScreen(), arguments: {"orderModel": row.order}),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const DsIconWell(icon: Icons.receipt_rounded, tone: DsTone.info, size: 36),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${"Order".tr} ${WalletController.orderLabel(row.order.id)}", style: t.titleSm),
                          if (row.order.createdAt != null) Text(Constant.timestampToDateTime(row.order.createdAt!), style: t.caption),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textMuted),
                  ],
                ),
                const DsGap(DsSpace.xs),
                _line(context, "Order subtotal".tr, money(row.subTotal)),
                _line(
                  context,
                  commissionLabel,
                  row.commissionAmount > 0 ? "-${money(row.commissionAmount)}" : money(0),
                  color: row.commissionAmount > 0 ? c.dangerStrong : null,
                ),
                if (row.taxAmount != 0) _line(context, "Tax".tr, money(row.taxAmount)),
              ],
            ),
          ),
          Container(
            color: c.successSoft,
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.md),
            child: Row(
              children: [
                Icon(Icons.storefront_rounded, size: 18, color: c.successStrong),
                const DsGap(DsSpace.sm),
                Expanded(
                  child: Text(row.storeReceivedFromCredit ? "Store received".tr : "Store receives (estimated)".tr, style: t.labelSm.withColor(c.successStrong)),
                ),
                const DsGap(DsSpace.sm),
                Text(money(row.storeReceived), style: t.titleSm.tabular.withColor(c.successStrong)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- Payouts

class WalletPayoutsTab extends StatelessWidget {
  const WalletPayoutsTab({super.key, required this.controller, required this.isDark});

  final WalletController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = controller.withdrawalList;
      return _RefreshableList(
        controller: controller,
        isDark: isDark,
        header: null,
        grouped: false,
        itemCount: rows.length,
        emptyMessage: "No payout requests yet".tr,
        emptyIcon: Icons.payments_outlined,
        itemBuilder: (context, index) => _payoutCard(context, rows[index]),
      );
    });
  }

  Widget _payoutCard(BuildContext context, WithdrawalModel transactionModel) {
    final c = context.dsColors;
    final t = context.dsText;
    final status = transactionModel.paymentStatus ?? '';
    final method = (transactionModel.withdrawMethod ?? '').isEmpty ? '' : transactionModel.withdrawMethod!.capitalizeString();
    final adminNote = (transactionModel.adminNote ?? '').trim();
    final tone = status == "Success"
        ? DsTone.success
        : status == "Pending"
        ? DsTone.warning
        : DsTone.danger;
    return DsCard.outlined(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconWell("assets/icons/ic_debit.svg", tone),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((transactionModel.note ?? '').isEmpty ? "Withdrawal".tr : transactionModel.note!, style: t.bodyStrong),
                    const DsGap(DsSpace.xxs),
                    Text(transactionModel.paidDate == null ? '' : Constant.timestampToDateTime(transactionModel.paidDate!), style: t.caption),
                  ],
                ),
              ),
              const DsGap(DsSpace.sm),
              Text(
                "-${Constant.amountShow(amount: (transactionModel.amount ?? '').isEmpty ? "0.0" : transactionModel.amount.toString())}",
                style: t.titleSm.tabular.withColor(c.dangerStrong),
              ),
            ],
          ),
          const DsGap(DsSpace.md),
          Wrap(
            spacing: DsSpace.sm,
            runSpacing: DsSpace.xs,
            children: [
              if (status.isNotEmpty) DsStatusChip(label: status, tone: tone, pulse: status == "Pending"),
              if (method.isNotEmpty) DsBadge(label: "($method)", icon: Icons.account_balance_outlined, style: DsBadgeStyle.outline),
            ],
          ),
          if (adminNote.isNotEmpty) ...[
            const DsGap(DsSpace.md),
            Container(
              padding: const EdgeInsets.all(DsSpace.md),
              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sticky_note_2_outlined, size: 16, color: c.textMuted),
                  const DsGap(DsSpace.sm),
                  Expanded(child: Text("${"Admin note".tr}: $adminNote", style: t.bodySm.withColor(c.textSecondary))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/app/Home_screen/order_details_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/wallet_controller.dart';
import 'package:vendor/models/currency_model.dart';
import 'package:vendor/models/wallet_transaction_model.dart';
import 'package:vendor/models/withdrawal_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/widget/my_separator.dart';

/// Pull-to-refresh wrapper whose empty state still scrolls (so it can refresh).
class _RefreshableList extends StatelessWidget {
  const _RefreshableList({required this.controller, required this.isDark, required this.header, required this.itemCount, required this.itemBuilder, required this.emptyMessage});

  final WalletController controller;
  final bool isDark;
  final Widget? header;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppThemeData.primary300,
      onRefresh: controller.refreshAll,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              if (header != null) ...[header!, const SizedBox(height: 10)],
              if (itemCount == 0)
                SizedBox(height: constraints.maxHeight * 0.5, child: Constant.showEmptyView(message: emptyMessage, isDark: isDark))
              else
                Container(
                  decoration: ShapeDecoration(
                    color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: itemCount,
                    itemBuilder: itemBuilder,
                    separatorBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                    ),
                  ),
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
  const _PeriodSummary({required this.controller, required this.isDark, required this.label, required this.value, this.caption});

  final WalletController controller;
  final bool isDark;
  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final periods = {WalletPeriod.today: "Today".tr, WalletPeriod.week: "This week".tr, WalletPeriod.month: "This month".tr};
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: periods.entries.map((entry) {
              final selected = controller.selectedPeriod.value == entry.key;
              return ChoiceChip(
                label: Text(entry.value),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => controller.selectedPeriod.value = entry.key,
                selectedColor: AppThemeData.primary300,
                backgroundColor: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                side: BorderSide.none,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontFamily: AppThemeData.medium,
                  fontWeight: FontWeight.w500,
                  color: selected ? AppThemeData.grey50 : (isDark ? AppThemeData.grey200 : AppThemeData.grey700),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(fontSize: 13, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400, color: isDark ? AppThemeData.grey300 : AppThemeData.grey600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontFamily: AppThemeData.bold, fontWeight: FontWeight.w700, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              style: TextStyle(fontSize: 12, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
            ),
          ],
        ],
      ),
    );
  }
}

TextStyle _titleStyle(bool isDark) => TextStyle(fontSize: 16, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800);

TextStyle _metaStyle(bool isDark) => TextStyle(fontSize: 12, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500, color: isDark ? AppThemeData.grey200 : AppThemeData.grey700);

Widget _iconBox(bool isDark, String asset) {
  return Container(
    decoration: ShapeDecoration(
      shape: RoundedRectangleBorder(
        side: BorderSide(width: 1, color: isDark ? AppThemeData.grey800 : AppThemeData.grey100),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: SvgPicture.asset(asset, height: 16, width: 16)),
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
        itemBuilder: (context, index) => _transactionCard(rows[index]),
      );
    });
  }

  Widget _transactionCard(WalletTransactionModel transactionModel) {
    final hasOrder = (transactionModel.orderId ?? '').isNotEmpty && transactionModel.orderId != 'null';
    final amount = Constant.amountShow(amount: transactionModel.amount.toString(), currency: controller.currencyForTransaction(transactionModel));
    return InkWell(
      onTap: hasOrder
          ? () async {
              await FireStoreUtils.getOrderByOrderId(transactionModel.orderId.toString()).then((value) {
                if (value != null) {
                  Get.to(const OrderDetailsScreen(), arguments: {"orderModel": value});
                }
              });
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            _iconBox(isDark, transactionModel.isTopup == false ? "assets/icons/ic_debit.svg" : "assets/icons/ic_credit.svg"),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(transactionModel.note.toString(), style: _titleStyle(isDark))),
                      Text(
                        transactionModel.isTopup == false ? "-$amount" : amount,
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: AppThemeData.medium,
                          fontWeight: FontWeight.w500,
                          color: transactionModel.isTopup == true ? AppThemeData.success400 : AppThemeData.danger300,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(transactionModel.date == null ? '' : Constant.timestampToDateTime(transactionModel.date!), style: _metaStyle(isDark)),
                      ),
                      if (hasOrder) Text(WalletController.orderLabel(transactionModel.orderId), style: _metaStyle(isDark)),
                      if (controller.isAccountRow(transactionModel))
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: isDark ? AppThemeData.grey800 : AppThemeData.grey100, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            "Account".tr,
                            style: TextStyle(fontSize: 11, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500, color: isDark ? AppThemeData.grey300 : AppThemeData.grey600),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
        header: _PeriodSummary(
          controller: controller,
          isDark: isDark,
          label: "Total commission".tr,
          value: Constant.amountShow(amount: controller.periodCommission.toString(), currency: controller.periodCommissionCurrency),
          caption: "@count completed orders".trParams({'count': periodRows.length.toString()}),
        ),
        itemCount: rows.length,
        emptyMessage: "No completed orders yet".tr,
        itemBuilder: (context, index) => _commissionCard(rows[index]),
      );
    });
  }

  Widget _line(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400, color: isDark ? AppThemeData.grey300 : AppThemeData.grey600),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontFamily: bold ? AppThemeData.semiBold : AppThemeData.medium,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
              color: color ?? (isDark ? AppThemeData.grey100 : AppThemeData.grey800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _commissionCard(OrderCommissionRow row) {
    final CurrencyModel? currency = controller.currencyForOrder(row.order);
    String money(double v) => Constant.amountShow(amount: v.toString(), currency: currency);
    final percent = row.commissionPercent % 1 == 0 ? row.commissionPercent.toStringAsFixed(0) : row.commissionPercent.toStringAsFixed(2);
    final commissionLabel = row.commissionApplied ? "${"Admin commission".tr} ($percent%)" : "Admin commission".tr;
    return InkWell(
      onTap: () => Get.to(const OrderDetailsScreen(), arguments: {"orderModel": row.order}),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text("${"Order".tr} ${WalletController.orderLabel(row.order.id)}", style: _titleStyle(isDark))),
                Text(row.order.createdAt == null ? '' : Constant.timestampToDateTime(row.order.createdAt!), style: _metaStyle(isDark)),
              ],
            ),
            const SizedBox(height: 2),
            _line("Order subtotal".tr, money(row.subTotal)),
            _line(commissionLabel, row.commissionAmount > 0 ? "-${money(row.commissionAmount)}" : money(0), color: row.commissionAmount > 0 ? AppThemeData.danger300 : null),
            if (row.taxAmount != 0) _line("Tax".tr, money(row.taxAmount)),
            _line(row.storeReceivedFromCredit ? "Store received".tr : "Store receives (estimated)".tr, money(row.storeReceived), color: AppThemeData.success400, bold: true),
          ],
        ),
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
        itemCount: rows.length,
        emptyMessage: "No payout requests yet".tr,
        itemBuilder: (context, index) => _payoutCard(rows[index]),
      );
    });
  }

  Widget _payoutCard(WithdrawalModel transactionModel) {
    final status = transactionModel.paymentStatus ?? '';
    final method = (transactionModel.withdrawMethod ?? '').isEmpty ? '' : transactionModel.withdrawMethod!.capitalizeString();
    final adminNote = (transactionModel.adminNote ?? '').trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconBox(isDark, "assets/icons/ic_debit.svg"),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((transactionModel.note ?? '').isEmpty ? "Withdrawal".tr : transactionModel.note!, style: _titleStyle(isDark)),
                          if (method.isNotEmpty)
                            Text(
                              "($method)",
                              style: TextStyle(fontSize: 14, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w600, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      "-${Constant.amountShow(amount: (transactionModel.amount ?? '').isEmpty ? "0.0" : transactionModel.amount.toString())}",
                      style: const TextStyle(fontSize: 16, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500, color: AppThemeData.danger300),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: AppThemeData.semiBold,
                          fontWeight: FontWeight.w600,
                          color: status == "Success"
                              ? AppThemeData.success400
                              : status == "Pending"
                              ? AppThemeData.primary300
                              : AppThemeData.danger300,
                        ),
                      ),
                    ),
                    Text(transactionModel.paidDate == null ? '' : Constant.timestampToDateTime(transactionModel.paidDate!), style: _metaStyle(isDark)),
                  ],
                ),
                if (adminNote.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    "${"Admin note".tr}: $adminNote",
                    style: TextStyle(fontSize: 13, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400, color: isDark ? AppThemeData.grey300 : AppThemeData.grey600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

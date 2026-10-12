import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/company_cash_model.dart';
import 'package:driver/services/company_cash_service.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class DriverCashSettlementScreen extends StatefulWidget {
  const DriverCashSettlementScreen({super.key});

  @override
  State<DriverCashSettlementScreen> createState() => _DriverCashSettlementScreenState();
}

class _DriverCashSettlementScreenState extends State<DriverCashSettlementScreen> {
  final String _driverUid = FireStoreUtils.getCurrentUid();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showSettlementDialog(double outstanding) {
    _amountController.text = outstanding > 0 ? outstanding.toStringAsFixed(2) : '';
    _notesController.clear();

    Get.dialog(
      AlertDialog(
        title: Text('Hand Over Cash'.tr, style: context.dsText.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Submit a cash settlement request to your company owner after handing over cash.'
                    .tr,
                style: context.dsText.bodySm,
              ),
              const DsGap(DsSpace.md),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Settlement Amount'.tr,
                  hintText: '0.00',
                  prefixText: '${Constant.currencyModel?.symbol ?? ''} ',
                  border: const OutlineInputBorder(),
                ),
              ),
              const DsGap(DsSpace.md),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)'.tr,
                  hintText: 'e.g. Handed over at office'.tr,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
              if (amt <= 0) {
                ShowToastDialog.showToast('Please enter a valid amount'.tr);
                return;
              }
              final ownerId = Constant.userModel?.ownerId;
              if (ownerId == null || ownerId.isEmpty) {
                ShowToastDialog.showToast('No company owner linked to your account'.tr);
                return;
              }

              Get.back();
              ShowToastDialog.showLoader('Submitting settlement...'.tr);
              try {
                final success = await CompanyCashService.submitSettlementRequest(
                  ownerId: ownerId,
                  amount: amt,
                  notes: _notesController.text.trim(),
                );
                ShowToastDialog.closeLoader();
                if (success) {
                  ShowToastDialog.showToast('Settlement request submitted'.tr);
                } else {
                  ShowToastDialog.showToast('Failed to submit settlement'.tr);
                }
              } catch (e) {
                ShowToastDialog.closeLoader();
                ShowToastDialog.showToast('Error: $e');
              }
            },
            child: Text('Submit'.tr),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;

    return Scaffold(
      appBar: DsAppBar(
        title: 'Cash Ledger & Settlements'.tr,
      ),
      body: StreamBuilder<List<CompanyCashTransactionModel>>(
        stream: CompanyCashService.streamDriverTransactions(_driverUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final transactions = snapshot.data ?? [];
          final summary = DriverCashSummary.fromTransactions(transactions);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(DsSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Balance Card
                      DsCard(
                        color: c.surface,
                        padding: const EdgeInsets.all(DsSpace.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Outstanding Cash Balance'.tr, style: t.overline),
                            const DsGap(DsSpace.xs),
                            Text(
                              Constant.amountShow(amount: summary.outstandingBalance.toString()),
                              style: t.metric.withColor(summary.outstandingBalance > 0 ? c.danger : c.brand),
                            ),
                            const DsGap(DsSpace.xs),
                            Text(
                              'Cash collected from COD orders to be deposited with Company Owner'.tr,
                              style: t.caption,
                            ),
                            const DsGap(DsSpace.lg),
                            Row(
                              children: [
                                Expanded(
                                  child: _metricBox(
                                    label: 'Total Collected'.tr,
                                    value: Constant.amountShow(amount: summary.totalCollected.toString()),
                                    color: c.textSecondary,
                                  ),
                                ),
                                const DsGap(DsSpace.md),
                                Expanded(
                                  child: _metricBox(
                                    label: 'Total Settled'.tr,
                                    value: Constant.amountShow(amount: summary.totalSettled.toString()),
                                    color: c.success,
                                  ),
                                ),
                              ],
                            ),
                            if (summary.pendingSettlement > 0) ...[
                              const DsGap(DsSpace.md),
                              DsInlineAlert(
                                tone: DsTone.warning,
                                icon: Icons.hourglass_top_rounded,
                                message:
                                    '${'Pending Owner Confirmation:'.tr} ${Constant.amountShow(amount: summary.pendingSettlement.toString())}',
                              ),
                            ],
                            const DsGap(DsSpace.lg),
                            DsButton.primary(
                              label: 'Hand Over Cash / Request Settlement'.tr,
                              icon: Icons.payments_outlined,
                              size: DsButtonSize.lg,
                              expand: true,
                              onPressed: () => _showSettlementDialog(summary.outstandingBalance),
                            ),
                          ],
                        ),
                      ),
                      const DsGap(DsSpace.xl),
                      Text('Transaction History'.tr, style: t.titleSm.w700),
                      const DsGap(DsSpace.sm),
                    ],
                  ),
                ),
              ),
              if (transactions.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text('No cash transactions recorded yet.'.tr, style: t.bodySecondary),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tx = transactions[index];
                        return _buildTransactionCard(tx);
                      },
                      childCount: transactions.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: DsGap(DsSpace.xxl),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _metricBox({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(DsSpace.md),
      decoration: BoxDecoration(
        color: context.dsColors.surfaceAlt,
        borderRadius: DsRadius.brMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.dsText.caption),
          const DsGap(DsSpace.xxs),
          Text(value, style: context.dsText.titleSm.w700),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(CompanyCashTransactionModel tx) {
    final c = context.dsColors;
    final t = context.dsText;

    final isCollection = tx.type == CompanyCashTransactionType.collection;
    final isSettlement = tx.type == CompanyCashTransactionType.settlement;

    final dateStr = tx.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(tx.createdAt!.toDate())
        : '-';

    IconData icon;
    DsTone tone;
    String typeLabel;

    if (isCollection) {
      icon = Icons.call_received_rounded;
      tone = DsTone.warning;
      typeLabel = 'COD Collection'.tr;
    } else if (isSettlement) {
      icon = Icons.call_made_rounded;
      tone = tx.status == CompanyCashTransactionStatus.confirmed
          ? DsTone.success
          : (tx.status == CompanyCashTransactionStatus.rejected ? DsTone.danger : DsTone.neutral);
      typeLabel = 'Cash Settlement'.tr;
    } else {
      icon = Icons.tune_rounded;
      tone = DsTone.info;
      typeLabel = 'Owner Adjustment'.tr;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.md),
      child: DsCard.outlined(
        padding: const EdgeInsets.all(DsSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DsIconWell(
                  icon: icon,
                  tone: tone,
                  size: 36,
                  circle: true,
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(typeLabel, style: t.titleSm.w600),
                      Text(dateStr, style: t.caption),
                    ],
                  ),
                ),
                Text(
                  Constant.amountShow(amount: (tx.amount ?? 0).toString()),
                  style: t.title.withColor(isCollection ? c.danger : c.success),
                ),
              ],
            ),
            if (tx.orderId != null && tx.orderId!.isNotEmpty) ...[
              const DsGap(DsSpace.sm),
              Text('${'Order #'.tr}${tx.orderId}', style: t.bodySm.w600),
            ],
            if (tx.notes != null && tx.notes!.isNotEmpty) ...[
              const DsGap(DsSpace.xxs),
              Text(tx.notes!, style: t.caption),
            ],
            const DsGap(DsSpace.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DsStatusChip(
                  label: (tx.status ?? 'confirmed').toUpperCase().tr,
                  status: tx.status == CompanyCashTransactionStatus.confirmed ? Constant.orderCompleted : tx.status,
                ),
                if (tx.rejectionReason != null && tx.rejectionReason!.isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: DsSpace.sm),
                      child: Text(
                        'Reason: ${tx.rejectionReason}',
                        style: t.caption.withColor(c.danger),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

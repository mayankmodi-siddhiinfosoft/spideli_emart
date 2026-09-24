import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/region_service.dart';
import 'package:driver/utils/rental_proposal_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Customer price proposal on a rental booking (spec 4.9). Hidden when the
/// order has no `priceProposal`. While "pending" the driver/owner can Accept,
/// Reject or Counter; [onChanged] is called after a successful response.
class RentalProposalCard extends StatelessWidget {
  final RentalOrderModel order;

  /// Kept for call-site compatibility; colors now come from `context.dsColors`.
  final bool isDark;
  final VoidCallback? onChanged;

  const RentalProposalCard({super.key, required this.order, required this.isDark, this.onChanged});

  String _money(num? value) => value == null ? '--' : Constant.amountShow(currency: RegionService.currencyForRecord(order.regionId), amount: value.toString());

  String _statusLabel(String? status) {
    switch (status) {
      case 'pending':
        return "Awaiting your answer".tr;
      case 'accepted':
        return "Accepted".tr;
      case 'rejected':
        return "Rejected".tr;
      case 'countered':
        return "Counter-offer sent - waiting for the customer".tr;
      default:
        return status ?? '';
    }
  }

  DsTone _statusTone(String? status) {
    switch (status) {
      case 'accepted':
        return DsTone.success;
      case 'rejected':
        return DsTone.danger;
      case 'countered':
        return DsTone.info;
      default:
        return DsTone.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (order.priceProposal == null) return const SizedBox();
    final c = context.dsColors;
    final t = context.dsText;
    final status = order.proposalStatus;
    return DsCard.tinted(
      tone: DsTone.brand,
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer_outlined, size: 18, color: c.brandStrong),
              const DsGap(DsSpace.sm),
              Expanded(child: Text("Customer price proposal".tr, style: t.titleSm)),
              Text(_money(order.proposedAmount), style: t.titleSm.withColor(c.brandStrong).w700.tabular),
            ],
          ),
          const DsGap(DsSpace.xs),
          Text(
            "${'Listed price'.tr}: ${(order.listedPrice ?? order.subTotal) == null ? '--' : Constant.amountShow(currency: RegionService.currencyForRecord(order.regionId), amount: order.listedPrice ?? order.subTotal)}",
            style: t.bodySm,
          ),
          if (order.proposalMessage != null) ...[
            const DsGap(DsSpace.xs),
            Text("\"${order.proposalMessage!}\"", style: t.body.copyWith(fontStyle: FontStyle.italic)),
          ],
          if (status == 'countered' && order.counterAmount != null) ...[
            const DsGap(DsSpace.xs),
            Text("${'Your counter-offer'.tr}: ${_money(order.counterAmount)}", style: t.bodyStrong),
          ],
          const DsGap(DsSpace.sm),
          DsBadge(label: _statusLabel(status), tone: _statusTone(status), small: true),
          if (status == 'pending' && order.id != null) ...[
            const DsGap(DsSpace.md),
            Row(
              children: [
                Expanded(
                  child: DsButton.secondary(
                    label: "Reject".tr,
                    size: DsButtonSize.sm,
                    expand: true,
                    onPressed: () => _run(() => RentalProposalService.reject(order.id!), "Proposal rejected".tr),
                  ),
                ),
                const DsGap(DsSpace.sm),
                Expanded(
                  child: DsButton.tonal(
                    label: "Counter".tr,
                    size: DsButtonSize.sm,
                    expand: true,
                    color: c.warningStrong,
                    onPressed: () => _counter(),
                  ),
                ),
                const DsGap(DsSpace.sm),
                Expanded(
                  child: DsButton.success(
                    label: "Accept".tr,
                    size: DsButtonSize.sm,
                    expand: true,
                    onPressed: () => _run(() => RentalProposalService.accept(order.id!), "Proposal accepted".tr),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _run(Future<String?> Function() action, String success) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final error = await action();
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast(error == null ? success : error.tr);
    onChanged?.call();
  }

  Future<void> _counter() async {
    final amountController = TextEditingController();
    final messageController = TextEditingController();
    final result = await Get.dialog<bool>(
      DsDialog(
        title: "Counter-offer".tr,
        icon: Icons.price_change_outlined,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsTextField(
              label: 'Amount'.tr,
              controller: amountController,
              hint: 'Enter your price'.tr,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            ),
            DsTextField(
              label: 'Message (optional)'.tr,
              controller: messageController,
              hint: 'Add a message for the customer'.tr,
              maxLines: 2,
              bottomSpacing: 0,
            ),
          ],
        ),
        secondaryLabel: "Cancel".tr,
        onSecondary: () => Get.back(result: false),
        primaryLabel: "Send".tr,
        onPrimary: () {
          final value = num.tryParse(amountController.text.trim());
          if (value == null || value <= 0) {
            ShowToastDialog.showToast("Please enter a valid amount".tr);
            return;
          }
          Get.back(result: true);
        },
      ),
    );
    if (result == true) {
      final amount = num.parse(amountController.text.trim());
      await _run(() => RentalProposalService.counter(order.id!, amount: amount, message: messageController.text), "Counter-offer sent".tr);
    }
  }
}

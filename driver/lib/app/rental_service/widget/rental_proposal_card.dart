import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/round_button_fill.dart';
import 'package:driver/themes/text_field_widget.dart';
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

  @override
  Widget build(BuildContext context) {
    if (order.priceProposal == null) return const SizedBox();
    final status = order.proposalStatus;
    final textColor = isDark ? AppThemeData.grey50 : AppThemeData.grey900;
    final subColor = isDark ? AppThemeData.grey300 : AppThemeData.grey600;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppThemeData.greyDark100 : AppThemeData.primary50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeData.primary300.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer_outlined, size: 18, color: AppThemeData.primary300),
              const SizedBox(width: 6),
              Expanded(child: Text("Customer price proposal".tr, style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 15, color: textColor))),
              Text(_money(order.proposedAmount), style: TextStyle(fontFamily: AppThemeData.bold, fontSize: 16, color: AppThemeData.primary300)),
            ],
          ),
          const SizedBox(height: 4),
          Text("${'Listed price'.tr}: ${(order.listedPrice ?? order.subTotal) == null ? '--' : Constant.amountShow(currency: RegionService.currencyForRecord(order.regionId), amount: order.listedPrice ?? order.subTotal)}",
              style: TextStyle(fontFamily: AppThemeData.regular, fontSize: 13, color: subColor)),
          if (order.proposalMessage != null) ...[
            const SizedBox(height: 4),
            Text("\"${order.proposalMessage!}\"", style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 13, fontStyle: FontStyle.italic, color: textColor)),
          ],
          if (status == 'countered' && order.counterAmount != null) ...[
            const SizedBox(height: 4),
            Text("${'Your counter-offer'.tr}: ${_money(order.counterAmount)}", style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 13, color: textColor)),
          ],
          const SizedBox(height: 4),
          Text(_statusLabel(status), style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 13, color: status == 'rejected' ? AppThemeData.danger300 : subColor)),
          if (status == 'pending' && order.id != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: RoundedButtonFill(
                    title: "Reject".tr,
                    height: 4.5,
                    fontSizes: 13,
                    borderRadius: 10,
                    color: isDark ? AppThemeData.greyDark300 : AppThemeData.grey300,
                    textColor: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                    onPress: () => _run(() => RentalProposalService.reject(order.id!), "Proposal rejected".tr),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RoundedButtonFill(
                    title: "Counter".tr,
                    height: 4.5,
                    fontSizes: 13,
                    borderRadius: 10,
                    color: AppThemeData.warning300,
                    textColor: AppThemeData.grey900,
                    onPress: () => _counter(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RoundedButtonFill(
                    title: "Accept".tr,
                    height: 4.5,
                    fontSizes: 13,
                    borderRadius: 10,
                    color: AppThemeData.success400,
                    textColor: AppThemeData.grey50,
                    onPress: () => _run(() => RentalProposalService.accept(order.id!), "Proposal accepted".tr),
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
      AlertDialog(
        backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
        title: Text("Counter-offer".tr, style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFieldWidget(
                title: 'Amount'.tr,
                controller: amountController,
                hintText: 'Enter your price'.tr,
                textInputType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              ),
              TextFieldWidget(
                title: 'Message (optional)'.tr,
                controller: messageController,
                hintText: 'Add a message for the customer'.tr,
                maxLine: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text("Cancel".tr)),
          TextButton(
            onPressed: () {
              final value = num.tryParse(amountController.text.trim());
              if (value == null || value <= 0) {
                ShowToastDialog.showToast("Please enter a valid amount".tr);
                return;
              }
              Get.back(result: true);
            },
            child: Text("Send".tr),
          ),
        ],
      ),
    );
    if (result == true) {
      final amount = num.parse(amountController.text.trim());
      await _run(() => RentalProposalService.counter(order.id!, amount: amount, message: messageController.text), "Counter-offer sent".tr);
    }
  }
}

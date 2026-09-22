import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/models/rental_order_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/themes/text_field_widget.dart';
import 'package:customer/utils/rental_proposal_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Amount + optional message entered in [showProposePriceSheet].
typedef PriceProposalInput = ({num amount, String message});

/// "Propose my price" (spec 4.9): asks for an amount and an optional message.
/// [listedPrice] is shown for reference. Returns null when dismissed.
Future<PriceProposalInput?> showProposePriceSheet({required String listedPrice}) {
  final isDark = Get.find<ThemeController>().isDark.value;
  return Get.bottomSheet<PriceProposalInput>(
    _ProposePriceBody(listedPrice: listedPrice),
    isScrollControlled: true,
    backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
  );
}

class _ProposePriceBody extends StatefulWidget {
  final String listedPrice;

  const _ProposePriceBody({required this.listedPrice});

  @override
  State<_ProposePriceBody> createState() => _ProposePriceBodyState();
}

class _ProposePriceBodyState extends State<_ProposePriceBody> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _message = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _message.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = num.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      ShowToastDialog.showToast("Please enter a valid amount".tr);
      return;
    }
    Get.back(result: (amount: amount, message: _message.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Get.find<ThemeController>().isDark.value;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Propose my price".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
              const SizedBox(height: 4),
              Text(
                "${'Listed price'.tr}: ${widget.listedPrice}. ${'The car owner can accept, reject or counter your proposal.'.tr}",
                style: AppThemeData.regularTextStyle(fontSize: 13, color: isDark ? AppThemeData.grey400 : AppThemeData.grey600),
              ),
              const SizedBox(height: 12),
              TextFieldWidget(
                title: "Your price".tr,
                hintText: "Amount".tr,
                controller: _amount,
                textInputType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              ),
              TextFieldWidget(title: "Message (optional)".tr, hintText: "Add a note for the car owner".tr, controller: _message, maxLine: 3),
              const SizedBox(height: 12),
              RoundedButtonFill(title: "Send proposal".tr, color: AppThemeData.primary300, textColor: AppThemeData.grey900, onPress: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

/// The customer's view of a booking's price proposal (spec 4.9): status, and
/// the actions open to the customer - accept / reject a counter, or after a
/// rejection keep the listed price / propose again. Hidden when the booking has
/// no proposal. Writes go through [RentalProposalService] (guarded).
class RentalProposalCard extends StatelessWidget {
  final RentalOrderModel order;
  final bool isDark;
  final CurrencyModel? currency;

  const RentalProposalCard({super.key, required this.order, required this.isDark, this.currency});

  String _money(num? value) => value == null ? '--' : Constant.amountShow(amount: value.toString(), currency: currency);

  Future<void> _run(Future<String?> Function() action, String success) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final error = await action();
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast(error ?? success);
  }

  @override
  Widget build(BuildContext context) {
    if (order.priceProposal == null || order.id == null) return const SizedBox.shrink();
    final status = order.proposalStatus;
    final open = order.status == Constant.orderPlaced;
    final text = isDark ? AppThemeData.greyDark900 : AppThemeData.grey900;
    final sub = isDark ? AppThemeData.greyDark500 : AppThemeData.grey600;
    final listed = num.tryParse(order.listedPrice ?? '') ?? (status == 'accepted' ? null : num.tryParse(order.subTotal ?? ''));

    String statusText;
    Color statusColor;
    switch (status) {
      case 'pending':
        statusText = "Waiting for the car owner's answer".tr;
        statusColor = AppThemeData.info500;
        break;
      case 'countered':
        statusText = "The car owner sent a counter-offer".tr;
        statusColor = AppThemeData.warning400;
        break;
      case 'accepted':
        statusText = "Price agreed".tr;
        statusColor = AppThemeData.success400;
        break;
      case 'rejected':
        statusText = "Your proposal was declined".tr;
        statusColor = AppThemeData.danger300;
        break;
      default:
        statusText = status ?? '';
        statusColor = sub;
    }

    Widget row(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppThemeData.regularTextStyle(fontSize: 14, color: sub))),
          Text(value, style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: color ?? text)),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppThemeData.greyDark50 : AppThemeData.primary50,
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
              Expanded(child: Text("Price proposal".tr, style: AppThemeData.boldTextStyle(fontSize: 16, color: text))),
            ],
          ),
          const SizedBox(height: 4),
          Text(statusText, style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: statusColor)),
          const SizedBox(height: 6),
          if (listed != null) row("Listed price".tr, _money(listed)),
          row("Your proposal".tr, _money(order.proposedAmount)),
          if (order.proposalMessage != null) row("Your message".tr, order.proposalMessage!),
          if (status == 'countered' || (status == 'rejected' && order.counterAmount != null)) row("Counter-offer".tr, _money(order.counterAmount), color: AppThemeData.warning400),
          if (status == 'accepted') row("Agreed price".tr, _money(num.tryParse(order.subTotal ?? '')), color: AppThemeData.success400),
          if (status == 'accepted') Text("You will pay the agreed price.".tr, style: AppThemeData.regularTextStyle(fontSize: 12, color: sub)),
          if (status == 'countered' && open) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: RoundedButtonFill(
                    title: "Reject".tr,
                    height: 5,
                    borderRadius: 10,
                    color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                    textColor: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                    onPress: () => _run(() => RentalProposalService.rejectCounter(order.id!), "Counter-offer rejected".tr),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RoundedButtonFill(
                    title: "${'Accept'.tr} ${_money(order.counterAmount)}",
                    height: 5,
                    borderRadius: 10,
                    color: AppThemeData.primary300,
                    textColor: AppThemeData.grey900,
                    onPress: () => _run(() => RentalProposalService.acceptCounter(order.id!), "Counter-offer accepted".tr),
                  ),
                ),
              ],
            ),
          ],
          if (status == 'rejected' && open) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: RoundedButtonFill(
                    title: "Book at listed price".tr,
                    height: 5,
                    borderRadius: 10,
                    color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                    textColor: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                    onPress: () => _run(() => RentalProposalService.keepListedPrice(order.id!), "Your booking stays open at the listed price".tr),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RoundedButtonFill(
                    title: "Propose again".tr,
                    height: 5,
                    borderRadius: 10,
                    color: AppThemeData.primary300,
                    textColor: AppThemeData.grey900,
                    onPress: () async {
                      final input = await showProposePriceSheet(listedPrice: _money(listed));
                      if (input == null) return;
                      await _run(() => RentalProposalService.proposeAgain(order.id!, amount: input.amount, message: input.message), "Proposal sent".tr);
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One-line proposal status for booking lists.
class RentalProposalStatusLine extends StatelessWidget {
  final RentalOrderModel order;

  const RentalProposalStatusLine({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order.proposalStatus;
    if (status == null) return const SizedBox.shrink();
    final label = switch (status) {
      'pending' => "Price proposal: waiting for the owner".tr,
      'countered' => "Price proposal: counter-offer received".tr,
      'accepted' => "Price proposal: agreed".tr,
      'rejected' => "Price proposal: declined".tr,
      _ => status,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.local_offer_outlined, size: 16, color: AppThemeData.primary300),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: AppThemeData.semiBoldTextStyle(fontSize: 13, color: AppThemeData.primary300))),
        ],
      ),
    );
  }
}

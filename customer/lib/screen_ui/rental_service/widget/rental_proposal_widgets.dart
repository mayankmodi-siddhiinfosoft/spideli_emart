import 'package:customer/constant/constant.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/models/rental_order_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/rental_proposal_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Amount + optional message entered in [showProposePriceSheet].
typedef PriceProposalInput = ({num amount, String message});

/// "Propose my price" (spec 4.9): asks for an amount and an optional message.
/// [listedPrice] is shown for reference. Returns null when dismissed.
Future<PriceProposalInput?> showProposePriceSheet({required String listedPrice}) {
  return Get.bottomSheet<PriceProposalInput>(
    _ProposePriceBody(listedPrice: listedPrice),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: DsColors.resolve(Get.isDarkMode).scrim,
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
    return DsSheet(
      title: "Propose my price".tr,
      subtitle: "${'Listed price'.tr}: ${widget.listedPrice}. ${'The car owner can accept, reject or counter your proposal.'.tr}",
      actions: DsButton.primary(
        label: "Send proposal".tr,
        icon: Icons.local_offer_outlined,
        size: DsButtonSize.lg,
        expand: true,
        onPressed: _submit,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsTextField(
              label: "Your price".tr,
              hint: "Amount".tr,
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              prefixIcon: Icons.payments_outlined,
              autofocus: true,
            ),
            DsTextField(
              label: "Message (optional)".tr,
              hint: "Add a note for the car owner".tr,
              controller: _message,
              maxLines: 3,
              minLines: 2,
              bottomSpacing: 0,
            ),
          ],
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
  final CurrencyModel? currency;

  const RentalProposalCard({super.key, required this.order, this.currency});

  String _money(num? value) => value == null ? '--' : Constant.amountShow(amount: value.toString(), currency: currency);

  Future<void> _run(Future<String?> Function() action, String success) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final error = await action();
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast(error ?? success);
  }

  /// Tone + label for each negotiation state.
  static (String, DsTone) _statusOf(String? status) => switch (status) {
    'pending' => ("Waiting for the car owner's answer".tr, DsTone.info),
    'countered' => ("The car owner sent a counter-offer".tr, DsTone.warning),
    'accepted' => ("Price agreed".tr, DsTone.success),
    'rejected' => ("Your proposal was declined".tr, DsTone.danger),
    _ => (status ?? '', DsTone.neutral),
  };

  @override
  Widget build(BuildContext context) {
    if (order.priceProposal == null || order.id == null) return const SizedBox.shrink();
    final c = context.dsColors;
    final t = context.dsText;
    final status = order.proposalStatus;
    final open = order.status == Constant.orderPlaced;
    final listed = num.tryParse(order.listedPrice ?? '') ?? (status == 'accepted' ? null : num.tryParse(order.subTotal ?? ''));
    final (statusText, statusTone) = _statusOf(status);

    Widget row(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: t.bodySecondary)),
          const DsGap(DsSpace.md),
          Flexible(child: Text(value, style: t.bodyStrong.tabular.withColor(color ?? c.textPrimary), textAlign: TextAlign.end)),
        ],
      ),
    );

    return DsCard.tinted(
      tone: statusTone == DsTone.neutral ? DsTone.brand : statusTone,
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer_outlined, size: 18, color: c.brandStrong),
              const DsGap(DsSpace.sm),
              Expanded(child: Text("Price proposal".tr, style: t.titleSm)),
              DsStatusChip(label: statusText, tone: statusTone == DsTone.neutral ? DsTone.brand : statusTone, pulse: status == 'pending'),
            ],
          ),
          const DsGap(DsSpace.md),
          if (listed != null) row("Listed price".tr, _money(listed)),
          row("Your proposal".tr, _money(order.proposedAmount)),
          if (order.proposalMessage != null) row("Your message".tr, order.proposalMessage!),
          if (status == 'countered' || (status == 'rejected' && order.counterAmount != null)) row("Counter-offer".tr, _money(order.counterAmount), color: c.warningStrong),
          if (status == 'accepted') row("Agreed price".tr, _money(num.tryParse(order.subTotal ?? '')), color: c.successStrong),
          if (status == 'accepted') Text("You will pay the agreed price.".tr, style: t.caption),
          if (status == 'countered' && open) ...[
            const DsGap(DsSpace.lg),
            Row(
              children: [
                Expanded(
                  child: DsButton.secondary(
                    label: "Reject".tr,
                    expand: true,
                    onPressed: () => _run(() => RentalProposalService.rejectCounter(order.id!), "Counter-offer rejected".tr),
                  ),
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: DsButton.primary(
                    label: "${'Accept'.tr} ${_money(order.counterAmount)}",
                    expand: true,
                    onPressed: () => _run(() => RentalProposalService.acceptCounter(order.id!), "Counter-offer accepted".tr),
                  ),
                ),
              ],
            ),
          ],
          if (status == 'rejected' && open) ...[
            const DsGap(DsSpace.lg),
            Row(
              children: [
                Expanded(
                  child: DsButton.secondary(
                    label: "Book at listed price".tr,
                    expand: true,
                    onPressed: () => _run(() => RentalProposalService.keepListedPrice(order.id!), "Your booking stays open at the listed price".tr),
                  ),
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: DsButton.primary(
                    label: "Propose again".tr,
                    expand: true,
                    onPressed: () async {
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
    final (_, tone) = RentalProposalCard._statusOf(status);
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: DsBadge(label: label, tone: tone == DsTone.neutral ? DsTone.brand : tone, icon: Icons.local_offer_outlined),
    );
  }
}

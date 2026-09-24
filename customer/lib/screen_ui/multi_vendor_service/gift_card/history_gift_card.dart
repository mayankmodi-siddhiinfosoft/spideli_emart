import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/history_gift_card_controller.dart';
import 'package:customer/models/gift_cards_order_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Archetype G — purchased gift vouchers. Each row is a voucher: a gradient
/// value plate on the left, the code and masked pin as tabular digits, and a
/// share / redeemed footer.
class HistoryGiftCard extends StatelessWidget {
  const HistoryGiftCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: HistoryGiftCardController(),
      builder: (controller) {
        final bool isLoading = controller.isLoading.value;
        final List<GiftCardsOrderModel> vouchers = controller.giftCardsOrderList.toList();

        return DsScaffold(
          maxContentWidth: DsLayout.contentMax,
          appBar: DsAppBar(title: "History".tr),
          body: isLoading
              ? const SingleChildScrollView(child: DsSkeletonList(itemCount: 4, leading: false))
              : vouchers.isEmpty
              ? DsEmptyState(icon: Icons.card_giftcard_rounded, title: "Purchased Gift card not found".tr)
              : ListView.builder(
                  itemCount: vouchers.length,
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                  itemBuilder: (context, index) {
                    GiftCardsOrderModel giftCardOrderModel = vouchers[index];
                    return DsFadeSlideIn(
                      index: index,
                      child: _VoucherCard(giftCardOrderModel: giftCardOrderModel, index: index, controller: controller),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _VoucherCard extends StatelessWidget {
  final GiftCardsOrderModel giftCardOrderModel;
  final int index;
  final HistoryGiftCardController controller;

  const _VoucherCard({required this.giftCardOrderModel, required this.index, required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    final bool redeemed = giftCardOrderModel.redeem == true;
    final bool pinVisible = giftCardOrderModel.isPasswordShow == true;

    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(gradient: DsGradients.brand(context)),
            padding: const EdgeInsets.all(DsSpace.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.card_giftcard_rounded, color: Colors.white),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Text(
                    giftCardOrderModel.giftTitle.toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSm.withColor(Colors.white),
                  ),
                ),
                const DsGap(DsSpace.md),
                Text(
                  Constant.amountShow(amount: giftCardOrderModel.price.toString(), currency: RegionService.customerCurrency),
                  style: t.title.tabular.withColor(Colors.white),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DsSpace.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text("Gift Code".tr, style: t.bodySecondary)),
                    const DsGap(DsSpace.md),
                    Flexible(
                      child: Text(
                        giftCardOrderModel.giftCode.toString().replaceAllMapped(RegExp(r".{4}"), (match) => "${match.group(0)} "),
                        textAlign: TextAlign.end,
                        style: t.titleSm.tabular,
                      ),
                    ),
                  ],
                ),
                const DsGap(DsSpace.sm),
                Row(
                  children: [
                    Expanded(child: Text("Gift Pin".tr, style: t.bodySecondary)),
                    const DsGap(DsSpace.md),
                    Text(pinVisible ? giftCardOrderModel.giftPin.toString() : "****", style: t.titleSm.tabular),
                    const DsGap(DsSpace.xs),
                    DsIconButton(
                      icon: pinVisible ? Icons.visibility_off : Icons.remove_red_eye,
                      semanticLabel: pinVisible ? 'Hide password'.tr : 'Show password'.tr,
                      size: 36,
                      onPressed: () {
                        controller.updateList(index);
                        controller.update();
                      },
                    ),
                  ],
                ),
                const DsDivider(spacing: DsSpace.md),
                Row(
                  children: [
                    DsButton.tonal(
                      label: 'Share'.tr,
                      trailingIcon: Icons.share,
                      size: DsButtonSize.sm,
                      onPressed: () {
                        controller.share(
                          giftCardOrderModel.giftCode.toString(),
                          giftCardOrderModel.giftPin.toString(),
                          giftCardOrderModel.message.toString(),
                          giftCardOrderModel.price.toString(),
                          giftCardOrderModel.expireDate!,
                        );
                      },
                    ),
                    const Expanded(child: SizedBox()),
                    DsBadge(
                      label: redeemed ? "Redeemed".tr : "Not Redeem".tr,
                      tone: redeemed ? DsTone.success : DsTone.danger,
                      icon: redeemed ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

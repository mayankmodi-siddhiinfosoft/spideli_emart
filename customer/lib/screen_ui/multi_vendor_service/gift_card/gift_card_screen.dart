import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/gift_card_controller.dart';
import 'package:customer/models/gift_cards_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/gift_card/redeem_gift_card_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/gift_card/select_gift_payment_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../themes/show_toast_dialog.dart';
import 'history_gift_card.dart';

/// Archetype G — gift cards. The card art is the hero (a peeking carousel),
/// the amount is entered as a big tabular figure with quick-pick chips, and
/// the personal message sits in its own block.
class GiftCardScreen extends StatelessWidget {
  const GiftCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: GiftCardController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final bool isLoading = controller.isLoading.value;
        final List<GiftCardsModel> cards = controller.giftCardList;

        return DsScaffold(
          maxContentWidth: DsLayout.contentMax,
          appBar: DsAppBar(
            title: "Customize Gift Card".tr,
            actions: [
              DsIconButton(
                semanticLabel: "History".tr,
                child: SvgPicture.asset("assets/icons/ic_history.svg", width: 20, height: 20),
                onPressed: () {
                  Get.to(const HistoryGiftCard());
                },
              ),
              DsIconButton(
                semanticLabel: "Redeem".tr,
                child: SvgPicture.asset("assets/icons/ic_redeem.svg", width: 20, height: 20),
                onPressed: () {
                  Get.to(const RedeemGiftCardScreen());
                },
              ),
              const DsGap(DsSpace.sm),
            ],
          ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Continue".tr,
              size: DsButtonSize.lg,
              expand: true,
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: () async {
                if (controller.amountController.value.text.isNotEmpty) {
                  if (Constant.userModel == null) {
                    ShowToastDialog.showToast("Please log in to the application. You are not logged in.".tr);
                  } else {
                    giftCardBottomSheet(context, controller);
                  }
                } else {
                  ShowToastDialog.showToast("Please enter Amount".tr);
                }
              },
            ),
          ),
          body: isLoading
              ? const SingleChildScrollView(child: DsSkeletonDetail(mediaHeight: 180))
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: DsSpace.xxxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: DsFadeSlideIn.stagger([
                      SizedBox(
                        height: 190,
                        child: PageView.builder(
                          itemCount: cards.length,
                          onPageChanged: (value) {
                            controller.selectedPageIndex.value = value;
                            controller.selectedGiftCard.value = controller.giftCardList[controller.selectedPageIndex.value];

                            controller.messageController.value.text = controller.giftCardList[controller.selectedPageIndex.value].message.toString();
                          },
                          scrollDirection: Axis.horizontal,
                          controller: controller.pageController,
                          itemBuilder: (context, index) {
                            GiftCardsModel giftCardModel = cards[index];
                            return DsPressable(
                              onTap: () {
                                controller.selectedGiftCard.value = giftCardModel;
                                controller.messageController.value.text = controller.selectedGiftCard.value.message.toString();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                                child: Container(
                                  decoration: BoxDecoration(borderRadius: DsRadius.brLg, boxShadow: DsShadows.md(context)),
                                  child: DsImage(url: giftCardModel.image.toString(), radius: DsRadius.lg, errorIcon: Icons.card_giftcard_rounded),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const DsGap(DsSpace.lg),
                            DsTextField(
                              label: 'Choose an amount'.tr,
                              controller: controller.amountController.value,
                              hint: 'Enter gift card amount'.tr,
                              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                              textInputAction: TextInputAction.done,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                              bottomSpacing: DsSpace.md,
                              prefix: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: 14),
                                child: Text((RegionService.customerCurrency ?? Constant.currencyModel!).symbol.tr, style: t.titleSm.tabular),
                              ),
                              onChanged: (value) {
                                controller.selectedAmount.value = value;
                              },
                            ),
                            SizedBox(
                              height: 44,
                              child: ListView.builder(
                                itemCount: controller.amountList.length,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                scrollDirection: Axis.horizontal,
                                itemBuilder: (context, index) {
                                  // The chip reads `selectedAmount` lazily, so it
                                  // needs its own observer.
                                  return Obx(() {
                                    final bool selected = controller.selectedAmount == controller.amountList[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(right: DsSpace.sm),
                                      child: DsPressable(
                                        onTap: () {
                                          controller.selectedAmount.value = controller.amountList[index];
                                          controller.amountController.value.text = controller.amountList[index];
                                        },
                                        child: AnimatedContainer(
                                          duration: DsMotion.of(context, DsMotion.fast),
                                          alignment: Alignment.center,
                                          padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                                          decoration: BoxDecoration(
                                            color: selected ? c.brandSoft : c.surface,
                                            borderRadius: DsRadius.brPill,
                                            border: Border.all(color: selected ? c.brand : c.border),
                                          ),
                                          child: Text(
                                            Constant.amountShow(amount: controller.amountList[index], currency: RegionService.customerCurrency),
                                            style: t.label.tabular.withColor(selected ? c.brandStrong : c.textSecondary),
                                          ),
                                        ),
                                      ),
                                    );
                                  });
                                },
                              ),
                            ),
                            const DsGap(DsSpace.xxl),
                            DsTextField(
                              label: 'Add Message (Optional)'.tr,
                              controller: controller.messageController.value,
                              hint: 'Add message here....'.tr,
                              maxLines: 6,
                              bottomSpacing: 0,
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
        );
      },
    );
  }

  Future giftCardBottomSheet(BuildContext context, GiftCardController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: DsRadius.sheetTop),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (context) => StatefulBuilder(
        builder: (context1, setState) {
          final c = context.dsColors;
          final t = context.dsText;
          return Obx(
            () => DsSheet(
              title: "Bill Details".tr,
              showClose: true,
              actions: DsButton.primary(
                label: "${'Pay'.tr} ${Constant.amountShow(amount: controller.amountController.value.text, currency: RegionService.customerCurrency)}",
                size: DsButtonSize.lg,
                expand: true,
                onPressed: () async {
                  Get.off(const SelectGiftPaymentScreen());
                },
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DsImage(url: controller.selectedGiftCard.value.image.toString(), height: 150, radius: DsRadius.lg, errorIcon: Icons.card_giftcard_rounded),
                  const DsGap(DsSpace.lg),
                  DsInlineAlert(
                    tone: DsTone.info,
                    icon: Icons.card_giftcard_rounded,
                    message: 'Complete payment and share this e-gift card with loved ones using any app'.tr,
                  ),
                  const DsGap(DsSpace.lg),
                  DsCard.outlined(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text("Sub Total".tr, style: t.bodySecondary)),
                            Text(Constant.amountShow(amount: controller.amountController.value.text, currency: RegionService.customerCurrency), style: t.bodyStrong.tabular),
                          ],
                        ),
                        const DsDivider(spacing: DsSpace.md),
                        Row(
                          children: [
                            Expanded(child: Text("Grand Total".tr, style: t.titleSm)),
                            Text(
                              Constant.amountShow(amount: controller.amountController.value.text, currency: RegionService.customerCurrency),
                              style: t.title.tabular.withColor(c.brandStrong),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.lg),
                  Center(
                    child: Text(
                      "${'Gift Card expire'.tr} ${controller.selectedGiftCard.value.expiryDay} ${'days after purchase'.tr}".tr,
                      textAlign: TextAlign.center,
                      style: t.bodySm,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

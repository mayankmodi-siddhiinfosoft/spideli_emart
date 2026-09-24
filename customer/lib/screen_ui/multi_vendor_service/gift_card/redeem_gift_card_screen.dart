import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/dash_board_controller.dart';
import 'package:customer/controllers/redeem_gift_card_controller.dart';
import 'package:customer/models/gift_cards_order_model.dart';
import 'package:customer/models/wallet_transaction_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../dash_board_screens/dash_board_screen.dart';

/// Focused redeem form: a gradient voucher hero on top, then the code and
/// pin fields, with the action pinned to the bottom.
class RedeemGiftCardScreen extends StatelessWidget {
  const RedeemGiftCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: RedeemGiftCardController(),
      builder: (controller) {
        final t = context.dsText;
        return DsScaffold(
          maxContentWidth: DsLayout.contentMax,
          appBar: const DsAppBar(),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Redeem".tr,
              icon: Icons.redeem_rounded,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: () async {
                if (controller.giftCodeController.value.text.isEmpty) {
                  ShowToastDialog.showToast("Please Enter Gift Code".tr);
                } else if (controller.giftPinController.value.text.isEmpty) {
                  ShowToastDialog.showToast("Please Enter Gift Pin".tr);
                } else {
                  ShowToastDialog.showLoader("Please wait...".tr);
                  await FireStoreUtils.checkRedeemCode(controller.giftCodeController.value.text.replaceAll(" ", "")).then((value) async {
                    if (value != null) {
                      GiftCardsOrderModel giftCodeModel = value;
                      if (giftCodeModel.redeem == true) {
                        ShowToastDialog.closeLoader();
                        ShowToastDialog.showToast("Gift voucher already redeemed".tr);
                      } else if (giftCodeModel.giftPin != controller.giftPinController.value.text) {
                        ShowToastDialog.closeLoader();
                        ShowToastDialog.showToast("Gift Pin Invalid".tr);
                      } else if (giftCodeModel.expireDate!.toDate().isBefore(DateTime.now())) {
                        ShowToastDialog.closeLoader();
                        ShowToastDialog.showToast("Gift Voucher expire".tr);
                      } else {
                        giftCodeModel.redeem = true;

                        WalletTransactionModel transactionModel = WalletTransactionModel(
                          id: Constant.getUuid(),
                          amount: double.parse(giftCodeModel.price.toString()),
                          date: Timestamp.now(),
                          paymentMethod: "Wallet",
                          transactionUser: "user",
                          userId: FireStoreUtils.getCurrentUid(),
                          isTopup: true,
                          note: "Gift Voucher",
                          paymentStatus: "success",
                        );

                        await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
                          if (value == true) {
                            await FireStoreUtils.updateUserWallet(amount: giftCodeModel.price.toString(), userId: FireStoreUtils.getCurrentUid()).then((value) async {
                              await FireStoreUtils.sendTopUpMail(paymentMethod: "Gift Voucher", amount: giftCodeModel.price.toString(), tractionId: transactionModel.id.toString());
                              await FireStoreUtils.placeGiftCardOrder(giftCodeModel).then((value) {
                                ShowToastDialog.closeLoader();
                                if (Constant.walletSetting == true) {
                                  Get.offAll(const DashBoardScreen());
                                  DashBoardController controller = Get.put(DashBoardController());
                                  controller.selectedIndex.value = 2;
                                }
                                ShowToastDialog.showToast("Voucher redeem successfully".tr);
                              });
                            });
                          }
                        });
                      }
                    } else {
                      ShowToastDialog.closeLoader();
                      ShowToastDialog.showToast("Invalid Gift Code".tr);
                    }
                  });
                }
              },
            ),
          ),
          body: InkWell(
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.lg, DsSpace.xxxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: DsFadeSlideIn.stagger([
                  DsCard.gradient(
                    child: Row(
                      children: [
                        const Icon(Icons.redeem_rounded, color: Colors.white, size: 34),
                        const DsGap(DsSpace.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Redeem Gift Card".tr, style: t.headline.withColor(Colors.white)),
                              const DsGap(DsSpace.xs),
                              Text(
                                "Enter your gift card code to enjoy discounts and special offers on your orders.".tr,
                                style: t.bodySm.withColor(Colors.white.withValues(alpha: 0.88)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.xxl),
                  DsFormSection(
                    plain: true,
                    children: [
                      DsTextField(
                        label: 'Gift Code'.tr,
                        controller: controller.giftCodeController.value,
                        hint: 'Enter gift code'.tr,
                        keyboardType: TextInputType.number,
                        prefix: Padding(padding: const EdgeInsets.all(DsSpace.md), child: SvgPicture.asset("assets/icons/ic_gift_code.svg", width: 20, height: 20)),
                      ),
                      DsTextField(
                        label: 'Gift Pin'.tr,
                        controller: controller.giftPinController.value,
                        hint: 'Enter gift pin'.tr,
                        keyboardType: TextInputType.number,
                        bottomSpacing: 0,
                        prefix: Padding(padding: const EdgeInsets.all(DsSpace.md), child: SvgPicture.asset("assets/icons/ic_gift_pin.svg", width: 20, height: 20)),
                      ),
                    ],
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

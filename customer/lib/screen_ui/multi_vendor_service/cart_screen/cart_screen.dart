import 'package:bottom_picker/bottom_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cart_controller.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/payment/create_razor_pay_order_model.dart';
import 'package:customer/payment/rozorpay_conroller.dart';
import 'package:customer/screen_ui/location_enable_screens/address_list_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/cart_screen/select_payment_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../models/user_model.dart';
import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../../../widget/shop_widgets.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';
import '../wallet_screen/wallet_screen.dart';
import 'coupon_list_screen.dart';

/// Archetype C — cart + checkout. One vertical stack of labelled steps:
/// fulfilment, address, items, delivery timing, offers, bill, tip and remarks.
/// The payment method and the Pay Now button live in a sticky bar, with the
/// cashback note riding above them.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: CartController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final isDark = context.dsIsDark;

        // Observables are read here, inside the tracked builder.
        final bool isEmpty = cartItem.isEmpty;
        final String foodType = controller.selectedFoodType.value;
        final bool isTakeAway = foodType == 'TakeAway';
        final bool selfDelivery = controller.vendorModel.value.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true;
        final String deliveryType = controller.deliveryType.value;
        final double tips = controller.deliveryTips.value;
        final bool cashbackApply = controller.isCashbackApply.value;
        final String paymentMethod = controller.selectedPaymentMethod.value;
        final currency = controller.storeCurrency;

        return DsScaffold(
          title: "Cart".tr,
          maxContentWidth: DsLayout.contentMax,
          body: isEmpty
              ? DsEmptyState(icon: Icons.shopping_cart_outlined, title: "Item Not available".tr)
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.lg, DsSpace.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Delivery / TakeAway at checkout; products the mode doesn't allow are flagged and blocked.
                      Padding(
                        padding: const EdgeInsets.only(bottom: DsSpace.lg),
                        child: OrderTypeToggle(value: foodType, isDark: isDark, onChanged: controller.setFoodType),
                      ),
                      isTakeAway
                          ? const SizedBox()
                          : DsCard.outlined(
                              margin: const EdgeInsets.only(bottom: DsSpace.xl),
                              padding: const EdgeInsets.all(DsSpace.lg),
                              semanticLabel: "Delivery Address".tr,
                              onTap: () {
                                Get.to(AddressListScreen())!.then((value) {
                                  if (value != null) {
                                    ShippingAddress shippingAddress = value;
                                    if (Constant.checkZoneCheck(shippingAddress.location!.latitude ?? 0.0, shippingAddress.location!.longitude ?? 0.0)) {
                                      controller.selectedAddress.value = shippingAddress;
                                      controller.calculatePrice();
                                    } else {
                                      ShowToastDialog.showToast("Service not available in this area".tr);
                                    }
                                  }
                                });
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Icon(Icons.near_me_outlined, size: 20, color: c.brandStrong),
                                      const DsGap(DsSpace.sm),
                                      Expanded(child: Text(controller.selectedAddress.value.addressAs.toString(), style: t.label.withColor(c.brandStrong))),
                                      Icon(Icons.expand_more_rounded, color: c.iconDefault),
                                    ],
                                  ),
                                  const DsGap(DsSpace.xs),
                                  Text(controller.selectedAddress.value.getFullAddress(), style: t.bodySecondary),
                                ],
                              ),
                            ),
                      DsCard(
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: cartItem.length,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            CartProductModel cartProductModel = cartItem[index];
                            ProductModel? productModel;
                            FireStoreUtils.getProductById(cartProductModel.id!.split('~').first).then((value) {
                              productModel = value;
                            });
                            return DsPressable(
                              onTap: () async {
                                await FireStoreUtils.getVendorById(productModel!.vendorID.toString()).then((value) {
                                  if (value != null) {
                                    Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": value});
                                  }
                                });
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      DsImage(url: cartProductModel.photo.toString(), height: 72, width: 72, radius: DsRadius.md, fit: BoxFit.cover, errorIcon: Icons.fastfood_outlined),
                                      const DsGap(DsSpace.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("${cartProductModel.name}", style: t.bodyStrong),
                                            const DsGap(DsSpace.xxs),
                                            // Wholesale tier reached by this line's quantity (spec 8.2).
                                            cartProductModel.linePrice.isWholesale
                                                ? Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            Constant.amountShow(amount: cartProductModel.chargedUnitPrice.toString(), currency: currency),
                                                            style: t.titleSm.tabular.withColor(c.brandStrong),
                                                          ),
                                                          const DsGap(DsSpace.xs),
                                                          if (cartProductModel.lineMeta?.isWholesaleOnly != true)
                                                            Text(
                                                              Constant.amountShow(amount: cartProductModel.retailUnitPrice.toString(), currency: currency),
                                                              style: t.bodySm.tabular.strike,
                                                            ),
                                                        ],
                                                      ),
                                                      Text("${'Wholesale price'.tr} · ${'from'.tr} ${cartProductModel.linePrice.minQty} ${'pcs'.tr}", style: t.labelSm.withColor(c.brandStrong)),
                                                    ],
                                                  )
                                                : double.parse(cartProductModel.discountPrice.toString()) <= 0 ||
                                                      cartProductModel.retailUnitPrice != double.parse(cartProductModel.discountPrice.toString())
                                                ? Text(
                                                    Constant.amountShow(amount: cartProductModel.price, currency: currency),
                                                    style: t.titleSm.tabular.withColor(c.brandStrong),
                                                  )
                                                : Row(
                                                    children: [
                                                      Text(
                                                        Constant.amountShow(amount: cartProductModel.discountPrice.toString(), currency: currency),
                                                        style: t.titleSm.tabular.withColor(c.brandStrong),
                                                      ),
                                                      const DsGap(DsSpace.xs),
                                                      Text(
                                                        Constant.amountShow(amount: cartProductModel.price, currency: currency),
                                                        style: t.bodySm.tabular.strike,
                                                      ),
                                                    ],
                                                  ),
                                            Builder(
                                              builder: (context) {
                                                // Next cheaper tier, so the customer sees when the price switches.
                                                final next = (cartProductModel.lineMeta?.tiers ?? const []).firstWhereOrNull(
                                                  (t) => t.isUsable && t.minQtyValue > (cartProductModel.quantity ?? 0) && t.priceValue < cartProductModel.chargedUnitPrice,
                                                );
                                                if (next == null) return const SizedBox.shrink();
                                                return Text(
                                                  "${'Buy'.tr} ${next.minQtyValue}+ ${'for'.tr} ${Constant.amountShow(amount: next.price, currency: currency)} ${'each'.tr}",
                                                  style: t.caption,
                                                );
                                              },
                                            ),
                                            if (cartProductModel.lineMeta != null && !cartProductModel.lineMeta!.fulfilment.contains(foodTypeToFulfilment(foodType)))
                                              Padding(
                                                padding: const EdgeInsets.only(top: DsSpace.xs),
                                                child: DsBadge(label: "${'Not available for'.tr} ${foodType.tr}", tone: DsTone.danger, icon: Icons.error_outline_rounded, small: true),
                                              ),
                                            if (Constant.taxScope == "product")
                                              cartProductModel.taxSetting?.isEmpty == true
                                                  ? const SizedBox()
                                                  : Text(
                                                      "${'Tax:'.tr} ${Constant.getTaxDisplayText(cartProductModel.taxSetting, currency: currency)}",
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: t.caption,
                                                    ),
                                          ],
                                        ),
                                      ),
                                      const DsGap(DsSpace.sm),
                                      _LineStepper(
                                        quantity: cartProductModel.quantity.toString(),
                                        onRemove: () {
                                          // Below a wholesale-only product's minimum quantity the line is removed.
                                          final int next = cartProductModel.quantity! - 1;
                                          controller.addToCart(cartProductModel: cartProductModel, isIncrement: false, quantity: next < cartProductModel.minOrderQuantity ? 0 : next);
                                        },
                                        onAdd: () {
                                          if (productModel!.itemAttribute != null) {
                                            if (productModel!.itemAttribute!.variants!.where((element) => element.variantSku == cartProductModel.variantInfo!.variantSku).isNotEmpty) {
                                              if (int.parse(
                                                        productModel!.itemAttribute!.variants!
                                                            .where((element) => element.variantSku == cartProductModel.variantInfo!.variantSku)
                                                            .first
                                                            .variantQuantity
                                                            .toString(),
                                                      ) >
                                                      (cartProductModel.quantity ?? 0) ||
                                                  int.parse(
                                                        productModel!.itemAttribute!.variants!
                                                            .where((element) => element.variantSku == cartProductModel.variantInfo!.variantSku)
                                                            .first
                                                            .variantQuantity
                                                            .toString(),
                                                      ) ==
                                                      -1) {
                                                controller.addToCart(cartProductModel: cartProductModel, isIncrement: true, quantity: cartProductModel.quantity! + 1);
                                              } else {
                                                ShowToastDialog.showToast("Out of stock".tr);
                                              }
                                            } else {
                                              if ((productModel!.quantity ?? 0) > (cartProductModel.quantity ?? 0) || productModel!.quantity == -1) {
                                                controller.addToCart(cartProductModel: cartProductModel, isIncrement: true, quantity: cartProductModel.quantity! + 1);
                                              } else {
                                                ShowToastDialog.showToast("Out of stock".tr);
                                              }
                                            }
                                          } else {
                                            if ((productModel!.quantity ?? 0) > (cartProductModel.quantity ?? 0) || productModel!.quantity == -1) {
                                              controller.addToCart(cartProductModel: cartProductModel, isIncrement: true, quantity: cartProductModel.quantity! + 1);
                                            } else {
                                              ShowToastDialog.showToast("Out of stock".tr);
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  cartProductModel.variantInfo == null || cartProductModel.variantInfo!.variantOptions == null || cartProductModel.variantInfo!.variantOptions!.isEmpty
                                      ? const SizedBox()
                                      : Padding(
                                          padding: const EdgeInsets.only(top: DsSpace.md),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("Variants".tr, style: t.labelSm),
                                              const DsGap(DsSpace.xs),
                                              Wrap(
                                                spacing: DsSpace.xs,
                                                runSpacing: DsSpace.xs,
                                                children: List.generate(cartProductModel.variantInfo!.variantOptions!.length, (i) {
                                                  return _MetaPill(
                                                    label:
                                                        "${cartProductModel.variantInfo!.variantOptions!.keys.elementAt(i)} : ${cartProductModel.variantInfo!.variantOptions![cartProductModel.variantInfo!.variantOptions!.keys.elementAt(i)]}",
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          ),
                                        ),
                                  cartProductModel.extras == null || cartProductModel.extras!.isEmpty || cartProductModel.extrasPrice == '0'
                                      ? const SizedBox()
                                      : Padding(
                                          padding: const EdgeInsets.only(top: DsSpace.md),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(child: Text("Addons".tr, style: t.labelSm)),
                                                  Text(
                                                    Constant.amountShow(
                                                      amount: (double.parse(cartProductModel.extrasPrice.toString()) * double.parse(cartProductModel.quantity.toString())).toString(),
                                                      currency: currency,
                                                    ),
                                                    style: t.label.tabular.withColor(c.brandStrong),
                                                  ),
                                                ],
                                              ),
                                              const DsGap(DsSpace.xs),
                                              Wrap(
                                                spacing: DsSpace.xs,
                                                runSpacing: DsSpace.xs,
                                                children: List.generate(cartProductModel.extras!.length, (i) {
                                                  return _MetaPill(label: cartProductModel.extras![i].toString());
                                                }).toList(),
                                              ),
                                            ],
                                          ),
                                        ),
                                ],
                              ),
                            );
                          },
                          separatorBuilder: (context, index) {
                            return const DsDivider(spacing: DsSpace.md);
                          },
                        ),
                      ),
                      DsSectionHeader(title: "${'Delivery Type'.tr} ($foodType)".tr, icon: Icons.schedule_outlined),
                      isTakeAway
                          ? const SizedBox()
                          : _ChoiceRow(
                              title: "Instant Delivery".tr,
                              subtitle: "Standard".tr,
                              selected: deliveryType == "instant",
                              onTap: () {
                                controller.deliveryType.value = "instant";
                              },
                            ),
                      if (!isTakeAway) const DsGap(DsSpace.md),
                      _ChoiceRow(
                        title: "Schedule Time".tr,
                        subtitle: "${'Your preferred time'.tr} ${deliveryType == "schedule" ? Constant.timestampToDateTime(Timestamp.fromDate(controller.scheduleDateTime.value)) : ""}",
                        selected: deliveryType == "schedule",
                        onTap: () {
                          controller.deliveryType.value = "schedule";
                          BottomPicker<DateTime>.dateTime(
                            onSubmit: (index) {
                              controller.scheduleDateTime.value = index!;
                            },
                            minDateTime: DateTime.now(),
                            displaySubmitButton: true,
                            // bottom_picker 5 dropped pickerTitle and the built-in close icon; rebuild the same header.
                            headerBuilder: (context) => Row(
                              children: [
                                Expanded(child: Text('Schedule Time'.tr)),
                                InkWell(
                                  onTap: () => Navigator.pop(context),
                                  child: const Icon(Icons.close, color: Colors.black, size: 20),
                                ),
                              ],
                            ),
                            buttonSingleColor: c.brand,
                          ).show(context);
                        },
                      ),
                      DsSectionHeader(title: "Offers & Benefits".tr, icon: Icons.redeem_outlined),
                      DsCard.tinted(
                        semanticLabel: "Apply Coupons".tr,
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.lg),
                        onTap: () {
                          Get.to(const CouponListScreen());
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(Icons.confirmation_number_outlined, size: 20, color: c.brandStrong),
                            const DsGap(DsSpace.sm),
                            Expanded(child: Text("Apply Coupons".tr, style: t.titleSm)),
                            Icon(Icons.keyboard_arrow_right, color: c.iconDefault),
                          ],
                        ),
                      ),
                      DsSectionHeader(title: "Bill Details".tr, icon: Icons.receipt_long_outlined),
                      DsCard(
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.lg),
                        child: Column(
                          children: [
                            amountRow(
                              title: "Item totals".tr,
                              amount: Constant.amountShow(amount: controller.subTotal.value.toString(), currency: currency),
                              isDark: isDark,
                            ),
                            sectionDivider(isDark),
                            amountRow(
                              title: "Coupon Discount".tr,
                              amount: "- (${Constant.amountShow(amount: controller.couponAmount.value.toString(), currency: currency)})",
                              isDark: isDark,
                              amountColor: c.dangerStrong,
                            ),
                            controller.vendorModel.value.specialDiscountEnable == true && Constant.specialDiscountOffer == true
                                ? Padding(
                                    padding: const EdgeInsets.only(top: DsSpace.md),
                                    child: amountRow(
                                      title: "Special Discount".tr,
                                      amount: "- (${Constant.amountShow(amount: controller.specialDiscountAmount.value.toString(), currency: currency)})",
                                      isDark: isDark,
                                      amountColor: c.dangerStrong,
                                    ),
                                  )
                                : const SizedBox(),
                            const DsGap(DsSpace.md),
                            if (Constant.sectionConstantModel?.packagingChargeEnable == true)
                              amountRow(
                                title: "Packaging charge".tr,
                                amount: Constant.amountShow(amount: controller.packagingCharge.value.toString(), currency: currency),
                                isDark: isDark,
                              ),
                            if (Constant.sectionConstantModel?.packagingChargeEnable == true) const DsGap(DsSpace.md),
                            isTakeAway
                                ? const SizedBox()
                                : amountRow(
                                    title: "Delivery Fee".tr,
                                    amount: selfDelivery ? 'Free Delivery'.tr : Constant.amountShow(amount: controller.deliveryCharges.value.toString(), currency: currency),
                                    isDark: isDark,
                                    amountColor: selfDelivery ? c.successStrong : null,
                                  ),
                            if (!isTakeAway) const DsGap(DsSpace.md),
                            isTakeAway || selfDelivery
                                ? const SizedBox()
                                : amountRow(
                                    title: "Delivery Tips".tr,
                                    amount: Constant.amountShow(amount: controller.deliveryTips.toString(), currency: currency),
                                    isDark: isDark,
                                    leadingExtra: tips == 0
                                        ? null
                                        : DsButton.ghost(
                                            label: "Remove".tr,
                                            size: DsButtonSize.sm,
                                            onPressed: () {
                                              controller.deliveryTips.value = 0;
                                              controller.calculatePrice();
                                            },
                                          ),
                                  ),
                            isTakeAway || selfDelivery ? const SizedBox() : const DsGap(DsSpace.md),
                            if (Constant.sectionConstantModel?.platformFee?.enable == true)
                              amountRow(
                                title: "Platform fee".tr,
                                amount: Constant.amountShow(amount: controller.platformFee.value.toString(), currency: currency),
                                isDark: isDark,
                              ),
                            if (Constant.sectionConstantModel?.platformFee?.enable == true) const DsGap(DsSpace.md),
                            sectionDivider(isDark),
                            DsPressable(
                              onTap: () {
                                showBillBifurcationDialog(context, isDark, controller);
                              },
                              child: amountRow(
                                title: "Tax amount".tr,
                                amount: Constant.amountShow(amount: controller.totalTaxAmount.value.toString(), currency: currency),
                                isDark: isDark,
                                textColour: c.textSecondary,
                                underline: true,
                              ),
                            ),
                            sectionDivider(isDark),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: Text("To Pay".tr, style: t.titleSm)),
                                Text(
                                  Constant.amountShow(amount: controller.totalAmount.value.toString(), currency: currency),
                                  style: t.title.tabular,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      isTakeAway || selfDelivery
                          ? const SizedBox()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DsSectionHeader(title: "Thanks with a tip!".tr, icon: Icons.volunteer_activism_outlined),
                                DsCard(
                                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.lg),
                                  child: Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: Text("Around the clock, our delivery partners make it happen. Show gratitude with a tip..".tr, style: t.bodySecondary)),
                                          const DsGap(DsSpace.md),
                                          SvgPicture.asset("assets/images/ic_tips.svg"),
                                        ],
                                      ),
                                      const DsGap(DsSpace.xl),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _TipChip(
                                              label: Constant.amountShow(amount: "20", currency: currency),
                                              selected: tips == 20,
                                              onTap: () {
                                                controller.deliveryTips.value = 20;
                                                controller.calculatePrice();
                                              },
                                            ),
                                          ),
                                          const DsGap(DsSpace.sm),
                                          Expanded(
                                            child: _TipChip(
                                              label: Constant.amountShow(amount: "30", currency: currency),
                                              selected: tips == 30,
                                              onTap: () {
                                                controller.deliveryTips.value = 30;
                                                controller.calculatePrice();
                                              },
                                            ),
                                          ),
                                          const DsGap(DsSpace.sm),
                                          Expanded(
                                            child: _TipChip(
                                              label: Constant.amountShow(amount: "40", currency: currency),
                                              selected: tips == 40,
                                              onTap: () {
                                                controller.deliveryTips.value = 40;
                                                controller.calculatePrice();
                                              },
                                            ),
                                          ),
                                          const DsGap(DsSpace.sm),
                                          Expanded(
                                            child: _TipChip(
                                              label: 'Other'.tr,
                                              selected: false,
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (BuildContext context) {
                                                    return tipsDialog(controller, isDark);
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                      DsSectionHeader(title: 'Remarks'.tr, icon: Icons.sticky_note_2_outlined),
                      DsTextField(controller: controller.reMarkController.value, hint: 'Write remarks for the store'.tr, maxLines: 4, bottomSpacing: 0),
                    ],
                  ),
                ),
          bottomBar: isEmpty
              ? null
              : DsStickyBar(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (cashbackApply)
                        Padding(
                          padding: const EdgeInsets.only(bottom: DsSpace.md),
                          child: DsCard.tinted(
                            tone: DsTone.success,
                            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Cashback Offer".tr, style: t.labelSm.withColor(c.textPrimary)),
                                Text("${"Cashback Name :".tr} ${controller.bestCashback.value.title ?? ''}", style: t.caption.withColor(c.successStrong)),
                                Text(
                                  "${"You will get".tr} ${Constant.amountShow(amount: controller.bestCashback.value.cashbackValue?.toStringAsFixed(2), currency: currency)} ${"cashback after completing the order.".tr}",
                                  style: t.caption.withColor(c.successStrong),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DsPressable(
                              onTap: () {
                                Get.to(const SelectPaymentScreen())?.then((v) {
                                  controller.getCashback();
                                });
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  paymentMethod == ''
                                      ? cardDecoration(controller, PaymentGateway.wallet, isDark, "")
                                      : paymentMethod == PaymentGateway.wallet.name
                                      ? cardDecoration(controller, PaymentGateway.wallet, isDark, "assets/images/ic_wallet.png")
                                      : paymentMethod == PaymentGateway.cod.name
                                      ? cardDecoration(controller, PaymentGateway.cod, isDark, "assets/images/ic_cash.png")
                                      : paymentMethod == PaymentGateway.stripe.name
                                      ? cardDecoration(controller, PaymentGateway.stripe, isDark, "assets/images/stripe.png")
                                      : paymentMethod == PaymentGateway.paypal.name
                                      ? cardDecoration(controller, PaymentGateway.paypal, isDark, "assets/images/paypal.png")
                                      : paymentMethod == PaymentGateway.payStack.name
                                      ? cardDecoration(controller, PaymentGateway.payStack, isDark, "assets/images/paystack.png")
                                      : paymentMethod == PaymentGateway.mercadoPago.name
                                      ? cardDecoration(controller, PaymentGateway.mercadoPago, isDark, "assets/images/mercado-pago.png")
                                      : paymentMethod == PaymentGateway.flutterWave.name
                                      ? cardDecoration(controller, PaymentGateway.flutterWave, isDark, "assets/images/flutterwave_logo.png")
                                      : paymentMethod == PaymentGateway.payFast.name
                                      ? cardDecoration(controller, PaymentGateway.payFast, isDark, "assets/images/payfast.png")
                                      : paymentMethod == PaymentGateway.midTrans.name
                                      ? cardDecoration(controller, PaymentGateway.midTrans, isDark, "assets/images/midtrans.png")
                                      : paymentMethod == PaymentGateway.orangeMoney.name
                                      ? cardDecoration(controller, PaymentGateway.orangeMoney, isDark, "assets/images/orange_money.png")
                                      : paymentMethod == PaymentGateway.xendit.name
                                      ? cardDecoration(controller, PaymentGateway.xendit, isDark, "assets/images/xendit.png")
                                      : cardDecoration(controller, PaymentGateway.razorpay, isDark, "assets/images/razorpay.png"),
                                  const DsGap(DsSpace.sm),
                                  Flexible(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text("Pay Via".tr, style: t.caption),
                                            const DsGap(DsSpace.xs),
                                            Text("(Change)".tr, style: t.labelSm.withColor(c.brandStrong)),
                                          ],
                                        ),
                                        paymentMethod == ''
                                            ? Padding(
                                                padding: const EdgeInsets.only(top: DsSpace.xs),
                                                child: DsShimmer(child: DsSkeleton.line(width: 60, height: 12)),
                                              )
                                            : Text(paymentMethod, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyStrong),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const DsGap(DsSpace.md),
                          Expanded(
                            child: _PayNowButton(
                              ready: paymentMethod != '',
                              onPressed: () async {
                                if (controller.deliveryType.value == "schedule") {
                                  bool isOpen = controller.isSelectedDateRestaurantOpen(selectedDateTime: controller.scheduleDateTime.value);
                                  if (isOpen == false) {
                                    ShowToastDialog.showToast("The restaurant will be closed at the selected scheduled time. Please choose a different date and time.".tr);
                                    return;
                                  }
                                }
                                if ((controller.couponAmount.value >= 1) && (controller.couponAmount.value > controller.totalAmount.value)) {
                                  ShowToastDialog.showToast("The total price must be greater than or equal to the coupon discount value for the code to apply. Please review your cart total.".tr);
                                  return;
                                }
                                if ((controller.specialDiscountAmount.value >= 1) && (controller.specialDiscountAmount.value > controller.totalAmount.value)) {
                                  ShowToastDialog.showToast("The total price must be greater than or equal to the special discount value for the code to apply. Please review your cart total.".tr);
                                  return;
                                }
                                // Delivery / TakeAway allowed for every product, business-only
                                // and minimum-quantity rules - before any payment starts.
                                if (controller.isOrderPlaced.value == false && !await controller.validateCartBeforePayment()) {
                                  return;
                                }
                                if (!context.mounted) return;
                                if (controller.isOrderPlaced.value == false) {
                                  controller.isOrderPlaced.value = true;
                                  await controller.getCashback();
                                  if (controller.selectedPaymentMethod.value == PaymentGateway.stripe.name) {
                                    controller.stripeMakePayment(amount: controller.totalAmount.value.toString());
                                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.paypal.name) {
                                    controller.paypalPaymentSheet(controller.totalAmount.value.toString(), context);
                                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.payStack.name) {
                                    controller.payStackPayment(controller.totalAmount.value.toString());
                                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.mercadoPago.name) {
                                    controller.mercadoPagoMakePayment(context: context, amount: controller.totalAmount.value.toString());
                                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.flutterWave.name) {
                                    controller.flutterWaveInitiatePayment(context: context, amount: controller.totalAmount.value.toString());
                                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.payFast.name) {
                                    controller.payFastPayment(context: context, amount: controller.totalAmount.value.toString());
                                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.cod.name) {
                                    controller.placeOrder();
                                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.wallet.name) {
                                    controller.placeOrder();
                                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.midTrans.name) {
                                    controller.midtransMakePayment(context: context, amount: controller.totalAmount.value.toString());
                                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.orangeMoney.name) {
                                    controller.orangeMakePayment(context: context, amount: controller.totalAmount.value.toString());
                                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.xendit.name) {
                                    controller.xenditPayment(context, controller.totalAmount.value.toString());
                                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.razorpay.name) {
                                    RazorPayController().createOrderRazorPay(amount: double.parse(controller.totalAmount.value.toString()), razorpayModel: controller.razorPayModel.value).then((
                                      value,
                                    ) {
                                      if (value == null) {
                                        Get.back();
                                        ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
                                      } else {
                                        CreateRazorPayOrderModel result = value;
                                        controller.openCheckout(amount: controller.totalAmount.value.toString(), orderId: result.id);
                                      }
                                    });
                                  } else {
                                    controller.isOrderPlaced.value = false;
                                    ShowToastDialog.showToast("Please select payment method".tr);
                                  }
                                  controller.isOrderPlaced.value = false;
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  void showBillBifurcationDialog(BuildContext context, bool isDark, CartController controller) {
    showDialog(
      context: context,
      builder: (context) {
        final c = DsColors.of(context);
        final t = DsTextTheme(c);
        return Dialog(
          backgroundColor: c.surfaceRaised,
          insetPadding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
          shape: const RoundedRectangleBorder(borderRadius: DsRadius.brLg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: DsLayout.contentMax),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.xl, DsSpace.xl, DsSpace.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(header: true, child: Text("Tax Details".tr, style: t.title)),
                  const DsGap(DsSpace.sm),
                  sectionDivider(isDark),
                  Constant.taxScope == 'product'
                      ? amountRow(
                          title: "Tax on item total".tr,
                          amount: Constant.amountShow(amount: controller.productTaxAmount.value.toString(), currency: controller.storeCurrency),
                          isDark: isDark,
                        )
                      : amountRow(
                          title: "Tax on Order Total".tr,
                          amount: Constant.amountShow(amount: controller.orderTaxAmount.value.toString(), currency: controller.storeCurrency),
                          isDark: isDark,
                        ),
                  if (controller.selectedFoodType.value != 'TakeAway' && controller.vendorModel.value.isSelfDelivery != true && Constant.driverDeliveryTaxList!.isNotEmpty == true)
                    sectionDivider(isDark),
                  if (controller.selectedFoodType.value != 'TakeAway' && controller.vendorModel.value.isSelfDelivery != true)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: Constant.driverDeliveryTaxList!.length,
                      itemBuilder: (context, index) {
                        return amountRow(
                          title: "${Constant.driverDeliveryTaxList?[index].title} ${'Tax on Delivery Fee'.tr}",
                          amount: Constant.amountShow(
                            amount: Constant.calculateTax(taxModel: Constant.driverDeliveryTaxList![index], amount: (controller.deliveryCharges.value).toString()).toString(),
                            currency: controller.storeCurrency,
                          ),
                          isDark: isDark,
                        );
                      },
                    ),
                  if (Constant.packagingTaxList?.isNotEmpty == true) sectionDivider(isDark),
                  ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: Constant.packagingTaxList!.length,
                    itemBuilder: (context, index) {
                      return amountRow(
                        title: "${Constant.packagingTaxList![index].title} ${'Tax on Packaging Fee'.tr}",
                        amount: controller.packagingCharge.value == 0.0
                            ? Constant.amountShow(amount: '0', currency: controller.storeCurrency)
                            : Constant.amountShow(
                                amount: Constant.calculateTax(taxModel: Constant.packagingTaxList![index], amount: controller.packagingCharge.value.toString()).toString(),
                                currency: controller.storeCurrency,
                              ),
                        isDark: isDark,
                      );
                    },
                  ),
                  if (Constant.platformTaxList?.isNotEmpty == true) sectionDivider(isDark),
                  if (Constant.platformTaxList?.isNotEmpty == true)
                    ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: Constant.platformTaxList!.length,
                      itemBuilder: (context, index) {
                        return amountRow(
                          title: "${Constant.platformTaxList![index].title} ${'Tax on Platform Fee'.tr}",
                          amount: controller.platformFee.value == 0.0
                              ? Constant.amountShow(amount: '0', currency: controller.storeCurrency)
                              : Constant.amountShow(
                                  amount: Constant.calculateTax(taxModel: Constant.platformTaxList![index], amount: controller.platformFee.value.toString()).toString(),
                                  currency: controller.storeCurrency,
                                ),
                          isDark: isDark,
                        );
                      },
                    ),
                  if (Constant.platformTaxList?.isNotEmpty == true) sectionDivider(isDark),
                  amountRow(
                    title: "Total Tax Amount".tr,
                    amount: Constant.amountShow(amount: controller.totalTaxAmount.value.toString(), currency: controller.storeCurrency),
                    amountColor: c.brandStrong,
                    isDark: isDark,
                  ),
                  const DsGap(DsSpace.lg),
                  Align(
                    alignment: Alignment.centerRight,
                    child: DsButton.ghost(label: "Close".tr, onPressed: () => Navigator.pop(context)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// One "label … amount" line of the bill summary.
  Widget amountRow({required String title, required String amount, required bool isDark, Color? textColour, Color? amountColor, bool? underline, Widget? trailing, Widget? leadingExtra}) {
    return _AmountRow(title: title, amount: amount, textColour: textColour, amountColor: amountColor, underline: underline, trailing: trailing, leadingExtra: leadingExtra);
  }

  /// Compact gateway logo tile shown next to "Pay Via".
  Widget cardDecoration(CartController controller, PaymentGateway value, isDark, String image) {
    return _GatewayTile(image: image, name: value.name);
  }

  Widget sectionDivider(bool isDark) {
    return const DsDivider(spacing: DsSpace.md);
  }

  Widget tipsDialog(CartController controller, isDark) {
    return _TipsDialog(controller: controller);
  }
}

class _AmountRow extends StatelessWidget {
  final String title;
  final String amount;
  final Color? textColour;
  final Color? amountColor;
  final bool? underline;
  final Widget? trailing;
  final Widget? leadingExtra;
  const _AmountRow({required this.title, required this.amount, this.textColour, this.amountColor, this.underline, this.trailing, this.leadingExtra});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.tr,
                style: t.body.copyWith(color: textColour ?? c.textSecondary, decoration: underline == true ? TextDecoration.underline : TextDecoration.none, decorationColor: c.textSecondary),
              ),
              ?leadingExtra,
            ],
          ),
        ),
        const DsGap(DsSpace.sm),
        trailing ?? Text(amount, style: t.bodyStrong.tabular.withColor(amountColor ?? c.textPrimary)),
      ],
    );
  }
}

/// +/- stepper for a cart line.
class _LineStepper extends StatelessWidget {
  final String quantity;
  final VoidCallback onRemove;
  final VoidCallback onAdd;
  const _LineStepper({required this.quantity, required this.onRemove, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: DsRadius.brPill,
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DsIconButton(icon: Icons.remove_rounded, semanticLabel: 'Remove'.tr, size: 32, onPressed: onRemove),
          Text(quantity, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label.tabular),
          DsIconButton(icon: Icons.add_rounded, semanticLabel: 'Add item'.tr, size: 32, onPressed: onAdd),
        ],
      ),
    );
  }
}

/// Small neutral pill used for variants and add-ons.
class _MetaPill extends StatelessWidget {
  final String label;
  const _MetaPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brSm),
      child: Text(label, style: t.bodySm),
    );
  }
}

/// Selectable row for the delivery timing options.
class _ChoiceRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceRow({required this.title, required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Semantics(
      selected: selected,
      button: true,
      child: DsCard.outlined(
        onTap: onTap,
        borderColor: selected ? c.brand : null,
        padding: const EdgeInsets.all(DsSpace.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleSm),
                  const DsGap(DsSpace.xxs),
                  Text(subtitle, style: t.caption),
                ],
              ),
            ),
            const DsGap(DsSpace.sm),
            AnimatedContainer(
              duration: DsMotion.of(context, DsMotion.fast),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? c.brand : c.borderStrong, width: 2),
              ),
              alignment: Alignment.center,
              child: AnimatedScale(
                duration: DsMotion.of(context, DsMotion.fast),
                scale: selected ? 1 : 0,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c.brand),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TipChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Semantics(
      selected: selected,
      button: true,
      child: DsPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: DsMotion.of(context, DsMotion.fast),
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.sm),
          decoration: BoxDecoration(
            color: selected ? c.brandSoft : Colors.transparent,
            borderRadius: DsRadius.brMd,
            border: Border.all(color: selected ? c.brand : c.border),
          ),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label.tabular.withColor(selected ? c.brandStrong : c.textPrimary)),
        ),
      ),
    );
  }
}

class _GatewayTile extends StatelessWidget {
  final String image;
  final String name;
  const _GatewayTile({required this.image, required this.name});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: DsRadius.brSm,
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(name == "payFast" ? 0 : DsSpace.sm),
        child: image == '' ? DsShimmer(child: DsSkeleton.box(width: 28, height: 28, radius: DsRadius.xs)) : Image.asset(image),
      ),
    );
  }
}

class _TipsDialog extends StatelessWidget {
  final CartController controller;
  const _TipsDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: DsRadius.brXl),
      insetPadding: const EdgeInsets.all(DsSpace.lg),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      backgroundColor: c.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.xxl),
        child: SizedBox(
          width: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DsTextField(
                label: 'Tips Amount'.tr,
                controller: controller.tipsController.value,
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                prefix: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                  child: Text((controller.storeCurrency ?? Constant.currencyModel!).symbol.tr, style: t.titleSm),
                ),
                hint: 'Enter Tips Amount'.tr,
                bottomSpacing: DsSpace.md,
              ),
              Row(
                children: [
                  Expanded(
                    child: DsButton.secondary(
                      label: "Cancel".tr,
                      expand: true,
                      onPressed: () async {
                        Get.back();
                      },
                    ),
                  ),
                  const DsGap(DsSpace.lg),
                  Expanded(
                    child: DsButton.primary(
                      label: "Add".tr,
                      expand: true,
                      onPressed: () async {
                        if (controller.tipsController.value.text.isEmpty) {
                          ShowToastDialog.showToast("Please enter tips Amount".tr);
                        } else {
                          controller.deliveryTips.value = double.parse(controller.tipsController.value.text);
                          controller.calculatePrice();
                          Get.back();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pay Now: a filled primary once a payment method is chosen, muted before —
/// but always tappable, so the "select payment method" toast still fires.
class _PayNowButton extends StatelessWidget {
  final bool ready;
  final Future<void> Function() onPressed;
  const _PayNowButton({required this.ready, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ready
        ? DsButton.primary(label: "Pay Now".tr, size: DsButtonSize.lg, expand: true, onPressed: onPressed)
        : DsButton.secondary(label: "Pay Now".tr, size: DsButtonSize.lg, expand: true, onPressed: onPressed);
  }
}

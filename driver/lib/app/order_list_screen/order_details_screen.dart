import 'package:driver/utils/region_service.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/order_details_controller.dart';
import 'package:driver/models/cart_product_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Archetype J (detail) — receipt. A tinted summary header with the order id
/// and status, the route below it, then the item manifest and a bill card
/// whose "To Pay" line is the emphasised total.
class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    // Kept as the observable read that rebuilds this screen on a theme change;
    // colors now come from `context.dsColors`.
    themeController.isDark.value;
    return GetX(
        init: OrderDetailsController(),
        builder: (controller) {
          final bool isLoading = controller.isLoading.value;
          return DsScaffold(
            title: "Order Details".tr,
            body: DsAsync(
              isLoading: isLoading,
              skeleton: const DsSkeletonDetail(mediaHeight: 120),
              builder: (context) => ListView(
                padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                children: DsFadeSlideIn.stagger([
                  Padding(padding: const EdgeInsets.only(bottom: DsSpace.lg), child: _summaryCard(context, controller)),
                  Padding(padding: const EdgeInsets.only(bottom: DsSpace.xl), child: _routeCard(context, controller)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DsSectionHeader(title: "Order Details".tr, icon: Icons.shopping_bag_outlined, padding: EdgeInsets.zero),
                      const DsGap(DsSpace.md),
                      _productsCard(context, controller),
                      const DsGap(DsSpace.xl),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DsSectionHeader(title: "Bill Details".tr, icon: Icons.receipt_long_outlined, padding: EdgeInsets.zero),
                      const DsGap(DsSpace.md),
                      controller.orderModel.value.paymentMethod == 'cod' ? _codBillCard(context, controller) : _payoutBillCard(context, controller),
                    ],
                  ),
                ]),
              ),
            ),
          );
        });
  }

  Widget _summaryCard(BuildContext context, OrderDetailsController controller) {
    final c = context.dsColors;
    final t = context.dsText;
    final status = controller.orderModel.value.status.toString();
    return DsCard.tinted(
      tone: DsTone.fromStatus(status),
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Order".tr, style: t.caption),
                Text(
                  "${'Order'.tr} ${Constant.orderId(orderId: controller.orderModel.value.id.toString())}".tr,
                  style: t.title.w700.tabular.withColor(c.textPrimary),
                ),
              ],
            ),
          ),
          const DsGap(DsSpace.md),
          DsStatusChip(label: status.tr, status: status, pulse: DsTone.fromStatus(status) == DsTone.info),
        ],
      ),
    );
  }

  Widget _routeCard(BuildContext context, OrderDetailsController controller) {
    return DsCard(
      padding: const EdgeInsets.all(DsSpace.lg),
      child: DsRouteStops(
        stops: [
          DsRouteStop(
            kind: DsStopKind.pickup,
            label: "${controller.orderModel.value.vendor!.title}",
            address: "${controller.orderModel.value.vendor!.location}",
          ),
          DsRouteStop(
            kind: DsStopKind.drop,
            label: "${controller.orderModel.value.address!.addressAs} · ${controller.orderModel.value.author!.fullName()}",
            address: controller.orderModel.value.address!.getFullAddress(),
          ),
        ],
      ),
    );
  }

  Widget _productsCard(BuildContext context, OrderDetailsController controller) {
    final c = context.dsColors;
    final t = context.dsText;
    final products = controller.orderModel.value.products ?? <CartProductModel>[];
    final currency = RegionService.currencyForRecord(controller.orderModel.value.regionId);

    return DsCard(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.sm),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: products.length,
        physics: const NeverScrollableScrollPhysics(),
        separatorBuilder: (context, index) => const DsDivider(spacing: DsSpace.md),
        itemBuilder: (context, index) {
          CartProductModel cartProductModel = products[index];
          final bool discounted =
              double.parse(cartProductModel.discountPrice == null || cartProductModel.discountPrice!.isEmpty ? "0.0" : cartProductModel.discountPrice.toString()) > 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    DsImage(url: cartProductModel.photo.toString(), width: 64, height: 64, radius: DsRadius.md),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Text("${cartProductModel.name}", style: t.bodyStrong)),
                              const DsGap(DsSpace.sm),
                              DsBadge(label: "x ${cartProductModel.quantity}", small: true),
                            ],
                          ),
                          const DsGap(DsSpace.xs),
                          discounted
                              ? Row(
                                  children: [
                                    Text(
                                      Constant.amountShow(currency: currency, amount: cartProductModel.discountPrice.toString()),
                                      style: t.titleSm.w700.tabular,
                                    ),
                                    const DsGap(DsSpace.sm),
                                    Text(
                                      Constant.amountShow(currency: currency, amount: cartProductModel.price),
                                      style: t.bodySm.strike.withColor(c.textMuted).tabular,
                                    ),
                                  ],
                                )
                              : Text(
                                  Constant.amountShow(currency: currency, amount: cartProductModel.price),
                                  style: t.titleSm.w700.tabular,
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!(cartProductModel.variantInfo == null || cartProductModel.variantInfo!.variantOptions!.isEmpty)) ...[
                  const DsGap(DsSpace.md),
                  Text("Variants".tr, style: t.labelSm),
                  const DsGap(DsSpace.xs),
                  Wrap(
                    spacing: DsSpace.sm,
                    runSpacing: DsSpace.sm,
                    children: List.generate(
                      cartProductModel.variantInfo!.variantOptions!.length,
                      (i) => DsBadge(
                        label:
                            "${cartProductModel.variantInfo!.variantOptions!.keys.elementAt(i)} : ${cartProductModel.variantInfo!.variantOptions![cartProductModel.variantInfo!.variantOptions!.keys.elementAt(i)]}",
                        small: true,
                      ),
                    ).toList(),
                  ),
                ],
                if (!(cartProductModel.extras == null || cartProductModel.extras!.isEmpty)) ...[
                  const DsGap(DsSpace.md),
                  Row(
                    children: [
                      Expanded(child: Text("Addons".tr, style: t.labelSm)),
                      const DsGap(DsSpace.sm),
                      Text(
                        Constant.amountShow(
                            currency: currency,
                            amount: (double.parse(cartProductModel.extrasPrice.toString()) * double.parse(cartProductModel.quantity.toString())).toString()),
                        style: t.bodyStrong.withColor(c.brandStrong).tabular,
                      ),
                    ],
                  ),
                  const DsGap(DsSpace.xs),
                  Wrap(
                    spacing: DsSpace.sm,
                    runSpacing: DsSpace.sm,
                    children: List.generate(
                      cartProductModel.extras!.length,
                      (i) => DsBadge(label: cartProductModel.extras![i].toString(), small: true),
                    ).toList(),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Cash-on-delivery: the driver collects the full customer bill.
  Widget _codBillCard(BuildContext context, OrderDetailsController controller) {
    final c = context.dsColors;
    final t = context.dsText;
    final currency = RegionService.currencyForRecord(controller.orderModel.value.regionId);
    final bool showTips = !(controller.orderModel.value.takeAway == true ||
        controller.orderModel.value.vendor!.isSelfDelivery == true ||
        controller.orderModel.value.isFreeDelivery == true);

    return DsCard(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.sm),
      child: Column(
        children: [
          /// Item Total
          DsInfoRow(
            label: "Item totals".tr,
            value: Constant.amountShow(currency: currency, amount: controller.subTotal.value.toString()),
            divider: true,
          ),

          /// Coupon Discount
          DsInfoRow(
            label: "Coupon Discount".tr,
            value: "- (${Constant.amountShow(currency: currency, amount: controller.couponAmount.value.toString())})",
            valueTone: DsTone.danger,
            divider: true,
          ),

          /// Special Discount
          if (controller.orderModel.value.vendor!.specialDiscountEnable == true)
            DsInfoRow(
              label: "Special Discount".tr,
              value: "- (${Constant.amountShow(currency: currency, amount: controller.specialDiscountAmount.value.toString())})",
              valueTone: DsTone.danger,
              divider: true,
            ),

          /// Packaging
          DsInfoRow(
            label: "Packaging charge".tr,
            value: Constant.amountShow(currency: currency, amount: controller.packagingCharge.value.toString()),
            divider: true,
          ),

          /// Delivery Fee
          if (controller.orderModel.value.takeAway == false)
            DsInfoRow(
              label: "Delivery Fee".tr,
              divider: true,
              valueWidget: (controller.orderModel.value.vendor!.isSelfDelivery == true || controller.orderModel.value.isFreeDelivery == true)
                  ? Text('Free Delivery'.tr, textAlign: TextAlign.end, style: t.bodyStrong.withColor(c.successStrong))
                  : Text(
                      Constant.amountShow(currency: currency, amount: controller.deliveryCharges.value.toString()),
                      textAlign: TextAlign.end,
                      style: t.bodyStrong.tabular,
                    ),
            ),

          /// Delivery Tips
          if (showTips)
            DsInfoRow(
              label: "Delivery Tips".tr,
              value: Constant.amountShow(currency: currency, amount: controller.deliveryTips.toString()),
              divider: true,
            ),

          /// Platform Fee
          DsInfoRow(
            label: "Platform fee".tr,
            value: Constant.amountShow(currency: currency, amount: controller.platformFee.value.toString()),
            divider: true,
          ),

          /// Tax
          InkWell(
            onTap: () {
              showBillBifurcationDialog(context, controller);
            },
            child: DsInfoRow(
              label: "Tax amount".tr,
              divider: true,
              valueWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      Constant.amountShow(currency: currency, amount: controller.totalTaxAmount.value.toString()),
                      textAlign: TextAlign.end,
                      style: t.bodyStrong.withColor(c.brandStrong).tabular,
                    ),
                  ),
                  const DsGap(DsSpace.xs),
                  Icon(Icons.info_outline_rounded, size: 16, color: c.brandStrong),
                ],
              ),
            ),
          ),

          /// To Pay
          DsInfoRow(
            label: "To Pay".tr,
            value: Constant.amountShow(currency: currency, amount: controller.totalAmount.value.toString()),
            emphasize: true,
            valueTone: DsTone.brand,
          ),
        ],
      ),
    );
  }

  /// Prepaid orders: the driver only sees their own delivery payout.
  Widget _payoutBillCard(BuildContext context, OrderDetailsController controller) {
    final c = context.dsColors;
    final t = context.dsText;
    final currency = RegionService.currencyForRecord(controller.orderModel.value.regionId);
    final bool showTips = !(controller.orderModel.value.takeAway == true ||
        controller.orderModel.value.vendor!.isSelfDelivery == true ||
        controller.orderModel.value.isFreeDelivery == true);
    final bool driverTaxed = controller.orderModel.value.takeAway != true && controller.orderModel.value.vendor?.isSelfDelivery != true;
    final driverDeliveryTax = controller.orderModel.value.driverDeliveryTax ?? [];

    return DsCard(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.sm),
      child: Column(
        children: [
          DsInfoRow(
            label: "Delivery Fee".tr,
            divider: true,
            valueWidget: (controller.orderModel.value.vendor!.isSelfDelivery == true || controller.orderModel.value.isFreeDelivery == true)
                ? Text('Free Delivery'.tr, textAlign: TextAlign.end, style: t.bodyStrong.withColor(c.successStrong))
                : Text(
                    Constant.amountShow(currency: currency, amount: controller.deliveryCharges.value.toString()),
                    textAlign: TextAlign.end,
                    style: t.bodyStrong.tabular,
                  ),
          ),

          /// Delivery Tips
          if (showTips)
            DsInfoRow(
              label: "Delivery Tips".tr,
              value: Constant.amountShow(currency: currency, amount: controller.deliveryTips.toString()),
              divider: true,
            ),

          if (driverTaxed)
            for (int index = 0; index < driverDeliveryTax.length; index++)
              DsInfoRow(
                label: "${driverDeliveryTax[index].title} ${'Tax on Delivery Fee'.tr}",
                value: Constant.amountShow(
                    currency: currency,
                    amount: Constant.calculateTax(
                      taxModel: driverDeliveryTax[index],
                      amount: (controller.deliveryCharges.value).toString(),
                    ).toString()),
                divider: true,
              ),

          /// To Pay
          DsInfoRow(
            label: "To Pay".tr,
            value: Constant.amountShow(currency: currency, amount: controller.totalAmount.value.toString()),
            emphasize: true,
            valueTone: DsTone.brand,
          ),
        ],
      ),
    );
  }
}

void showBillBifurcationDialog(BuildContext context, OrderDetailsController controller) {
  final currency = RegionService.currencyForRecord(controller.orderModel.value.regionId);
  final bool driverTaxed = controller.orderModel.value.takeAway != true && controller.orderModel.value.vendor?.isSelfDelivery != true;
  final driverDeliveryTax = controller.orderModel.value.driverDeliveryTax ?? [];
  final packagingTax = controller.orderModel.value.packagingTax ?? [];
  final platformTax = controller.orderModel.value.platformTax ?? [];

  showDialog(
    context: context,
    builder: (context) {
      return DsDialog(
        title: "Tax Details".tr,
        icon: Icons.percent_rounded,
        primaryLabel: "Close".tr,
        onPrimary: () => Navigator.pop(context),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            controller.orderModel.value.taxScope == 'product'
                ? DsInfoRow(
                    label: "Tax on item total".tr,
                    value: Constant.amountShow(currency: currency, amount: controller.productTaxAmount.value.toString()),
                    divider: true,
                  )
                : DsInfoRow(
                    label: "Tax on Order Total".tr,
                    value: Constant.amountShow(currency: currency, amount: controller.orderTaxAmount.value.toString()),
                    divider: true,
                  ),
            if (driverTaxed)
              for (int index = 0; index < driverDeliveryTax.length; index++)
                DsInfoRow(
                  label: "${driverDeliveryTax[index].title} ${'Tax on Delivery Fee'.tr}",
                  value: Constant.amountShow(
                      currency: currency,
                      amount: Constant.calculateTax(
                        taxModel: driverDeliveryTax[index],
                        amount: (controller.deliveryCharges.value).toString(),
                      ).toString()),
                  divider: true,
                ),
            for (int index = 0; index < packagingTax.length; index++)
              DsInfoRow(
                label: "${packagingTax[index].title} ${'Tax on Packaging Fee'.tr}",
                value: controller.packagingCharge.value == 0.0
                    ? Constant.amountShow(currency: currency, amount: controller.packagingCharge.value.toString())
                    : Constant.amountShow(
                        currency: currency,
                        amount: Constant.calculateTax(
                          taxModel: packagingTax[index],
                          amount: controller.packagingCharge.value.toString(),
                        ).toString()),
                divider: true,
              ),
            for (int index = 0; index < platformTax.length; index++)
              DsInfoRow(
                label: "${platformTax[index].title} ${'Tax on Platform Fee'.tr}",
                value: controller.platformFee.value == 0.0
                    ? Constant.amountShow(currency: currency, amount: controller.platformFee.value.toString())
                    : Constant.amountShow(
                        currency: currency,
                        amount: Constant.calculateTax(
                          taxModel: platformTax[index],
                          amount: controller.platformFee.value.toString(),
                        ).toString()),
                divider: true,
              ),
            DsInfoRow(
              label: "Total Tax Amount".tr,
              value: Constant.amountShow(currency: currency, amount: controller.totalTaxAmount.value.toString()),
              emphasize: true,
              valueTone: DsTone.brand,
            ),
          ],
        ),
      );
    },
  );
}

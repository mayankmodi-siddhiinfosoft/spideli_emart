import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/order_details_controller.dart';
import 'package:driver/models/cart_product_model.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/network_image_widget.dart';
import 'package:driver/widget/my_separator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:timelines_plus/timelines_plus.dart';

class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
        init: OrderDetailsController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            appBar: AppBar(
              backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
              centerTitle: false,
              titleSpacing: 0,
              title: Text(
                "Order Details".tr,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontFamily: AppThemeData.medium,
                  fontSize: 16,
                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                ),
              ),
            ),
            body: controller.isLoading.value
                ? Constant.loader()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${'Order'.tr} ${Constant.orderId(orderId: controller.orderModel.value.id.toString())}".tr,
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                        fontFamily: AppThemeData.semiBold,
                                        fontSize: 18,
                                        color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Constant.statusColor(status: controller.orderModel.value.status.toString()),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                                child: Text(
                                  controller.orderModel.value.status.toString().tr,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: AppThemeData.bold,
                                    fontSize: 14,
                                    color: Constant.statusText(status: controller.orderModel.value.status.toString()),
                                  ),
                                ),
                              )
                              // RoundedButtonFill(
                              //   title: controller.orderModel.value.status.toString().tr,
                              //   color: Constant.statusColor(status: controller.orderModel.value.status.toString()),
                              //   width: 32,
                              //   height: 4.5,
                              //   textColor: Constant.statusText(status: controller.orderModel.value.status.toString()),
                              //   onPress: () async {},
                              // ),
                            ],
                          ),
                          const SizedBox(
                            height: 14,
                          ),
                          Container(
                            decoration: ShapeDecoration(
                              color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: [
                                  Timeline.tileBuilder(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    physics: const NeverScrollableScrollPhysics(),
                                    theme: TimelineThemeData(
                                      nodePosition: 0,
                                      // indicatorPosition: 0,
                                    ),
                                    builder: TimelineTileBuilder.connected(
                                      contentsAlign: ContentsAlign.basic,
                                      indicatorBuilder: (context, index) {
                                        return SvgPicture.asset("assets/icons/ic_location.svg");
                                      },
                                      connectorBuilder: (context, index, connectorType) {
                                        return const DashedLineConnector(
                                          color: AppThemeData.grey300,
                                          gap: 3,
                                        );
                                      },
                                      contentsBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                          child: index == 0
                                              ? Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "${controller.orderModel.value.vendor!.title}",
                                                      textAlign: TextAlign.start,
                                                      style: TextStyle(
                                                        fontFamily: AppThemeData.semiBold,
                                                        fontSize: 16,
                                                        color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                                      ),
                                                    ),
                                                    Text(
                                                      "${controller.orderModel.value.vendor!.location}",
                                                      textAlign: TextAlign.start,
                                                      style: TextStyle(
                                                        fontFamily: AppThemeData.medium,
                                                        fontSize: 14,
                                                        color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "${controller.orderModel.value.address!.addressAs}",
                                                      textAlign: TextAlign.start,
                                                      style: TextStyle(
                                                        fontFamily: AppThemeData.semiBold,
                                                        fontSize: 16,
                                                        color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                                      ),
                                                    ),
                                                    Text(
                                                      controller.orderModel.value.author!.fullName(),
                                                      textAlign: TextAlign.start,
                                                      style: TextStyle(
                                                        fontFamily: AppThemeData.semiBold,
                                                        fontSize: 16,
                                                        color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                                      ),
                                                    ),
                                                    Text(
                                                      controller.orderModel.value.address!.getFullAddress(),
                                                      textAlign: TextAlign.start,
                                                      style: TextStyle(
                                                        fontFamily: AppThemeData.medium,
                                                        fontSize: 14,
                                                        color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        );
                                      },
                                      itemCount: 2,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 14,
                          ),
                          Text(
                            "Order Details".tr,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              fontFamily: AppThemeData.semiBold,
                              fontSize: 16,
                              color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Container(
                            decoration: ShapeDecoration(
                              color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: controller.orderModel.value.products!.length,
                                physics: const NeverScrollableScrollPhysics(),
                                itemBuilder: (context, index) {
                                  CartProductModel cartProductModel = controller.orderModel.value.products![index];
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          ClipRRect(
                                            borderRadius: const BorderRadius.all(Radius.circular(14)),
                                            child: Stack(
                                              children: [
                                                NetworkImageWidget(
                                                  imageUrl: cartProductModel.photo.toString(),
                                                  height: Responsive.height(8, context),
                                                  width: Responsive.width(16, context),
                                                  fit: BoxFit.cover,
                                                ),
                                                Container(
                                                  height: Responsive.height(8, context),
                                                  width: Responsive.width(16, context),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: const Alignment(-0.00, -1.00),
                                                      end: const Alignment(0, 1),
                                                      colors: [Colors.black.withOpacity(0), const Color(0xFF111827)],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 10,
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        "${cartProductModel.name}",
                                                        textAlign: TextAlign.start,
                                                        style: TextStyle(
                                                          fontFamily: AppThemeData.regular,
                                                          color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      "x ${cartProductModel.quantity}",
                                                      textAlign: TextAlign.start,
                                                      style: TextStyle(
                                                        fontFamily: AppThemeData.regular,
                                                        color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                double.parse(cartProductModel.discountPrice == null || cartProductModel.discountPrice!.isEmpty ? "0.0" : cartProductModel.discountPrice.toString()) <= 0
                                                    ? Text(
                                                        Constant.amountShow(amount: cartProductModel.price),
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                          fontFamily: AppThemeData.semiBold,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      )
                                                    : Row(
                                                        children: [
                                                          Text(
                                                            Constant.amountShow(amount: cartProductModel.discountPrice.toString()),
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                              fontFamily: AppThemeData.semiBold,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                          Text(
                                                            Constant.amountShow(amount: cartProductModel.price),
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              decoration: TextDecoration.lineThrough,
                                                              decorationColor: isDark ? AppThemeData.grey500 : AppThemeData.grey400,
                                                              color: isDark ? AppThemeData.grey500 : AppThemeData.grey400,
                                                              fontFamily: AppThemeData.semiBold,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      cartProductModel.variantInfo == null || cartProductModel.variantInfo!.variantOptions!.isEmpty
                                          ? Container()
                                          : Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "Variants".tr,
                                                    textAlign: TextAlign.start,
                                                    style: TextStyle(
                                                      fontFamily: AppThemeData.semiBold,
                                                      color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    height: 5,
                                                  ),
                                                  Wrap(
                                                    spacing: 6.0,
                                                    runSpacing: 6.0,
                                                    children: List.generate(
                                                      cartProductModel.variantInfo!.variantOptions!.length,
                                                      (i) {
                                                        return Container(
                                                          decoration: ShapeDecoration(
                                                            color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                          ),
                                                          child: Padding(
                                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                                            child: Text(
                                                              "${cartProductModel.variantInfo!.variantOptions!.keys.elementAt(i)} : ${cartProductModel.variantInfo!.variantOptions![cartProductModel.variantInfo!.variantOptions!.keys.elementAt(i)]}",
                                                              textAlign: TextAlign.start,
                                                              style: TextStyle(
                                                                fontFamily: AppThemeData.medium,
                                                                color: isDark ? AppThemeData.grey500 : AppThemeData.grey400,
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ).toList(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                      cartProductModel.extras == null || cartProductModel.extras!.isEmpty
                                          ? const SizedBox()
                                          : Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        "Addons".tr,
                                                        textAlign: TextAlign.start,
                                                        style: TextStyle(
                                                          fontFamily: AppThemeData.semiBold,
                                                          color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      Constant.amountShow(
                                                          amount: (double.parse(cartProductModel.extrasPrice.toString()) * double.parse(cartProductModel.quantity.toString())).toString()),
                                                      textAlign: TextAlign.start,
                                                      style: TextStyle(
                                                        fontFamily: AppThemeData.semiBold,
                                                        color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Wrap(
                                                  spacing: 6.0,
                                                  runSpacing: 6.0,
                                                  children: List.generate(
                                                    cartProductModel.extras!.length,
                                                    (i) {
                                                      return Container(
                                                        decoration: ShapeDecoration(
                                                          color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                        ),
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                                          child: Text(
                                                            cartProductModel.extras![i].toString(),
                                                            textAlign: TextAlign.start,
                                                            style: TextStyle(
                                                              fontFamily: AppThemeData.medium,
                                                              color: isDark ? AppThemeData.grey500 : AppThemeData.grey400,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ).toList(),
                                                ),
                                              ],
                                            ),
                                    ],
                                  );
                                },
                                separatorBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 14,
                          ),
                          Text(
                            "Bill Details".tr,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              fontFamily: AppThemeData.semiBold,
                              fontSize: 16,
                              color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          controller.orderModel.value.paymentMethod == 'cod'
                              ? Container(
                                  width: Responsive.width(100, context),
                                  decoration: ShapeDecoration(
                                    color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    shadows: const [
                                      BoxShadow(
                                        color: Color(0x14000000),
                                        blurRadius: 52,
                                      )
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                    child: Column(
                                      children: [
                                        /// Item Total
                                        amountRow(title: "Item totals".tr, amount: Constant.amountShow(amount: controller.subTotal.value.toString()), isDark: isDark),

                                        sectionDivider(isDark),

                                        /// Coupon Discount
                                        amountRow(
                                          title: "Coupon Discount",
                                          amount: "- (${Constant.amountShow(amount: controller.couponAmount.value.toString())})",
                                          isDark: isDark,
                                          amountColor: AppThemeData.danger300,
                                        ),

                                        sectionDivider(isDark),

                                        /// Special Discount
                                        if (controller.orderModel.value.vendor!.specialDiscountEnable == true) ...[
                                          // const SizedBox(height: 5),
                                          amountRow(
                                            title: "Special Discount",
                                            amount: "- (${Constant.amountShow(amount: controller.specialDiscountAmount.value.toString())})",
                                            isDark: isDark,
                                            amountColor: AppThemeData.danger300,
                                          ),
                                        ],
                                        if (controller.specialDiscountAmount.value > 0.0) const SizedBox(height: 5),

                                        /// Packaging
                                        amountRow(
                                          title: "Packaging charge",
                                          amount: Constant.amountShow(amount: controller.packagingCharge.value.toString()),
                                          isDark: isDark,
                                        ),

                                        sectionDivider(isDark),

                                        /// Delivery Fee
                                        if (controller.orderModel.value.takeAway == false)
                                          amountRow(
                                            title: "Delivery Fee".tr,
                                            isDark: isDark,
                                            trailing: (controller.orderModel.value.vendor!.isSelfDelivery == true || controller.orderModel.value.isFreeDelivery == true)
                                                ? Text(
                                                    'Free Delivery'.tr,
                                                    style: TextStyle(
                                                      fontFamily: AppThemeData.regular,
                                                      color: AppThemeData.success400,
                                                      fontSize: 16,
                                                    ),
                                                  )
                                                : Text(
                                                    Constant.amountShow(amount: controller.deliveryCharges.value.toString()),
                                                    style: TextStyle(
                                                      fontFamily: AppThemeData.regular,
                                                      color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                            amount: '',
                                          ),

                                        /// Delivery Tips
                                        if (!(controller.orderModel.value.takeAway == true ||
                                            controller.orderModel.value.vendor!.isSelfDelivery == true ||
                                            controller.orderModel.value.isFreeDelivery == true)) ...[
                                          const SizedBox(height: 10),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "Delivery Tips".tr,
                                                      style: TextStyle(
                                                        fontFamily: AppThemeData.regular,
                                                        color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    // if (controller.deliveryTips.value != 0)
                                                    //   InkWell(
                                                    //     onTap: () {
                                                    //       controller.deliveryTips.value = 0;
                                                    //       controller.calculatePrice();
                                                    //     },
                                                    //     child: Text(
                                                    //       "Remove".tr,
                                                    //       style: TextStyle(
                                                    //         fontFamily: AppThemeData.medium,
                                                    //         color: AppThemeData.primary300,
                                                    //       ),
                                                    //     ),
                                                    //   ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                Constant.amountShow(amount: controller.deliveryTips.toString()),
                                                style: TextStyle(
                                                  fontFamily: AppThemeData.regular,
                                                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (!(controller.orderModel.value.takeAway == true ||
                                            controller.orderModel.value.vendor!.isSelfDelivery == true ||
                                            controller.orderModel.value.isFreeDelivery == true))
                                          sectionDivider(isDark),

                                        /// Platform Fee
                                        amountRow(
                                          title: "Platform fee".tr,
                                          amount: Constant.amountShow(amount: controller.platformFee.value.toString()),
                                          isDark: isDark,
                                        ),

                                        sectionDivider(isDark),

                                        /// Tax
                                        InkWell(
                                          onTap: () {
                                            showBillBifurcationDialog(context, isDark, controller);
                                          },
                                          child: amountRow(
                                              title: "Tax amount",
                                              amount: Constant.amountShow(amount: controller.totalTaxAmount.value.toString()),
                                              isDark: isDark,
                                              textColour: AppThemeData.secondary300,
                                              underline: true),
                                        ),

                                        sectionDivider(isDark),

                                        /// To Pay
                                        amountRow(
                                          title: "To Pay".tr,
                                          amount: Constant.amountShow(amount: controller.totalAmount.value.toString()),
                                          amountColor: AppThemeData.primary300,
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Container(
                                  width: Responsive.width(100, context),
                                  decoration: ShapeDecoration(
                                    color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    shadows: const [
                                      BoxShadow(
                                        color: Color(0x14000000),
                                        blurRadius: 52,
                                      )
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                    child: Column(
                                      children: [
                                        /// Item Total

                                        amountRow(
                                          title: "Delivery Fee",
                                          isDark: isDark,
                                          trailing: (controller.orderModel.value.vendor!.isSelfDelivery == true || controller.orderModel.value.isFreeDelivery == true)
                                              ? Text(
                                                  'Free Delivery'.tr,
                                                  style: TextStyle(
                                                    fontFamily: AppThemeData.regular,
                                                    color: AppThemeData.success400,
                                                    fontSize: 16,
                                                  ),
                                                )
                                              : Text(
                                                  Constant.amountShow(amount: controller.deliveryCharges.value.toString()),
                                                  style: TextStyle(
                                                    fontFamily: AppThemeData.regular,
                                                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                          amount: '',
                                        ),

                                        /// Delivery Tips
                                        if (!(controller.orderModel.value.takeAway == true ||
                                            controller.orderModel.value.vendor!.isSelfDelivery == true ||
                                            controller.orderModel.value.isFreeDelivery == true)) ...[
                                          const SizedBox(height: 10),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "Delivery Tips".tr,
                                                      style: TextStyle(
                                                        fontFamily: AppThemeData.regular,
                                                        color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    // if (controller.deliveryTips.value != 0)
                                                    //   InkWell(
                                                    //     onTap: () {
                                                    //       controller.deliveryTips.value = 0;
                                                    //       controller.calculatePrice();
                                                    //     },
                                                    //     child: Text(
                                                    //       "Remove".tr,
                                                    //       style: TextStyle(
                                                    //         fontFamily: AppThemeData.medium,
                                                    //         color: AppThemeData.primary300,
                                                    //       ),
                                                    //     ),
                                                    //   ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                Constant.amountShow(amount: controller.deliveryTips.toString()),
                                                style: TextStyle(
                                                  fontFamily: AppThemeData.regular,
                                                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],

                                        sectionDivider(isDark),
                                        if (controller.orderModel.value.takeAway != true && controller.orderModel.value.vendor?.isSelfDelivery != true)
                                          ListView.builder(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: controller.orderModel.value.driverDeliveryTax?.length,
                                            itemBuilder: (context, index) {
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                                child: amountRow(
                                                  title: "${controller.orderModel.value.driverDeliveryTax![index].title} ${'Tax on Delivery Fee'.tr}",
                                                  amount: Constant.amountShow(
                                                      amount: Constant.calculateTax(
                                                    taxModel: controller.orderModel.value.driverDeliveryTax![index],
                                                    amount: (controller.deliveryCharges.value).toString(),
                                                  ).toString()),
                                                  isDark: isDark,
                                                ),
                                              );
                                            },
                                          ),
                                        if (controller.orderModel.value.takeAway != true && controller.orderModel.value.vendor?.isSelfDelivery != true) sectionDivider(isDark),

                                        /// To Pay
                                        amountRow(
                                          title: "To Pay".tr,
                                          amount: Constant.amountShow(amount: controller.totalAmount.value.toString()),
                                          amountColor: AppThemeData.primary300,
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          const SizedBox(
                            height: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
          );
        });
  }
}

Widget amountRow({
  required String title,
  required String amount,
  required bool isDark,
  Color? textColour,
  Color? amountColor,
  bool? underline,
  Widget? trailing,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          title.tr,
          style: TextStyle(
              fontFamily: AppThemeData.regular,
              color: textColour ?? (isDark ? AppThemeData.grey300 : AppThemeData.grey600),
              fontSize: 16,
              decoration: underline == true ? TextDecoration.underline : TextDecoration.none),
        ),
      ),
      trailing ??
          Text(
            amount,
            style: TextStyle(
              fontFamily: AppThemeData.regular,
              color: amountColor ?? (isDark ? AppThemeData.grey50 : AppThemeData.grey900),
              fontSize: 16,
            ),
          ),
    ],
  );
}

Widget sectionDivider(bool isDark) {
  return Column(
    children: [
      const SizedBox(height: 10),
      MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
      const SizedBox(height: 10),
    ],
  );
}

void showBillBifurcationDialog(BuildContext context, bool isDark, OrderDetailsController controller) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
        insetPadding: const EdgeInsets.symmetric(horizontal: 10), // 🔥 KEY FIX
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: Responsive.width(100, context), // ✅ 90% width
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Text(
                  "Tax Details".tr,
                  style: TextStyle(
                    fontFamily: AppThemeData.medium,
                    fontSize: 18,
                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                  ),
                ),
                const SizedBox(height: 5),
                sectionDivider(isDark),
                const SizedBox(height: 5),
                controller.orderModel.value.taxScope == 'product'
                    ? amountRow(
                        title: "Tax on item total".tr,
                        amount: Constant.amountShow(
                          amount: controller.productTaxAmount.value.toString(),
                        ),
                        isDark: isDark,
                      )
                    : amountRow(
                        title: "Tax on Order Total".tr,
                        amount: Constant.amountShow(
                          amount: controller.orderTaxAmount.value.toString(),
                        ),
                        isDark: isDark,
                      ),
                sectionDivider(isDark),
                if (controller.orderModel.value.takeAway != true && controller.orderModel.value.vendor?.isSelfDelivery != true)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: controller.orderModel.value.driverDeliveryTax?.length,
                    itemBuilder: (context, index) {
                      return amountRow(
                        title: "${controller.orderModel.value.driverDeliveryTax![index].title} ${'Tax on Delivery Fee'.tr}",
                        amount: Constant.amountShow(
                            amount: Constant.calculateTax(
                          taxModel: controller.orderModel.value.driverDeliveryTax![index],
                          amount: (controller.deliveryCharges.value).toString(),
                        ).toString()),
                        isDark: isDark,
                      );
                    },
                  ),
                if (controller.orderModel.value.takeAway != true && controller.orderModel.value.vendor?.isSelfDelivery != true) sectionDivider(isDark),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.orderModel.value.packagingTax!.length,
                  itemBuilder: (context, index) {
                    return amountRow(
                      title: "${controller.orderModel.value.packagingTax![index].title} ${'Tax on Packaging Fee'.tr}",
                      amount: controller.packagingCharge.value == 0.0
                          ? Constant.amountShow(amount: controller.packagingCharge.value.toString())
                          : Constant.amountShow(
                              amount: Constant.calculateTax(
                              taxModel: controller.orderModel.value.packagingTax![index],
                              amount: controller.packagingCharge.value.toString(),
                            ).toString()),
                      isDark: isDark,
                    );
                  },
                ),
                sectionDivider(isDark),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.orderModel.value.platformTax!.length,
                  itemBuilder: (context, index) {
                    return amountRow(
                      title: "${controller.orderModel.value.platformTax?[index].title} ${'Tax on Platform Fee'.tr}",
                      amount: controller.platformFee.value == 0.0
                          ? Constant.amountShow(amount: controller.platformFee.value.toString())
                          : Constant.amountShow(
                              amount: Constant.calculateTax(
                              taxModel: controller.orderModel.value.platformTax![index],
                              amount: controller.platformFee.value.toString(),
                            ).toString()),
                      isDark: isDark,
                    );
                  },
                ),
                sectionDivider(isDark),
                amountRow(
                  title: "Total Tax Amount".tr,
                  amount: Constant.amountShow(amount: controller.totalTaxAmount.value.toString()),
                  amountColor: AppThemeData.primary300,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Close".tr),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

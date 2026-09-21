import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/responsive.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/app/product_rating_view_screen/product_rating_view_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/order_details_controller.dart';
import 'package:vendor/models/cart_product_model.dart';
import 'package:vendor/models/order_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/utils/network_image_widget.dart';
import 'package:vendor/widget/my_separator.dart';

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
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            titleSpacing: 0,
            iconTheme: const IconThemeData(color: AppThemeData.grey50, size: 20),
            title: Text(
              "Order Summary".tr,
              style: TextStyle(color: AppThemeData.grey50, fontSize: 18, fontFamily: AppThemeData.medium),
            ),
          ),
          body: controller.isLoading.value
              ? Constant.loader()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${"Order".tr} ${Constant.orderId(orderId: controller.orderModel.value.id.toString())}",
                                    textAlign: TextAlign.start,
                                    style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 18, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                                  ),
                                ],
                              ),
                            ),
                            RoundedButtonFill(
                              title: controller.orderModel.value.status.toString().tr,
                              color: Constant.statusColor(status: controller.orderModel.value.status.toString()),
                              width: 32,
                              height: 4.2,
                              radius: 10,
                              textColor: Constant.statusText(status: controller.orderModel.value.status.toString()),
                              onPress: () async {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: Responsive.width(100, context),
                          decoration: ShapeDecoration(
                            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            shadows: const [BoxShadow(color: Color(0x14000000), blurRadius: 52)],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ClipOval(child: NetworkImageWidget(imageUrl: controller.orderModel.value.author!.profilePictureURL.toString(), width: 40, height: 40)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            controller.orderModel.value.author!.fullName().toString().tr,
                                            style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 14, fontFamily: AppThemeData.semiBold),
                                          ),
                                          controller.orderModel.value.takeAway == true
                                              ? Text(
                                                  "Take Away".tr,
                                                  style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontSize: 12, fontFamily: AppThemeData.medium),
                                                )
                                              : Text(
                                                  controller.orderModel.value.address?.getFullAddress() ?? ''.tr,
                                                  style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontSize: 12, fontFamily: AppThemeData.medium),
                                                ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                ),
                                ListView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: controller.orderModel.value.products!.length,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    CartProductModel product = controller.orderModel.value.products![index];
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "${product.quantity}x ${product.name}".tr,
                                                    style: TextStyle(
                                                      color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w500,
                                                      fontFamily: AppThemeData.semiBold,
                                                    ),
                                                  ),
                                                  product.taxSetting!.isEmpty
                                                      ? SizedBox()
                                                      : Text(
                                                          "Tax: ${Constant.getTaxDisplayText(product.taxSetting)}",
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontFamily: AppThemeData.semiBold),
                                                        ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  double.parse(product.discountPrice ?? "0.0") <= 0
                                                      ? Constant.amountShow(amount: (double.parse(product.price.toString()) * double.parse(product.quantity.toString())).toString())
                                                      : Constant.amountShow(amount: (double.parse(product.discountPrice.toString()) * double.parse(product.quantity.toString())).toString()).tr,
                                                  style: TextStyle(
                                                    color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    fontFamily: AppThemeData.semiBold,
                                                  ),
                                                ),
                                                InkWell(
                                                  splashColor: Colors.transparent,
                                                  onTap: () {
                                                    Get.to(const ProductRatingViewScreen(), arguments: {"orderModel": controller.orderModel.value, "productId": product.id});
                                                  },
                                                  child: Text(
                                                    "View Ratings".tr,
                                                    style: TextStyle(
                                                      color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                                      fontWeight: FontWeight.w500,
                                                      decoration: TextDecoration.underline,
                                                      fontFamily: AppThemeData.semiBold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        product.variantInfo == null || product.variantInfo!.variantOptions!.isEmpty
                                            ? Container()
                                            : Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "Variants".tr,
                                                      textAlign: TextAlign.start,
                                                      style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    Wrap(
                                                      spacing: 6.0,
                                                      runSpacing: 6.0,
                                                      children: List.generate(product.variantInfo!.variantOptions!.length, (i) {
                                                        return Container(
                                                          decoration: ShapeDecoration(
                                                            color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                          ),
                                                          child: Padding(
                                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                                            child: Text(
                                                              "${product.variantInfo!.variantOptions!.keys.elementAt(i)} : ${product.variantInfo!.variantOptions![product.variantInfo!.variantOptions!.keys.elementAt(i)]}",
                                                              textAlign: TextAlign.start,
                                                              style: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.grey500 : AppThemeData.grey400),
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                        product.extras == null || product.extras!.isEmpty
                                            ? const SizedBox()
                                            : Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          "Addons".tr,
                                                          textAlign: TextAlign.start,
                                                          style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16),
                                                        ),
                                                      ),
                                                      Text(
                                                        Constant.amountShow(amount: (double.parse(product.extrasPrice.toString()) * double.parse(product.quantity.toString())).toString()),
                                                        textAlign: TextAlign.start,
                                                        style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontSize: 16),
                                                      ),
                                                    ],
                                                  ),
                                                  Wrap(
                                                    spacing: 6.0,
                                                    runSpacing: 6.0,
                                                    children: List.generate(product.extras!.length, (i) {
                                                      return Container(
                                                        decoration: ShapeDecoration(
                                                          color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                        ),
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                                          child: Text(
                                                            product.extras![i].toString(),
                                                            textAlign: TextAlign.start,
                                                            style: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.grey500 : AppThemeData.grey400),
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ],
                                              ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                controller.orderModel.value.scheduleTime == null
                                    ? const SizedBox()
                                    : Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              "Schedule Time".tr,
                                              style: TextStyle(
                                                color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w400,
                                                fontFamily: AppThemeData.regular,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            Constant.timestampToDateTime(controller.orderModel.value.scheduleTime!).tr,
                                            style: TextStyle(
                                              color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              fontFamily: AppThemeData.semiBold,
                                            ),
                                          ),
                                        ],
                                      ),
                                const SizedBox(height: 5),
                                controller.orderModel.value.notes == null || controller.orderModel.value.notes!.isEmpty
                                    ? const SizedBox()
                                    : InkWell(
                                        splashColor: Colors.transparent,
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return viewRemarkDialog(controller, isDark, controller.orderModel.value);
                                            },
                                          );
                                        },
                                        child: Text(
                                          "View Remarks".tr,
                                          textAlign: TextAlign.start,
                                          style: TextStyle(
                                            fontFamily: AppThemeData.regular,
                                            decoration: TextDecoration.underline,
                                            color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: Responsive.width(100, context),
                          decoration: ShapeDecoration(
                            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            shadows: const [BoxShadow(color: Color(0x14000000), blurRadius: 52)],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            child: Column(
                              children: [
                                /// Item Total
                                amountRow(
                                  title: "Item totals".tr,
                                  amount: Constant.amountShow(amount: controller.subTotal.value.toString()),
                                  isDark: isDark,
                                ),

                                const SizedBox(height: 10),

                                /// Coupon Discount
                                amountRow(
                                  title: "Coupon Discount",
                                  amount: "- (${Constant.amountShow(amount: controller.couponAmount.value.toString())})",
                                  isDark: isDark,
                                  amountColor: AppThemeData.danger300,
                                ),

                                /// Special Discount
                                if (controller.orderModel.value.vendor?.specialDiscountEnable == true) ...[
                                  const SizedBox(height: 10),
                                  amountRow(
                                    title: "Special Discount",
                                    amount: "- (${Constant.amountShow(amount: controller.specialDiscountAmount.value.toString())})",
                                    isDark: isDark,
                                    amountColor: AppThemeData.danger300,
                                  ),
                                ],
                                if (controller.orderModel.value.packagingChargeEnable == true) const SizedBox(height: 10),

                                if (controller.orderModel.value.packagingChargeEnable == true)
                                  amountRow(
                                    title: "Packaging charge",
                                    amount: Constant.amountShow(amount: controller.packagingCharge.value.toString()),
                                    isDark: isDark,
                                  ),
                                if (controller.orderModel.value.packagingChargeEnable == true) const SizedBox(height: 10),
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
                                    textColour: AppThemeData.primary300,
                                    underline: true,
                                  ),
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
                        ),
                        if (controller.orderModel.value.takeAway != true &&
                            controller.orderModel.value.isPosOrder == false &&
                            (controller.orderModel.value.status == Constant.orderCompleted || controller.orderModel.value.status == Constant.orderInTransit))
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                              ),
                              Text(
                                "Delivery Man Information".tr,
                                style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16, fontWeight: FontWeight.w400, fontFamily: AppThemeData.semiBold),
                              ),
                              SizedBox(height: 12),
                              Row(
                                children: [
                                  ClipOval(
                                    child: NetworkImageWidget(imageUrl: controller.orderModel.value.driver?.profilePictureURL ?? '', width: 40, height: 40, fit: BoxFit.cover),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    controller.orderModel.value.driver?.fullName() ?? '',
                                                    style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 14, fontFamily: AppThemeData.medium),
                                                  ),
                                                  Text(
                                                    controller.orderModel.value.driver?.email ?? '',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontSize: 12, fontFamily: AppThemeData.medium),
                                                  ),
                                                ],
                                              ),
                                              Row(crossAxisAlignment: CrossAxisAlignment.center, mainAxisAlignment: MainAxisAlignment.start, children: []),
                                            ],
                                          ),
                                        ),
                                        InkWell(
                                          splashColor: Colors.transparent,
                                          onTap: () {
                                            Constant.makePhoneCall(controller.orderModel.value.driver?.phoneNumber ?? '');
                                          },
                                          child: Container(
                                            width: 42,
                                            height: 42,
                                            decoration: ShapeDecoration(
                                              shape: RoundedRectangleBorder(
                                                side: BorderSide(width: 1, color: isDark ? AppThemeData.grey200 : AppThemeData.grey400),
                                                borderRadius: BorderRadius.circular(120),
                                              ),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: SvgPicture.asset("assets/icons/ic_phone_call.svg", color: isDark ? AppThemeData.grey200 : AppThemeData.grey400),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: RoundedButtonFill(
                            title: "Print Invoice".tr,
                            color: AppThemeData.danger300,
                            textColor: AppThemeData.grey50,
                            height: 5,
                            onPress: () async {
                              controller.printTicket(context);
                            },
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

  Dialog viewRemarkDialog(OrderDetailsController controller, isDark, OrderModel orderModel) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
      child: SizedBox(
        width: 500,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Text(
                  orderModel.notes.toString(),
                  textAlign: TextAlign.start,
                  style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 18),
                ),
              ),
              RoundedButtonFill(
                title: "Cancel".tr,
                color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                textColor: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                onPress: () async {
                  Get.back();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget amountRow({required String title, required String amount, required bool isDark, Color? textColour, Color? amountColor, bool? underline, Widget? trailing}) {
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
              decoration: underline == true ? TextDecoration.underline : TextDecoration.none,
            ),
          ),
        ),
        trailing ??
            Text(
              amount,
              style: TextStyle(fontFamily: AppThemeData.regular, color: amountColor ?? (isDark ? AppThemeData.grey50 : AppThemeData.grey900), fontSize: 16),
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
                  SizedBox(height: 5),
                  Text(
                    "Tax Details".tr,
                    style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 18, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                  ),
                  const SizedBox(height: 16),
                  if (controller.productTaxAmount.value > 0)
                    amountRow(
                      title: "Tax on item total",
                      amount: Constant.amountShow(amount: controller.productTaxAmount.value.toString()),
                      isDark: isDark,
                    ),
                  if (controller.orderTaxAmount.value > 0)
                    amountRow(
                      title: "Tax on Order Total",
                      amount: Constant.amountShow(amount: controller.orderTaxAmount.value.toString()),
                      isDark: isDark,
                    ),
                  sectionDivider(isDark),
                  if (controller.packagingTaxAmount.value > 0)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: controller.orderModel.value.packagingTax!.length,
                      itemBuilder: (context, index) {
                        return amountRow(
                          title: "${controller.orderModel.value.packagingTax![index].title} ${'Tax on Packaging Fee'.tr}",
                          amount: Constant.amountShow(
                            amount: Constant.calculateTax(taxModel: controller.orderModel.value.packagingTax![index], amount: controller.packagingCharge.value.toString()).toString(),
                          ),
                          isDark: isDark,
                        );
                      },
                    ),
                  if (controller.packagingTaxAmount.value > 0) const SizedBox(height: 10),
                  if (controller.packagingTaxAmount.value > 0) sectionDivider(isDark),

                  /// To Pay
                  amountRow(
                    title: "Total Tax Amount",
                    amount: Constant.amountShow(amount: controller.totalTaxAmount.value.toString()),
                    amountColor: AppThemeData.primary300,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: () => Navigator.pop(context), child: Text("Close".tr)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

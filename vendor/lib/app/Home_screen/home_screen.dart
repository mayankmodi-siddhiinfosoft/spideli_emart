import 'package:bottom_picker/resources/extensions.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:vendor/app/store_screens/store_picker.dart';
import 'package:flutter_multi_formatter/flutter_multi_formatter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:uuid/uuid.dart';
import 'package:vendor/app/Home_screen/order_details_screen.dart';
import 'package:vendor/app/add_restaurant_screen/add_restaurant_screen.dart';
import 'package:vendor/app/chat_screens/chat_screen.dart';
import 'package:vendor/app/chat_screens/restaurant_inbox_screen.dart';
import 'package:vendor/app/driver_screens/add_driver_screen.dart';
import 'package:vendor/app/product_rating_view_screen/product_rating_view_screen.dart';
import 'package:vendor/app/verification_screen/verification_screen.dart';
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/send_notification.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/dash_board_controller.dart';
import 'package:vendor/controller/home_controller.dart';
import 'package:vendor/models/cart_product_model.dart';
import 'package:vendor/models/order_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/wallet_transaction_model.dart';
import 'package:vendor/service/audio_player_service.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/text_field_widget.dart';
import 'package:vendor/models/currency_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/region_service.dart';
import 'package:vendor/utils/network_image_widget.dart';
import 'package:vendor/widget/my_separator.dart';
import 'package:vendor/widget/wholesale_tag.dart';

import '../../themes/round_button_fill.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: HomeController(),
      builder: (controller) {
        return controller.isLoading.value
            ? Constant.loader()
            : DefaultTabController(
                length: 6,
                child: Scaffold(
                  appBar: _buildHomeHeader(context, controller, isDark),
                  body: controller.userModel.value.isAutoVerify == false && controller.userModel.value.isDocumentVerify == false
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                decoration: ShapeDecoration(
                                  color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                ),
                                child: Padding(padding: const EdgeInsets.all(20), child: SvgPicture.asset("assets/icons/ic_document.svg")),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Document Verification in Pending".tr,
                                style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 22, fontFamily: AppThemeData.semiBold),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "Your documents are being reviewed. We will notify you once the verification is complete.".tr,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.bold),
                              ),
                              const SizedBox(height: 20),
                              RoundedButtonFill(
                                title: "View Status".tr,
                                width: 55,
                                height: 5.5,
                                color: AppThemeData.primary300,
                                textColor: AppThemeData.grey50,
                                onPress: () async {
                                  Get.to(const VerificationScreen());
                                },
                              ),
                            ],
                          ),
                        )
                      : controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                decoration: ShapeDecoration(
                                  color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                ),
                                child: Padding(padding: const EdgeInsets.all(20), child: SvgPicture.asset("assets/icons/ic_building_two.svg")),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Add Your First Store".tr,
                                style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 22, fontFamily: AppThemeData.semiBold),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "Get started by adding your Store/Outlet details to manage your menu, orders, and reservations across the platform.".tr,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.bold),
                              ),
                              const SizedBox(height: 20),
                              RoundedButtonFill(
                                title: "Add Store".tr,
                                width: 55,
                                height: 5.5,
                                color: AppThemeData.primary300,
                                textColor: AppThemeData.grey50,
                                onPress: () async {
                                  Get.to(const AddRestaurantScreen())?.then((v) {
                                    controller.getUserProfile();
                                  });
                                },
                              ),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Constant.getEmployeeRolePermission(module: "Manage Order") == true
                              ? TabBarView(
                                  children: [
                                    controller.newOrderList.isEmpty
                                        ? _OrdersEmptyState(icon: Icons.receipt_long_outlined, title: "No new orders".tr, subtitle: "New orders appear here as soon as customers place them.".tr, isDark: isDark)
                                        : ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: controller.newOrderList.length,
                                            itemBuilder: (context, index) {
                                              OrderModel orderModel = controller.newOrderList[index];
                                              return newOrderWidget(isDark, context, orderModel, controller);
                                            },
                                          ),
                                    // Preparing and Ready both use the card of the former "Accepted"
                                    // tab, so every action it offered stays available.
                                    controller.preparingOrderList.isEmpty
                                        ? _OrdersEmptyState(icon: Icons.soup_kitchen_outlined, title: "No orders being prepared".tr, subtitle: "Orders you accept show here while they are being prepared or waiting for a driver.".tr, isDark: isDark)
                                        : ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: controller.preparingOrderList.length,
                                            itemBuilder: (context, index) {
                                              OrderModel orderModel = controller.preparingOrderList[index];
                                              return acceptedWidget(isDark, context, orderModel, controller);
                                            },
                                          ),
                                    controller.readyOrderList.isEmpty
                                        ? _OrdersEmptyState(icon: Icons.delivery_dining_outlined, title: "No orders ready".tr, subtitle: "Orders that are shipped or on their way to the customer show here.".tr, isDark: isDark)
                                        : ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: controller.readyOrderList.length,
                                            itemBuilder: (context, index) {
                                              OrderModel orderModel = controller.readyOrderList[index];
                                              return acceptedWidget(isDark, context, orderModel, controller);
                                            },
                                          ),
                                    controller.completedOrderList.isEmpty
                                        ? _OrdersEmptyState(icon: Icons.task_alt_rounded, title: "No completed orders".tr, subtitle: "Delivered and picked-up orders are listed here.".tr, isDark: isDark)
                                        : ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: controller.completedOrderList.length,
                                            itemBuilder: (context, index) {
                                              OrderModel orderModel = controller.completedOrderList[index];
                                              return completedAndRejectedWidget(isDark, context, orderModel, controller);
                                            },
                                          ),
                                    controller.rejectedOrderList.isEmpty
                                        ? _OrdersEmptyState(icon: Icons.block_rounded, title: "No rejected orders".tr, subtitle: "Orders you decline are kept here for reference.".tr, isDark: isDark)
                                        : ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: controller.rejectedOrderList.length,
                                            itemBuilder: (context, index) {
                                              OrderModel orderModel = controller.rejectedOrderList[index];
                                              return completedAndRejectedWidget(isDark, context, orderModel, controller);
                                            },
                                          ),
                                    controller.cancelledOrderList.isEmpty
                                        ? _OrdersEmptyState(icon: Icons.cancel_outlined, title: "No cancelled orders".tr, subtitle: "Orders cancelled by the store or the customer appear here.".tr, isDark: isDark)
                                        : ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: controller.cancelledOrderList.length,
                                            itemBuilder: (context, index) {
                                              OrderModel orderModel = controller.cancelledOrderList[index];
                                              return completedAndRejectedWidget(isDark, context, orderModel, controller);
                                            },
                                          ),
                                  ],
                                )
                              : Constant.showEmptyView(message: "You don’t have permission to view orders.".tr, isDark: isDark),
                        ),
                ),
              );
      },
    );
  }

  InkWell newOrderWidget(isDark, BuildContext context, OrderModel orderModel, HomeController controller) {
    // Amounts of an order are shown in the currency it was charged in.
    final CurrencyModel? orderCurrency = RegionService.currencyForOrder(orderModel.regionId);
    // Reset
    double subTotal = 0.0;
    double specialDiscountAmount = 0.0;
    double couponAmount = 0.0;
    double productTaxAmount = 0.0;
    double orderTaxAmount = 0.0;
    double packagingTaxAmount = 0.0;
    double totalTaxAmount = 0.0;
    double packagingCharge = 0.0;
    double totalAmount = 0.0;
    double adminCommission = 0.0;

    /// ---------------- SUBTOTAL ----------------
    for (var element in orderModel.products!) {
      final double price = element.unitPrice;

      final double qty = double.parse(element.quantity.toString());
      final double extras = double.parse(element.extrasPrice.toString());

      subTotal += (price * qty) + (extras * qty);
    }

    /// ---------------- DISCOUNTS ----------------
    couponAmount = double.parse(orderModel.discount.toString());

    if (orderModel.specialDiscount != null && orderModel.specialDiscount!['special_discount'] != null) {
      specialDiscountAmount = double.parse(orderModel.specialDiscount!['special_discount'].toString());
    }

    final double totalDiscount = couponAmount + specialDiscountAmount;

    /// ---------------- DISCOUNT RATIO ----------------
    double discountRatio = 0.0;
    if (subTotal > 0 && totalDiscount > 0) {
      discountRatio = totalDiscount / subTotal;
    }

    /// ---------------- PRODUCT TAX (AFTER DISCOUNT) ----------------
    if (orderModel.taxScope == "product") {
      for (var element in orderModel.products!) {
        final double price = element.unitPrice;

        final double qty = double.parse(element.quantity.toString());
        final double extras = double.parse(element.extrasPrice.toString());

        final double itemAmount = (price * qty) + (extras * qty);

        final double discountedItemAmount = itemAmount - (itemAmount * discountRatio);

        for (var taxElement in element.taxSetting!) {
          if (taxElement.type == "fix") {
            productTaxAmount += Constant.calculateTax(amount: discountedItemAmount.toString(), taxModel: taxElement) * qty;
          } else {
            productTaxAmount += Constant.calculateTax(amount: discountedItemAmount.toString(), taxModel: taxElement);
          }
        }
      }
    }

    /// ---------------- ORDER LEVEL TAX ----------------
    if (orderModel.taxScope == "order") {
      for (var taxElement in orderModel.taxSetting ?? []) {
        orderTaxAmount += Constant.calculateTax(amount: (subTotal - totalDiscount).toString(), taxModel: taxElement);
      }
    }

    packagingCharge = orderModel.packagingChargeEnable == true ? double.parse(orderModel.vendor!.packagingCharge.toString()) : 0.0;

    /// ---------------- PACKAGING TAX ----------------
    if (packagingCharge > 0) {
      for (var taxElement in orderModel.packagingTax ?? []) {
        packagingTaxAmount += Constant.calculateTax(amount: packagingCharge.toString(), taxModel: taxElement);
      }
    }

    /// ---------------- TOTAL TAX ----------------
    totalTaxAmount = productTaxAmount + orderTaxAmount + packagingTaxAmount;

    /// ---------------- FINAL TOTAL ----------------
    totalAmount = (subTotal - totalDiscount) + totalTaxAmount + packagingCharge;

    if (orderModel.adminCommissionType!.toLowerCase() == 'Percent'.toLowerCase() || orderModel.adminCommissionType!.toLowerCase() == 'percentage'.toLowerCase()) {
      double basePrice = subTotal / (1 + (double.parse(orderModel.adminCommission!) / 100));
      adminCommission = subTotal - basePrice;
    } else {
      adminCommission = double.parse(orderModel.adminCommission!);
    }

    return InkWell(
      onTap: () async {
        Get.to(const OrderDetailsScreen(), arguments: {"orderModel": orderModel});
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Container(
          decoration: ShapeDecoration(
            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipOval(
                      child: NetworkImageWidget(imageUrl: orderModel.author!.profilePictureURL.toString(), width: 40, height: 40, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            orderModel.author!.fullName().toString().tr,
                            style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 14, fontFamily: AppThemeData.semiBold),
                          ),
                          orderModel.takeAway == true
                              ? Text(
                                  "Take Away".tr,
                                  style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontSize: 12, fontFamily: AppThemeData.medium),
                                )
                              : Text(
                                  orderModel.address!.getFullAddress().tr,
                                  style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontSize: 12, fontFamily: AppThemeData.medium),
                                ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  itemCount: orderModel.products!.length,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    CartProductModel product = orderModel.products![index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${product.quantity}x ${product.name}".tr,
                                    style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 16, fontWeight: FontWeight.w500, fontFamily: AppThemeData.semiBold),
                                  ),
                                  WholesaleTag(product: product, isDark: isDark),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  Constant.amountShow(currency: orderCurrency, amount: (product.unitPrice * double.parse(product.quantity.toString())).toString()),
                                  style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 16, fontWeight: FontWeight.w500, fontFamily: AppThemeData.semiBold),
                                ),
                                InkWell(
                                  onTap: () {
                                    Get.to(const ProductRatingViewScreen(), arguments: {"orderModel": orderModel, "productId": product.id});
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
                                        Constant.amountShow(currency: orderCurrency, amount: (double.parse(product.extrasPrice.toString()) * double.parse(product.quantity.toString())).toString()),
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
                  separatorBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 10),
                      child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Order Date".tr,
                        style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16, fontWeight: FontWeight.w400, fontFamily: AppThemeData.regular),
                      ),
                    ),
                    Text(
                      Constant.timestampToDateTime(orderModel.createdAt!),
                      style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 14, fontWeight: FontWeight.w500, fontFamily: AppThemeData.semiBold),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Total Amount".tr,
                        style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16, fontWeight: FontWeight.w400, fontFamily: AppThemeData.regular),
                      ),
                    ),
                    Text(
                      Constant.amountShow(currency: orderCurrency, amount: totalAmount.toString()).tr,
                      style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 16, fontWeight: FontWeight.w500, fontFamily: AppThemeData.semiBold),
                    ),
                  ],
                ),
                Visibility(
                  visible: Constant.vendorAdminCommission?.isEnabled == true,
                  child: Column(
                    children: [
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Admin Commissions".tr,
                              style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16, fontWeight: FontWeight.w400, fontFamily: AppThemeData.regular),
                            ),
                          ),
                          Text(
                            "-${Constant.amountShow(currency: orderCurrency, amount: adminCommission.toString())}".tr,
                            style: TextStyle(color: isDark ? AppThemeData.danger300 : AppThemeData.danger300, fontSize: 16, fontWeight: FontWeight.w500, fontFamily: AppThemeData.semiBold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                orderModel.scheduleTime == null
                    ? const SizedBox()
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Schedule Time".tr,
                              style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16, fontWeight: FontWeight.w400, fontFamily: AppThemeData.regular),
                            ),
                          ),
                          Text(
                            Constant.timestampToDateTime(orderModel.scheduleTime!).tr,
                            style: TextStyle(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontSize: 16, fontWeight: FontWeight.w500, fontFamily: AppThemeData.semiBold),
                          ),
                        ],
                      ),
                const SizedBox(height: 5),
                orderModel.notes == null || orderModel.notes!.isEmpty
                    ? const SizedBox()
                    : InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return viewRemarkDialog(controller, isDark, orderModel);
                            },
                          );
                        },
                        child: Text(
                          "View Remarks".tr,
                          textAlign: TextAlign.start,
                          style: TextStyle(fontFamily: AppThemeData.regular, decoration: TextDecoration.underline, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontSize: 16),
                        ),
                      ),
                if (Constant.getEmployeeRolePermission(module: "Manage Order") == true)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: RoundedButtonFill(
                            title: "Reject".tr,
                            color: AppThemeData.danger300,
                            textColor: AppThemeData.grey50,
                            height: 5,
                            onPress: () async {
                              ShowToastDialog.showLoader('Please wait...'.tr);
                              await AudioPlayerService.playSound(false);
                              orderModel.status = Constant.orderRejected;
                              if (orderModel.cashback?.id != null && orderModel.cashback?.cashbackValue != null) {
                                await FireStoreUtils.deleteCashbackRedeem(orderModel);
                              }
                              await FireStoreUtils.updateOrder(orderModel);

                              SendNotification.sendFcmMessage(Constant.restaurantRejected, orderModel.author!.fcmToken.toString(), {});

                              if (orderModel.paymentMethod!.toLowerCase() != 'cod') {
                                double finalAmount =
                                    (subTotal + double.parse(orderModel.discount.toString()) + specialDiscountAmount + double.parse(totalTaxAmount.toString())) +
                                    double.parse(orderModel.deliveryCharge.toString()) +
                                    double.parse(orderModel.tipAmount.toString());

                                WalletTransactionModel historyModel = WalletTransactionModel(
                                  amount: finalAmount,
                                  id: const Uuid().v4(),
                                  orderId: orderModel.id,
                                  userId: orderModel.author!.id,
                                  date: Timestamp.now(),
                                  isTopup: true,
                                  paymentMethod: "Wallet",
                                  paymentStatus: "success",
                                  note: "Order Refund success",
                                  transactionUser: "user",
                                );

                                await FireStoreUtils.fireStore.collection(CollectionName.wallet).doc(historyModel.id).set(historyModel.toJson());
                                await FireStoreUtils.updateUserWallet(amount: finalAmount.toString(), userId: orderModel.author!.id.toString());
                              }

                              ShowToastDialog.closeLoader();
                              controller.getOrder();
                              Get.back();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Constant.isSelfDeliveryFeature == true && controller.vendermodel.value.isSelfDelivery == true && orderModel.takeAway == false
                              ? RoundedButtonFill(
                                  title: "Self Delivery".tr,
                                  height: 5,
                                  color: AppThemeData.success400,
                                  textColor: AppThemeData.grey50,
                                  onPress: () async {
                                    if ((Constant.isSubscriptionModelApplied == true || Constant.vendorAdminCommission?.isEnabled == true) && controller.vendermodel.value.subscriptionPlan != null) {
                                      if (controller.vendermodel.value.subscriptionTotalOrders == '0' || controller.vendermodel.value.subscriptionTotalOrders == null) {
                                        ShowToastDialog.closeLoader();
                                        ShowToastDialog.showToast(
                                          "You have reached the maximum order capacity for your current plan. Upgrade your subscription to continue accepting orders seamlessly!.".tr,
                                        );
                                        return;
                                      }
                                    }
                                    if (orderModel.scheduleTime != null) {
                                      if (DateTime.now().isAtSameMomentOrAfter(Constant.checkScheduleTime(scheduleDate: orderModel.scheduleTime!.toDate()))) {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return estimatedTimeDialog(controller, isDark, orderModel, context);
                                          },
                                        );
                                      } else {
                                        ShowToastDialog.showToast(
                                          "${"You can accept order on".tr} ${Constant.timestampToDateTime(Timestamp.fromDate(Constant.checkScheduleTime(scheduleDate: orderModel.scheduleTime!.toDate())))}.",
                                        );
                                      }
                                    } else {
                                      if (Constant.selectedSection!.isProductDetails == true && Constant.selectedSection!.name == "Restaurants") {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return estimatedTimeDialog(controller, isDark, orderModel, context);
                                          },
                                        );
                                      } else {
                                        if ((Constant.isSubscriptionModelApplied == true || Constant.vendorAdminCommission?.isEnabled == true) &&
                                            controller.vendermodel.value.subscriptionPlan != null) {
                                          if (controller.vendermodel.value.subscriptionTotalOrders != '-1' && controller.vendermodel.value.subscriptionTotalOrders != null) {
                                            controller.vendermodel.value.subscriptionTotalOrders = (int.parse(controller.vendermodel.value.subscriptionTotalOrders!) - 1).toString();
                                            await FireStoreUtils.updateVendor(controller.vendermodel.value);
                                          }
                                        }
                                        if (Constant.isSelfDeliveryFeature == true && controller.vendermodel.value.isSelfDelivery == true && orderModel.takeAway == false) {
                                          ShowToastDialog.showLoader('Please wait...'.tr);
                                          await controller.getAllDriverList();
                                          ShowToastDialog.closeLoader();
                                          Get.back();
                                          showDialog(
                                            // ignore: use_build_context_synchronously
                                            context: context,
                                            builder: (BuildContext context) {
                                              return showListOfDeliverymenDialog(controller, isDark, orderModel);
                                            },
                                          );
                                        } else {
                                          ShowToastDialog.showLoader('Please wait...'.tr);
                                          orderModel.status = Constant.orderAccepted;
                                          await AudioPlayerService.playSound(false);
                                          await FireStoreUtils.updateOrder(orderModel);
                                          await FireStoreUtils.restaurantVendorWalletSet(orderModel);
                                          SendNotification.sendFcmMessage(Constant.restaurantAccepted, orderModel.author!.fcmToken.toString(), {});

                                          ShowToastDialog.closeLoader();
                                          Get.back();
                                        }
                                      }
                                    }

                                    // if (orderModel.scheduleTime != null) {
                                    //   if (DateTime.now().isAtSameMomentOrAfter(
                                    //     Constant.checkScheduleTime(scheduleDate: orderModel.scheduleTime!.toDate()),
                                    //   )) {
                                    //     showDialog(
                                    //       context: context,
                                    //       builder: (BuildContext context) {
                                    //         return estimatedTimeDialog(controller, isDark, orderModel, context);
                                    //       },
                                    //     );
                                    //   } else {
                                    //     ShowToastDialog.showToast(
                                    //       "${"You can accept order on".tr} ${Constant.timestampToDateTime(Timestamp.fromDate(Constant.checkScheduleTime(scheduleDate: orderModel.scheduleTime!.toDate())))}.",
                                    //     );
                                    //   }
                                    // } else {
                                    //   controller.driverUserList.clear();
                                    //   controller.selectDriverUser.value = UserModel();
                                    //
                                    //   showDialog(
                                    //     context: context,
                                    //     builder: (BuildContext context) {
                                    //       return estimatedTimeDialog(controller, isDark, orderModel, context);
                                    //     },
                                    //   );
                                    // }
                                  },
                                )
                              : RoundedButtonFill(
                                  title: "Accept".tr,
                                  height: 5,
                                  color: AppThemeData.success400,
                                  textColor: AppThemeData.grey50,
                                  onPress: () async {
                                    if (Constant.selectedSection!.serviceTypeFlag == 'ecommerce-service') {
                                      await AudioPlayerService.playSound(false);
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return courierCompanyNameDialog(controller, isDark, orderModel, context);
                                        },
                                      );
                                    } else {
                                      if ((Constant.isSubscriptionModelApplied == true || Constant.vendorAdminCommission?.isEnabled == true) && controller.vendermodel.value.subscriptionPlan != null) {
                                        if (controller.vendermodel.value.subscriptionTotalOrders == '0' || controller.vendermodel.value.subscriptionTotalOrders == null) {
                                          ShowToastDialog.closeLoader();
                                          ShowToastDialog.showToast(
                                            "You have reached the maximum order capacity for your current plan. Upgrade your subscription to continue accepting orders seamlessly!.".tr,
                                          );
                                          return;
                                        }
                                      }
                                      if (orderModel.scheduleTime != null) {
                                        if (DateTime.now().isAtSameMomentOrAfter(Constant.checkScheduleTime(scheduleDate: orderModel.scheduleTime!.toDate()))) {
                                          showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return estimatedTimeDialog(controller, isDark, orderModel, context);
                                            },
                                          );
                                        } else {
                                          ShowToastDialog.showToast(
                                            "${"You can accept order on".tr} ${Constant.timestampToDateTime(Timestamp.fromDate(Constant.checkScheduleTime(scheduleDate: orderModel.scheduleTime!.toDate())))}.",
                                          );
                                        }
                                      } else {
                                        if (Constant.selectedSection!.isProductDetails == true && Constant.selectedSection!.name == "Restaurants" && orderModel.takeAway == false) {
                                          showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return estimatedTimeDialog(controller, isDark, orderModel, context);
                                            },
                                          );
                                        } else {
                                          if ((Constant.isSubscriptionModelApplied == true || Constant.vendorAdminCommission?.isEnabled == true) &&
                                              controller.vendermodel.value.subscriptionPlan != null) {
                                            if (controller.vendermodel.value.subscriptionTotalOrders != '-1' && controller.vendermodel.value.subscriptionTotalOrders != null) {
                                              controller.vendermodel.value.subscriptionTotalOrders = (int.parse(controller.vendermodel.value.subscriptionTotalOrders!) - 1).toString();
                                              await FireStoreUtils.updateVendor(controller.vendermodel.value);
                                            }
                                          }
                                          if (Constant.isSelfDeliveryFeature == true && controller.vendermodel.value.isSelfDelivery == true && orderModel.takeAway == false) {
                                            ShowToastDialog.showLoader('Please wait...'.tr);
                                            await controller.getAllDriverList();
                                            ShowToastDialog.closeLoader();
                                            Get.back();
                                            showDialog(
                                              // ignore: use_build_context_synchronously
                                              context: context,
                                              builder: (BuildContext context) {
                                                return showListOfDeliverymenDialog(controller, isDark, orderModel);
                                              },
                                            );
                                          } else {
                                            ShowToastDialog.showLoader('Please wait...'.tr);
                                            orderModel.status = Constant.orderAccepted;
                                            await AudioPlayerService.playSound(false);
                                            await FireStoreUtils.updateOrder(orderModel);
                                            await FireStoreUtils.restaurantVendorWalletSet(orderModel);
                                            SendNotification.sendFcmMessage(Constant.restaurantAccepted, orderModel.author!.fcmToken.toString(), {});

                                            ShowToastDialog.closeLoader();
                                            Get.back();
                                          }
                                        }
                                      }
                                    }
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InkWell acceptedWidget(isDark, BuildContext context, OrderModel orderModel, HomeController controller) {
    // Amounts of an order are shown in the currency it was charged in.
    final CurrencyModel? orderCurrency = RegionService.currencyForOrder(orderModel.regionId);
    // Reset
    double subTotal = 0.0;
    double specialDiscountAmount = 0.0;
    double couponAmount = 0.0;
    double productTaxAmount = 0.0;
    double orderTaxAmount = 0.0;
    double packagingTaxAmount = 0.0;
    double totalTaxAmount = 0.0;
    double packagingCharge = 0.0;
    double totalAmount = 0.0;
    double adminCommission = 0.0;

    /// ---------------- SUBTOTAL ----------------
    for (var element in orderModel.products!) {
      final double price = element.unitPrice;

      final double qty = double.parse(element.quantity.toString());
      final double extras = double.parse(element.extrasPrice.toString());

      subTotal += (price * qty) + (extras * qty);
    }

    /// ---------------- DISCOUNTS ----------------
    couponAmount = double.parse(orderModel.discount.toString());

    if (orderModel.specialDiscount != null && orderModel.specialDiscount!['special_discount'] != null) {
      specialDiscountAmount = double.parse(orderModel.specialDiscount!['special_discount'].toString());
    }

    final double totalDiscount = couponAmount + specialDiscountAmount;

    /// ---------------- DISCOUNT RATIO ----------------
    double discountRatio = 0.0;
    if (subTotal > 0 && totalDiscount > 0) {
      discountRatio = totalDiscount / subTotal;
    }

    /// ---------------- PRODUCT TAX (AFTER DISCOUNT) ----------------
    if (orderModel.taxScope == "product") {
      for (var element in orderModel.products!) {
        final double price = element.unitPrice;

        final double qty = double.parse(element.quantity.toString());
        final double extras = double.parse(element.extrasPrice.toString());

        final double itemAmount = (price * qty) + (extras * qty);

        final double discountedItemAmount = itemAmount - (itemAmount * discountRatio);

        for (var taxElement in element.taxSetting!) {
          if (taxElement.type == "fix") {
            productTaxAmount += Constant.calculateTax(amount: discountedItemAmount.toString(), taxModel: taxElement) * qty;
          } else {
            productTaxAmount += Constant.calculateTax(amount: discountedItemAmount.toString(), taxModel: taxElement);
          }
        }
      }
    }

    /// ---------------- ORDER LEVEL TAX ----------------
    if (orderModel.taxScope == "order") {
      for (var taxElement in orderModel.taxSetting ?? []) {
        orderTaxAmount += Constant.calculateTax(amount: (subTotal - totalDiscount).toString(), taxModel: taxElement);
      }
    }

    packagingCharge = orderModel.packagingChargeEnable == true ? double.parse(orderModel.vendor!.packagingCharge.toString()) : 0.0;

    /// ---------------- PACKAGING TAX ----------------
    if (packagingCharge > 0) {
      for (var taxElement in orderModel.packagingTax ?? []) {
        packagingTaxAmount += Constant.calculateTax(amount: packagingCharge.toString(), taxModel: taxElement);
      }
    }

    /// ---------------- TOTAL TAX ----------------
    totalTaxAmount = productTaxAmount + orderTaxAmount + packagingTaxAmount;

    /// ---------------- FINAL TOTAL ----------------
    totalAmount = (subTotal - totalDiscount) + totalTaxAmount + packagingCharge;

    if (orderModel.adminCommissionType!.toLowerCase() == 'Percent'.toLowerCase() || orderModel.adminCommissionType!.toLowerCase() == 'percentage'.toLowerCase()) {
      double basePrice = subTotal / (1 + (double.parse(orderModel.adminCommission!) / 100));
      adminCommission = subTotal - basePrice;
    } else {
      adminCommission = double.parse(orderModel.adminCommission!);
    }

    return InkWell(
      onTap: () async {
        Get.to(const OrderDetailsScreen(), arguments: {"orderModel": orderModel});
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Container(
          decoration: ShapeDecoration(
            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipOval(
                      child: NetworkImageWidget(imageUrl: orderModel.author!.profilePictureURL.toString(), width: 40, height: 40, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            orderModel.author!.fullName().toString().tr,
                            style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 14, fontFamily: AppThemeData.semiBold),
                          ),
                          orderModel.takeAway == true
                              ? Text(
                                  "Take Away".tr,
                                  style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontSize: 12, fontFamily: AppThemeData.medium),
                                )
                              : Text(
                                  orderModel.address!.getFullAddress().tr,
                                  style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontSize: 12, fontFamily: AppThemeData.medium),
                                ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: orderModel.products!.length,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    CartProductModel product = orderModel.products![index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${product.quantity}x ${product.name}".tr,
                                    style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 16, fontWeight: FontWeight.w500, fontFamily: AppThemeData.semiBold),
                                  ),
                                  WholesaleTag(product: product, isDark: isDark),
                                ],
                              ),
                            ),
                            Text(
                              Constant.amountShow(currency: orderCurrency, amount: (product.unitPrice * double.parse(product.quantity.toString())).toString()),
                              style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 16, fontWeight: FontWeight.w500, fontFamily: AppThemeData.semiBold),
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
                                        Constant.amountShow(currency: orderCurrency, amount: (double.parse(product.extrasPrice.toString()) * double.parse(product.quantity.toString())).toString()),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Order Date".tr,
                        style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16, fontWeight: FontWeight.w400, fontFamily: AppThemeData.regular),
                      ),
                    ),
                    Text(
                      Constant.timestampToDateTime(orderModel.createdAt!),
                      style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 14, fontWeight: FontWeight.w500, fontFamily: AppThemeData.semiBold),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Total Amount".tr,
                        style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16, fontWeight: FontWeight.w400, fontFamily: AppThemeData.regular),
                      ),
                    ),
                    Text(
                      Constant.amountShow(currency: orderCurrency, amount: totalAmount.toString()).tr,
                      style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 16, fontWeight: FontWeight.w500, fontFamily: AppThemeData.semiBold),
                    ),
                  ],
                ),
                Visibility(
                  visible: Constant.vendorAdminCommission?.isEnabled == true,
                  child: Column(
                    children: [
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Admin Commissions".tr,
                              style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16, fontWeight: FontWeight.w400, fontFamily: AppThemeData.regular),
                            ),
                          ),
                          Text(
                            "-${Constant.amountShow(currency: orderCurrency, amount: adminCommission.toString())}".tr,
                            style: TextStyle(color: isDark ? AppThemeData.danger300 : AppThemeData.danger300, fontSize: 16, fontWeight: FontWeight.w500, fontFamily: AppThemeData.semiBold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                orderModel.scheduleTime == null
                    ? const SizedBox()
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Schedule Time".tr,
                              style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16, fontWeight: FontWeight.w400, fontFamily: AppThemeData.regular),
                            ),
                          ),
                          Text(
                            Constant.timestampToDateTime(orderModel.scheduleTime!).tr,
                            style: TextStyle(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontSize: 16, fontWeight: FontWeight.w500, fontFamily: AppThemeData.semiBold),
                          ),
                        ],
                      ),
                const SizedBox(height: 5),
                orderModel.notes == null || orderModel.notes!.isEmpty
                    ? const SizedBox()
                    : InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return viewRemarkDialog(controller, isDark, orderModel);
                            },
                          );
                        },
                        child: Text(
                          "View Remarks".tr,
                          textAlign: TextAlign.start,
                          style: TextStyle(fontFamily: AppThemeData.regular, decoration: TextDecoration.underline, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontSize: 16),
                        ),
                      ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: RoundedButtonFill(
                          title: "Cancel Order".tr,
                          color: AppThemeData.danger300,
                          textColor: AppThemeData.grey50,
                          height: 5,
                          onPress: () async {
                            ShowToastDialog.showLoader('Please wait...'.tr);
                            orderModel.status = Constant.orderCancelled;
                            if (orderModel.driverID != null) {
                              UserModel? driverModel = await FireStoreUtils.getUserById(orderModel.driverID ?? '');
                              driverModel?.orderRequestData?.remove(orderModel.id);
                              driverModel?.inProgressOrderID?.remove(orderModel.id);
                              await FireStoreUtils.updateDriverUser(driverModel!);
                              SendNotification.sendFcmMessage(Constant.driverCancelled, driverModel.fcmToken.toString(), {'title': 'Cancelled Order'});
                            }
                            if (orderModel.cashback?.id != null && orderModel.cashback?.cashbackValue != null) {
                              await FireStoreUtils.deleteCashbackRedeem(orderModel);
                            }
                            await FireStoreUtils.updateOrder(orderModel);
                            SendNotification.sendFcmMessage(Constant.restaurantCancelled, orderModel.author!.fcmToken.toString(), {});

                            if (orderModel.paymentMethod!.toLowerCase() != 'cod') {
                              double finalAmount =
                                  (subTotal + double.parse(orderModel.discount.toString()) + specialDiscountAmount + double.parse(totalTaxAmount.toString())) +
                                  double.parse(orderModel.deliveryCharge.toString()) +
                                  double.parse(orderModel.tipAmount.toString());

                              WalletTransactionModel historyModel = WalletTransactionModel(
                                amount: finalAmount,
                                id: const Uuid().v4(),
                                orderId: orderModel.id,
                                userId: orderModel.author!.id,
                                date: Timestamp.now(),
                                isTopup: true,
                                paymentMethod: "Wallet",
                                paymentStatus: "success",
                                note: "Order Refund success",
                                transactionUser: "user",
                              );

                              await FireStoreUtils.fireStore.collection(CollectionName.wallet).doc(historyModel.id).set(historyModel.toJson());
                              await FireStoreUtils.updateUserWallet(amount: finalAmount.toString(), userId: orderModel.author!.id.toString());
                            }

                            // Reverse exactly what this order credited the store - read back
                            // from its wallet rows - rather than recomputing it: the recomputed
                            // figure left out the packaging charge, and an order that was never
                            // credited must not be debited at all.
                            final credited = await FireStoreUtils.netVendorCreditForOrder(orderModel.id.toString());
                            final String vendorOwnerId = (orderModel.vendor?.author ?? FireStoreUtils.getCurrentUid()).toString();
                            if (credited.total > 0) {
                              WalletTransactionModel historyTaxModel = WalletTransactionModel(
                                amount: credited.tax,
                                id: const Uuid().v4(),
                                orderId: orderModel.id,
                                userId: vendorOwnerId,
                                date: Timestamp.now(),
                                isTopup: false,
                                paymentMethod: "tax",
                                paymentStatus: "success",
                                note: "Order tax refunded to customer",
                                transactionUser: "vendor",
                              );

                              WalletTransactionModel historyModel = WalletTransactionModel(
                                amount: credited.orderAmount,
                                id: const Uuid().v4(),
                                orderId: orderModel.id,
                                userId: vendorOwnerId,
                                date: Timestamp.now(),
                                isTopup: false,
                                paymentMethod: "Wallet",
                                paymentStatus: "success",
                                note: "Order amount refunded to customer",
                                transactionUser: "vendor",
                              );

                              await FireStoreUtils.fireStore.collection(CollectionName.wallet).doc(historyTaxModel.id).set(historyTaxModel.toJson());
                              await FireStoreUtils.fireStore.collection(CollectionName.wallet).doc(historyModel.id).set(historyModel.toJson());
                              // Debit the store that took the order and its owner (not the
                              // logged-in user, who may be an employee).
                              await FireStoreUtils.adjustVendorWallet(
                                amount: -credited.total,
                                vendorId: (orderModel.vendorID ?? orderModel.vendor?.id).toString(),
                                ownerId: vendorOwnerId,
                              );
                            }
                            await controller.getOrder();
                            Get.back();
                            ShowToastDialog.closeLoader();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: orderModel.takeAway == true
                            ? RoundedButtonFill(
                                title: "Delivered".tr,
                                color: AppThemeData.primary300,
                                textColor: AppThemeData.grey50,
                                height: 5,
                                onPress: () async {
                                  ShowToastDialog.showLoader('Please wait...'.tr);
                                  orderModel.status = Constant.orderCompleted;
                                  if (orderModel.cashback?.cashbackValue != null && orderModel.cashback?.id != null) {
                                    WalletTransactionModel transactionModel = WalletTransactionModel(
                                      id: Constant.getUuid(),
                                      amount: double.parse("${orderModel.cashback?.cashbackValue ?? 0.0}"),
                                      date: Timestamp.now(),
                                      paymentMethod: "Cashback Amount",
                                      transactionUser: "user",
                                      userId: orderModel.author?.id,
                                      isTopup: true,
                                      orderId: orderModel.id,
                                      note: "Cashback Amount",
                                      paymentStatus: "success",
                                    );
                                    await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
                                      if (value == true) {
                                        await FireStoreUtils.updateUserWallet(
                                          amount: double.parse("${orderModel.cashback?.cashbackValue ?? 0.0}").toString(),
                                          userId: orderModel.author!.id.toString(),
                                        );
                                      }
                                    });
                                  }
                                  await FireStoreUtils.updateOrder(orderModel);
                                  await FireStoreUtils.restaurantVendorWalletSet(orderModel);
                                  SendNotification.sendFcmMessage(Constant.takeawayCompleted, orderModel.author!.fcmToken.toString(), {});

                                  ShowToastDialog.closeLoader();
                                },
                              )
                            : RoundedButtonFill(
                                title: Constant.selectedSection!.serviceTypeFlag == 'ecommerce-service' ? "Mark Deliver".tr : orderModel.status.toString(),
                                color: AppThemeData.primary300,
                                textColor: AppThemeData.grey50,
                                height: 5,
                                onPress: () async {
                                  if (Constant.selectedSection!.serviceTypeFlag == 'ecommerce-service') {
                                    ShowToastDialog.showLoader('Please wait...'.tr);
                                    orderModel.status = Constant.orderCompleted;
                                    await AudioPlayerService.playSound(false);
                                    await FireStoreUtils.updateOrder(orderModel);
                                    SendNotification.sendOneNotification(
                                      token: orderModel.author!.fcmToken.toString(),
                                      title: "Order Delivered".tr,
                                      body: "Your order has been delivered successfully".tr,
                                      payload: {},
                                    );
                                    controller.getOrder();
                                    ShowToastDialog.closeLoader();
                                  }
                                },
                              ),
                      ),
                      Visibility(
                        visible: controller.userModel.value.subscriptionPlan?.features?.chat != false,
                        child: Row(
                          children: [
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: () async {
                                ShowToastDialog.showLoader("Please wait".tr);

                                UserModel? customer = await FireStoreUtils.getUserById(orderModel.authorID.toString());
                                UserModel? restaurant = await FireStoreUtils.getUserProfile(orderModel.vendor!.author.toString());
                                // VendorModel? vendorModel = await FireStoreUtils.getVendorById(orderModel.vendorID.toString());
                                ShowToastDialog.closeLoader();

                                Get.to(
                                  const ChatScreen(),
                                  arguments: {
                                    "senderName": restaurant?.fullName(),
                                    "senderId": restaurant?.id,
                                    "senderProfileUrl": restaurant?.profilePictureURL,
                                    "receivedName": customer?.fullName(),
                                    "receivedId": customer?.id,
                                    "receivedProfileUrl": customer?.profilePictureURL,
                                    "orderId": orderModel.id,
                                    "token": restaurant?.fcmToken,
                                    "chatType": Constant.userRoleVendor,
                                  },
                                );
                              },
                              child: Container(
                                decoration: ShapeDecoration(
                                  color: AppThemeData.secondary50,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Padding(padding: const EdgeInsets.all(8.0), child: SvgPicture.asset("assets/icons/ic_message.svg")),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InkWell completedAndRejectedWidget(isDark, BuildContext context, OrderModel orderModel, HomeController controller) {
    // Amounts of an order are shown in the currency it was charged in.
    final CurrencyModel? orderCurrency = RegionService.currencyForOrder(orderModel.regionId);
    // Reset
    double subTotal = 0.0;
    double specialDiscountAmount = 0.0;
    double couponAmount = 0.0;
    double productTaxAmount = 0.0;
    double orderTaxAmount = 0.0;
    double packagingTaxAmount = 0.0;
    double totalTaxAmount = 0.0;
    double packagingCharge = 0.0;
    double totalAmount = 0.0;
    double adminCommission = 0.0;

    /// ---------------- SUBTOTAL ----------------
    for (var element in orderModel.products!) {
      final double price = element.unitPrice;

      final double qty = double.parse(element.quantity.toString());
      final double extras = double.parse(element.extrasPrice.toString());

      subTotal += (price * qty) + (extras * qty);
    }

    /// ---------------- DISCOUNTS ----------------
    couponAmount = double.parse(orderModel.discount.toString());

    if (orderModel.specialDiscount != null && orderModel.specialDiscount!['special_discount'] != null) {
      specialDiscountAmount = double.parse(orderModel.specialDiscount!['special_discount'].toString());
    }

    final double totalDiscount = couponAmount + specialDiscountAmount;

    /// ---------------- DISCOUNT RATIO ----------------
    double discountRatio = 0.0;
    if (subTotal > 0 && totalDiscount > 0) {
      discountRatio = totalDiscount / subTotal;
    }

    /// ---------------- PRODUCT TAX (AFTER DISCOUNT) ----------------
    if (orderModel.taxScope == "product") {
      for (var element in orderModel.products!) {
        final double price = element.unitPrice;

        final double qty = double.parse(element.quantity.toString());
        final double extras = double.parse(element.extrasPrice.toString());

        final double itemAmount = (price * qty) + (extras * qty);

        final double discountedItemAmount = itemAmount - (itemAmount * discountRatio);

        for (var taxElement in element.taxSetting!) {
          if (taxElement.type == "fix") {
            productTaxAmount += Constant.calculateTax(amount: discountedItemAmount.toString(), taxModel: taxElement) * qty;
          } else {
            productTaxAmount += Constant.calculateTax(amount: discountedItemAmount.toString(), taxModel: taxElement);
          }
        }
      }
    }

    /// ---------------- ORDER LEVEL TAX ----------------
    if (orderModel.taxScope == "order") {
      for (var taxElement in orderModel.taxSetting ?? []) {
        orderTaxAmount += Constant.calculateTax(amount: (subTotal - totalDiscount).toString(), taxModel: taxElement);
      }
    }

    packagingCharge = orderModel.packagingChargeEnable == true ? double.parse(orderModel.vendor!.packagingCharge.toString()) : 0.0;

    /// ---------------- PACKAGING TAX ----------------
    if (packagingCharge > 0) {
      for (var taxElement in orderModel.packagingTax ?? []) {
        packagingTaxAmount += Constant.calculateTax(amount: packagingCharge.toString(), taxModel: taxElement);
      }
    }

    /// ---------------- TOTAL TAX ----------------
    totalTaxAmount = productTaxAmount + orderTaxAmount + packagingTaxAmount;

    /// ---------------- FINAL TOTAL ----------------
    totalAmount = (subTotal - totalDiscount) + totalTaxAmount + packagingCharge;

    if (orderModel.adminCommissionType!.toLowerCase() == 'Percent'.toLowerCase() || orderModel.adminCommissionType!.toLowerCase() == 'percentage'.toLowerCase()) {
      double basePrice = subTotal / (1 + (double.parse(orderModel.adminCommission!) / 100));
      adminCommission = subTotal - basePrice;
    } else {
      adminCommission = double.parse(orderModel.adminCommission!);
    }

    return InkWell(
      onTap: () async {
        Get.to(const OrderDetailsScreen(), arguments: {"orderModel": orderModel});
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Container(
          decoration: ShapeDecoration(
            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipOval(
                      child: NetworkImageWidget(imageUrl: orderModel.author!.profilePictureURL.toString(), width: 40, height: 40, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            orderModel.author!.fullName().toString().tr,
                            style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 14, fontFamily: AppThemeData.semiBold),
                          ),
                          orderModel.takeAway == true
                              ? Text(
                                  "Take Away".tr,
                                  style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontSize: 12, fontFamily: AppThemeData.medium),
                                )
                              : Text(
                                  orderModel.address?.getFullAddress() ?? '',
                                  style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontSize: 12, fontFamily: AppThemeData.medium),
                                ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: orderModel.products!.length,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    CartProductModel product = orderModel.products![index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${product.quantity}x ${product.name}".tr,
                                    style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 16, fontWeight: FontWeight.w500, fontFamily: AppThemeData.semiBold),
                                  ),
                                  WholesaleTag(product: product, isDark: isDark),
                                ],
                              ),
                            ),
                            Text(
                              Constant.amountShow(currency: orderCurrency, amount: (product.unitPrice * double.parse(product.quantity.toString())).toString()),
                              style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 16, fontWeight: FontWeight.w500, fontFamily: AppThemeData.semiBold),
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
                                        Constant.amountShow(currency: orderCurrency, amount: (double.parse(product.extrasPrice.toString()) * double.parse(product.quantity.toString())).toString()),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Order Date".tr,
                        style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16, fontWeight: FontWeight.w400, fontFamily: AppThemeData.regular),
                      ),
                    ),
                    Text(
                      Constant.timestampToDateTime(orderModel.createdAt!),
                      style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 14, fontWeight: FontWeight.w500, fontFamily: AppThemeData.semiBold),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Total Amount".tr,
                        style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16, fontWeight: FontWeight.w400, fontFamily: AppThemeData.regular),
                      ),
                    ),
                    Text(
                      Constant.amountShow(currency: orderCurrency, amount: totalAmount.toString()).tr,
                      style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 16, fontWeight: FontWeight.w500, fontFamily: AppThemeData.semiBold),
                    ),
                  ],
                ),
                Visibility(
                  visible: Constant.vendorAdminCommission?.isEnabled == true,
                  child: Column(
                    children: [
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Admin Commissions".tr,
                              style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16, fontWeight: FontWeight.w400, fontFamily: AppThemeData.regular),
                            ),
                          ),
                          Text(
                            "-${Constant.amountShow(currency: orderCurrency, amount: adminCommission.toString())}".tr,
                            style: TextStyle(color: isDark ? AppThemeData.danger300 : AppThemeData.danger300, fontSize: 16, fontWeight: FontWeight.w500, fontFamily: AppThemeData.semiBold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                orderModel.scheduleTime == null
                    ? const SizedBox()
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Schedule Time".tr,
                              style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16, fontWeight: FontWeight.w400, fontFamily: AppThemeData.regular),
                            ),
                          ),
                          Text(
                            Constant.timestampToDateTime(orderModel.scheduleTime!).tr,
                            style: TextStyle(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontSize: 16, fontWeight: FontWeight.w500, fontFamily: AppThemeData.semiBold),
                          ),
                        ],
                      ),
                const SizedBox(height: 5),
                orderModel.notes == null || orderModel.notes!.isEmpty
                    ? const SizedBox()
                    : InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return viewRemarkDialog(controller, isDark, orderModel);
                            },
                          );
                        },
                        child: Text(
                          "View Remarks".tr,
                          textAlign: TextAlign.start,
                          style: TextStyle(fontFamily: AppThemeData.regular, decoration: TextDecoration.underline, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontSize: 16),
                        ),
                      ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: RoundedButtonFill(
                    title: orderModel.status.toString(),
                    color: orderModel.status == Constant.orderRejected ? AppThemeData.danger300 : AppThemeData.primary300,
                    textColor: AppThemeData.grey50,
                    height: 5,
                    onPress: () async {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Dialog showListOfDeliverymenDialog(HomeController controller, isDark, OrderModel orderModel) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
      child: SizedBox(
        width: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      "Select the delivery man".tr,
                      textAlign: TextAlign.start,
                      style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 18),
                    ),
                  ),
                  TextButton(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Add Delivery Man'.tr,
                        style: TextStyle(color: AppThemeData.primary300, fontFamily: AppThemeData.medium),
                      ),
                    ),
                    onPressed: () {
                      Get.to(AddDriverScreen())?.then((value) async {
                        if (value == true) {
                          Get.back();
                          ShowToastDialog.showToastDuration("Please ensure that the deliveryman is signed in and has an active status to assign the delivery.".tr, duration: Duration(seconds: 4));
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            Obx(
              () => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownSearch<UserModel>(
                  items: (String s, LoadProps? data) => controller.driverUserList,
                  selectedItem: controller.selectDriverUser.value,
                  compareFn: (UserModel a, UserModel b) => a.id == b.id,
                  itemAsString: (UserModel? user) => user == null || user.id == null ? "Select Delivery Man".tr : "${user.firstName} ${user.lastName}",
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        labelText: "Search Delivery Man".tr,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                    itemBuilder: (context, UserModel driver, bool isSelected, bool check) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text("${driver.firstName} ${driver.lastName}", style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14)),
                            ),
                            if (Constant.singleOrderReceive == true)
                              Expanded(
                                flex: 1,
                                child: driver.inProgressOrderID?.isEmpty == true
                                    ? Text(
                                        'Assign'.tr,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 12, color: AppThemeData.primary300),
                                      )
                                    : Text(
                                        'Occupied'.tr,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 12, color: AppThemeData.danger300),
                                      ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(labelText: "Select Delivery Man".tr, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16)),
                  ),
                  onSelected: (UserModel? value) {
                    if (value == null) return;

                    if (Constant.singleOrderReceive == true && value.inProgressOrderID?.isNotEmpty == true) {
                      ShowToastDialog.showToast("This delivery man is already assigned. Kindly select a different one.".tr);
                      return;
                    }

                    controller.selectDriverUser.value = value;
                  },
                ),
              ),
            ),
            SizedBox(height: 20),
            PreferredSize(
              preferredSize: const Size.fromHeight(4.0),
              child: Container(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200, height: 3.0),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: RoundedButtonFill(
                          title: "Cancel".tr,
                          color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                          textColor: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                          onPress: () async {
                            Get.back();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RoundedButtonFill(
                          title: "Order Assign".tr,
                          color: AppThemeData.primary300,
                          textColor: AppThemeData.grey50,
                          onPress: () async {
                            if (controller.selectDriverUser.value.id != null && controller.selectDriverUser.value.id != '') {
                              Get.back();
                              ShowToastDialog.showLoader('Please wait...'.tr);
                              await AudioPlayerService.playSound(false);

                              orderModel.notes = "";
                              orderModel.driverID = controller.selectDriverUser.value.id;
                              orderModel.driver = controller.selectDriverUser.value;
                              orderModel.status = Constant.orderInTransit;
                              controller.selectDriverUser.value.inProgressOrderID?.add(orderModel.id);

                              await FireStoreUtils.updateOrder(orderModel);
                              await FireStoreUtils.updateDriverUser(controller.selectDriverUser.value);
                              await FireStoreUtils.restaurantVendorWalletSet(orderModel);
                              SendNotification.sendFcmMessage(Constant.restaurantAccepted, orderModel.author!.fcmToken.toString(), {});
                              SendNotification.sendFcmMessage(Constant.newDeliveryOrder, orderModel.driver?.fcmToken ?? '', {});
                              ShowToastDialog.closeLoader();
                            } else {
                              ShowToastDialog.showToast("Please select the delivery man".tr);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Dialog estimatedTimeDialog(HomeController controller, isDark, OrderModel orderModel, BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
      child: SizedBox(
        width: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text(
                "Estimate time to prepare".tr,
                textAlign: TextAlign.start,
                style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 18),
              ),
            ),
            PreferredSize(
              preferredSize: const Size.fromHeight(4.0),
              child: Container(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200, height: 3.0),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  TextFieldWidget(
                    title: 'Estimated time to Prepare'.tr,
                    inputFormatters: [MaskedInputFormatter('##:##')],
                    controller: controller.estimatedTimeController.value,
                    hintText: '00:00'.tr,
                    textInputType: TextInputType.number,
                    prefix: const Icon(Icons.alarm),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: RoundedButtonFill(
                          title: "Cancel".tr,
                          color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                          textColor: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                          onPress: () async {
                            Get.back();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RoundedButtonFill(
                          title: "Shipped order".tr,
                          color: AppThemeData.primary300,
                          textColor: AppThemeData.grey50,
                          onPress: () async {
                            if (controller.estimatedTimeController.value.text.isNotEmpty) {
                              if ((Constant.isSubscriptionModelApplied == true || Constant.vendorAdminCommission?.isEnabled == true) && controller.vendermodel.value.subscriptionPlan != null) {
                                if (controller.vendermodel.value.subscriptionTotalOrders != '-1' && controller.vendermodel.value.subscriptionTotalOrders != null) {
                                  controller.vendermodel.value.subscriptionTotalOrders = (int.parse(controller.vendermodel.value.subscriptionTotalOrders!) - 1).toString();
                                  await FireStoreUtils.updateVendor(controller.vendermodel.value);
                                }
                              }
                              if (Constant.isSelfDeliveryFeature == true && controller.vendermodel.value.isSelfDelivery == true && orderModel.takeAway == false) {
                                ShowToastDialog.showLoader('Please wait...'.tr);
                                await controller.getAllDriverList();
                                ShowToastDialog.closeLoader();
                                orderModel.estimatedTimeToPrepare = controller.estimatedTimeController.value.text;
                                Get.back();
                                showDialog(
                                  // ignore: use_build_context_synchronously
                                  context: context,
                                  builder: (BuildContext context) {
                                    return showListOfDeliverymenDialog(controller, isDark, orderModel);
                                  },
                                );
                              } else {
                                ShowToastDialog.showLoader('Please wait...'.tr);
                                orderModel.estimatedTimeToPrepare = controller.estimatedTimeController.value.text;
                                orderModel.status = Constant.orderAccepted;
                                await AudioPlayerService.playSound(false);
                                await FireStoreUtils.updateOrder(orderModel);
                                await FireStoreUtils.restaurantVendorWalletSet(orderModel);
                                await SendNotification.sendFcmMessage(Constant.restaurantAccepted, orderModel.author!.fcmToken.toString(), {});
                                ShowToastDialog.closeLoader();
                                Get.back();
                              }
                            } else {
                              ShowToastDialog.showToast("Please enter estimated time".tr);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Dialog courierCompanyNameDialog(HomeController controller, isDark, OrderModel orderModel, BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
      child: SizedBox(
        width: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  TextFieldWidget(title: 'Courier company name'.tr, controller: controller.courierCompanyName.value, hintText: 'Enter Courier company name'.tr),
                  TextFieldWidget(title: 'Tracking Id'.tr, controller: controller.courierCompanyTrackingId.value, hintText: 'Enter Courier tracking Id'.tr),
                  Row(
                    children: [
                      Expanded(
                        child: RoundedButtonFill(
                          title: "Cancel".tr,
                          color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                          textColor: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                          onPress: () async {
                            Get.back();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RoundedButtonFill(
                          title: "Shipped order".tr,
                          color: AppThemeData.primary300,
                          textColor: AppThemeData.grey50,
                          onPress: () async {
                            if (controller.courierCompanyName.value.text.isEmpty) {
                              ShowToastDialog.showToast("Please enter courier company name".tr);
                            } else if (controller.courierCompanyTrackingId.value.text.isEmpty) {
                              ShowToastDialog.showToast("Please enter courier tracking id".tr);
                            } else {
                              ShowToastDialog.showLoader('Please wait...'.tr);
                              orderModel.courierCompanyName = controller.courierCompanyName.value.text;
                              orderModel.courierTrackingId = controller.courierCompanyTrackingId.value.text;
                              orderModel.status = Constant.orderShipped;
                              await AudioPlayerService.playSound(false);
                              await FireStoreUtils.updateOrder(orderModel);
                              await FireStoreUtils.restaurantVendorWalletSet(orderModel);
                              SendNotification.sendFcmMessage(Constant.restaurantAccepted, orderModel.author!.fcmToken.toString(), {});

                              ShowToastDialog.closeLoader();
                              Get.back();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Dialog viewRemarkDialog(HomeController controller, isDark, OrderModel orderModel) {
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

  /// Home header: who is signed in, the store being worked on (switchable for
  /// owners), and the order-status tabs.
  PreferredSizeWidget _buildHomeHeader(BuildContext context, HomeController controller, bool isDark) {
    final Color onBrand = isDark ? AppThemeData.grey900 : AppThemeData.grey50;
    final bool hasStore = (controller.userModel.value.vendorID ?? '').isNotEmpty;
    final bool canViewOrders = Constant.getEmployeeRolePermission(module: "Manage Order") == true;
    final double bottomHeight = (hasStore ? 80 : 0) + (canViewOrders ? 54 : 0);

    return AppBar(
      backgroundColor: AppThemeData.primary300,
      centerTitle: false,
      toolbarHeight: 72,
      titleSpacing: 16,
      title: Row(
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              DashBoardController dashBoardController = Get.find<DashBoardController>();
              dashBoardController.selectedIndex.value = Constant.selectedSection!.dineInActive == true ? 4 : 3;
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, color: onBrand.withValues(alpha: 0.4)),
              child: ClipOval(
                child: NetworkImageWidget(
                  imageUrl: controller.userModel.value.profilePictureURL.toString(),
                  height: 46,
                  width: 46,
                  fit: BoxFit.cover,
                  errorWidget: Image.asset("assets/images/user_placeholder.png"),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome to spideli Store".tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: onBrand.withValues(alpha: 0.85), fontSize: 13, fontFamily: AppThemeData.regular),
                ),
                const SizedBox(height: 2),
                Text(
                  controller.userModel.value.fullName().tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: onBrand, fontSize: 19, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Visibility(
          visible: controller.userModel.value.subscriptionPlan?.features?.chat != false,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Material(
              color: onBrand.withValues(alpha: 0.18),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Get.to(const RestaurantInboxScreen()),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: SvgPicture.asset("assets/icons/ic_chat.svg", width: 22, height: 22, colorFilter: ColorFilter.mode(onBrand, BlendMode.srcIn)),
                ),
              ),
            ),
          ),
        ),
      ],
      bottom: bottomHeight == 0
          ? null
          : PreferredSize(
              preferredSize: Size.fromHeight(bottomHeight),
              child: Column(
                children: [
                  if (hasStore)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: CurrentStoreCard(
                        storeName: controller.vendermodel.value.title,
                        storePhoto: controller.vendermodel.value.photo,
                        isDark: isDark,
                      ),
                    ),
                  if (canViewOrders)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(
                        height: 44,
                        child: TabBar(
                          onTap: (value) {
                            controller.selectedTabIndex.value = value;
                          },
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          splashBorderRadius: BorderRadius.circular(22),
                          // Selected status: a white pill with brand-coloured text.
                          indicator: BoxDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, borderRadius: BorderRadius.circular(22)),
                          labelColor: AppThemeData.primary300,
                          unselectedLabelColor: onBrand.withValues(alpha: 0.9),
                          labelStyle: const TextStyle(fontSize: 15, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                          unselectedLabelStyle: const TextStyle(fontSize: 15, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
                          tabs: [
                            for (final label in ["New", "Preparing", "Ready", "Completed", "Rejected", "Cancelled"])
                              Tab(
                                height: 40,
                                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(label.tr)),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

}

/// Empty state for an order tab: an icon, what's missing, and what will
/// appear there.
class _OrdersEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  const _OrdersEmptyState({required this.icon, required this.title, required this.subtitle, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? AppThemeData.grey800 : AppThemeData.primary600),
              child: Icon(icon, size: 42, color: AppThemeData.primary300),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 19, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontSize: 14, height: 1.4, fontFamily: AppThemeData.regular),
            ),
          ],
        ),
      ),
    );
  }
}

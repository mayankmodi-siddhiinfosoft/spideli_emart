import 'package:bottom_picker/resources/extensions.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendor/app/store_screens/store_picker.dart';
import 'package:flutter_multi_formatter/flutter_multi_formatter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:uuid/uuid.dart';
import 'package:vendor/app/Home_screen/order_details_screen.dart';
import 'package:vendor/app/add_restaurant_screen/add_restaurant_screen.dart';
import 'package:vendor/app/chat_screens/chat_screen.dart';
import 'package:vendor/app/chat_screens/restaurant_inbox_screen.dart';
import 'package:vendor/app/driver_screens/add_driver_screen.dart';
import 'package:vendor/app/product_rating_view_screen/product_rating_view_screen.dart';
import 'package:vendor/app/verification_screen/verification_screen.dart';
import 'package:vendor/app/widgets/order_ui.dart';
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
import 'package:vendor/models/currency_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/region_service.dart';
import 'package:vendor/widget/wholesale_tag.dart';

/// Store dashboard: a brand hero (who is signed in, the current store with its
/// switcher, and a live order-pipeline KPI strip), a pinned order-status tab
/// bar with live counts, and one order feed per status.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: HomeController(),
      builder: (controller) {
        if (controller.isLoading.value) return const _HomeSkeleton();

        final c = context.dsColors;
        final bool isVerificationPending = controller.userModel.value.isAutoVerify == false && controller.userModel.value.isDocumentVerify == false;
        final bool hasNoStore = controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty;
        final bool canViewOrders = Constant.getEmployeeRolePermission(module: "Manage Order") == true;

        // Read every list here, inside the GetX builder, so the screen rebuilds
        // whenever orders change (tab bodies are built lazily, outside it).
        final List<OrderModel> newOrders = controller.newOrderList.toList();
        final List<OrderModel> preparingOrders = controller.preparingOrderList.toList();
        final List<OrderModel> readyOrders = controller.readyOrderList.toList();
        final List<OrderModel> completedOrders = controller.completedOrderList.toList();
        final List<OrderModel> rejectedOrders = controller.rejectedOrderList.toList();
        final List<OrderModel> cancelledOrders = controller.cancelledOrderList.toList();
        final List<int> counts = [
          newOrders.length,
          preparingOrders.length,
          readyOrders.length,
          completedOrders.length,
          rejectedOrders.length,
          cancelledOrders.length,
        ];

        final LinearGradient brand = DsGradients.brand(context);
        // Vertical, so the status-bar strip and the hero meet without a seam.
        final LinearGradient heroGradient = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: brand.colors);
        final bool showsOrders = !isVerificationPending && !hasNoStore && canViewOrders;
        final Widget header = _buildHomeHeader(context, controller, isDark, gradient: heroGradient, counts: showsOrders ? counts : null);
        final double tabsExtent = 32 + MediaQuery.textScalerOf(context).scale(28);

        final Widget body;
        if (isVerificationPending) {
          body = _HomeStateView(
            svgAsset: "assets/icons/ic_document.svg",
            tone: DsTone.warning,
            title: "Document Verification in Pending".tr,
            message: "Your documents are being reviewed. We will notify you once the verification is complete.".tr,
            actionLabel: "View Status".tr,
            actionIcon: Icons.fact_check_outlined,
            onAction: () async {
              Get.to(const VerificationScreen());
            },
          );
        } else if (hasNoStore) {
          body = _HomeStateView(
            svgAsset: "assets/icons/ic_building_two.svg",
            tone: DsTone.brand,
            title: "Add Your First Store".tr,
            message: "Get started by adding your Store/Outlet details to manage your menu, orders, and reservations across the platform.".tr,
            actionLabel: "Add Store".tr,
            actionIcon: Icons.add_business_outlined,
            onAction: () async {
              Get.to(const AddRestaurantScreen())?.then((v) {
                controller.getUserProfile();
              });
            },
          );
        } else if (canViewOrders) {
          body = TabBarView(
            children: [
              _ordersTab(
                storageKey: 'orders-new',
                orders: newOrders,
                emptyIcon: Icons.receipt_long_outlined,
                emptyTitle: "No new orders".tr,
                emptyMessage: "New orders appear here as soon as customers place them.".tr,
                itemBuilder: (context, orderModel) => newOrderWidget(isDark, context, orderModel, controller),
              ),
              // Preparing and Ready both use the card of the former "Accepted"
              // tab, so every action it offered stays available.
              _ordersTab(
                storageKey: 'orders-preparing',
                orders: preparingOrders,
                emptyIcon: Icons.soup_kitchen_outlined,
                emptyTitle: "No orders being prepared".tr,
                emptyMessage: "Orders you accept show here while they are being prepared or waiting for a driver.".tr,
                itemBuilder: (context, orderModel) => acceptedWidget(isDark, context, orderModel, controller),
              ),
              _ordersTab(
                storageKey: 'orders-ready',
                orders: readyOrders,
                emptyIcon: Icons.delivery_dining_outlined,
                emptyTitle: "No orders ready".tr,
                emptyMessage: "Orders that are shipped or on their way to the customer show here.".tr,
                itemBuilder: (context, orderModel) => acceptedWidget(isDark, context, orderModel, controller),
              ),
              _ordersTab(
                storageKey: 'orders-completed',
                orders: completedOrders,
                emptyIcon: Icons.task_alt_rounded,
                emptyTitle: "No completed orders".tr,
                emptyMessage: "Delivered and picked-up orders are listed here.".tr,
                itemBuilder: (context, orderModel) => completedAndRejectedWidget(isDark, context, orderModel, controller),
              ),
              _ordersTab(
                storageKey: 'orders-rejected',
                orders: rejectedOrders,
                emptyIcon: Icons.block_rounded,
                emptyTitle: "No rejected orders".tr,
                emptyMessage: "Orders you decline are kept here for reference.".tr,
                emptyTone: DsTone.neutral,
                itemBuilder: (context, orderModel) => completedAndRejectedWidget(isDark, context, orderModel, controller),
              ),
              _ordersTab(
                storageKey: 'orders-cancelled',
                orders: cancelledOrders,
                emptyIcon: Icons.cancel_outlined,
                emptyTitle: "No cancelled orders".tr,
                emptyMessage: "Orders cancelled by the store or the customer appear here.".tr,
                emptyTone: DsTone.neutral,
                itemBuilder: (context, orderModel) => completedAndRejectedWidget(isDark, context, orderModel, controller),
              ),
            ],
          );
        } else {
          body = DsEmptyState(icon: Icons.lock_outline_rounded, tone: DsTone.neutral, compact: true, title: "You don’t have permission to view orders.".tr);
        }

        return DefaultTabController(
          length: 6,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: Scaffold(
              backgroundColor: c.background,
              body: Column(
                children: [
                  // Status-bar strip: the hero scrolls away beneath it and the
                  // pinned tab bar stops right under it.
                  Container(height: MediaQuery.paddingOf(context).top, color: heroGradient.colors.first),
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: NestedScrollView(
                        headerSliverBuilder: (context, innerBoxIsScrolled) => [
                          SliverToBoxAdapter(child: header),
                          if (canViewOrders)
                            SliverOverlapAbsorber(
                              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                              sliver: SliverPersistentHeader(
                                pinned: true,
                                delegate: _OrderTabsHeader(
                                  extent: tabsExtent,
                                  counts: counts,
                                  onTap: (value) {
                                    controller.selectedTabIndex.value = value;
                                  },
                                ),
                              ),
                            ),
                        ],
                        body: body,
                      ),
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

  /// One order feed: a single column on phones, 2-3 columns on tablets.
  Widget _ordersTab({
    required String storageKey,
    required List<OrderModel> orders,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptyMessage,
    DsTone emptyTone = DsTone.brand,
    required Widget Function(BuildContext context, OrderModel orderModel) itemBuilder,
  }) {
    return Builder(
      builder: (context) {
        final l = context.dsLayout;
        final double inset = l.horizontalInsetFor(DsLayout.wideMax);
        final double available = l.width - inset * 2;
        final int columns = available >= 1060 ? 3 : (available >= 680 ? 2 : 1);
        final int rows = (orders.length / columns).ceil();
        return CustomScrollView(
          key: PageStorageKey<String>(storageKey),
          slivers: [
            SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
            if (orders.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(icon: emptyIcon, tone: emptyTone, compact: true, title: emptyTitle, message: emptyMessage),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(inset, DsSpace.sm, inset, DsSpace.xxxl),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, row) {
                    if (columns == 1) {
                      final OrderModel orderModel = orders[row];
                      return Padding(
                        key: ValueKey('${orderModel.id}'),
                        padding: const EdgeInsets.only(bottom: DsSpace.md),
                        child: DsFadeSlideIn(index: row, child: itemBuilder(context, orderModel)),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: DsSpace.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int j = 0; j < columns; j++) ...[
                            if (j > 0) DsGap.md,
                            Expanded(
                              child: row * columns + j < orders.length
                                  ? DsFadeSlideIn(
                                      key: ValueKey('${orders[row * columns + j].id}'),
                                      index: row * columns + j,
                                      child: itemBuilder(context, orders[row * columns + j]),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    );
                  }, childCount: rows),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget newOrderWidget(isDark, BuildContext context, OrderModel orderModel, HomeController controller) {
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

    final c = context.dsColors;
    return _orderCard(
      context,
      orderModel: orderModel,
      orderCurrency: orderCurrency,
      isDark: isDark,
      addressText: orderModel.takeAway == true ? "Take Away".tr : orderModel.address!.getFullAddress().tr,
      totalAmount: totalAmount,
      adminCommission: adminCommission,
      showRatings: true,
      onViewRemarks: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return viewRemarkDialog(controller, isDark, orderModel);
          },
        );
      },
      actions: Constant.getEmployeeRolePermission(module: "Manage Order") == true
          ? Row(
              children: [
                Expanded(
                  child: DsButton.dangerTonal(
                    label: "Reject".tr,
                    icon: Icons.close_rounded,
                    onPressed: () async {
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

                      // A new order is normally rejected before anything was
                      // credited, but a POS / panel-created order can already
                      // carry a credit. Guarded: an order that was never
                      // credited is not debited.
                      await FireStoreUtils.reverseVendorCreditForOrder(orderModel);

                      ShowToastDialog.closeLoader();
                      controller.getOrder();
                      Get.back();
                    },
                  ),
                ),
                DsGap.md,
                Expanded(
                  child: Constant.isSelfDeliveryFeature == true && controller.vendermodel.value.isSelfDelivery == true && orderModel.takeAway == false
                      ? DsButton.primary(
                          label: "Self Delivery".tr,
                          icon: Icons.delivery_dining_rounded,
                          color: c.success,
                          onPressed: () async {
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
                      : DsButton.primary(
                          label: "Accept".tr,
                          icon: Icons.check_rounded,
                          color: c.success,
                          onPressed: () async {
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
            )
          : null,
    );
  }

  Widget acceptedWidget(isDark, BuildContext context, OrderModel orderModel, HomeController controller) {
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

    return _orderCard(
      context,
      orderModel: orderModel,
      orderCurrency: orderCurrency,
      isDark: isDark,
      addressText: orderModel.takeAway == true ? "Take Away".tr : orderModel.address!.getFullAddress().tr,
      totalAmount: totalAmount,
      adminCommission: adminCommission,
      showRatings: false,
      onViewRemarks: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return viewRemarkDialog(controller, isDark, orderModel);
          },
        );
      },
      actions: Row(
        children: [
          Expanded(
            child: DsButton.dangerTonal(
              label: "Cancel Order".tr,
              onPressed: () async {
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
                await FireStoreUtils.reverseVendorCreditForOrder(orderModel);
                await controller.getOrder();
                Get.back();
                ShowToastDialog.closeLoader();
              },
            ),
          ),
          DsGap.md,
          Expanded(
            child: orderModel.takeAway == true
                ? DsButton.primary(
                    label: "Delivered".tr,
                    icon: Icons.task_alt_rounded,
                    onPressed: () async {
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
                : DsButton.primary(
                    label: Constant.selectedSection!.serviceTypeFlag == 'ecommerce-service' ? "Mark Deliver".tr : orderModel.status.toString(),
                    onPressed: () async {
                      if (Constant.selectedSection!.serviceTypeFlag == 'ecommerce-service') {
                        ShowToastDialog.showLoader('Please wait...'.tr);
                        orderModel.status = Constant.orderCompleted;
                        await AudioPlayerService.playSound(false);
                        await FireStoreUtils.updateOrder(orderModel);
                        // Last completion path that never credited the store
                        // (APP-SPEC-STORE.md §2). Idempotent: an order already
                        // credited on Accept / Shipped is skipped.
                        await FireStoreUtils.restaurantVendorWalletSet(orderModel);
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
          if (controller.userModel.value.subscriptionPlan?.features?.chat != false) ...[
            DsGap.sm,
            DsIconButton(
              semanticLabel: "Chat".tr,
              variant: DsIconButtonVariant.brand,
              size: 48,
              onPressed: () async {
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
              child: SvgPicture.asset("assets/icons/ic_message.svg", width: 22, height: 22),
            ),
          ],
        ],
      ),
    );
  }

  Widget completedAndRejectedWidget(isDark, BuildContext context, OrderModel orderModel, HomeController controller) {
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

    return _orderCard(
      context,
      orderModel: orderModel,
      orderCurrency: orderCurrency,
      isDark: isDark,
      addressText: orderModel.takeAway == true ? "Take Away".tr : orderModel.address?.getFullAddress() ?? '',
      totalAmount: totalAmount,
      adminCommission: adminCommission,
      showRatings: false,
      onViewRemarks: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return viewRemarkDialog(controller, isDark, orderModel);
          },
        );
      },
      actions: _StatusBanner(status: orderModel.status.toString(), tone: orderModel.status == Constant.orderRejected ? DsTone.danger : DsTone.fromStatus(orderModel.status)),
    );
  }

  /// The shared order card: customer, status chips + progress track, items,
  /// a summary panel and the tab-specific [actions].
  Widget _orderCard(
    BuildContext context, {
    required OrderModel orderModel,
    required CurrencyModel? orderCurrency,
    required bool isDark,
    required String addressText,
    required double totalAmount,
    required double adminCommission,
    required bool showRatings,
    required VoidCallback onViewRemarks,
    Widget? actions,
  }) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool isNew = orderModel.status == Constant.orderPlaced;
    final List<CartProductModel> products = orderModel.products!;
    return DsCard(
      padding: EdgeInsets.zero,
      borderColor: isNew ? c.brand.withValues(alpha: 0.55) : null,
      onTap: () async {
        Get.to(const OrderDetailsScreen(), arguments: {"orderModel": orderModel});
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Customer
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.sm, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DsAvatar(imageUrl: orderModel.author!.profilePictureURL.toString(), name: orderModel.author!.fullName(), size: 44),
                DsGap.md,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(orderModel.author!.fullName().toString().tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                      const DsGap(DsSpace.xxs),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(orderModel.takeAway == true ? Icons.shopping_bag_outlined : Icons.location_on_outlined, size: 15, color: c.textMuted),
                          ),
                          DsGap.xs,
                          Expanded(child: Text(addressText, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySm)),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: c.textMuted),
              ],
            ),
          ),
          // Identity + status: one heading, one value, chip on the same line.
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OrderIdHeader(
                  label: "Order".tr,
                  shortId: Constant.orderId(orderId: orderModel.id.toString()),
                  fullId: orderModel.id.toString(),
                  // The card tap opens the order, so the id is not tappable here.
                  copyable: false,
                  statusChip: DsStatusChip(label: orderModel.status.toString().tr, status: orderModel.status, pulse: isNew),
                ),
                if (orderModel.scheduleTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: DsSpace.xs),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DsBadge(label: "Schedule Time".tr, icon: Icons.event_outlined, tone: DsTone.warning),
                    ),
                  ),
              ],
            ),
          ),
          _StatusTrack(status: orderModel.status),
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, 0),
            child: Divider(height: 1, thickness: 1, color: c.divider),
          ),
          // Items
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int index = 0; index < products.length; index++) ...[
                  if (index > 0) Padding(padding: const EdgeInsets.symmetric(vertical: DsSpace.md), child: Divider(height: 1, thickness: 1, color: c.divider)),
                  _productBlock(context, orderModel: orderModel, product: products[index], orderCurrency: orderCurrency, isDark: isDark, showRatings: showRatings),
                ],
              ],
            ),
          ),
          // Summary
          Container(
            margin: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, 0),
            padding: const EdgeInsets.all(DsSpace.md),
            decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OrderMoneyRow(label: "Order Date".tr, value: Constant.timestampToDateTime(orderModel.createdAt!), padding: const EdgeInsets.symmetric(vertical: DsSpace.xs)),
                if (Constant.vendorAdminCommission?.isEnabled == true)
                  OrderMoneyRow(
                    label: "Admin Commissions".tr,
                    value: "-${Constant.amountShow(currency: orderCurrency, amount: adminCommission.toString())}".tr,
                    valueColor: c.dangerStrong,
                    padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                  ),
                if (orderModel.scheduleTime != null)
                  OrderMoneyRow(
                    label: "Schedule Time".tr,
                    value: Constant.timestampToDateTime(orderModel.scheduleTime!).tr,
                    valueColor: c.brandStrong,
                    padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                  ),
                OrderTotalRow(
                  label: "Total Amount".tr,
                  value: Constant.amountShow(currency: orderCurrency, amount: totalAmount.toString()).tr,
                  valueColor: c.textPrimary,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          if (!(orderModel.notes == null || orderModel.notes!.isEmpty))
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.sm, DsSpace.xs, DsSpace.lg, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: DsButton.ghost(label: "View Remarks".tr, icon: Icons.sticky_note_2_outlined, size: DsButtonSize.sm, onPressed: onViewRemarks),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(DsSpace.lg, actions == null ? 0 : DsSpace.md, DsSpace.lg, DsSpace.lg),
            child: actions ?? const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// One ordered product with its variants and add-ons.
  Widget _productBlock(
    BuildContext context, {
    required OrderModel orderModel,
    required CartProductModel product,
    required CurrencyModel? orderCurrency,
    required bool isDark,
    required bool showRatings,
  }) {
    final c = context.dsColors;
    final t = context.dsText;
    Widget chip(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brSm, border: Border.all(color: c.border)),
      child: Text(text, style: t.bodySm),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrderItemRow(
          name: "${product.name}".tr,
          quantityLabel: "×${product.quantity}",
          price: Constant.amountShow(currency: orderCurrency, amount: (product.unitPrice * double.parse(product.quantity.toString())).toString()),
          subtitle: WholesaleTag(product: product, isDark: isDark),
          trailing: showRatings
              ? Semantics(
                  button: true,
                  child: InkWell(
                    borderRadius: DsRadius.brXs,
                    onTap: () {
                      Get.to(const ProductRatingViewScreen(), arguments: {"orderModel": orderModel, "productId": product.id});
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, size: 16, color: c.warning),
                          const DsGap(DsSpace.xxs),
                          Text("View Ratings".tr, style: t.link.copyWith(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
        ),
        if (!(product.variantInfo == null || product.variantInfo!.variantOptions!.isEmpty)) ...[
          const DsGap(DsSpace.sm),
          Text("Variants".tr.toUpperCase(), style: t.overline),
          const DsGap(DsSpace.xs),
          Wrap(
            spacing: 6.0,
            runSpacing: 6.0,
            children: List.generate(product.variantInfo!.variantOptions!.length, (i) {
              return chip(
                "${product.variantInfo!.variantOptions!.keys.elementAt(i)} : ${product.variantInfo!.variantOptions![product.variantInfo!.variantOptions!.keys.elementAt(i)]}",
              );
            }).toList(),
          ),
        ],
        if (!(product.extras == null || product.extras!.isEmpty)) ...[
          const DsGap(DsSpace.sm),
          Row(
            children: [
              Expanded(child: Text("Addons".tr.toUpperCase(), style: t.overline)),
              Text(
                Constant.amountShow(currency: orderCurrency, amount: (double.parse(product.extrasPrice.toString()) * double.parse(product.quantity.toString())).toString()),
                style: t.labelSm.copyWith(color: c.brandStrong),
              ),
            ],
          ),
          const DsGap(DsSpace.xs),
          Wrap(
            spacing: 6.0,
            runSpacing: 6.0,
            children: List.generate(product.extras!.length, (i) {
              return chip(product.extras![i].toString());
            }).toList(),
          ),
        ],
      ],
    );
  }

  Dialog showListOfDeliverymenDialog(HomeController controller, isDark, OrderModel orderModel) {
    return Dialog(
      insetPadding: const EdgeInsets.all(DsSpace.lg),
      clipBehavior: Clip.antiAlias,
      child: Builder(
        builder: (context) {
          final c = context.dsColors;
          final t = context.dsText;
          return _DialogFrame(
            icon: Icons.delivery_dining_rounded,
            title: "Select the delivery man".tr,
            actions: Row(
              children: [
                Expanded(
                  child: DsButton.secondary(
                    label: "Cancel".tr,
                    onPressed: () async {
                      Get.back();
                    },
                  ),
                ),
                DsGap.md,
                Expanded(
                  child: DsButton.primary(
                    label: "Order Assign".tr,
                    onPressed: () async {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Obx(
                  () => DropdownSearch<UserModel>(
                    items: (String s, LoadProps? data) => controller.driverUserList,
                    selectedItem: controller.selectDriverUser.value,
                    compareFn: (UserModel a, UserModel b) => a.id == b.id,
                    itemAsString: (UserModel? user) => user == null || user.id == null ? "Select Delivery Man".tr : "${user.firstName} ${user.lastName}",
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(decoration: DsInputDecoration.of(context, prefixIcon: Icons.search).copyWith(labelText: "Search Delivery Man".tr)),
                      itemBuilder: (context, UserModel driver, bool isSelected, bool check) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                flex: 5,
                                child: Row(
                                  children: [
                                    DsAvatar(name: "${driver.firstName} ${driver.lastName}", imageUrl: driver.profilePictureURL, size: 32),
                                    DsGap.sm,
                                    Expanded(child: Text("${driver.firstName} ${driver.lastName}", style: t.bodyStrong)),
                                  ],
                                ),
                              ),
                              if (Constant.singleOrderReceive == true)
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: driver.inProgressOrderID?.isEmpty == true
                                        ? DsBadge(label: 'Assign'.tr, tone: DsTone.success, small: true)
                                        : DsBadge(label: 'Occupied'.tr, tone: DsTone.danger, small: true),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    decoratorProps: DropDownDecoratorProps(
                      decoration: DsInputDecoration.of(context, prefixIcon: Icons.person_search_outlined).copyWith(labelText: "Select Delivery Man".tr),
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
                DsGap.sm,
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DsButton.ghost(
                    label: 'Add Delivery Man'.tr,
                    icon: Icons.person_add_alt_1_outlined,
                    size: DsButtonSize.sm,
                    color: c.brandStrong,
                    onPressed: () {
                      Get.to(AddDriverScreen())?.then((value) async {
                        if (value == true) {
                          Get.back();
                          ShowToastDialog.showToastDuration("Please ensure that the deliveryman is signed in and has an active status to assign the delivery.".tr, duration: Duration(seconds: 4));
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Dialog estimatedTimeDialog(HomeController controller, isDark, OrderModel orderModel, BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(DsSpace.lg),
      clipBehavior: Clip.antiAlias,
      child: _DialogFrame(
        icon: Icons.timer_outlined,
        title: "Estimate time to prepare".tr,
        actions: Row(
          children: [
            Expanded(
              child: DsButton.secondary(
                label: "Cancel".tr,
                onPressed: () async {
                  Get.back();
                },
              ),
            ),
            DsGap.md,
            Expanded(
              child: DsButton.primary(
                label: "Shipped order".tr,
                onPressed: () async {
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
        child: DsTextField(
          label: 'Estimated time to Prepare'.tr,
          inputFormatters: [MaskedInputFormatter('##:##')],
          controller: controller.estimatedTimeController.value,
          hint: '00:00'.tr,
          keyboardType: TextInputType.number,
          prefixIcon: Icons.alarm,
          bottomSpacing: 0,
        ),
      ),
    );
  }

  Dialog courierCompanyNameDialog(HomeController controller, isDark, OrderModel orderModel, BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(DsSpace.lg),
      clipBehavior: Clip.antiAlias,
      child: _DialogFrame(
        icon: Icons.local_shipping_outlined,
        title: "Shipped order".tr,
        actions: Row(
          children: [
            Expanded(
              child: DsButton.secondary(
                label: "Cancel".tr,
                onPressed: () async {
                  Get.back();
                },
              ),
            ),
            DsGap.md,
            Expanded(
              child: DsButton.primary(
                label: "Shipped order".tr,
                onPressed: () async {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsTextField(label: 'Courier company name'.tr, controller: controller.courierCompanyName.value, hint: 'Enter Courier company name'.tr, prefixIcon: Icons.business_outlined),
            DsTextField(label: 'Tracking Id'.tr, controller: controller.courierCompanyTrackingId.value, hint: 'Enter Courier tracking Id'.tr, prefixIcon: Icons.qr_code_2_rounded, bottomSpacing: 0),
          ],
        ),
      ),
    );
  }

  Dialog viewRemarkDialog(HomeController controller, isDark, OrderModel orderModel) {
    return Dialog(
      insetPadding: const EdgeInsets.all(DsSpace.lg),
      clipBehavior: Clip.antiAlias,
      child: _DialogFrame(
        icon: Icons.sticky_note_2_outlined,
        title: "View Remarks".tr,
        actions: DsButton.secondary(
          label: "Cancel".tr,
          expand: true,
          onPressed: () async {
            Get.back();
          },
        ),
        child: Builder(builder: (context) => Text(orderModel.notes.toString(), textAlign: TextAlign.start, style: context.dsText.bodyLg)),
      ),
    );
  }

  /// Hero: who is signed in, the store being worked on (switchable for
  /// owners), and the live order pipeline.
  Widget _buildHomeHeader(BuildContext context, HomeController controller, bool isDark, {required Gradient gradient, List<int>? counts}) {
    final l = context.dsLayout;
    final t = context.dsText;
    final double inset = l.horizontalInsetFor(DsLayout.wideMax);
    final bool hasStore = (controller.userModel.value.vendorID ?? '').isNotEmpty;

    return Container(
      decoration: BoxDecoration(gradient: gradient, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(DsRadius.xxl))),
      padding: EdgeInsets.fromLTRB(inset, DsSpace.sm, inset, DsSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: DsFadeSlideIn.stagger([
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.35)),
                child: DsAvatar(
                  imageUrl: controller.userModel.value.profilePictureURL.toString(),
                  name: controller.userModel.value.fullName(),
                  size: 48,
                  onTap: () {
                    DashBoardController dashBoardController = Get.find<DashBoardController>();
                    dashBoardController.selectedIndex.value = Constant.selectedSection!.dineInActive == true ? 4 : 3;
                  },
                ),
              ),
              DsGap.md,
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome to spideli Store".tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySm.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                    ),
                    const DsGap(DsSpace.xxs),
                    Text(
                      controller.userModel.value.fullName().tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.headline.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
              if (controller.userModel.value.subscriptionPlan?.features?.chat != false)
                Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.18)),
                  child: DsIconButton(
                    semanticLabel: "Inbox".tr,
                    size: 48,
                    color: Colors.white,
                    onPressed: () => Get.to(const RestaurantInboxScreen()),
                    child: SvgPicture.asset("assets/icons/ic_chat.svg", width: 22, height: 22, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
                  ),
                ),
            ],
          ),
          if (hasStore)
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.lg),
              child: CurrentStoreCard(storeName: controller.vendermodel.value.title, storePhoto: controller.vendermodel.value.photo, isDark: isDark),
            ),
          if (counts != null)
            Padding(
              padding: const EdgeInsets.only(top: DsSpace.lg),
              child: _KpiStrip(
                counts: counts,
                onSelect: (value) {
                  controller.selectedTabIndex.value = value;
                },
              ),
            ),
        ]),
      ),
    );
  }
}

/// Order pipeline on the hero: New / Preparing / Ready / Completed. Tapping a
/// tile opens that tab.
class _KpiStrip extends StatelessWidget {
  final List<int> counts;
  final ValueChanged<int> onSelect;

  const _KpiStrip({required this.counts, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final double scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    const List<(IconData, String)> items = [
      (Icons.notifications_active_outlined, "New"),
      (Icons.soup_kitchen_outlined, "Preparing"),
      (Icons.delivery_dining_outlined, "Ready"),
      (Icons.task_alt_rounded, "Completed"),
    ];
    return DsAdaptiveGrid(
      minItemWidth: 148 * scale,
      spacing: DsSpace.sm,
      runSpacing: DsSpace.sm,
      children: [
        for (int i = 0; i < items.length; i++)
          _KpiTile(
            icon: items[i].$1,
            label: items[i].$2.tr,
            count: counts[i],
            live: i == 0 && counts[i] > 0,
            onTap: () {
              DefaultTabController.maybeOf(context)?.animateTo(i);
              onSelect(i);
            },
          ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool live;
  final VoidCallback onTap;

  const _KpiTile({required this.icon, required this.label, required this.count, required this.live, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DsPressable(
      onTap: onTap,
      semanticLabel: '$label: $count',
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: live ? 0.24 : 0.14),
          borderRadius: DsRadius.brLg,
          border: Border.all(color: Colors.white.withValues(alpha: live ? 0.45 : 0.22)),
        ),
        child: Row(
          children: [
            DsIconWell(icon: icon, onBrand: true, size: 36),
            DsGap.md,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DsAnimatedCounter(value: count, style: DsTypography.metric.copyWith(color: Colors.white, fontSize: 22, height: 1.1)),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsTypography.labelSm.copyWith(color: Colors.white.withValues(alpha: 0.86))),
                ],
              ),
            ),
            if (live) const _LiveDot(),
          ],
        ),
      ),
    );
  }
}

/// Small pulsing white dot for "orders waiting".
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (DsMotion.reduced(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 16,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: 1 + _c.value * 1.2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: (1 - _c.value) * 0.6)),
              ),
            ),
            Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

/// Pinned order-status tabs: a sliding brand pill with a live count per tab.
class _OrderTabsHeader extends SliverPersistentHeaderDelegate {
  final double extent;
  final List<int> counts;
  final ValueChanged<int> onTap;

  _OrderTabsHeader({required this.extent, required this.counts, required this.onTap});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  bool shouldRebuild(covariant _OrderTabsHeader oldDelegate) => true;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final c = context.dsColors;
    final l = context.dsLayout;
    final double inset = l.horizontalInsetFor(DsLayout.wideMax);
    final labels = ["New", "Preparing", "Ready", "Completed", "Rejected", "Cancelled"];
    return AnimatedContainer(
      duration: DsMotion.of(context, DsMotion.fast),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(bottom: BorderSide(color: overlapsContent ? c.divider : Colors.transparent)),
      ),
      alignment: Alignment.center,
      child: TabBar(
        onTap: onTap,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.symmetric(horizontal: inset - 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        splashBorderRadius: DsRadius.brPill,
        indicator: BoxDecoration(color: c.brand, borderRadius: DsRadius.brPill, boxShadow: DsShadows.glow(context, color: c.brand).take(1).toList()),
        labelColor: c.onBrand,
        unselectedLabelColor: c.textSecondary,
        labelStyle: DsTypography.label,
        unselectedLabelStyle: DsTypography.bodyStrong,
        tabs: [
          for (int i = 0; i < labels.length; i++)
            Tab(
              height: extent - 16,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(labels[i].tr),
                    if (counts[i] > 0) ...[DsGap.sm, _TabCount(count: counts[i])],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabCount extends StatelessWidget {
  final int count;
  const _TabCount({required this.count});

  @override
  Widget build(BuildContext context) {
    // Follows the tab's animated label color (on-brand when selected).
    final Color fg = DefaultTextStyle.of(context).style.color ?? context.dsColors.textSecondary;
    return AnimatedSwitcher(
      duration: DsMotion.of(context, DsMotion.base),
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child)),
      child: Container(
        key: ValueKey(count),
        constraints: const BoxConstraints(minWidth: 22),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: fg.withValues(alpha: 0.16), borderRadius: DsRadius.brPill),
        child: Text(count > 99 ? '99+' : '$count', textAlign: TextAlign.center, style: DsTypography.labelSm.copyWith(color: fg).tabular),
      ),
    );
  }
}

/// Compact order progress: Placed > Preparing > Ready > Completed. Hidden for
/// rejected / cancelled orders (their status chip says it all).
class _StatusTrack extends StatelessWidget {
  final String? status;
  const _StatusTrack({required this.status});

  @override
  Widget build(BuildContext context) {
    final int stage;
    if (status == Constant.orderPlaced) {
      stage = 0;
    } else if (HomeController.preparingStatuses.contains(status)) {
      stage = 1;
    } else if (HomeController.readyStatuses.contains(status)) {
      stage = 2;
    } else if (status == Constant.orderCompleted) {
      stage = 3;
    } else {
      return const SizedBox.shrink();
    }
    final c = context.dsColors;
    final t = context.dsText;
    final labels = ["Placed".tr, "Preparing".tr, "Ready".tr, "Completed".tr];
    final Duration d = DsMotion.of(context, DsMotion.slow);
    Widget line(bool on) => Expanded(
      child: AnimatedContainer(
        duration: d,
        curve: DsMotion.standard,
        height: 3,
        decoration: BoxDecoration(color: on ? c.brand : c.border, borderRadius: DsRadius.brPill),
      ),
    );
    return Semantics(
      label: labels[stage],
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < labels.length; i++)
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 20,
                      child: Row(
                        children: [
                          i == 0 ? const Spacer() : line(i <= stage),
                          AnimatedContainer(
                            duration: d,
                            curve: DsMotion.standard,
                            width: i == stage ? 20 : 14,
                            height: i == stage ? 20 : 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < stage ? c.brand : (i == stage ? c.brandSoft : c.surface),
                              border: Border.all(color: i <= stage ? c.brand : c.borderStrong, width: i == stage ? 2 : 1.5),
                            ),
                            child: i < stage
                                ? Icon(Icons.check_rounded, size: 10, color: c.onBrand)
                                : (i == stage ? Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: c.brand))) : null),
                          ),
                          i == labels.length - 1 ? const Spacer() : line(i < stage),
                        ],
                      ),
                    ),
                    const DsGap(DsSpace.xs),
                    Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: t.caption.copyWith(color: i <= stage ? c.textPrimary : c.textMuted, fontWeight: i == stage ? FontWeight.w700 : FontWeight.w500),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Final state of a completed / rejected / cancelled order.
class _StatusBanner extends StatelessWidget {
  final String status;
  final DsTone tone;
  const _StatusBanner({required this.status, required this.tone});

  @override
  Widget build(BuildContext context) {
    final tc = context.dsColors.tone(tone);
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
      decoration: BoxDecoration(color: tc.soft, borderRadius: DsRadius.brMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(tone == DsTone.danger ? Icons.block_rounded : Icons.verified_rounded, size: 18, color: tc.strong),
          DsGap.sm,
          Flexible(child: Text(status, textAlign: TextAlign.center, style: DsTypography.label.copyWith(color: tc.strong))),
        ],
      ),
    );
  }
}

/// Dialog body shared by the order dialogs: icon + title, content, actions.
class _DialogFrame extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget actions;

  const _DialogFrame({required this.icon, required this.title, required this.child, required this.actions});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DsSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DsIconWell(icon: icon, size: 44),
                DsGap.md,
                Expanded(child: Semantics(header: true, child: Text(title, style: t.title))),
              ],
            ),
            DsGap.xl,
            child,
            DsGap.xxl,
            actions,
          ],
        ),
      ),
    );
  }
}

/// Full-page state (verification pending, no store yet) with one action.
class _HomeStateView extends StatelessWidget {
  final String svgAsset;
  final DsTone tone;
  final String title;
  final String message;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  const _HomeStateView({
    required this.svgAsset,
    required this.tone,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final tc = context.dsColors.tone(tone);
    return DsEmptyState(
      tone: tone,
      title: title,
      message: message,
      actionLabel: actionLabel,
      actionIcon: actionIcon,
      onAction: onAction,
      illustration: Center(
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [tc.soft, tc.soft.withValues(alpha: 0)], stops: const [0.6, 1]),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 96,
            height: 96,
            padding: const EdgeInsets.all(DsSpace.xl),
            decoration: BoxDecoration(shape: BoxShape.circle, color: tc.soft, border: Border.all(color: tc.main.withValues(alpha: 0.2))),
            child: SvgPicture.asset(svgAsset),
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder shaped like the dashboard.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l = context.dsLayout;
    final double inset = l.horizontalInsetFor(DsLayout.wideMax);
    final double top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: c.background,
      body: DsShimmer(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(DsRadius.xxl)),
                child: DsSkeleton.box(height: top + 250, radius: 0),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(inset, DsSpace.lg, inset, DsSpace.lg),
                child: Row(
                  children: [
                    for (int i = 0; i < 4; i++) ...[
                      if (i > 0) DsGap.sm,
                      Expanded(child: DsSkeleton.box(height: 36, radius: DsRadius.pill)),
                    ],
                  ],
                ),
              ),
              for (int i = 0; i < 2; i++)
                Container(
                  margin: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.md),
                  padding: const EdgeInsets.all(DsSpace.lg),
                  decoration: BoxDecoration(borderRadius: DsRadius.brLg, border: Border.all(color: c.shimmerBase)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          DsSkeleton.circle(size: 44),
                          DsGap.md,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [DsSkeleton.line(width: 140, height: 14), DsGap.sm, DsSkeleton.line(width: 200)],
                            ),
                          ),
                        ],
                      ),
                      DsGap.lg,
                      DsSkeleton.line(height: 6),
                      DsGap.lg,
                      DsSkeleton.line(width: 220, height: 14),
                      DsGap.sm,
                      DsSkeleton.line(width: 160, height: 14),
                      DsGap.lg,
                      DsSkeleton.box(height: 72),
                      DsGap.lg,
                      Row(children: [Expanded(child: DsSkeleton.box(height: 44)), DsGap.md, Expanded(child: DsSkeleton.box(height: 44))]),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

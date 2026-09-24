import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/order_controller.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/order_model.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/order_history_limit.dart';
import 'package:customer/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/theme_controller.dart';
import '../../../themes/show_toast_dialog.dart';
import '../../auth_screens/login_screen.dart';
import 'live_tracking_screen.dart';
import 'order_details_screen.dart';

/// Archetype F — order history. A ledger-style list: each order is a receipt
/// card (store thumb + status, a tinted strip of line items, an action rail).
/// The free order-history limit and its "See older orders" prompt are kept
/// exactly as they were.
class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: OrderController(),
      builder: (controller) {
        final t = context.dsText;
        // Every observable this screen depends on is read here, inside the
        // tracked builder, and handed to the lazily-built item builders.
        final bool isLoading = controller.isLoading.value;
        final int hiddenCount = controller.hiddenOrderCount.value;
        final List<OrderModel> allList = controller.allList.toList();
        final List<OrderModel> inProgressList = controller.inProgressList.toList();
        final List<OrderModel> deliveredList = controller.deliveredList.toList();
        final List<OrderModel> cancelledList = controller.cancelledList.toList();
        final List<OrderModel> rejectedList = controller.rejectedList.toList();

        return DsScaffold(
          body: SafeArea(
            bottom: false,
            child: isLoading
                ? const SingleChildScrollView(child: DsSkeletonList(itemCount: 4, leading: true, trailing: false))
                : Constant.userModel == null
                ? const _LoggedOutView()
                : DefaultTabController(
                    length: 5,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("My Order".tr, style: t.display),
                                    const DsGap(DsSpace.xs),
                                    Text(
                                      "Keep track your delivered, In Progress and Rejected item all in just one place.".tr,
                                      style: t.bodySecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const DsGap(DsSpace.md),
                        DsTabBar(
                          scrollable: true,
                          tabs: ['All'.tr, 'In Progress'.tr, 'Delivered'.tr, 'Cancelled'.tr, 'Rejected'.tr],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              allList.isEmpty && hiddenCount == 0
                                  ? const _NoOrders()
                                  : RefreshIndicator(
                                      onRefresh: () => controller.getOrder(),
                                      child: ListView.builder(
                                        itemCount: allList.length + (hiddenCount > 0 ? 1 : 0),
                                        shrinkWrap: true,
                                        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                                        itemBuilder: (context, index) {
                                          if (index == allList.length) {
                                            return OlderOrdersPrompt(hiddenCount: hiddenCount, isDark: isDark, onReturn: controller.getOrder);
                                          }
                                          OrderModel orderModel = allList[index];
                                          return DsFadeSlideIn(index: index, child: _OrderCard(orderModel: orderModel, controller: controller));
                                        },
                                      ),
                                    ),
                              _OrderList(orders: inProgressList, controller: controller),
                              _OrderList(orders: deliveredList, controller: controller),
                              _OrderList(orders: cancelledList, controller: controller),
                              _OrderList(orders: rejectedList, controller: controller),
                            ],
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
}

/// One status tab: pull-to-refresh + staggered receipt cards.
class _OrderList extends StatelessWidget {
  final List<OrderModel> orders;
  final OrderController controller;

  const _OrderList({required this.orders, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return const _NoOrders();
    return RefreshIndicator(
      onRefresh: () => controller.getOrder(),
      child: ListView.builder(
        itemCount: orders.length,
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        itemBuilder: (context, index) {
          OrderModel orderModel = orders[index];
          return DsFadeSlideIn(index: index, child: _OrderCard(orderModel: orderModel, controller: controller));
        },
      ),
    );
  }
}

class _NoOrders extends StatelessWidget {
  const _NoOrders();

  @override
  Widget build(BuildContext context) {
    return DsEmptyState(
      icon: Icons.receipt_long_outlined,
      title: "Order Not Found".tr,
      message: "Keep track your delivered, In Progress and Rejected item all in just one place.".tr,
    );
  }
}

class _LoggedOutView extends StatelessWidget {
  const _LoggedOutView();

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xxl),
        child: DsResponsive(
          maxWidth: 420,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: DsFadeSlideIn.stagger([
              Image.asset("assets/images/login.gif", height: 120),
              const DsGap(DsSpace.md),
              Text("Please Log In to Continue".tr, textAlign: TextAlign.center, style: t.headline),
              const DsGap(DsSpace.sm),
              Text(
                "You’re not logged in. Please sign in to access your account and explore all features.".tr,
                textAlign: TextAlign.center,
                style: t.bodySecondary,
              ),
              const DsGap(DsSpace.xl),
              DsButton.primary(
                label: "Log in".tr,
                icon: Icons.login_rounded,
                size: DsButtonSize.lg,
                expand: true,
                onPressed: () async {
                  Get.offAll(const LoginScreen());
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Receipt card — header (store + status), tinted line-item strip, actions.
class _OrderCard extends StatelessWidget {
  final OrderModel orderModel;
  final OrderController controller;

  const _OrderCard({required this.orderModel, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final String status = orderModel.status.toString();
    final bool hideTrack = Constant.sectionConstantModel!.serviceTypeFlag == 'ecommerce-service';

    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(DsSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DsImage(url: orderModel.vendor!.photo.toString(), width: 64, height: 64, radius: DsRadius.md, errorIcon: Icons.storefront_outlined),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DsStatusChip(label: status, status: status, pulse: status == Constant.orderShipped || status == Constant.orderInTransit),
                      const DsGap(DsSpace.sm),
                      Text(orderModel.vendor!.title.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSm),
                      const DsGap(DsSpace.xxs),
                      Text(Constant.timestampToDateTime(orderModel.createdAt!), style: t.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: c.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
            child: ListView.separated(
              itemCount: orderModel.products!.length,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (context, index) => const DsGap(DsSpace.sm),
              itemBuilder: (context, index) {
                CartProductModel cartProduct = orderModel.products![index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: 1),
                      decoration: BoxDecoration(color: c.surface, borderRadius: DsRadius.brXs),
                      child: Text("${cartProduct.quantity}", style: t.labelSm.tabular),
                    ),
                    const DsGap(DsSpace.sm),
                    Expanded(child: Text(cartProduct.name.toString(), style: t.body)),
                    const DsGap(DsSpace.sm),
                    Text(
                      Constant.amountShow(
                        amount: double.parse(cartProduct.discountPrice.toString()) <= 0
                            ? (double.parse('${cartProduct.price ?? 0}') * double.parse('${cartProduct.quantity ?? 0}')).toString()
                            : (double.parse('${cartProduct.discountPrice ?? 0}') * double.parse('${cartProduct.quantity ?? 0}')).toString(),
                        currency: RegionService.currencyForRecord(orderModel.regionId),
                      ),
                      style: t.bodyStrong.tabular,
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DsSpace.sm),
            child: Row(
              children: [
                status == Constant.orderCompleted
                    ? Expanded(
                        child: DsButton.ghost(
                          label: "Reorder".tr,
                          icon: Icons.refresh_rounded,
                          onPressed: () async {
                            for (var element in orderModel.products!) {
                              await controller.addToCart(cartProductModel: element, vendor: orderModel.vendor);
                              ShowToastDialog.showToast("Item Added In a cart".tr);
                            }
                          },
                        ),
                      )
                    : status == Constant.orderShipped || status == Constant.orderInTransit
                    ? hideTrack
                          ? const SizedBox()
                          : Expanded(
                              child: DsButton.ghost(
                                label: "Track Order".tr,
                                icon: Icons.near_me_outlined,
                                onPressed: () {
                                  Get.to(const LiveTrackingScreen(), arguments: {"orderModel": orderModel});
                                },
                              ),
                            )
                    : const SizedBox(),
                Expanded(
                  child: DsButton.ghost(
                    label: "View Details".tr,
                    trailingIcon: Icons.chevron_right_rounded,
                    color: c.textPrimary,
                    onPressed: () {
                      Get.to(const OrderDetailsScreen(), arguments: {"orderModel": orderModel});
                      // Get.off(const OrderPlacingScreen(), arguments: {"orderModel": orderModel});
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

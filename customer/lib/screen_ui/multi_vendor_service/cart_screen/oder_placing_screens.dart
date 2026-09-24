import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/dash_board_controller.dart';
import 'package:customer/controllers/dash_board_ecommarce_controller.dart';
import 'package:customer/controllers/order_placing_controller.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/screen_ui/ecommarce/dash_board_e_commerce_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../dash_board_screens/dash_board_screen.dart';

/// Archetype K — status / result. Two states in one page: "placing" shows the
/// timer illustration with the address and the order summary, "placed" flips
/// to a success hero with the order id. Track Order stays in the sticky bar
/// and is disabled until the order exists.
class OrderPlacingScreen extends StatelessWidget {
  const OrderPlacingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: OrderPlacingController(),
      builder: (controller) {
        final bool isLoading = controller.isLoading.value;
        final bool isPlacing = controller.isPlacing.value;
        final orderModel = controller.orderModel.value;

        return DsScaffold(
          maxContentWidth: DsLayout.contentMax,
          appBar: const DsAppBar(),
          body: isLoading
              ? const Center(child: DsBrandLoader())
              : AnimatedSwitcher(
                  duration: DsMotion.of(context, DsMotion.base),
                  child: isPlacing
                      ? SingleChildScrollView(
                          key: const ValueKey('placed'),
                          padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxl),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: DsFadeSlideIn.stagger([
                              DsCard.gradient(
                                gradient: DsGradients.tone(context, DsTone.success),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 40),
                                    const DsGap(DsSpace.md),
                                    Text("Order Placed".tr, style: context.dsText.display.withColor(Colors.white)),
                                    const DsGap(DsSpace.xs),
                                    Text("Hang tight — your items are being delivered quickly and safely!".tr, style: context.dsText.body.withColor(Colors.white70)),
                                  ],
                                ),
                              ),
                              _InfoBlock(
                                icon: Icons.receipt_long_outlined,
                                title: "Order ID".tr,
                                child: Text(orderModel.id.toString(), style: context.dsText.bodyStrong.tabular),
                              ),
                            ], offset: const Offset(0, 22)),
                          ),
                        )
                      : SingleChildScrollView(
                          key: const ValueKey('placing'),
                          padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: DsFadeSlideIn.stagger([
                              Center(child: Image.asset("assets/images/ic_timer.gif", height: 140)),
                              Padding(
                                padding: const EdgeInsets.only(top: DsSpace.xl),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Placing your order".tr, style: context.dsText.display),
                                    const DsGap(DsSpace.xs),
                                    Text("Take a moment to review your order before proceeding to checkout.".tr, style: context.dsText.bodySecondary),
                                    const DsGap(DsSpace.md),
                                    const DsProgressBar(value: null),
                                  ],
                                ),
                              ),
                              _InfoBlock(
                                icon: Icons.location_on_outlined,
                                title: "Delivery Address".tr,
                                child: Text(orderModel.address!.getFullAddress(), style: context.dsText.bodySecondary),
                              ),
                              _InfoBlock(
                                icon: Icons.menu_book_outlined,
                                title: "Order Summary".tr,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: orderModel.products!.length,
                                  itemBuilder: (context, index) {
                                    CartProductModel cartProductModel = orderModel.products![index];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: DsSpace.xs),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("${cartProductModel.quantity} x".tr, style: context.dsText.bodyStrong.tabular),
                                          const DsGap(DsSpace.sm),
                                          Expanded(child: Text("${cartProductModel.name}".tr, style: context.dsText.body)),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ], offset: const Offset(0, 22)),
                          ),
                        ),
                ),
          bottomBar: DsStickyBar(
            child: isPlacing
                ? DsButton.primary(
                    label: "Track Order".tr,
                    icon: Icons.local_shipping_outlined,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () async {
                      if (Constant.sectionConstantModel!.serviceTypeFlag == "ecommerce-service") {
                        Get.offAll(const DashBoardEcommerceScreen());
                        DashBoardEcommerceController controller = Get.put(DashBoardEcommerceController());
                        controller.selectedIndex.value = 3;
                      } else {
                        Get.offAll(const DashBoardScreen());
                        DashBoardController controller = Get.put(DashBoardController());
                        controller.selectedIndex.value = 3;
                      }
                    },
                  )
                : DsButton.primary(label: "Track Order".tr, icon: Icons.local_shipping_outlined, size: DsButtonSize.lg, expand: true, loading: true, onPressed: () async {}),
          ),
        );
      },
    );
  }
}

/// Labelled block used for the address, id and summary.
class _InfoBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _InfoBlock({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard(
      margin: const EdgeInsets.only(top: DsSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: c.brandStrong),
              const DsGap(DsSpace.sm),
              Expanded(child: Text(title, style: t.label.withColor(c.brandStrong))),
            ],
          ),
          const DsGap(DsSpace.sm),
          child,
        ],
      ),
    );
  }
}

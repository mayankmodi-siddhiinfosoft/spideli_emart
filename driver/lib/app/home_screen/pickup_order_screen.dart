import 'package:driver/app/home_screen/widgets/order_manifest.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/pickup_order_controller.dart';
import 'package:driver/models/cart_product_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Archetype C (live trip step, no map) — "collect the goods". A gradient
/// pickup hero, the item manifest to check against, the drop-off stop, and
/// the irreversible hand-over behind a slide in the sticky bar.
class PickupOrderScreen extends StatelessWidget {
  const PickupOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    // Kept as the observable read that rebuilds this screen on a theme change;
    // colors now come from `context.dsColors`.
    themeController.isDark.value;
    return GetX(
        init: PickupOrderController(),
        builder: (controller) {
          final bool isLoading = controller.isLoading.value;
          final bool confirmed = controller.conformPickup.value;
          final List<CartProductModel> products = controller.orderModel.value.products ?? <CartProductModel>[];

          return DsScaffold(
            title: Constant.orderId(orderId: controller.orderModel.value.id.toString()).tr,
            body: DsAsync(
              isLoading: isLoading,
              skeleton: const DsSkeletonDetail(),
              builder: (context) => ListView(
                padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                children: DsFadeSlideIn.stagger([
                  Padding(padding: const EdgeInsets.only(bottom: DsSpace.xl), child: _pickupHero(context)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DsSectionHeader(title: "Item and Deliver to the".tr, icon: Icons.inventory_2_outlined, padding: EdgeInsets.zero),
                      const DsGap(DsSpace.md),
                      OrderManifestCard(products: products),
                      const DsGap(DsSpace.lg),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: DsSpace.lg),
                    child: OrderConfirmCheck(
                      value: confirmed,
                      label: "Confirm Pickup".tr,
                      onChanged: (value) {
                        if (value != null) {
                          controller.conformPickup.value = value;
                        }
                      },
                    ),
                  ),
                  DsCard(
                    padding: const EdgeInsets.all(DsSpace.lg),
                    child: DsRouteStops(
                      stops: [
                        DsRouteStop(
                          kind: DsStopKind.drop,
                          label: "${'Deliver to the'.tr} · ${controller.orderModel.value.author!.fullName()}",
                          address: controller.orderModel.value.address!.getFullAddress(),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
            bottomBar: isLoading
                ? null
                : DsStickyBar(
                    child: DsSlideToConfirm(
                      label: "Picked Order".tr,
                      icon: Icons.shopping_bag_rounded,
                      tone: DsTone.brand,
                      onConfirmed: () async {
                        if (controller.conformPickup.value == false) {
                          ShowToastDialog.showToast("Conform pickup order".tr);
                        } else {
                          ShowToastDialog.showLoader("Please wait".tr);
                          controller.orderModel.value.status = Constant.orderInTransit;
                          await FireStoreUtils.setOrder(controller.orderModel.value);
                          ShowToastDialog.closeLoader();
                          Get.back(result: true);
                        }
                      },
                    ),
                  ),
          );
        });
  }

  Widget _pickupHero(BuildContext context) {
    final t = context.dsText;
    return DsCard.tinted(
      tone: DsTone.brand,
      padding: const EdgeInsets.all(DsSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Image.asset("assets/images/order_pickup.gif", height: 160)),
          const DsGap(DsSpace.lg),
          Text("Order Ready to pickup".tr, style: t.headline),
          const DsGap(DsSpace.xs),
          Text(
            "Your order has been ready pickup the order and deliver to the customer’s locations.".tr,
            style: t.bodySecondary,
          ),
        ],
      ),
    );
  }
}

import 'package:driver/app/chat_screens/chat_screen.dart';
import 'package:driver/app/home_screen/widgets/order_manifest.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/deliver_order_controller.dart';
import 'package:driver/models/cart_product_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Archetype C (live trip step, no map) — "hand it over". The customer sits
/// in a tinted header with the chat shortcut, the manifest is the checklist,
/// and the irreversible completion is a slide in the sticky bar.
class DeliverOrderScreen extends StatelessWidget {
  const DeliverOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    // Kept as the observable read that rebuilds this screen on a theme change;
    // colors now come from `context.dsColors`.
    themeController.isDark.value;
    return GetX(
        init: DeliverOrderController(),
        builder: (controller) {
          final bool isLoading = controller.isLoading.value;
          final bool confirmed = controller.conformPickup.value;
          final List<CartProductModel> products = controller.orderModel.value.products ?? <CartProductModel>[];

          return DsScaffold(
            title: Constant.orderId(orderId: controller.orderModel.value.id.toString()).tr,
            body: DsAsync(
              isLoading: isLoading,
              skeleton: const DsSkeletonDetail(mediaHeight: 120),
              builder: (context) => ListView(
                padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
                children: DsFadeSlideIn.stagger([
                  Padding(padding: const EdgeInsets.only(bottom: DsSpace.xl), child: _customerCard(context, controller)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DsSectionHeader(title: "Item and Deliver to the".tr, icon: Icons.inventory_2_outlined, padding: EdgeInsets.zero),
                      const DsGap(DsSpace.md),
                      OrderManifestCard(products: products),
                      const DsGap(DsSpace.lg),
                    ],
                  ),
                  OrderConfirmCheck(
                    value: confirmed,
                    label: "${'Give'.tr} ${controller.totalQuantity.value.toString()} ${'Items to the customer'.tr}".tr,
                    onChanged: (value) {
                      if (value != null) {
                        controller.conformPickup.value = value;
                      }
                    },
                  ),
                ]),
              ),
            ),
            bottomBar: isLoading
                ? null
                : DsStickyBar(
                    child: DsSlideToConfirm(
                      label: "Make Order Delivered".tr,
                      icon: Icons.check_rounded,
                      tone: DsTone.success,
                      onConfirmed: () async {
                        if (controller.conformPickup.value == false) {
                          ShowToastDialog.showToast("Conform Deliver order".tr);
                        } else {
                          await controller.completedOrder();
                        }
                      },
                    ),
                  ),
          );
        });
  }

  Widget _customerCard(BuildContext context, DeliverOrderController controller) {
    final t = context.dsText;
    return DsCard.tinted(
      tone: DsTone.success,
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsAvatar(name: controller.orderModel.value.author!.fullName(), size: 48),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Deliver to the".tr, style: t.caption),
                Text(controller.orderModel.value.author!.fullName(), style: t.titleSm.w700),
                const DsGap(DsSpace.xs),
                Text(controller.orderModel.value.address!.getFullAddress(), style: t.bodySm),
              ],
            ),
          ),
          const DsGap(DsSpace.sm),
          DsIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            semanticLabel: "Chat".tr,
            variant: DsIconButtonVariant.brand,
            onPressed: () async {
              ShowToastDialog.showLoader("Please wait".tr);

              UserModel? customer = await FireStoreUtils.getUserProfile(controller.orderModel.value.authorID.toString());
              UserModel? driver = await FireStoreUtils.getUserProfile(controller.orderModel.value.driverID.toString());

              ShowToastDialog.closeLoader();

              Get.to(const ChatScreen(), arguments: {
                "senderName": driver!.fullName(),
                "receivedName": customer!.fullName(),
                "orderId": controller.orderModel.value.id,
                "senderId": driver.id,
                "receivedId": customer.id,
                "receivedProfileUrl": customer.profilePictureURL ?? "",
                "senderProfileUrl": driver.profilePictureURL ?? "",
                "token": customer.fcmToken,
                "chatType": Constant.userRoleDriver,
              });
            },
          ),
        ],
      ),
    );
  }
}

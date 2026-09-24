import 'package:customer/constant/assets.dart';
import 'package:customer/controllers/address_list_controller.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/screen_ui/location_enable_screens/enter_manually_location.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

class AddressListScreen extends StatelessWidget {
  const AddressListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: AddressListController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final isLoading = controller.isLoading.value;
        final addresses = controller.shippingAddressList;

        return DsScaffold.collapsing(
          title: "My Addresses".tr,
          // Keep the screen's original back action.
          onBack: () {
            Get.back();
          },
          subtitle: isLoading || addresses.isEmpty ? null : '${addresses.length} ${"Saved".tr}',
          slivers: [
            DsSliverResponsive(
              bottom: DsSpace.md,
              sliver: SliverToBoxAdapter(
                child: Text("Allows users to view, manage, add, or edit delivery addresses.".tr, style: t.bodySm.withColor(c.textSecondary)),
              ),
            ),
            if (isLoading)
              const SliverToBoxAdapter(child: DsSkeletonList(itemCount: 4, leading: false, trailing: false))
            else if (addresses.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(
                  icon: Icons.location_off_outlined,
                  title: "Address not found".tr,
                  message: "Add a delivery address to get started.".tr,
                ),
              )
            else
              DsSliverResponsive(
                sliver: SliverList.builder(
                  itemCount: addresses.length,
                  itemBuilder: (context, index) {
                    final ShippingAddress address = addresses[index];
                    return DsFadeSlideIn(
                      index: index,
                      child: DsCard.outlined(
                        margin: const EdgeInsets.only(bottom: DsSpace.md),
                        onTap: () {
                          Get.back(result: address);
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DsIconWell(icon: _iconFor(address.addressAs), size: 42, circle: true),
                            const DsGap(DsSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: DsSpace.sm,
                                    runSpacing: DsSpace.xs,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      DsBadge(label: address.addressAs.toString(), small: true),
                                      if (address.isDefault == true) DsBadge(label: "Default".tr, tone: DsTone.success, style: DsBadgeStyle.solid, small: true),
                                    ],
                                  ),
                                  const DsGap(DsSpace.sm),
                                  Text(address.getFullAddress().toString(), style: t.body.withColor(c.textPrimary)),
                                ],
                              ),
                            ),
                            const DsGap(DsSpace.xs),
                            Column(
                              children: [
                                DsIconButton(
                                  semanticLabel: "Delete".tr,
                                  child: SvgPicture.asset("assets/icons/ic_delete_address.svg", width: 20, height: 20),
                                  onPressed: () async {
                                    await controller.deleteAddress(index);
                                  },
                                ),
                                DsIconButton(
                                  semanticLabel: "Edit".tr,
                                  child: SvgPicture.asset("assets/icons/ic_edit_address.svg", width: 20, height: 20),
                                  onPressed: () {
                                    Get.to(EnterManuallyLocationScreen(), arguments: {"address": address, "mode": "Edit"})!.then((value) {
                                      if (value == true) {
                                        controller.getUser();
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Add New Address".tr,
              size: DsButtonSize.lg,
              expand: true,
              leading: SvgPicture.asset(AppAssets.icPlus, width: 20, height: 18, colorFilter: ColorFilter.mode(c.onBrand, BlendMode.srcIn)),
              onPressed: () {
                Get.to(EnterManuallyLocationScreen())!.then((value) {
                  if (value == true) {
                    controller.getUser();
                  }
                });
              },
            ),
          ),
        );
      },
    );
  }

  IconData _iconFor(String? addressAs) {
    switch ((addressAs ?? '').trim().toLowerCase()) {
      case 'home':
        return Icons.home_rounded;
      case 'work':
      case 'office':
        return Icons.work_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }
}

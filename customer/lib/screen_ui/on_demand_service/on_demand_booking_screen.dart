import 'package:customer/utils/region_service.dart';
import 'package:bottom_picker/bottom_picker.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/on_demand_booking_controller.dart';
import '../../models/user_model.dart';
import '../../themes/show_toast_dialog.dart';
import '../../widget/osm_map/map_picker_page.dart';
import '../../widget/place_picker/location_picker_screen.dart';
import '../../widget/place_picker/selected_location_model.dart';
import '../location_enable_screens/address_list_screen.dart';

/// Archetype E – booking wizard: service summary, address, notes, schedule,
/// offers and the bill, with a sticky confirm bar.
class OnDemandBookingScreen extends StatelessWidget {
  const OnDemandBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: OnDemandBookingController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final l = context.dsLayout;

        return DsScaffold(
          title: "Book Service".tr,
          maxContentWidth: DsLayout.contentMax,
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: DsFadeSlideIn.stagger([
                // Services Section
                Text("Services".tr, style: t.titleSm),
                const DsGap(DsSpace.sm),
                DsCard.outlined(
                  padding: const EdgeInsets.all(DsSpace.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(controller.provider.value?.title ?? '', style: t.titleSm),
                            const DsGap(DsSpace.xs),
                            Text(controller.categoryTitle.value, style: t.bodySm),
                            if (controller.provider.value?.priceUnit == "Fixed") ...[
                              const DsGap(DsSpace.lg),
                              Row(
                                children: [
                                  DsIconButton(
                                    icon: Icons.remove_rounded,
                                    semanticLabel: 'Remove'.tr,
                                    variant: DsIconButtonVariant.tonal,
                                    size: 36,
                                    onPressed: controller.decrementQuantity,
                                  ),
                                  const DsGap(DsSpace.md),
                                  Text('${controller.quantity.value}', style: t.titleSm.tabular),
                                  const DsGap(DsSpace.md),
                                  DsIconButton(
                                    icon: Icons.add_rounded,
                                    semanticLabel: 'Add'.tr,
                                    variant: DsIconButtonVariant.brand,
                                    size: 36,
                                    onPressed: controller.incrementQuantity,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const DsGap(DsSpace.md),
                      DsImage(
                        url: (controller.provider.value?.photos.isNotEmpty ?? false) ? controller.provider.value!.photos.first : Constant.placeHolderImage,
                        height: 96,
                        width: 96,
                        radius: DsRadius.lg,
                      ),
                    ],
                  ),
                ),
                const DsGap(DsSpace.lg),
                DsCard.outlined(
                  padding: EdgeInsets.zero,
                  onTap: () => _pickAddress(context, controller),
                  semanticLabel: "Address".tr,
                  child: DsListTile(
                    title: "Address".tr,
                    subtitle: controller.selectedAddress.value.getFullAddress(),
                    leadingIcon: Icons.location_on_outlined,
                    leadingTone: DsTone.brand,
                    trailing: Text("Change".tr, style: t.link),
                    onTap: () => _pickAddress(context, controller),
                  ),
                ),
                const DsGap(DsSpace.lg),
                DsFormSection(
                  title: "Description".tr,
                  icon: Icons.notes_rounded,
                  children: [
                    DsTextField(hint: "Enter Description".tr, controller: controller.descriptionController.value, maxLines: 5, minLines: 3, bottomSpacing: 0),
                  ],
                ),
                const DsGap(DsSpace.lg),
                DsFormSection(
                  title: "Booking Date & Slot".tr,
                  icon: Icons.event_rounded,
                  children: [
                    DsTextField(
                      hint: "Choose Date and Time".tr,
                      controller: controller.dateTimeController.value,
                      readOnly: true,
                      bottomSpacing: 0,
                      suffix: Icon(Icons.calendar_month_rounded, color: c.brand, size: 20),
                      onTap: () {
                        BottomPicker<DateTime>.dateTime(
                          onSubmit: (date) {
                            controller.setDateTime(date!);
                          },
                          minDateTime: DateTime.now(),
                          buttonAlignment: MainAxisAlignment.center,
                          displaySubmitButton: true,
                          buttonSingleColor: c.brand,
                          buttonPadding: 10,
                          buttonWidth: 70,
                          // bottom_picker 5 dropped pickerTitle/closeIconColor and the built-in close icon; rebuild the same header.
                          headerBuilder: (context) => Row(
                            children: [
                              Expanded(child: Text("", style: t.bodyStrong)),
                              DsIconButton(icon: Icons.close_rounded, semanticLabel: 'Close'.tr, size: 36, onPressed: () => Navigator.pop(context)),
                            ],
                          ),
                          backgroundColor: c.surfaceRaised,
                          pickerTextStyle: t.bodyStrong,
                        ).show(context);
                      },
                    ),
                  ],
                ),
                const DsGap(DsSpace.lg),
                controller.provider.value?.priceUnit == "Fixed"
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        controller.couponList.isNotEmpty
                            ? SizedBox(
                              height: 92,
                              child: ListView.builder(
                                itemCount: controller.couponList.length,
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.zero,
                                itemBuilder: (context, index) {
                                  final coupon = controller.couponList[index];
                                  return GestureDetector(onTap: () => controller.applyCoupon(coupon), child: buildOfferItem(context, controller, index));
                                },
                              ),
                            )
                            : Container(),
                        buildPromoCode(context, controller),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                          child: Text("Price Detail".tr, style: t.titleSm),
                        ),
                        priceTotalRow(context, controller),
                      ],
                    )
                    : SizedBox(),
              ]),
            ),
          ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Confirm".tr,
              icon: Icons.check_circle_outline_rounded,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: () => controller.confirmBooking(context),
            ),
          ),
        );
      },
    );
  }

  /// Address picker – behaviour moved verbatim from the old address row.
  Future<void> _pickAddress(BuildContext context, OnDemandBookingController controller) async {
    if (Constant.userModel != null) {
      Get.to(AddressListScreen())!.then((value) {
        if (value != null) {
          ShippingAddress shippingAddress = value;
          if (Constant.checkZoneCheck(shippingAddress.location!.latitude ?? 0.0, shippingAddress.location!.longitude ?? 0.0)) {
            controller.selectedAddress.value = shippingAddress;
            controller.calculatePrice();
          } else {
            ShowToastDialog.showToast("Service not available in this area".tr);
          }
        }
      });
    } else {
      Constant.checkPermission(
        onTap: () async {
          ShowToastDialog.showLoader("Please wait...".tr);

          ShippingAddress shippingAddress = ShippingAddress();

          try {
            await Geolocator.requestPermission();
            await Geolocator.getCurrentPosition();
            ShowToastDialog.closeLoader();

            if (Constant.selectedMapType == 'osm') {
              final result = await Get.to(() => MapPickerPage());
              if (result != null) {
                final firstPlace = result;
                final lat = firstPlace.coordinates.latitude;
                final lng = firstPlace.coordinates.longitude;
                final address = firstPlace.address;

                shippingAddress.addressAs = "Home";
                shippingAddress.locality = address.toString();
                shippingAddress.location = UserLocation(latitude: lat, longitude: lng);

                controller.selectedAddress.value = shippingAddress;
                Get.back();
              }
            } else {
              Get.to(LocationPickerScreen())!.then((value) async {
                if (value != null) {
                  SelectedLocationModel selectedLocationModel = value;

                  shippingAddress.addressAs = "Home";
                  shippingAddress.location = UserLocation(latitude: selectedLocationModel.latLng!.latitude, longitude: selectedLocationModel.latLng!.longitude);
                  shippingAddress.locality = "Picked from Map";

                  controller.selectedAddress.value = shippingAddress;
                }
              });
            }
          } catch (e) {
            await Geocoding().placemarkFromCoordinates(19.228825, 72.854118).then((valuePlaceMaker) {
              Placemark placeMark = valuePlaceMaker[0];
              shippingAddress.location = UserLocation(latitude: 19.228825, longitude: 72.854118);
              String currentLocation =
                  "${placeMark.name}, ${placeMark.subLocality}, ${placeMark.locality}, ${placeMark.administrativeArea}, ${placeMark.postalCode}, ${placeMark.country}";
              shippingAddress.locality = currentLocation;
            });

            controller.selectedAddress.value = shippingAddress;
            ShowToastDialog.closeLoader();
          }
        },
        context: context,
      );
    }
  }

  /// Ticket-style coupon chip.
  Widget buildOfferItem(BuildContext context, OnDemandBookingController controller, int index) {
    return Obx(() {
      final coupon = controller.couponList[index];
      final c = context.dsColors;
      final t = context.dsText;

      return Container(
        margin: const EdgeInsetsDirectional.only(end: DsSpace.md, top: DsSpace.sm, bottom: DsSpace.sm),
        child: DottedBorder(
          options: RoundedRectDottedBorderOptions(strokeWidth: 1, radius: const Radius.circular(DsRadius.md), color: c.brand),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Image(image: AssetImage('assets/images/offer_icon.png'), height: 22, width: 22),
                    const DsGap(DsSpace.sm),
                    Text(
                      coupon.discountType == "Fix Price" ? "${Constant.amountShow(amount: coupon.discount.toString(), currency: RegionService.currencyForService(regionId: controller.provider.value?.regionId))} ${'OFF'.tr}" : "${coupon.discount} ${'% Off'.tr}",
                      style: t.titleSm.tabular,
                    ),
                  ],
                ),
                const DsGap(DsSpace.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(coupon.code ?? '', style: t.labelSm.withColor(c.brandStrong)),
                    Container(margin: const EdgeInsets.symmetric(horizontal: DsSpace.md), width: 1, height: 12, color: c.border),
                    Text("valid till ".tr + controller.getDate(coupon.expiresAt!.toDate().toString()), style: t.caption),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget buildPromoCode(BuildContext context, OnDemandBookingController controller) {
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.sm),
      child: DsCard.outlined(
        padding: const EdgeInsets.all(DsSpace.md),
        onTap: () {
          Get.bottomSheet(promoCodeSheet(context, controller), isScrollControlled: true, isDismissible: true, backgroundColor: Colors.transparent, enableDrag: true);
        },
        child: Row(
          children: [
            Image.asset("assets/images/reedem.png", height: 44, width: 44),
            const DsGap(DsSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Promo Code".tr, overflow: TextOverflow.ellipsis, style: t.titleSm),
                  const DsGap(DsSpace.xxs),
                  Text("Apply promo code".tr, overflow: TextOverflow.ellipsis, style: t.bodySm),
                ],
              ),
            ),
            DsIconButton(
              icon: Icons.add_rounded,
              semanticLabel: "Apply promo code".tr,
              variant: DsIconButtonVariant.tonal,
              onPressed: () {
                Get.bottomSheet(promoCodeSheet(context, controller), isScrollControlled: true, isDismissible: true, backgroundColor: Colors.transparent, enableDrag: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget promoCodeSheet(BuildContext context, OnDemandBookingController controller) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsSheet(
      title: 'Redeem Your Coupons'.tr,
      showClose: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Image(image: AssetImage('assets/images/redeem_coupon.png'), width: 100),
          const DsGap(DsSpace.lg),
          Text("Voucher or Coupon code".tr, textAlign: TextAlign.center, style: t.bodySecondary),
          const DsGap(DsSpace.lg),
          DottedBorder(
            options: RoundedRectDottedBorderOptions(strokeWidth: 1, radius: const Radius.circular(DsRadius.md), color: c.brand),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
              child: TextFormField(
                textAlign: TextAlign.center,
                style: t.titleSm.tabular,
                controller: controller.couponTextController.value,
                decoration: InputDecoration(border: InputBorder.none, hintText: "Write Coupon Code".tr, hintStyle: t.bodySecondary),
              ),
            ),
          ),
          const DsGap(DsSpace.xl),
          DsButton.primary(
            label: "REDEEM NOW".tr,
            size: DsButtonSize.lg,
            expand: true,
            onPressed: () {
              final inputCode = controller.couponTextController.value.text.trim().toLowerCase();

              final matchingCoupon = controller.couponList.firstWhereOrNull((c) => c.code?.toLowerCase() == inputCode);

              if (matchingCoupon != null) {
                controller.applyCoupon(matchingCoupon);
                Get.back();
              } else {
                ShowToastDialog.showToast("Applied coupon not valid.".tr);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget priceTotalRow(BuildContext context, OnDemandBookingController controller) {
    return Obx(() {
      final c = context.dsColors;
      final t = context.dsText;
      return DsCard.outlined(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
        child: Column(
          children: [
            rowText(context, "Price".tr, Constant.amountShow(amount: controller.price.value.toString(), currency: RegionService.currencyForService(regionId: controller.provider.value?.regionId))),
            controller.discountAmount.value != 0 ? const DsDivider(spacing: DsSpace.xs) : const SizedBox(),
            controller.discountAmount.value != 0
                ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${"Discount".tr} ${controller.discountType.value == 'Percentage' || controller.discountType.value == 'Percent' ? "(${controller.discountLabel.value}%)" : "(${Constant.amountShow(amount: controller.discountLabel.value, currency: RegionService.currencyForService(regionId: controller.provider.value?.regionId))})"}",
                              style: t.body,
                            ),
                            Text(controller.offerCode.value, style: t.caption),
                          ],
                        ),
                      ),
                      Text(
                        "(-${Constant.amountShow(amount: controller.discountAmount.value.toString(), currency: RegionService.currencyForService(regionId: controller.provider.value?.regionId))})",
                        style: t.bodyStrong.withColor(c.dangerStrong).tabular,
                      ),
                    ],
                  ),
                )
                : const SizedBox(),
            const DsDivider(spacing: DsSpace.xs),
            if (Constant.platformFeeModel?.enable == true) rowText(context, "Platform fee".tr, Constant.amountShow(amount: Constant.platformFeeModel?.fee.toString(), currency: RegionService.currencyForService(regionId: controller.provider.value?.regionId))),
            if (Constant.platformFeeModel?.enable == true) const DsDivider(spacing: DsSpace.xs),
            InkWell(
              onTap: () {
                showBillBifurcationDialog(context, controller);
              },
              child: rowText(context, "Tax amount".tr, Constant.amountShow(amount: (controller.taxAmount.value).toString(), currency: RegionService.currencyForService(regionId: controller.provider.value?.regionId)), underline: true),
            ),
            const DsDivider(spacing: DsSpace.xs),
            rowText(context, "Total Amount".tr, Constant.amountShow(amount: controller.totalAmount.value.toString(), currency: RegionService.currencyForService(regionId: controller.provider.value?.regionId)), total: true),
          ],
        ),
      );
    });
  }

  Widget rowText(BuildContext context, String title, String value, {bool? underline, bool total = false}) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title.tr,
              style: (total ? t.titleSm : t.body).copyWith(decoration: underline == true ? TextDecoration.underline : TextDecoration.none, decorationColor: c.textSecondary),
            ),
          ),
          const DsGap(DsSpace.md),
          Text(value.tr, style: total ? t.title.withColor(c.brandStrong).tabular : t.bodyStrong.tabular),
        ],
      ),
    );
  }

  void showBillBifurcationDialog(BuildContext context, OnDemandBookingController controller) {
    showDialog(
      context: context,
      builder: (context) {
        return DsDialog(
          title: "Tax Details".tr,
          icon: Icons.receipt_long_outlined,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              amountRow(context, title: "Tax on Order Total".tr, amount: Constant.amountShow(amount: controller.orderTaxAmount.value.toString(), currency: RegionService.currencyForService(regionId: controller.provider.value?.regionId))),
              const DsDivider(spacing: DsSpace.sm),
              amountRow(context, title: "Tax on Platform Fee".tr, amount: Constant.amountShow(amount: controller.platformTaxAmount.value.toString(), currency: RegionService.currencyForService(regionId: controller.provider.value?.regionId))),
              const DsDivider(spacing: DsSpace.sm),
              amountRow(context, title: "Total Tax Amount".tr, amount: Constant.amountShow(amount: controller.taxAmount.value.toString(), currency: RegionService.currencyForService(regionId: controller.provider.value?.regionId)), highlight: true),
            ],
          ),
          primaryLabel: "Close".tr,
          onPrimary: () => Navigator.pop(context),
        );
      },
    );
  }

  Widget amountRow(BuildContext context, {required String title, required String amount, bool highlight = false}) {
    final c = context.dsColors;
    final t = context.dsText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(title.tr, style: t.bodySecondary)),
        const DsGap(DsSpace.md),
        Text(amount, style: highlight ? t.titleSm.withColor(c.brandStrong).tabular : t.bodyStrong.tabular),
      ],
    );
  }
}

import 'package:driver/utils/region_service.dart';
import 'package:driver/app/parcel_screen/parcel_order_details.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/parcel_search_controller.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/network_image_widget.dart';
import 'package:driver/widget/osm_map/map_picker_page.dart';
import 'package:driver/widget/osm_map/place_model.dart';
import 'package:driver/widget/place_picker/location_picker_screen.dart';
import 'package:driver/widget/place_picker/selected_location_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as latlong;

/// Parcel search (archetype H form + J results): a route/date query card on top,
/// then the matching bookings as acceptable job cards.
class ParcelSearchScreen extends StatelessWidget {
  const ParcelSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
        init: ParcelSearchController(),
        builder: (controller) {
          final c = context.dsColors;
          return DsScaffold(
            backgroundColor: c.background,
            title: "Search parcel".tr,
            body: controller.isLoading.value
                ? const DsSkeletonList(itemCount: 4)
                : Column(
                    children: [
                      DsResponsive(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.sm),
                          child: DsFadeSlideIn(
                            child: DsCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  DsTextField(
                                    readOnly: true,
                                    controller: controller.sourceTextEditController.value,
                                    bottomSpacing: DsSpace.md,
                                    prefixIcon: Icons.trip_origin_rounded,
                                    onTap: () async {
                                      if (Constant.selectedMapType == 'osm') {
                                        PlaceModel? result = await Get.to(() => MapPickerPage());
                                        if (result != null) {
                                          controller.sourceTextEditController.value.text = '';
                                          final firstPlace = result;
                                          final lat = firstPlace.coordinates.latitude;
                                          final lng = firstPlace.coordinates.longitude;

                                          controller.sourceTextEditController.value.text = result.address.toString();
                                          controller.departureLatLongOsm.value = latlong.LatLng(lat, lng);
                                        }
                                      } else {
                                        Get.to(LocationPickerScreen())!.then((value) async {
                                          if (value != null) {
                                            SelectedLocationModel selectedLocationModel = value;

                                            final place = selectedLocationModel.address;

                                            // ✅ Build full readable address from Placemark fields
                                            controller.sourceTextEditController.value.text = '${place?.name ?? ''}, ${place?.street ?? ''}, ${place?.subLocality ?? ''}, '
                                                    '${place?.locality ?? ''}, ${place?.administrativeArea ?? ''}, ${place?.postalCode ?? ''}, ${place?.country ?? ''}'
                                                .replaceAll(RegExp(r', ,|, , ,'), ',')
                                                .trim()
                                                .replaceAll(RegExp(r',+$'), '');

                                            controller.departureLatLong.value = latlong.LatLng(
                                              selectedLocationModel.latLng!.latitude,
                                              selectedLocationModel.latLng!.longitude,
                                            );
                                          }
                                        });
                                      }
                                    },
                                    hint: 'Where you want to go?',
                                  ),
                                  DsTextField(
                                    readOnly: true,
                                    controller: controller.destinationTextEditController.value,
                                    bottomSpacing: DsSpace.md,
                                    prefixIcon: Icons.place_outlined,
                                    onTap: () async {
                                      if (Constant.selectedMapType == 'osm') {
                                        PlaceModel? result = await Get.to(() => MapPickerPage());
                                        if (result != null) {
                                          controller.destinationTextEditController.value.text = '';
                                          final firstPlace = result;
                                          final lat = firstPlace.coordinates.latitude;
                                          final lng = firstPlace.coordinates.longitude;
                                          // ignore: unused_local_variable
                                          final address = firstPlace.address;
                                          controller.destinationTextEditController.value.text = result.address.toString();
                                          controller.destinationLatLongOsm.value = latlong.LatLng(lat, lng);
                                        }
                                      } else {
                                        Get.to(LocationPickerScreen())!.then(
                                          (value) async {
                                            if (value != null) {
                                              SelectedLocationModel selectedLocationModel = value;
                                              final place = selectedLocationModel.address;

                                              controller.destinationTextEditController.value.text = '${place?.name ?? ''}, ${place?.street ?? ''}, ${place?.subLocality ?? ''}, '
                                                      '${place?.locality ?? ''}, ${place?.administrativeArea ?? ''}, ${place?.postalCode ?? ''}, ${place?.country ?? ''}'
                                                  .replaceAll(RegExp(r', ,|, , ,'), ',')
                                                  .trim()
                                                  .replaceAll(RegExp(r',+$'), '');

                                              controller.destinationLatLong.value = latlong.LatLng(
                                                selectedLocationModel.latLng!.latitude,
                                                selectedLocationModel.latLng!.longitude,
                                              );
                                            }
                                          },
                                        );
                                      }
                                    },
                                    hint: 'Where to?'.tr,
                                  ),
                                  DsTextField(
                                    controller: controller.dateTimeTextEditController.value,
                                    hint: 'Select Date'.tr,
                                    readOnly: true,
                                    bottomSpacing: DsSpace.lg,
                                    prefixIcon: Icons.event_outlined,
                                    onTap: () async {
                                      controller.pickDateTime();
                                    },
                                  ),
                                  DsButton.primary(
                                    label: "Search Parcel".tr,
                                    icon: Icons.search_rounded,
                                    size: DsButtonSize.lg,
                                    expand: true,
                                    onPressed: () async {
                                      FocusScope.of(context).unfocus();
                                      controller.searchParcel();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: controller.parcelList.isEmpty
                            ? DsEmptyState(
                                icon: Icons.manage_search_rounded,
                                compact: true,
                                title: "Parcel Booking not found".tr,
                              )
                            : DsResponsive(
                                child: ListView.separated(
                                  itemCount: controller.parcelList.length,
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, DsSpace.xxl),
                                  separatorBuilder: (_, _) => const DsGap(DsSpace.lg),
                                  itemBuilder: (context, index) {
                                    ParcelOrderModel parcelBookingData = controller.parcelList[index];
                                    return DsFadeSlideIn(
                                      index: index,
                                      child: _ParcelResultCard(
                                        order: parcelBookingData,
                                        amount: Constant.amountShow(
                                                currency: RegionService.currencyForRecord(parcelBookingData.regionId),
                                                amount: controller.calculateParcelTotalAmountBooking(parcelBookingData))
                                            .tr,
                                        categoryImage: controller.getSelectedCategory(parcelBookingData)?.image ?? '',
                                        hasCategoryImage: controller.getSelectedCategory(parcelBookingData)?.image != null &&
                                            controller.getSelectedCategory(parcelBookingData)!.image!.isNotEmpty,
                                        scheduleLabel: parcelBookingData.isSchedule == true
                                            ? "Schedule Pickup time: ${controller.formatDate(parcelBookingData.senderPickupDateTime!)}"
                                            : null,
                                        onOpen: () {
                                          Get.to(() => const ParcelOrderDetails(), arguments: parcelBookingData);
                                        },
                                        onAccept: () async {
                                          final hasOwner = controller.driverModel.value.ownerId != null && controller.driverModel.value.ownerId!.isNotEmpty;
                                          if (hasOwner) {
                                            final ownerWallet = controller.ownerModel.value.walletAmount ?? 0.0;
                                            final minOwnerDeposit = double.parse(Constant.ownerMinimumDepositToRideAccept);
                                            if (ownerWallet >= minOwnerDeposit) {
                                              controller.acceptParcelBooking(parcelBookingData);
                                            } else {
                                              ShowToastDialog.showToast("Your owner has to maintain minimum {amount} wallet balance to accept the parcel booking. Please contact your owner"
                                                  .trParams({"amount": Constant.amountShow(amount: Constant.ownerMinimumDepositToRideAccept)}).tr);
                                            }
                                          } else {
                                            final driverWallet = controller.driverModel.value.walletAmount ?? 0.0;
                                            final minDeposit = double.parse(Constant.minimumDepositToRideAccept);
                                            if (driverWallet >= minDeposit) {
                                              controller.acceptParcelBooking(parcelBookingData);
                                            } else {
                                              ShowToastDialog.showToast(
                                                  "You must have at least ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} in your wallet to accept this order"
                                                      .trParams({"amount": Constant.amountShow(amount: Constant.minimumDepositToRideAccept)}).tr);
                                            }
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
          );
        });
  }
}

/// A searchable parcel booking the driver can accept.
class _ParcelResultCard extends StatelessWidget {
  final ParcelOrderModel order;
  final String amount;
  final String categoryImage;
  final bool hasCategoryImage;
  final String? scheduleLabel;
  final VoidCallback onOpen;
  final VoidCallback onAccept;

  const _ParcelResultCard({
    required this.order,
    required this.amount,
    required this.categoryImage,
    required this.hasCategoryImage,
    required this.scheduleLabel,
    required this.onOpen,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard(
      onTap: onOpen,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: c.surfaceAlt,
            padding: const EdgeInsets.all(DsSpace.lg),
            child: DsRouteStops(
              stops: [
                DsRouteStop(kind: DsStopKind.pickup, label: 'Pickup'.tr, address: "${order.sender!.address}"),
                DsRouteStop(kind: DsStopKind.drop, label: 'Delivery'.tr, address: "${order.receiver!.address}"),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DsSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DsAvatar(imageUrl: order.author!.profilePictureURL.toString(), name: order.author!.fullName(), size: 48),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: Text(
                        order.author!.fullName(),
                        textAlign: TextAlign.start,
                        style: t.titleSm.w700,
                      ),
                    ),
                  ],
                ),
                const DsGap(DsSpace.lg),
                DsTripMetrics(
                  items: [
                    DsTripMetric(icon: Icons.payments_outlined, value: amount, label: 'Amount'.tr),
                    DsTripMetric(icon: Icons.event_outlined, value: '${Constant.timestampToDate(order.senderPickupDateTime!)}  '.tr, label: 'Date'.tr),
                    DsTripMetric(icon: Icons.scale_outlined, value: '${order.parcelWeight}'.tr, label: 'Weight'.tr),
                  ],
                ),
                const DsGap(DsSpace.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Parcel Type:".tr, style: t.bodySecondary),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              order.parcelType ?? '',
                              textAlign: TextAlign.end,
                              style: t.bodyStrong,
                            ),
                          ),
                          if (hasCategoryImage) ...[
                            const DsGap(DsSpace.sm),
                            NetworkImageWidget(imageUrl: categoryImage, height: 20, width: 20),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (scheduleLabel != null) ...[
                  const DsGap(DsSpace.md),
                  DsInlineAlert(tone: DsTone.info, icon: Icons.schedule_rounded, message: scheduleLabel!),
                ],
                const DsGap(DsSpace.lg),
                DsButton.success(
                  label: "Accept".tr,
                  icon: Icons.check_rounded,
                  size: DsButtonSize.xl,
                  expand: true,
                  onPressed: onAccept,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

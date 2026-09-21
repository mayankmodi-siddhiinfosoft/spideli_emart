import 'package:driver/app/parcel_screen/parcel_order_details.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/parcel_search_controller.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/round_button_fill.dart';
import 'package:driver/themes/text_field_widget.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/network_image_widget.dart';
import 'package:driver/widget/dotted_line.dart';
import 'package:driver/widget/osm_map/map_picker_page.dart';
import 'package:driver/widget/osm_map/place_model.dart';
import 'package:driver/widget/place_picker/location_picker_screen.dart';
import 'package:driver/widget/place_picker/selected_location_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as latlong;
import 'package:timelines_plus/timelines_plus.dart';

class ParcelSearchScreen extends StatelessWidget {
  const ParcelSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
        init: ParcelSearchController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            appBar: AppBar(
              backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
              centerTitle: false,
              titleSpacing: 0,
              iconTheme: IconThemeData(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, size: 20),
              title: Text(
                "Search parcel".tr,
                style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 18, fontFamily: AppThemeData.medium),
              ),
            ),
            body: controller.isLoading.value
                ? Constant.loader()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFieldWidget(
                                readOnly: true,
                                controller: controller.sourceTextEditController.value,
                                onClick: () async {
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
                                hintText: 'Where you want to go?',
                                prefix: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: SvgPicture.asset("assets/icons/ic_source.svg"),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: TextFieldWidget(
                                readOnly: true,
                                controller: controller.destinationTextEditController.value,
                                onClick: () async {
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
                                hintText: 'Where to?'.tr,
                                prefix: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: SvgPicture.asset("assets/icons/ic_destination.svg"),
                                ),
                              ),
                            ),
                          ],
                        ),
                        TextFieldWidget(
                          controller: controller.dateTimeTextEditController.value,
                          hintText: 'Select Date'.tr,
                          readOnly: true,
                          onClick: () async {
                            controller.pickDateTime();
                          },
                          prefix: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SvgPicture.asset("assets/images/ic_data.svg"),
                          ),
                        ),
                        RoundedButtonFill(
                          title: "Search Parcel".tr,
                          height: 5.5,
                          color: AppThemeData.primary300,
                          textColor: AppThemeData.grey50,
                          onPress: () async {
                            FocusScope.of(context).unfocus();
                            controller.searchParcel();
                          },
                        ),
                        Expanded(
                          child: controller.parcelList.isEmpty
                              ? Constant.showEmptyView(message: "Parcel Booking not found".tr, isDark: isDark)
                              : ListView.builder(
                                  itemCount: controller.parcelList.length,
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemBuilder: (context, index) {
                                    ParcelOrderModel parcelBookingData = controller.parcelList[index];
                                    return InkWell(
                                      onTap: () {
                                        Get.to(() => const ParcelOrderDetails(), arguments: parcelBookingData);
                                      },
                                      child: Container(
                                        width: Responsive.width(100, context),
                                        margin: const EdgeInsets.all(8),
                                        padding: const EdgeInsets.all(16),
                                        decoration: ShapeDecoration(
                                          color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          shadows: [
                                            BoxShadow(
                                              color: isDark ? AppThemeData.greyDark200 : Color(0x14000000),
                                              blurRadius: 23,
                                              offset: Offset(0, 0),
                                              spreadRadius: 0,
                                            )
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                color: isDark ? AppThemeData.greyDark100 : AppThemeData.grey100,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                child: Timeline.tileBuilder(
                                                  shrinkWrap: true,
                                                  padding: EdgeInsets.zero,
                                                  physics: const NeverScrollableScrollPhysics(),
                                                  theme: TimelineThemeData(
                                                    nodePosition: 0,
                                                    // indicatorPosition: 0,
                                                  ),
                                                  builder: TimelineTileBuilder.connected(
                                                    contentsAlign: ContentsAlign.basic,
                                                    indicatorBuilder: (context, index) {
                                                      return index == 0
                                                          ? SvgPicture.asset("assets/icons/ic_source.svg")
                                                          : index == 1
                                                              ? SvgPicture.asset("assets/icons/ic_destination.svg")
                                                              : SizedBox();
                                                    },
                                                    connectorBuilder: (context, index, connectorType) {
                                                      return DashedLineConnector(
                                                        color: isDark ? AppThemeData.greyDark300 : AppThemeData.grey300,
                                                        gap: 4,
                                                      );
                                                    },
                                                    contentsBuilder: (context, index) {
                                                      return Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                        child: Text(
                                                          index == 0 ? "${parcelBookingData.sender!.address}" : "${parcelBookingData.receiver!.address}",
                                                          style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                        ),
                                                      );
                                                    },
                                                    itemCount: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              children: [
                                                ClipOval(
                                                  child: NetworkImageWidget(
                                                    imageUrl: parcelBookingData.author!.profilePictureURL.toString(),
                                                    width: 52,
                                                    height: 52,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 10,
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        parcelBookingData.author!.fullName(),
                                                        textAlign: TextAlign.start,
                                                        style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              ],
                                            ),
                                            SizedBox(
                                              height: 12,
                                            ),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    children: [
                                                      SvgPicture.asset(
                                                        "assets/icons/ic_amount.svg",
                                                        colorFilter: ColorFilter.mode(isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, BlendMode.srcIn),
                                                      ),
                                                      SizedBox(
                                                        height: 5,
                                                      ),
                                                      Text(
                                                        Constant.amountShow(amount: controller.calculateParcelTotalAmountBooking(parcelBookingData)).tr,
                                                        textAlign: TextAlign.start,
                                                        style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    children: [
                                                      SvgPicture.asset(
                                                        "assets/icons/ic_date.svg",
                                                        colorFilter: ColorFilter.mode(isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, BlendMode.srcIn),
                                                      ),
                                                      SizedBox(
                                                        height: 5,
                                                      ),
                                                      Text(
                                                        '${Constant.timestampToDate(parcelBookingData.senderPickupDateTime!)}  '.tr,
                                                        textAlign: TextAlign.start,
                                                        style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    children: [
                                                      SvgPicture.asset(
                                                        "assets/icons/weight-line.svg",
                                                        colorFilter: ColorFilter.mode(isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, BlendMode.srcIn),
                                                      ),
                                                      SizedBox(
                                                        height: 5,
                                                      ),
                                                      Text(
                                                        '${parcelBookingData.parcelWeight}'.tr,
                                                        textAlign: TextAlign.start,
                                                        style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                      )
                                                    ],
                                                  ),
                                                )
                                              ],
                                            ),
                                            SizedBox(
                                              height: 12,
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  "Parcel Type:".tr,
                                                  style: AppThemeData.semiBoldTextStyle(
                                                    fontSize: 16,
                                                    color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800,
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      parcelBookingData.parcelType ?? '',
                                                      style: AppThemeData.semiBoldTextStyle(
                                                        fontSize: 16,
                                                        color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    if (controller.getSelectedCategory(parcelBookingData)?.image != null && controller.getSelectedCategory(parcelBookingData)!.image!.isNotEmpty)
                                                      NetworkImageWidget(imageUrl: controller.getSelectedCategory(parcelBookingData)?.image ?? '', height: 20, width: 20),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            if (parcelBookingData.isSchedule == true)
                                              SizedBox(
                                                height: 12,
                                              ),
                                            if (parcelBookingData.isSchedule == true)
                                              Text(
                                                "Schedule Pickup time: ${controller.formatDate(parcelBookingData.senderPickupDateTime!)}",
                                                style: AppThemeData.mediumTextStyle(fontSize: 14, color: AppThemeData.info400),
                                              ),
                                            const SizedBox(height: 16),
                                            DottedLine(
                                              dashColor: Colors.grey,
                                              lineThickness: 1.0,
                                              dashLength: 4.0,
                                              dashGapLength: 3.0,
                                              direction: Axis.horizontal,
                                            ),
                                            const SizedBox(height: 16),
                                            RoundedButtonFill(
                                              title: "Accept".tr,
                                              height: 5.5,
                                              color: AppThemeData.primary300,
                                              textColor: AppThemeData.grey50,
                                              onPress: () async {
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
                                            )
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        )
                      ],
                    ),
                  ),
          );
        });
  }
}

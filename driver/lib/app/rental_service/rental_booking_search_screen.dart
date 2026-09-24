import 'package:driver/utils/region_service.dart';
import 'package:driver/app/rental_service/rental_order_details_screen.dart';
import 'package:driver/app/rental_service/widget/rental_proposal_card.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/rental_booking_search_controller.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Archetype B – incoming rental requests as a stack of request cards with
/// the section badge, fare, route, package metrics and Reject / Accept.
class RentalBookingSearchScreen extends StatelessWidget {
  const RentalBookingSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
        init: RentalBookingSearchController(),
        builder: (controller) {
          return DsScaffold(
            title: "Search Rental Booking".tr,
            body: DsAsync(
              isLoading: controller.isLoading.value,
              skeleton: const DsSkeletonList(itemCount: 3, leading: false, trailing: false),
              isEmpty: controller.rentalBookingData.isEmpty,
              empty: Center(
                child: DsEmptyState(icon: Icons.car_rental_rounded, title: "No Rental booking available", compact: true),
              ),
              builder: (_) => ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
                itemCount: controller.rentalBookingData.length,
                itemBuilder: (context, index) {
                  RentalOrderModel rentalBookingData = controller.rentalBookingData[index];
                  return DsFadeSlideIn(
                    index: index,
                    child: _requestCard(context, controller, rentalBookingData),
                  );
                },
              ),
            ),
          );
        });
  }

  Widget _requestCard(BuildContext context, RentalBookingSearchController controller, RentalOrderModel rentalBookingData) {
    return DsPressable(
      onTap: () {
        Get.to(() => RentalOrderDetailsScreen(), arguments: {"rentalOrder": rentalBookingData.id});
      },
      child: DsRequestCard(
        margin: const EdgeInsets.only(bottom: DsSpace.md),
        title: '${rentalBookingData.author!.firstName} ${rentalBookingData.author!.lastName}'.tr,
        section: DsSection.rental,
        sectionLabel: "Rental".tr,
        fare: Constant.amountShow(currency: RegionService.currencyForRecord(rentalBookingData.regionId), amount: rentalBookingData.subTotal).tr,
        fareCaption: Constant.timestampToDateTime(rentalBookingData.bookingDateTime!).tr,
        stops: [
          DsRouteStop(kind: DsStopKind.pickup, label: "Pickup".tr, address: "${rentalBookingData.sourceLocationName}"),
        ],
        metrics: [
          DsTripMetric(icon: Icons.inventory_2_outlined, value: "${rentalBookingData.rentalPackageModel!.name}".tr, label: "Package Details:".tr),
          DsTripMetric(
            icon: Icons.route_rounded,
            value: "${rentalBookingData.rentalPackageModel!.includedDistance} ${Constant.distanceType}".tr,
            label: "Including Distance:".tr,
          ),
          DsTripMetric(icon: Icons.schedule_rounded, value: "${rentalBookingData.rentalPackageModel!.includedHours} Hr".tr, label: "Including Duration:".tr),
        ],
        extra: RentalProposalCard(order: rentalBookingData, isDark: context.dsIsDark, onChanged: () => controller.getRentalSearchBooking()),
        rejectLabel: "Reject".tr,
        onReject: () async {
          await controller.rejectBooking(rentalBookingData);
        },
        acceptLabel: "Accept".tr,
        onAccept: () async {
          if (controller.driverModel.value.ownerId != null && controller.driverModel.value.ownerId!.isNotEmpty) {
            if (controller.ownerModel.value.walletAmount != null && controller.ownerModel.value.walletAmount! >= double.parse(Constant.minimumDepositToRideAccept)) {
              await controller.acceptBooking(rentalBookingData);
            } else {
              ShowToastDialog.showToast(
                  "Your owner has to maintain minimum ${Constant.amountShow(amount: Constant.ownerMinimumDepositToRideAccept)} wallet balance to accept the rental booking. Please contact your owner"
                      .tr);
            }
          } else {
            if (controller.driverModel.value.walletAmount! >= double.parse(Constant.minimumDepositToRideAccept)) {
              await controller.acceptBooking(rentalBookingData);
            } else {
              ShowToastDialog.showToast("Your owner has to maintain minimum @amount wallet balance to accept the rental booking. Please contact your owner"
                  .trParams({"amount": Constant.amountShow(amount: Constant.ownerMinimumDepositToRideAccept)}));
            }
          }
        },
      ),
    );
  }
}

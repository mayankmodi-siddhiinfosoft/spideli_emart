import 'package:driver/app/rental_service/widget/rental_proposal_card.dart';
import 'package:driver/utils/region_service.dart';
import 'package:driver/app/chat_screens/chat_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/rental_order_details_controller.dart';

/// Archetype J (detail) – booking header, customer, vehicle, rental details
/// and the fare breakdown, each as its own card.
class RentalOrderDetailsScreen extends StatelessWidget {
  const RentalOrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: RentalOrderDetailsController(),
      builder: (controller) {
        return DsScaffold(
          title: "Order Details".tr,
          body: DsAsync(
            isLoading: controller.isLoading.value,
            skeleton: const DsSkeletonDetail(),
            builder: (_) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: DsFadeSlideIn.stagger([
                  RentalProposalCard(
                    order: controller.order.value,
                    isDark: context.dsIsDark,
                    onChanged: () {
                      if (controller.order.value.id != null) controller.fetchOrder(controller.order.value.id!);
                    },
                  ),
                  if ((controller.order.value.cancelReason?.isNotEmpty ?? false) &&
                      [Constant.orderCancelled, Constant.orderRejected, Constant.driverRejected].contains(controller.order.value.status))
                    Padding(
                      padding: const EdgeInsets.only(bottom: DsSpace.md),
                      child: DsInlineAlert(
                        tone: DsTone.danger,
                        icon: Icons.block_rounded,
                        message:
                            "${'Cancellation reason'.tr}${controller.order.value.cancelledBy == null ? '' : ' (${controller.order.value.cancelledBy!.tr})'}: ${controller.order.value.cancelReason}",
                      ),
                    ),
                  _bookingCard(context, controller),
                  const DsGap(DsSpace.lg),
                  if (controller.order.value.rentalPackageModel != null) ...[
                    _preferenceCard(context, controller),
                    const DsGap(DsSpace.lg),
                  ],
                  if (controller.order.value.author != null) ...[
                    _customerCard(context, controller),
                    const DsGap(DsSpace.lg),
                  ],
                  if (controller.order.value.rentalVehicleType != null) ...[
                    _vehicleCard(context, controller),
                    const DsGap(DsSpace.lg),
                  ],
                  _rentalDetailsCard(context, controller),
                  const DsGap(DsSpace.lg),
                  _summaryCard(context, controller),
                  if (!(controller.order.value.driver != null && controller.order.value.driver!.ownerId != null && controller.order.value.driver!.ownerId!.isNotEmpty ||
                      controller.order.value.status == Constant.orderPlaced))
                    Padding(
                      padding: const EdgeInsets.only(top: DsSpace.md),
                      child: DsInlineAlert(
                        tone: DsTone.danger,
                        icon: Icons.info_outline_rounded,
                        message: "Note : Admin commission will be debited from your wallet balance. \n \nAdmin commission will apply on your booking Amount minus Discount(if applicable).",
                      ),
                    ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bookingCard(BuildContext context, RentalOrderDetailsController controller) {
    final t = context.dsText;
    return DsCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text("Booking Id : ${controller.order.value.id}", style: t.bodyStrong.tabular)),
              DsIconButton(
                icon: Icons.copy_rounded,
                semanticLabel: "Copy booking ID".tr,
                variant: DsIconButtonVariant.tonal,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: controller.order.value.id.toString()));
                  ShowToastDialog.showToast("Booking ID copied to clipboard".tr);
                },
              ),
            ],
          ),
          const DsGap(DsSpace.md),
          DsRouteStops(
            stops: [
              DsRouteStop(
                kind: DsStopKind.pickup,
                label: controller.order.value.bookingDateTime != null ? Constant.timestampToDate(controller.order.value.bookingDateTime!) : null,
                address: controller.order.value.sourceLocationName ?? "-",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _preferenceCard(BuildContext context, RentalOrderDetailsController controller) {
    final t = context.dsText;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Your Preference", style: t.overline),
          const DsGap(DsSpace.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(controller.order.value.rentalPackageModel!.name ?? "-", style: t.title),
                    const DsGap(DsSpace.xs),
                    Text(controller.order.value.rentalPackageModel!.description ?? "", style: t.bodySm),
                  ],
                ),
              ),
              const DsGap(DsSpace.md),
              Text(
                Constant.amountShow(
                    currency: RegionService.currencyForRecord(controller.order.value.regionId), amount: controller.order.value.rentalPackageModel!.baseFare.toString()),
                style: t.title.w700.tabular,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _customerCard(BuildContext context, RentalOrderDetailsController controller) {
    final t = context.dsText;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("About Customer".tr, style: t.overline),
          const DsGap(DsSpace.sm),
          Row(
            children: [
              DsAvatar(
                imageUrl: controller.userData.value?.profilePictureURL ?? '',
                name: controller.userData.value?.fullName(),
                size: 52,
              ),
              const DsGap(DsSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(controller.userData.value?.fullName() ?? '', style: t.title),
                    Text(controller.userData.value?.email ?? '', style: t.bodySm),
                    Text(controller.userData.value?.phoneNumber ?? '', style: t.bodyStrong.tabular),
                  ],
                ),
              ),
              const DsGap(DsSpace.sm),
              DsIconButton(
                icon: Icons.forum_outlined,
                semanticLabel: "Chat with customer".tr,
                variant: DsIconButtonVariant.brand,
                onPressed: () async {
                  ShowToastDialog.showLoader("Please wait".tr);

                  UserModel? customer = await FireStoreUtils.getUserProfile(controller.order.value.authorID.toString());
                  UserModel? driver = await FireStoreUtils.getUserProfile(controller.order.value.driverId.toString());

                  ShowToastDialog.closeLoader();

                  Get.to(const ChatScreen(), arguments: {
                    "senderName": driver?.fullName(),
                    "receivedName": customer?.fullName(),
                    "orderId": controller.order.value.id,
                    "senderId": driver?.id,
                    "receivedId": customer?.id,
                    "receivedProfileUrl": customer?.profilePictureURL ?? "",
                    "senderProfileUrl": driver?.profilePictureURL ?? "",
                    "token": customer?.fcmToken,
                    "chatType": Constant.userRoleDriver,
                  });
                },
              ),
              // Visibility(
              //   visible: controller.order.value?.status == Constant.orderCompleted ? true : false,
              //   child: Padding(
              //     padding: const EdgeInsets.symmetric(vertical: 10),
              //     child: RoundedButtonFill(
              //       title: 'Add Review'.tr,
              //       onPress: () async {
              //         final result = await Get.to(() => RentalReviewScreen(), arguments: {'order': controller.order.value});
              //
              //         // If review was submitted successfully
              //         if (result == true) {
              //           await controller.fetchCustomerDetails();
              //         }
              //       },
              //       height: 5,
              //       borderRadius: 15,
              //       color: Colors.orange,
              //       textColor: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
              //     ),
              //   ),
              // ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vehicleCard(BuildContext context, RentalOrderDetailsController controller) {
    final t = context.dsText;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Vehicle Type".tr, style: t.overline),
          const DsGap(DsSpace.md),
          Row(
            children: [
              DsImage(url: controller.order.value.rentalVehicleType!.rentalVehicleIcon ?? "", height: 50, width: 50, radius: DsRadius.md),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(controller.order.value.rentalVehicleType!.name ?? "", style: t.title),
                    Text(controller.order.value.rentalVehicleType!.shortDescription ?? "", style: t.bodySecondary),
                  ],
                ),
              ),
              const DsGap(DsSpace.md),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rentalDetailsCard(BuildContext context, RentalOrderDetailsController controller) {
    final t = context.dsText;
    final order = controller.order.value;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Rental Details".tr, style: t.titleSm),
          const DsDivider(spacing: DsSpace.sm),
          DsInfoRow(label: 'Rental Package'.tr, value: order.rentalPackageModel!.name.toString().tr),
          DsInfoRow(
            label: 'Rental Package Price'.tr,
            value: Constant.amountShow(currency: RegionService.currencyForRecord(order.regionId), amount: order.rentalPackageModel!.baseFare.toString()).tr,
          ),
          DsInfoRow(
            label: 'Including ${Constant.distanceType.tr}',
            value: "${order.rentalPackageModel!.includedDistance.toString()} ${Constant.distanceType}".tr,
          ),
          DsInfoRow(label: 'Including Hours'.tr, value: "${order.rentalPackageModel!.includedHours.toString()} Hr".tr),
          DsInfoRow(label: 'Extra ${Constant.distanceType}', value: controller.getExtraKm()),

          // Padding(
          //   padding: const EdgeInsets.symmetric(vertical: 10),
          //   child: Row(
          //     children: [
          //       Expanded(
          //         child: Text(
          //           'Extra ${Constant.distanceType}',
          //           textAlign: TextAlign.start,
          //           style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
          //         ),
          //       ),
          //       Text(
          //         "${(double.parse(controller.order.value.endKitoMetersReading!.toString()) - double.parse(controller.order.value.startKitoMetersReading!.toString()) - double.parse(controller.order.value.rentalPackageModel!.includedDistance!.toString()))} ${Constant.distanceType}",
          //         textAlign: TextAlign.start,
          //         style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
          //       ),
          //     ],
          //   ),
          // ),
          if (order.endTime != null)
            DsInfoRow(
              label: 'Extra Minutes'.tr,
              value:
                  "${order.endTime == null ? "0" : (((order.endTime!.toDate().difference(order.startTime!.toDate()).inMinutes) - (int.parse(order.rentalPackageModel!.includedHours.toString()) * 60)).clamp(0, double.infinity).toInt().toString())} Min",
            ),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context, RentalOrderDetailsController controller) {
    final t = context.dsText;
    final order = controller.order.value;
    final currency = RegionService.currencyForRecord(order.regionId);
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Order Summary".tr, style: t.overline),
          const DsGap(DsSpace.sm),
          DsInfoRow(label: "Subtotal".tr, value: Constant.amountShow(currency: currency, amount: controller.subTotal.value.toString())),
          DsInfoRow(
            label: "Discount".tr,
            value: Constant.amountShow(currency: currency, amount: controller.discount.value.toString()),
            valueTone: DsTone.danger,
          ),
          ...List.generate(order.taxSetting?.length ?? 0, (index) {
            final taxModel = order.taxSetting![index];
            final taxTitle = "${taxModel.title} ${taxModel.type == 'fix' ? '(${Constant.amountShow(currency: currency, amount: taxModel.tax)})' : '(${taxModel.tax}%)'}";
            return DsInfoRow(
              label: taxTitle,
              value: Constant.amountShow(
                currency: currency,
                amount: Constant.getTaxValue(
                  amount: (controller.subTotal.value - controller.discount.value).toString(),
                  taxModel: taxModel,
                ).toString(),
              ),
            );
          }),
          const DsDivider(spacing: DsSpace.sm),
          DsInfoRow(label: "Order Total".tr, value: Constant.amountShow(currency: currency, amount: controller.totalAmount.value.toString()), emphasize: true),
          DsInfoRow(
            label: "Admin Commission (${order.adminCommission}${order.adminCommissionType == "Percentage" || order.adminCommissionType == "percentage" ? "%" : Constant.currencyModel!.symbol})".tr,
            value: Constant.amountShow(currency: currency, amount: controller.adminCommission.value.toString()),
            valueTone: DsTone.danger,
          ),
        ],
      ),
    );
  }
}

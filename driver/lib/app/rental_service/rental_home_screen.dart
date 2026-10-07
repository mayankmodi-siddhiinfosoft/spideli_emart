import 'package:driver/utils/address_format.dart';
import 'package:driver/utils/region_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/app/rental_service/rental_booking_search_screen.dart';
import 'package:driver/app/rental_service/rental_order_details_screen.dart';
import 'package:driver/app/wallet_screen/payment_list_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/rental_dashboard_controller.dart';
import 'package:driver/controllers/rental_home_controller.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/services/driver_job_queue_service.dart';
import 'package:driver/themes/custom_dialog_box.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../models/user_model.dart';
import '../chat_screens/chat_screen.dart';

/// Archetype J / A – the rental driver's job board: one booking card per
/// active rental with its single next action at the bottom of the card.
class RentalHomeScreen extends StatelessWidget {
  const RentalHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      themeController.isDark.value;
      return GetX(
          init: RentalHomeController(),
          builder: (controller) {
            final bool verified = !(Constant.userModel?.isDocumentVerify == false && Constant.userModel?.isAutoVerify == false);
            // New bookings (the queue banner, 'Search new ride' and the
            // empty-state search, whose Accept takes a booking) are for a
            // verified driver who is online. Assigned bookings are listed and
            // workable whatever this says.
            final bool canTakeNewWork = verified && controller.userModel.value.isActive == true;
            return DsScaffold(
              body: controller.isLoading.value
                  ? const DsSkeletonList(itemCount: 3, leading: false, trailing: false)
                  // The verification gate and the offline notice are about
                  // receiving new bookings; bookings already assigned to this
                  // driver are listed either way (both used to replace the
                  // list and every action on it).
                  : controller.rentalBookingData.isEmpty && Constant.userModel?.isDocumentVerify == false && Constant.userModel?.isAutoVerify == false
                      ? _centered(
                          DsEmptyState(
                            tone: DsTone.warning,
                            illustration: SvgPicture.asset("assets/icons/ic_document.svg"),
                            title: "Document Verification in Pending".tr,
                            message: "Your documents are being reviewed. We will notify you once the verification is complete.".tr,
                            actionLabel: "View Status".tr,
                            actionIcon: Icons.arrow_forward_rounded,
                            onAction: () async {
                              RentalDashboardController dashBoardController = Get.put(RentalDashboardController());
                              dashBoardController.drawerIndex.value = 4;
                            },
                          ),
                        )
                      : controller.rentalBookingData.isEmpty && controller.userModel.value.isActive == false
                          ? _centered(
                              DsEmptyState(
                                tone: DsTone.neutral,
                                illustration: SvgPicture.asset("assets/images/empty_parcel.svg"),
                                title: 'You’re Currently Offline'.tr,
                                message: 'Switch to online mode to accept and deliver rental orders.'.tr,
                              ),
                            )
                          : controller.rentalBookingData.isEmpty
                              ? Column(
                                  children: [
                                    _walletAlert(context, controller),
                                    if (canTakeNewWork) const _NewRentalJobsBanner(),
                                    Expanded(
                                      child: _centered(
                                        DsEmptyState(
                                          tone: DsTone.brand,
                                          illustration: SvgPicture.asset("assets/images/empty_parcel.svg"),
                                          title: 'No rental requests available in your selected zone.'.tr,
                                          actionLabel: canTakeNewWork ? "Search Rental Booking".tr : null,
                                          actionIcon: Icons.search_rounded,
                                          onAction: canTakeNewWork
                                              ? () {
                                                  Get.to(RentalBookingSearchScreen());
                                                }
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                                  child: Column(
                                    children: [
                                      // Unverified or offline: the assigned
                                      // bookings only, no way to new ones.
                                      if (canTakeNewWork) ...[
                                        const _NewRentalJobsBanner(gutter: false),
                                        const DsGap(DsSpace.sm),
                                        DsTextField(
                                          hint: 'Search new ride'.tr,
                                          readOnly: true,
                                          prefixIcon: Icons.search_rounded,
                                          bottomSpacing: DsSpace.md,
                                          onTap: () {
                                            Get.to(RentalBookingSearchScreen());
                                          },
                                        ),
                                      ] else
                                        const DsGap(DsSpace.md),
                                      Expanded(
                                        child: RefreshIndicator(
                                          onRefresh: () async {
                                            await controller.getBookingData();
                                          },
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: controller.rentalBookingData.length,
                                            padding: EdgeInsets.zero,
                                            itemBuilder: (context, index) {
                                              RentalOrderModel rentalBookingData = controller.rentalBookingData[index];
                                              return DsFadeSlideIn(
                                                index: index,
                                                child: _bookingCard(context, controller, rentalBookingData),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
            );
          });
    });
  }

  Widget _centered(Widget child) => Center(
        child: DsResponsive(alignment: Alignment.center, padded: true, maxWidth: 480, child: SingleChildScrollView(child: child)),
      );

  /// Minimum-deposit warning (driver's own wallet, or the owner's).
  Widget _walletAlert(BuildContext context, RentalHomeController controller) {
    return Obx(() {
      final user = controller.userModel.value;
      final controllerOwner = controller.ownerModel.value;

      final num wallet = user.walletAmount ?? 0.0;
      final num ownerWallet = controllerOwner.walletAmount ?? 0.0;
      final String? ownerId = user.ownerId;

      final num minDeposit = double.parse(Constant.minimumDepositToRideAccept);
      // A company's driver works on the company's wallet, held to the owner
      // minimum — the threshold the owner's home screen and Accept use.
      final num ownerMinDeposit = double.tryParse(Constant.ownerMinimumDepositToRideAccept) ?? 0;

      // 🧠 Logic:
      // If individual driver → check driver's own wallet
      // If owner driver → check owner's wallet
      if ((ownerId == null || ownerId.isEmpty) && wallet < minDeposit) {
        // Individual driver case
        return Padding(
          padding: const EdgeInsets.all(DsSpace.lg),
          child: DsInlineAlert(
            tone: DsTone.danger,
            icon: Icons.account_balance_wallet_outlined,
            message: "${'You must have at least'.tr} ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} ${'in your wallet to receive orders'.tr}",
          ),
        );
      } else if (ownerId != null && ownerId.isNotEmpty && ownerWallet < ownerMinDeposit) {
        // Owner-driver case
        return Padding(
          padding: const EdgeInsets.all(DsSpace.lg),
          child: DsInlineAlert(
            tone: DsTone.danger,
            icon: Icons.account_balance_wallet_outlined,
            message: "Your owner doesn't have the minimum wallet amount to receive orders. Please contact your owner.".tr,
          ),
        );
      } else {
        return const SizedBox();
      }
    });
  }

  Widget _bookingCard(BuildContext context, RentalHomeController controller, RentalOrderModel rentalBookingData) {
    final c = context.dsColors;
    final t = context.dsText;
    final canContact = rentalBookingData.status == Constant.driverAccepted || rentalBookingData.status == Constant.orderShipped;
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      onTap: () {
        Get.to(() => RentalOrderDetailsScreen(), arguments: {"rentalOrder": rentalBookingData.id});
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Author profile image
              DsAvatar(
                imageUrl: rentalBookingData.author?.profilePictureURL,
                name: '${rentalBookingData.author?.firstName ?? ''} ${rentalBookingData.author?.lastName ?? ''}',
                size: 52,
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: Text(
                  '${rentalBookingData.author?.firstName ?? ''} ${rentalBookingData.author?.lastName ?? ''}'.tr,
                  style: t.titleSm,
                ),
              ),
              // Phone and Chat buttons if status matches
              if (canContact) ...[
                DsIconButton(
                  icon: Icons.call_outlined,
                  semanticLabel: "Call customer".tr,
                  variant: DsIconButtonVariant.brand,
                  onPressed: () {
                    if (rentalBookingData.author?.phoneNumber != null) {
                      Constant.makePhoneCall(rentalBookingData.author!.phoneNumber!);
                    }
                  },
                ),
                const DsGap(DsSpace.sm),
                DsIconButton(
                  icon: Icons.forum_outlined,
                  semanticLabel: "Chat with customer".tr,
                  variant: DsIconButtonVariant.tonal,
                  onPressed: () async {
                    ShowToastDialog.showLoader("Please wait".tr);

                    UserModel? customer = await FireStoreUtils.getUserProfile(rentalBookingData.authorID ?? '');
                    UserModel? driver = await FireStoreUtils.getUserProfile(rentalBookingData.driverId ?? '');

                    ShowToastDialog.closeLoader();

                    if (customer != null && driver != null) {
                      Get.to(const ChatScreen(), arguments: {
                        "senderName": driver.fullName(),
                        "receivedName": customer.fullName(),
                        "orderId": rentalBookingData.id,
                        "senderId": driver.id,
                        "receivedId": customer.id,
                        "receivedProfileUrl": customer.profilePictureURL ?? "",
                        "senderProfileUrl": driver.profilePictureURL ?? "",
                        "token": customer.fcmToken,
                        "chatType": Constant.userRoleDriver,
                      });
                    } else {
                      ShowToastDialog.showToast("User not found");
                    }
                  },
                ),
              ],
            ],
          ),
          const DsGap(DsSpace.lg),
          Container(
            padding: const EdgeInsets.all(DsSpace.md),
            decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
            child: Column(
              children: [
                DsRouteStops(
                  stops: [
                    DsRouteStop(kind: DsStopKind.pickup, label: "Pickup".tr, address: AddressFormat.orPlaceholder(rentalBookingData.sourceLocationName)),
                  ],
                ),
                const DsDivider(spacing: DsSpace.sm),
                DsInfoRow(
                  label: "Package Details:".tr,
                  value: (rentalBookingData.rentalPackageModel?.name ?? '-').tr,
                  valueTone: DsTone.brand,
                ),
                DsInfoRow(
                  label: "Including Distance:".tr,
                  value: "${rentalBookingData.rentalPackageModel?.includedDistance ?? '-'} ${Constant.distanceType}".tr,
                  valueTone: DsTone.brand,
                ),
                DsInfoRow(
                  label: "Including Duration:".tr,
                  value: "${rentalBookingData.rentalPackageModel?.includedHours ?? '-'} Hr".tr,
                  valueTone: DsTone.brand,
                ),
              ],
            ),
          ),
          const DsGap(DsSpace.md),
          DsTripMetrics(
            items: [
              DsTripMetric(
                icon: Icons.payments_outlined,
                value: Constant.amountShow(currency: RegionService.currencyForRecord(rentalBookingData.regionId), amount: rentalBookingData.subTotal).tr,
                label: "Amount".tr,
              ),
              DsTripMetric(
                icon: Icons.event_outlined,
                value: rentalBookingData.bookingDateTime == null ? '-' : Constant.timestampToDateTime(rentalBookingData.bookingDateTime!).tr,
                label: "Booking".tr,
              ),
            ],
          ),
          const DsGap(DsSpace.lg),
          _bookingAction(context, controller, rentalBookingData),
        ],
      ),
    );
  }

  /// The single next step for this booking – unchanged conditions and handlers.
  Widget _bookingAction(BuildContext context, RentalHomeController controller, RentalOrderModel rentalBookingData) {
    // 'Order Shipped' is a booking not started yet, like 'Driver Accepted':
    // it fell through to "Complete Booking" / the payment button.
    if (rentalBookingData.status == Constant.driverAccepted || rentalBookingData.status == Constant.orderShipped) {
      return DsButton.primary(
        label: "Reached Location".tr,
        icon: Icons.location_on_outlined,
        size: DsButtonSize.lg,
        expand: true,
        onPressed: () async {
          if (rentalBookingData.bookingDateTime != null && rentalBookingData.bookingDateTime!.toDate().isAfter(DateTime.now())) {
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return CustomDialogBox(
                    title: "Alert".tr,
                    descriptions: "${'The customer is not renting the car at the moment and has scheduled the car rental for'.tr} ${Constant.formatTimestamp(rentalBookingData.bookingDateTime!)}.".tr,
                    positiveString: "Okay".tr,
                    positiveClick: () async {
                      Get.back();
                    },
                  );
                });
          } else {
            showVerifyRentalPassengerDialog(context, controller, rentalBookingData);
          }
        },
      );
    }
    if (rentalBookingData.status == Constant.orderInTransit &&
        (double.tryParse('${rentalBookingData.endKitoMetersReading ?? ''}') ?? 0) < (double.tryParse('${rentalBookingData.startKitoMetersReading ?? ''}') ?? 0)) {
      return DsButton.primary(
        label: "Set Final kilometers".tr,
        icon: Icons.speed_rounded,
        size: DsButtonSize.lg,
        expand: true,
        onPressed: () async {
          setFinalKilometerDialog(context, controller, rentalBookingData);
        },
      );
    }
    if (rentalBookingData.paymentStatus == true) {
      return DsButton.success(
        label: "Complete Booking".tr,
        icon: Icons.check_rounded,
        size: DsButtonSize.lg,
        expand: true,
        onPressed: () async {
          controller.completeParcel(rentalBookingData);
        },
      );
    }
    final isCod = rentalBookingData.paymentMethod == PaymentGateway.cod.name;
    final label = isCod ? "Confirm cash payment".tr : "Payment Pending".tr;
    void onPressed() async {
      if (rentalBookingData.paymentMethod == PaymentGateway.cod.name) {
        conformCashPayment(context, controller, rentalBookingData);
      } else {
        ShowToastDialog.showToast("Please collect the payment from the customer through the app.");
      }
    }

    return isCod
        ? DsButton.success(label: label, icon: Icons.payments_outlined, size: DsButtonSize.lg, expand: true, onPressed: onPressed)
        : DsButton.danger(label: label, icon: Icons.hourglass_bottom_rounded, size: DsButtonSize.lg, expand: true, onPressed: onPressed);
  }

  void showVerifyRentalPassengerDialog(
    BuildContext context,
    RentalHomeController controller,
    RentalOrderModel rentalBookingData,
  ) {
    Rx<PinInputController> otpController = PinInputController().obs;
    final c = DsColors.of(context);

    Get.dialog(
      DsDialog(
        title: Constant.enableOTPTripStartForRental == false ? "Trip Start" : "Verify Passenger".tr,
        message: Constant.enableOTPTripStartForRental == false ? null : "Enter the OTP shared by the customer to begin the trip".tr,
        icon: Icons.play_circle_outline_rounded,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsTextField(
              controller: controller.currentKilometerController.value,
              hint: 'Enter Current Kilometer reading'.tr,
              label: 'Current Kilometer reading'.tr,
              prefixIcon: Icons.speed_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              bottomSpacing: Constant.enableOTPTripStartForRental == false ? 0 : DsSpace.md,
            ),
            Constant.enableOTPTripStartForRental == false
                ? const SizedBox()
                : MaterialPinField(
                    length: 4,
                    pinController: otpController.value,
                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                    ],
                    enableAutofill: true,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    hintCharacter: "-",
                    theme: MaterialPinTheme(
                      cellSize: const Size(50, 50),
                      shape: MaterialPinShape.outlined,
                      borderRadius: DsRadius.brMd,
                      textStyle: DsTypography.title.copyWith(color: c.textPrimary),
                      hintStyle: DsTypography.title.copyWith(color: c.textMuted),
                      fillColor: c.surfaceAlt,
                      borderColor: c.border,
                      focusedBorderColor: c.brand,
                      cursorColor: c.brand,
                    ),
                    onChanged: (value) {},
                    onCompleted: (pin) async {
                      // OTP completed
                    },
                  ),
          ],
        ),
        secondaryLabel: "Cancel".tr,
        onSecondary: () => Get.back(),
        primaryLabel: "Start Ride".tr,
        onPrimary: () async {
          if (controller.currentKilometerController.value.text.isEmpty || double.parse(controller.currentKilometerController.value.text) < 10) {
            ShowToastDialog.showToast("Please enter current kilometer reading".tr);
            return;
          }
          if (Constant.enableOTPTripStartForRental == true && otpController.value.text.isEmpty && otpController.value.text.length < 6) {
            ShowToastDialog.showToast("Please enter valid OTP".tr);
            return;
          }
          if (Constant.enableOTPTripStartForRental == true && rentalBookingData.otpCode != otpController.value.text.trim()) {
            ShowToastDialog.showToast("Invalid OTP".tr);
            return;
          }

          rentalBookingData.startKitoMetersReading = controller.currentKilometerController.value.text.trim();
          rentalBookingData.startTime = Timestamp.now();
          rentalBookingData.status = Constant.orderInTransit;

          ShowToastDialog.showLoader("Updating...".tr);
          // A failed write used to leave the full-screen loader up for good.
          try {
            await FireStoreUtils.rentalOrderPlace(rentalBookingData);
          } catch (e) {
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
            return;
          }
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast("Ride started successfully".tr);
          controller.currentKilometerController.value.clear();
          otpController.value.clear();
          Get.back();
        },
      ),
      barrierDismissible: true,
    );
  }

  void setFinalKilometerDialog(BuildContext context, RentalHomeController controller, RentalOrderModel rentalBookingData) {
    Get.dialog(
      DsDialog(
        title: "Enter Kilometer Reading",
        icon: Icons.speed_rounded,
        content: DsTextField(
          controller: controller.completeKilometerController.value,
          hint: 'Enter Current Kilometer reading',
          label: ' Current Kilometer reading',
          prefixIcon: Icons.speed_rounded,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
          bottomSpacing: 0,
        ),
        secondaryLabel: "Cancel".tr,
        onSecondary: () {
          Get.back();
        },
        primaryLabel: "Save".tr,
        onPrimary: () async {
          if (controller.completeKilometerController.value.text.isEmpty) {
            ShowToastDialog.showToast("Please enter current kilometer reading".tr);
            return;
          } else if ((double.tryParse(controller.completeKilometerController.value.text.toString().trim()) ?? 0) <
              (double.tryParse('${rentalBookingData.startKitoMetersReading ?? ''}') ?? 0)) {
            ShowToastDialog.showToast("Final kilometer reading cannot be less than starting kilometer reading".tr);
            return;
          } else {
            rentalBookingData.endKitoMetersReading = controller.completeKilometerController.value.text.toString().trim();
            rentalBookingData.endTime = Timestamp.now();
            ShowToastDialog.showLoader("Updating...".tr);
            try {
              await FireStoreUtils.rentalOrderPlace(rentalBookingData);
            } catch (e) {
              ShowToastDialog.closeLoader();
              ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
              return;
            }
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Kilometer updated successfully".tr);
            controller.completeKilometerController.value.clear();
            Get.back();
          }
        },
      ),
      barrierDismissible: true,
    );
  }

  void conformCashPayment(BuildContext context, RentalHomeController controller, RentalOrderModel rentalBookingData) {
    Get.dialog(
      DsDialog(
        title: "Confirm Cash Collection",
        message: "Please confirm that you have received the full cash amount from the customer before continuing.",
        icon: Icons.payments_outlined,
        tone: DsTone.success,
        secondaryLabel: "Cancel".tr,
        onSecondary: () {
          Get.back();
        },
        primaryLabel: "Ride Completed".tr,
        onPrimary: () async {
          ShowToastDialog.showLoader("Updating...".tr);
          final String? previousStatus = rentalBookingData.status;
          final bool? previousPaid = rentalBookingData.paymentStatus;
          rentalBookingData.status = Constant.orderCompleted;
          rentalBookingData.paymentStatus = true;
          // A throw anywhere here (an `author!`, a failed write) used to leave
          // the full-screen loader up and the whole app unresponsive.
          try {
            await controller.updateCabWalletAmount(rentalBookingData);
            await FireStoreUtils.rentalOrderPlace(rentalBookingData);
          } catch (e) {
            rentalBookingData.status = previousStatus;
            rentalBookingData.paymentStatus = previousPaid;
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
            return;
          }
          Map<String, dynamic> payLoad = <String, dynamic>{"type": "rental_order", "orderId": rentalBookingData.id};
          SendNotification.notifyCustomer(Constant.rentalCompleted,
              customerId: rentalBookingData.authorID ?? rentalBookingData.author?.id,
              embeddedToken: rentalBookingData.author?.fcmToken,
              payload: payLoad,
              status: rentalBookingData.status);
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast("Ride completed successfully".tr);
          Get.back();
        },
      ),
      barrierDismissible: true,
    );
  }
}

/// Badge for the automatic driver-notification queue (admin spec §14): the
/// rental bookings placed while the driver was offline, found the moment they
/// came back online. Hidden — and costing nothing — when there are none.
class _NewRentalJobsBanner extends StatelessWidget {
  /// False where the surrounding layout already applies the horizontal gutter.
  final bool gutter;

  const _NewRentalJobsBanner({this.gutter = true});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int waiting = DriverJobQueueService.rentalJobCount.value;
      if (waiting <= 0) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.fromLTRB(gutter ? DsSpace.lg : 0, DsSpace.lg, gutter ? DsSpace.lg : 0, 0),
        child: DsInlineAlert(
          tone: DsTone.brand,
          icon: Icons.notifications_active_outlined,
          title: "New rental requests".tr,
          message: waiting == 1
              ? "1 rental request is waiting for you.".tr
              : "$waiting ${'rental requests are waiting for you.'.tr}",
          actionLabel: "View requests".tr,
          onAction: () => Get.to(RentalBookingSearchScreen()),
        ),
      );
    });
  }
}

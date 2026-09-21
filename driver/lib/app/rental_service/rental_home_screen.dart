import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/app/rental_service/rental_booking_search_screen.dart';
import 'package:driver/app/rental_service/rental_order_details_screen.dart';
import 'package:driver/app/wallet_screen/payment_list_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/rental_dashboard_controller.dart';
import 'package:driver/controllers/rental_home_controller.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/custom_dialog_box.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/round_button_fill.dart';
import 'package:driver/themes/text_field_widget.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/network_image_widget.dart';
import 'package:driver/widget/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:timelines_plus/timelines_plus.dart';

import '../../models/user_model.dart';
import '../chat_screens/chat_screen.dart';

class RentalHomeScreen extends StatelessWidget {
  const RentalHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetX(
          init: RentalHomeController(),
          builder: (controller) {
            return Scaffold(
              backgroundColor: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
              body: controller.isLoading.value
                  ? Constant.loader()
                  : Constant.userModel?.isDocumentVerify == false && Constant.userModel?.isAutoVerify == false
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                decoration: ShapeDecoration(
                                  color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(120),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: SvgPicture.asset("assets/icons/ic_document.svg"),
                                ),
                              ),
                              const SizedBox(
                                height: 12,
                              ),
                              Text(
                                "Document Verification in Pending".tr,
                                style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 22, fontFamily: AppThemeData.semiBold),
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              Text(
                                "Your documents are being reviewed. We will notify you once the verification is complete.".tr,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.bold),
                              ),
                              const SizedBox(
                                height: 20,
                              ),
                              RoundedButtonFill(
                                title: "View Status".tr,
                                width: 55,
                                height: 5.5,
                                color: AppThemeData.primary300,
                                textColor: AppThemeData.grey50,
                                onPress: () async {
                                  RentalDashboardController dashBoardController = Get.put(RentalDashboardController());
                                  dashBoardController.drawerIndex.value = 4;
                                },
                              ),
                            ],
                          ),
                        )
                      : controller.userModel.value.isActive == false
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset("assets/images/empty_parcel.svg"),
                                  SizedBox(
                                    height: 20,
                                  ),
                                  Text(
                                    'You’re Currently Offline'.tr,
                                    textAlign: TextAlign.center,
                                    style: AppThemeData.mediumTextStyle(
                                      fontSize: 18,
                                      color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                    ),
                                  ),
                                  SizedBox(
                                    height: 10,
                                  ),
                                  Text(
                                    'Switch to online mode to accept and deliver rental orders.'.tr,
                                    textAlign: TextAlign.center,
                                    style: AppThemeData.mediumTextStyle(
                                      fontSize: 14,
                                      color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : controller.rentalBookingData.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(
                                    children: [
                                      Obx(() {
                                        final user = controller.userModel.value;
                                        final controllerOwner = controller.ownerModel.value;

                                        final num wallet = user.walletAmount ?? 0.0;
                                        final num ownerWallet = controllerOwner.walletAmount ?? 0.0;
                                        final String? ownerId = user.ownerId;

                                        final num minDeposit = double.parse(Constant.minimumDepositToRideAccept);

                                        // 🧠 Logic:
                                        // If individual driver → check driver's own wallet
                                        // If owner driver → check owner's wallet
                                        if ((ownerId == null || ownerId.isEmpty) && wallet < minDeposit) {
                                          // Individual driver case
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: AppThemeData.danger50,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text(
                                                  "${'You must have at least'.tr} ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} ${'in your wallet to receive orders'.tr}",
                                                  style: TextStyle(
                                                    color: AppThemeData.grey900,
                                                    fontSize: 14,
                                                    fontFamily: AppThemeData.semiBold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        } else if (ownerId != null && ownerId.isNotEmpty && ownerWallet < minDeposit) {
                                          // Owner-driver case
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: AppThemeData.danger50,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text(
                                                  "Your owner doesn't have the minimum wallet amount to receive orders. Please contact your owner.".tr,
                                                  style: TextStyle(
                                                    color: AppThemeData.grey900,
                                                    fontSize: 14,
                                                    fontFamily: AppThemeData.semiBold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        } else {
                                          return const SizedBox();
                                        }
                                      }),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SvgPicture.asset("assets/images/empty_parcel.svg"),
                                            SizedBox(
                                              height: 20,
                                            ),
                                            Text(
                                              'No rental requests available in your selected zone.'.tr,
                                              textAlign: TextAlign.center,
                                              style: AppThemeData.mediumTextStyle(
                                                fontSize: 18,
                                                color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                              ),
                                            ),
                                            SizedBox(
                                              height: 20,
                                            ),
                                            RoundedButtonFill(
                                              title: "Search Rental Booking".tr,
                                              height: 5.5,
                                              color: AppThemeData.primary300,
                                              textColor: AppThemeData.grey50,
                                              onPress: () {
                                                Get.to(RentalBookingSearchScreen());
                                              },
                                            )
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          Get.to(RentalBookingSearchScreen());
                                        },
                                        child: TextFieldWidget(
                                          hintText: 'Search new ride'.tr,
                                          enable: false,
                                          controller: null,
                                        ),
                                      ),
                                      Expanded(
                                        child: RefreshIndicator(
                                          onRefresh: () async {
                                            await controller.getBookingData();
                                          },
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: controller.rentalBookingData.length,
                                            padding: EdgeInsetsGeometry.zero,
                                            itemBuilder: (context, index) {
                                              RentalOrderModel rentalBookingData = controller.rentalBookingData[index];
                                              return InkWell(
                                                onTap: () {
                                                  Get.to(() => RentalOrderDetailsScreen(), arguments: {"rentalOrder": rentalBookingData.id});
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.only(bottom: 10),
                                                  child: Container(
                                                    padding: EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(15),
                                                      color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                                      border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            // Author profile image
                                                            ClipOval(
                                                              child: rentalBookingData.author?.profilePictureURL != null
                                                                  ? NetworkImageWidget(
                                                                      imageUrl: rentalBookingData.author!.profilePictureURL!,
                                                                      width: 52,
                                                                      height: 52,
                                                                      fit: BoxFit.cover,
                                                                    )
                                                                  : Container(
                                                                      width: 52,
                                                                      height: 52,
                                                                      color: isDark ? AppThemeData.grey700 : AppThemeData.grey300,
                                                                      child: Icon(Icons.person, color: Colors.white),
                                                                    ),
                                                            ),
                                                            SizedBox(width: 10),
                                                            Expanded(
                                                              child: Text(
                                                                '${rentalBookingData.author?.firstName ?? ''} ${rentalBookingData.author?.lastName ?? ''}'.tr,
                                                                textAlign: TextAlign.start,
                                                                style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                              ),
                                                            ),
                                                            // Phone and Chat buttons if status matches
                                                            if (rentalBookingData.status == Constant.driverAccepted || rentalBookingData.status == Constant.orderShipped)
                                                              Row(
                                                                children: [
                                                                  InkWell(
                                                                    onTap: () {
                                                                      if (rentalBookingData.author?.phoneNumber != null) {
                                                                        Constant.makePhoneCall(rentalBookingData.author!.phoneNumber!);
                                                                      }
                                                                    },
                                                                    child: SvgPicture.asset(
                                                                      "assets/icons/ic_phone_dial.svg",
                                                                      width: 36,
                                                                    ),
                                                                  ),
                                                                  SizedBox(width: 10),
                                                                  InkWell(
                                                                    onTap: () async {
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
                                                                    child: Container(
                                                                      width: 50,
                                                                      height: 42,
                                                                      decoration: ShapeDecoration(
                                                                        shape: RoundedRectangleBorder(
                                                                          side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                                                          borderRadius: BorderRadius.circular(120),
                                                                        ),
                                                                      ),
                                                                      child: Padding(
                                                                        padding: const EdgeInsets.all(8.0),
                                                                        child: SvgPicture.asset("assets/icons/ic_wechat.svg"),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 16),
                                                        Container(
                                                          decoration: BoxDecoration(
                                                            color: isDark ? AppThemeData.greyDark100 : AppThemeData.grey100,
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                          child: Padding(
                                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                            child: Column(
                                                              children: [
                                                                Timeline.tileBuilder(
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
                                                                      return SvgPicture.asset("assets/icons/ic_location.svg");
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
                                                                          "${rentalBookingData.sourceLocationName}",
                                                                          style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                                        ),
                                                                      );
                                                                    },
                                                                    itemCount: 1,
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  height: 5,
                                                                ),
                                                                DottedLine(
                                                                  dashColor: Colors.grey,
                                                                  lineThickness: 1.0,
                                                                  dashLength: 4.0,
                                                                  dashGapLength: 3.0,
                                                                  direction: Axis.horizontal,
                                                                ),
                                                                SizedBox(
                                                                  height: 10,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child: Text(
                                                                        "Package Details:".tr,
                                                                        textAlign: TextAlign.start,
                                                                        style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      "${rentalBookingData.rentalPackageModel!.name}".tr,
                                                                      textAlign: TextAlign.start,
                                                                      style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                                                    ),
                                                                  ],
                                                                ),
                                                                SizedBox(
                                                                  height: 5,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child: Text(
                                                                        "Including Distance:".tr,
                                                                        textAlign: TextAlign.start,
                                                                        style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      "${rentalBookingData.rentalPackageModel!.includedDistance} ${Constant.distanceType}".tr,
                                                                      textAlign: TextAlign.start,
                                                                      style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                                                    ),
                                                                  ],
                                                                ),
                                                                SizedBox(
                                                                  height: 5,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child: Text(
                                                                        "Including Duration:".tr,
                                                                        textAlign: TextAlign.start,
                                                                        style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      "${rentalBookingData.rentalPackageModel!.includedHours} Hr".tr,
                                                                      textAlign: TextAlign.start,
                                                                      style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                                                    ),
                                                                  ],
                                                                )
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          height: 12,
                                                        ),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Column(
                                                                children: [
                                                                  SvgPicture.asset("assets/icons/ic_amount.svg"),
                                                                  SizedBox(
                                                                    height: 5,
                                                                  ),
                                                                  Text(
                                                                    Constant.amountShow(amount: rentalBookingData.subTotal).tr,
                                                                    textAlign: TextAlign.start,
                                                                    style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                                  )
                                                                ],
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Column(
                                                                children: [
                                                                  SvgPicture.asset("assets/icons/ic_date.svg"),
                                                                  SizedBox(
                                                                    height: 5,
                                                                  ),
                                                                  Text(
                                                                    Constant.timestampToDateTime(rentalBookingData.bookingDateTime!).tr,
                                                                    textAlign: TextAlign.start,
                                                                    style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                                  )
                                                                ],
                                                              ),
                                                            )
                                                          ],
                                                        ),
                                                        const SizedBox(height: 16),
                                                        rentalBookingData.status == Constant.driverAccepted
                                                            ? RoundedButtonFill(
                                                                title: "Reached Location".tr,
                                                                height: 5.5,
                                                                color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                                                textColor: isDark ? AppThemeData.grey50 : AppThemeData.grey50,
                                                                onPress: () async {
                                                                  if (rentalBookingData.bookingDateTime!.toDate().isAfter(DateTime.now())) {
                                                                    showDialog(
                                                                        context: context,
                                                                        builder: (BuildContext context) {
                                                                          return CustomDialogBox(
                                                                            title: "Alert".tr,
                                                                            descriptions:
                                                                                "${'The customer is not renting the car at the moment and has scheduled the car rental for'.tr} ${Constant.formatTimestamp(rentalBookingData.bookingDateTime!)}."
                                                                                    .tr,
                                                                            positiveString: "Okay".tr,
                                                                            positiveClick: () async {
                                                                              Get.back();
                                                                            },
                                                                          );
                                                                        });
                                                                  } else {
                                                                    showVerifyRentalPassengerDialog(context, isDark, controller, rentalBookingData);
                                                                  }
                                                                },
                                                              )
                                                            : rentalBookingData.status == Constant.orderInTransit &&
                                                                    double.parse(rentalBookingData.endKitoMetersReading.toString()) < double.parse(rentalBookingData.startKitoMetersReading.toString())
                                                                ? RoundedButtonFill(
                                                                    title: "Set Final kilometers".tr,
                                                                    height: 5.5,
                                                                    color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                                                    textColor: isDark ? AppThemeData.grey50 : AppThemeData.grey50,
                                                                    onPress: () async {
                                                                      setFinalKilometerDialog(context, isDark, controller, rentalBookingData);
                                                                    },
                                                                  )
                                                                : rentalBookingData.paymentStatus == true
                                                                    ? RoundedButtonFill(
                                                                        title: "Complete Booking".tr,
                                                                        height: 5.5,
                                                                        color: isDark ? AppThemeData.success500 : AppThemeData.success500,
                                                                        textColor: isDark ? AppThemeData.grey50 : AppThemeData.grey50,
                                                                        onPress: () async {
                                                                          controller.completeParcel(rentalBookingData);
                                                                        },
                                                                      )
                                                                    : RoundedButtonFill(
                                                                        title: rentalBookingData.paymentMethod == PaymentGateway.cod.name ? "Confirm cash payment".tr : "Payment Pending".tr,
                                                                        height: 5.5,
                                                                        color: rentalBookingData.paymentMethod == PaymentGateway.cod.name
                                                                            ? AppThemeData.success500
                                                                            : isDark
                                                                                ? AppThemeData.dangerDark300
                                                                                : AppThemeData.dangerDark300,
                                                                        textColor: isDark ? AppThemeData.grey50 : AppThemeData.grey50,
                                                                        onPress: () async {
                                                                          if (rentalBookingData.paymentMethod == PaymentGateway.cod.name) {
                                                                            conformCashPayment(context, isDark, controller, rentalBookingData);
                                                                          } else {
                                                                            ShowToastDialog.showToast("Please collect the payment from the customer through the app.");
                                                                          }
                                                                        },
                                                                      )
                                                      ],
                                                    ),
                                                  ),
                                                ),
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

  void showVerifyRentalPassengerDialog(
    BuildContext context,
    bool isDark,
    RentalHomeController controller,
    RentalOrderModel rentalBookingData,
  ) {
    Rx<PinInputController> otpController = PinInputController().obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark
            ? AppThemeData.greyDark50 // 👈 dark background
            : AppThemeData.grey50, // 👈 light background
        child: SizedBox(
          width: Responsive.width(90, context),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        Constant.enableOTPTripStartForRental == false ? "Trip Start" : "Verify Passenger".tr,
                        style: AppThemeData.boldTextStyle(
                          fontSize: 22,
                          color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Get.back(),
                      child: Icon(
                        Icons.close,
                        color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Constant.enableOTPTripStartForRental == false
                    ? const SizedBox()
                    : Text(
                        "Enter the OTP shared by the customer to begin the trip".tr,
                        textAlign: TextAlign.start,
                        style: AppThemeData.mediumTextStyle(
                          color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey600,
                          fontSize: 14,
                        ),
                      ),
                SizedBox(height: 20),
                TextFieldWidget(
                  controller: controller.currentKilometerController.value,
                  hintText: 'Enter Current Kilometer reading'.tr,
                  title: 'Current Kilometer reading'.tr,
                  enable: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                SizedBox(height: 10),
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
                          borderRadius: BorderRadius.circular(10),
                          textStyle: TextStyle(
                            color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                          ),
                          hintStyle: TextStyle(
                            color: isDark ? AppThemeData.greyDark300 : AppThemeData.grey700,
                          ),
                          fillColor: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                          borderColor: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                          focusedBorderColor: AppThemeData.primary300,
                          cursorColor: AppThemeData.primary300,
                        ),
                        onChanged: (value) {},
                        onCompleted: (pin) async {
                          // OTP completed
                        },
                      ),
                SizedBox(height: 10),
                RoundedButtonFill(
                  title: "Start Ride".tr,
                  height: 5.5,
                  color: AppThemeData.primary300,
                  textColor: AppThemeData.grey50,
                  onPress: () async {
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
                    await FireStoreUtils.rentalOrderPlace(rentalBookingData).then((value) {
                      ShowToastDialog.closeLoader();
                      ShowToastDialog.showToast("Ride started successfully".tr);
                      controller.currentKilometerController.value.clear();
                      otpController.value.clear();
                      Get.back();
                    });
                  },
                )
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  void setFinalKilometerDialog(BuildContext context, bool isDark, RentalHomeController controller, RentalOrderModel rentalBookingData) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark
            ? AppThemeData.greyDark50 // 👈 dark background
            : AppThemeData.grey50, // 👈 light background
        child: SizedBox(
          width: Responsive.width(80, context),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text("Enter Kilometer Reading", style: AppThemeData.boldTextStyle(fontSize: 22, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900))),
                    InkWell(
                      onTap: () {
                        Get.back();
                      },
                      child: Icon(Icons.close),
                    )
                  ],
                ),
                SizedBox(height: 8),
                TextFieldWidget(
                  controller: controller.completeKilometerController.value,
                  hintText: 'Enter Current Kilometer reading',
                  title: ' Current Kilometer reading',
                  inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                ),
                SizedBox(height: 20),
                RoundedButtonFill(
                  title: "Save".tr,
                  height: 5.5,
                  color: AppThemeData.primary300,
                  textColor: AppThemeData.grey50,
                  onPress: () async {
                    if (controller.completeKilometerController.value.text.isEmpty) {
                      ShowToastDialog.showToast("Please enter current kilometer reading".tr);
                      return;
                    } else if (double.parse(controller.completeKilometerController.value.text.toString().trim()) < double.parse(rentalBookingData.startKitoMetersReading.toString())) {
                      ShowToastDialog.showToast("Final kilometer reading cannot be less than starting kilometer reading".tr);
                      return;
                    } else {
                      rentalBookingData.endKitoMetersReading = controller.completeKilometerController.value.text.toString().trim();
                      rentalBookingData.endTime = Timestamp.now();
                      ShowToastDialog.showLoader("Updating...".tr);
                      await FireStoreUtils.rentalOrderPlace(rentalBookingData).then((value) {
                        ShowToastDialog.closeLoader();
                        ShowToastDialog.showToast("Kilometer updated successfully".tr);
                        controller.completeKilometerController.value.clear();
                        Get.back();
                      });
                    }
                  },
                )
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  void conformCashPayment(BuildContext context, bool isDark, RentalHomeController controller, RentalOrderModel rentalBookingData) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark
            ? AppThemeData.greyDark50 // 👈 dark background
            : AppThemeData.grey50, // 👈 light background
        child: SizedBox(
          width: Responsive.width(80, context),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text("Confirm Cash Collection", style: AppThemeData.boldTextStyle(fontSize: 20, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900))),
                    InkWell(
                      onTap: () {
                        Get.back();
                      },
                      child: Icon(
                        Icons.close,
                        color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                      ),
                    )
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  "Please confirm that you have received the full cash amount from the customer before continuing.",
                  textAlign: TextAlign.start,
                  style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500, fontSize: 14),
                ),
                SizedBox(height: 25),
                RoundedButtonFill(
                  title: "Ride Completed".tr,
                  height: 5.5,
                  color: AppThemeData.primary300,
                  textColor: AppThemeData.grey50,
                  onPress: () async {
                    ShowToastDialog.showLoader("Updating...".tr);
                    rentalBookingData.status = Constant.orderCompleted;
                    rentalBookingData.paymentStatus = true;
                    await controller.updateCabWalletAmount(rentalBookingData);
                    await FireStoreUtils.rentalOrderPlace(rentalBookingData).then((value) {
                      Map<String, dynamic> payLoad = <String, dynamic>{"type": "rental_order", "orderId": rentalBookingData.id};
                      SendNotification.sendFcmMessage(Constant.rentalCompleted, rentalBookingData.author!.fcmToken.toString(), payLoad);
                      ShowToastDialog.closeLoader();
                      ShowToastDialog.showToast("Ride completed successfully".tr);
                      Get.back();
                    });
                  },
                )
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }
}

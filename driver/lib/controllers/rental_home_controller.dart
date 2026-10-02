import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/app/wallet_screen/payment_list_screen.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/wallet_transaction_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant/show_toast_dialog.dart' show ShowToastDialog;

class RentalHomeController extends GetxController {
  RxList<RentalOrderModel> rentalBookingData = <RentalOrderModel>[].obs;

  RxBool isLoading = true.obs;

  Rx<TextEditingController> currentKilometerController = TextEditingController().obs;
  Rx<TextEditingController> completeKilometerController = TextEditingController().obs;
  Rx<UserModel> userModel = UserModel().obs;
  Rx<UserModel> ownerModel = UserModel().obs;


  // One subscription each. Pull-to-refresh calls [getBookingData] again, and
  // every call used to add another set of listeners on top of the last.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _bookingSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _ownerSub;

  @override
  void onInit() {
    getBookingData();
    // TODO: implement onInit
    super.onInit();
  }

  @override
  void onClose() {
    _cancelSubscriptions();
    super.onClose();
  }

  void _cancelSubscriptions() {
    _bookingSub?.cancel();
    _userSub?.cancel();
    _ownerSub?.cancel();
    _bookingSub = null;
    _userSub = null;
    _ownerSub = null;
  }

  Future<void> getBookingData() async {
    _cancelSubscriptions();
    isLoading.value = true;
    rentalBookingData.clear();

    // Driver’s active rental bookings
    _bookingSub = FireStoreUtils.fireStore
        .collection(CollectionName.rentalOrders)
        .where("driverId", isEqualTo: FireStoreUtils.getCurrentUid())
        .where("status", whereIn: [
          Constant.driverAccepted,
          Constant.orderInTransit,
          Constant.orderShipped,
        ])
        .snapshots()
        .listen((event) {
          rentalBookingData.clear();

          for (var element in event.docs) {
            // One unreadable booking must not take the list (and the loader)
            // down with it: a throw here left the skeleton up for good.
            try {
              rentalBookingData.add(RentalOrderModel.fromJson(element.data()));
            } catch (e) {
              log("RentalHomeController: ${element.id} could not be read: $e");
            }
          }

          // ✅ Turn off loader *after first snapshot*
          isLoading.value = false;
          update();
        }, onError: (Object e) {
          log("RentalHomeController.getBookingData failed: $e");
          isLoading.value = false;
          update();
        });

    // Driver user data listener
    _userSub = FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).snapshots().listen((event) {
      if (event.exists) {
        userModel.value = UserModel.fromJson(event.data()!);
      }
    });

    // An independent driver has no owner, and `Constant.userModel` itself
    // can still be null on a cold start — the `!` threw here and took the
    // whole subscribe step (including the driver listener below it in the
    // other modules) down with it.
    final String ownerId = Constant.userModel?.ownerId ?? '';
    if (ownerId.isNotEmpty) {
      _ownerSub = FireStoreUtils.fireStore.collection(CollectionName.users).doc(ownerId).snapshots().listen(
            (event) async {
          if (event.exists) {
            ownerModel.value = UserModel.fromJson(event.data()!);
          }
        },
      );
    }
  }

  Future<void> completeParcel(RentalOrderModel parcelBookingData) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final String? previousStatus = parcelBookingData.status;
    parcelBookingData.status = Constant.orderCompleted;

    // A throw here used to leave the full-screen loader up for good.
    try {
      await updateCabWalletAmount(parcelBookingData);
      await FireStoreUtils.rentalOrderPlace(parcelBookingData);
    } catch (e) {
      log("RentalHomeController.completeParcel failed: $e");
      parcelBookingData.status = previousStatus;
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
      return;
    }
    Map<String, dynamic> payLoad = <String, dynamic>{"type": "rental_order", "orderId": parcelBookingData.id};
    SendNotification.sendFcmMessage(Constant.rentalCompleted, parcelBookingData.author?.fcmToken ?? '', payLoad);
    FireStoreUtils.getRentalFirstOrderOrNOt(parcelBookingData).then((value) async {
      if (value == true) {
        await FireStoreUtils.updateRentalReferralAmount(parcelBookingData);
      }
    });
    ShowToastDialog.showToast("Ride completed successfully".tr);
    ShowToastDialog.closeLoader();
  }

  RxDouble subTotal = 0.0.obs;
  RxDouble discount = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;
  RxDouble extraKilometerCharge = 0.0.obs;
  RxDouble extraMinutesCharge = 0.0.obs;
  RxDouble adminComm = 0.0.obs;

  Future<void> updateCabWalletAmount(RentalOrderModel orderModel) async {
    // Who the money moves on: the company when this driver belongs to one, the
    // driver themselves otherwise. `orderModel.driver!` threw for every booking
    // whose embedded driver map is absent — which is exactly the independent
    // driver's case (client point 10), and it threw BETWEEN the two wallet
    // writes below, leaving the booking credited but the commission never
    // taken.
    final String ownerId = orderModel.driver?.ownerId ?? '';
    final String walletUserId = ownerId.isNotEmpty ? ownerId : FireStoreUtils.getCurrentUid();

    subTotal.value = 0.0;
    discount.value = 0.0;
    taxAmount.value = 0.0;
    totalAmount.value = 0.0;
    extraKilometerCharge.value = 0.0;
    extraMinutesCharge.value = 0.0;
    adminComm.value = 0.0;
    subTotal.value = double.tryParse(orderModel.subTotal?.toString() ?? "0") ?? 0.0;
    discount.value = double.tryParse(orderModel.discount?.toString() ?? "0") ?? 0.0;

    // Null-safe: a booking set straight to "In Transit" by hand has no
    // `startTime`, and one without a package has no included hours / km.
    final int? includedHours = int.tryParse('${orderModel.rentalPackageModel?.includedHours ?? ''}');
    if (orderModel.endTime != null && orderModel.startTime != null && includedHours != null) {
      DateTime start = orderModel.startTime!.toDate();
      DateTime end = orderModel.endTime!.toDate();
      int hours = end.difference(start).inHours;
      if (hours >= includedHours) {
        hours = hours - includedHours;
        double hourlyRate = double.tryParse(orderModel.rentalPackageModel?.extraMinuteFare?.toString() ?? "0") ?? 0.0;
        extraMinutesCharge.value = (hours * 60) * hourlyRate;
      }
    }

    if (orderModel.startKitoMetersReading != null && orderModel.endKitoMetersReading != null) {
      double startKm = double.tryParse(orderModel.startKitoMetersReading?.toString() ?? "0") ?? 0.0;
      double endKm = double.tryParse(orderModel.endKitoMetersReading?.toString() ?? "0") ?? 0.0;
      if (endKm > startKm) {
        double totalKm = endKm - startKm;
        final double? includedDistance = double.tryParse('${orderModel.rentalPackageModel?.includedDistance ?? ''}');
        if (includedDistance != null && totalKm > includedDistance) {
          totalKm = totalKm - includedDistance;
          double extraKmRate = double.tryParse(orderModel.rentalPackageModel?.extraKmFare?.toString() ?? "0") ?? 0.0;
          extraKilometerCharge.value = totalKm * extraKmRate;
        }
      }
    }
    subTotal.value = subTotal.value + extraKilometerCharge.value + extraMinutesCharge.value;

    if (orderModel.taxSetting != null) {
      for (var element in orderModel.taxSetting!) {
        taxAmount.value += Constant.calculateTax(amount: (subTotal.value - discount.value).toString(), taxModel: element);
      }
    }

    totalAmount.value = (subTotal.value - discount.value) + taxAmount.value;

    if ((orderModel.adminCommission ?? '').isNotEmpty) {
      adminComm.value = Constant.calculateAdminCommission(
          amount: (subTotal.value - discount.value).toString(), adminCommissionType: orderModel.adminCommissionType.toString(), adminCommission: orderModel.adminCommission ?? '0');
    }

    if (orderModel.paymentMethod.toString() != PaymentGateway.cod.name) {
      WalletTransactionModel transactionModel = WalletTransactionModel(
          id: Constant.getUuid(),
          amount: totalAmount.value,
          date: Timestamp.now(),
          paymentMethod: orderModel.paymentMethod ?? '',
          transactionUser: "driver",
          userId: walletUserId,
          isTopup: true,
          orderId: orderModel.id,
          note: "Booking amount credited",
          paymentStatus: "success");

      await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
        if (value == true) {
          await FireStoreUtils.updateUserWallet(
              amount: totalAmount.value.toString(),
              userId: walletUserId);
        }
      });
    }

    WalletTransactionModel adminCommissionTrancation = WalletTransactionModel(
        id: Constant.getUuid(),
        amount: adminComm.value,
        date: Timestamp.now(),
        paymentMethod: orderModel.paymentMethod ?? '',
        transactionUser: "driver",
        userId: walletUserId,
        isTopup: false,
        orderId: orderModel.id,
        note: "Admin commission deducted",
        paymentStatus: "success");

    print("=================== Admin Commission: ${adminComm.value} ==================");
    log("=========${adminCommissionTrancation.toJson().toString()}=========}");
    await FireStoreUtils.setWalletTransaction(adminCommissionTrancation).then((value) async {
      if (value == true) {
        await FireStoreUtils.updateUserWallet(
            amount: "-${adminComm.value.toString()}",
            userId: walletUserId);
      }
    });

  }
}

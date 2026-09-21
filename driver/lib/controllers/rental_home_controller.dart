import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
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


  @override
  void onInit() {
    getBookingData();
    // TODO: implement onInit
    super.onInit();
  }


  Future<void> getBookingData() async {
    isLoading.value = true;
    rentalBookingData.clear();

    // Driver’s active rental bookings
    FireStoreUtils.fireStore
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
            rentalBookingData.add(RentalOrderModel.fromJson(element.data()));
          }

          // ✅ Turn off loader *after first snapshot*
          isLoading.value = false;
          update();
        });

    // Driver user data listener
    FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).snapshots().listen((event) {
      if (event.exists) {
        userModel.value = UserModel.fromJson(event.data()!);
      }
    });

    if (Constant.userModel!.ownerId != null && Constant.userModel!.ownerId!.isNotEmpty) {
      FireStoreUtils.fireStore.collection(CollectionName.users).doc(Constant.userModel!.ownerId).snapshots().listen(
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
    parcelBookingData.status = Constant.orderCompleted;

    await updateCabWalletAmount(parcelBookingData);
    await FireStoreUtils.rentalOrderPlace(parcelBookingData);
    Map<String, dynamic> payLoad = <String, dynamic>{"type": "rental_order", "orderId": parcelBookingData.id};
    SendNotification.sendFcmMessage(Constant.rentalCompleted, parcelBookingData.author!.fcmToken.toString(), payLoad);
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
    subTotal.value = 0.0;
    discount.value = 0.0;
    taxAmount.value = 0.0;
    totalAmount.value = 0.0;
    extraKilometerCharge.value = 0.0;
    extraMinutesCharge.value = 0.0;
    adminComm.value = 0.0;
    subTotal.value = double.tryParse(orderModel.subTotal?.toString() ?? "0") ?? 0.0;
    discount.value = double.tryParse(orderModel.discount?.toString() ?? "0") ?? 0.0;

    if (orderModel.endTime != null) {
      DateTime start = orderModel.startTime!.toDate();
      DateTime end = orderModel.endTime!.toDate();
      int hours = end.difference(start).inHours;
      if (hours >= int.parse(orderModel.rentalPackageModel!.includedHours.toString())) {
        hours = hours - int.parse(orderModel.rentalPackageModel!.includedHours.toString());
        double hourlyRate = double.tryParse(orderModel.rentalPackageModel?.extraMinuteFare?.toString() ?? "0") ?? 0.0;
        extraMinutesCharge.value = (hours * 60) * hourlyRate;
      }
    }

    if (orderModel.startKitoMetersReading != null && orderModel.endKitoMetersReading != null) {
      double startKm = double.tryParse(orderModel.startKitoMetersReading?.toString() ?? "0") ?? 0.0;
      double endKm = double.tryParse(orderModel.endKitoMetersReading?.toString() ?? "0") ?? 0.0;
      if (endKm > startKm) {
        double totalKm = endKm - startKm;
        if (totalKm > double.parse(orderModel.rentalPackageModel!.includedDistance!)) {
          totalKm = totalKm - double.parse(orderModel.rentalPackageModel!.includedDistance!);
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

    if (orderModel.adminCommission!.isNotEmpty) {
      adminComm.value = Constant.calculateAdminCommission(
          amount: (subTotal.value - discount.value).toString(), adminCommissionType: orderModel.adminCommissionType.toString(), adminCommission: orderModel.adminCommission ?? '0');
    }

    if (orderModel.paymentMethod.toString() != PaymentGateway.cod.name) {
      WalletTransactionModel transactionModel = WalletTransactionModel(
          id: Constant.getUuid(),
          amount: totalAmount.value,
          date: Timestamp.now(),
          paymentMethod: orderModel.paymentMethod!,
          transactionUser: "driver",
          userId: orderModel.driver!.ownerId != null && orderModel.driver!.ownerId!.isNotEmpty ? orderModel.driver!.ownerId.toString() : FireStoreUtils.getCurrentUid(),
          isTopup: true,
          orderId: orderModel.id,
          note: "Booking amount credited",
          paymentStatus: "success");

      await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
        if (value == true) {
          await FireStoreUtils.updateUserWallet(
              amount: totalAmount.value.toString(),
              userId: orderModel.driver!.ownerId != null && orderModel.driver!.ownerId!.isNotEmpty ? orderModel.driver!.ownerId.toString() : FireStoreUtils.getCurrentUid());
        }
      });
    }

    WalletTransactionModel adminCommissionTrancation = WalletTransactionModel(
        id: Constant.getUuid(),
        amount: adminComm.value,
        date: Timestamp.now(),
        paymentMethod: orderModel.paymentMethod!,
        transactionUser: "driver",
        userId: orderModel.driver!.ownerId != null && orderModel.driver!.ownerId!.isNotEmpty ? orderModel.driver!.ownerId.toString() : FireStoreUtils.getCurrentUid(),
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
            userId: orderModel.driver!.ownerId != null && orderModel.driver!.ownerId!.isNotEmpty ? orderModel.driver!.ownerId.toString() : FireStoreUtils.getCurrentUid());
      }
    });

  }
}

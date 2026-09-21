import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/app/wallet_screen/payment_list_screen.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/wallet_transaction_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:get/get.dart';

class ParcelHomeController extends GetxController {
  RxList<ParcelOrderModel> parcelOrdersList = <ParcelOrderModel>[].obs;
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getParcelList();
    super.onInit();
  }

  Rx<UserModel> userModel = UserModel().obs;
  Rx<UserModel> ownerModel = UserModel().obs;

  Future<void> getParcelList() async {
    print("==>${userModel.value.isActive}");
    FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).snapshots().listen(
          (event) {
        if (event.exists) {
          userModel.value = UserModel.fromJson(event.data()!);
          print("==>${userModel.value.isActive}");
          update();
        }
      },
    );
    print("==>${userModel.value.isActive}");


    await FireStoreUtils.getOnGoingParcelList().then(
      (value) {
        parcelOrdersList.value = value;
        update();
      },
    );

    if (Constant.userModel!.ownerId != null && Constant.userModel!.ownerId!.isNotEmpty) {
      FireStoreUtils.fireStore.collection(CollectionName.users).doc(Constant.userModel!.ownerId).snapshots().listen(
            (event) async {
          if (event.exists) {
            ownerModel.value = UserModel.fromJson(event.data()!);
          }
        },
      );
    }
    isLoading.value = false;
    update();
  }

  Future<void> pickupParcel(ParcelOrderModel parcelBookingData) async {
    ShowToastDialog.showLoader("Please wait".tr);
    parcelBookingData.status = Constant.orderInTransit;
    await FireStoreUtils.setParcelOrder(parcelBookingData);
    await getParcelList();
    ShowToastDialog.closeLoader();
  }

  Future<void> completeParcel(ParcelOrderModel parcelBookingData) async {
    ShowToastDialog.showLoader("Please wait");
    parcelBookingData.status = Constant.orderCompleted;

    await updateCabWalletAmount(parcelBookingData);
    await FireStoreUtils.setParcelOrder(parcelBookingData);
    Map<String, dynamic> payLoad = <String, dynamic>{"type": "parcel_order", "orderId": parcelBookingData.id};
    await SendNotification.sendFcmMessage(Constant.parcelCompleted, parcelBookingData.author!.fcmToken.toString(), payLoad);
    await getParcelList();
    await FireStoreUtils.getParcelFirstOrderOrNOt(parcelBookingData).then((value) async {
      if (value == true) {
        await FireStoreUtils.updateParcelReferralAmount(parcelBookingData);
      }
    });

    ShowToastDialog.closeLoader();
  }

  Future<void> updateCabWalletAmount(ParcelOrderModel orderModel) async {
    double totalTax = 0.0;
    double adminComm = 0.0;
    double discount = 0.0;
    double subTotal = 0.0;
    double totalAmount = 0.0;

    subTotal = double.parse(orderModel.subTotal ?? '0.0');
    discount = double.parse(orderModel.discount ?? '0.0');

    for (var element in orderModel.taxSetting!) {
      totalTax = totalTax + Constant.calculateTax(amount: (subTotal - discount).toString(), taxModel: element);
    }

    if (orderModel.adminCommission!.isNotEmpty) {
      adminComm = Constant.calculateAdminCommission(
          amount: (subTotal - discount).toString(),
          adminCommissionType: orderModel.adminCommissionType.toString(),
          adminCommission: orderModel.adminCommission ?? '0');
    }

    totalAmount = ((subTotal - discount) + totalTax);
    if (orderModel.paymentMethod.toString() != PaymentGateway.cod.name) {
      WalletTransactionModel transactionModel = WalletTransactionModel(
          id: Constant.getUuid(),
          amount: totalAmount,
          date: Timestamp.now(),
          paymentMethod: orderModel.paymentMethod!,
          transactionUser: "driver",
          userId: orderModel.driver!.ownerId != null && orderModel.driver!.ownerId!.isNotEmpty
              ? orderModel.driver!.ownerId.toString()
              : FireStoreUtils.getCurrentUid(),
          isTopup: true,
          orderId: orderModel.id,
          note: "Booking amount credited",
          paymentStatus: "success");

      await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
        if (value == true) {
          await FireStoreUtils.updateUserWallet(
              amount: totalAmount.toString(),
              userId: orderModel.driver!.ownerId != null && orderModel.driver!.ownerId!.isNotEmpty
                  ? orderModel.driver!.ownerId.toString()
                  : FireStoreUtils.getCurrentUid());
        }
      });
    }

    WalletTransactionModel transactionModel = WalletTransactionModel(
        id: Constant.getUuid(),
        amount: adminComm,
        date: Timestamp.now(),
        paymentMethod: orderModel.paymentMethod!,
        transactionUser: "driver",
        userId: orderModel.driver!.ownerId != null && orderModel.driver!.ownerId!.isNotEmpty
            ? orderModel.driver!.ownerId.toString()
            : FireStoreUtils.getCurrentUid(),
        isTopup: false,
        orderId: orderModel.id,
        note: "Admin commission deducted",
        paymentStatus: "success");

    await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
      if (value == true) {
        await FireStoreUtils.updateUserWallet(
            amount: "-${adminComm.toString()}",
            userId: orderModel.driver!.ownerId != null && orderModel.driver!.ownerId!.isNotEmpty
                ? orderModel.driver!.ownerId.toString()
                : FireStoreUtils.getCurrentUid());
      }
    });
  }

  String calculateParcelTotalAmountBooking(ParcelOrderModel parcelBookingData) {
    String subTotal = parcelBookingData.subTotal.toString();
    String discount = parcelBookingData.discount ?? "0.0";
    String taxAmount = "0.0";
    for (var element in parcelBookingData.taxSetting!) {
      taxAmount = (double.parse(taxAmount) +
              Constant.calculateTax(amount: (double.parse(subTotal) - double.parse(discount)).toString(), taxModel: element))
          .toStringAsFixed(int.tryParse(Constant.currencyModel!.decimalDigits.toString()) ?? 2);
    }

    return ((double.parse(subTotal) - (double.parse(discount))) + double.parse(taxAmount))
        .toStringAsFixed(int.tryParse(Constant.currencyModel!.decimalDigits.toString()) ?? 2);
  }
}

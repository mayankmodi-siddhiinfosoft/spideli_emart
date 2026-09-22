import 'package:driver/app/parcel_screen/parcel_tracking/parcel_proof_sheet.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/parcel_tracking_service.dart';
import 'package:flutter/material.dart';
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
    String? error;
    try {
      // Existing "In Transit" status, plus the tracking event `Collected` (spec 4.2 step 8) — field updates only.
      error = await ParcelTrackingService.onLegacyPickup(parcelBookingData);
    } catch (e) {
      debugPrint('ParcelHomeController.pickupParcel $e');
      error = "Something went wrong. Please try again.";
    } finally {
      ShowToastDialog.closeLoader();
    }
    if (error != null) {
      ShowToastDialog.showToast(error.tr);
      return;
    }
    await getParcelList();
  }

  /// Existing "Deliver Parcel": for a contract parcel delivered at home the driver first records proof
  /// (receiver code or photo); for pickup-point delivery the last step is the hand-over at that point.
  /// Parcels created before the contract complete exactly as before (plus a `Delivered` tracking event).
  Future<void> completeParcel(ParcelOrderModel listOrder, {BuildContext? context, bool isDark = false}) async {
    // The list may be stale (e.g. the parcel was completed or cancelled from another screen): re-read and
    // refuse cancelled / returned / already completed parcels, or steps that must be scanned.
    ParcelOrderModel parcelBookingData;
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      parcelBookingData = await ParcelTrackingService.prepareLegacyDeliver(listOrder);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(e is String ? e.tr : "Something went wrong. Please try again.".tr);
      await getParcelList();
      return;
    }
    ShowToastDialog.closeLoader();
    Map<String, dynamic>? proof;
    if (parcelBookingData.deliveryMethod == 'pickup_point') {
      final ok = await Get.dialog<bool>(AlertDialog(
        title: Text("Hand over at the pickup point".tr),
        content: Text("Confirm the parcel was handed over at the destination pickup point. This completes your delivery.".tr),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text("Cancel".tr)),
          TextButton(onPressed: () => Get.back(result: true), child: Text("Confirm".tr)),
        ],
      ));
      if (ok != true) return;
    } else if (parcelBookingData.hasTrackingContract && context != null && context.mounted) {
      proof = await showParcelProofSheet(context, parcelBookingData, isDark: isDark);
      if (proof == null) return;
    }
    ShowToastDialog.showLoader("Please wait".tr);
    String? error;
    try {
      await ParcelTrackingService.onLegacyDeliver(parcelBookingData, deliveryProof: proof);
    } catch (e) {
      debugPrint('ParcelHomeController.completeParcel $e');
      error = e is String ? e : "Something went wrong. Please try again.";
    } finally {
      ShowToastDialog.closeLoader();
    }
    if (error != null) ShowToastDialog.showToast(error.tr);
    await getParcelList();
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

    // Fixed intercity/intercountry tax is added on top of the taxed amount.
    return ((double.parse(subTotal) - (double.parse(discount))) + double.parse(taxAmount) + (parcelBookingData.parcelScopeTax ?? 0).toDouble())
        .toStringAsFixed(int.tryParse(Constant.currencyModel!.decimalDigits.toString()) ?? 2);
  }
}

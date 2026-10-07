import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/app/parcel_screen/parcel_tracking/parcel_proof_sheet.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/parcel_tracking_service.dart';
import 'package:flutter/material.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/parcel_amounts.dart';
import 'package:get/get.dart';

class ParcelHomeController extends GetxController {
  RxList<ParcelOrderModel> parcelOrdersList = <ParcelOrderModel>[].obs;
  RxBool isLoading = true.obs;

  /// Live list of the parcels assigned to this driver (panel report 01 §4).
  StreamSubscription<List<ParcelOrderModel>>? _ongoingSub;

  // One subscription each: [getParcelList] runs again after every pickup,
  // delivery, scan and pull-to-refresh, and each run used to add another
  // pair of user / owner listeners on top of the last.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _ownerSub;

  @override
  void onInit() {
    // TODO: implement onInit
    getParcelList();
    _listenOnGoingParcels();
    super.onInit();
  }

  @override
  void onClose() {
    _ongoingSub?.cancel();
    _userSub?.cancel();
    _ownerSub?.cancel();
    super.onClose();
  }

  /// The list was read once on open (and after a pickup / delivery), so a
  /// parcel assigned while the screen was open only showed on the next visit.
  /// Same query, kept live; [getParcelList] still refreshes it after actions.
  void _listenOnGoingParcels() {
    _ongoingSub?.cancel();
    _ongoingSub = FireStoreUtils.listenOnGoingParcelList().listen(
      (value) {
        parcelOrdersList.value = value;
        update();
      },
      onError: (Object e) => log("ParcelHomeController ongoing parcels failed: $e"),
    );
  }

  Rx<UserModel> userModel = UserModel().obs;
  Rx<UserModel> ownerModel = UserModel().obs;

  Future<void> getParcelList() async {
    print("==>${userModel.value.isActive}");
    _userSub?.cancel();
    _userSub = FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).snapshots().listen(
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

    // An independent driver has no owner, and `Constant.userModel` itself
    // can still be null on a cold start — the `!` threw here and took the
    // whole subscribe step (including the driver listener below it in the
    // other modules) down with it.
    final String ownerId = Constant.userModel?.ownerId ?? '';
    _ownerSub?.cancel();
    _ownerSub = null;
    if (ownerId.isNotEmpty) {
      _ownerSub = FireStoreUtils.fireStore.collection(CollectionName.users).doc(ownerId).snapshots().listen(
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
    final String? receiverCode = ParcelTrackingService.receiverCode(parcelBookingData);
    if (receiverCode != null && parcelBookingData.deliveryMethod != 'pickup_point' && (context == null || !context.mounted)) {
      // Client point 20: never complete a coded delivery without the code.
      ShowToastDialog.showToast("Open the parcel and complete it from there: the receiver's code is required.".tr);
      return;
    }
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
    } else if ((parcelBookingData.hasTrackingContract || receiverCode != null) && context != null && context.mounted) {
      // Client point 20: a parcel carrying a receiver code always needs the
      // proof step, contract or not — the code IS the proof of delivery.
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

  /// The total the customer was charged, which is what the driver collects
  /// on a cash parcel ([ParcelAmounts]: platform fee and its taxes, the fixed
  /// tax and the receiver-SMS fee included). Tolerant: this runs while the job
  /// card is built, and a parcel without `subTotal` / `taxSetting` (or with an
  /// empty discount) used to throw there, replacing the card and its Pickup /
  /// Deliver buttons.
  String calculateParcelTotalAmountBooking(ParcelOrderModel parcelBookingData) {
    final int digits = int.tryParse('${Constant.currencyModel?.decimalDigits}') ?? 2;
    return ParcelAmounts.of(parcelBookingData).totalText(digits);
  }

}

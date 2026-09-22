import 'dart:developer';
import 'dart:math' as maths;

import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/rental_order_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/rental_proposal_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../screen_ui/rental_service/rental_dashboard_screen.dart';
import 'cab_rental_dashboard_controllers.dart';

class RentalConformationController extends GetxController {
  RxBool isLoading = false.obs;

  Rx<RentalOrderModel> rentalOrderModel = RentalOrderModel().obs;
  Rx<TextEditingController> couponController = TextEditingController().obs;

  @override
  void onInit() {
    getArguments();
    fetchCoupons();
    super.onInit();
  }

  void getArguments() {
    final args = Get.arguments;
    if (args.containsKey('rentalOrderModel') && args['rentalOrderModel'] is RentalOrderModel) {
      rentalOrderModel.value = args['rentalOrderModel'] as RentalOrderModel;
      calculateAmount();
    } else {
      debugPrint('No rental order found in arguments or invalid format.');
    }
    isLoading.value = false;
  }

  RxDouble subTotal = 0.0.obs;
  RxDouble discount = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxDouble orderTaxAmount = 0.0.obs;
  RxDouble platformTaxAmount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;
  Rx<CouponModel> selectedCouponModel = CouponModel().obs;

  void calculateAmount() {
    subTotal.value = 0.0;
    discount.value = 0.0;
    taxAmount.value = 0.0;
    totalAmount.value = 0.0;
    orderTaxAmount.value = 0;
    platformTaxAmount.value = 0;

    subTotal.value = double.tryParse(rentalOrderModel.value.subTotal ?? '0') ?? 0.0;
    if (selectedCouponModel.value.id != null) {
      discount.value = Constant.calculateDiscount(amount: subTotal.value.toString(), offerModel: selectedCouponModel.value);
    }
    log("orderProductTaxList.value ::11:: ${Constant.orderProductTaxList?.length}");
    for (var taxElement in Constant.orderProductTaxList ?? []) {
      orderTaxAmount.value += Constant.calculateTax(amount: (subTotal.value - discount.value).toString(), taxModel: taxElement);
    }
    log("platformTaxAmount.value ::11:: ${Constant.platformTaxList?.length}");
    if (Constant.platformFeeModel?.enable == true && double.parse(Constant.platformFeeModel?.fee ?? '0.0') > 0.0) {
      for (var taxElement in Constant.platformTaxList ?? []) {
        platformTaxAmount.value += Constant.calculateTax(amount: Constant.platformFeeModel?.fee ?? '0.0', taxModel: taxElement);
      }
    }
    taxAmount.value = orderTaxAmount.value + platformTaxAmount.value;
    totalAmount.value = subTotal.value - discount.value + double.parse(Constant.platformFeeModel?.fee ?? '0.0') + taxAmount.value;
  }

  RxList<CouponModel> couponList = <CouponModel>[].obs;

  Future<void> fetchCoupons() async {
    try {
      await FireStoreUtils.getRentalCoupon().then((value) {
        couponList.value = value;
      });
    } catch (e) {
      print("Error fetching coupons: $e");
    }
  }

  /// "Propose my price" (spec 4.9): books the car like [placeOrder] and adds a
  /// pending `priceProposal`. The listed price stays in `subTotal` (and is kept
  /// in `listedPrice`); it changes only when a proposal / counter is accepted.
  /// A coupon is not combined with a proposal (the discount would apply to a
  /// price that is still being negotiated).
  Future<void> proposePrice({required num amount, String? message}) async {
    if (selectedCouponModel.value.id != null) {
      selectedCouponModel.value = CouponModel();
      couponController.value.clear();
      calculateAmount();
      ShowToastDialog.showToast("Coupons can't be combined with a price proposal".tr);
    }
    await placeOrder(
      extraFields: {'priceProposal': RentalProposalService.initial(amount: amount, message: message), 'listedPrice': subTotal.value.toString()},
      successMessage: "Your price proposal was sent".tr,
    );
  }

  Future<void> placeOrder({Map<String, dynamic>? extraFields, String? successMessage}) async {
    ShowToastDialog.showLoader("Placing booking...".tr);
    rentalOrderModel.value.discount = discount.value.toString();
    rentalOrderModel.value.couponCode = selectedCouponModel.value.code;
    rentalOrderModel.value.couponId = selectedCouponModel.value.id;
    rentalOrderModel.value.subTotal = subTotal.value.toString();
    rentalOrderModel.value.otpCode = (maths.Random().nextInt(9000) + 1000).toString();
    rentalOrderModel.value.platformFee = Constant.platformFeeModel?.fee;
    rentalOrderModel.value.platformTax = Constant.platformTaxList;
    rentalOrderModel.value.taxSetting = Constant.orderProductTaxList;
    // Creation write; `priceProposal` / `listedPrice` are not in toJson (the
    // Driver app answers the proposal), so they are added here.
    await FireStoreUtils.fireStore.collection(CollectionName.rentalOrders).doc(rentalOrderModel.value.id).setKnownFields({...rentalOrderModel.value.toJson(), ...?extraFields}).then((value) async {
      await FireStoreUtils.sendCarBookEmail(orderModel: rentalOrderModel.value);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(successMessage ?? "Order placed successfully".tr);
      Get.offAll(const RentalDashboardScreen());
      CabRentalDashboardControllers controller = Get.put(CabRentalDashboardControllers());
      controller.selectedIndex.value = 1;
      // Get.back();
    });
  }
}

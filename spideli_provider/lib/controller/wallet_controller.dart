import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/FlutterWaveSettingDataModel.dart';
import 'package:spideliprovider/model/paypalSettingData.dart';
import 'package:spideliprovider/model/stripeSettingData.dart';
import 'package:spideliprovider/model/topupTranHistory.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/model/withdrawHistoryModel.dart';
import 'package:spideliprovider/model/withdraw_method_model.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../model/razorpayKeyModel.dart';

class WalletController extends GetxController {
  RxBool isLoading = true.obs;
  RxString walletAmount = "0.0".obs;

  static FirebaseFirestore fireStore = FireStoreUtils.firestore;

  RxList<WithdrawHistoryModel> withdrawHistoryQuery = <WithdrawHistoryModel>[].obs;
  RxList<TopupTranHistoryModel> topupHistoryQuery = <TopupTranHistoryModel>[].obs;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? userQuery;
  RxString userId = "".obs;

  UserBankDetails? userBankDetail = MyAppState.currentUser!.userBankDetails;
  Rx<TextEditingController> amountController = TextEditingController(text: 50.toString()).obs;
  Rx<TextEditingController> noteController = TextEditingController(text: '').obs;

  Rx<WithdrawMethodModel> withdrawMethodModel = WithdrawMethodModel().obs;
  RxInt selectedValue = 0.obs;
  Rx<RazorPayModel> razorPayModel = RazorPayModel().obs;
  Rx<PaypalSettingData> paypalDataModel = PaypalSettingData().obs;
  Rx<StripeSettingData> stripeSettingData = StripeSettingData().obs;
  Rx<FlutterWaveSettingData> flutterWaveSettingData = FlutterWaveSettingData().obs;

  @override
  void onInit() {
    getData();
    super.onInit();
  }

  getData() async {
    userId.value = MyAppState.currentUser!.id;
    try {
      userQuery = fireStore.collection(USERS).doc(userId.value).snapshots();
      print(userQuery!.isEmpty);
    } catch (e) {
      print(e);
    }
    await getPaymentSettings();

    await FireStoreUtils.getTopUpTransaction(userId.value).then((value) {
      topupHistoryQuery.clear();
      topupHistoryQuery.addAll(value);
    });

    await FireStoreUtils.getWithdrawTransaction(userId.value).then((value) {
      withdrawHistoryQuery.clear();
      withdrawHistoryQuery.addAll(value);
    });

    update();
  }

  getPaymentSettings() async {
    await FireStoreUtils.firestore.collection(Setting).doc("razorpaySettings").get().then((user) {
      debugPrint(user.data().toString());
      try {
        razorPayModel.value = RazorPayModel.fromJson(user.data() ?? {});
      } catch (e) {
        debugPrint('FireStoreUtils.getUserByID failed to parse user object ${user.id}');
      }
    });

    await FireStoreUtils.firestore.collection(Setting).doc("paypalSettings").get().then((paypalData) {
      try {
        paypalDataModel.value = PaypalSettingData.fromJson(paypalData.data() ?? {});
      } catch (error) {
        debugPrint(error.toString());
      }
    });

    await FireStoreUtils.firestore.collection(Setting).doc("stripeSettings").get().then((paypalData) {
      try {
        stripeSettingData.value = StripeSettingData.fromJson(paypalData.data() ?? {});
      } catch (error) {
        debugPrint(error.toString());
      }
    });

    await FireStoreUtils.firestore.collection(Setting).doc("flutterWave").get().then((paypalData) {
      try {
        flutterWaveSettingData.value = FlutterWaveSettingData.fromJson(paypalData.data() ?? {});
      } catch (error) {
        debugPrint(error.toString());
      }
    });

    await FireStoreUtils.getWithdrawMethod().then(
      (value) {
        if (value != null) {
          withdrawMethodModel.value = value;
        }
      },
    );
    update();
  }
}

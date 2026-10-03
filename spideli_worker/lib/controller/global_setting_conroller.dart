import 'dart:developer';

import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/model/currency_model.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:get/get.dart';

class GlobalSettingController extends GetxController {
  @override
  void onInit() {
    // Notifications are set up once, after the first frame, by
    // MyAppState.notificationInit (main.dart). A second NotificationService
    // .initInfo() here asked for the permission a second time at startup.
    getCurrentCurrency();
    super.onInit();
  }

  Future<void> getCurrentCurrency() async {
    // Guarded: offline it used to throw an unhandled exception at start-up.
    CurrencyModel? value;
    try {
      value = await FireStoreUtils.getCurrency();
    } catch (e) {
      log("getCurrency failed: $e");
    }
    currencyData = value ?? CurrencyModel(id: "", code: "USD", decimal: 2, isactive: true, name: "US Dollar", symbol: "\$", symbolatright: false);
  }

}

import 'dart:developer';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/model/currency_model.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/region_service.dart';
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

  getCurrentCurrency() async {
    // Each read is guarded: offline, they used to throw an unhandled
    // exception at start-up (seen with the splash hang).
    CurrencyModel? value;
    try {
      value = await FireStoreUtils.getCurrency();
    } catch (e) {
      log("getCurrency failed: $e");
    }
    currencyData = value ?? CurrencyModel(id: "", code: "USD", decimal: 2, isactive: true, name: "US Dollar", symbol: "\$", symbolatright: false);
    // Global currency is only the fallback; a provider with a region keeps
    // its region currency even if this read finishes last.
    RegionService.onGlobalCurrency(currencyData!);

    try {
      final settings = await FireStoreUtils.firestore.collection(Setting).doc('globalSettings').get();
      defaultCountryCode = settings.data()?['defaultCountryCode'] ?? '';
      defaultCountry = settings.data()?['defaultCountry'] ?? '';
    } catch (e) {
      log("globalSettings read failed: $e");
    }
    update();
  }

}

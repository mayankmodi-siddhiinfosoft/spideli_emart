import 'dart:developer';

import 'package:driver/constant/constant.dart';
import 'package:driver/models/currency_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:driver/utils/region_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../constant/collection_name.dart';

class GlobalSettingController extends GetxController {
  @override
  void onInit() {
    notificationInit();
    getCurrentCurrency();

    super.onInit();
  }

  Future<void> getCurrentCurrency() async {
    FireStoreUtils.fireStore.collection(CollectionName.currencies).where("isActive", isEqualTo: true).snapshots().listen((event) {
      if (event.docs.isNotEmpty) {
        Constant.currencyModel = CurrencyModel.fromJson(event.docs.first.data());
      } else {
        Constant.currencyModel = CurrencyModel(id: "", code: "USD", decimalDigits: 2, enable: true, name: "US Dollar", symbol: "\$", symbolAtRight: false);
      }
      // The global currency is only a fallback now: a driver attached to a
      // region shows live amounts in that region's currency.
      RegionService.onGlobalCurrency(Constant.currencyModel!);
    });
    RegionService.ensureLoaded();
    await FireStoreUtils.getSettings();
  }

  NotificationService notificationService = NotificationService();

  void notificationInit() {
    notificationService.initInfo().then((value) async {
      // Client point 19: the token has to be on the driver's user document on
      // every launch AND whenever FCM rotates it, and the driver has to be on
      // the topics the server addresses available work by. The token is
      // written field-level (it used to write the whole user document back,
      // over whatever changed since it was read) and never logged.
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final UserModel? driverUserModel = await FireStoreUtils.getUserProfile(user.uid);
      await NotificationService.syncSignedInDevice(driverUserModel);
    }).catchError((Object e) {
      log("notificationInit failed: $e");
    });
  }
}

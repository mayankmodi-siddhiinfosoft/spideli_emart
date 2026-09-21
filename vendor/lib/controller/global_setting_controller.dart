import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/currency_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/notification_service.dart';

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
    });
    await FireStoreUtils.getSettings();
  }

  NotificationService notificationService = NotificationService();

  dynamic notificationInit() => notificationService.initInfo().then((value) async {
    String token = await NotificationService.getToken();
    if (FirebaseAuth.instance.currentUser != null) {
      await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) {
        if (value != null) {
          UserModel driverUserModel = value;
          driverUserModel.fcmToken = token;
          FireStoreUtils.updateUser(driverUserModel);
        }
      });
    }
  });
}

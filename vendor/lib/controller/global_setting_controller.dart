import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/currency_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/notification_service.dart';
import 'package:vendor/utils/region_service.dart';

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
      // The global currency is only a fallback: once the store is known, its
      // region's currency wins (see RegionService).
      RegionService.onGlobalCurrency(Constant.currencyModel!);
    });
    await FireStoreUtils.getSettings();
  }

  NotificationService notificationService = NotificationService();

  /// Channels, listeners, permission and the device token. `initInfo` saves
  /// the token on the signed-in user itself, as a field-level write. This
  /// used to write the whole profile back with whatever `getToken()`
  /// returned - `''` on iOS, where it ran before the APNs token existed.
  Future<void> notificationInit() => notificationService.initInfo();
}

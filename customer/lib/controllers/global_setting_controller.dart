import 'dart:async';

import 'package:customer/constant/constant.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/utils/notification_service.dart';
import 'package:customer/utils/push_token_sync.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../constant/collection_name.dart';
import '../service/fire_store_utils.dart';
import '../utils/region_service.dart';

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
        Constant.currencyModel = CurrencyModel(id: "", code: "USD", decimal: 2, isactive: true, name: "US Dollar", symbol: "\$", symbolatright: false);
      }
    });
    // Regions, their currencies and zones (spec 18.4 / 18.5): loaded once,
    // alongside the settings. Without region data nothing changes.
    await Future.wait([FireStoreUtils.getSettings(), RegionService.ensureLoaded()]);
  }

  NotificationService notificationService = NotificationService();

  void notificationInit() {
    // The token does not need the permission (and the dialog can stay open),
    // so it is saved straight away: field-level, and never '' over a good one.
    // This used to save a whole user with whatever getToken() gave, which on
    // iOS was '' (no APNs token yet), wiping the iPhone's token on every start.
    unawaited(PushTokenSync.syncForCurrentUser());
    // Receiving and the permission dialog, after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(notificationService.initInfo()));
  }
}

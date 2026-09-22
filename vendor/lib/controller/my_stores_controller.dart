import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:get/get.dart';
import 'package:vendor/app/splash_screen.dart';
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/home_controller.dart';
import 'package:vendor/models/currency_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/region_service.dart';
import 'package:vendor/utils/store_service.dart';

/// One store's figures for the consolidated view (spec 8.1: "the dashboard can
/// show per store or consolidated"). A null count means it could not be read.
class StoreOverview {
  final int? ordersToday;
  final int? inProgress;
  final int? completedToday;
  final double balance;
  final CurrencyModel? currency;

  const StoreOverview({this.ordersToday, this.inProgress, this.completedToday, required this.balance, this.currency});

  String get balanceText => Constant.amountShow(currency: currency, amount: balance.toString());
}

class MyStoresController extends GetxController {
  /// Load the per-store figures too (the My Stores screen). The header store
  /// picker only needs the list.
  final bool withOverview;

  MyStoresController({this.withOverview = true});

  RxBool isLoading = true.obs;
  RxList<VendorModel> stores = <VendorModel>[].obs;

  RxBool isOverviewLoading = false.obs;
  RxMap<String, StoreOverview> overviews = <String, StoreOverview>{}.obs;

  String? get currentStoreId => Constant.userModel?.vendorID;

  /// Orders not finished yet: New, Preparing and Ready (see the Home tabs).
  static const List<String> inProgressStatuses = [Constant.orderPlaced, ...HomeController.preparingStatuses, ...HomeController.readyStatuses];

  @override
  void onInit() {
    getStores();
    super.onInit();
  }

  Future<void> getStores() async {
    isLoading.value = true;
    try {
      stores.value = await StoreService.getOwnerStores(FireStoreUtils.getCurrentUid());
    } catch (e) {
      ShowToastDialog.showToast("Could not load your stores".tr);
    }
    isLoading.value = false;
    if (withOverview) await getOverviews();
  }

  // ---------------------------------------------------------------------------
  // Consolidated view
  // ---------------------------------------------------------------------------

  Future<void> getOverviews() async {
    if (stores.isEmpty) {
      overviews.clear();
      return;
    }
    isOverviewLoading.value = true;
    await RegionService.ensureLoaded();
    final List<MapEntry<String, StoreOverview>> results = await Future.wait(
      stores.where((s) => (s.id ?? '').isNotEmpty).map((store) async => MapEntry(store.id!, await _overviewFor(store))),
    );
    overviews
      ..clear()
      ..addEntries(results);
    isOverviewLoading.value = false;
  }

  Future<StoreOverview> _overviewFor(VendorModel store) async {
    final Query<Map<String, dynamic>> orders = FireStoreUtils.fireStore.collection(CollectionName.vendorOrders).where('vendorID', isEqualTo: store.id);
    final DateTime now = DateTime.now();
    final Timestamp startOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day));

    int? ordersToday;
    int? completedToday;
    try {
      // Newest first, stopping at midnight: the same (vendorID, createdAt desc)
      // index the Home order list already uses, so no new index is needed.
      final snapshot = await orders.orderBy('createdAt', descending: true).endAt([startOfDay]).get();
      final todays = snapshot.docs.where((d) {
        final created = d.data()['createdAt'];
        return created is Timestamp && created.compareTo(startOfDay) >= 0;
      }).toList();
      ordersToday = todays.length;
      completedToday = todays.where((d) => d.data()['status'] == Constant.orderCompleted).length;
    } catch (e) {
      log("Store overview (today) failed for ${store.id}: $e");
    }

    int? inProgress;
    try {
      final count = await orders.where('status', whereIn: inProgressStatuses).count().get();
      inProgress = count.count;
    } catch (e) {
      log("Store overview (in progress) failed for ${store.id}: $e");
    }

    CurrencyModel? currency;
    try {
      currency = RegionService.currencyForRegion(await RegionService.resolveStoreRegionId(store));
    } catch (e) {
      log("Store overview (currency) failed for ${store.id}: $e");
    }
    currency ??= RegionService.globalCurrency ?? Constant.currencyModel;

    return StoreOverview(
      ordersToday: ordersToday,
      inProgress: inProgress,
      completedToday: completedToday,
      balance: (store.storeWalletAmount ?? 0).toDouble(),
      currency: currency,
    );
  }

  /// Sum of a count over all stores; null when any store's figure is missing.
  int? totalOf(int? Function(StoreOverview o) pick) {
    if (overviews.isEmpty) return null;
    int total = 0;
    for (final o in overviews.values) {
      final int? value = pick(o);
      if (value == null) return null;
      total += value;
    }
    return total;
  }

  /// Currencies are the same when their code is (the same currency may be
  /// parsed from different rows), else when their symbol is.
  static String _currencyKey(CurrencyModel? c) => c == null ? '' : ((c.code ?? '').isNotEmpty ? c.code!.toUpperCase() : 'symbol:${c.symbol ?? ''}');

  /// All stores share one currency, so their balances can be added up.
  bool get hasSingleCurrency => overviews.values.map((o) => _currencyKey(o.currency)).toSet().length <= 1;

  /// Consolidated store balance, or null when the stores use several currencies.
  String? get totalBalanceText {
    if (overviews.isEmpty || !hasSingleCurrency) return null;
    final double total = overviews.values.fold(0.0, (acc, o) => acc + o.balance);
    return Constant.amountShow(currency: overviews.values.first.currency, amount: total.toString());
  }

  /// Switches to [store] and restarts from the splash screen, so every screen
  /// and cached value (store, currency, taxes, permissions) reloads for it.
  Future<void> switchTo(VendorModel store) async {
    if (store.id == null || store.id == currentStoreId) return;
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      await StoreService.selectStore(store.id!);
      ShowToastDialog.closeLoader();
      Get.offAll(() => const SplashScreen());
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Could not switch store. Please try again.".tr);
    }
  }
}

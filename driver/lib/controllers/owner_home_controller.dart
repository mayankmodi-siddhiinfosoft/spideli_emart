import 'package:driver/constant/collection_name.dart';
import 'package:driver/models/cab_order_model.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:get/get.dart';

import '../constant/constant.dart';
import '../constant/show_toast_dialog.dart';
import '../models/tax_model.dart';

class OwnerHomeController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<UserModel> driverList = <UserModel>[].obs;

  RxMap<String, int> driverRideCounts = <String, int>{}.obs;

  RxMap<String, double> driverEarnings = <String, double>{}.obs;

  @override
  void onInit() {
    super.onInit();
    getDriverList();
  }

  Future<void> getDriverList() async {
    isLoading.value = true;
    driverList.value = await FireStoreUtils.getOwnerDriver();
    isLoading.value = false;

    for (var driver in driverList) {
      if (driver.id != null && driver.id!.isNotEmpty) {
        _listenDriverOrders(driver.id!);
      }
    }
  }

  void _listenDriverOrders(String driverId) {
    FireStoreUtils.getCabDriverOrders(driverId).listen((orders) {
      _processCabOrders(driverId, orders);
    });

    FireStoreUtils.listenParcelOrders(driverId).listen((orders) {
      _processParcelOrders(driverId, orders);
    });

    FireStoreUtils.getRentalOrders(driverId).listen((orders) {
      _processRentalOrders(driverId, orders);
    });
  }

  void _processCabOrders(String driverId, List<CabOrderModel> orders) {
    final completedOrders = orders.where((o) => o.status == Constant.orderCompleted).toList();

    driverRideCounts["cab_$driverId"] = completedOrders.length;
    _updateDriverTotalRides(driverId);

    double earnings = 0;
    for (var order in completedOrders) {
      double subTotal = double.tryParse(order.subTotal ?? "0") ?? 0;
      double discount = double.tryParse(order.discount ?? "0") ?? 0;
      double tip = double.tryParse(order.tipAmount ?? "0") ?? 0;

      double taxTotal = _calculateTax(order.taxSetting, subTotal, discount);
      double driverEarned = (subTotal - discount + tip + taxTotal).clamp(0, double.infinity);

      earnings += driverEarned;
    }

    driverEarnings["cab_$driverId"] = earnings;
    _updateDriverTotalEarnings(driverId);
  }

  void _processParcelOrders(String driverId, List<ParcelOrderModel> orders) {
    final completedOrders = orders.where((o) => o.status == Constant.orderCompleted).toList();

    driverRideCounts["parcel_$driverId"] = completedOrders.length;
    _updateDriverTotalRides(driverId);

    double earnings = 0;
    for (var order in completedOrders) {
      double subTotal = double.tryParse(order.subTotal?.toString() ?? "0") ?? 0;
      double discount = double.tryParse(order.discount?.toString() ?? "0") ?? 0;

      double taxTotal = _calculateTax(order.taxSetting, subTotal, discount);
      double driverEarned = (subTotal - discount + taxTotal).clamp(0, double.infinity);

      earnings += driverEarned;
    }

    driverEarnings["parcel_$driverId"] = earnings;
    _updateDriverTotalEarnings(driverId);
  }

  void _processRentalOrders(String driverId, List<RentalOrderModel> orders) {
    final completedOrders = orders.where((o) => o.status == Constant.orderCompleted).toList();

    driverRideCounts["rental_$driverId"] = completedOrders.length;
    _updateDriverTotalRides(driverId);

    double earnings = 0;
    for (var order in completedOrders) {
      double subTotal = double.tryParse(order.subTotal ?? "0") ?? 0;
      double discount = double.tryParse(order.discount ?? "0") ?? 0;
      double tip = double.tryParse(order.tipAmount ?? "0") ?? 0;

      double taxTotal = _calculateTax(order.taxSetting, subTotal, discount);
      double driverEarned = (subTotal - discount + tip + taxTotal).clamp(0, double.infinity);

      earnings += driverEarned;
    }

    driverEarnings["rental_$driverId"] = earnings;
    _updateDriverTotalEarnings(driverId);
  }

  double _calculateTax(List<TaxModel>? taxList, double subTotal, double discount) {
    if (taxList == null) return 0.0;
    double totalTax = 0.0;

    for (var tax in taxList) {
      if (tax.enable != true) continue;

      double taxVal = double.tryParse(tax.tax ?? '0') ?? 0.0;
      String type = (tax.type ?? 'fix').toLowerCase();

      if (type == "percentage") {
        totalTax += (subTotal - discount) * taxVal / 100;
      } else {
        totalTax += taxVal;
      }
    }

    return totalTax;
  }

  void _updateDriverTotalRides(String driverId) {
    final cab = driverRideCounts["cab_$driverId"] ?? 0;
    final parcel = driverRideCounts["parcel_$driverId"] ?? 0;
    final rental = driverRideCounts["rental_$driverId"] ?? 0;
    driverRideCounts[driverId] = cab + parcel + rental;
  }

  void _updateDriverTotalEarnings(String driverId) {
    final cab = driverEarnings["cab_$driverId"] ?? 0;
    final parcel = driverEarnings["parcel_$driverId"] ?? 0;
    final rental = driverEarnings["rental_$driverId"] ?? 0;
    driverEarnings[driverId] = cab + parcel + rental;
  }

  /// Totals by type across all drivers
  int get totalCabRides => driverRideCounts.entries.where((e) => e.key.startsWith("cab_")).fold(0, (sum, e) => sum + e.value);

  int get totalParcelRides => driverRideCounts.entries.where((e) => e.key.startsWith("parcel_")).fold(0, (sum, e) => sum + e.value);

  int get totalRentalRides => driverRideCounts.entries.where((e) => e.key.startsWith("rental_")).fold(0, (sum, e) => sum + e.value);

  double get totalCabEarnings => driverEarnings.entries.where((e) => e.key.startsWith("cab_")).fold(0.0, (sum, e) => sum + e.value);

  double get totalParcelEarnings => driverEarnings.entries.where((e) => e.key.startsWith("parcel_")).fold(0.0, (sum, e) => sum + e.value);

  double get totalRentalEarnings => driverEarnings.entries.where((e) => e.key.startsWith("rental_")).fold(0.0, (sum, e) => sum + e.value);

  /// Grand totals across all drivers
  int get totalRidesAllDrivers => driverList.fold(0, (total, driver) => total + (driverRideCounts[driver.id] ?? 0));

  double get totalEarningsAllDrivers => driverList.fold(0.0, (total, driver) => total + (driverEarnings[driver.id] ?? 0));

  Future<void> deleteDriver(String driverId) async {
    ShowToastDialog.showLoader("Deleting driver...".tr);

    await FireStoreUtils.deleteDriverId(driverId).then((isDeleted) async {
      ShowToastDialog.closeLoader();

      if (isDeleted) {
        await FireStoreUtils.fireStore.collection(CollectionName.users).doc(driverId).delete();
        ShowToastDialog.showToast("Driver account deleted successfully".tr);
        getDriverList();
      } else {
        ShowToastDialog.showToast("Failed to delete driver. Please contact administrator.".tr);
      }
    }).catchError((error) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("An error occurred while deleting driver: $error".tr);
    });
  }
}

import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:get/get.dart';
import '../constant/constant.dart';
import '../models/user_model.dart';

class RentalOrderDetailsController extends GetxController {
  Rx<RentalOrderModel> order = RentalOrderModel().obs;
  RxBool isLoading = true.obs;

  RxDouble subTotal = 0.0.obs;
  RxDouble discount = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;
  RxDouble adminCommission = 0.0.obs;
  RxDouble extraKilometerCharge = 0.0.obs;
  RxDouble extraMinutesCharge = 0.0.obs;
  Rx<UserModel?> userData = Rx<UserModel?>(null);

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args != null && args["rentalOrder"] != null) {
      String orderId = args["rentalOrder"];
      fetchOrder(orderId);
    } else {
      isLoading.value = false;
      ShowToastDialog.showToast("Invalid order details");
    }
  }

  String getExtraKm() {
    try {
      final double start = double.tryParse(order.value.startKitoMetersReading ?? '0') ?? 0.0;
      final double end = double.tryParse(order.value.endKitoMetersReading ?? '0') ?? 0.0;
      final double included = double.tryParse(order.value.rentalPackageModel?.includedDistance?.toString() ?? '0') ?? 0.0;

      // Calculate extra km safely
      final double extra = (end - start - included);
      final double validExtra = extra > 0 ? extra : 0;

      return "${validExtra.toStringAsFixed(2)} ${Constant.distanceType}";
    } catch (e) {
      return "0 ${Constant.distanceType}";
    }
  }

  ///Safe calculation after order is loaded
  void calculateTotalAmount() {
    try {
      subTotal.value = double.tryParse(order.value.subTotal?.toString() ?? "0") ?? 0.0;
      discount.value = double.tryParse(order.value.discount?.toString() ?? "0") ?? 0.0;
      taxAmount.value = 0.0;

      if (order.value.endTime != null) {
        DateTime start = order.value.startTime!.toDate();
        DateTime end = order.value.endTime!.toDate();

        // Total rented minutes
        int totalMinutes = end.difference(start).inMinutes;

        int includedMinutes = (int.tryParse(order.value.rentalPackageModel?.includedHours.toString() ?? "0") ?? 0) * 60;

        if (totalMinutes > includedMinutes) {
          int extraMinutes = totalMinutes - includedMinutes;

          double minuteFare = double.tryParse(order.value.rentalPackageModel?.extraMinuteFare?.toString() ?? "0") ?? 0.0;

          extraMinutesCharge.value = extraMinutes * minuteFare;
        } else {
          extraMinutesCharge.value = 0;
        }
      }
      if (order.value.startKitoMetersReading != null && order.value.endKitoMetersReading != null) {
        double startKm = double.tryParse(order.value.startKitoMetersReading?.toString() ?? "0") ?? 0.0;
        double endKm = double.tryParse(order.value.endKitoMetersReading?.toString() ?? "0") ?? 0.0;
        if (endKm > startKm) {
          double totalKm = endKm - startKm;
          if (totalKm > double.parse(order.value.rentalPackageModel!.includedDistance!)) {
            totalKm = totalKm - double.parse(order.value.rentalPackageModel!.includedDistance!);
            double extraKmRate = double.tryParse(order.value.rentalPackageModel?.extraKmFare?.toString() ?? "0") ?? 0.0;
            extraKilometerCharge.value = totalKm * extraKmRate;
          }
        }
      }
      subTotal.value = subTotal.value + extraKilometerCharge.value + extraMinutesCharge.value;

      if (order.value.taxSetting != null) {
        for (var element in order.value.taxSetting!) {
          taxAmount.value += Constant.calculateTax(amount: (subTotal.value - discount.value).toString(), taxModel: element);
        }
      }

      if (order.value.adminCommission!.isNotEmpty) {
        adminCommission.value = Constant.calculateAdminCommission(
            amount: (subTotal.value - discount.value).toString(),
            adminCommissionType: order.value.adminCommissionType.toString(),
            adminCommission: order.value.adminCommission ?? '0');
      }

      totalAmount.value = (subTotal.value - discount.value) + taxAmount.value;
    } catch (e) {
      ShowToastDialog.showToast("Failed to calculate total: $e");
    }
  }

  Future<void> fetchOrder(String orderId) async {
    try {
      isLoading.value = true;
      order.value = (await FireStoreUtils.getRentalOrderById(orderId))!;

      calculateTotalAmount();
      fetchCustomerDetails();
    } catch (e) {
      ShowToastDialog.showToast("Failed to fetch order details: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchCustomerDetails() async {
    if (order.value.authorID != null) {
      final user = await FireStoreUtils.getUserProfile(order.value.authorID!);
      if (user != null) {
        userData.value = user;
      }
    }
  }
}

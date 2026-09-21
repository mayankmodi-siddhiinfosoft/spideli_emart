import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constant/constant.dart';
import '../models/parcel_category.dart';
import '../models/parcel_order_model.dart';
import '../utils/fire_store_utils.dart';

class ParcelOrderDetailsController extends GetxController {
  Rx<ParcelOrderModel> parcelOrder = ParcelOrderModel().obs;
  RxList<ParcelCategory> parcelCategory = <ParcelCategory>[].obs;
  RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args != null && args is ParcelOrderModel) {
      parcelOrder.value = args;
    }
    loadParcelCategories();
    calculateTotalAmount();
  }

  RxDouble subTotal = 0.0.obs;
  RxDouble discount = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;
  RxDouble adminCommission = 0.0.obs;

  void calculateTotalAmount() {
    taxAmount = 0.0.obs;
    discount = 0.0.obs;
    subTotal.value = double.parse(parcelOrder.value.subTotal.toString());
    discount.value = double.parse(parcelOrder.value.discount ?? '0.0');

    for (var element in parcelOrder.value.taxSetting!) {
      taxAmount.value = (taxAmount.value + Constant.calculateTax(amount: (subTotal.value - discount.value).toString(), taxModel: element));
    }

    if (parcelOrder.value.adminCommission!.isNotEmpty) {
      adminCommission.value = Constant.calculateAdminCommission(
          amount: (subTotal.value - discount.value).toString(),
          adminCommissionType: parcelOrder.value.adminCommissionType.toString(),
          adminCommission: parcelOrder.value.adminCommission ?? '0');
    }


    totalAmount.value = (subTotal.value - discount.value) + taxAmount.value;
    update();
  }

  void loadParcelCategories() async {
    isLoading.value = true;
    final categories = await FireStoreUtils.getParcelServiceCategory();
    parcelCategory.value = categories;
    isLoading.value = false;
  }

  String formatDate(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return DateFormat("dd MMM yyyy, hh:mm a").format(dateTime);
  }

  ParcelCategory? getSelectedCategory() {
    try {
      return parcelCategory.firstWhere(
            (cat) => cat.title?.toLowerCase().trim() == parcelOrder.value.parcelType?.toLowerCase().trim(),
        orElse: () => ParcelCategory(),
      );
    } catch (e) {
      return null;
    }
  }
}

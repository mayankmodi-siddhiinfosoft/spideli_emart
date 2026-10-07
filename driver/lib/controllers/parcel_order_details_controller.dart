import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constant/constant.dart';
import '../models/parcel_category.dart';
import '../models/parcel_order_model.dart';
import '../utils/fire_store_utils.dart';
import '../utils/parcel_amounts.dart';

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

  /// Bill lines the customer paid on top of the taxed fare (all 0 when
  /// absent): the platform fee and its taxes, the fixed intercity /
  /// intercountry tax and the receiver-SMS fee (point 54).
  RxDouble platformFee = 0.0.obs;
  RxDouble platformTaxAmount = 0.0.obs;
  RxDouble scopeTax = 0.0.obs;
  RxDouble smsCharge = 0.0.obs;

  /// The bill exactly as the customer was charged ([ParcelAmounts]), so the
  /// "Order Total" — the cash a driver collects — reconciles with the lines
  /// shown. Tolerant of a record without `subTotal`, taxes or commission.
  void calculateTotalAmount() {
    final ParcelAmounts amounts = ParcelAmounts.of(parcelOrder.value);
    subTotal.value = amounts.subTotal;
    discount.value = amounts.discount;
    taxAmount.value = amounts.orderTax;
    platformFee.value = amounts.platformFee;
    platformTaxAmount.value = amounts.platformTax;
    scopeTax.value = amounts.scopeTax;
    smsCharge.value = amounts.smsCharge;

    adminCommission.value = 0.0;
    final String commission = (parcelOrder.value.adminCommission ?? '').trim();
    if (commission.isNotEmpty && double.tryParse(commission) != null) {
      adminCommission.value = Constant.calculateAdminCommission(
          amount: (amounts.subTotal - amounts.discount).toString(),
          adminCommissionType: parcelOrder.value.adminCommissionType.toString(),
          adminCommission: commission);
    }

    totalAmount.value = amounts.total;
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

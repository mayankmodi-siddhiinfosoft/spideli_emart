import 'package:spideliprovider/model/coupon_model.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:get/get.dart';

class CouponController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<CouponModel> couponModel = <CouponModel>[].obs;

  @override
  void onInit() {
    getCouponData();
    super.onInit();
  }

  getCouponData() async {
    await FireStoreUtils.getCoupons().then((value) {
      couponModel.value = value;
    });

    isLoading.value = false;
    update();
  }


}

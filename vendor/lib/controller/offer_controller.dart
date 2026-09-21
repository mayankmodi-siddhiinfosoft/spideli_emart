import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/coupon_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class OfferController extends GetxController {
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getOffers();
    super.onInit();
  }

  RxList<CouponModel> offerList = <CouponModel>[].obs;

  Future<void> getOffers() async {
    print("vendor id:${Constant.userModel!.vendorID}");
    await FireStoreUtils.getOffer(Constant.userModel!.vendorID.toString()).then((value) {
      offerList.value = value;
    });
    isLoading.value = false;
  }
}

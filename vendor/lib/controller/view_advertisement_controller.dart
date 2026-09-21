import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/advertisement_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class ViewAdvertisementController extends GetxController {
  @override
  void onInit() {
    getArgument();
    // TODO: implement onInit
    super.onInit();
  }

  Rx<AdvertisementModel> advertisementModel = AdvertisementModel().obs;
  Rx<VendorModel?> vendorModel = VendorModel().obs;

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      advertisementModel.value = argumentData['advsModel'];
    }
    if (Constant.userModel?.vendorID != null) {
      vendorModel.value = await FireStoreUtils.getVendorById(Constant.userModel!.vendorID!);
    }
  }
}

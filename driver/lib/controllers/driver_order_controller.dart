import 'package:get/get.dart';

class DriverOrderListController extends GetxController {
  RxString driverId = "".obs;
  RxString serviceType = "".obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;

    if (args != null) {
      if (args['driverId'] != null) {
        driverId.value = args['driverId'];
      }
      if (args['serviceType'] != null) {
        serviceType.value = args['serviceType'];
      }
    }
  }
}

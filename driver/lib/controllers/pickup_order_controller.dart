import 'package:driver/models/order_model.dart';
import 'package:driver/utils/args.dart';
import 'package:get/get.dart';

class PickupOrderController extends GetxController {
  RxBool isLoading = true.obs;
  RxBool conformPickup = false.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getArgument();
    super.onInit();
  }

  Rx<OrderModel> orderModel = OrderModel().obs;

  void getArgument() {
    final OrderModel? passed = argOf<OrderModel>(Get.arguments, 'orderModel');
    if (passed != null) orderModel.value = passed;
    isLoading.value = false;
    update();
  }
}

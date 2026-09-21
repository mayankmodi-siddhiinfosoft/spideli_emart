import 'package:spideliprovider/model/onprovider_order_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:get/get.dart';

class AssignWorkerController extends GetxController {
  RxString selectedWorkerRadioTile = ''.obs;
  RxString fcmToken = ''.obs;
  RxBool select = false.obs;
  RxList<User> user = <User>[].obs;
  Rx<OnProviderOrderModel> onProviderOrder = OnProviderOrderModel().obs;
  @override
  void onInit() {
    getArgument();
    getData();
    super.onInit();
  }

  void getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      onProviderOrder.value = argumentData['onProviderOrder'];
    }
    update();
  }

  getData() async {
    await FireStoreUtils.getAllOnlineWorkers().then((value) {
      user.value = value;
    });
    update();
  }
}

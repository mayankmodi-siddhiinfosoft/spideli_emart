import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:get/get.dart';

class AllWorkersController extends GetxController {
  RxList<User> user = <User>[].obs;

  @override
  void onInit() {
    getData();
    super.onInit();
  }

  getData() async {
    await FireStoreUtils.getAllWorkers().then((value) {
      user.value = value;
    });
  }
}

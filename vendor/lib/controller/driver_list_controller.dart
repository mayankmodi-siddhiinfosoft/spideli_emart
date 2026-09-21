import 'package:get/get.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class DriverListController extends GetxController {
  @override
  void onInit() {
    // TODO: implement onInit
    getAllDriverList();
    super.onInit();
  }

  RxBool isLoading = true.obs;
  RxList<UserModel> driverUserList = <UserModel>[].obs;

  Future<void> getAllDriverList() async {
    await FireStoreUtils.getAllDrivers().then((value) {
      if (value.isNotEmpty == true) {
        driverUserList.value = value;
      }
    });
    isLoading.value = false;
  }

  Future<void> updateDriver(UserModel user) async {
    await FireStoreUtils.updateDriverUser(user);
  }
}

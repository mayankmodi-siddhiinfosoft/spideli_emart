import 'package:get/get.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class EmployeeListController extends GetxController {
  @override
  void onInit() {
    getAllEmployeeList();
    super.onInit();
  }

  RxBool isLoading = true.obs;
  RxList<UserModel> employeeUserList = <UserModel>[].obs;

  Future<void> getAllEmployeeList() async {
    await FireStoreUtils.getAllEmployee().then(
      (value) {
        if (value.isNotEmpty == true) {
          employeeUserList.value = value;
        }
      },
    );
    isLoading.value = false;
  }

  Future<void> updateEmployee(UserModel user) async {
    await FireStoreUtils.updateDriverUser(user);
  }
}

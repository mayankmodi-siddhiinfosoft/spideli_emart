import 'package:get/get.dart';
import 'package:vendor/models/employee_role_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class RoleController extends GetxController {
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getAllEmployeeRoles();
    super.onInit();
  }

  RxList<EmployeeRoleModel> employeeRolelList = <EmployeeRoleModel>[].obs;

  Future<void> getAllEmployeeRoles() async {
    await FireStoreUtils.getAllEmployeeRoles().then(
      (value) {
        employeeRolelList.value = value;
      },
    );
    isLoading.value = false;
  }
}

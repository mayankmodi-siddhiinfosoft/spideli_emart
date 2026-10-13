import 'package:spideliprovider/model/onprovider_order_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/worker_verification_service.dart';
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

  /// Online workers who may be given a job: with worker verification on,
  /// only those whose documents are approved (the Worker app hides the jobs
  /// of anyone else, so an assignment to them would be seen by nobody).
  getData() async {
    final List<User> online = await FireStoreUtils.getAllOnlineWorkers();
    final Set<String> allowed = await WorkerVerificationService.assignableWorkerIds(online.map((w) => (id: w.id, isDocumentVerify: w.isDocumentVerify)).toList());
    hiddenUnverified.value = online.where((w) => !allowed.contains(w.id)).length;
    user.value = online.where((w) => allowed.contains(w.id)).toList();
    update();
  }

  /// Online workers left out because their documents are not approved.
  RxInt hiddenUnverified = 0.obs;
}

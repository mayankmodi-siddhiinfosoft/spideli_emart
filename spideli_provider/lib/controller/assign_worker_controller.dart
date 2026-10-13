import 'package:spideliprovider/model/onprovider_order_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/model/worker_verification.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/worker_verification_service.dart';
import 'package:get/get.dart';

class AssignWorkerController extends GetxController {
  RxString selectedWorkerRadioTile = ''.obs;
  RxString fcmToken = ''.obs;
  RxBool select = false.obs;

  /// Every online worker of the provider; those who may not be given an
  /// order ([refusals]) are listed greyed out with the reason and cannot be
  /// selected.
  RxList<User> user = <User>[].obs;
  Rx<OnProviderOrderModel> onProviderOrder = OnProviderOrderModel().obs;

  /// Why a worker may not be assigned (absent / null = may be), from the
  /// worker's documents and the current required types
  /// ([WorkerVerificationService.assignmentRefusals]). The Assign action
  /// re-validates in its own transaction anyway.
  RxMap<String, WorkerAssignmentRefusal?> refusals = <String, WorkerAssignmentRefusal?>{}.obs;
  RxBool isLoading = true.obs;

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

  /// Whether [worker] may be selected: only when every required document is
  /// uploaded and approved (or verification is off).
  bool canAssign(User worker) => refusals.containsKey(worker.id) && refusals[worker.id] == null;

  WorkerAssignmentRefusal? refusalOf(User worker) => refusals.containsKey(worker.id) ? refusals[worker.id] : WorkerAssignmentRefusal.unknown;

  /// Online workers, assignable ones first.
  Future<void> getData() async {
    isLoading.value = true;
    update();
    final List<User> online = await FireStoreUtils.getAllOnlineWorkers();
    final Map<String, WorkerAssignmentRefusal?> result = await WorkerVerificationService.assignmentRefusals(
      online.map((w) => (id: w.id, data: <String, dynamic>{'providerId': w.providerId, 'isDocumentVerify': w.isDocumentVerify})).toList(),
    );
    refusals.value = result;
    online.sort((a, b) {
      final int ra = result[a.id] == null ? 0 : 1;
      final int rb = result[b.id] == null ? 0 : 1;
      return ra != rb ? ra.compareTo(rb) : a.fullName().toLowerCase().compareTo(b.fullName().toLowerCase());
    });
    user.value = online;
    if (selectedWorkerRadioTile.value.isNotEmpty && result[selectedWorkerRadioTile.value] != null) {
      selectedWorkerRadioTile.value = '';
      fcmToken.value = '';
    }
    isLoading.value = false;
    update();
  }

  /// Online workers who may not be assigned now.
  int get hiddenUnverified => user.where((w) => !canAssign(w)).length;
}

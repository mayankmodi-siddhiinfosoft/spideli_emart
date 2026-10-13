import 'dart:developer';

import 'package:get/get.dart';
import 'package:spideliprovider/model/document_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/model/worker_verification.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/worker_verification_service.dart';

/// The provider's own workers (`providers_workers` where `providerId` is the
/// provider) with their verification state and the counts per state.
class WorkerVerificationController extends GetxController {
  RxBool isLoading = true.obs;

  /// The workers, their documents or the required types could not be read:
  /// the screen offers a retry instead of showing states it does not know.
  RxBool loadFailed = false.obs;
  Rxn<bool> verificationRequired = Rxn<bool>();
  RxList<DocumentType> types = <DocumentType>[].obs;
  RxList<User> workers = <User>[].obs;
  RxMap<String, Map<String, UploadedDocument>> uploads = <String, Map<String, UploadedDocument>>{}.obs;

  /// null = every worker.
  Rxn<WorkerVerificationState> filter = Rxn<WorkerVerificationState>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    loadFailed.value = false;
    try {
      final results = await Future.wait([
        WorkerVerificationService.verificationRequired(),
        WorkerVerificationService.requiredTypes(),
        FireStoreUtils.getAllWorkers(),
      ]);
      verificationRequired.value = results[0] as bool?;
      final WorkerDocumentTypes t = results[1] as WorkerDocumentTypes;
      types.value = t.types;
      workers.value = results[2] as List<User>;
      uploads.value = await WorkerVerificationService.uploadsOf(workers.map((w) => w.id).toList());
      loadFailed.value = t.failed;
    } catch (e, s) {
      log('Worker verification list not loaded: $e', stackTrace: s);
      loadFailed.value = true;
    }
    isLoading.value = false;
  }

  WorkerVerificationState stateOf(User worker) => WorkerVerificationRules.stateOf(types, uploads[worker.id] ?? const {}, isDocumentVerify: worker.isDocumentVerify);

  int countOf(WorkerVerificationState state) => workers.where((w) => stateOf(w) == state).length;

  /// The filtered workers, those waiting for a review first.
  List<User> get visible {
    final list = workers.where((w) => filter.value == null || stateOf(w) == filter.value).toList();
    list.sort((a, b) => stateOf(a).index == stateOf(b).index ? a.fullName().toLowerCase().compareTo(b.fullName().toLowerCase()) : _rank(stateOf(a)).compareTo(_rank(stateOf(b))));
    return list;
  }

  static int _rank(WorkerVerificationState s) {
    switch (s) {
      case WorkerVerificationState.pendingReview:
        return 0;
      case WorkerVerificationState.rejected:
        return 1;
      case WorkerVerificationState.notSubmitted:
        return 2;
      case WorkerVerificationState.verified:
        return 3;
    }
  }
}

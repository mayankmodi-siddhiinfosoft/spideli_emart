import 'dart:async';

import 'package:get/get.dart';
import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/main.dart';
import 'package:spideliworker/model/document_model.dart';
import 'package:spideliworker/services/document_service.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/utils/region_service.dart';

/// Live verification state of the signed-in worker (spec 3.6 / 11) and the
/// worker's region (zone-bound jobs). Registered permanently by the
/// dashboard; the Jobs, Profile and Documents screens read it.
class VerificationController extends GetxController {
  RxBool isLoading = true.obs;

  /// `settings/document_verification_settings.isWorkerVerification`.
  RxBool verificationRequired = false.obs;
  RxList<DocumentModel> documentTypes = <DocumentModel>[].obs;
  Rxn<WorkerDocumentModel> uploaded = Rxn<WorkerDocumentModel>();
  Rxn<bool> isDocumentVerify = Rxn<bool>();

  StreamSubscription? _documentsSub;
  StreamSubscription? _workerSub;

  String get _uid => MyAppState.currentUser?.id ?? '';

  VerificationStatus get overallStatus => DocumentService.overallStatus(documentTypes, uploaded.value, isDocumentVerify: isDocumentVerify.value);

  /// Unverified workers do not see or accept jobs. When verification is not
  /// switched on by the admin, today's behaviour: always true.
  bool get canReceiveJobs => !verificationRequired.value || overallStatus == VerificationStatus.approved;

  VerificationStatus statusOf(DocumentModel type) => DocumentService.statusOf(uploaded.value?.documentFor(type.id));

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    if (_uid.isEmpty) {
      isLoading.value = false;
      return;
    }
    isDocumentVerify.value = MyAppState.currentUser?.isDocumentVerify;
    final results = await Future.wait([
      DocumentService.isVerificationRequired(),
      DocumentService.getDocumentTypes(),
      RegionService.ensureLoaded(),
      RegionService.resolveWorkerRegion(_uid, workerDocRegionId: MyAppState.currentUser?.regionId),
    ]);
    verificationRequired.value = results[0] as bool;
    documentTypes.value = results[1] as List<DocumentModel>;

    _documentsSub?.cancel();
    _documentsSub = DocumentService.watchWorkerDocuments(_uid).listen((value) {
      uploaded.value = value;
      isLoading.value = false;
    }, onError: (_) => isLoading.value = false);

    // The admin approves by setting providers_workers.isDocumentVerify and may
    // move the worker to another region: follow both live.
    _workerSub?.cancel();
    _workerSub = FireStoreUtils.firestore.collection(WORKERS).doc(_uid).snapshots().listen((snap) {
      final data = snap.data();
      if (data == null) return;
      isDocumentVerify.value = data['isDocumentVerify'] is bool ? data['isDocumentVerify'] : null;
      final regionId = data['regionId']?.toString();
      if (regionId != null && regionId.isNotEmpty && regionId != RegionService.workerRegionId) {
        RegionService.workerRegionId = regionId;
        update();
      }
    }, onError: (_) {});
  }

  @override
  void onClose() {
    _documentsSub?.cancel();
    _workerSub?.cancel();
    super.onClose();
  }
}

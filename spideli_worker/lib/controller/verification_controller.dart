import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/main.dart';
import 'package:spideliworker/model/document_model.dart';
import 'package:spideliworker/services/document_service.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/utils/region_service.dart';

/// Live verification state of the signed-in worker (spec 3.6 / 11) and the
/// worker's region (zone-bound jobs). Registered by the dashboard ([ensure]);
/// the Jobs, Profile and Documents screens and the job actions read it.
///
/// Everything it depends on is LIVE (Firestore listeners), so an approval or
/// rejection by the admin panel or by the worker's provider, a document type
/// added or disabled, or verification switched on or off shows at once,
/// without restarting the app; a listener that started offline catches up by
/// itself once the device is back online.
class VerificationController extends GetxController {
  /// The registered controller, created when there is none yet (a job action
  /// reached before the dashboard, e.g. from a push).
  static VerificationController ensure() => Get.isRegistered<VerificationController>() ? Get.find<VerificationController>() : Get.put(VerificationController());

  RxBool isLoading = true.obs;

  /// `settings/document_verification_settings.isWorkerVerification`; null
  /// until it is known (then treated as on, [DocumentService.canReceiveJobs]).
  Rxn<bool> verificationRequired = Rxn<bool>();
  RxList<DocumentModel> documentTypes = <DocumentModel>[].obs;

  /// The admin's document types could not be read (offline, rules): the
  /// Documents screen offers a retry instead of saying none are configured,
  /// and the job gate stays closed.
  RxBool typesLoadFailed = false.obs;
  Rxn<WorkerDocumentModel> uploaded = Rxn<WorkerDocumentModel>();
  Rxn<bool> isDocumentVerify = Rxn<bool>();

  final List<StreamSubscription> _subs = [];
  final Set<String> _pending = {};

  String get _uid => MyAppState.currentUser?.id ?? '';

  VerificationStatus get overallStatus => DocumentService.overallStatus(documentTypes, uploaded.value, isDocumentVerify: isDocumentVerify.value);

  /// Unverified workers do not see, start or get assigned jobs and cannot go
  /// online ([DocumentService.canReceiveJobs]). False while loading.
  bool get canReceiveJobs =>
      !isLoading.value &&
      DocumentService.canReceiveJobs(
        verificationRequired: verificationRequired.value,
        types: documentTypes,
        typesLoadFailed: typesLoadFailed.value,
        uploaded: uploaded.value,
        isDocumentVerify: isDocumentVerify.value,
      );

  VerificationStatus statusOf(DocumentModel type) => DocumentService.statusOf(uploaded.value?.documentFor(type.id));

  /// Waits (up to [timeout]) for the first answer of every listener. False
  /// when the state is still unknown then.
  Future<bool> whenLoaded({Duration timeout = const Duration(seconds: 15)}) async {
    if (!isLoading.value) return true;
    try {
      await isLoading.stream.firstWhere((loading) => !loading).timeout(timeout);
      return true;
    } catch (_) {
      return !isLoading.value;
    }
  }

  /// [canReceiveJobs] once the state is known; false when it cannot be known.
  Future<bool> checkCanReceiveJobs() async => await whenLoaded() && canReceiveJobs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  void _answered(String key) {
    _pending.remove(key);
    if (_pending.isEmpty) isLoading.value = false;
  }

  /// (Re)subscribes every listener: used at start and by "Retry" /
  /// pull-to-refresh.
  Future<void> load() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    if (_uid.isEmpty) {
      isLoading.value = false;
      return;
    }
    final String uid = _uid;
    isDocumentVerify.value = MyAppState.currentUser?.isDocumentVerify;
    _pending
      ..clear()
      ..addAll(['settings', 'types', 'uploads', 'worker']);
    isLoading.value = true;

    try {
      await Future.wait([
        RegionService.ensureLoaded(),
        RegionService.resolveWorkerRegion(uid, workerDocRegionId: MyAppState.currentUser?.regionId),
      ]);
    } catch (e) {
      // The region only filters offered jobs; the verification state must
      // still load.
      log('Worker region not resolved: $e');
    }

    _subs.add(DocumentService.settingsRef().snapshots(includeMetadataChanges: true).listen((snap) {
      final bool? required = DocumentService.verificationRequiredFrom(exists: snap.exists, isFromCache: snap.metadata.isFromCache, data: snap.data());
      // An empty cache answer is not an answer: the value stays unknown
      // (treated as on) until the server's arrives.
      if (required != null || !snap.metadata.isFromCache) verificationRequired.value = required;
      _answered('settings');
    }, onError: (_) => _answered('settings')));

    _subs.add(DocumentService.typesQuery().snapshots(includeMetadataChanges: true).listen((QuerySnapshot<Map<String, dynamic>> snap) {
      final bool unreadable = DocumentService.typesUnreadable(isEmpty: snap.docs.isEmpty, isFromCache: snap.metadata.isFromCache);
      typesLoadFailed.value = unreadable;
      documentTypes.value = DocumentService.documentTypesFrom(snap.docs.map((doc) => MapEntry(doc.id, doc.data())));
      _answered('types');
    }, onError: (_) {
      typesLoadFailed.value = true;
      _answered('types');
    }));

    _subs.add(DocumentService.verifyRef(uid).snapshots().listen((snap) {
      uploaded.value = snap.exists && snap.data() != null ? WorkerDocumentModel.fromJson(snap.data()!) : null;
      _answered('uploads');
    }, onError: (_) => _answered('uploads')));

    // The admin or the provider verifies by setting
    // providers_workers.isDocumentVerify, and the admin may move the worker
    // to another region: follow both live.
    _subs.add(FireStoreUtils.firestore.collection(WORKERS).doc(uid).snapshots().listen((snap) {
      final data = snap.data();
      if (data != null) {
        final bool? verified = data['isDocumentVerify'] is bool ? data['isDocumentVerify'] : null;
        isDocumentVerify.value = verified;
        MyAppState.currentUser?.isDocumentVerify = verified;
        final regionId = data['regionId']?.toString();
        if (regionId != null && regionId.isNotEmpty && regionId != RegionService.workerRegionId) {
          RegionService.workerRegionId = regionId;
          update();
        }
      }
      _answered('worker');
    }, onError: (_) => _answered('worker')));
  }

  @override
  void onClose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    super.onClose();
  }
}

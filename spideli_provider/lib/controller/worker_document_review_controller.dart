import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:spideliprovider/model/document_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/model/worker_verification.dart';
import 'package:spideliprovider/services/worker_document_push.dart';
import 'package:spideliprovider/services/worker_verification_service.dart';

/// One worker's documents, reviewed by their provider. The worker record and
/// the uploads are followed live, so a re-upload made while the screen is
/// open shows at once.
class WorkerDocumentReviewController extends GetxController {
  final String workerId;

  WorkerDocumentReviewController(this.workerId);

  RxBool isLoading = true.obs;
  RxBool busy = false.obs;

  /// The required types could not be read: no action is offered.
  RxBool typesLoadFailed = false.obs;

  /// The worker does not exist or is not this provider's worker.
  RxBool notYourWorker = false.obs;
  Rxn<User> worker = Rxn<User>();
  RxList<DocumentType> types = <DocumentType>[].obs;
  RxMap<String, UploadedDocument> uploads = <String, UploadedDocument>{}.obs;

  final List<StreamSubscription> _subs = [];
  bool _workerRead = false;
  bool _uploadsRead = false;
  bool _typesRead = false;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  void _settle() {
    if (_workerRead && _uploadsRead && _typesRead) isLoading.value = false;
  }

  Future<void> load() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _workerRead = _uploadsRead = _typesRead = false;
    isLoading.value = true;
    _subs.add(WorkerVerificationService.workerRef(workerId).snapshots().listen((snap) {
      final data = snap.data();
      notYourWorker.value = !WorkerVerificationRules.canReview(data, WorkerVerificationService.providerId);
      worker.value = data == null ? null : User.fromJson(data);
      _workerRead = true;
      _settle();
    }, onError: (_) {
      notYourWorker.value = true;
      _workerRead = true;
      _settle();
    }));
    _subs.add(WorkerVerificationService.verifyRef(workerId).snapshots().listen((snap) {
      uploads.value = WorkerVerificationRules.uploadsFrom(snap.data()?['documents']);
      _uploadsRead = true;
      _settle();
    }, onError: (_) {
      _uploadsRead = true;
      _settle();
    }));
    final WorkerDocumentTypes t = await WorkerVerificationService.requiredTypes();
    types.value = t.types;
    typesLoadFailed.value = t.failed;
    _typesRead = true;
    _settle();
  }

  DocumentStatus statusOf(DocumentType type) => WorkerVerificationRules.statusOf(uploads[type.id]);

  WorkerVerificationState get state => WorkerVerificationRules.stateOf(types, uploads, isDocumentVerify: worker.value?.isDocumentVerify);

  List<DocumentType> get missing => WorkerVerificationRules.missing(types, uploads);

  /// At least one required document waits for a decision.
  bool get hasPending => types.any((t) => statusOf(t) == DocumentStatus.pendingReview);

  bool get canAct => !isLoading.value && !busy.value && !notYourWorker.value && !typesLoadFailed.value;

  Future<WorkerReviewResult> _run(WorkerReviewAction action, WorkerReviewOutcome Function(dynamic stored, String reviewerId, Timestamp at) plan, {String reason = ''}) async {
    busy.value = true;
    try {
      return await WorkerVerificationService.review(
        workerId: workerId,
        action: action,
        types: types.toList(),
        reason: reason,
        plan: plan,
      );
    } finally {
      busy.value = false;
    }
  }

  Future<WorkerReviewResult> approve(DocumentType type) => _run(
        WorkerReviewAction.approve,
        (stored, reviewerId, at) => WorkerVerificationRules.approve(types: types.toList(), stored: stored, documentId: type.id, reviewerId: reviewerId, at: at),
      );

  Future<WorkerReviewResult> reject(DocumentType type, String reason) => _run(
        WorkerReviewAction.reject,
        (stored, reviewerId, at) => WorkerVerificationRules.reject(types: types.toList(), stored: stored, documentId: type.id, reason: reason, reviewerId: reviewerId, at: at),
        reason: reason,
      );

  Future<WorkerReviewResult> approveAll() => _run(
        WorkerReviewAction.approveAll,
        (stored, reviewerId, at) => WorkerVerificationRules.approveAll(types: types.toList(), stored: stored, reviewerId: reviewerId, at: at),
      );

  @override
  void onClose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.onClose();
  }
}

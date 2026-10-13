import 'dart:async';
import 'dart:developer';

import 'package:get/get.dart';
import 'package:spideliprovider/model/document_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/model/worker_verification.dart';
import 'package:spideliprovider/services/worker_verification_service.dart';

/// The provider's own workers (`providers_workers` where `providerId` is the
/// provider) with their overall verification status (Not submitted / Pending
/// / Action required / Verified) and the counts per status.
///
/// Everything is LIVE (Firestore listeners): the workers, their
/// `documents_verify` records (worker records only), the required types and
/// the verification setting, so a worker's upload or a decision taken here
/// or in the admin panel shows at once.
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
  Rxn<WorkerOverallStatus> filter = Rxn<WorkerOverallStatus>();

  final List<StreamSubscription> _subs = [];
  final List<StreamSubscription> _uploadSubs = [];
  final Map<int, Map<String, Map<String, UploadedDocument>>> _chunks = {};
  final Set<String> _pending = {};
  final Set<String> _errors = {};
  bool _typesFailed = false;
  List<String> _watchedIds = const [];

  @override
  void onInit() {
    super.onInit();
    load();
  }

  void _answered(String key, {bool ok = true}) {
    if (ok) _errors.remove(key);
    loadFailed.value = _errors.isNotEmpty || _typesFailed;
    _pending.remove(key);
    if (_pending.isEmpty) isLoading.value = false;
  }

  void _failed(String key, Object e) {
    log('Worker verification list: $key not read: $e');
    _errors.add(key);
    _answered(key, ok: false);
  }

  /// (Re)subscribes every listener: at start and by "Retry" /
  /// pull-to-refresh.
  Future<void> load() async {
    await _cancel(_subs);
    await _cancel(_uploadSubs);
    _chunks.clear();
    _watchedIds = const [];
    _errors.clear();
    _typesFailed = false;
    loadFailed.value = false;
    isLoading.value = true;
    _pending
      ..clear()
      ..addAll(['settings', 'types', 'workers']);

    _subs.add(WorkerVerificationService.verificationRequiredStream().listen((required) {
      if (required != null || verificationRequired.value == null) verificationRequired.value = required;
      _answered('settings');
    }, onError: (e) => _answered('settings')));

    _subs.add(WorkerVerificationService.requiredTypesStream().listen((t) {
      // A cache miss after a good read keeps the types already known.
      if (!(t.failed && types.isNotEmpty)) {
        types.value = t.types;
        _typesFailed = t.failed;
      }
      _answered('types');
    }, onError: (e) => _failed('types', e)));

    _subs.add(WorkerVerificationService.myWorkersQuery().snapshots().listen((snap) {
      final List<User> list = [];
      for (final doc in snap.docs) {
        try {
          list.add(User.fromJson(doc.data()));
        } catch (e) {
          log('Worker ${doc.id} not parsed: $e');
        }
      }
      workers.value = list;
      _watchUploads(list.map((w) => w.id).where((id) => id.trim().isNotEmpty && !id.contains('/')).toSet().toList()..sort());
      _answered('workers');
    }, onError: (e) => _failed('workers', e)));
  }

  /// Follows `documents_verify` of [ids], 30 per listener (Firestore's
  /// `whereIn` limit); resubscribes only when the set of workers changes.
  void _watchUploads(List<String> ids) {
    if (_listEquals(ids, _watchedIds)) return;
    _watchedIds = ids;
    _cancel(_uploadSubs);
    _chunks.clear();
    _errors.removeWhere((k) => k.startsWith('uploads'));
    if (ids.isEmpty) {
      uploads.value = {};
      return;
    }
    for (int i = 0, chunk = 0; i < ids.length; i += 30, chunk++) {
      final List<String> part = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final String key = 'uploads$chunk';
      final int index = chunk;
      _pending.add(key);
      isLoading.value = true;
      _uploadSubs.add(WorkerVerificationService.uploadsStream(part).listen((map) {
        _chunks[index] = map;
        uploads.value = {for (final c in _chunks.values) ...c};
        _answered(key);
      }, onError: (e) => _failed(key, e)));
    }
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static Future<void> _cancel(List<StreamSubscription> subs) async {
    final copy = List<StreamSubscription>.from(subs);
    subs.clear();
    for (final s in copy) {
      await s.cancel();
    }
  }

  /// The worker's overall status, computed from the REQUIRED documents
  /// ([WorkerVerificationRules.overall]).
  WorkerOverallStatus stateOf(User worker) => statusOfId(worker.id, isDocumentVerify: worker.isDocumentVerify);

  WorkerOverallStatus statusOfId(String workerId, {bool? isDocumentVerify}) =>
      WorkerVerificationRules.overall(types, uploads[workerId] ?? const {}, isDocumentVerify: isDocumentVerify, verificationRequired: verificationRequired.value);

  int countOf(WorkerOverallStatus state) => workers.where((w) => stateOf(w) == state).length;

  /// The filtered workers: action required and pending first.
  List<User> get visible {
    final list = workers.where((w) => filter.value == null || stateOf(w) == filter.value).toList();
    list.sort((a, b) => stateOf(a) == stateOf(b) ? a.fullName().toLowerCase().compareTo(b.fullName().toLowerCase()) : rank(stateOf(a)).compareTo(rank(stateOf(b))));
    return list;
  }

  /// List order: what needs the provider's attention first.
  static int rank(WorkerOverallStatus s) {
    switch (s) {
      case WorkerOverallStatus.pending:
        return 0;
      case WorkerOverallStatus.actionRequired:
        return 1;
      case WorkerOverallStatus.notSubmitted:
        return 2;
      case WorkerOverallStatus.verified:
        return 3;
    }
  }

  @override
  void onClose() {
    _cancel(_subs);
    _cancel(_uploadSubs);
    super.onClose();
  }
}

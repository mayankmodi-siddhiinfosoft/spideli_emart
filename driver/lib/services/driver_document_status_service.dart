import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/models/document_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/driver_document_status.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore side of [DriverDocumentStatus]: reads a driver's required
/// documents and `documents_verify/{uid}` record, computes the overall
/// status and keeps [DocumentStatusCache] up to date — once ([refresh], used
/// by the jobs gates right before they decide) or live ([watch], used by
/// the documents screens; [startOwn] for the signed-in driver).
abstract final class DriverDocumentStatusService {
  static FirebaseFirestore get _db => FireStoreUtils.fireStore;

  /// Reads and caches the overall status of a COMPANY driver (null for
  /// anyone else, and when a read fails: the cached value / flag stays).
  static Future<DocumentOverallStatus?> refresh(UserModel? user) async {
    final String uid = (user?.id ?? '').trim();
    if (uid.isEmpty || !DriverDocumentStatus.isCompanyDriver(user)) return null;
    try {
      final List<DocumentModel> required = await FireStoreUtils.getDocumentListForTypes(FireStoreUtils.documentTypesFor(user), throwOnError: true);
      final DocumentSnapshot<Map<String, dynamic>> snap = await _db.collection(CollectionName.documentsVerify).doc(uid).get();
      final DocumentOverallStatus status = DriverDocumentsView.of(user: user, required: required, record: snap.exists ? snap.data() : null).overall;
      DocumentStatusCache.put(uid, status);
      return status;
    } catch (e) {
      log("Document status of $uid not computed: $e");
      return null;
    }
  }

  /// [refresh] for several drivers (the owner's assignment list); one
  /// required-documents read per distinct set of document types.
  static Future<void> refreshAll(Iterable<UserModel> users) async {
    final Map<String, Future<List<DocumentModel>>> byTypes = {};
    await Future.wait(users.where(DriverDocumentStatus.isCompanyDriver).map((user) async {
      final String uid = (user.id ?? '').trim();
      if (uid.isEmpty) return;
      try {
        final List<String> types = FireStoreUtils.documentTypesFor(user);
        final List<DocumentModel> required = await (byTypes[types.join(',')] ??= FireStoreUtils.getDocumentListForTypes(types, throwOnError: true));
        final DocumentSnapshot<Map<String, dynamic>> snap = await _db.collection(CollectionName.documentsVerify).doc(uid).get();
        DocumentStatusCache.put(uid, DriverDocumentsView.of(user: user, required: required, record: snap.exists ? snap.data() : null).overall);
      } catch (e) {
        log("Document status of $uid not computed: $e");
      }
    }));
  }

  /// [uid]'s documents, live: a new [DriverDocumentsView] whenever
  /// `users/{uid}` or `documents_verify/{uid}` changes (the required list is
  /// read again when the driver's document types change). A failed read is
  /// an error event; the stream keeps listening.
  static Stream<DriverDocumentsView> watch(String uid) {
    final String id = uid.trim();
    late final StreamController<DriverDocumentsView> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? recordSub;
    Map<String, dynamic>? userData;
    Map<String, dynamic>? record;
    bool userSeen = false;
    bool recordSeen = false;
    List<DocumentModel> required = const [];
    String? typesKey;
    Future<void> chain = Future<void>.value();

    Future<void> emit() async {
      if (!userSeen || !recordSeen || controller.isClosed) return;
      final UserModel? user = userData == null ? null : UserModel.fromJson({...userData!, 'id': id});
      final List<String> types = FireStoreUtils.documentTypesFor(user);
      final String key = types.join(',');
      if (key != typesKey) {
        try {
          required = await FireStoreUtils.getDocumentListForTypes(types, throwOnError: true);
          typesKey = key;
        } catch (e) {
          if (!controller.isClosed) controller.addError(e);
          return;
        }
      }
      final DriverDocumentsView view = DriverDocumentsView.of(user: user, required: required, record: record);
      if (DriverDocumentStatus.isCompanyDriver(user)) DocumentStatusCache.put(id, view.overall);
      if (!controller.isClosed) controller.add(view);
    }

    void schedule() => chain = chain.then((_) => emit());

    controller = StreamController<DriverDocumentsView>(
      onListen: () {
        if (id.isEmpty) {
          controller.addError(StateError('No driver'));
          return;
        }
        userSub = _db.collection(CollectionName.users).doc(id).snapshots().listen((snap) {
          userData = snap.exists ? snap.data() : null;
          userSeen = true;
          schedule();
        }, onError: controller.addError);
        recordSub = _db.collection(CollectionName.documentsVerify).doc(id).snapshots().listen((snap) {
          record = snap.exists ? snap.data() : null;
          recordSeen = true;
          schedule();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await userSub?.cancel();
        await recordSub?.cancel();
      },
    );
    return controller.stream;
  }

  // ── The signed-in driver ──────────────────────────────────────────────────

  static String? _ownUid;
  static StreamSubscription<DriverDocumentsView>? _ownSub;

  /// Keeps the signed-in driver's status in [DocumentStatusCache] live, so
  /// every synchronous gate and home screen uses the computed status
  /// (idempotent; started with the online status by every dashboard).
  static void startOwn() {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    if (_ownUid == uid && _ownSub != null) return;
    _ownSub?.cancel();
    _ownUid = uid;
    _ownSub = watch(uid).listen((_) {}, onError: (Object e) => log("Own document status: $e"));
  }

  /// Stops following (log-out, account deletion).
  static Future<void> stopOwn() async {
    final StreamSubscription<DriverDocumentsView>? sub = _ownSub;
    _ownSub = null;
    _ownUid = null;
    await sub?.cancel();
  }

  /// Forgets every computed status (signed out).
  static Future<void> reset() async {
    await stopOwn();
    DocumentStatusCache.clear();
  }
}

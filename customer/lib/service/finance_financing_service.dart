import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/service/finance_region_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/utils/finance_financing_rules.dart';
import 'package:customer/utils/finance_region_rules.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Project financing for the customer app (.claude/FINANCE-DIRECT-FIRESTORE.md
/// section 3.11). The owner writes their projects, applications and
/// documents directly to Firestore (the plans of [FinancingPlans], checked
/// by the security rules); documents go to Storage first
/// (`financing_documents/{uid}/{applicationId}/…`). The ADMIN reviews:
/// statuses, `reason`, document notes and `financing_reviews`.
///
/// A refusal of the rules becomes `FinanceException('permission_denied')`.
abstract final class FinanceFinancingService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get _uid => FinanceService.uid;

  static Stream<List<Map<String, dynamic>>> _list(Query<Map<String, dynamic>> q) => q.snapshots().map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

  static Stream<Map<String, dynamic>?> _doc(String collection, String id) =>
      _db.collection(collection).doc(id).snapshots().map((s) => s.data() == null ? null : {...s.data()!, 'id': s.id});

  /// The financing settings of the customer's Finance region
  /// (`finance_settings/{regionId}_financing`), or null.
  static Future<FinancingConfig?> config({String? regionId}) async => FinancingConfig.parse(await FinanceRegion.settings(FinanceModules.financing, regionId: regionId));

  static Stream<List<Map<String, dynamic>>> projects() => _list(_db.collection('financing_projects').where('ownerId', isEqualTo: _uid).orderBy('createdAt', descending: true).limit(20));

  static Stream<List<Map<String, dynamic>>> applications() =>
      _list(_db.collection('financing_applications').where('ownerId', isEqualTo: _uid).orderBy('createdAt', descending: true).limit(50));

  static Stream<Map<String, dynamic>?> application(String id) => _doc('financing_applications', id);

  static Query<Map<String, dynamic>> _documents(String applicationId) =>
      _db.collection('financing_documents').where('ownerId', isEqualTo: _uid).where('applicationId', isEqualTo: applicationId).orderBy('uploadedAt', descending: true);

  static Stream<List<Map<String, dynamic>>> documents(String applicationId) => _list(_documents(applicationId));

  /// The review history the owner may see (`publicNote` only).
  static Stream<List<Map<String, dynamic>>> reviews(String applicationId) => _list(_db
      .collection('financing_reviews')
      .where('ownerId', isEqualTo: _uid)
      .where('applicationId', isEqualTo: applicationId)
      .orderBy('at', descending: true));

  static Stream<List<Map<String, dynamic>>> resources() => _db.collection('financial_resources').where('published', isEqualTo: true).limit(200).snapshots().map((s) {
        final docs = s.docs.map((d) => {...d.data(), 'id': d.id}).toList()
          ..sort((a, b) {
            final int o = _order(a).compareTo(_order(b));
            return o != 0 ? o : '${a['title']}'.compareTo('${b['title']}');
          });
        return docs;
      });

  // ── Owner's writes ────────────────────────────────────────────────────

  /// A new id for a project or an application: kept by the form, so a
  /// retry writes the same document instead of a second one.
  static String newProjectId() => _db.collection('financing_projects').doc().id;

  static String newApplicationId() => _db.collection('financing_applications').doc().id;

  /// Creates the project [projectId] ([isNew]) or saves the owner's edit.
  static Future<void> saveProject(String projectId, Map<String, dynamic> fields, {required bool isNew}) => _guard(() async {
        final String uid = _signedIn();
        // A new project already written by a first attempt is edited instead.
        final bool exists = isNew && await _existing('financing_projects/$projectId') != null;
        // A new project is made in the customer's Finance region (its sectors and stages).
        final String? regionId = isNew && !exists ? await FinanceRegion.require() : null;
        await _commit(FinanceRegion.stamp(FinancingPlans.saveProject(projectId: projectId, uid: uid, isNew: isNew && !exists, fields: fields), regionId));
      });

  /// Creates the draft [applicationId] for the owner's project `projectId`
  /// (in [fields]); a retry after a lost answer finds it written.
  static Future<void> createApplication(String applicationId, Map<String, dynamic> fields) => _guard(() async {
        final String uid = _signedIn();
        if (await _existing('financing_applications/$applicationId') != null) return;
        final String projectId = fields['projectId'].toString();
        final project = (await _db.collection('financing_projects').doc(projectId).get()).data();
        if (project == null || project['ownerId'] != uid) throw const FinanceException('permission_denied');
        final String regionId = await FinanceRegion.require();
        await _commit(FinanceRegion.stamp(FinancingPlans.createApplication(
          applicationId: applicationId,
          uid: uid,
          projectId: projectId,
          projectName: project['name']?.toString() ?? '',
          fields: fields,
        ), regionId));
      });

  static Future<Map<String, dynamic>> _application(String applicationId) async {
    final a = (await _db.collection('financing_applications').doc(applicationId).get()).data();
    if (a == null) throw const FinanceException('financing_not_editable');
    return a;
  }

  /// The owner's edit while `draft` / `additional_info_required`.
  static Future<void> updateApplication(String applicationId, Map<String, dynamic> fields) => _guard(() async {
        _signedIn();
        final String? problem = FinancingChecks.edit((await _application(applicationId))['status']?.toString());
        if (problem != null) throw FinanceException(problem);
        await _commit(FinancingPlans.updateApplication(applicationId, fields));
      });

  /// Uploads a document to `financing_documents/{uid}/{applicationId}/`
  /// (never overwritten), then records it on the application.
  static Future<void> addDocument({
    required String applicationId,
    required String type,
    required String name,
    required String contentType,
    required int size,
    String? path,
    Uint8List? bytes,
  }) =>
      _guard(() async {
        final String uid = _signedIn();
        final String? problem = FinancingChecks.edit((await _application(applicationId))['status']?.toString());
        if (problem != null) throw FinanceException(problem);
        final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        final storagePath = 'financing_documents/$uid/$applicationId/${DateTime.now().millisecondsSinceEpoch}-$safe';
        final ref = FirebaseStorage.instance.ref(storagePath);
        final meta = SettableMetadata(contentType: contentType);
        if (path != null) {
          await ref.putFile(File(path), meta);
        } else {
          await ref.putData(bytes!, meta);
        }
        await _commit(FinancingPlans.addDocument(
          documentId: _db.collection('financing_documents').doc().id,
          uid: uid,
          applicationId: applicationId,
          type: type,
          name: name,
          storagePath: storagePath,
          contentType: contentType,
          size: size,
        ));
      });

  /// Removes a document while the application is editable (and its file,
  /// when Storage lets the owner delete it).
  static Future<void> removeDocument(String documentId) => _guard(() async {
        _signedIn();
        final d = await _existing('financing_documents/$documentId');
        if (d == null) return;
        final String? problem = FinancingChecks.edit((await _application(d['applicationId'].toString()))['status']?.toString());
        if (problem != null) throw FinanceException(problem);
        await _commit(FinancingPlans.removeDocument(documentId));
        final String path = (d['storagePath'] ?? '').toString();
        if (path.isNotEmpty) {
          try {
            await FirebaseStorage.instance.ref(path).delete();
          } catch (_) {
            // The file stays for the admin to clean up; the document is gone.
          }
        }
      });

  /// Submits (or sends back after a request for information, with
  /// [message]) once every required document of [config] is there.
  static Future<void> submit(String applicationId, String message, FinancingConfig config) => _guard(() async {
        _signedIn();
        final a = await _application(applicationId);
        final docs = (await _documents(applicationId).get()).docs.map((d) => d.data()).toList();
        final missing = missingDocuments(config.requiredFor(a['financingType']?.toString() ?? ''), docs);
        final String? problem = FinancingChecks.submit(a['status']?.toString(), missing);
        if (problem != null) throw FinanceException(problem);
        await _commit(FinancingPlans.submit(applicationId, message: message));
      });

  static Future<void> withdraw(String applicationId) => _guard(() async {
        _signedIn();
        final a = await _application(applicationId);
        if (a['status'] == 'withdrawn') return;
        final String? problem = FinancingChecks.withdraw(a['status']?.toString());
        if (problem != null) throw FinanceException(problem);
        await _commit(FinancingPlans.withdraw(applicationId));
      });

  /// Opens one of the owner's documents or a resource file.
  static Future<void> open({String? storagePath, String? url}) async {
    final String link = storagePath != null ? await FirebaseStorage.instance.ref(storagePath).getDownloadURL() : url!;
    await Constant().launchURL(Uri.parse(link));
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  static String _signedIn() {
    final String uid = _uid;
    if (uid.isEmpty) throw const FinanceException('sign_in_required');
    return uid;
  }

  /// The document at [path], or null when it does not exist (the rules
  /// cannot let its owner read a document before it exists).
  static Future<Map<String, dynamic>?> _existing(String path) async {
    try {
      return (await _db.doc(path).get()).data();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// [writes] in one batch (`delete` included).
  static Future<void> _commit(List<FinanceWrite> writes) async {
    final batch = _db.batch();
    for (final w in writes) {
      final ref = _db.doc(w.path);
      switch (w.op) {
        case 'create':
          batch.set(ref, w.data);
        case 'update':
          batch.update(ref, w.data);
        case 'delete':
          batch.delete(ref);
        default:
          batch.set(ref, w.data, SetOptions(merge: true));
      }
    }
    await batch.commit();
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e, st) {
      if (e.code == 'permission-denied') Error.throwWithStackTrace(const FinanceException('permission_denied'), st);
      rethrow;
    }
  }
}

/// The admin's display order (`order`, lowest first; unset last).
int _order(Map<String, dynamic> m) => m['order'] is num ? (m['order'] as num).toInt() : 1 << 30;

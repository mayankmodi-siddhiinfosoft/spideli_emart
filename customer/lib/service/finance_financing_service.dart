import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/utils/finance_financing_rules.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Project financing for the customer app (.claude/FINANCE-APP-CONTRACT.md
/// section 16). Reads the owner's projects, applications, documents and
/// review history; every change is a request to a callable function. The
/// only client write is the document upload to the owner's own folder.
abstract final class FinanceFinancingService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get _uid => FinanceService.uid;

  static Stream<List<Map<String, dynamic>>> _list(Query<Map<String, dynamic>> q) => q.snapshots().map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

  static Stream<Map<String, dynamic>?> _doc(String collection, String id) =>
      _db.collection(collection).doc(id).snapshots().map((s) => s.data() == null ? null : {...s.data()!, 'id': s.id});

  static Future<FinancingConfig?> config() async => FinancingConfig.parse((await _db.collection('platform_settings').doc('financing').get()).data());

  static Stream<List<Map<String, dynamic>>> projects() => _list(_db.collection('financing_projects').where('ownerId', isEqualTo: _uid).orderBy('createdAt', descending: true).limit(20));

  static Stream<List<Map<String, dynamic>>> applications() =>
      _list(_db.collection('financing_applications').where('ownerId', isEqualTo: _uid).orderBy('createdAt', descending: true).limit(50));

  static Stream<Map<String, dynamic>?> application(String id) => _doc('financing_applications', id);

  static Stream<List<Map<String, dynamic>>> documents(String applicationId) => _list(_db
      .collection('financing_documents')
      .where('ownerId', isEqualTo: _uid)
      .where('applicationId', isEqualTo: applicationId)
      .orderBy('uploadedAt', descending: true));

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

  /// Creates or updates a project; returns its id.
  static Future<String> saveProject(String? projectId, Map<String, dynamic> fields) async {
    final r = await FinanceService.call('financingSaveProject', {'projectId': ?projectId, ...fields});
    return (r['projectId'] ?? projectId).toString();
  }

  /// Creates a draft application; returns its id.
  static Future<String> createApplication(Map<String, dynamic> fields) async {
    final r = await FinanceService.call('financingCreateApplication', fields);
    return r['applicationId'].toString();
  }

  static Future<void> updateApplication(String applicationId, Map<String, dynamic> fields) =>
      FinanceService.call('financingUpdateApplication', {'applicationId': applicationId, ...fields});

  /// Uploads a document to financing_documents/{uid}/{applicationId}/ and registers it.
  static Future<void> addDocument({
    required String applicationId,
    required String type,
    required String name,
    required String contentType,
    required int size,
    String? path,
    Uint8List? bytes,
  }) async {
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final storagePath = 'financing_documents/$_uid/$applicationId/${DateTime.now().millisecondsSinceEpoch}-$safe';
    final ref = FirebaseStorage.instance.ref(storagePath);
    final meta = SettableMetadata(contentType: contentType);
    if (path != null) {
      await ref.putFile(File(path), meta);
    } else {
      await ref.putData(bytes!, meta);
    }
    await FinanceService.call('financingRegisterDocument', {
      'applicationId': applicationId,
      'type': type,
      'name': name,
      'storagePath': storagePath,
      'contentType': contentType,
      'size': size,
    });
  }

  static Future<void> removeDocument(String documentId) => FinanceService.call('financingRemoveDocument', {'documentId': documentId});

  /// Submits (or re-submits after a request for information, with [message]).
  static Future<void> submit(String applicationId, String message) =>
      FinanceService.call('financingSubmit', {'applicationId': applicationId, 'declarationAccepted': true, if (message.isNotEmpty) 'message': message});

  static Future<void> withdraw(String applicationId) => FinanceService.call('financingWithdraw', {'applicationId': applicationId});

  /// Opens one of the owner's documents or a resource file.
  static Future<void> open({String? storagePath, String? url}) async {
    final String link = storagePath != null ? await FirebaseStorage.instance.ref(storagePath).getDownloadURL() : url!;
    await Constant().launchURL(Uri.parse(link));
  }
}

/// The admin's display order (`order`, lowest first; unset last).
int _order(Map<String, dynamic> m) => m['order'] is num ? (m['order'] as num).toInt() : 1 << 30;

/// Spideli Finance > Identity verification (KYC): what the customer app
/// writes to Firestore itself (.claude/FINANCE-DIRECT-FIRESTORE.md 3.1), as
/// pure write plans the security rules check. The reviewer's steps
/// (`submitted -> under_review -> additional_info_required | approved |
/// rejected`, document decisions, `users/{uid}.kycLevel`) are the admin
/// panel's. Unit tested in test/finance_kyc_direct_test.dart.
library;

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/utils/finance_rules.dart';

abstract final class KycWrites {
  /// The fields of the details form the app keeps (anything else is dropped).
  static const List<String> personalFields = ['fullName', 'dateOfBirth', 'nationality', 'idNumber', 'address', 'city', 'country'];
  static const List<String> businessFields = ['companyName', 'registrationNumber', 'taxNumber', 'registeredAddress', 'country'];

  /// The longest value of one field.
  static const int maxFieldLength = 200;

  /// The status the app shows for the user's verification: that of the
  /// latest application (newest `createdAt`; one being created, without a
  /// server time yet, is the newest). Null without any application.
  /// `users/{uid}.kycStatus` is the admin's mirror and no longer read.
  static String? latestStatus(List<Map<String, dynamic>> apps) {
    Map<String, dynamic>? latest;
    int latestAt = -1;
    for (final a in apps) {
      final v = a['createdAt'];
      final int at = v is Timestamp ? v.millisecondsSinceEpoch : (v == null ? 1 << 52 : 0);
      if (at > latestAt) {
        latest = a;
        latestAt = at;
      }
    }
    final s = latest?['status']?.toString();
    return s == null || s.isEmpty ? null : s;
  }

  /// Why a new application of [level] cannot be started: an open one exists
  /// (one at a time), the level is approved, or it is not offered to
  /// [accountType]. Null when it can.
  static String? createBlocker(List<Map<String, dynamic>> apps, KycSettings settings, String level, String accountType) {
    final lvl = settings.levels[level];
    if (lvl == null || !lvl.accountTypes.contains(accountType)) return 'kyc_not_configured';
    if (apps.any((a) => KycStatus.isOpen(a['status']?.toString()))) return 'kyc_application_open';
    if (apps.any((a) => a['level'] == level && a['status'] == KycStatus.approved)) return 'kyc_level_approved';
    return null;
  }

  /// A new application, `draft`, revision 1.
  static List<FinanceWrite> create({required String applicationId, required String uid, required String level, required String accountType}) => [
        FinanceWrite('kyc_applications/$applicationId', 'create', {
          'id': applicationId,
          'userId': uid,
          'level': level,
          'accountType': accountType,
          'status': KycStatus.draft,
          'revision': 1,
          'personal': <String, dynamic>{},
          if (accountType == 'business') 'business': <String, dynamic>{},
          'reason': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      ];

  /// Only the known fields, trimmed and capped; empty ones are left out.
  static Map<String, String> clean(Map<String, String> values, List<String> known) => {
        for (final f in known)
          if ((values[f] ?? '').trim().isNotEmpty) f: _cap(values[f]!.trim()),
      };

  static String _cap(String s) => s.length > maxFieldLength ? s.substring(0, maxFieldLength) : s;

  /// The details of an editable application (`draft` or
  /// `additional_info_required`); each group replaces the stored one.
  static List<FinanceWrite> updateDetails({required String applicationId, Map<String, String>? personal, Map<String, String>? business}) => [
        FinanceWrite('kyc_applications/$applicationId', 'update', {
          if (personal != null) 'personal': clean(personal, personalFields),
          if (business != null) 'business': clean(business, businessFields),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      ];

  /// The Storage path of an upload: `kyc/{uid}/{applicationId}/{type}-{side}-{epochMillis}.jpg`
  /// (a new name each time: nothing is overwritten).
  static String storagePath(String uid, String applicationId, String type, String side, int millis) => 'kyc/$uid/$applicationId/$type-$side-$millis.jpg';

  /// The id of the `kyc_documents` record of an upload.
  static String documentId(String applicationId, String type, String side, int millis) => '${applicationId}_${type}_${side}_$millis';

  /// The earlier uploads of the same type and side that a new one replaces
  /// (every one not already superseded).
  static List<String> toSupersede(List<Map<String, dynamic>> docs, String type, String side, {String? except}) => [
        for (final d in docs)
          if (d['type'] == type && d['side'] == side && d['status'] != 'superseded' && (d['id'] ?? '') != (except ?? '') && (d['id'] ?? '').toString().isNotEmpty)
            d['id'].toString(),
      ];

  /// The record of an uploaded file (`uploaded`), and each earlier upload of
  /// the same type and side set to `superseded`.
  static List<FinanceWrite> registerDocument({
    required String documentId,
    required String applicationId,
    required String uid,
    required String type,
    required String side,
    required String storagePath,
    required String contentType,
    required int size,
    required int revision,
    List<String> supersede = const [],
  }) =>
      [
        FinanceWrite('kyc_documents/$documentId', 'create', {
          'id': documentId,
          'applicationId': applicationId,
          'userId': uid,
          'type': type,
          'side': side,
          'status': 'uploaded',
          'storagePath': storagePath,
          'contentType': contentType,
          'size': size,
          'revision': revision,
          'createdAt': FieldValue.serverTimestamp(),
        }),
        for (final id in supersede)
          if (id != documentId)
            FinanceWrite('kyc_documents/$id', 'update', {
              'status': 'superseded',
              'supersededBy': documentId,
              'updatedAt': FieldValue.serverTimestamp(),
            }),
      ];

  /// Why [app] cannot be submitted (a `FinanceErrors` key), or null: it must
  /// be editable, have a full name (and the company's name and registration
  /// number for a business), and every required document group.
  static String? submitBlocker(Map<String, dynamic> app, KycSettings settings, List<KycDocumentRef> docs) {
    if (!KycStatus.ownerMayEdit(app['status']?.toString())) return 'kyc_invalid_transition';
    String of(String group, String f) => (((app[group] as Map?) ?? const {})[f] ?? '').toString().trim();
    if (of('personal', 'fullName').isEmpty) return 'kyc_personal_details_missing';
    if (app['accountType'] == 'business' && (of('business', 'companyName').isEmpty || of('business', 'registrationNumber').isEmpty)) {
      return 'kyc_business_details_missing';
    }
    if (settings.levels[app['level']?.toString()] == null) return 'kyc_not_configured';
    if (settings.missingGroups(app['level'].toString(), docs).isNotEmpty) return 'kyc_documents_missing';
    return null;
  }

  /// Submit: `status -> submitted`, `submittedAt`, and the history entry.
  static List<FinanceWrite> submit({required String applicationId, required String uid, required String reviewId, required int revision}) => [
        FinanceWrite('kyc_applications/$applicationId', 'update', {
          'status': KycStatus.submitted,
          'submittedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        _review(reviewId, applicationId, uid, 'submit'),
      ];

  /// Start again after `rejected`: `draft`, the next revision, no reason.
  static List<FinanceWrite> reopen({required String applicationId, required String uid, required String reviewId, required int revision}) => [
        FinanceWrite('kyc_applications/$applicationId', 'update', {
          'status': KycStatus.draft,
          'revision': revision + 1,
          'reason': null,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
        _review(reviewId, applicationId, uid, 'reopen'),
      ];

  static FinanceWrite _review(String id, String applicationId, String uid, String action) => FinanceWrite('kyc_reviews/$id', 'create', {
        'id': id,
        'applicationId': applicationId,
        'userId': uid,
        'action': action,
        'reason': null,
        'at': FieldValue.serverTimestamp(),
      });
}

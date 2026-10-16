/// Spideli Finance: project financing, the pure rules and write plans the
/// screens use (.claude/FINANCE-DIRECT-FIRESTORE.md section 3.11,
/// .claude/FINANCE-APP-CONTRACT.md section 16). Unit tested in
/// test/finance_financing_rules_test.dart and
/// test/finance_financing_direct_test.dart.
///
/// The owner writes projects, applications (draft, edits while `draft` /
/// `additional_info_required`, submission with the declaration, withdrawal)
/// and documents directly to Firestore, checked by the security rules. The
/// ADMIN (and the reviewers of the financing institutions, through the
/// admin panel) decide every other status: review, information requests,
/// document notes, approval, funding and closure, with `financing_reviews`.
library;

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:customer/service/finance_ledger.dart' show FinanceWrite;

int _int(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [];

Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

Map<String, int> _amounts(dynamic v) => {for (final e in _map(v).entries) if (_int(e.value) > 0) e.key: _int(e.value)};

/// A document the application must include, possibly only for some financing types.
class RequiredDocument {
  final String type;

  /// Empty = every financing type.
  final List<String> financingTypes;

  const RequiredDocument(this.type, this.financingTypes);
}

/// `finance_settings/{regionId}_financing` (admin). Null when missing or invalid.
class FinancingConfig {
  final List<String> currencies;
  final List<String> financingTypes;
  final List<String> sectors;
  final List<String> stages;
  final List<String> documentTypes;
  final List<RequiredDocument> requiredDocuments;
  final Map<String, int> minAmount;
  final Map<String, int> maxAmount;
  final List<int> durationsMonths;
  final List<String> allowedContentTypes;
  final int maxFileBytes;

  const FinancingConfig({
    required this.currencies,
    required this.financingTypes,
    required this.sectors,
    required this.stages,
    required this.documentTypes,
    required this.requiredDocuments,
    required this.minAmount,
    required this.maxAmount,
    required this.durationsMonths,
    required this.allowedContentTypes,
    required this.maxFileBytes,
  });

  static FinancingConfig? parse(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final currencies = _strings(raw['currencies']).where((c) => RegExp(r'^[A-Z]{3}$').hasMatch(c)).toList();
    final types = _strings(raw['financingTypes']).where(FinancingLabels.types.contains).toList();
    final docTypes = _strings(raw['documentTypes']);
    if (currencies.isEmpty || types.isEmpty || docTypes.isEmpty) return null;
    final required = <RequiredDocument>[
      for (final r in (raw['requiredDocuments'] is List ? raw['requiredDocuments'] as List : const []))
        if (r is String && docTypes.contains(r))
          RequiredDocument(r, const [])
        else if (r is Map && docTypes.contains(r['type']?.toString()))
          RequiredDocument(r['type'].toString(), _strings(r['financingTypes'])),
    ];
    final durations = (raw['durationsMonths'] is List ? (raw['durationsMonths'] as List).map(_int).where((d) => d > 0).toList() : <int>[])..sort();
    final contentTypes = _strings(raw['allowedContentTypes']);
    final int maxBytes = _int(raw['maxFileBytes']);
    return FinancingConfig(
      currencies: currencies,
      financingTypes: types,
      sectors: _strings(raw['sectors']).isEmpty ? const ['other'] : _strings(raw['sectors']),
      stages: _strings(raw['stages']),
      documentTypes: docTypes,
      requiredDocuments: required,
      minAmount: _amounts(raw['minAmount']),
      maxAmount: _amounts(raw['maxAmount']),
      durationsMonths: durations,
      allowedContentTypes: contentTypes.isEmpty ? const ['application/pdf', 'image/jpeg', 'image/png'] : contentTypes,
      maxFileBytes: maxBytes <= 0 ? 20 * 1024 * 1024 : math.min(maxBytes, 50 * 1024 * 1024),
    );
  }

  /// The document types a [financingType] application must include.
  List<String> requiredFor(String financingType) =>
      {for (final r in requiredDocuments) if (r.financingTypes.isEmpty || r.financingTypes.contains(financingType)) r.type}.toList();

  /// Translation key of the problem with [amount], or null.
  String? amountProblem(int? amount, String currency) {
    if (amount == null || amount <= 0) return 'Enter a valid amount.';
    if (minAmount[currency] != null && amount < minAmount[currency]!) return 'The amount is below the minimum.';
    if (maxAmount[currency] != null && amount > maxAmount[currency]!) return 'The amount is above the maximum.';
    return null;
  }

  /// Translation key of the problem with a file, or null.
  String? fileProblem(String contentType, int size) {
    if (!allowedContentTypes.contains(contentType)) return 'This file type is not accepted. Use a PDF or a photo.';
    if (size <= 0) return 'This file is empty.';
    if (size > maxFileBytes) return 'This file is too large.';
    return null;
  }

  /// Loans (and mixed financing) have a duration.
  bool hasDuration(String financingType) => durationsMonths.isNotEmpty && (financingType == 'loan' || financingType == 'mixed');
}

/// The content type of a picked file, from its extension.
String contentTypeOf(String fileName) => switch (fileName.split('.').last.toLowerCase()) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      _ => 'application/octet-stream',
    };

/// The extensions to offer in the file picker for [contentTypes].
List<String> extensionsFor(List<String> contentTypes) => [
      for (final c in contentTypes)
        ...switch (c) {
          'application/pdf' => ['pdf'],
          'image/jpeg' => ['jpg', 'jpeg'],
          'image/png' => ['png'],
          'application/msword' => ['doc'],
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => ['docx'],
          'application/vnd.ms-excel' => ['xls'],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => ['xlsx'],
          _ => const <String>[],
        },
    ];

/// The required types not covered by an uploaded document (a rejected one does not count).
List<String> missingDocuments(List<String> required, List<Map<String, dynamic>> uploaded) {
  final have = {for (final d in uploaded) if (d['status'] != 'rejected') d['type']?.toString()};
  return [for (final t in required) if (!have.contains(t)) t];
}

/// Application statuses (`financing_applications.status`).
abstract final class FinancingStatus {
  static const List<String> steps = ['submitted', 'under_review', 'approved', 'funded', 'closed'];

  static String label(String? s) => const {
        'draft': 'Draft',
        'submitted': 'Submitted',
        'under_review': 'Under review',
        'additional_info_required': 'More information needed',
        'approved': 'Approved',
        'rejected': 'Not approved',
        'funded': 'Funded',
        'closed': 'Closed',
        'withdrawn': 'Withdrawn',
      }[s] ??
      (s ?? '-');

  /// The owner can change details and documents.
  static bool editable(String? s) => s == 'draft' || s == 'additional_info_required';

  static bool canSubmit(String? s, List<String> missing) => editable(s) && missing.isEmpty;

  static bool canWithdraw(String? s) => const ['draft', 'submitted', 'under_review', 'additional_info_required'].contains(s);
}

abstract final class FinancingLabels {
  static const List<String> types = ['loan', 'equity', 'grant', 'guarantee', 'mixed'];

  static String type(String? t) => const {
        'loan': 'Loan',
        'equity': 'Equity investment',
        'grant': 'Grant',
        'guarantee': 'Guarantee',
        'mixed': 'Mixed financing',
      }[t] ??
      (t ?? '-');

  static String sector(String? s) => const {
        'agriculture': 'Agriculture',
        'commerce': 'Trade',
        'manufacturing': 'Manufacturing',
        'services': 'Services',
        'technology': 'Technology',
        'health': 'Health',
        'education': 'Education',
        'energy': 'Energy',
        'construction': 'Construction',
        'transport': 'Transport and logistics',
        'tourism': 'Tourism',
        'other': 'Other',
      }[s] ??
      (s ?? '-');

  static String stage(String? s) => const {
        'idea': 'Idea',
        'startup': 'Starting',
        'growth': 'Growing',
        'established': 'Established',
      }[s] ??
      (s ?? '-');

  static String document(String? t) => const {
        'business_plan': 'Business plan',
        'financial_statements': 'Financial statements',
        'financial_forecast': 'Financial forecast',
        'registration': 'Company registration',
        'tax_certificate': 'Tax certificate',
        'bank_statements': 'Bank statements',
        'id_documents': 'Identity of the managers',
        'pitch_deck': 'Presentation',
        'quotes': 'Supplier quotes',
        'other': 'Other document',
      }[t] ??
      (t ?? '-');

  static String documentStatus(String? s) => const {'received': 'Received', 'accepted': 'Accepted', 'rejected': 'To replace'}[s] ?? (s ?? '-');

  static String resource(String? t) => const {
        'template': 'Templates',
        'guide': 'Guides',
        'faq': 'Questions and answers',
        'regulation': 'Regulations',
      }[t] ??
      (t ?? '-');
}

/// Why an owner's step cannot be written, as a `FinanceException` reason
/// (null when it can).
abstract final class FinancingChecks {
  static String? edit(String? status) => FinancingStatus.editable(status) ? null : 'financing_not_editable';

  static String? submit(String? status, List<String> missing) {
    if (!FinancingStatus.editable(status)) return 'financing_not_editable';
    if (missing.isNotEmpty) return 'financing_documents_missing';
    return null;
  }

  static String? withdraw(String? status) => FinancingStatus.canWithdraw(status) ? null : 'financing_not_editable';
}

/// The owner's writes, as data (pure; committed in one batch by
/// FinanceFinancingService). Ids are chosen by the app before the first
/// attempt, so a retry writes the same document.
abstract final class FinancingPlans {
  static Object get _now => FieldValue.serverTimestamp();

  /// Optional project fields: not stored when empty (removed on an edit).
  static const List<String> optionalProjectFields = ['stage', 'employees', 'foundedYear', 'website'];

  static bool _blank(dynamic v) => v == null || (v is String && v.trim().isEmpty);

  /// A new project ([isNew]) or the owner's edit of it: `name`, `sector`,
  /// `country`, `city`, `description`, and the optional fields.
  static List<FinanceWrite> saveProject({required String projectId, required String uid, required bool isNew, required Map<String, dynamic> fields}) {
    final base = {
      'name': fields['name'],
      'sector': fields['sector'],
      'country': fields['country'] ?? '',
      'city': fields['city'] ?? '',
      'description': fields['description'],
    };
    if (isNew) {
      return [
        FinanceWrite('financing_projects/$projectId', 'create', {
          'id': projectId,
          'ownerId': uid,
          ...base,
          for (final k in optionalProjectFields)
            if (!_blank(fields[k])) k: fields[k],
          'createdAt': _now,
          'updatedAt': _now,
        }),
      ];
    }
    return [
      FinanceWrite('financing_projects/$projectId', 'update', {
        ...base,
        for (final k in optionalProjectFields) k: _blank(fields[k]) ? FieldValue.delete() : fields[k],
        'updatedAt': _now,
      }),
    ];
  }

  /// The application fields the owner edits.
  static Map<String, dynamic> _application(Map<String, dynamic> f, {required bool isNew}) => {
        'financingType': f['financingType'],
        'amount': f['amount'],
        'currency': f['currency'],
        if (f['durationMonths'] != null) 'durationMonths': f['durationMonths'] else if (!isNew) 'durationMonths': FieldValue.delete(),
        'useOfFunds': f['useOfFunds'],
      };

  /// A draft application for the owner's project [projectId].
  static List<FinanceWrite> createApplication({
    required String applicationId,
    required String uid,
    required String projectId,
    required String projectName,
    required Map<String, dynamic> fields,
  }) =>
      [
        FinanceWrite('financing_applications/$applicationId', 'create', {
          'id': applicationId,
          'ownerId': uid,
          'projectId': projectId,
          'projectName': projectName,
          ..._application(fields, isNew: true),
          'status': 'draft',
          'reviewerIds': <String>[],
          'createdAt': _now,
          'updatedAt': _now,
        }),
      ];

  /// The owner's edit while `draft` / `additional_info_required` (the
  /// project of an application never changes).
  static List<FinanceWrite> updateApplication(String applicationId, Map<String, dynamic> fields) => [
        FinanceWrite('financing_applications/$applicationId', 'update', {..._application(fields, isNew: false), 'updatedAt': _now}),
      ];

  /// Submits (or sends back after a request for information) with the
  /// owner's declaration; [message] is their note to the reviewers. The
  /// reviewers' previous request (`reason`) is answered.
  static List<FinanceWrite> submit(String applicationId, {String message = ''}) => [
        FinanceWrite('financing_applications/$applicationId', 'update', {
          'status': 'submitted',
          'declarationAccepted': true,
          'declarationAcceptedAt': _now,
          'submittedAt': _now,
          'ownerMessage': message,
          'reason': null,
          'updatedAt': _now,
        }),
      ];

  static List<FinanceWrite> withdraw(String applicationId) => [
        FinanceWrite('financing_applications/$applicationId', 'update', {'status': 'withdrawn', 'withdrawnAt': _now, 'updatedAt': _now}),
      ];

  /// A document already uploaded to [storagePath]
  /// (`financing_documents/{uid}/{applicationId}/…`).
  static List<FinanceWrite> addDocument({
    required String documentId,
    required String uid,
    required String applicationId,
    required String type,
    required String name,
    required String storagePath,
    required String contentType,
    required int size,
  }) =>
      [
        FinanceWrite('financing_documents/$documentId', 'create', {
          'id': documentId,
          'ownerId': uid,
          'applicationId': applicationId,
          'type': type,
          'name': name,
          'storagePath': storagePath,
          'contentType': contentType,
          'size': size,
          'status': 'received',
          'note': '',
          'uploadedAt': _now,
        }),
      ];

  /// Removes a document of an editable application (op `delete`).
  static List<FinanceWrite> removeDocument(String documentId) => [FinanceWrite('financing_documents/$documentId', 'delete', const {})];
}

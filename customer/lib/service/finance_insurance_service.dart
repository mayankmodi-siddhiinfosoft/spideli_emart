import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/service/finance_direct.dart';
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/utils/finance_insurance_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Online insurance for the customer app (.claude/FINANCE-APP-CONTRACT.md
/// section 13, .claude/FINANCE-DIRECT-FIRESTORE.md section 3.10). Reads what
/// Spideli and the insurers stored; each step is written to Firestore
/// (checked by the security rules) and the admin completes it with the
/// insurer (prices, activation, renewal, cancellation, claim decisions).
abstract final class FinanceInsuranceService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get _uid => FinanceService.uid;

  static Future<InsuranceConfig?> config() async => InsuranceConfig.parse((await _db.collection('platform_settings').doc('insurance').get()).data());

  /// The published catalog, in the admin's order.
  static Stream<List<InsuranceProduct>> products() => _db.collection('insurance_products').where('published', isEqualTo: true).limit(100).snapshots().map((s) {
        final docs = s.docs.toList()
          ..sort((a, b) {
            final int o = _order(a.data()).compareTo(_order(b.data()));
            return o != 0 ? o : '${a.data()['name']}'.compareTo('${b.data()['name']}');
          });
        return docs.map((d) => InsuranceProduct.fromMap({...d.data(), 'id': d.id})).where((p) => p.name.isNotEmpty && p.currency.isNotEmpty).toList();
      });

  static Stream<InsuranceProduct?> product(String id) =>
      _db.collection('insurance_products').doc(id).snapshots().map((s) => s.data() == null ? null : InsuranceProduct.fromMap({...s.data()!, 'id': s.id}));

  static Stream<List<Map<String, dynamic>>> _mine(String collection, {int limit = 50}) => _db
      .collection(collection)
      .where('userId', isEqualTo: _uid)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

  static Stream<List<Map<String, dynamic>>> quotes() => _mine('insurance_quotes');

  static Stream<List<Map<String, dynamic>>> policies() => _mine('insurance_policies');

  static Stream<List<Map<String, dynamic>>> claims() => _mine('insurance_claims');

  static Stream<Map<String, dynamic>?> doc(String collection, String id) =>
      _db.collection(collection).doc(id).snapshots().map((s) => s.data() == null ? null : {...s.data()!, 'id': s.id});

  static Stream<List<Map<String, dynamic>>> premiums(String policyId) => _db
      .collection('insurance_premiums')
      .where('userId', isEqualTo: _uid)
      .where('policyId', isEqualTo: policyId)
      .orderBy('dueDate')
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

  static Stream<List<Map<String, dynamic>>> policyClaims(String policyId) => _db
      .collection('insurance_claims')
      .where('userId', isEqualTo: _uid)
      .where('policyId', isEqualTo: policyId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

  /// Opens a product document, a policy document or a claim file.
  static Future<void> open({String? storagePath, String? url}) async {
    final String link = storagePath != null ? await FirebaseStorage.instance.ref(storagePath).getDownloadURL() : url!;
    await Constant().launchURL(Uri.parse(link));
  }

  /// The record at [path] when it is the user's, else [reason].
  static Future<Map<String, dynamic>> _owned(String path, String reason) async {
    final d = await FinanceDirect.get(path);
    if (d == null || d['userId'] != _uid) throw FinanceException(reason);
    return d;
  }

  /// Asks the insurer (through Spideli) for a quote:
  /// `insurance_quotes/{requestKey}` `requested`. Returns the quote id.
  static Future<String> requestQuote({
    required InsuranceProduct product,
    required Map<String, dynamic> answers,
    required String frequency,
    required DateTime coverStart,
    required String requestKey,
  }) async {
    final String path = 'insurance_quotes/$requestKey';
    if (await FinanceDirect.existing(path) != null) return requestKey;
    // The product as it is now: still offered, every question answered.
    final data = await FinanceDirect.get('insurance_products/${product.id}');
    final InsuranceProduct? now = data == null ? null : InsuranceProduct.fromMap({...data, 'id': product.id});
    if (now == null || data!['published'] != true || !now.acceptsQuotes || !now.frequencies.containsKey(frequency)) throw const FinanceException('product_closed');
    if (now.factors.any((f) => f.multiplierFor(answers[f.key]) == null)) throw const FinanceException('not_eligible');
    await FinanceDirect.commit(InsuranceWrites.requestQuote(id: requestKey, uid: _uid, product: now, answers: answers, frequency: frequency, coverStart: coverStart));
    return requestKey;
  }

  static Future<void> declineQuote(String quoteId) async {
    final q = await _owned('insurance_quotes/$quoteId', 'quote_expired');
    if (q['status'] == 'declined') return;
    if (!Quote.fromMap(q, _toDate).canDecline) throw const FinanceException('quote_expired');
    await FinanceDirect.commit(InsuranceWrites.declineQuote(quoteId));
  }

  static DateTime? _toDate(dynamic v) => v is Timestamp ? v.toDate() : null;

  /// Accepts quote [quoteId] under terms [termsVersion], signed with
  /// [signatureName], paying the first premium with [funding]: the policy is
  /// `pending_activation` until the insurer confirms it. Idempotent on the
  /// quote (one policy per quote).
  static Future<Map<String, dynamic>> acceptQuote({
    required String quoteId,
    required int termsVersion,
    required String signatureName,
    required FinanceFunding funding,
  }) async {
    final String path = 'insurance_quotes/$quoteId';
    final q = await _owned(path, 'quote_expired');
    final String status = q['status']?.toString() ?? '';
    if (status != 'accepted') {
      if (!Quote.fromMap(q, _toDate).canAccept(DateTime.now())) throw const FinanceException('quote_expired');
      if (FinanceSummary.intOf(q['termsVersion']) != termsVersion) throw const FinanceException('terms_outdated');
    }
    final String policyId = InsuranceWrites.policyIdOf(quoteId);
    final String premiumId = InsuranceWrites.firstPremiumIdOf(policyId);
    return FinanceDirect.payPlatform(
      funding: funding,
      type: 'insurance_premium',
      currency: q['currency']?.toString() ?? '',
      amount: Quote.fromMap(q, _toDate).premium,
      sourceKind: 'insurance_premiums',
      sourceId: premiumId,
      description: 'Insurance premium: ${q['productName'] ?? ''}',
      existing: () async {
        final now = await FinanceDirect.get(path);
        if (now?['status'] != 'accepted') return null;
        return await FinanceDirect.existing('insurance_premiums/$premiumId') ?? const {};
      },
      writes: (posting) => InsuranceWrites.acceptQuote(quoteId: quoteId, quote: q, uid: _uid, signatureName: signatureName, posting: posting, paidWith: funding.toMap()),
    );
  }

  /// Pays premium [premiumId] of [policyId] (`due`, `overdue` or `failed`)
  /// with [funding]. Idempotent: a premium already paid is done.
  static Future<Map<String, dynamic>> payPremium(String policyId, String premiumId, String currency, FinanceFunding funding) async {
    final String path = 'insurance_premiums/$premiumId';
    final pr = await _owned(path, 'policy_not_active');
    final String? status = pr['status']?.toString();
    if (pr['policyId'] != policyId || (status != 'paid' && !PolicyActions.premiumPayable(status))) throw const FinanceException('policy_not_active');
    return FinanceDirect.payPlatform(
      funding: funding,
      type: 'insurance_premium',
      currency: pr['currency']?.toString() ?? currency,
      amount: FinanceSummary.intOf(pr['amount']),
      sourceKind: 'insurance_premiums',
      sourceId: premiumId,
      description: 'Insurance premium',
      existing: () async {
        final now = await FinanceDirect.get(path);
        return now?['status'] == 'paid' ? now : null;
      },
      writes: (posting) => InsuranceWrites.payPremium(premiumId: premiumId, posting: posting, paidWith: funding.toMap()),
    );
  }

  /// Pays the `renewalPremium` the insurer set on a `renewal_due` policy
  /// (`renewalRequestedAt`); the admin renews it. Idempotent on the policy.
  static Future<Map<String, dynamic>> renew(String policyId, FinanceFunding funding) async {
    final String path = 'insurance_policies/$policyId';
    final p = await _owned(path, 'policy_not_active');
    final int amount = FinanceSummary.intOf(p['renewalPremium']);
    if (p['renewalRequestedAt'] == null && !PolicyActions.canRenew(p['status']?.toString(), amount)) throw const FinanceException('policy_not_active');
    return FinanceDirect.payPlatform(
      funding: funding,
      type: 'insurance_premium',
      currency: p['currency']?.toString() ?? '',
      amount: amount,
      sourceKind: 'insurance_policies',
      sourceId: policyId,
      description: 'Insurance renewal: ${p['productName'] ?? ''}',
      existing: () async {
        final now = await FinanceDirect.get(path);
        return now?['renewalRequestedAt'] == null ? null : {'reference': now!['renewalReference'] ?? ''};
      },
      writes: (posting) => InsuranceWrites.renew(policyId: policyId, amount: amount, posting: posting, paidWith: funding.toMap()),
    );
  }

  static Future<void> setAutoRenew(String policyId, bool autoRenew) async {
    final p = await _owned('insurance_policies/$policyId', 'policy_not_active');
    if (!PolicyActions.canSetAutoRenew(p['status']?.toString())) throw const FinanceException('policy_not_active');
    await FinanceDirect.commit(InsuranceWrites.setAutoRenew(policyId, autoRenew));
  }

  static Future<void> requestCancellation(String policyId, String reason) async {
    final p = await _owned('insurance_policies/$policyId', 'policy_not_active');
    final String status = p['status']?.toString() ?? '';
    if (status == 'cancellation_requested') return;
    if (!PolicyActions.canCancel(status)) throw const FinanceException('policy_not_active');
    await FinanceDirect.commit(InsuranceWrites.requestCancellation(policyId: policyId, status: status, reason: reason));
  }

  /// Uploads [files] to insurance_claims/{uid}/{claimId}/ (never
  /// overwritten) and returns them as claim documents, numbered from [first].
  static Future<List<Map<String, dynamic>>> _upload(String claimId, List<File> files, {int first = 0}) async {
    final docs = <Map<String, dynamic>>[];
    for (int i = 0; i < files.length; i++) {
      final String path = 'insurance_claims/$_uid/$claimId/${DateTime.now().millisecondsSinceEpoch}-$i.jpg';
      try {
        await FirebaseStorage.instance.ref(path).putFile(files[i], SettableMetadata(contentType: 'image/jpeg'));
      } on FirebaseException catch (e) {
        throw e.code == 'unauthorized' ? const FinanceException('permission_denied') : e;
      }
      docs.add({'name': 'Photo ${first + i + 1}', 'storagePath': path});
    }
    return docs;
  }

  /// Declares a claim on [policy]: its photos to Storage first, then
  /// `insurance_claims/{requestKey}` `submitted`. Returns the claim id.
  static Future<String> submitClaim({
    required Map<String, dynamic> policy,
    required DateTime incidentDate,
    required String description,
    required int amountClaimed,
    required List<File> files,
    required String requestKey,
  }) async {
    final String path = 'insurance_claims/$requestKey';
    if (await FinanceDirect.existing(path) != null) return requestKey;
    final String policyId = policy['id'].toString();
    final p = await _owned('insurance_policies/$policyId', 'policy_not_active');
    if (!PolicyActions.canClaim(p['status']?.toString())) throw const FinanceException('policy_not_active');
    final docs = await _upload(requestKey, files);
    await FinanceDirect.commit(InsuranceWrites.createClaim(
      id: requestKey,
      uid: _uid,
      policy: {...p, 'id': policyId},
      incidentDate: incidentDate,
      description: description,
      amountClaimed: amountClaimed,
      documents: docs,
    ));
    return requestKey;
  }

  /// Answers the insurer's request for more information (message and new
  /// photos): the claim goes back `under_review`, the message is kept in its
  /// events (`events/{requestKey}`: a retry finds it and stops).
  static Future<void> respondToClaim(String claimId, String message, List<File> files, String requestKey) async {
    if (await FinanceDirect.existing('insurance_claims/$claimId/events/$requestKey') != null) return;
    final c = await _owned('insurance_claims/$claimId', 'claim_not_editable');
    if (!PolicyActions.canRespondToClaim(c['status']?.toString())) throw const FinanceException('claim_not_editable');
    final docs = await _upload(claimId, files, first: c['documents'] is List ? (c['documents'] as List).length : 0);
    await FinanceDirect.commit(InsuranceWrites.respondToClaim(claimId: claimId, eventId: requestKey, uid: _uid, message: message, documents: docs));
  }

  static Future<void> withdrawClaim(String claimId) async {
    final c = await _owned('insurance_claims/$claimId', 'claim_not_editable');
    final String? status = c['status']?.toString();
    if (status == 'withdrawn') return;
    if (!PolicyActions.canWithdrawClaim(status)) throw const FinanceException('claim_not_editable');
    await FinanceDirect.commit(InsuranceWrites.withdrawClaim(claimId));
  }
}

/// The admin's display order of a product (`order`, lowest first; unset last).
int _order(Map<String, dynamic> m) => m['order'] is num ? (m['order'] as num).toInt() : 1 << 30;

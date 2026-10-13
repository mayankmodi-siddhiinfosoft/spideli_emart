import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/utils/finance_insurance_rules.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Online insurance for the customer app (.claude/FINANCE-APP-CONTRACT.md
/// section 13). Reads what the server and the insurers' integrations
/// stored; every step is a request to a callable function.
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

  static Future<String> requestQuote({required String productId, required Map<String, dynamic> answers, required String frequency, required DateTime coverStart}) async {
    final r = await FinanceService.call('insuranceRequestQuote', {
      'productId': productId,
      'answers': answers,
      'frequency': frequency,
      'coverStart': '${coverStart.year}-${coverStart.month.toString().padLeft(2, '0')}-${coverStart.day.toString().padLeft(2, '0')}',
    });
    return r['quoteId'].toString();
  }

  static Future<void> declineQuote(String quoteId) => FinanceService.call('insuranceDeclineQuote', {'quoteId': quoteId});

  /// Accepts quote [quoteId] under terms [termsVersion], signed with [signatureName],
  /// and pays the first premium. The policy is active only once the insurer confirms.
  static Future<Map<String, dynamic>> acceptQuote({
    required String quoteId,
    required int termsVersion,
    required String signatureName,
    required Map<String, dynamic> payment,
    required String requestKey,
  }) =>
      FinanceService.call('insuranceAcceptQuote', {
        'quoteId': quoteId,
        'termsVersion': termsVersion,
        'signatureName': signatureName,
        'payment': payment,
        'idempotencyKey': requestKey,
      });

  static Future<Map<String, dynamic>> payPremium(String policyId, String premiumId, Map<String, dynamic> payment, String requestKey) =>
      FinanceService.call('insurancePayPremium', {'policyId': policyId, 'premiumId': premiumId, 'payment': payment, 'idempotencyKey': requestKey});

  static Future<Map<String, dynamic>> renew(String policyId, Map<String, dynamic> payment, String requestKey) =>
      FinanceService.call('insuranceRenewPolicy', {'policyId': policyId, 'payment': payment, 'idempotencyKey': requestKey});

  static Future<void> setAutoRenew(String policyId, bool autoRenew) => FinanceService.call('insuranceSetAutoRenew', {'policyId': policyId, 'autoRenew': autoRenew});

  static Future<void> requestCancellation(String policyId, String reason) =>
      FinanceService.call('insuranceRequestCancellation', {'policyId': policyId, if (reason.isNotEmpty) 'reason': reason});

  /// Opens a claim, uploads its evidence to insurance_claims/{uid}/{claimId}/, then submits it.
  static Future<String> submitClaim({
    required String policyId,
    required DateTime incidentDate,
    required String description,
    required int amountClaimed,
    required List<File> files,
  }) async {
    final r = await FinanceService.call('insuranceCreateClaim', {
      'policyId': policyId,
      'incidentDate': '${incidentDate.year}-${incidentDate.month.toString().padLeft(2, '0')}-${incidentDate.day.toString().padLeft(2, '0')}',
      'description': description,
      'amountClaimed': amountClaimed,
    });
    final String claimId = r['claimId'].toString();
    await addClaimFiles(claimId, files);
    await FinanceService.call('insuranceSubmitClaim', {'claimId': claimId});
    return claimId;
  }

  static Future<void> addClaimFiles(String claimId, List<File> files) async {
    for (int i = 0; i < files.length; i++) {
      final String path = 'insurance_claims/$_uid/$claimId/${DateTime.now().millisecondsSinceEpoch}-$i.jpg';
      await FirebaseStorage.instance.ref(path).putFile(files[i], SettableMetadata(contentType: 'image/jpeg'));
      await FinanceService.call('insuranceRegisterClaimDocument', {'claimId': claimId, 'storagePath': path, 'name': 'Photo ${i + 1}'});
    }
  }

  /// Answers the insurer's request for more information (message and new files).
  static Future<void> respondToClaim(String claimId, String message, List<File> files) async {
    await addClaimFiles(claimId, files);
    await FinanceService.call('insuranceRespondClaim', {'claimId': claimId, if (message.isNotEmpty) 'message': message});
  }

  static Future<void> withdrawClaim(String claimId) => FinanceService.call('insuranceWithdrawClaim', {'claimId': claimId});
}

/// The admin's display order of a product (`order`, lowest first; unset last).
int _order(Map<String, dynamic> m) => m['order'] is num ? (m['order'] as num).toInt() : 1 << 30;

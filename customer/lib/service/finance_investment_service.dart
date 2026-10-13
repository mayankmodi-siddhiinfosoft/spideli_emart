import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/utils/finance_investment_rules.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Investments for the customer app (.claude/FINANCE-APP-CONTRACT.md
/// section 12). Reads what the server and the fund managers published;
/// every order is a request to a callable function.
abstract final class FinanceInvestmentService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get _uid => FinanceService.uid;
  static DateTime? Function(dynamic) get _toDate => FinanceGroupService.toDate;

  static Future<InvestmentConfig?> config() async => InvestmentConfig.parse((await _db.collection('platform_settings').doc('investments').get()).data());

  /// The published catalog, in the manager's order.
  static Stream<List<Fund>> funds() => _db.collection('investment_funds').where('published', isEqualTo: true).limit(100).snapshots().map((s) {
        final docs = s.docs.toList()
          ..sort((a, b) {
            final int o = _order(a.data()).compareTo(_order(b.data()));
            return o != 0 ? o : '${a.data()['name']}'.compareTo('${b.data()['name']}');
          });
        return docs.map((d) => Fund.fromMap({...d.data(), 'id': d.id}, _toDate)).toList();
      });

  static Stream<Fund?> fund(String id) =>
      _db.collection('investment_funds').doc(id).snapshots().map((s) => s.data() == null ? null : Fund.fromMap({...s.data()!, 'id': s.id}, _toDate));

  /// The unit price history, oldest first (up to the last [limit] prices).
  static Stream<List<NavPoint>> valuations(String fundId, {int limit = 90}) => _db
      .collection('investment_valuations')
      .where('fundId', isEqualTo: fundId)
      .orderBy('date', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => [
            for (final d in s.docs.reversed)
              if (_toDate(d.data()['date']) != null && d.data()['navPerUnit'] is num) NavPoint(_toDate(d.data()['date'])!, (d.data()['navPerUnit'] as num).toDouble()),
          ]);

  static Stream<List<Holding>> holdings() => _db.collection('investment_holdings').where('userId', isEqualTo: _uid).snapshots().map(
      (s) => s.docs.map((d) => Holding.fromMap(d.data(), _toDate)).where((h) => h.hasUnits).toList()..sort((a, b) => b.currentValue.compareTo(a.currentValue)));

  /// The user's position in one fund (`investment_holdings/{uid}_{fundId}`), or null.
  static Stream<Holding?> holding(String fundId) =>
      _db.collection('investment_holdings').doc('${_uid}_$fundId').snapshots().map((s) => s.data() == null ? null : Holding.fromMap(s.data()!, _toDate));

  /// The portfolio totals and allocation, from `finance_summaries/{uid}.investments`.
  static Stream<Map<String, dynamic>?> portfolio() => _db.collection('finance_summaries').doc(_uid).snapshots().map((s) {
        final data = s.data();
        final inv = data?['investments'];
        return inv is Map ? {...Map<String, dynamic>.from(inv), 'currency': data?['currency']} : null;
      });

  static Stream<List<Map<String, dynamic>>> _mine(String collection, {String? fundId, int limit = 50}) {
    Query<Map<String, dynamic>> q = _db.collection(collection).where('userId', isEqualTo: _uid);
    if (fundId != null) q = q.where('fundId', isEqualTo: fundId);
    return q.orderBy('createdAt', descending: true).limit(limit).snapshots().map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  static Stream<List<Map<String, dynamic>>> subscriptions() => _mine('investment_subscriptions');

  static Stream<List<Map<String, dynamic>>> redemptions() => _mine('investment_redemptions');

  static Stream<Map<String, dynamic>?> order(String collection, String id) =>
      _db.collection(collection).doc(id).snapshots().map((s) => s.data() == null ? null : {...s.data()!, 'id': s.id});

  static Stream<List<Map<String, dynamic>>> transactions(String fundId) => _mine('investment_transactions', fundId: fundId);

  /// Statements and reports the server generated (PDF in Storage).
  static Stream<List<Map<String, dynamic>>> reports() => _mine('investment_reports', limit: 24);

  /// Opens a fund document or a report: a Storage path (through a download
  /// link the rules allow) or an https link.
  static Future<void> open({String? storagePath, String? url}) async {
    final String link = storagePath != null ? await FirebaseStorage.instance.ref(storagePath).getDownloadURL() : url!;
    await Constant().launchURL(Uri.parse(link));
  }

  /// Subscribes [amount] to [fundId] after the user accepted the fund's
  /// terms [termsVersion] and the risk disclosure and signed with their
  /// name. The reply says how the payment proceeds (as section 8.4).
  static Future<Map<String, dynamic>> subscribe({
    required String fundId,
    required int amount,
    required String currency,
    required int termsVersion,
    required String signatureName,
    required Map<String, dynamic> payment,
    required String requestKey,
  }) =>
      FinanceService.call('investmentSubscribe', {
        'fundId': fundId,
        'amount': amount,
        'currency': currency,
        'termsVersion': termsVersion,
        'riskAcknowledged': true,
        'signatureName': signatureName,
        'payment': payment,
        'idempotencyKey': requestKey,
      });

  /// Redeems [amount] of value, or the whole redeemable position when [full].
  static Future<Map<String, dynamic>> redeem({required String fundId, required bool full, int? amount, required Map<String, dynamic> destination, required String requestKey}) =>
      FinanceService.call('investmentRedeem', {
        'fundId': fundId,
        'full': full,
        if (!full) 'amount': amount,
        'destination': destination,
        'idempotencyKey': requestKey,
      });

  static Future<void> cancelRedemption(String redemptionId) => FinanceService.call('investmentCancelRedemption', {'redemptionId': redemptionId});
}

/// The manager's display order of a fund (`order`, lowest first; unset last).
int _order(Map<String, dynamic> m) => m['order'] is num ? (m['order'] as num).toInt() : 1 << 30;

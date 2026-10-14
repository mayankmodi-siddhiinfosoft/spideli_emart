import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/service/finance_direct.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/utils/finance_investment_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Investments for the customer app (.claude/FINANCE-APP-CONTRACT.md
/// section 12, .claude/FINANCE-DIRECT-FIRESTORE.md section 3.9). Reads what
/// Spideli published; orders are written to Firestore (checked by the
/// security rules) and executed by Spideli at the fund's next unit price.
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

  /// The portfolio totals (`investments`) and `allocation` of the dashboard
  /// summary the app computes from the user's holdings; null without one.
  static Stream<FinanceSummary?> portfolio() => FinanceService.summary().map((s) => s?.investments == null ? null : s);

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

  /// Subscribes [amount] to [fund] after the user accepted the fund's
  /// terms and the risks and signed with [signatureName]: the money goes to
  /// Spideli at once ([funding]: the wallet, or a gateway payment deposited
  /// into it first) with `investment_subscriptions/{requestKey}` `paid`;
  /// Spideli buys the units at the next unit price. Idempotent on [requestKey].
  static Future<Map<String, dynamic>> subscribe({
    required Fund fund,
    required int amount,
    required int termsVersion,
    required String signatureName,
    required FinanceFunding funding,
    required String requestKey,
  }) async {
    // The fund as it is now: still open, the same terms, the minimum.
    final data = await FinanceDirect.get('investment_funds/${fund.id}');
    final Fund? now = data == null ? null : Fund.fromMap({...data, 'id': fund.id}, _toDate);
    if (now == null || !now.acceptsSubscriptions || data!['published'] != true) throw const FinanceException('fund_closed');
    if (now.termsVersion != termsVersion) throw const FinanceException('terms_outdated');
    final held = await FinanceDirect.existing('investment_holdings/${_uid}_${fund.id}');
    final bool holder = held != null && Holding.fromMap(held, _toDate).hasUnits;
    if (amount < now.minimumFor(holder: holder)) throw const FinanceException('below_minimum');
    final String path = 'investment_subscriptions/$requestKey';
    return FinanceDirect.payPlatform(
      funding: funding,
      type: 'investment_subscription',
      currency: now.currency,
      amount: amount,
      sourceKind: 'investment_subscriptions',
      sourceId: requestKey,
      description: 'Investment: ${now.name}',
      existing: () => FinanceDirect.existing(path),
      writes: (posting) => InvestmentWrites.subscribe(
        id: requestKey,
        uid: _uid,
        fund: now,
        amount: amount,
        fee: InvestmentCalculator.subscription(now, amount).fee,
        signatureName: signatureName,
        posting: posting,
        paidWith: funding.toMap(),
      ),
    );
  }

  /// Redeems [amount] of value, or the whole redeemable position when
  /// [full], paid to [destination] once Spideli has executed it
  /// (`investment_redemptions/{requestKey}` `submitted`). Idempotent on
  /// [requestKey]. Returns the reply of the payment sheet.
  static Future<Map<String, dynamic>> redeem({required Holding holding, required Fund fund, required bool full, int? amount, required Map<String, dynamic> destination, required String requestKey}) async {
    if (!fund.redemptionAllowed || fund.status == 'suspended') throw const FinanceException('redemption_not_allowed');
    if (!full && !fund.partialRedemption) throw const FinanceException('redemption_not_allowed');
    if (holding.redeemableValue <= 0 || (!full && ((amount ?? 0) <= 0 || amount! > holding.redeemableValue))) throw const FinanceException('insufficient_units');
    final String path = 'investment_redemptions/$requestKey';
    final done = await FinanceDirect.existing(path);
    if (done != null) return {'status': 'submitted', 'reference': done['reference'] ?? ''};
    final String reference = FinanceLedger.newReference();
    await FinanceDirect.commit(InvestmentWrites.redeem(
      id: requestKey,
      uid: _uid,
      fundId: holding.fundId,
      fundName: holding.fundName.isNotEmpty ? holding.fundName : fund.name,
      currency: holding.currency,
      full: full,
      amount: amount,
      destination: destination,
      reference: reference,
    ));
    return {'status': 'submitted', 'reference': reference};
  }

  /// Withdraws a redemption Spideli has not started processing.
  static Future<void> cancelRedemption(String redemptionId) async {
    final o = await FinanceDirect.get('investment_redemptions/$redemptionId');
    // ("This action is no longer possible. Please refresh.")
    if (o == null || o['userId'] != _uid || !InvestmentOrders.canCancelRedemption(o['status']?.toString())) throw const FinanceException('kyc_invalid_transition');
    await FinanceDirect.commit(InvestmentWrites.cancelRedemption(redemptionId));
  }
}

/// The manager's display order of a fund (`order`, lowest first; unset last).
int _order(Map<String, dynamic> m) => m['order'] is num ? (m['order'] as num).toInt() : 1 << 30;

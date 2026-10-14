import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/utils/finance_intel_rules.dart';

/// Economic intelligence, markets, investor matching and the AI coach for
/// the customer app (.claude/FINANCE-APP-CONTRACT.md section 17,
/// .claude/FINANCE-DIRECT-FIRESTORE.md section 3.11). Every figure is read
/// from what the ADMIN published from approved, licensed sources
/// (indicators, rates, opportunities, market data, news). The customer
/// writes only their own documents, directly (checked by the security
/// rules): `investor_profiles/{uid}`, `investor_watchlists/{uid}` and
/// `opportunity_interests/{opportunityId}_{uid}`. The coach runs on a
/// server (no AI key in the app) and is turned off until one exists.
abstract final class FinanceIntelService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get _uid => FinanceService.uid;
  static DateTime? Function(dynamic) get _toDate => FinanceGroupService.toDate;

  static Future<IntelligenceConfig?> config() async => IntelligenceConfig.parse((await _db.collection('platform_settings').doc('intelligence').get()).data());

  // ── Indicators and exchange rates ──────────────────────────────────────

  /// The published indicators of [country] that carry their source, period and update time.
  static Stream<List<Indicator>> indicators(String country) =>
      _db.collection('economic_indicators').where('published', isEqualTo: true).where('country', isEqualTo: country).limit(100).snapshots().map((s) {
        final docs = s.docs.toList()..sort((a, b) => _order(a.data()).compareTo(_order(b.data())));
        return docs.map((d) => Indicator.fromMap({...d.data(), 'id': d.id}, _toDate)).where((i) => i.complete).toList();
      });

  /// Past values of an indicator, oldest first: (period, value).
  static Stream<List<(String, double)>> indicatorHistory(String indicatorId) => _db
      .collection('economic_indicator_history')
      .where('indicatorId', isEqualTo: indicatorId)
      .orderBy('periodEnd', descending: true)
      .limit(40)
      .snapshots()
      .map((s) => [
            for (final d in s.docs.reversed)
              if (d.data()['value'] is num) (d.data()['period']?.toString() ?? '', (d.data()['value'] as num).toDouble()),
          ]);

  static Stream<List<FxRate>> rates(String base) => _db
      .collection('exchange_rate_snapshots')
      .where('to', isEqualTo: base)
      .orderBy('observedAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map((d) => FxRate.fromMap(d.data(), _toDate)).whereType<FxRate>().toList());

  /// One pair over time, oldest first.
  static Stream<List<FxRate>> rateHistory(String from, String to) => _db
      .collection('exchange_rate_snapshots')
      .where('pair', isEqualTo: '${from}_$to')
      .orderBy('observedAt', descending: true)
      .limit(90)
      .snapshots()
      .map((s) => s.docs.reversed.map((d) => FxRate.fromMap(d.data(), _toDate)).whereType<FxRate>().toList());

  // ── Opportunities and matching ─────────────────────────────────────────

  static Stream<List<Opportunity>> opportunities() => _db
      .collection('investment_opportunities')
      .where('published', isEqualTo: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => Opportunity.fromMap({...d.data(), 'id': d.id}, _toDate)).toList());

  static Stream<Opportunity?> opportunity(String id) =>
      _db.collection('investment_opportunities').doc(id).snapshots().map((s) => s.data() == null ? null : Opportunity.fromMap({...s.data()!, 'id': s.id}, _toDate));

  static Stream<Map<String, dynamic>?> investorProfile() => _db.collection('investor_profiles').doc(_uid).snapshots().map((s) => s.data());

  /// Saves the user's own investor profile (values from the admin's [config]).
  static Future<void> saveInvestorProfile(
    MatchingConfig config, {
    required String currency,
    required List<String> sectors,
    required List<String> countries,
    required List<String> types,
    required int minTicket,
    required int maxTicket,
    required int maxRisk,
    required int maxHorizonMonths,
  }) =>
      _guard(() async {
        final String uid = _signedIn();
        final String? problem = IntelPlans.profileProblem(config, currency: currency, minTicket: minTicket, maxTicket: maxTicket);
        if (problem != null) throw FinanceException(problem);
        await _commit(IntelPlans.investorProfile(
          uid,
          config,
          currency: currency,
          sectors: sectors,
          countries: countries,
          types: types,
          minTicket: minTicket,
          maxTicket: maxTicket,
          maxRisk: maxRisk,
          maxHorizonMonths: maxHorizonMonths,
        ));
      });

  /// Tells the project owner the user is interested (their name and email
  /// go with it), or hides the opportunity. No money moves.
  static Future<void> respond(String opportunityId, bool interested, {String message = ''}) => _guard(() async {
        final String uid = _signedIn();
        final snap = await _db.collection('investment_opportunities').doc(opportunityId).get();
        final o = snap.data() == null ? null : Opportunity.fromMap({...snap.data()!, 'id': snap.id}, _toDate);
        if (o == null || !o.isOpen(DateTime.now())) throw const FinanceException('opportunity_closed');
        final user = Constant.userModel;
        await _commit(IntelPlans.respond(
          opportunityId: opportunityId,
          uid: uid,
          interested: interested,
          message: message,
          name: user?.fullName() ?? '',
          email: user?.email ?? '',
        ));
      });

  // ── Markets (published by the admin from licensed feeds) ──────────────

  /// Every published security (stocks, ETFs, bonds, indices), live: each
  /// price change of the feed arrives as it is published.
  static Stream<List<MarketSecurity>> securities() => _db
      .collection('market_securities')
      .where('published', isEqualTo: true)
      .limit(500)
      .snapshots()
      .map((s) => s.docs.map((d) => MarketSecurity.fromMap({...d.data(), 'id': d.id}, _toDate)).whereType<MarketSecurity>().toList()..sort(MarketSecurity.byName));

  /// One security, live; null when it is no longer published.
  static Stream<MarketSecurity?> security(String id) =>
      _gone(_db.collection('market_securities').doc(id).snapshots().map((s) => s.data() == null ? null : MarketSecurity.fromMap({...s.data()!, 'id': s.id}, _toDate)));

  /// The closing prices of a security, oldest first (the last 120).
  static Stream<List<(DateTime, double)>> priceHistory(String securityId) => _db
      .collection('market_price_history')
      .where('securityId', isEqualTo: securityId)
      .orderBy('date', descending: true)
      .limit(120)
      .snapshots()
      .map((s) => closingPrices(s.docs.map((d) => d.data()).toList(), _toDate));

  static Stream<List<IpoListing>> ipos() => _db
      .collection('ipo_listings')
      .where('published', isEqualTo: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map((d) => IpoListing.fromMap({...d.data(), 'id': d.id}, _toDate)).whereType<IpoListing>().toList()..sort(IpoListing.compare));

  static Stream<IpoListing?> ipo(String id) =>
      _gone(_db.collection('ipo_listings').doc(id).snapshots().map((s) => s.data() == null ? null : IpoListing.fromMap({...s.data()!, 'id': s.id}, _toDate)));

  static Stream<List<StockCollection>> collections() => _db
      .collection('stock_collections')
      .where('published', isEqualTo: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => StockCollection.fromMap({...d.data(), 'id': d.id})).whereType<StockCollection>().toList()
        ..sort((a, b) => a.order != b.order ? a.order.compareTo(b.order) : a.title.compareTo(b.title)));

  /// The latest published news and analyses, newest first.
  static Stream<List<FinanceNews>> news() => _db
      .collection('finance_news')
      .where('published', isEqualTo: true)
      .orderBy('publishedAt', descending: true)
      .limit(60)
      .snapshots()
      .map((s) => s.docs.map((d) => FinanceNews.fromMap({...d.data(), 'id': d.id}, _toDate)).whereType<FinanceNews>().toList());

  /// The ids of the user's watchlist (`investor_watchlists/{uid}`).
  static Stream<List<String>> watchlist() => _db.collection('investor_watchlists').doc(_uid).snapshots().map((s) => MarketPlans.watchlist(s.data()));

  /// Adds [securityId] to the user's watchlist ([watch]) or removes it.
  static Future<void> setWatched(String securityId, bool watch) => _guard(() async {
        final String uid = _signedIn();
        final current = MarketPlans.watchlist((await _db.collection('investor_watchlists').doc(uid).get()).data());
        final String? problem = MarketPlans.watchProblem(current, securityId, watch);
        if (problem != null) throw FinanceException(problem);
        await _commit(MarketPlans.save(uid, MarketPlans.toggled(current, securityId, watch)));
      });

  // ── Coach ──────────────────────────────────────────────────────────────

  static Stream<CoachConsent?> consent() => _db.collection('coach_consents').doc(_uid).snapshots().map((s) => CoachConsent.fromMap(s.data()));

  static Future<void> acceptConsent(int version, bool shareSummary) => FinanceService.call('coachAcceptConsent', {'version': version, 'shareSummary': shareSummary});

  static Future<void> setShareSummary(bool shareSummary) => FinanceService.call('coachUpdateConsent', {'shareSummary': shareSummary});

  static Future<void> withdrawConsent({required bool deleteHistory}) => FinanceService.call('coachWithdrawConsent', {'deleteHistory': deleteHistory});

  static Stream<List<Map<String, dynamic>>> sessions() => _db
      .collection('financial_coach_sessions')
      .where('userId', isEqualTo: _uid)
      .orderBy('updatedAt', descending: true)
      .limit(30)
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

  static Stream<List<Map<String, dynamic>>> messages(String sessionId) => _db
      .collection('financial_coach_sessions')
      .doc(sessionId)
      .collection('messages')
      .orderBy('createdAt')
      .limitToLast(200)
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

  /// Sends [text]; the server stores the question and the answer. Returns the session id.
  static Future<String> send({String? sessionId, required String topic, required String text}) async {
    final r = await FinanceService.call('coachSendMessage', {'sessionId': ?sessionId, 'topic': topic, 'text': text});
    return (r['sessionId'] ?? sessionId).toString();
  }

  static Future<void> deleteSession(String sessionId) => FinanceService.call('coachDeleteSession', {'sessionId': sessionId});

  static Future<void> feedback(String sessionId, String messageId, bool helpful) =>
      FinanceService.call('coachFeedback', {'sessionId': sessionId, 'messageId': messageId, 'helpful': helpful});
}

/// The admin's display order (`order`, lowest first; unset last).
int _order(Map<String, dynamic> m) => m['order'] is num ? (m['order'] as num).toInt() : 1 << 30;

String _signedIn() {
  final String uid = FinanceService.uid;
  if (uid.isEmpty) throw const FinanceException('sign_in_required');
  return uid;
}

/// [writes] in one batch.
Future<void> _commit(List<FinanceWrite> writes) async {
  final batch = FirebaseFirestore.instance.batch();
  FinanceLedger.apply(batch, writes);
  await batch.commit();
}

/// [action], with a refusal of the security rules as
/// `FinanceException('permission_denied')`.
Future<T> _guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on FirebaseException catch (e, st) {
    if (e.code == 'permission-denied') Error.throwWithStackTrace(const FinanceException('permission_denied'), st);
    rethrow;
  }
}

/// A published document read by its id: one the admin unpublished (the
/// rules no longer let it be read) is gone (null), not an error.
Stream<T?> _gone<T>(Stream<T?> source) => source.transform(StreamTransformer<T?, T?>.fromHandlers(
      handleError: (e, st, sink) => e is FirebaseException && e.code == 'permission-denied' ? sink.add(null) : sink.addError(e, st),
    ));

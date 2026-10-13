import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/utils/finance_intel_rules.dart';

/// Economic intelligence, investor matching and the AI coach for the
/// customer app (.claude/FINANCE-APP-CONTRACT.md section 17). Every figure
/// is read from what the server collected from approved sources; the coach
/// runs in a Cloud Function (no AI key in the app).
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

  static Future<void> saveInvestorProfile(Map<String, dynamic> profile) => FinanceService.call('intelligenceSaveInvestorProfile', profile);

  /// Tells the project owner the user is interested (or hides it). No money moves.
  static Future<void> respond(String opportunityId, bool interested, {String message = ''}) => FinanceService.call(
      'intelligenceRespondOpportunity', {'opportunityId': opportunityId, 'interested': interested, if (message.isNotEmpty) 'message': message});

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

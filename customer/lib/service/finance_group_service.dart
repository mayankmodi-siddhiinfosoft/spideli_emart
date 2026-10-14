import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/service/finance_service.dart';
import 'package:customer/utils/finance_group_rules.dart';

/// Savings goals and tontines for the customer app
/// (.claude/FINANCE-APP-CONTRACT.md sections 8-9). Reads what the server
/// stored; every change, and above all every money movement, is a request to
/// a callable function. Queries are shaped so the security rules can prove
/// the user may read them (each is constrained to the user or to a group the
/// user belongs to).
abstract final class FinanceGroupService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get _uid => FinanceService.uid;

  static DateTime? toDate(dynamic v) => v is Timestamp ? v.toDate() : null;

  /// An idempotency key for one confirmed request: a retried or doubled call
  /// with the same key can never pay twice (the server keeps the first result).
  static String newRequestKey() {
    final r = Random.secure();
    return '${DateTime.now().millisecondsSinceEpoch}-${List.generate(12, (_) => r.nextInt(36).toRadixString(36)).join()}';
  }

  static String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// How a payment is made: `{ method: 'wallet' }` or
  /// `{ method: 'mobile_money' | 'wave', operator?, number }`.
  static Map<String, dynamic> paymentOf(String method, {String? operator, String? number}) => {
        'method': method,
        if (operator != null && operator.isNotEmpty) 'operator': operator,
        if (number != null && number.isNotEmpty) 'number': number,
      };

  // ── Configuration ─────────────────────────────────────────────────────

  static Future<SavingsConfig?> savingsConfig() async => SavingsConfig.parse((await _db.collection('platform_settings').doc('savings').get()).data());

  static Future<TontineConfig?> tontineConfig() async => TontineConfig.parse((await _db.collection('platform_settings').doc('tontines').get()).data());

  // ── Savings goals ─────────────────────────────────────────────────────

  static Stream<List<SavingsGoal>> myGoals() => _db
      .collection('savings_goals')
      .where('memberIds', arrayContains: _uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => SavingsGoal.fromMap(d.data(), toDate)).toList());

  /// Group goals the user is invited to.
  static Stream<List<SavingsGoal>> goalInvitations() => _db
      .collection('savings_goals')
      .where('invitedIds', arrayContains: _uid)
      .snapshots()
      .map((s) => s.docs.map((d) => SavingsGoal.fromMap(d.data(), toDate)).toList());

  static Stream<SavingsGoal?> goal(String goalId) =>
      _db.collection('savings_goals').doc(goalId).snapshots().map((s) => s.data() == null ? null : SavingsGoal.fromMap(s.data()!, toDate));

  static Stream<List<Map<String, dynamic>>> goalContributions(String goalId) => _db
      .collection('savings_contributions')
      .where('goalId', isEqualTo: goalId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  static Stream<List<Map<String, dynamic>>> goalWithdrawals(String goalId) => _db
      .collection('savings_withdrawals')
      .where('goalId', isEqualTo: goalId)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  static Future<String> createGoal({
    required String name,
    required String purpose,
    required String description,
    required int targetAmount,
    required String currency,
    DateTime? deadline,
    String? frequency,
    int? scheduleAmount,
    List<String> inviteEmails = const [],
  }) async {
    final r = await FinanceService.call('savingsCreateGoal', {
      'name': name,
      'purpose': purpose,
      if (description.isNotEmpty) 'description': description,
      'targetAmount': targetAmount,
      'currency': currency,
      if (deadline != null) 'deadline': _day(deadline),
      if (frequency != null && (scheduleAmount ?? 0) > 0) 'schedule': {'frequency': frequency, 'amount': scheduleAmount},
      if (inviteEmails.isNotEmpty) 'inviteEmails': inviteEmails,
    });
    return r['goalId'].toString();
  }

  static Future<void> updateGoal(String goalId, {String? name, String? description, DateTime? deadline, String? frequency, int? scheduleAmount, bool clearSchedule = false}) =>
      FinanceService.call('savingsUpdateGoal', {
        'goalId': goalId,
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (deadline != null) 'deadline': _day(deadline),
        if (clearSchedule) 'schedule': null,
        if (!clearSchedule && frequency != null && (scheduleAmount ?? 0) > 0) 'schedule': {'frequency': frequency, 'amount': scheduleAmount},
      });

  static Future<void> inviteToGoal(String goalId, String email) => FinanceService.call('savingsInviteMember', {'goalId': goalId, 'email': email});

  static Future<void> respondToGoalInvite(String goalId, bool accept) => FinanceService.call('savingsRespondInvite', {'goalId': goalId, 'accept': accept});

  /// Asks the server to collect [amount] into the goal. The reply says how
  /// the payment proceeds (`status`, `instructions`); the contribution's
  /// final status arrives in `savings_contributions` once the provider
  /// confirms it.
  static Future<Map<String, dynamic>> contributeToGoal(String goalId, int amount, Map<String, dynamic> payment, String requestKey) =>
      FinanceService.call('savingsContribute', {'goalId': goalId, 'amount': amount, 'payment': payment, 'idempotencyKey': requestKey});

  static Future<Map<String, dynamic>> requestWithdrawal(String goalId, int amount, Map<String, dynamic> destination, String requestKey, {String? reason}) =>
      FinanceService.call('savingsRequestWithdrawal', {
        'goalId': goalId,
        'amount': amount,
        'destination': destination,
        'idempotencyKey': requestKey,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

  static Future<void> cancelGoal(String goalId) => FinanceService.call('savingsCancelGoal', {'goalId': goalId});

  // ── Tontines ──────────────────────────────────────────────────────────

  static Stream<List<Tontine>> myTontines() => _db
      .collection('tontines')
      .where('memberIds', arrayContains: _uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Tontine.fromMap(d.data(), toDate)).toList());

  /// The user's pending invitations (`tontine_members`, status `invited`).
  static Stream<List<Map<String, dynamic>>> tontineInvitations() => _db
      .collection('tontine_members')
      .where('userId', isEqualTo: _uid)
      .where('status', isEqualTo: 'invited')
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  static Stream<Tontine?> tontine(String id) =>
      _db.collection('tontines').doc(id).snapshots().map((s) => s.data() == null ? null : Tontine.fromMap(s.data()!, toDate));

  static Stream<List<Map<String, dynamic>>> members(String tontineId) => _db
      .collection('tontine_members')
      .where('tontineId', isEqualTo: tontineId)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList()
        ..sort((a, b) => ((a['payoutPosition'] as num?) ?? 999).compareTo((b['payoutPosition'] as num?) ?? 999)));

  static Stream<List<Map<String, dynamic>>> cycles(String tontineId) => _db
      .collection('tontine_cycles')
      .where('tontineId', isEqualTo: tontineId)
      .orderBy('number')
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  static Stream<List<Map<String, dynamic>>> cycleContributions(String tontineId, String cycleId) => _db
      .collection('tontine_contributions')
      .where('tontineId', isEqualTo: tontineId)
      .where('cycleId', isEqualTo: cycleId)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  static Stream<List<Map<String, dynamic>>> payouts(String tontineId) => _db
      .collection('tontine_payouts')
      .where('tontineId', isEqualTo: tontineId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  static Stream<List<Map<String, dynamic>>> disputes(String tontineId) => _db
      .collection('tontine_disputes')
      .where('tontineId', isEqualTo: tontineId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  static Future<String> createTontine({
    required String name,
    required String description,
    required String rules,
    required int contributionAmount,
    required String currency,
    required String frequency,
    required int membersLimit,
    required String payoutOrderMethod,
    required DateTime startDate,
  }) async {
    final r = await FinanceService.call('tontineCreate', {
      'name': name,
      if (description.isNotEmpty) 'description': description,
      if (rules.isNotEmpty) 'rules': rules,
      'contributionAmount': contributionAmount,
      'currency': currency,
      'frequency': frequency,
      'membersLimit': membersLimit,
      'payoutOrderMethod': payoutOrderMethod,
      'startDate': _day(startDate),
    });
    return r['tontineId'].toString();
  }

  static Future<void> invite(String tontineId, String email) => FinanceService.call('tontineInvite', {'tontineId': tontineId, 'email': email});

  static Future<void> respondToInvite(String tontineId, bool accept) => FinanceService.call('tontineRespondInvite', {'tontineId': tontineId, 'accept': accept});

  static Future<void> setPayoutOrder(String tontineId, List<String> order) => FinanceService.call('tontineSetPayoutOrder', {'tontineId': tontineId, 'order': order});

  static Future<void> start(String tontineId) => FinanceService.call('tontineStart', {'tontineId': tontineId});

  static Future<Map<String, dynamic>> contributeToTontine(String tontineId, String cycleId, Map<String, dynamic> payment, String requestKey) =>
      FinanceService.call('tontineContribute', {'tontineId': tontineId, 'cycleId': cycleId, 'payment': payment, 'idempotencyKey': requestKey});

  static Future<void> approvePayout(String payoutId) => FinanceService.call('tontineApprovePayout', {'payoutId': payoutId});

  static Future<void> raiseDispute(String tontineId, {required String subject, required String description, String? againstUserId}) =>
      FinanceService.call('tontineRaiseDispute', {
        'tontineId': tontineId,
        'subject': subject,
        'description': description,
        if (againstUserId != null) 'againstUserId': againstUserId,
      });
}

/// One idempotency key per intended operation. A retry of the SAME request
/// (same action, target, amount and payment) - after a lost answer, a
/// timeout, an app restart of the screen - reuses the key until the request
/// succeeds, so the server can never run it twice; any other request gets a
/// new key. [intent] names the request, e.g.
/// `savings.contribute:<goalId>:<amount>:<method>:<number>`.
abstract final class FinanceRequestKeys {
  static final Map<String, String> _open = {};

  /// The key for [intent]: the open one, else a new one.
  static String of(String intent) => _open.putIfAbsent(intent, FinanceGroupService.newRequestKey);

  /// [intent] succeeded: a later request of it is a new operation.
  static void done(String intent) => _open.remove(intent);

  /// The intent of a payment step: [action], its [target], [amount] and the
  /// chosen [payment] (method and number).
  /// Sends [send] with the key of its intent (action, target, amount,
  /// payment): a retry of the same request reuses the key until the server
  /// has answered, so it can never be paid twice.
  static Future<T> send<T>(String action, String target, int amount, Map<String, dynamic> payment, Future<T> Function(String key) send) async {
    final String intent = intentOf(action, target, amount, payment);
    final T reply = await send(of(intent));
    done(intent);
    return reply;
  }

  static String intentOf(String action, String target, int amount, Map<String, dynamic> payment) =>
      '$action:$target:$amount:${payment['method'] ?? ''}:${payment['number'] ?? ''}';
}

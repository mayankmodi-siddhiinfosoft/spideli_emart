import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/service/finance_region_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/service/push_message.dart';
import 'package:customer/service/send_notification.dart';
import 'package:customer/utils/finance_group_rules.dart';
import 'package:customer/utils/finance_region_rules.dart';
import 'package:customer/utils/finance_security_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:intl/intl.dart' show DateFormat;

/// Savings goals and tontines for the customer app
/// (.claude/FINANCE-APP-CONTRACT.md sections 8-9). The user's own steps are
/// written to Firestore directly (.claude/FINANCE-DIRECT-FIRESTORE.md 3.6,
/// 3.7) - planned as data by [SavingsWrites] / [TontineWrites], checked by
/// the security rules - and every money movement is a ledger posting in the
/// same batch or transaction. Everything is re-read from the server before it
/// is written, and documents that must exist once have a deterministic id
/// (or a request key, [FinanceRequestKeys]): a retry after a lost answer finds
/// the first result instead of paying twice. Queries are shaped so the
/// security rules can prove the user may read them (each is constrained to
/// the user or to a group the user belongs to).
abstract final class FinanceGroupService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get _uid => FinanceService.uid;

  static DateTime? toDate(dynamic v) => v is Timestamp ? v.toDate() : null;

  /// An idempotency key for one confirmed request: a retried or doubled call
  /// with the same key can never pay twice (the first result is found again).
  static String newRequestKey() {
    final r = Random.secure();
    return '${DateTime.now().millisecondsSinceEpoch}-${List.generate(12, (_) => r.nextInt(36).toRadixString(36)).join()}';
  }

  /// The intent of a funded request for [FinanceRequestKeys]: each gateway
  /// payment is its own request (one posting per payment).
  static Map<String, dynamic> _intentOf(FinanceFunding f) => {'method': f.method, 'number': f.reference ?? ''};

  /// The funding alone (the pay sheet hands a richer object).
  static FinanceFunding _funding(FinanceFunding f) => f.isWallet ? const FinanceFunding.wallet() : FinanceFunding.gateway(f.method, f.reference);

  static String _signedIn() => _uid.isEmpty ? throw const FinanceException('sign_in_required') : _uid;

  static String get _myName => (Constant.userModel?.fullName() ?? '').trim();

  /// Runs [action]; a write the security rules refuse becomes `permission_denied`.
  static Future<T> _write<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw const FinanceException('permission_denied');
      rethrow;
    }
  }

  static Future<void> _commit(List<FinanceWrite> writes) async {
    final batch = _db.batch();
    FinanceLedger.apply(batch, writes, db: _db);
    await batch.commit();
  }

  static void _applyTx(Transaction tx, Iterable<FinanceWrite> writes) {
    for (final w in writes) {
      final ref = _db.doc(w.path);
      switch (w.op) {
        case 'create':
          tx.set(ref, w.data);
        case 'update':
          tx.update(ref, w.data);
        default:
          tx.set(ref, w.data, SetOptions(merge: true));
      }
    }
  }

  /// A document as stored now, or null when it does not exist - or cannot
  /// be read yet (the rules let a user read a record of theirs, not one
  /// that does not exist): a write that would repeat it is refused anyway.
  static Future<Map<String, dynamic>?> _existing(String path) async {
    try {
      final s = await _db.doc(path).get(const GetOptions(source: Source.server));
      return s.data() == null ? null : {...s.data()!, 'id': s.id};
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'not-found') return null;
      rethrow;
    }
  }

  /// Whether the wallet [walletId] (of another user: a payout's
  /// beneficiary) exists, so the posting creates it or credits it. When the
  /// rules let only its owner read an existing wallet, a refusal means it
  /// exists.
  static Future<bool> _walletExists(String walletId) async {
    try {
      return await FinanceLedger.exists(walletId, db: _db);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return true;
      rethrow;
    }
  }

  /// How a payment is made: `{ method: 'wallet' }` or
  /// `{ method: 'mobile_money' | 'wave', operator?, number }`.
  static Map<String, dynamic> paymentOf(String method, {String? operator, String? number}) => {
        'method': method,
        if (operator != null && operator.isNotEmpty) 'operator': operator,
        if (number != null && number.isNotEmpty) 'number': number,
      };

  // ── Configuration ─────────────────────────────────────────────────────

  /// The savings settings of [regionId] (a goal's own region), else of the
  /// customer's Finance region (`finance_settings/{regionId}_savings`).
  static Future<SavingsConfig?> savingsConfig({String? regionId}) async => SavingsConfig.parse(await FinanceRegion.settings(FinanceModules.savings, regionId: regionId));

  /// The tontine settings of [regionId] (a tontine's own region), else of
  /// the customer's Finance region (`finance_settings/{regionId}_tontines`).
  static Future<TontineConfig?> tontineConfig({String? regionId}) async => TontineConfig.parse(await FinanceRegion.settings(FinanceModules.tontines, regionId: regionId));

  /// The region of a stored goal or tontine (its own), else the customer's:
  /// its postings carry it.
  static String? _regionOf(String regionId) => regionId.isNotEmpty ? regionId : FinanceRegion.currentId;

  // ── Savings goals ─────────────────────────────────────────────────────

  static Stream<List<SavingsGoal>> myGoals() => _db
      .collection('savings_goals')
      .where('memberIds', arrayContains: _uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => SavingsGoal.fromMap({...d.data(), 'id': d.id}, toDate)).toList());

  /// Group goals the user is invited to (still open).
  static Stream<List<SavingsGoal>> goalInvitations() => _db
      .collection('savings_goals')
      .where('invitedIds', arrayContains: _uid)
      .snapshots()
      .map((s) => s.docs.map((d) => SavingsGoal.fromMap({...d.data(), 'id': d.id}, toDate)).where((g) => g.isActive).toList());

  static Stream<SavingsGoal?> goal(String goalId) =>
      _db.collection('savings_goals').doc(goalId).snapshots().map((s) => s.data() == null ? null : SavingsGoal.fromMap({...s.data()!, 'id': s.id}, toDate));

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

  /// A goal as stored now (members and invitees may read it).
  static Future<SavingsGoal> _goalNow(String goalId) async {
    final g = await _existing('savings_goals/$goalId');
    if (g == null) throw const FinanceException('invalid_state');
    return SavingsGoal.fromMap(g, toDate);
  }

  /// Creates a goal (and its ledger account). Invitations go only to
  /// existing Spideli accounts, found by email: an unknown address is
  /// refused with `recipient_not_found` (details `email`) and nothing is
  /// written. A retry after a lost answer finds the goal it created.
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
  }) =>
      _write(() async {
        final String uid = _signedIn();
        // An "all services" restriction (or one naming savings) stops new
        // goals; money already saved stays the user's to add to or withdraw.
        if (FinanceRestriction.blocks(await _me(), 'savings')) throw const FinanceException('finance_restricted');
        final String regionId = await FinanceRegion.require();
        final cfg = await savingsConfig(regionId: regionId);
        if (cfg == null || !cfg.purposes.contains(purpose) || !cfg.currencies.contains(currency)) throw const FinanceException('invalid_state');
        if (targetAmount <= 0 || (scheduleAmount ?? 0) < 0) throw const FinanceException('amount_out_of_range');
        final emails = inviteEmails.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet().toList();
        if (emails.isNotEmpty && !cfg.groupGoals) throw const FinanceException('invalid_state');
        if (emails.length + 1 > cfg.maxMembers) throw const FinanceException('group_full');
        final invitees = <FinancePerson>[];
        for (final e in emails) {
          final p = await FinancePeople.byEmail(e);
          if (p == null) throw FinanceException('recipient_not_found', {'email': e});
          if (p.uid == uid) throw FinanceException('invite_self', {'email': e});
          invitees.add(p);
        }
        return FinanceRequestKeys.send('savings.create', '$name/$purpose/$currency', targetAmount, {'method': emails.join(',')}, (key) async {
          final String goalId = key;
          final existing = await _existing('savings_goals/$goalId');
          if (existing != null && existing['ownerId'] == uid) return goalId;
          await _commit(FinanceRegion.stamp(SavingsWrites.create(
            goalId: goalId,
            uid: uid,
            name: name,
            purpose: purpose,
            description: description,
            targetAmount: targetAmount,
            currency: currency,
            deadline: deadline,
            frequency: frequency,
            scheduleAmount: scheduleAmount,
            invitedIds: [for (final p in invitees) p.uid],
          ), regionId));
          FinancePeople.push('savings_invite', [for (final p in invitees) p.uid], {'goalId': goalId}, {'goalName': name, 'inviterName': _myName});
          return goalId;
        });
      });

  /// The owner's changes (name, description, deadline, schedule).
  static Future<void> updateGoal(String goalId, {String? name, String? description, DateTime? deadline, String? frequency, int? scheduleAmount, bool clearSchedule = false}) =>
      _write(() async {
        final String uid = _signedIn();
        final g = await _goalNow(goalId);
        if (g.ownerId != uid) throw const FinanceException('permission_denied');
        if (!g.isActive) throw const FinanceException('invalid_state');
        await _commit(SavingsWrites.update(goalId,
            name: name, description: description, deadline: deadline, frequency: frequency, scheduleAmount: scheduleAmount, clearSchedule: clearSchedule));
      });

  /// The owner invites the Spideli account of [email] (`invitedIds`).
  static Future<void> inviteToGoal(String goalId, String email) => _write(() async {
        final String uid = _signedIn();
        final g = await _goalNow(goalId);
        final cfg = await savingsConfig(regionId: _regionOf(g.regionId));
        if (cfg == null) throw const FinanceException('invalid_state');
        final p = await FinancePeople.byEmail(email);
        if (p == null) throw FinanceException('recipient_not_found', {'email': email});
        final String? blocker = SavingsWrites.inviteBlocker(g, cfg, uid, p.uid);
        if (blocker != null) throw FinanceException(blocker, {'email': email});
        await _commit(SavingsWrites.invite(goalId, p.uid));
        FinancePeople.push('savings_invite', [p.uid], {'goalId': goalId}, {'goalName': g.name, 'inviterName': _myName});
      });

  /// The invitee joins ([accept]) or declines.
  static Future<void> respondToGoalInvite(String goalId, bool accept) => _write(() async {
        final String uid = _signedIn();
        if (accept && FinanceRestriction.blocks(await _me(), 'savings')) throw const FinanceException('finance_restricted');
        final g = await _goalNow(goalId);
        // Already answered (a retry after a lost answer).
        if (!g.invitedIds.contains(uid) && g.memberIds.contains(uid) == accept) return;
        final String? blocker = SavingsWrites.respondBlocker(g, accept ? await savingsConfig(regionId: _regionOf(g.regionId)) : null, uid, accept);
        if (blocker != null) throw FinanceException(blocker);
        await _commit(SavingsWrites.respond(goalId, uid, accept));
      });

  /// Adds [amount] to the goal from the user's wallet, or from a payment a
  /// gateway has just taken ([funding]): the contribution (`succeeded`), its
  /// posting and the goal's `savedAmount`, in one batch. A wallet payment
  /// needs the balance. The contribution's id is the request key: a retry
  /// of the same request finds it instead of paying twice. The reply is the
  /// pay sheet's (`status: succeeded`, `reference`).
  static Future<Map<String, dynamic>> contributeToGoal(String goalId, int amount, FinanceFunding payment) => _write(
        () => FinanceRequestKeys.send('savings.contribute', goalId, amount, _intentOf(payment), (key) async {
          final FinanceFunding funding = _funding(payment);
          final String uid = _signedIn();
          final done = await _existing('savings_contributions/$key');
          if (done != null) return {'status': 'succeeded', 'reference': done['reference']};
          final g = await _goalNow(goalId);
          final String? blocker = SavingsWrites.contributeBlocker(g, uid, amount);
          if (blocker != null) throw FinanceException(blocker);
          String walletId = FinanceLedger.walletId(uid, g.currency);
          if (funding.isWallet) {
            final w = await FinanceLedger.wallet(uid, g.currency, db: _db);
            if (!w.exists || w.balance < amount) throw const FinanceException('insufficient_funds');
            walletId = w.id;
          }
          final p = SavingsWrites.contribute(goal: g, contributionId: key, uid: uid, amount: amount, walletId: walletId, funding: funding);
          await _commit(FinanceRegion.stamp(p.writes, _regionOf(g.regionId)));
          return {'status': 'succeeded', 'reference': p.reference};
        }),
      );

  /// Withdraws [amount] to the user's wallet. A solo goal's owner gets it at
  /// once (`completed`); in a group goal the request (`requested`) waits for
  /// the admin, who applies the group's rules. Reply: `status`
  /// (`completed` / `requested`) and `reference`.
  static Future<Map<String, dynamic>> requestWithdrawal(String goalId, int amount, {String? reason}) => _write(
        () => FinanceRequestKeys.send('savings.withdraw', goalId, amount, const {'method': 'wallet'}, (key) async {
          final String uid = _signedIn();
          final done = await _existing('savings_withdrawals/$key');
          if (done != null) return {'status': done['status'], 'reference': done['reference']};
          final g = await _goalNow(goalId);
          final String? blocker = SavingsWrites.withdrawBlocker(g, await savingsConfig(regionId: _regionOf(g.regionId)), uid, amount);
          if (blocker != null) throw FinanceException(blocker);
          final w = await FinanceLedger.wallet(uid, g.currency, db: _db);
          final p = SavingsWrites.withdraw(goal: g, withdrawalId: key, uid: uid, amount: amount, walletId: w.id, walletExists: w.exists, reason: reason ?? '');
          await _commit(FinanceRegion.stamp(p.writes, _regionOf(g.regionId)));
          return {'status': g.isSolo ? 'completed' : 'requested', 'reference': p.reference};
        }),
      );

  /// The owner cancels: a solo goal returns its balance to the owner's
  /// wallet and closes (`cancelled`); a group goal asks the admin
  /// (`cancellation_requested`). Returns the goal's new status.
  static Future<String> cancelGoal(String goalId) => _write(() async {
        final String uid = _signedIn();
        final g = await _goalNow(goalId);
        // Already done (a retry after a lost answer).
        if (g.ownerId == uid && (g.status == 'cancelled' || g.status == 'cancellation_requested')) return g.status;
        final String? blocker = SavingsWrites.cancelBlocker(g, uid);
        if (blocker != null) throw FinanceException(blocker);
        final w = await FinanceLedger.wallet(uid, g.currency, db: _db);
        await _commit(FinanceRegion.stamp(SavingsWrites.cancel(goal: g, uid: uid, walletId: w.id, walletExists: w.exists).writes, _regionOf(g.regionId)));
        return g.isSolo ? 'cancelled' : 'cancellation_requested';
      });

  // ── Tontines ──────────────────────────────────────────────────────────

  static Stream<List<Tontine>> myTontines() => _db
      .collection('tontines')
      .where('memberIds', arrayContains: _uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Tontine.fromMap({...d.data(), 'id': d.id}, toDate)).toList());

  /// The user's pending invitations (`tontine_members`, status `invited`).
  static Stream<List<Map<String, dynamic>>> tontineInvitations() => _db
      .collection('tontine_members')
      .where('userId', isEqualTo: _uid)
      .where('status', isEqualTo: 'invited')
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  static Stream<Tontine?> tontine(String id) =>
      _db.collection('tontines').doc(id).snapshots().map((s) => s.data() == null ? null : Tontine.fromMap({...s.data()!, 'id': s.id}, toDate));

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
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

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
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

  static Stream<List<Map<String, dynamic>>> disputes(String tontineId) => _db
      .collection('tontine_disputes')
      .where('tontineId', isEqualTo: tontineId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  /// The user's own `users/{uid}` as stored now (its `financeRestriction`).
  static Future<Map<String, dynamic>?> _me() => _existing('users/${_signedIn()}');

  /// A tontine as stored now (its active members may read it).
  static Future<Tontine> _tontineNow(String tontineId) async {
    final t = await _existing('tontines/$tontineId');
    if (t == null) throw const FinanceException('invalid_state');
    return Tontine.fromMap(t, toDate);
  }

  static Future<List<Map<String, dynamic>>> _membersNow(String tontineId) async {
    final s = await _db.collection('tontine_members').where('tontineId', isEqualTo: tontineId).get(const GetOptions(source: Source.server));
    return [for (final d in s.docs) {...d.data(), 'id': d.id}];
  }

  /// Creates a tontine (`forming`), the creator's admin membership and the
  /// pot account. Refused while the user is restricted for tontines. A retry
  /// after a lost answer finds the tontine it created.
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
  }) =>
      _write(() async {
        final String uid = _signedIn();
        final String? restricted = TontineWrites.restrictionBlocker(await _me());
        if (restricted != null) throw FinanceException(restricted);
        final String regionId = await FinanceRegion.require();
        final cfg = await tontineConfig(regionId: regionId);
        if (cfg == null ||
            !cfg.currencies.contains(currency) ||
            !cfg.frequencies.contains(frequency) ||
            !cfg.payoutOrderMethods.contains(payoutOrderMethod) ||
            membersLimit < cfg.minMembers ||
            membersLimit > cfg.maxMembers) {
          throw const FinanceException('invalid_state');
        }
        if (contributionAmount < cfg.minFor(currency)) throw const FinanceException('below_minimum');
        return FinanceRequestKeys.send('tontine.create', '$name/$currency/$frequency/$membersLimit', contributionAmount, {'method': payoutOrderMethod}, (key) async {
          final String tontineId = key;
          final existing = await _existing('tontines/$tontineId');
          if (existing != null && existing['createdBy'] == uid) return tontineId;
          await _commit(FinanceRegion.stamp(TontineWrites.create(
            tontineId: tontineId,
            uid: uid,
            displayName: _myName,
            email: Constant.userModel?.email ?? '',
            name: name,
            description: description,
            rules: rules,
            contributionAmount: contributionAmount,
            currency: currency,
            frequency: frequency,
            membersLimit: membersLimit,
            payoutOrderMethod: payoutOrderMethod,
            startDate: startDate,
          ), regionId));
          return tontineId;
        });
      });

  /// An admin invites the Spideli account of [email]: its member document
  /// (`invited`) carries the tontine's terms.
  static Future<void> invite(String tontineId, String email) => _write(() async {
        final String uid = _signedIn();
        final t = await _tontineNow(tontineId);
        final members = await _membersNow(tontineId);
        final p = await FinancePeople.byEmail(email);
        if (p == null) throw FinanceException('recipient_not_found', {'email': email});
        final String? blocker = TontineWrites.inviteBlocker(t, uid, p.uid, members);
        if (blocker != null) throw FinanceException(blocker, {'email': email});
        final bool again = members.any((m) => m['userId'] == p.uid);
        await _commit(TontineWrites.invite(t: t, inviterUid: uid, inviterName: _myName, inviteeUid: p.uid, inviteeName: p.name, inviteeEmail: p.email, again: again));
        FinancePeople.push('tontine_invite', [p.uid], {'tontineId': tontineId}, {'tontineName': t.name, 'inviterName': _myName});
      });

  /// The invitee joins ([accept]: own membership `active`, `memberIds` +=
  /// self) or declines. Joining is refused while restricted for tontines,
  /// and once the tontine is full or has started (`invitation_closed`).
  static Future<void> respondToInvite(String tontineId, bool accept) => _write(() async {
        final String uid = _signedIn();
        if (accept) {
          final String? restricted = TontineWrites.restrictionBlocker(await _me());
          if (restricted != null) throw FinanceException(restricted);
        }
        final m = await _existing('tontine_members/${TontineWrites.memberId(tontineId, uid)}');
        // Already answered (a retry after a lost answer).
        if (m != null && m['status'] == (accept ? 'active' : 'declined')) return;
        if (m == null || m['status'] != 'invited') throw const FinanceException('invalid_state');
        try {
          await _commit(TontineWrites.respond(tontineId, uid, accept));
        } on FirebaseException catch (e) {
          // The invitee cannot read the tontine: a refusal of the join means it is full or has started.
          if (accept && e.code == 'permission-denied') throw const FinanceException('invitation_closed');
          rethrow;
        }
      });

  /// The admin's payout order (fixed order, while forming): exactly the active members.
  static Future<void> setPayoutOrder(String tontineId, List<String> order) => _write(() async {
        final String uid = _signedIn();
        final t = await _tontineNow(tontineId);
        if (!t.isAdmin(uid)) throw const FinanceException('permission_denied');
        if (!t.isForming || t.payoutOrderMethod != 'fixed') throw const FinanceException('invalid_state');
        if (order.length != t.memberIds.length || !t.memberIds.every(order.contains)) throw const FinanceException('invalid_state');
        await _commit(TontineWrites.payoutOrder(tontineId, order));
      });

  /// An admin starts the tontine: the order (saved, or drawn now for a
  /// random one), `active`, and every cycle. Members, amount and order are
  /// then fixed.
  static Future<void> start(String tontineId) => _write(() async {
        final String uid = _signedIn();
        final t = await _tontineNow(tontineId);
        final cfg = await tontineConfig(regionId: _regionOf(t.regionId));
        if (cfg == null) throw const FinanceException('invalid_state');
        // Already started (a retry after a lost answer).
        if (t.isAdmin(uid) && t.isActive) return;
        final active = (await _membersNow(tontineId)).where((m) => m['status'] == 'active' && t.memberIds.contains(m['userId'])).toList();
        final bool random = t.payoutOrderMethod == 'random';
        final positioned = active.where((m) => m['payoutPosition'] is num).toList()..sort((a, b) => (a['payoutPosition'] as num).compareTo(b['payoutPosition'] as num));
        final List<String> order = random ? TontineWrites.draw(t.memberIds) : [for (final m in positioned) m['userId'].toString()];
        final String? blocker = TontineActions.startBlocker(t, uid, cfg, order);
        if (blocker != null) throw const FinanceException('invalid_state');
        // Positions 1..n in the order the cycles follow (drawn, or a saved order with gaps).
        final bool rewrite = random || [for (final (i, m) in positioned.indexed) (m['payoutPosition'] as num).toInt() == i + 1].contains(false);
        final now = DateTime.now();
        await _commit(TontineWrites.start(t: t, order: order, now: now, drawn: rewrite));
        final first = TontineWrites.firstDue(t, now);
        FinancePeople.push('tontine_started', t.memberIds, {'tontineId': tontineId}, {'tontineName': t.name, 'firstDueDate': DateFormat('dd MMM yyyy').format(first)});
      });

  /// Pays the member's contribution to the collecting cycle [cycleId] from
  /// the wallet, or from a payment a gateway has just taken ([funding]), in
  /// one transaction: the contribution `{cycleId}_{uid}` (once per cycle
  /// and member), its posting and the cycle's `collectedAmount` - and, when
  /// it completes the pot, the payout awaiting the admins' approval. A retry
  /// finds the contribution instead of paying twice.
  static Future<Map<String, dynamic>> contributeToTontine(String tontineId, String cycleId, FinanceFunding payment) => _write(() async {
        final String uid = _signedIn();
        final FinanceFunding funding = _funding(payment);
        final String id = TontineWrites.contributionId(cycleId, uid);
        final done = await _existing('tontine_contributions/$id');
        if (done != null && done['status'] == 'paid') return {'status': 'succeeded', 'reference': done['reference']};
        final t0 = await _tontineNow(tontineId);
        String walletId = FinanceLedger.walletId(uid, t0.currency);
        if (funding.isWallet) {
          final w = await FinanceLedger.wallet(uid, t0.currency, db: _db);
          if (!w.exists || w.balance < t0.contributionAmount) throw const FinanceException('insufficient_funds');
          walletId = w.id;
        }
        try {
          final r = await _db.runTransaction((tx) async {
            final ts = await tx.get(_db.doc('tontines/$tontineId'));
            final cs = await tx.get(_db.doc('tontine_cycles/$cycleId'));
            if (ts.data() == null || cs.data() == null) throw const FinanceException('invalid_state');
            final t = Tontine.fromMap({...ts.data()!, 'id': ts.id}, toDate);
            final cycle = {...cs.data()!, 'id': cs.id};
            final String? blocker = TontineWrites.contributeBlocker(t, cycle, uid);
            if (blocker != null) throw FinanceException(blocker);
            final p = TontineWrites.contribute(t: t, cycle: cycle, uid: uid, walletId: walletId, funding: funding);
            _applyTx(tx, FinanceRegion.stamp(p.writes, _regionOf(t.regionId)));
            final bool completes = p.writes.any((w) => w.path.startsWith('tontine_payouts/'));
            return (reference: p.reference, completes: completes, t: t, cycle: cycle);
          });
          if (r.completes) {
            final String beneficiary = r.cycle['beneficiaryUserId']?.toString() ?? '';
            final b = await FinancePeople.byId(beneficiary);
            FinancePeople.push('tontine_payout_pending_approval', r.t.adminIds.where((a) => a != beneficiary), {'tontineId': tontineId, 'cycleId': cycleId}, {
              'tontineName': r.t.name,
              'beneficiaryName': b?.name ?? '',
              'amount': FinanceMoney.format(FinanceSummary.intOf(r.cycle['expectedAmount']), r.t.currency),
            });
          }
          return {'status': 'succeeded', 'reference': r.reference};
        } on FirebaseException catch (e) {
          // Refused because it was already paid (a lost answer): that payment is the result.
          if (e.code == 'permission-denied') {
            final again = await _existing('tontine_contributions/$id');
            if (again != null && again['status'] == 'paid') return {'status': 'succeeded', 'reference': again['reference']};
          }
          rethrow;
        }
      });

  /// An admin approves a payout awaiting approval: the pot pays the
  /// beneficiary's wallet, the cycle is paid and the next one opens (or the
  /// tontine completes), in one transaction. The beneficiary never approves
  /// their own payout (`payout_self_approval`): another admin does, or
  /// Spideli when they are the only one.
  static Future<void> approvePayout(String payoutId) => _write(() async {
        final String uid = _signedIn();
        final p0 = await _existing('tontine_payouts/$payoutId');
        if (p0 == null) throw const FinanceException('invalid_state');
        // Already paid (a retry after a lost answer, or another admin approved it).
        if (p0['status'] == 'paid') return;
        final String tontineId = p0['tontineId'].toString();
        final t0 = await _tontineNow(tontineId);
        final String? blocker0 = TontineWrites.approveBlocker(t0, p0, uid);
        if (blocker0 != null) throw FinanceException(blocker0);
        final String beneficiary = p0['beneficiaryUserId'].toString();
        final int number = FinanceSummary.intOf(p0['cycleNumber']);
        final cycles = await _db.collection('tontine_cycles').where('tontineId', isEqualTo: tontineId).get(const GetOptions(source: Source.server));
        final next = cycles.docs.where((d) => FinanceSummary.intOf(d.data()['number']) == number + 1).firstOrNull;
        final String walletId = FinanceLedger.walletId(beneficiary, t0.currency);
        final bool walletExists = await _walletExists(walletId);
        final r = await _db.runTransaction((tx) async {
          final ps = await tx.get(_db.doc('tontine_payouts/$payoutId'));
          final ts = await tx.get(_db.doc('tontines/$tontineId'));
          final ns = next == null ? null : await tx.get(next.reference);
          if (ps.data() == null || ts.data() == null) throw const FinanceException('invalid_state');
          final t = Tontine.fromMap({...ts.data()!, 'id': ts.id}, toDate);
          final payout = {...ps.data()!, 'id': ps.id};
          final String? blocker = TontineWrites.approveBlocker(t, payout, uid);
          if (blocker != null) throw FinanceException(blocker);
          if (FinanceSummary.intOf(payout['cycleNumber']) != t.currentCycle) throw const FinanceException('invalid_state');
          final p = TontineWrites.approvePayout(
            t: t,
            payout: payout,
            nextCycle: ns?.data() == null ? null : {...ns!.data()!, 'id': ns.id},
            approverUid: uid,
            walletId: walletId,
            walletExists: walletExists,
          );
          _applyTx(tx, FinanceRegion.stamp(p.writes, _regionOf(t.regionId)));
          return (t: t, amount: FinanceSummary.intOf(payout['amount']));
        });
        FinancePeople.push('tontine_payout_paid', [beneficiary], {'tontineId': tontineId, 'payoutId': payoutId}, {
          'tontineName': r.t.name,
          'amount': FinanceMoney.format(r.amount, r.t.currency),
        });
      });

  /// An active member raises a dispute (`open`) for the admins.
  static Future<void> raiseDispute(String tontineId, {required String subject, required String description, String? againstUserId}) => _write(() async {
        final String uid = _signedIn();
        final t = await _tontineNow(tontineId);
        if (!t.memberIds.contains(uid)) throw const FinanceException('permission_denied');
        await FinanceRequestKeys.send('tontine.dispute', '$tontineId/${againstUserId ?? ''}/$subject', description.length, const {'method': 'dispute'}, (key) async {
          if (await _existing('tontine_disputes/$key') != null) return;
          await _commit(TontineWrites.dispute(disputeId: key, tontineId: tontineId, uid: uid, subject: subject, description: description, againstUserId: againstUserId));
          FinancePeople.push('tontine_dispute_raised', t.adminIds, {'tontineId': tontineId, 'disputeId': key}, {'tontineName': t.name, 'subject': subject});
        });
      });
}

/// A Spideli account as the finance groups need it: found by email, named,
/// reached by push (`users/{uid}`, readable by signed-in users).
class FinancePerson {
  final String uid;
  final String name;
  final String email;
  final String token;

  const FinancePerson({required this.uid, required this.name, required this.email, required this.token});

  static FinancePerson of(String uid, Map<String, dynamic> m) {
    final String name = '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim();
    final String email = (m['email'] ?? '').toString().trim();
    return FinancePerson(uid: uid, name: name.isNotEmpty ? name : email, email: email, token: (m['fcmToken'] ?? '').toString());
  }
}

/// People lookups and pushes for savings goals, tontines and their chats.
abstract final class FinancePeople {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static final Map<String, FinancePerson> _cache = {};

  /// The Spideli account of [email] (a customer account first), or null.
  static Future<FinancePerson?> byEmail(String email) async {
    final String e = email.trim().toLowerCase();
    if (e.isEmpty) return null;
    final s = await _db.collection('users').where('email', isEqualTo: e).limit(5).get();
    if (s.docs.isEmpty) return null;
    final d = s.docs.where((d) => (d.data()['role'] ?? 'customer') == 'customer').firstOrNull ?? s.docs.first;
    return _cache[d.id] = FinancePerson.of(d.id, d.data());
  }

  /// The account [uid] (cached for the session), or null.
  static Future<FinancePerson?> byId(String uid) async {
    if (uid.isEmpty) return null;
    final cached = _cache[uid];
    if (cached != null) return cached;
    try {
      final s = await _db.collection('users').doc(uid).get();
      return s.data() == null ? null : _cache[uid] = FinancePerson.of(uid, s.data()!);
    } catch (_) {
      return null;
    }
  }

  /// The name of [uid] when already known (no read).
  static String? cachedName(String uid) => _cache[uid]?.name;

  /// Sends the `dynamic_notification` template [type] to each of [uids]
  /// (never the user themselves). Best effort: a missing token or a failed
  /// send is only logged.
  static void push(String type, Iterable<String> uids, Map<String, dynamic> payload, Map<String, String> placeholders) {
    final String me = FinanceService.uid;
    final targets = uids.where((u) => u.isNotEmpty && u != me).toSet();
    unawaited(Future.wait([
      for (final u in targets)
        () async {
          try {
            final p = await byId(u);
            if (p == null || p.token.isEmpty) return;
            await SendNotification.sendFcmMessage(type, p.token, {'type': type, ...payload}, recipient: PushRecipient.customer, placeholders: placeholders);
          } catch (_) {}
        }(),
    ]));
  }
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

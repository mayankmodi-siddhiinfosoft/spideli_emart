import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/utils/finance_group_rules.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime? _d(dynamic v) => v is DateTime ? v : null;

/// The savings-goal writes the customer app makes itself
/// (.claude/FINANCE-DIRECT-FIRESTORE.md 3.6): every batch as data, money
/// only as balanced postings.
void main() {
  SavingsGoal goal({List<String> members = const ['o'], List<String> invited = const [], int saved = 30000, int target = 100000, String status = 'active'}) =>
      SavingsGoal.fromMap({
        'id': 'g1',
        'name': 'Trip',
        'purpose': 'travel',
        'ownerId': 'o',
        'memberIds': members,
        'invitedIds': invited,
        'currency': 'XAF',
        'targetAmount': target,
        'savedAmount': saved,
        'status': status,
      }, _d);
  final cfg = SavingsConfig.parse({
    'purposes': ['travel'],
    'currencies': ['XAF'],
    'groupGoals': true,
    'maxMembers': 3,
    'earlyWithdrawal': {'allowed': false},
    'paymentMethods': ['wallet'],
  })!;
  final early = SavingsConfig.parse({
    'purposes': ['travel'],
    'currencies': ['XAF'],
    'groupGoals': true,
    'maxMembers': 3,
    'earlyWithdrawal': {'allowed': true},
    'paymentMethods': ['wallet'],
  })!;

  FinanceWrite one(List<FinanceWrite> ws, String path) => ws.singleWhere((w) => w.path == path);
  Map<String, dynamic> tx(List<FinanceWrite> ws) => ws.singleWhere((w) => w.path.startsWith('ledger_transactions/')).data;
  List<Map<String, dynamic>> lines(List<FinanceWrite> ws) => List<Map<String, dynamic>>.from(tx(ws)['lines'] as List);

  /// Each account once per batch, and every ledger line has its account's balance change.
  void balanced(List<FinanceWrite> ws) {
    final accounts = ws.where((w) => w.path.startsWith('financial_accounts/')).map((w) => w.path).toList();
    expect(accounts.toSet().length, accounts.length, reason: 'an account appears once per batch');
    final l = lines(ws);
    final int debits = l.where((x) => x['direction'] == 'debit').fold(0, (s, x) => s + (x['amount'] as int));
    final int credits = l.where((x) => x['direction'] == 'credit').fold(0, (s, x) => s + (x['amount'] as int));
    expect(debits, credits);
    for (final x in l) {
      expect(accounts, contains('financial_accounts/${x['accountId']}'));
    }
  }

  group('create, invite, answer, edit', () {
    test('the goal (active, nothing saved, the owner its only member) and its empty account', () {
      final ws = SavingsWrites.create(
        goalId: 'g1',
        uid: 'o',
        name: 'Trip',
        purpose: 'travel',
        description: '',
        targetAmount: 100000,
        currency: 'XAF',
        deadline: DateTime(2027, 6, 30, 15),
        frequency: 'monthly',
        scheduleAmount: 10000,
        invitedIds: const ['a', 'b', 'a', 'o'],
      );
      final g = one(ws, 'savings_goals/g1');
      expect(g.op, 'create');
      expect(g.data['ownerId'], 'o');
      expect(g.data['memberIds'], ['o']);
      expect(g.data['invitedIds'], ['a', 'b'], reason: 'no duplicate, never the owner');
      expect(g.data['savedAmount'], 0);
      expect(g.data['status'], 'active');
      expect(g.data['accountId'], 'goal_g1');
      expect(g.data['deadline'], Timestamp.fromDate(DateTime(2027, 6, 30)));
      expect(g.data['schedule'], {'frequency': 'monthly', 'amount': 10000});
      final a = one(ws, 'financial_accounts/goal_g1');
      expect(a.op, 'create');
      expect(a.data['kind'], 'savings_goal');
      expect(a.data['refId'], 'g1');
      expect(a.data['balance'], 0);
      expect(a.data['memberIds'], ['o']);
      expect(ws.where((w) => w.path.startsWith('ledger_transactions/')), isEmpty, reason: 'no money moves');
    });

    test('invite and answer move the user between invitedIds and memberIds', () {
      expect(SavingsWrites.invite('g1', 'a').single.data['invitedIds'], FieldValue.arrayUnion(['a']));
      final yes = SavingsWrites.respond('g1', 'a', true).single.data;
      expect(yes['invitedIds'], FieldValue.arrayRemove(['a']));
      expect(yes['memberIds'], FieldValue.arrayUnion(['a']));
      expect(SavingsWrites.respond('g1', 'a', false).single.data.containsKey('memberIds'), isFalse);
    });

    test('who may invite and join', () {
      expect(SavingsWrites.inviteBlocker(goal(), cfg, 'o', 'a'), isNull);
      expect(SavingsWrites.inviteBlocker(goal(), cfg, 'x', 'a'), 'permission_denied', reason: 'the owner only');
      expect(SavingsWrites.inviteBlocker(goal(), cfg, 'o', 'o'), 'invite_self');
      expect(SavingsWrites.inviteBlocker(goal(invited: const ['a']), cfg, 'o', 'a'), 'already_member');
      expect(SavingsWrites.inviteBlocker(goal(members: const ['o', 'b'], invited: const ['c']), cfg, 'o', 'a'), 'group_full');
      expect(SavingsWrites.inviteBlocker(goal(status: 'cancelled'), cfg, 'o', 'a'), 'invalid_state');
      expect(SavingsWrites.respondBlocker(goal(invited: const ['a']), cfg, 'a', true), isNull);
      expect(SavingsWrites.respondBlocker(goal(), cfg, 'a', true), 'invalid_state', reason: 'not invited');
      expect(SavingsWrites.respondBlocker(goal(members: const ['o', 'b', 'c'], invited: const ['a']), cfg, 'a', true), 'group_full');
      expect(SavingsWrites.respondBlocker(goal(members: const ['o', 'b', 'c'], invited: const ['a']), null, 'a', false), isNull, reason: 'declining is always possible');
    });

    test('edit: only the given fields; a removed schedule is deleted', () {
      final w = SavingsWrites.update('g1', name: 'Trip 2', clearSchedule: true).single;
      expect(w.op, 'update');
      expect(w.data['name'], 'Trip 2');
      expect(w.data['schedule'], FieldValue.delete());
      expect(w.data.keys.toSet(), {'name', 'schedule', 'updatedAt'});
    });
  });

  group('contribute', () {
    test('from the wallet: contribution succeeded, posting wallet -> goal, savedAmount += amount', () {
      final p = SavingsWrites.contribute(goal: goal(), contributionId: 'k1', uid: 'o', amount: 5000, walletId: 'wallet_o_XAF', funding: const FinanceFunding.wallet());
      final ws = p.writes;
      balanced(ws);
      final c = one(ws, 'savings_contributions/k1');
      expect(c.op, 'create');
      expect(c.data['status'], 'succeeded');
      expect(c.data['amount'], 5000);
      expect(c.data['txId'], p.txId);
      expect(c.data['reference'], p.reference);
      expect(lines(ws).first, {'accountId': 'wallet_o_XAF', 'direction': 'debit', 'amount': 5000});
      expect(lines(ws)[1], {'accountId': 'goal_g1', 'direction': 'credit', 'amount': 5000});
      expect(tx(ws)['type'], 'savings_contribution');
      expect(tx(ws)['source'], {'kind': 'savings_contributions', 'id': 'k1'});
      final g = one(ws, 'savings_goals/g1');
      expect(g.data['savedAmount'], FieldValue.increment(5000));
      expect(g.data['lastTxId'], p.txId, reason: 'the posting that moved savedAmount');
    });

    test('from a gateway payment: the platform account pays, one receipt', () {
      final p = SavingsWrites.contribute(
          goal: goal(), contributionId: 'k2', uid: 'o', amount: 5000, walletId: 'wallet_o_XAF', funding: const FinanceFunding.gateway('stripe', 'pi_1'));
      balanced(p.writes);
      expect(lines(p.writes).first['accountId'], 'platform_XAF');
      expect(p.writes.where((w) => w.path == 'payment_receipts/stripe_pi_1'), hasLength(1));
      expect(one(p.writes, 'savings_contributions/k2').data['gateway'], {'method': 'stripe', 'reference': 'pi_1'});
      expect(p.writes.where((w) => w.path == 'financial_accounts/wallet_o_XAF'), isEmpty);
    });

    test('members of an active goal only', () {
      expect(SavingsWrites.contributeBlocker(goal(), 'o', 1000), isNull);
      expect(SavingsWrites.contributeBlocker(goal(), 'x', 1000), 'permission_denied');
      expect(SavingsWrites.contributeBlocker(goal(status: 'cancelled'), 'o', 1000), 'invalid_state');
      expect(SavingsWrites.contributeBlocker(goal(), 'o', 0), 'amount_out_of_range');
    });
  });

  group('withdraw', () {
    test('solo goal: completed at once, posting goal -> own wallet (created when missing), savedAmount -= amount', () {
      final p = SavingsWrites.withdraw(goal: goal(), withdrawalId: 'w1', uid: 'o', amount: 10000, walletId: 'wallet_o_XAF', walletExists: false);
      balanced(p.writes);
      final w = one(p.writes, 'savings_withdrawals/w1');
      expect(w.data['status'], 'completed');
      expect(w.data['txId'], p.txId);
      expect(lines(p.writes).first, {'accountId': 'goal_g1', 'direction': 'debit', 'amount': 10000});
      final wallet = one(p.writes, 'financial_accounts/wallet_o_XAF');
      expect(wallet.op, 'create');
      expect(wallet.data['userId'], 'o');
      expect(wallet.data['balance'], 10000);
      expect(one(p.writes, 'savings_goals/g1').data['savedAmount'], FieldValue.increment(-10000));
      expect(tx(p.writes)['type'], 'savings_withdrawal');
    });

    test('group goal: a request for the admin, no money moves', () {
      final p = SavingsWrites.withdraw(goal: goal(members: const ['o', 'a']), withdrawalId: 'w2', uid: 'a', amount: 10000, walletId: 'wallet_a_XAF', walletExists: true, reason: ' school fees ');
      expect(p.writes.length, 1);
      final w = p.writes.single;
      expect(w.path, 'savings_withdrawals/w2');
      expect(w.data['status'], 'requested');
      expect(w.data['reason'], 'school fees');
      expect(w.data['destination'], {'method': 'wallet', 'accountId': 'wallet_a_XAF'});
    });

    test('rules: early only when allowed, never more than saved, a solo goal by its owner', () {
      expect(SavingsWrites.withdrawBlocker(goal(), cfg, 'o', 1000), 'withdrawal_not_allowed', reason: 'target not reached, no early withdrawal');
      expect(SavingsWrites.withdrawBlocker(goal(), early, 'o', 1000), isNull);
      expect(SavingsWrites.withdrawBlocker(goal(saved: 100000), cfg, 'o', 1000), isNull, reason: 'target reached');
      expect(SavingsWrites.withdrawBlocker(goal(), early, 'o', 30001), 'insufficient_funds');
      expect(SavingsWrites.withdrawBlocker(goal(), early, 'x', 1000), 'permission_denied');
      expect(SavingsWrites.withdrawBlocker(goal(members: const ['o', 'a']), early, 'a', 1000), isNull, reason: 'a group member may ask');
    });
  });

  group('cancel', () {
    test('solo goal: the whole balance back to the wallet, then cancelled', () {
      final p = SavingsWrites.cancel(goal: goal(), uid: 'o', walletId: 'wallet_o_XAF', walletExists: true);
      balanced(p.writes);
      expect(lines(p.writes).first, {'accountId': 'goal_g1', 'direction': 'debit', 'amount': 30000});
      expect(tx(p.writes)['source'], {'kind': 'savings_goals', 'id': 'g1'});
      final g = one(p.writes, 'savings_goals/g1');
      expect(g.data['status'], 'cancelled');
      expect(g.data['savedAmount'], FieldValue.increment(-30000));
      expect(one(p.writes, 'financial_accounts/wallet_o_XAF').op, 'update');
    });

    test('solo goal with nothing saved: only the status', () {
      final p = SavingsWrites.cancel(goal: goal(saved: 0), uid: 'o', walletId: 'wallet_o_XAF', walletExists: true);
      expect(p.writes.single.data['status'], 'cancelled');
    });

    test('group goal: a cancellation request for the admin', () {
      final p = SavingsWrites.cancel(goal: goal(members: const ['o', 'a']), uid: 'o', walletId: 'wallet_o_XAF', walletExists: true);
      expect(p.writes.single.data['status'], 'cancellation_requested');
      expect(p.writes.single.data['cancellationRequestedBy'], 'o');
      expect(SavingsWrites.cancelBlocker(goal(), 'a'), 'permission_denied');
      expect(SavingsWrites.cancelBlocker(goal(status: 'cancellation_requested'), 'o'), 'invalid_state');
    });
  });

  group('progress over time', () {
    final now = DateTime(2026, 10, 14);
    test('month by month, anchored on the balance now', () {
      final months = SavingsProgress.monthly(
        [DatedAmount(DateTime(2026, 8, 3), 10000), DatedAmount(DateTime(2026, 8, 20), 5000), DatedAmount(DateTime(2026, 10, 1), 20000)],
        [DatedAmount(DateTime(2026, 9, 9), 3000)],
        32000,
        now,
      );
      expect(months.map((m) => m.month), [DateTime(2026, 8), DateTime(2026, 9), DateTime(2026, 10)]);
      expect(months.map((m) => m.added), [15000, 0, 20000]);
      expect(months.map((m) => m.withdrawn), [0, 3000, 0]);
      expect(months.map((m) => m.savedAtEnd), [15000, 12000, 32000]);
    });

    test('older movements not loaded: the series still ends on the balance', () {
      final months = SavingsProgress.monthly([DatedAmount(DateTime(2026, 10, 2), 1000)], const [], 51000, now);
      expect(months.single.savedAtEnd, 51000);
      expect(SavingsProgress.monthly(const [], const [], 0, now), isEmpty);
    });

    test('at most the last [months]', () {
      final months = SavingsProgress.monthly([DatedAmount(DateTime(2024, 1, 1), 1000), DatedAmount(DateTime(2026, 10, 1), 1000)], const [], 2000, now, months: 6);
      expect(months.length, 6);
      expect(months.first.month, DateTime(2026, 5));
      expect(months.first.savedAtEnd, 1000);
    });
  });
}

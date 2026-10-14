import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/utils/finance_group_rules.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime? _d(dynamic v) => v is DateTime ? v : (v is Timestamp ? v.toDate() : null);

/// The tontine writes the customer app makes itself
/// (.claude/FINANCE-DIRECT-FIRESTORE.md 3.7): deterministic ids, money only
/// as balanced postings, the last contribution opening the payout.
void main() {
  Tontine t({String status = 'active', List<String> members = const ['a', 'b', 'c'], List<String> admins = const ['a'], DateTime? start, String freq = 'monthly', int current = 1}) =>
      Tontine.fromMap({
        'id': 't1',
        'name': 'Family',
        'rules': 'Pay on time',
        'currency': 'XAF',
        'contributionAmount': 5000,
        'frequency': freq,
        'membersLimit': 4,
        'payoutOrderMethod': 'fixed',
        'status': status,
        'adminIds': admins,
        'memberIds': members,
        'currentCycle': current,
        'startDate': start ?? DateTime(2026, 11, 1),
      }, _d);

  FinanceWrite one(List<FinanceWrite> ws, String path) => ws.singleWhere((w) => w.path == path);
  Map<String, dynamic> tx(List<FinanceWrite> ws) => ws.singleWhere((w) => w.path.startsWith('ledger_transactions/')).data;
  List<Map<String, dynamic>> lines(List<FinanceWrite> ws) => List<Map<String, dynamic>>.from(tx(ws)['lines'] as List);

  test('ids: one member, cycle, contribution and payout document each', () {
    expect(TontineWrites.memberId('t1', 'u'), 't1_u');
    expect(TontineWrites.cycleId('t1', 2), 't1_2');
    expect(TontineWrites.contributionId('t1_2', 'u'), 't1_2_u');
    expect(TontineWrites.payoutId('t1_2'), 't1_2');
  });

  test('create: the tontine (forming), the creator\'s admin membership and the empty pot', () {
    final ws = TontineWrites.create(
      tontineId: 't1',
      uid: 'a',
      displayName: 'Awa',
      email: 'awa@x.com',
      name: 'Family',
      description: '',
      rules: '',
      contributionAmount: 5000,
      currency: 'XAF',
      frequency: 'monthly',
      membersLimit: 4,
      payoutOrderMethod: 'fixed',
      startDate: DateTime(2026, 11, 1, 9),
    );
    final tontine = one(ws, 'tontines/t1');
    expect(tontine.op, 'create');
    expect(tontine.data['status'], 'forming');
    expect(tontine.data['adminIds'], ['a']);
    expect(tontine.data['memberIds'], ['a']);
    expect(tontine.data['createdBy'], 'a');
    expect(tontine.data['potAccountId'], 'tontine_t1');
    expect(tontine.data['startDate'], Timestamp.fromDate(DateTime(2026, 11, 1)));
    final m = one(ws, 'tontine_members/t1_a');
    expect(m.data['role'], 'admin');
    expect(m.data['status'], 'active');
    expect(m.data['payoutPosition'], 1);
    final pot = one(ws, 'financial_accounts/tontine_t1');
    expect(pot.data['kind'], 'tontine_pot');
    expect(pot.data['refId'], 't1');
    expect(pot.data['balance'], 0);
  });

  group('invite and answer', () {
    test('the invitation carries the terms the invitee reads before joining', () {
      final w = TontineWrites.invite(t: t(status: 'forming'), inviterUid: 'a', inviterName: 'Awa', inviteeUid: 'd', inviteeName: 'Dio', inviteeEmail: 'd@x.com').single;
      expect(w.path, 'tontine_members/t1_d');
      expect(w.op, 'create');
      expect(w.data['status'], 'invited');
      expect(w.data['tontineName'], 'Family');
      expect(w.data['invitedBy'], 'a');
      expect(w.data['invitedByName'], 'Awa');
      for (final k in ['contributionAmount', 'currency', 'frequency', 'membersLimit', 'startDate', 'rules']) {
        expect(w.data.containsKey(k), isTrue, reason: 'term $k');
      }
      expect(TontineWrites.invite(t: t(status: 'forming'), inviterUid: 'a', inviterName: 'Awa', inviteeUid: 'd', inviteeName: 'Dio', inviteeEmail: 'd@x.com', again: true).single.op, 'update',
          reason: 'a declined invitation is renewed');
    });

    test('who may be invited', () {
      final forming = t(status: 'forming');
      final members = [
        {'userId': 'a', 'status': 'active'},
        {'userId': 'b', 'status': 'invited'},
        {'userId': 'c', 'status': 'declined'},
        {'userId': 'r', 'status': 'restricted'},
      ];
      expect(TontineWrites.inviteBlocker(forming, 'a', 'c', members), isNull, reason: 'declined: invited again');
      expect(TontineWrites.inviteBlocker(forming, 'a', 'b', members), 'already_member');
      expect(TontineWrites.inviteBlocker(forming, 'a', 'a', members), 'invite_self');
      expect(TontineWrites.inviteBlocker(forming, 'a', 'r', members), 'permission_denied');
      expect(TontineWrites.inviteBlocker(forming, 'b', 'd', members), 'permission_denied', reason: 'an admin only');
      expect(TontineWrites.inviteBlocker(t(), 'a', 'd', members), 'invalid_state', reason: 'members are fixed once started');
      expect(TontineWrites.inviteBlocker(forming, 'a', 'd', [...members, {'userId': 'e', 'status': 'active'}, {'userId': 'f', 'status': 'invited'}]), 'group_full');
    });

    test('accept: own membership active and memberIds += self; decline: declined only', () {
      final yes = TontineWrites.respond('t1', 'd', true);
      expect(one(yes, 'tontine_members/t1_d').data['status'], 'active');
      expect(one(yes, 'tontines/t1').data['memberIds'], FieldValue.arrayUnion(['d']));
      final no = TontineWrites.respond('t1', 'd', false);
      expect(no.single.data['status'], 'declined');
    });

    test('a restriction for tontines (or all) blocks creating and joining', () {
      expect(TontineWrites.restrictionBlocker(null), isNull);
      expect(TontineWrites.restrictionBlocker({'financeRestriction': {'status': 'lifted', 'scopes': ['all']}}), isNull);
      expect(TontineWrites.restrictionBlocker({'financeRestriction': {'status': 'restricted', 'scopes': ['loans']}}), isNull);
      expect(TontineWrites.restrictionBlocker({'financeRestriction': {'status': 'restricted', 'scopes': ['tontines']}}), 'finance_restricted');
      expect(TontineWrites.restrictionBlocker({'financeRestriction': {'status': 'restricted', 'scopes': ['all']}}), 'finance_restricted');
      expect(TontineWrites.restrictionBlocker({'financeRestriction': {'status': 'restricted'}}), 'finance_restricted', reason: 'no scope: everything');
    });
  });

  group('order and start', () {
    test('payout order: positions 1..n', () {
      final ws = TontineWrites.payoutOrder('t1', ['c', 'a', 'b']);
      expect([for (final w in ws) w.path], ['tontine_members/t1_c', 'tontine_members/t1_a', 'tontine_members/t1_b']);
      expect([for (final w in ws) w.data['payoutPosition']], [1, 2, 3]);
    });

    test('a random order is a draw of the members', () {
      final drawn = TontineWrites.draw(['a', 'b', 'c', 'd'], Random(7));
      expect(drawn.toSet(), {'a', 'b', 'c', 'd'});
      expect(drawn.length, 4);
    });

    test('start: active, cycle 1 collecting, one cycle per member with its beneficiary and due date', () {
      final now = DateTime(2026, 10, 14);
      final ws = TontineWrites.start(t: t(status: 'forming', start: DateTime(2027, 1, 31)), order: const ['c', 'a', 'b'], now: now);
      final tontine = one(ws, 'tontines/t1');
      expect(tontine.data['status'], 'active');
      expect(tontine.data['currentCycle'], 1);
      expect(tontine.data['nextDueAt'], Timestamp.fromDate(DateTime(2027, 1, 31)));
      expect(tontine.data.containsKey('startDate'), isFalse, reason: 'the agreed date has not passed');
      final cycles = ws.where((w) => w.path.startsWith('tontine_cycles/')).toList();
      expect(cycles.map((w) => w.path), ['tontine_cycles/t1_1', 'tontine_cycles/t1_2', 'tontine_cycles/t1_3']);
      expect(cycles.every((w) => w.op == 'create'), isTrue);
      expect(cycles.map((w) => w.data['beneficiaryUserId']), ['c', 'a', 'b']);
      expect(cycles.map((w) => w.data['status']), ['collecting', 'upcoming', 'upcoming']);
      expect(cycles.map((w) => w.data['expectedAmount']).toSet(), {15000});
      expect(cycles.map((w) => w.data['collectedAmount']).toSet(), {0});
      expect(cycles.map((w) => (w.data['dueDate'] as Timestamp).toDate()), [DateTime(2027, 1, 31), DateTime(2027, 2, 28), DateTime(2027, 3, 28)]);
      expect(ws.where((w) => w.path.startsWith('tontine_members/')), isEmpty, reason: 'a saved order is kept');
    });

    test('a start after the agreed date starts today; a drawn order is saved', () {
      final ws = TontineWrites.start(t: t(status: 'forming', start: DateTime(2026, 9, 1)), order: const ['b', 'c', 'a'], now: DateTime(2026, 10, 14, 18), drawn: true);
      expect(one(ws, 'tontines/t1').data['startDate'], Timestamp.fromDate(DateTime(2026, 10, 14)));
      expect(one(ws, 'tontine_cycles/t1_1').data['dueDate'], Timestamp.fromDate(DateTime(2026, 10, 14)));
      expect(one(ws, 'tontine_members/t1_b').data['payoutPosition'], 1);
      expect(one(ws, 'tontine_members/t1_a').data['payoutPosition'], 3);
    });
  });

  group('contribute', () {
    Map<String, dynamic> cycle({int collected = 0}) => {
          'id': 't1_1',
          'tontineId': 't1',
          'number': 1,
          'beneficiaryUserId': 'c',
          'expectedAmount': 15000,
          'collectedAmount': collected,
          'status': 'collecting',
        };

    test('one contribution per cycle and member, posting wallet -> pot, collectedAmount += amount', () {
      final p = TontineWrites.contribute(t: t(), cycle: cycle(), uid: 'a', walletId: 'wallet_a_XAF', funding: const FinanceFunding.wallet());
      final c = one(p.writes, 'tontine_contributions/t1_1_a');
      expect(c.op, 'create');
      expect(c.data['status'], 'paid');
      expect(c.data['amount'], 5000);
      expect(c.data['cycleId'], 't1_1');
      expect(c.data['txId'], p.txId);
      expect(lines(p.writes), [
        {'accountId': 'wallet_a_XAF', 'direction': 'debit', 'amount': 5000},
        {'accountId': 'tontine_t1', 'direction': 'credit', 'amount': 5000},
      ]);
      expect(tx(p.writes)['type'], 'tontine_contribution');
      final cy = one(p.writes, 'tontine_cycles/t1_1');
      expect(cy.data['collectedAmount'], FieldValue.increment(5000));
      expect(cy.data['lastTxId'], p.txId);
      expect(cy.data.containsKey('status'), isFalse);
      expect(p.writes.where((w) => w.path.startsWith('tontine_payouts/')), isEmpty);
    });

    test('the contribution that completes the pot opens the payout for approval', () {
      final p = TontineWrites.contribute(t: t(), cycle: cycle(collected: 10000), uid: 'b', walletId: 'wallet_b_XAF', funding: const FinanceFunding.gateway('orange_money', 'OM9'));
      expect(one(p.writes, 'tontine_cycles/t1_1').data['status'], 'payout_pending');
      final payout = one(p.writes, 'tontine_payouts/t1_1');
      expect(payout.op, 'create');
      expect(payout.data['status'], 'pending_approval');
      expect(payout.data['beneficiaryUserId'], 'c');
      expect(payout.data['amount'], 15000);
      expect(lines(p.writes).first['accountId'], 'platform_XAF', reason: 'a gateway payment');
      expect(p.writes.where((w) => w.path == 'payment_receipts/orange_money_OM9'), hasLength(1));
    });

    test('an active member, while the cycle collects', () {
      expect(TontineWrites.contributeBlocker(t(), cycle(), 'a'), isNull);
      expect(TontineWrites.contributeBlocker(t(), cycle(), 'z'), 'permission_denied');
      expect(TontineWrites.contributeBlocker(t(), {...cycle(), 'status': 'payout_pending'}, 'a'), 'invalid_state');
      expect(TontineWrites.contributeBlocker(t(status: 'suspended'), cycle(), 'a'), 'invalid_state');
    });
  });

  group('approve the payout', () {
    final payout = {'id': 't1_1', 'tontineId': 't1', 'cycleId': 't1_1', 'cycleNumber': 1, 'beneficiaryUserId': 'c', 'amount': 15000, 'status': 'pending_approval'};
    final next = {'id': 't1_2', 'number': 2, 'dueDate': Timestamp.fromDate(DateTime(2026, 12, 1))};

    test('pot -> beneficiary wallet, payout and cycle paid, next cycle collecting', () {
      final p = TontineWrites.approvePayout(t: t(), payout: payout, nextCycle: next, approverUid: 'a', walletId: 'wallet_c_XAF', walletExists: false);
      expect(lines(p.writes), [
        {'accountId': 'tontine_t1', 'direction': 'debit', 'amount': 15000},
        {'accountId': 'wallet_c_XAF', 'direction': 'credit', 'amount': 15000},
      ]);
      expect(tx(p.writes)['type'], 'tontine_payout');
      expect(tx(p.writes)['userIds'], ['c']);
      expect(tx(p.writes)['createdBy'], 'a');
      expect(one(p.writes, 'financial_accounts/wallet_c_XAF').op, 'create', reason: 'the beneficiary has no wallet yet');
      final po = one(p.writes, 'tontine_payouts/t1_1');
      expect(po.data['status'], 'paid');
      expect(po.data['approvedBy'], 'a');
      expect(po.data['txId'], p.txId);
      expect(one(p.writes, 'tontine_cycles/t1_1').data['status'], 'paid');
      expect(one(p.writes, 'tontine_cycles/t1_2').data['status'], 'collecting');
      final tt = one(p.writes, 'tontines/t1');
      expect(tt.data['currentCycle'], 2);
      expect(tt.data['nextDueAt'], next['dueDate']);
    });

    test('after the last cycle the tontine completes', () {
      final p = TontineWrites.approvePayout(t: t(current: 3), payout: {...payout, 'cycleNumber': 3}, nextCycle: null, approverUid: 'a', walletId: 'wallet_c_XAF', walletExists: true);
      final tt = one(p.writes, 'tontines/t1');
      expect(tt.data['status'], 'completed');
      expect(tt.data['nextDueAt'], FieldValue.delete());
      expect(one(p.writes, 'financial_accounts/wallet_c_XAF').op, 'update');
    });

    test('an admin approves; never the beneficiary their own payout', () {
      expect(TontineWrites.approveBlocker(t(), payout, 'a'), isNull);
      expect(TontineWrites.approveBlocker(t(), payout, 'b'), 'permission_denied', reason: 'not an admin');
      expect(TontineWrites.approveBlocker(t(admins: const ['a', 'c']), payout, 'c'), 'payout_self_approval');
      expect(TontineWrites.approveBlocker(t(), {...payout, 'status': 'paid'}, 'a'), 'invalid_state');
      expect(TontineWrites.waitsForSpideli(t(admins: const ['c']), payout), isTrue, reason: 'the beneficiary is the only admin');
      expect(TontineWrites.waitsForSpideli(t(admins: const ['a', 'c']), payout), isFalse);
      expect(TontineWrites.waitsForSpideli(t(), payout), isFalse);
    });
  });

  test('a dispute is open, raised by the member', () {
    final w = TontineWrites.dispute(disputeId: 'd1', tontineId: 't1', uid: 'b', subject: 'Late', description: 'Cycle 2 was not paid', againstUserId: 'c').single;
    expect(w.path, 'tontine_disputes/d1');
    expect(w.op, 'create');
    expect(w.data['status'], 'open');
    expect(w.data['raisedBy'], 'b');
    expect(w.data['againstUserId'], 'c');
    expect(TontineWrites.dispute(disputeId: 'd2', tontineId: 't1', uid: 'b', subject: 'S', description: 'D').single.data.containsKey('againstUserId'), isFalse);
  });

  test('invitations are offered while the tontine is forming only', () {
    expect(TontineActions.canInvite(t(status: 'forming'), 'a', 3), isTrue);
    expect(TontineActions.canInvite(t(), 'a', 3), isFalse);
  });
}

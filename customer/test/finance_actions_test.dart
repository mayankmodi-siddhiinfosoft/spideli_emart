import 'package:customer/utils/finance_actions.dart';
import 'package:customer/utils/finance_group_rules.dart';
import 'package:customer/utils/finance_lending_rules.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime? _d(dynamic v) => v is DateTime ? v : null;

/// The dashboard's "Needs your action" list.
void main() {
  const String me = 'me';
  final DateTime now = DateTime(2026, 10, 14, 12);
  Loan loan(String id, String status, {String borrower = 'b', DateTime? ends, int funded = 0}) => Loan.fromMap({
        'id': id,
        'borrowerId': borrower,
        'groupName': 'Family tontine',
        'status': status,
        'currency': 'XAF',
        'amount': 50000,
        'fundedAmount': funded,
        'eligibleVoterIds': [me, 'other'],
        'votingEndsAt': ends,
      }, _d);
  List<FinanceAction> collect({
    List<Map<String, dynamic>> invitations = const [],
    List<SavingsGoal> goals = const [],
    List<Loan> group = const [],
    Set<String> voted = const {},
    List<Loan> mine = const [],
    List<Map<String, dynamic>> quotes = const [],
    List<Map<String, dynamic>> claims = const [],
    List<Map<String, dynamic>> transfers = const [],
    List<Map<String, dynamic>> bills = const [],
  }) =>
      FinanceActions.collect(
        uid: me,
        now: now,
        tontineInvitations: invitations,
        goalInvitations: goals,
        groupLoans: group,
        votedLoanIds: voted,
        borrowed: mine,
        quotes: quotes,
        claims: claims,
        transfers: transfers,
        bills: bills,
        toDate: _d,
      );

  test('nothing to do: an empty list', () => expect(collect(), isEmpty));

  test('invitations to answer', () {
    final goal = SavingsGoal.fromMap({'id': 'g1', 'name': 'Trip', 'currency': 'XAF', 'targetAmount': 100, 'savedAmount': 0, 'memberIds': ['owner']}, _d);
    final a = collect(invitations: [
      {'tontineId': 't1', 'tontineName': 'Family tontine'}
    ], goals: [goal]);
    expect(a.map((x) => x.kind), [FinanceActionKind.tontineInvitation, FinanceActionKind.goalInvitation]);
    expect(a.first.id, 't1');
    expect(a.first.detail, 'Family tontine');
  });

  test('a loan vote only while voting is open and not yet voted; funding otherwise', () {
    expect(collect(group: [loan('l1', 'voting', ends: DateTime(2026, 10, 20))]).single.kind, FinanceActionKind.loanVote);
    expect(collect(group: [loan('l1', 'voting')], voted: {'l1'}), isEmpty);
    expect(collect(group: [loan('l1', 'voting', ends: DateTime(2026, 10, 13))]), isEmpty);
    expect(collect(group: [loan('l1', 'funding')]).single.kind, FinanceActionKind.loanFunding);
    // My own request is never mine to vote on.
    expect(collect(group: [loan('l1', 'voting', borrower: me)]), isEmpty);
  });

  test('my loan: the agreement to accept and an overdue repayment are urgent', () {
    final a = collect(mine: [loan('l1', 'agreement_pending', borrower: me), loan('l2', 'overdue', borrower: me), loan('l3', 'active', borrower: me)]);
    expect(a.map((x) => x.kind), [FinanceActionKind.loanAgreement, FinanceActionKind.loanOverdue]);
    expect(a.every((x) => x.urgent), isTrue);
  });

  test('a ready quote while it is valid; a claim waiting for information', () {
    final a = collect(quotes: [
      {'id': 'q1', 'status': 'quoted', 'productName': 'Health', 'validUntil': DateTime(2026, 10, 30)},
      {'id': 'q2', 'status': 'quoted', 'validUntil': DateTime(2026, 10, 1)},
      {'id': 'q3', 'status': 'accepted'},
    ], claims: [
      {'id': 'c1', 'status': 'info_requested', 'productName': 'Health'},
      {'id': 'c2', 'status': 'under_review'},
    ]);
    expect(a.map((x) => x.id), ['c1', 'q1']);
  });

  test('only my own transfers and bills to confirm, before they expire', () {
    final a = collect(transfers: [
      {'id': 't1', 'senderId': me, 'status': 'awaiting_confirmation', 'recipientName': 'Amina', 'expiresAt': DateTime(2026, 10, 14, 13)},
      {'id': 't2', 'senderId': 'someone', 'status': 'awaiting_confirmation'},
      {'id': 't3', 'senderId': me, 'status': 'awaiting_confirmation', 'expiresAt': DateTime(2026, 10, 14, 11)},
      {'id': 't4', 'senderId': me, 'status': 'completed'},
    ], bills: [
      {'id': 'b1', 'status': 'awaiting_confirmation', 'billerName': 'ENEO'},
    ]);
    expect(a.map((x) => x.id), ['t1', 'b1']);
    expect(a.first.detail, 'Amina');
  });

  test('urgent first, then the soonest due', () {
    final a = collect(
      quotes: [
        {'id': 'q-late', 'status': 'quoted', 'validUntil': DateTime(2026, 11, 30)},
        {'id': 'q-soon', 'status': 'quoted', 'validUntil': DateTime(2026, 10, 16)},
      ],
      mine: [loan('l1', 'overdue', borrower: me)],
    );
    expect(a.map((x) => x.id), ['l1', 'q-soon', 'q-late']);
  });
}

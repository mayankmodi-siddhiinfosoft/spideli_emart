import 'package:customer/utils/finance_group_rules.dart';
import 'package:customer/utils/finance_lending_rules.dart';
import 'package:customer/utils/finance_transfer_rules.dart';

/// What the user has to answer in Spideli Finance - the "Needs your action"
/// list of the dashboard - worked out from records the app already reads
/// (.claude/FINANCE-APP-CONTRACT.md). Pure, unit tested in
/// test/finance_actions_test.dart. The server re-checks every action.
enum FinanceActionKind {
  /// Accept or decline a tontine invitation (tontine_members, status invited).
  tontineInvitation,

  /// Join or decline a shared savings goal.
  goalInvitation,

  /// Vote on a group member's loan request (open voting, not voted yet).
  loanVote,

  /// A group loan is collecting funds (optional: lend if you wish).
  loanFunding,

  /// Accept the agreement of the user's own loan.
  loanAgreement,

  /// A repayment of the user's loan is overdue.
  loanOverdue,

  /// An insurance quote is ready to accept, while it is valid.
  insuranceQuote,

  /// The insurer asked for more information on a claim.
  claimInformation,

  /// A transfer the user started waits for its confirmation.
  transferConfirmation,

  /// A bill payment the user started waits for its confirmation.
  billConfirmation,
}

class FinanceAction {
  final FinanceActionKind kind;

  /// The record it is about (tontine, goal, loan, quote, claim, transfer...).
  final String id;

  /// What it is about, as stored (a name, a product, a recipient).
  final String detail;

  /// When it has to be done by, when known.
  final DateTime? dueAt;

  /// Blocking or costly when left (overdue, expiring confirmations).
  final bool urgent;

  const FinanceAction(this.kind, this.id, {this.detail = '', this.dueAt, this.urgent = false});

  /// The translation key of what to do.
  String get title => switch (kind) {
        FinanceActionKind.tontineInvitation => "Answer a tontine invitation",
        FinanceActionKind.goalInvitation => "Answer a savings goal invitation",
        FinanceActionKind.loanVote => "Vote on a loan request",
        FinanceActionKind.loanFunding => "A loan in your group is collecting funds",
        FinanceActionKind.loanAgreement => "Accept your loan agreement",
        FinanceActionKind.loanOverdue => "Loan repayment overdue",
        FinanceActionKind.insuranceQuote => "Your insurance quote is ready",
        FinanceActionKind.claimInformation => "The insurer needs more information",
        FinanceActionKind.transferConfirmation => "Confirm your transfer",
        FinanceActionKind.billConfirmation => "Confirm your bill payment",
      };

  @override
  String toString() => '${kind.name}($id)';
}

abstract final class FinanceActions {
  /// Every action, urgent ones first, then the soonest due.
  static List<FinanceAction> collect({
    required String uid,
    required DateTime now,
    List<Map<String, dynamic>> tontineInvitations = const [],
    List<SavingsGoal> goalInvitations = const [],
    List<Loan> groupLoans = const [],
    Set<String> votedLoanIds = const {},
    List<Loan> borrowed = const [],
    List<Map<String, dynamic>> quotes = const [],
    List<Map<String, dynamic>> claims = const [],
    List<Map<String, dynamic>> transfers = const [],
    List<Map<String, dynamic>> bills = const [],
    required DateTime? Function(dynamic value) toDate,
  }) {
    String text(dynamic v) => (v ?? '').toString().trim();
    final List<FinanceAction> all = [
      for (final i in tontineInvitations)
        FinanceAction(FinanceActionKind.tontineInvitation, text(i['tontineId']).isEmpty ? text(i['id']) : text(i['tontineId']), detail: text(i['tontineName'])),
      for (final g in goalInvitations) FinanceAction(FinanceActionKind.goalInvitation, g.id, detail: g.name),
      for (final l in groupLoans)
        if (LoanActions.canVote(l, uid, alreadyVoted: votedLoanIds.contains(l.id), now: now))
          FinanceAction(FinanceActionKind.loanVote, l.id, detail: l.groupName, dueAt: l.votingEndsAt)
        else if (LoanActions.canFund(l, uid))
          FinanceAction(FinanceActionKind.loanFunding, l.id, detail: l.groupName),
      for (final l in borrowed)
        if (LoanActions.canAcceptAgreement(l, uid))
          FinanceAction(FinanceActionKind.loanAgreement, l.id, detail: l.groupName, urgent: true)
        else if (l.status == 'overdue')
          FinanceAction(FinanceActionKind.loanOverdue, l.id, detail: l.groupName, urgent: true),
      for (final q in quotes)
        if (q['status'] == 'quoted' && (toDate(q['validUntil']) == null || now.isBefore(toDate(q['validUntil'])!)))
          FinanceAction(FinanceActionKind.insuranceQuote, text(q['id']), detail: text(q['productName']), dueAt: toDate(q['validUntil'])),
      for (final c in claims)
        if (c['status'] == 'info_requested') FinanceAction(FinanceActionKind.claimInformation, text(c['id']), detail: text(c['productName']), urgent: true),
      for (final t in transfers)
        if ((t['senderId'] == null || t['senderId'] == uid) && PaymentFlow.canConfirm(t['status']?.toString(), toDate(t['expiresAt']), now))
          FinanceAction(FinanceActionKind.transferConfirmation, text(t['id']), detail: text(t['recipientName']), dueAt: toDate(t['expiresAt']), urgent: true),
      for (final b in bills)
        if (PaymentFlow.canConfirm(b['status']?.toString(), toDate(b['expiresAt']), now))
          FinanceAction(FinanceActionKind.billConfirmation, text(b['id']), detail: text(b['billerName']), dueAt: toDate(b['expiresAt']), urgent: true),
    ];
    all.sort((a, b) {
      if (a.urgent != b.urgent) return a.urgent ? -1 : 1;
      final DateTime far = DateTime(9999);
      return (a.dueAt ?? far).compareTo(b.dueAt ?? far);
    });
    return all;
  }
}

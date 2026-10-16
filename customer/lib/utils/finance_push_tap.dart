import 'package:customer/utils/push_tap.dart';

/// The Finance screen a tapped push opens.
enum FinanceTapKind {
  kyc,
  walletOperation,
  wallet,
  transfer,
  transfers,
  bill,
  bills,
  goal,
  goals,
  tontine,
  tontines,
  loan,
  loans,
  fund,
  investments,
  quote,
  policy,
  claim,
  insurance,
  financing,
  financingList,
  opportunity,
  support,
}

/// Where a Spideli Finance push takes the customer (the admin panel's brief
/// of 16 Oct 2026, 2.3): its `data.type` is the template type, with the id
/// of its record. The Notification Center record carries the same `data`.
/// Pure (unit tested in test/finance_push_tap_test.dart).
abstract final class FinancePushTap {
  static String _id(Map<String, dynamic> data, String key) {
    final String v = PushTap.field(data, key);
    // A Firestore document id never contains '/'.
    return v.contains('/') ? '' : v;
  }

  /// The screen and the id it opens, or null when the push is not Finance's.
  /// A family without its id opens its list.
  static ({FinanceTapKind kind, String id})? targetOf(Map<String, dynamic> data) {
    final String type = PushTap.field(data, 'type');
    if (type.isEmpty) return null;
    ({FinanceTapKind kind, String id}) one(FinanceTapKind kind, String key, FinanceTapKind list) {
      final String id = _id(data, key);
      return id.isEmpty ? (kind: list, id: '') : (kind: kind, id: id);
    }

    if (type.startsWith('kyc_')) return (kind: FinanceTapKind.kyc, id: _id(data, 'applicationId'));
    if (type.startsWith('wallet_withdrawal_')) return one(FinanceTapKind.walletOperation, 'operationId', FinanceTapKind.wallet);
    if (const {'transfer_sent', 'transfer_reversed', 'transfer_received'}.contains(type)) return one(FinanceTapKind.transfer, 'transferId', FinanceTapKind.transfers);
    if (const {'bill_paid', 'bill_token', 'bill_reversed'}.contains(type)) return one(FinanceTapKind.bill, 'requestId', FinanceTapKind.bills);
    if (type.startsWith('savings_')) return one(FinanceTapKind.goal, 'goalId', FinanceTapKind.goals);
    if (type.startsWith('tontine_')) return one(FinanceTapKind.tontine, 'tontineId', FinanceTapKind.tontines);
    if (type.startsWith('loan_')) return one(FinanceTapKind.loan, 'loanId', FinanceTapKind.loans);
    if (type.startsWith('investment_')) return one(FinanceTapKind.fund, 'fundId', FinanceTapKind.investments);
    if (type.startsWith('insurance_claim_')) {
      final String claim = _id(data, 'claimId');
      if (claim.isNotEmpty) return (kind: FinanceTapKind.claim, id: claim);
      return one(FinanceTapKind.policy, 'policyId', FinanceTapKind.insurance);
    }
    if (type.startsWith('insurance_quote_')) return one(FinanceTapKind.quote, 'quoteId', FinanceTapKind.insurance);
    if (type.startsWith('insurance_')) return one(FinanceTapKind.policy, 'policyId', FinanceTapKind.insurance);
    if (type.startsWith('financing_')) return one(FinanceTapKind.financing, 'applicationId', FinanceTapKind.financingList);
    if (type == 'intelligence_new_match' || type == 'intelligence_interest_received') return one(FinanceTapKind.opportunity, 'opportunityId', FinanceTapKind.investments);
    if (type == 'support_ticket_resolved') return (kind: FinanceTapKind.support, id: _id(data, 'ticketId'));
    return null;
  }
}

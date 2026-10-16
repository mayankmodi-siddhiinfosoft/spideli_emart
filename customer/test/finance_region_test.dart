import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/utils/finance_push_tap.dart';
import 'package:customer/utils/finance_region_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spideli Finance per region (the admin panel's
/// APP-SPEC-FINANCE-REGION-SETTINGS): which region's settings apply, the
/// settings document, the regionId every request carries, and where a
/// Finance push opens (the admin's brief of 16 Oct 2026, 2.3).
void main() {
  group('the customer\'s Finance region', () {
    bool on(String id) => const {'yaounde', 'cameroun', 'india'}.contains(id);
    int zones(String id) => const {'cameroun': 5, 'yaounde': 1, 'douala': 1, 'india': 2}[id] ?? 0;

    test('the region resolved for the customer, when it offers Finance', () {
      final p = FinanceRegionRules.pick(candidates: ['yaounde'], offersFinance: on, zoneCount: zones);
      expect(p.status, FinanceRegionStatus.ready);
      expect(p.regionId, 'yaounde');
      expect(p.choices, ['yaounde']);
    });

    test('a region without financeEnabled offers no Finance (never another region of the country)', () {
      final p = FinanceRegionRules.pick(candidates: ['douala'], offersFinance: on, zoneCount: zones);
      expect(p.status, FinanceRegionStatus.notOffered);
      expect(p.regionId, isNull);
    });

    test('no region resolved: unresolved', () {
      expect(FinanceRegionRules.pick(candidates: const [], offersFinance: on).status, FinanceRegionStatus.unresolved);
    });

    test('several regions serve the place: the most specific (fewest zones), or the one the customer chose', () {
      final p = FinanceRegionRules.pick(candidates: ['cameroun', 'yaounde', 'douala'], offersFinance: on, zoneCount: zones);
      expect(p.regionId, 'yaounde');
      expect(p.choices, ['yaounde', 'cameroun']);
      final chosen = FinanceRegionRules.pick(candidates: ['cameroun', 'yaounde'], offersFinance: on, zoneCount: zones, remembered: 'cameroun');
      expect(chosen.regionId, 'cameroun');
      final stale = FinanceRegionRules.pick(candidates: ['cameroun', 'yaounde'], offersFinance: on, zoneCount: zones, remembered: 'india');
      expect(stale.regionId, 'yaounde', reason: 'a remembered region no longer around the customer is ignored');
    });

    test('a region in no zone sorts last; then by name', () {
      final p = FinanceRegionRules.pick(candidates: ['yaounde', 'x'], offersFinance: (_) => true, zoneCount: zones, name: (id) => id);
      expect(p.choices, ['yaounde', 'x']);
      final byName = FinanceRegionRules.pick(candidates: ['b', 'a'], offersFinance: (_) => true, name: (id) => id);
      expect(byName.regionId, 'a');
    });
  });

  group('settings documents', () {
    test('finance_settings/{regionId}_{module}', () {
      expect(FinanceRegionRules.settingsCollection, 'finance_settings');
      expect(FinanceRegionRules.settingsId('0UJDCiTISC58T7WhEAjg', FinanceModules.wallet), '0UJDCiTISC58T7WhEAjg_wallet');
      expect(FinanceModules.all, hasLength(12));
    });

    test('a document is used only for its own region and module; missing = not available', () {
      final doc = {'regionId': 'r1', 'module': 'wallet', 'currencies': ['XAF']};
      expect(FinanceRegionRules.settingsOf(doc, 'r1', 'wallet'), same(doc));
      expect(FinanceRegionRules.settingsOf(doc, 'r2', 'wallet'), isNull);
      expect(FinanceRegionRules.settingsOf(doc, 'r1', 'cards'), isNull);
      expect(FinanceRegionRules.settingsOf({'currencies': ['XAF']}, 'r1', 'wallet'), isNotNull, reason: 'the id names it');
      expect(FinanceRegionRules.settingsOf(null, 'r1', 'wallet'), isNull);
    });

    test('an unchanged document is the same (maps and lists by content)', () {
      expect(FinanceRegionRules.same({'a': [1, {'b': 2}]}, {'a': [1, {'b': 2}]}), isTrue);
      expect(FinanceRegionRules.same({'a': [1, {'b': 2}]}, {'a': [1, {'b': 3}]}), isFalse);
      expect(FinanceRegionRules.same({'a': 1}, {'a': 1, 'b': 1}), isFalse);
      expect(FinanceRegionRules.same(null, {'a': 1}), isFalse);
      expect(FinanceRegionRules.same(null, null), isTrue);
    });
  });

  group('regionId on requests', () {
    final posting = FinanceLedger.plan(
      type: 'transfer',
      currency: 'XAF',
      from: 'wallet_u_XAF',
      to: 'wallet_v_XAF',
      amount: 1000,
      userIds: ['u', 'v'],
      sourceKind: 'money_transfers',
      sourceId: 't1',
      createdBy: 'u',
    );
    final writes = [
      const FinanceWrite('money_transfers/t1', 'create', {'id': 't1', 'currency': 'XAF'}),
      ...posting.writes,
      FinanceWrite('transfer_beneficiaries/b1', 'create', {'userId': 'u', 'createdAt': FieldValue.serverTimestamp()}),
      const FinanceWrite('savings_goals/g1', 'update', {'name': 'x'}),
    ];

    test('every request and posting created carries the region; accounts, updates and other records do not', () {
      final out = FinanceRegionRules.stamp(writes, 'r1');
      Map<String, dynamic> at(String prefix) => out.firstWhere((w) => w.path.startsWith(prefix)).data;
      expect(at('money_transfers/')['regionId'], 'r1');
      expect(at('ledger_transactions/')['regionId'], 'r1');
      expect(out.where((w) => w.path.startsWith('financial_accounts/')).every((w) => !w.data.containsKey('regionId')), isTrue);
      expect(at('transfer_beneficiaries/').containsKey('regionId'), isFalse);
      expect(at('savings_goals/').containsKey('regionId'), isFalse, reason: 'an update never moves a record to another region');
    });

    test('every collection of the spec (3.4), the postings (3.5) and the financing project', () {
      for (final c in const [
        'wallet_operations',
        'money_transfers',
        'utility_payment_requests',
        'virtual_cards',
        'card_funding_requests',
        'savings_goals',
        'tontines',
        'loan_applications',
        'investment_subscriptions',
        'insurance_quotes',
        'financing_applications',
        'kyc_applications',
        'ledger_transactions',
        'financing_projects',
      ]) {
        expect(FinanceRegionRules.regionCollections, contains(c));
      }
    });

    test('a record that already names its region keeps it; no region, nothing changes', () {
      final own = FinanceRegionRules.stamp([const FinanceWrite('card_funding_requests/f1', 'create', {'regionId': 'card_region'})], 'r1');
      expect(own.single.data['regionId'], 'card_region');
      expect(FinanceRegionRules.stamp(writes, null).map((w) => w.data), writes.map((w) => w.data));
    });

    test('a stored record keeps its own region, else the customer\'s', () {
      expect(FinanceRegionRules.regionOf({'regionId': 'r2'}, 'r1'), 'r2');
      expect(FinanceRegionRules.regionOf({'regionId': ''}, 'r1'), 'r1');
      expect(FinanceRegionRules.regionOf(null, null), isNull);
    });
  });

  group('the balance card', () {
    final xaf = {'id': 'wallet_u_XAF', 'currency': 'XAF', 'balance': 245000};
    final inr = {'id': 'wallet_u_INR', 'currency': 'INR', 'balance': 500};

    test('the wallet in the region\'s currency comes first', () {
      expect(FinanceRegionRules.walletShown([xaf, inr], regionCurrency: 'INR', fallbackCurrency: 'XAF'), same(inr));
    });

    test('without one: the summary\'s currency, else the first wallet the customer holds', () {
      expect(FinanceRegionRules.walletShown([inr, xaf], regionCurrency: 'EUR', fallbackCurrency: 'XAF'), same(xaf));
      expect(FinanceRegionRules.walletShown([xaf], regionCurrency: 'INR'), same(xaf));
      expect(FinanceRegionRules.walletShown(const [], regionCurrency: 'INR'), isNull);
    });

    test('no wallet yet: 0 in the region\'s currency (never a fixed XAF)', () {
      expect(FinanceRegionRules.emptyCurrency(regionCurrency: 'INR', fallback: 'XAF'), 'INR');
      expect(FinanceRegionRules.emptyCurrency(regionCurrency: null, fallback: 'XOF'), 'XOF');
      expect(FinanceRegionRules.emptyCurrency(regionCurrency: '', fallback: null), 'XAF');
    });
  });

  group('a Finance push opens its record', () {
    ({FinanceTapKind kind, String id})? t(Map<String, dynamic> data) => FinancePushTap.targetOf(data);

    test('each family of the admin\'s brief with its id', () {
      expect(t({'type': 'kyc_approved', 'applicationId': 'a1'}), (kind: FinanceTapKind.kyc, id: 'a1'));
      expect(t({'type': 'wallet_withdrawal_completed', 'operationId': 'o1'}), (kind: FinanceTapKind.walletOperation, id: 'o1'));
      expect(t({'type': 'transfer_reversed', 'transferId': 't1'}), (kind: FinanceTapKind.transfer, id: 't1'));
      expect(t({'type': 'bill_token', 'requestId': 'r1'}), (kind: FinanceTapKind.bill, id: 'r1'));
      expect(t({'type': 'savings_withdrawal_rejected', 'goalId': 'g1'}), (kind: FinanceTapKind.goal, id: 'g1'));
      expect(t({'type': 'tontine_contribution_due', 'tontineId': 'tn', 'cycleId': 'tn_2'}), (kind: FinanceTapKind.tontine, id: 'tn'));
      expect(t({'type': 'loan_repayment_overdue', 'loanId': 'l1'}), (kind: FinanceTapKind.loan, id: 'l1'));
      expect(t({'type': 'investment_subscription_executed', 'fundId': 'f1'}), (kind: FinanceTapKind.fund, id: 'f1'));
      expect(t({'type': 'insurance_quote_ready', 'quoteId': 'q1'}), (kind: FinanceTapKind.quote, id: 'q1'));
      expect(t({'type': 'insurance_premium_overdue', 'policyId': 'p1'}), (kind: FinanceTapKind.policy, id: 'p1'));
      expect(t({'type': 'insurance_renewal_due', 'policyId': 'p1'}), (kind: FinanceTapKind.policy, id: 'p1'));
      expect(t({'type': 'insurance_claim_paid', 'claimId': 'c1', 'policyId': 'p1'}), (kind: FinanceTapKind.claim, id: 'c1'));
      expect(t({'type': 'financing_approved', 'applicationId': 'fa'}), (kind: FinanceTapKind.financing, id: 'fa'));
      expect(t({'type': 'intelligence_new_match', 'opportunityId': 'op'}), (kind: FinanceTapKind.opportunity, id: 'op'));
      expect(t({'type': 'support_ticket_resolved', 'ticketId': 'tk'}), (kind: FinanceTapKind.support, id: 'tk'));
    });

    test('without its id: the list of the service (investment reports: the funds)', () {
      expect(t({'type': 'investment_report_ready'}), (kind: FinanceTapKind.investments, id: ''));
      expect(t({'type': 'loan_repayment_due', 'loanId': 'a/b'}), (kind: FinanceTapKind.loans, id: ''));
      expect(t({'type': 'wallet_withdrawal_failed'}), (kind: FinanceTapKind.wallet, id: ''));
    });

    test('not a Finance push: null (the app\'s other pushes keep their routing)', () {
      expect(t({'type': 'admin_chat'}), isNull);
      expect(t({'type': 'provider_order', 'orderId': 'x'}), isNull);
      expect(t({'type': 'order_placed', 'orderId': 'x'}), isNull);
      expect(t(const {}), isNull);
    });
  });
}

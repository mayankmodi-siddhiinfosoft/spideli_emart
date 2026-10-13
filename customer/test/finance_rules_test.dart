import 'package:customer/utils/finance_rules.dart';
import 'package:customer/utils/finance_statement_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

/// The customer side of Spideli Finance mirrors the server's rules.
void main() {
  test('money formats integer minor units with the ISO exponent, like the server', () {
    expect(FinanceMoney.plain(1500000, 'XAF'), '1 500 000 XAF');
    expect(FinanceMoney.plain(1250, 'USD'), '12.50 USD');
    expect(FinanceMoney.plain(-5, 'EUR'), '-0.05 EUR');
    expect(FinanceMoney.plain(0, 'XOF'), '0 XOF');
    // Shown as one left-to-right unit inside Arabic text.
    expect(FinanceMoney.format(1500000, 'XAF'), '\u20661 500 000 XAF\u2069');
  });

  test('KYC status labels, tones and editability', () {
    expect(KycStatus.label('additional_info_required'), 'More information needed');
    expect(KycStatus.label(null), 'Not verified');
    expect(KycStatus.tone('approved'), 'success');
    expect(KycStatus.tone('rejected'), 'danger');
    expect(KycStatus.ownerMayEdit('draft'), isTrue);
    expect(KycStatus.ownerMayEdit('additional_info_required'), isTrue);
    expect(KycStatus.ownerMayEdit('under_review'), isFalse);
    expect(KycStatus.isOpen('submitted'), isTrue);
    expect(KycStatus.isOpen('approved'), isFalse);
  });

  final raw = {
    'documentTypes': {
      'national_id': {'sides': ['front', 'back']},
      'passport': {'sides': ['front']},
      'selfie': {'sides': ['front']},
      'business_registration': {'sides': ['front']},
    },
    'levels': {
      'basic': {'accountTypes': ['individual'], 'requiredDocuments': [{'anyOf': ['national_id', 'passport']}, {'anyOf': ['selfie']}]},
      'business': {'accountTypes': ['business'], 'requiredDocuments': [{'anyOf': ['business_registration']}]},
    },
    'allowedContentTypes': ['image/jpeg'],
    'maxFileBytes': 1000,
  };

  test('KYC settings: parsed, and missing groups as on the server', () {
    final s = KycSettings.parse(raw)!;
    expect(s.levelsFor('individual').map((l) => l.id), ['basic']);
    expect(s.levelsFor('business').map((l) => l.id), ['business']);
    expect(s.missingGroups('basic', const []), [['national_id', 'passport'], ['selfie']]);
    expect(s.missingGroups('basic', const [KycDocumentRef('national_id', 'front', 'uploaded'), KycDocumentRef('selfie', 'front', 'uploaded')]), [['national_id', 'passport']]);
    expect(s.missingGroups('basic', const [KycDocumentRef('passport', 'front', 'accepted'), KycDocumentRef('selfie', 'front', 'uploaded')]), isEmpty);
    expect(s.missingGroups('basic', const [KycDocumentRef('passport', 'front', 'superseded'), KycDocumentRef('selfie', 'front', 'uploaded')]), [['national_id', 'passport']]);
  });

  test('KYC settings: missing or malformed is null (the app then says it is unavailable)', () {
    expect(KycSettings.parse(null), isNull);
    expect(KycSettings.parse({'levels': {}}), isNull);
    expect(KycSettings.parse({...raw, 'levels': {'basic': {'accountTypes': ['individual'], 'requiredDocuments': [{'anyOf': ['unknown']}]}}}), isNull);
  });

  test('server error reasons map to messages', () {
    expect(FinanceErrors.messageKey('kyc_documents_missing'), 'Please add every required document before submitting.');
    expect(FinanceErrors.messageKey('who_knows'), 'Something went wrong. Please try again.');
  });

  test('a ledger transaction from the user side: credit to a wallet is money in', () {
    final sides = {'user_u_wallet_XAF': 'credit'};
    final deposit = [
      {'accountId': 'platform_mtn_provider_clearing_XAF', 'direction': 'debit', 'amount': 500},
      {'accountId': 'user_u_wallet_XAF', 'direction': 'credit', 'amount': 500},
    ];
    final spend = [
      {'accountId': 'user_u_wallet_XAF', 'direction': 'debit', 'amount': 200},
      {'accountId': 'platform_mtn_provider_clearing_XAF', 'direction': 'credit', 'amount': 200},
    ];
    expect(LedgerView.signedAmount(deposit, sides), 500);
    expect(LedgerView.signedAmount(spend, sides), -200);
    expect(LedgerView.typeLabel('manual_adjustment'), 'Adjustment');
  });

  test('dashboard summary: server totals parsed leniently; no summary or no currency = none', () {
    expect(FinanceSummary.parse(null), isNull);
    expect(FinanceSummary.parse({'currency': 'xaf'}), isNull);
    final s = FinanceSummary.parse({
      'currency': 'XAF',
      'investments': {'investedCapital': 100000, 'currentValuation': 112000, 'realizedGains': 2000, 'unrealizedGains': 10000},
      'savings': {'activeGoals': 2, 'savedAmount': 30000, 'targetAmount': 120000},
      'payments': {'last30Days': {'deposits': 50000, 'withdrawals': '20000'}},
      'monthly': [
        {'month': '2026-10', 'moneyIn': 9000, 'moneyOut': 4000},
        {'month': '2026-09', 'moneyIn': 12000, 'moneyOut': 15000},
        {'month': 'bad', 'moneyIn': 1},
      ],
    })!;
    expect(s.investments!['currentValuation'], 112000);
    expect(s.totalGains, 12000);
    expect(s.savingsProgress, 0.25);
    expect(s.last30Days, {'deposits': 50000, 'withdrawals': 20000});
    expect(s.monthly.map((m) => m.month), ['2026-09', '2026-10']);
    expect(s.chartMax, 15000);
    expect(s.tontines, isNull);
    expect(FinanceSummary.parse({'currency': 'XAF', 'savings': {'savedAmount': 5, 'targetAmount': 0}})!.savingsProgress, isNull);
    expect(FinanceSummary.parse({'currency': 'XAF', 'savings': {'savedAmount': 500, 'targetAmount': 100}})!.savingsProgress, 1.0);
  });

  test('statement rows are signed from the user side and totalled per currency', () {
    final sides = {'user_u_wallet_XAF': 'credit'};
    final txs = [
      {
        'createdAt': 2,
        'reference': 'LT-2',
        'type': 'withdrawal',
        'status': 'posted',
        'currency': 'XAF',
        'lines': [
          {'accountId': 'user_u_wallet_XAF', 'direction': 'debit', 'amount': 300},
          {'accountId': 'clearing', 'direction': 'credit', 'amount': 300},
        ],
      },
      {
        'createdAt': 1,
        'reference': 'LT-1',
        'type': 'deposit',
        'status': 'posted',
        'currency': 'XAF',
        'lines': [
          {'accountId': 'clearing', 'direction': 'debit', 'amount': 1000},
          {'accountId': 'user_u_wallet_XAF', 'direction': 'credit', 'amount': 1000},
        ],
      },
    ];
    final rows = FinanceStatement.rows(txs, sides, (v) => DateTime.fromMillisecondsSinceEpoch(v as int));
    expect(rows.map((r) => r.reference), ['LT-1', 'LT-2']);
    expect(rows.map((r) => r.signedAmount), [1000, -300]);
    final t = FinanceStatement.totals(rows)['XAF']!;
    expect(t.moneyIn, 1000);
    expect(t.moneyOut, 300);
  });

  test('the statement PDF builds for an empty and a multi-page period', () {
    String label(String k) => k;
    final rows = List.generate(
      120,
      (i) => StatementRow(at: DateTime(2026, 9, 1).add(Duration(hours: i)), reference: 'LT-$i', type: 'deposit', status: 'posted', signedAmount: i.isEven ? 1000 : -250, currency: 'XAF'),
    );
    final empty = FinanceStatementPdf.build(customerName: 'Alice', from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 30), rows: const [], label: label, typeLabel: (t) => t);
    final full = FinanceStatementPdf.build(customerName: 'Alice Ndongo', from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 30), rows: rows, label: label, typeLabel: (t) => t);
    expect(String.fromCharCodes(empty.take(5)), '%PDF-');
    expect(full.length, greaterThan(empty.length));
  });
}

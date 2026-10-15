import 'package:customer/utils/finance_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// A posting's amount for the user: + into their accounts, - out of them.
void main() {
  final lines = [
    {'accountId': 'platform_USD', 'direction': 'debit', 'amount': 1640},
    {'accountId': 'wallet_u1_USD', 'direction': 'credit', 'amount': 1640},
  ];

  test('an account the user is known to hold counts', () {
    expect(LedgerView.signedAmount(lines, {'wallet_u1_USD': 'credit'}), 1640);
  });

  test('a wallet just opened by this posting counts before the accounts list knows it', () {
    expect(LedgerView.signedAmount(lines, const {}), 0, reason: 'without the uid nothing is known');
    expect(LedgerView.signedAmount(lines, const {}, uid: 'u1'), 1640);
  });

  test("another user's wallet never counts", () {
    expect(LedgerView.signedAmount(lines, const {}, uid: 'u2'), 0);
    expect(LedgerView.signedAmount([{'accountId': 'wallet_u10_USD', 'direction': 'credit', 'amount': 5}], const {}, uid: 'u1'), 0);
  });
}

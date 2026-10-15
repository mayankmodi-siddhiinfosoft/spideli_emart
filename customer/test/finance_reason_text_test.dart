import 'package:customer/utils/finance_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reasons recorded by the admin or a rule are shown as sentences, never as
/// codes such as "cancelled_by_sender".
void main() {
  test('known codes read as their sentence', () {
    expect(financeReasonText('cancelled_by_sender'), 'Cancelled at your request.');
    expect(financeReasonText('vote'), 'The members of your group did not approve the request.');
  });

  test('other codes read as words', () {
    expect(financeReasonText('provider_timeout'), 'Provider timeout.');
  });

  test('a sentence is shown as written', () {
    expect(financeReasonText('The Mobile Money number did not accept the payment'), 'The Mobile Money number did not accept the payment');
    expect(financeReasonText(' Card blocked by the issuer. '), 'Card blocked by the issuer.');
  });
}

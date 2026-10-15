import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:flutter_test/flutter_test.dart';

/// The privacy eye hides every figure of the dashboard, not only the balance.
void main() {
  test('an amount keeps its currency and loses its figures', () {
    expect(FinPrivacy.maskAll('194 436 XAF'), '•••••• XAF');
    expect(FinPrivacy.maskAll('+35 000 XAF'), '•••••• XAF');
    expect(FinPrivacy.maskAll('−15 015 XAF'), '•••••• XAF');
  });

  test('amounts and percentages inside a sentence are masked; words stay', () {
    expect(FinPrivacy.maskAll('Return −2.0 % · −600 XAF'), 'Return •• % · •••••• XAF');
    expect(FinPrivacy.maskAll('Lent, outstanding 65 999 XAF'), 'Lent, outstanding •••••• XAF');
    expect(FinPrivacy.maskAll('2% of the target · 1 active'), '•• % of the target · 1 active');
  });

  test('text without amounts is unchanged', () {
    expect(FinPrivacy.maskAll('Tontine contribution'), 'Tontine contribution');
  });
}

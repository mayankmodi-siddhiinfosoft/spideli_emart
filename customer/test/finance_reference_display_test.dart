import 'package:customer/utils/finance_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// References are shown with plain hyphens (U+2011 rendered as an underscore
/// on some Android fonts) and never break across lines.
void main() {
  test('a reference keeps plain hyphens, each followed by a word joiner', () {
    final String shown = ltrRef('SPF-261015-8CNG3L');
    expect(shown.contains('‑'), isFalse);
    expect(shown, '⁦SPF-⁠261015-⁠8CNG3L⁩');
  });

  test('the visible characters are the stored reference', () {
    final String visible = ltrRef('SPL-DEMO-0005').replaceAll(RegExp('[⁠⁦⁩]'), '');
    expect(visible, 'SPL-DEMO-0005');
  });

  test('an empty reference stays empty', () {
    expect(ltrRef(null), '⁦⁩');
  });
}

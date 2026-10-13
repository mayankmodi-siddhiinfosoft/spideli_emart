import 'package:customer/utils/push_template_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushTemplateText.fill (carrier_parcel_order)', () {
    const String subject = 'New parcel order {trackingNumber}';
    const String message = '{customerName} booked a parcel with your company. Tracking number: {trackingNumber}. Open Orders to assign a driver.';
    final Map<String, String> values = {'customerName': 'Awa Njoya', 'trackingNumber': 'SPD-261013-K7M2QX'};

    test('fills every placeholder', () {
      expect(PushTemplateText.fill(subject, values), 'New parcel order SPD-261013-K7M2QX');
      expect(PushTemplateText.fill(message, values), 'Awa Njoya booked a parcel with your company. Tracking number: SPD-261013-K7M2QX. Open Orders to assign a driver.');
    });
    test('names match case-insensitively', () {
      expect(PushTemplateText.fill('{CUSTOMERNAME}', values), 'Awa Njoya');
    });
    test('an unknown placeholder is left as written; null text is empty', () {
      expect(PushTemplateText.fill('Hi {receiver}', values), 'Hi {receiver}');
      expect(PushTemplateText.fill(null, values), '');
    });
    test('a template without placeholders is unchanged', () {
      expect(PushTemplateText.fill('Plain text', values), 'Plain text');
    });
  });
}

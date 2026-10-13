import 'package:driver/services/carrier_parcel_rules.dart';
import 'package:driver/services/push_template_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('carrier parcel assignment / return push text', () {
    test('assigned: company, tracking number and driver are filled', () {
      final values = CarrierParcelRules.pushValues(orderId: 'o1', trackingNumber: 'SPD-261013-K7M2QX', companyName: 'LN Carrier', driverName: 'Ravi Patel');
      expect(PushTemplateText.fill('New parcel from {companyName}', values), 'New parcel from LN Carrier');
      expect(
        PushTemplateText.fill('{companyName} assigned you parcel {trackingNumber}. Accept or reject it before the time runs out.', values),
        'LN Carrier assigned you parcel SPD-261013-K7M2QX. Accept or reject it before the time runs out.',
      );
    });
    test('returned: the driver who passed it is named', () {
      final values = CarrierParcelRules.pushValues(orderId: 'o1', trackingNumber: 'SPD-1', driverName: 'Ravi Patel');
      expect(PushTemplateText.fill('{driverName} did not take parcel {trackingNumber}.', values), 'Ravi Patel did not take parcel SPD-1.');
    });
    test('no tracking number -> the order id; unknown names are left out', () {
      final values = CarrierParcelRules.pushValues(orderId: 'order-42', trackingNumber: '  ', companyName: '', driverName: null);
      expect(values, {'trackingNumber': 'order-42'});
    });
    test('the template types the admin manages', () {
      expect(CarrierParcelRules.assignedTemplate, 'carrier_parcel_assigned');
      expect(CarrierParcelRules.returnedTemplate, 'carrier_parcel_returned');
    });
  });
}

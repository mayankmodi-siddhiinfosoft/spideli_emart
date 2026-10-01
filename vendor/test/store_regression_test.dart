import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/controller/special_discount_controller.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_subscription_model.dart';
import 'package:vendor/utils/customer_subscription_service.dart';

void main() {
  // The special-discount "kind" dropdown used translated strings as its item
  // *values* while opening on the untranslated key, so in any language with a
  // translation for them the field was handed a value outside its own items and
  // asserted instead of rendering - the same fault class as the calendars that
  // did not display (report #8).
  group('special discount type options', () {
    test('every stored value maps onto one of the dropdown items', () {
      for (final String? stored in <String?>[null, '', 'dinein', 'delivery', 'something the panel wrote']) {
        expect(
          SpecialDiscountController.discountTypeOptions,
          contains(SpecialDiscountController.discountTypeOption(stored)),
          reason: 'stored value "$stored" must open on one of the dropdown items',
        );
      }
    });

    test('the two kinds round-trip', () {
      expect(SpecialDiscountController.storedDiscountType(SpecialDiscountController.dineInDiscountOption), 'dinein');
      expect(SpecialDiscountController.storedDiscountType(SpecialDiscountController.deliveryDiscountOption), 'delivery');
      expect(SpecialDiscountController.discountTypeOption('dinein'), SpecialDiscountController.dineInDiscountOption);
      expect(SpecialDiscountController.discountTypeOption('delivery'), SpecialDiscountController.deliveryDiscountOption);
    });

    test('an unknown option is stored as a delivery discount, never dropped', () {
      expect(SpecialDiscountController.storedDiscountType(null), 'delivery');
      expect(SpecialDiscountController.storedDiscountType('nonsense'), 'delivery');
    });
  });

  // Report #17 in the two places that still joined address parts by hand.
  group('addresses never print "null"', () {
    test('a customer subscription address drops a part stored as "null"', () {
      final UserModel user = UserModel()
        ..shippingAddress = [ShippingAddress(address: '123 Yaounde St', locality: 'null', landmark: 'Tsinga', isDefault: true)];
      expect(CustomerSubscriptionService.customerAddress(user), '123 Yaounde St, Tsinga');
    });

    test('an address with nothing usable reads as no address at all', () {
      final UserModel user = UserModel()
        ..shippingAddress = [ShippingAddress(address: 'null', locality: '', landmark: null, isDefault: true)];
      expect(CustomerSubscriptionService.customerAddress(user), isNull);
    });

    test('a subscription delivery address map drops its "null" parts', () {
      final model = VendorSubscriptionModel.fromJson({
        'deliveryAddress': {'address': '123 Yaounde St', 'locality': 'null', 'landmark': 'Tsinga'},
      });
      expect(model.deliveryAddress, '123 Yaounde St, Tsinga');
    });

    test('a subscription delivery address stored as the string "null" reads as none', () {
      final model = VendorSubscriptionModel.fromJson({'deliveryAddress': 'null'});
      expect(model.deliveryAddress, isNull);
    });

    test('an order shipping address drops its "null" parts', () {
      final ShippingAddress address = ShippingAddress(address: '123 Yaounde St', locality: 'null', landmark: 'Tsinga');
      expect(address.getFullAddress(), '123 Yaounde St, Tsinga');
    });
  });
}

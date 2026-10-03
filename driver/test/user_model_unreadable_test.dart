import 'package:driver/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stored value that does not parse must not be deleted or overwritten
/// when the profile is saved back (sign-in, app start).
void main() {
  test('an unreadable cab offer is flagged, so updateUser keeps it', () {
    final UserModel user = UserModel.fromJson({
      'role': 'driver',
      'ordercabRequestData': {'status': 5}, // a number where text is expected
    });
    expect(user.orderCabRequestData, isNull);
    expect(user.cabRequestUnreadable, isTrue);

    // Clearing the offer on purpose still deletes it.
    user.orderCabRequestData = null;
    expect(user.cabRequestUnreadable, isFalse);
  });

  test('no offer, or a non-map value, is not flagged', () {
    expect(UserModel.fromJson({'role': 'driver'}).cabRequestUnreadable, isFalse);
    expect(UserModel.fromJson({'role': 'driver', 'ordercabRequestData': ''}).cabRequestUnreadable, isFalse);
  });

  test('a shipping address list with an unreadable entry is not written back', () {
    final UserModel user = UserModel.fromJson({
      'role': 'driver',
      'shippingAddress': ['not a map', <String, dynamic>{}],
    });
    expect(user.shippingAddress, hasLength(1));
    expect(user.shippingAddressUnreadable, isTrue);
    expect(user.toJson().containsKey('shippingAddress'), isFalse);

    user.shippingAddress = [...user.shippingAddress!];
    expect(user.toJson().containsKey('shippingAddress'), isTrue);
  });

  test('a fully readable shipping address list is written as before', () {
    final UserModel user = UserModel.fromJson({
      'role': 'driver',
      'shippingAddress': [<String, dynamic>{}],
    });
    expect(user.shippingAddressUnreadable, isFalse);
    expect(user.toJson()['shippingAddress'], hasLength(1));
  });
}

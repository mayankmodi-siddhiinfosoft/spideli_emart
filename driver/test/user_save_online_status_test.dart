import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// "The driver goes Offline automatically": no save of an existing driver
/// (profile, bank, vehicle, section, review, every sign-in / app start) may
/// write the online switch back from its copy.
void main() {
  UserModel driver({bool? isActive}) => UserModel.fromJson({
        'id': 'd1',
        'role': 'driver',
        'firstName': 'Ana',
        'active': true,
        'isActive': isActive,
        'isDocumentVerify': true,
        'fcmToken': 'token-1',
        'wallet_amount': 40,
        'serviceTypes': ['delivery-service', 'cab-service'],
        'inProgressOrderID': ['o1'],
        'orderRequestData': ['o2'],
        'location': {'latitude': 1.0, 'longitude': 2.0},
        'rotation': 10,
      });

  test('an existing driver\'s save never writes isActive, whatever its copy says', () {
    for (final bool? copy in [true, false, null]) {
      final Map<String, dynamic> data = FireStoreUtils.userSaveData(driver(isActive: copy));
      expect(data.containsKey('isActive'), isFalse, reason: 'copy isActive: $copy');
    }
  });

  test('an existing driver\'s save keeps the rest of its rules', () {
    final Map<String, dynamic> data = FireStoreUtils.userSaveData(driver(isActive: false));
    for (final String key in ['wallet_amount', 'fcmToken', 'isDocumentVerify', 'orderRequestData', 'inProgressOrderID', 'location', 'rotation']) {
      expect(data.containsKey(key), isFalse, reason: key);
    }
    expect(data['firstName'], 'Ana');
    expect(data['active'], isTrue);
    // The service list the dispatch reads stays an array on every save.
    expect(data['serviceTypes'], ['delivery-service', 'cab-service']);
  });

  test('a new account starts offline (sign-up, a company creating a driver)', () {
    final UserModel fresh = driver(isActive: false);
    final Map<String, dynamic> data = FireStoreUtils.userSaveData(fresh, isNew: true);
    expect(data['isActive'], isFalse);
    expect(data['fcmToken'], 'token-1');
  });
}

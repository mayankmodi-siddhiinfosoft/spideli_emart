import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adding a driver to a company failed: removeNulls threw while removing an
/// empty nested map (a new driver's empty vehicleDetails).
void main() {
  test('empty nested maps and nulls are removed without throwing', () {
    final Map<String, dynamic> data = {
      'id': 'd1',
      'vehicleDetails': <String, dynamic>{},
      'sectionNames': <String, dynamic>{'s1': null},
      'location': <String, dynamic>{'latitude': 3.8, 'longitude': null},
      'ownerId': 'o1',
      'regionId': null,
    };
    final Map<String, dynamic> out = FireStoreUtils.removeNulls(data);
    expect(out.containsKey('vehicleDetails'), isFalse);
    expect(out.containsKey('sectionNames'), isFalse);
    expect(out.containsKey('regionId'), isFalse);
    expect(out['location'], {'latitude': 3.8});
    expect(out['ownerId'], 'o1');
  });
}

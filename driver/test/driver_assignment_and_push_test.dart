import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/constant.dart';
import 'package:driver/services/driver_assignment_watcher.dart';
import 'package:driver/services/push_message.dart';
import 'package:driver/utils/cancel_reason_list.dart';
import 'package:driver/widget/cancel_reason_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

/// Report 01 §4 "Driver assignment no longer requires an fcmToken", doc 21
/// (driver push topics) and 02#15 (the driver's cancellation fields).
void main() {
  group('DriverAssignmentWatcher.pendingIdToAdopt (hand assignment without a push)', () {
    const String me = 'driver-1';
    final DateTime now = DateTime(2026, 10, 7, 12);
    const List<String> delivery = [Constant.driverPending, Constant.orderAccepted];
    String? adopt(Map<String, dynamic> data, {String field = 'driverID', List<String> statuses = delivery}) =>
        DriverAssignmentWatcher.pendingIdToAdopt(data, me, field, statuses, now, docId: 'doc-id');

    test('the admin panel shape: Order Accepted + driverID, no fcmToken, no push', () {
      expect(adopt({'id': 'o1', 'status': Constant.orderAccepted, 'driverID': me, 'createdAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 5)))}), 'o1');
    });

    test('a Driver Pending hand assignment is adopted too', () {
      expect(adopt({'id': 'o2', 'status': Constant.driverPending, 'driverID': me}), 'o2');
    });

    test('falls back to the document id', () {
      expect(adopt({'status': Constant.driverPending, 'driverID': me}), 'doc-id');
    });

    test('not when another driver is named, or nobody', () {
      expect(adopt({'id': 'o3', 'status': Constant.driverPending, 'driverID': 'someone-else'}), isNull);
      expect(adopt({'id': 'o3', 'status': Constant.driverPending}), isNull);
      expect(adopt({'id': 'o3', 'status': Constant.driverPending, 'driverID': '  '}), isNull);
    });

    test('not after this driver rejected it', () {
      expect(adopt({'id': 'o4', 'status': Constant.driverPending, 'driverID': me, 'rejectedByDrivers': [me]}), isNull);
      expect(adopt({'id': 'o4', 'status': Constant.driverPending, 'driverID': me, 'rejectedByDrivers': ['other']}), 'o4');
    });

    test('not in a status that is not waiting for the driver', () {
      expect(adopt({'id': 'o5', 'status': Constant.orderCompleted, 'driverID': me}), isNull);
      expect(adopt({'id': 'o5', 'status': Constant.orderCancelled, 'driverID': me}), isNull);
    });

    test('an abandoned record (older than 48 h) is not revived', () {
      expect(adopt({'id': 'o6', 'status': Constant.driverPending, 'driverID': me, 'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 3)))}), isNull);
      // ...unless it is scheduled recently.
      expect(
        adopt({
          'id': 'o6',
          'status': Constant.driverPending,
          'driverID': me,
          'createdAt': Timestamp.fromDate(now.subtract(const Duration(days: 3))),
          'scheduleTime': Timestamp.fromDate(now.add(const Duration(hours: 1))),
        }),
        'o6',
      );
    });

    test('cab: driverId, Order Placed counts as waiting', () {
      expect(
        adopt({'id': 'r1', 'status': Constant.orderPlaced, 'driverId': me},
            field: 'driverId', statuses: const [Constant.driverPending, Constant.orderPlaced, Constant.orderAccepted]),
        'r1',
      );
      expect(adopt({'id': 'r1', 'status': Constant.orderPlaced, 'driverID': me}, field: 'driverId'), isNull);
    });

    test('a pending ride is adopted as a request, never into inProgressOrderID (dispatch spec §4, D2)', () {
      expect(DriverAssignmentWatcher.pendingAdoptFields['cab-service'], 'orderRequestData');
      expect(DriverAssignmentWatcher.pendingAdoptFields['delivery-service'], 'orderRequestData');
      expect(DriverAssignmentWatcher.pendingAdoptFields.values, isNot(contains('inProgressOrderID')));
    });

    test('no signed-in driver: nothing', () {
      expect(DriverAssignmentWatcher.pendingIdToAdopt({'id': 'o', 'status': Constant.driverPending, 'driverID': ''}, '', 'driverID', delivery, now), isNull);
    });
  });

  group('PushTopics.forDriver (doc 21)', () {
    test('every topic the server can address a driver by, every zone included', () {
      expect(
        PushTopics.forDriver(
          active: true,
          serviceTypes: const ['delivery-service', 'cab-service', 'parcel_delivery', 'rental-service'],
          sectionIds: const ['s1'],
          zoneId: 'z1',
          zoneIds: const ['z1', 'z2'],
          regionId: 'r1',
          ownerId: 'c1',
          carrierId: 'k1',
        ),
        {
          'driver',
          'driver_delivery-service',
          'driver_cab-service',
          'driver_parcel_delivery',
          'driver_rental-service',
          'section_s1',
          'zone_z1',
          'zone_z2',
          'region_r1',
          'company_c1',
          'carrier_k1',
        },
      );
    });

    test('a company account gets only its company / carrier topics, never job topics', () {
      expect(
        PushTopics.forDriver(
          active: true,
          isOwner: true,
          serviceTypes: const ['delivery-service', 'cab-service'],
          sectionIds: const ['s1'],
          zoneId: 'z1',
          zoneIds: const ['z1', 'z2', 'z3'],
          regionId: 'r1',
          ownerId: 'c1',
          carrierId: 'k1',
        ),
        {'company_c1', 'carrier_k1'},
      );
      expect(PushTopics.forDriver(active: true, isOwner: true, zoneIds: const ['z1']), isEmpty);
      expect(PushTopics.forDriver(active: false, isOwner: true, ownerId: 'c1'), isEmpty);
    });

    test('an account that is not active gets none (all are dropped)', () {
      expect(PushTopics.forDriver(active: false, serviceTypes: const ['cab-service'], zoneId: 'z1'), isEmpty);
    });

    test('blank values give no topic; unsafe characters become _', () {
      expect(PushTopics.forDriver(active: true, zoneId: '', regionId: '  ', ownerId: null), {'driver'});
      expect(PushTopics.topic('zone', 'Yaoundé 1'), 'zone_Yaound__1');
    });
  });

  group('CancelReasonResult.toFields (a driver pass, CANCEL-REASON-CONTRACT)', () {
    const CancelReasonResult chosen = CancelReasonResult(reason: 'Vehicle problem', code: 'vehicle_problem');

    test('a pass goes back to dispatch: driverRejections only, never the final cancellation fields', () {
      for (final Map<String, dynamic> f in [chosen.toFields('d1'), chosen.toFields('d1', afterAccept: true)]) {
        expect(f.keys, ['driverRejections']);
        expect(f['driverRejections'], isA<FieldValue>());
        for (final String key in const ['cancelReason', 'cancelReasonCode', 'cancelledBy', 'cancelledAt', 'cancelAction', 'status']) {
          expect(f.containsKey(key), isFalse, reason: '$key would outlive the pass on a record another driver completes');
        }
      }
    });

    test('"Other" records the typed text with code other', () {
      final CancelReasonResult other = CancelReasonResult.fromOption(CancelReasonOption.other, otherText: '  Customer unreachable ');
      expect(other.reason, 'Customer unreachable');
      expect(other.code, 'other');
      expect(other.toFields('d1').keys, ['driverRejections']);
    });

    test('a stored {code, label} entry records its code and label', () {
      final CancelReasonOption stored = parseCancelReasonList(
        {
          'reasons': [
            {'code': 'too_far', 'label': 'Pickup too far'},
          ],
        },
        roleKeys: const ['driver'],
        defaults: const ['Vehicle problem'],
      ).first;
      final CancelReasonResult result = CancelReasonResult.fromOption(stored);
      expect(result.reason, 'Pickup too far');
      expect(result.code, 'too_far');
    });
  });
}

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/models/cab_order_model.dart';
import 'package:customer/models/cancellation_fields.dart';
import 'package:customer/models/dine_in_booking_model.dart';
import 'package:customer/models/onprovider_order_model.dart';
import 'package:customer/models/order_model.dart';
import 'package:customer/models/parcel_order_model.dart';
import 'package:customer/models/rental_order_model.dart';
import 'package:customer/widget/cancel_reason_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

/// CANCEL-REASON-CONTRACT: the fields every order / booking / ride / parcel
/// carries, how they are read, written back and shown.
void main() {
  final at = Timestamp.fromDate(DateTime(2026, 10, 2, 14, 30));
  Map<String, dynamic> contract({String by = 'vendor', String action = 'rejected'}) => {
    'cancelReason': 'Out of stock',
    'cancelReasonCode': 'Out of stock',
    'cancelledBy': by,
    'cancelledByName': 'Pizza Hub',
    'cancelledAt': at,
    'cancelAction': action,
  };

  group('model round-trip', () {
    final Map<String, Map<String, dynamic> Function(Map<String, dynamic>)> models = {
      'OrderModel': (j) => OrderModel.fromJson(j).toJson(),
      // A real ride always carries `trigger_delevery` (its toJson requires it).
      'CabOrderModel': (j) => CabOrderModel.fromJson({'trigger_delevery': Timestamp.now(), ...j}).toJson(),
      'RentalOrderModel': (j) => RentalOrderModel.fromJson(j).toJson(),
      'ParcelOrderModel': (j) => ParcelOrderModel.fromJson(j).toJson(),
      'OnProviderOrderModel': (j) => OnProviderOrderModel.fromJson(j).toJson(),
      'DineInBookingModel': (j) => DineInBookingModel.fromJson(j).toJson(),
    };

    models.forEach((name, roundTrip) {
      test('$name keeps every contract field', () {
        final out = roundTrip({'id': 'o1', 'status': Constant.orderRejected, ...contract()});
        expect(out['cancelReason'], 'Out of stock');
        expect(out['cancelReasonCode'], 'Out of stock');
        expect(out['cancelledBy'], 'vendor');
        expect(out['cancelledByName'], 'Pizza Hub');
        expect(out['cancelledAt'], at);
        expect(out['cancelAction'], 'rejected');
      });

      test('$name never writes absent fields (a save cannot clear them)', () {
        final out = roundTrip({'id': 'o1', 'status': Constant.orderPlaced});
        for (final key in ['cancelReason', 'cancelReasonCode', 'cancelledBy', 'cancelledByName', 'cancelledAt', 'cancelAction']) {
          expect(out.containsKey(key), isFalse, reason: key);
        }
      });
    });
  });

  test('reads tolerantly: blanks and "null" are absent, any timestamp shape', () {
    final order = OrderModel.fromJson({'cancelReason': '  ', 'cancelledBy': 'null', 'cancelledAt': '2026-10-02T10:00:00Z', 'cancelAction': 'Rejected'});
    expect(order.cancelReason, isNull);
    expect(order.cancelledBy, isNull);
    expect(order.cancelledAt?.toDate().toUtc(), DateTime.utc(2026, 10, 2, 10));
    expect(order.cancelAction, 'rejected');
    expect(cancellationTimestamp(1700000000000), Timestamp.fromMillisecondsSinceEpoch(1700000000000));
    expect(cancellationTimestamp({'_seconds': 10, '_nanoseconds': 0}), Timestamp(10, 0));
  });

  group('summary', () {
    CancellationSummary? summary(Map<String, dynamic> json, {String? status, String vendorWord = 'Store', String? fallback}) =>
        CancellationSummary.of(status: status ?? json['status'], fields: OrderModel.fromJson(json), vendorWord: vendorWord, fallbackReason: fallback);

    test('vendor / store / restaurant are the same party, in the section word', () {
      for (final by in ['vendor', 'store', 'restaurant']) {
        final s = summary({'status': Constant.orderRejected, ...contract(by: by)}, vendorWord: 'Restaurant')!;
        expect(s.headline, 'Rejected by Restaurant');
        expect(s.reason, 'Out of stock');
        expect(s.actorName, 'Pizza Hub');
        expect(s.timeLabel, isNotNull);
      }
    });

    test('labels every party', () {
      expect(summary({'status': Constant.orderCancelled, 'cancelledBy': 'driver', 'cancelAction': 'cancelled'})!.headline, 'Cancelled by Driver');
      expect(summary({'status': Constant.orderCancelled, 'cancelledBy': 'provider'})!.headline, 'Cancelled by Service provider');
      expect(summary({'status': Constant.orderCancelled, 'cancelledBy': 'worker'})!.headline, 'Cancelled by Worker');
      expect(summary({'status': Constant.orderCancelled, 'cancelledBy': 'admin'})!.headline, 'Cancelled by Admin');
    });

    test('a customer cancellation on a ride stored as "Order Rejected" still reads as cancelled', () {
      final s = summary({'status': Constant.orderRejected, 'cancelledBy': 'customer', 'cancelReason': 'Changed my plans'})!;
      expect(s.headline, 'Cancelled by Customer');
      expect(s.actorName, isNull);
      expect(s.oneLine, 'Cancelled by Customer · Changed my plans');
    });

    test('a record cancelled before the rule shows "No reason recorded", never blank', () {
      final s = summary({'status': Constant.orderCancelled})!;
      expect(s.headline, 'Cancelled');
      expect(s.reason, 'No reason recorded');
      expect(s.hasReason, isFalse);
      expect(summary({'status': Constant.orderRejected, 'cancelReason': 'null'})!.reason, 'No reason recorded');
    });

    test('the pre-contract on-demand `reason` is used when there is no cancelReason', () {
      expect(summary({'status': Constant.orderCancelled}, fallback: 'Not home')!.reason, 'Not home');
    });

    test('nothing for open records or a driver pass back to dispatch', () {
      expect(summary({'status': Constant.orderPlaced, ...contract()}), isNull);
      expect(summary({'status': 'Driver Rejected', 'cancelReason': 'Too far'}), isNull);
    });
  });

  test('the customer reason result writes the full contract and mirrors it locally', () {
    const result = CancelReasonResult(reason: 'Ordered by mistake', code: 'other');
    final fields = result.toFields();
    expect(fields['cancelReason'], 'Ordered by mistake');
    expect(fields['cancelReasonCode'], 'other');
    expect(fields['cancelledBy'], 'customer');
    expect(fields['cancelAction'], 'cancelled');
    expect(fields['cancelledAt'], isA<FieldValue>());

    final order = OrderModel();
    result.applyTo(order);
    expect(order.cancelledBy, 'customer');
    expect(order.cancelAction, 'cancelled');
    expect(order.cancelledAt, isNotNull);
  });
}

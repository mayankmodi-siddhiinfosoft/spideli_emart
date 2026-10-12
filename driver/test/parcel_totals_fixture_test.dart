import 'dart:convert';
import 'dart:io';

import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/utils/parcel_amounts.dart';
import 'package:flutter_test/flutter_test.dart';

/// The driver's parcel total on the customer app's fixture
/// (`customer/test/fixtures/parcel_totals_fixture.json`, read by the
/// customer's own test too): the cash a driver collects is what the customer
/// was charged, and the platform's share is what the wallet is debited.
void main() {
  final Map<String, dynamic> fixture =
      jsonDecode(File('../customer/test/fixtures/parcel_totals_fixture.json').readAsStringSync()) as Map<String, dynamic>;
  for (final dynamic c in fixture['cases'] as List) {
    final Map<String, dynamic> kase = Map<String, dynamic>.from(c as Map);
    test('driver total: ${kase['name']}', () {
      final ParcelAmounts a = ParcelAmounts.of(ParcelOrderModel.fromJson(Map<String, dynamic>.from(kase['order'] as Map)));
      expect(a.total, closeTo((kase['total'] as num).toDouble(), 0.001));
      expect(a.platformTax, closeTo((kase['platformTax'] as num).toDouble(), 0.001));
      expect(a.platformShareOfCash, closeTo((kase['platformShare'] as num).toDouble(), 0.001));
      // Online or cash, the courier keeps the same amount.
      const double commission = 90;
      expect(a.onlineCredit - commission, closeTo(a.courierNet(commission), 0.001));
      expect(a.total - commission - a.platformShareOfCash, closeTo(a.courierNet(commission), 0.001));
    });
  }
}

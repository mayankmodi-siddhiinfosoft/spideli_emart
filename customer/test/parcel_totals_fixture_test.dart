import 'dart:convert';
import 'dart:io';

import 'package:customer/models/parcel_order_model.dart';
import 'package:customer/utils/parcel_receipt_pdf.dart' show ParcelAmounts;
import 'package:flutter_test/flutter_test.dart';

/// The customer's parcel total on the fixture the Driver app's test reads
/// too (`test/fixtures/parcel_totals_fixture.json`): checkout, receipt,
/// order screen, history export, cancel refund and the driver's cash total
/// are one number.
void main() {
  final Map<String, dynamic> fixture = jsonDecode(File('test/fixtures/parcel_totals_fixture.json').readAsStringSync()) as Map<String, dynamic>;
  for (final dynamic c in fixture['cases'] as List) {
    final Map<String, dynamic> kase = Map<String, dynamic>.from(c as Map);
    test('customer total: ${kase['name']}', () {
      final ParcelAmounts a = ParcelAmounts.of(ParcelOrderModel.fromJson(Map<String, dynamic>.from(kase['order'] as Map)));
      expect(a.total, closeTo((kase['total'] as num).toDouble(), 0.001));
      expect(a.platformTax, closeTo((kase['platformTax'] as num).toDouble(), 0.001));
    });
  }

  test('checkout charges the platform fee only while it is enabled', () {
    expect(ParcelAmounts.chargedPlatformFee(enabled: false, fee: '200'), 0);
    expect(ParcelAmounts.chargedPlatformFee(enabled: null, fee: '200'), 0);
    expect(ParcelAmounts.chargedPlatformFee(enabled: true, fee: '200'), 200);
    expect(ParcelAmounts.chargedPlatformFee(enabled: true, fee: ''), 0);
    expect(ParcelAmounts.chargedPlatformFee(enabled: true, fee: '-5'), 0);
  });
}

import 'package:customer/models/parcel_order_model.dart';
import 'package:customer/models/tax_model.dart';
import 'package:customer/utils/parcel_bill.dart';
import 'package:customer/utils/parcel_receipt_pdf.dart' show ParcelAmounts;
import 'package:customer/utils/platform_fee_charge.dart';
import 'package:flutter_test/flutter_test.dart';

/// The parcel bill as the customer website shows it (checkout and placed
/// order of 14 Oct 2026, MK Carrier Company, Ahmedabad).
void main() {
  TaxModel tax(String title, String type, String value, {bool enable = true}) =>
      TaxModel.fromJson({'title': title, 'type': type, 'tax': value, 'enable': enable, 'scope': 'order'});

  group('order taxes follow the global setting (settings/globalSettings.taxScope)', () {
    final List<TaxModel> section = [tax('CGST', 'fix', '8'), tax('GST', 'percentage', '18'), tax('Old', 'fix', '5', enable: false)];

    test('"order": the section\'s enabled order taxes are charged', () {
      expect(OrderTaxCharge.of(taxScope: 'order', orderTaxes: section).map((t) => t.title), ['CGST', 'GST']);
    });

    test('any other scope, or none: no order tax', () {
      expect(OrderTaxCharge.of(taxScope: 'product', orderTaxes: section), isEmpty);
      expect(OrderTaxCharge.of(taxScope: '', orderTaxes: section), isEmpty);
      expect(OrderTaxCharge.of(taxScope: null, orderTaxes: section), isEmpty);
      expect(OrderTaxCharge.of(taxScope: 'order', orderTaxes: null), isEmpty);
    });
  });

  test('the website\'s lines: platform charge, collection and delivery, each tax', () {
    final List<ParcelBillLine> lines = ParcelBill.lines(
      subTotal: 726.50,
      discount: 0,
      platformFee: 20,
      options: 100,
      orderTaxed: true,
      orderTax: 138.77,
      platformTaxes: const [('IGST', 10), ('tax', 1)],
      total: 996.27,
    );
    expect(lines.map((l) => l.prefix == null ? l.label : '${l.prefix} ${l.label}'), [
      'Subtotal',
      'Discount',
      'Platform Charge',
      'Collection and delivery',
      'Tax on Order Total',
      'IGST Tax on Platform Fee',
      'tax Tax on Platform Fee',
      'Total Tax Amount',
      'Order Total',
    ]);
    expect(lines.firstWhere((l) => l.label == 'Total Tax Amount').amount, closeTo(149.77, 0.001));
    expect(lines.firstWhere((l) => l.label == 'Discount').kind, ParcelBillKind.discount);
    expect(lines.firstWhere((l) => l.label == 'Collection and delivery').kind, ParcelBillKind.charge);
    expect(lines.last.kind, ParcelBillKind.total);
  });

  test('lines that do not apply are left out', () {
    final List<ParcelBillLine> lines = ParcelBill.lines(subTotal: 500, discount: 0, total: 500);
    expect(lines.map((l) => l.label), ['Subtotal', 'Discount', 'Order Total']);
    // A free receiver SMS and the fixed tax when there are some.
    final List<ParcelBillLine> more = ParcelBill.lines(subTotal: 500, discount: 0, scopeTax: 300, receiverSms: true, total: 800);
    expect(more.map((l) => l.label), ['Subtotal', 'Discount', 'Fixed tax', 'Receiver SMS', 'Order Total']);
    expect(more.firstWhere((l) => l.label == 'Receiver SMS').kind, ParcelBillKind.free);
  });

  test('the website\'s order reads back as charged (996.27)', () {
    final ParcelOrderModel order = ParcelOrderModel.fromJson({
      'id': 'INF0M5Q5xtzsVzTNzqFc',
      'subTotal': '726.5',
      'discount': '0.00',
      'platformFee': '20',
      'taxScope': 'order',
      'taxSetting': [
        {'title': 'CGST', 'type': 'fix', 'tax': '8', 'enable': true, 'scope': 'order'},
        {'title': 'GST', 'type': 'percentage', 'tax': '18', 'enable': true, 'scope': 'order'},
      ],
      'platformTax': [
        {'title': 'IGST', 'type': 'fix', 'tax': '10', 'enable': true, 'scope': 'platform'},
        {'title': 'tax', 'type': 'percentage', 'tax': '5', 'enable': true, 'scope': 'platform'},
      ],
      'priceBreakdown': {'carrierPrice': 726.5, 'commission': '0', 'options': '100', 'pickupCharge': '50', 'deliveryCharge': '50', 'total': 996.27},
    });
    final ParcelAmounts a = ParcelAmounts.of(order);
    expect(order.taxScope, 'order');
    expect(a.orderTax, closeTo(138.77, 0.001));
    expect(a.platformTax, closeTo(11, 0.001));
    expect(a.total, closeTo(996.27, 0.001));
  });
}

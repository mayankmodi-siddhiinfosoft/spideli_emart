import 'package:driver/constant/constant.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/models/tax_model.dart';

/// The amounts of a parcel order exactly as the customer app charged them
/// (customer `ParcelAmounts`, parcel_receipt_pdf.dart), so the total a
/// driver shows and collects in cash is the customer's total:
///
///   subTotal - discount + order taxes + platform fee + its taxes
///   + fixed (intercity / intercountry) tax + receiver-SMS fee (point 54)
///
/// The order taxes apply to subTotal - discount; the platform taxes to the
/// platform fee, and only when there is one. The fixed tax and the SMS fee are
/// outside VAT and coupons. Read tolerantly: a field a panel left out, or one
/// stored as text, counts as 0 instead of throwing while a card is built.
///
/// The customer's checkout adds the platform fee's taxes only while the
/// platform fee setting is enabled, yet writes `platformTax` on every parcel.
/// When the order's charged total (`priceBreakdown.total`,
/// [ParcelOrderModel.chargedTotal]) is exactly the total WITHOUT those taxes,
/// they were not charged: they count as 0 here too, so the total shown, the
/// cash collected and the platform's share debited from the driver all match
/// what the customer paid. Any other charged total leaves the lines as they
/// are (its meaning is not known for every writer).
class ParcelAmounts {
  final double subTotal;
  final double discount;
  final double orderTax;
  final double platformFee;
  final double platformTax;
  final double scopeTax;
  final double smsCharge;

  const ParcelAmounts({
    this.subTotal = 0,
    this.discount = 0,
    this.orderTax = 0,
    this.platformFee = 0,
    this.platformTax = 0,
    this.scopeTax = 0,
    this.smsCharge = 0,
  });

  factory ParcelAmounts.of(ParcelOrderModel order) {
    final double sub = _number(order.subTotal);
    final double disc = _number(order.discount);
    final double fee = _number(order.platformFee);
    double orderTax = 0;
    for (final TaxModel tax in order.taxSetting ?? const <TaxModel>[]) {
      orderTax += Constant.getTaxValue(amount: (sub - disc).toString(), taxModel: tax);
    }
    double platformTax = 0;
    if (fee > 0) {
      for (final TaxModel tax in order.platformTax ?? const <TaxModel>[]) {
        platformTax += Constant.getTaxValue(amount: fee.toString(), taxModel: tax);
      }
    }
    final double scope = (order.parcelScopeTax ?? 0).toDouble();
    final ParcelAmounts lines = ParcelAmounts(
      subTotal: sub,
      discount: disc,
      orderTax: orderTax,
      platformFee: fee > 0 ? fee : 0,
      platformTax: platformTax,
      scopeTax: scope.isFinite && scope > 0 ? scope : 0,
      smsCharge: order.smsChargeAmount.isFinite && order.smsChargeAmount > 0 ? order.smsChargeAmount : 0,
    );
    return platformTaxCharged(lines, order.chargedTotal) ? lines : lines.withoutPlatformTax();
  }

  /// Whether the customer was charged the platform fee's taxes of [lines]:
  /// false only when [chargedTotal] is the total without them (to the cent).
  static bool platformTaxCharged(ParcelAmounts lines, num? chargedTotal) {
    if (lines.platformTax <= 0 || chargedTotal == null || !chargedTotal.isFinite) return true;
    final double withoutTax = lines.total - lines.platformTax;
    return (chargedTotal - withoutTax).abs() >= 0.005;
  }

  ParcelAmounts withoutPlatformTax() => ParcelAmounts(
        subTotal: subTotal,
        discount: discount,
        orderTax: orderTax,
        platformFee: platformFee,
        scopeTax: scopeTax,
        smsCharge: smsCharge,
      );

  /// Every tax line: the order taxes and the platform fee's taxes.
  double get taxes => orderTax + platformTax;

  /// What the customer pays (and the driver collects on a cash parcel).
  double get total => subTotal - discount + orderTax + platformFee + platformTax + scopeTax + smsCharge;

  /// The part of a cash parcel's total that belongs to the platform, never
  /// to the driver: the platform fee and its taxes, the fixed tax and the
  /// receiver-SMS fee. Debited from the driver's wallet on completion.
  double get platformShareOfCash => platformFee + platformTax + scopeTax + smsCharge;

  /// [total] as text with [digits] decimals (the currency's).
  String totalText(int digits) => total.toStringAsFixed(digits);

  static double _number(dynamic value) {
    final double? parsed = value is num ? value.toDouble() : double.tryParse((value ?? '').toString().trim());
    return parsed == null || !parsed.isFinite ? 0 : parsed;
  }
}

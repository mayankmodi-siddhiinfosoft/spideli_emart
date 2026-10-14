import 'package:customer/constant/constant.dart';
import 'package:customer/models/platform_fee_model.dart';
import 'package:customer/models/tax_model.dart';

/// The platform fee as every customer checkout charges it (parcel, food /
/// e-commerce cart, cab, intercity, rental, on-demand).
///
/// The rule: the section's fee is charged only while the admin has it
/// enabled (`sections/{id}.platformFee.enable`) and it is above 0; its taxes
/// (scope `platform`) only together with it. The order records exactly what
/// was charged: `platformFee` = [feeField] ("0.0" when not charged) and
/// `platformTax` = [taxes] (`[]` when not charged), so the screens, receipts,
/// refunds and the other apps that re-add the stored fee read the same total.
///
/// Rides, rentals and on-demand bookings used to add the fee whenever it was
/// set, even when the admin had disabled it (with no "Platform fee" line on
/// screen).
class PlatformFeeCharge {
  PlatformFeeCharge._(this.fee, this.taxes);

  /// Nothing charged.
  static PlatformFeeCharge get none => PlatformFeeCharge._(0, <TaxModel>[]);

  /// The fee charged (0 when none).
  final double fee;

  /// The platform taxes charged with it (empty when no fee is charged). A
  /// copy: the order may keep it as its `platformTax`.
  final List<TaxModel> taxes;

  /// What a NEW checkout charges for [setting] and its [platformTaxes].
  factory PlatformFeeCharge.of(PlatformFeeModel? setting, List<TaxModel>? platformTaxes) {
    final double v = amount(enabled: setting?.enable, fee: setting?.fee);
    return v > 0 ? PlatformFeeCharge._(v, List<TaxModel>.of(platformTaxes ?? const <TaxModel>[])) : none;
  }

  /// What an EXISTING order recorded (its own `platformFee` / `platformTax`):
  /// paying or showing it later never re-reads today's setting.
  factory PlatformFeeCharge.recorded(String? fee, List<TaxModel>? platformTaxes) {
    final double v = parse(fee);
    return v > 0 ? PlatformFeeCharge._(v, List<TaxModel>.of(platformTaxes ?? const <TaxModel>[])) : none;
  }

  /// The current section's setting (`Constant.sectionConstantModel.platformFee`,
  /// else the copy loaded with the section) and the section's platform taxes.
  static PlatformFeeCharge current() => PlatformFeeCharge.of(Constant.sectionConstantModel?.platformFee ?? Constant.platformFeeModel, Constant.platformTaxList);

  /// The fee a checkout charges: [fee] only while [enabled] is true, else 0;
  /// never negative.
  static double amount({bool? enabled, Object? fee}) {
    if (enabled != true) return 0;
    final double v = parse(fee);
    return v > 0 ? v : 0;
  }

  /// A stored amount (`"10"`, `10`, `""`, null) as a number; 0 when unreadable.
  static double parse(Object? value) {
    if (value is num) return value.isFinite ? value.toDouble() : 0;
    final double? v = double.tryParse((value ?? '').toString().trim());
    return v == null || !v.isFinite ? 0 : v;
  }

  /// True when a fee is charged.
  bool get charged => fee > 0;

  /// The order's `platformFee` field.
  String get feeField => fee.toString();

  /// The taxes on the fee, with [taxOf] (default [Constant.calculateTax]).
  double taxAmount([double Function({String? amount, TaxModel? taxModel}) taxOf = Constant.calculateTax]) {
    if (!charged) return 0;
    double sum = 0;
    for (final TaxModel tax in taxes) {
      sum += taxOf(amount: fee.toString(), taxModel: tax);
    }
    return sum;
  }
}

/// The order taxes (scope `order`) a checkout charges, as the website does:
/// only while the global tax setting applies taxes per order
/// (`settings/globalSettings.taxScope == "order"`). Each tax is already one
/// of the section's, for the customer's country, and enabled
/// (`FireStoreUtils.getTaxList`); a disabled one is dropped here too.
class OrderTaxCharge {
  OrderTaxCharge._();

  /// `globalSettings.taxScope` value that charges the order taxes.
  static const String orderScope = 'order';

  /// The taxes charged for [taxScope] and the section's [orderTaxes] (a copy;
  /// empty when the global setting does not apply order taxes).
  static List<TaxModel> of({required String? taxScope, required List<TaxModel>? orderTaxes}) =>
      taxScope == orderScope ? (orderTaxes ?? const <TaxModel>[]).where((t) => t.enable == true).toList() : <TaxModel>[];

  /// For the current section and global setting.
  static List<TaxModel> current() => of(taxScope: Constant.taxScope, orderTaxes: Constant.orderProductTaxList);
}

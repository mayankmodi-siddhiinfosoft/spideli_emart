// The bill of a parcel order, line by line, as the customer website shows it
// (checkout and placed order): subtotal, discount, platform charge,
// collection and delivery, the fixed tax and the receiver SMS when there are
// some, tax on the order total, each tax on the platform fee, total tax,
// order total.
//
// Pure Dart (no Flutter): the checkout and the order screen build their rows
// from [ParcelBill.lines], so both read the same lines.

/// How a line's amount is shown.
enum ParcelBillKind {
  /// The amount as it is.
  plain,

  /// Taken off: "-amount".
  discount,

  /// Added on top of the subtotal: "+amount".
  charge,

  /// A receiver SMS the sender's region charges nothing for: "Free".
  free,

  /// The order total.
  total,
}

class ParcelBillLine {
  /// Translation key of the label.
  final String label;

  /// Shown before [label] (the platform-fee tax's own title, "IGST").
  final String? prefix;
  final double amount;
  final ParcelBillKind kind;

  const ParcelBillLine(this.label, this.amount, {this.prefix, this.kind = ParcelBillKind.plain});

  @override
  String toString() => '${prefix == null ? '' : '$prefix '}$label: $amount (${kind.name})';
}

class ParcelBill {
  ParcelBill._();

  /// The lines of a bill. [orderTaxed]: order taxes were charged (the
  /// section has some and the global setting applies them per order), so
  /// "Tax on Order Total" is shown even at 0. [platformTaxes]: each tax on
  /// the platform fee as (title, amount), only when that fee was charged.
  static List<ParcelBillLine> lines({
    required double subTotal,
    required double discount,
    double platformFee = 0,
    double options = 0,
    double scopeTax = 0,
    bool receiverSms = false,
    double smsCharge = 0,
    bool orderTaxed = false,
    double orderTax = 0,
    List<(String, double)> platformTaxes = const [],
    required double total,
  }) {
    final double platformTax = platformTaxes.fold(0, (sum, t) => sum + t.$2);
    return [
      ParcelBillLine('Subtotal', subTotal),
      ParcelBillLine('Discount', discount, kind: ParcelBillKind.discount),
      if (platformFee > 0) ParcelBillLine('Platform Charge', platformFee),
      if (options > 0) ParcelBillLine('Collection and delivery', options, kind: ParcelBillKind.charge),
      if (scopeTax > 0) ParcelBillLine('Fixed tax', scopeTax),
      if (receiverSms) ParcelBillLine('Receiver SMS', smsCharge, kind: smsCharge > 0 ? ParcelBillKind.plain : ParcelBillKind.free),
      if (orderTaxed) ParcelBillLine('Tax on Order Total', orderTax),
      for (final (String title, double amount) in platformTaxes) ParcelBillLine('Tax on Platform Fee', amount, prefix: title.trim().isEmpty ? null : title.trim()),
      if (orderTaxed || platformTaxes.isNotEmpty) ParcelBillLine('Total Tax Amount', orderTax + platformTax),
      ParcelBillLine('Order Total', total, kind: ParcelBillKind.total),
    ];
  }
}

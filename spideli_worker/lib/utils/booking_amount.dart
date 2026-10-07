import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/model/onprovider_order_model.dart';

/// The price block of a booking, exactly as the booking details screen
/// ("Price Detail" card, `BookingDetailsScreen.priceTotalRow`) computes it:
///
/// * price      = (disPrice when set, else price) x quantity
/// * discount   = discountLabel % of price ("Percentage" / "Percent"), else
///                the flat discountLabel
/// * subTotal   = price - discount
/// * total      = subTotal + every tax of `taxModel` on subTotal
///                ([getTaxValue]: enabled taxes only, fixed or percentage)
/// * adminComm  = adminCommission % of subTotal, or the flat value
///
/// Extra charges added after the job are shown in their own card on that
/// screen and are not part of [totalAmount].
class BookingAmounts {
  final double price;
  final double discount;
  final double subTotal;
  final double adminComm;
  final double totalAmount;

  const BookingAmounts({required this.price, required this.discount, required this.subTotal, required this.adminComm, required this.totalAmount});

  static double _safeDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    final parsed = double.tryParse(value.toString());
    return parsed ?? defaultValue;
  }

  factory BookingAmounts.of(OnProviderOrderModel order) {
    final double price = (order.provider.disPrice == "" || order.provider.disPrice == "0")
        ? _safeDouble(order.provider.price) * order.quantity
        : _safeDouble(order.provider.disPrice) * order.quantity;

    final double discount =
        (order.discountType == 'Percentage' || order.discountType == 'Percent') ? price * _safeDouble(order.discountLabel) / 100 : _safeDouble(order.discountLabel);

    final double subTotal = price - discount;
    double total = subTotal;

    final double adminComm = (order.adminCommissionType == 'Percent') ? (total * _safeDouble(order.adminCommission)) / 100 : _safeDouble(order.adminCommission);

    if (order.taxModel != null) {
      for (var element in order.taxModel!) {
        total = total + getTaxValue(amount: subTotal.toString(), taxModel: element);
      }
    }
    return BookingAmounts(price: price, discount: discount, subTotal: subTotal, adminComm: adminComm, totalAmount: total);
  }
}

/// The status label of a job, as the Jobs list's chip shows it (before
/// translation): "Pending", "Assigned", "Completed" or "In progress".
String jobStatusLabel(String status) {
  if (status == ORDER_STATUS_PLACED) return "Pending";
  if (status == ORDER_STATUS_ACCEPTED || status == ORDER_STATUS_ASSIGNED) return "Assigned";
  if (status == ORDER_STATUS_COMPLETED) return "Completed";
  return "In progress";
}

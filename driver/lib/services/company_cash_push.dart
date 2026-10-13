/// The company cash pushes (`CompanyCashService`) and their placeholders.
///
/// Their text comes only from the `dynamic_notification` templates below
/// (no app-side text, like every other driver push); a missing template
/// means no push (logged by `SendNotification.sendFcmMessage`). The app fills
/// the placeholders with `PushTemplateText.fill`. The routing data and the
/// channel (`driver_notifications_channel`) are unchanged.
///
/// | Template type | Recipient | Placeholders |
/// |---|---|---|
/// | `company_cash_collected` | company owner | `{driverName}`, `{amount}`, `{orderId}`, `{companyName}` |
/// | `company_cash_settlement_submitted` | company owner | `{driverName}`, `{amount}`, `{reference}`, `{companyName}` |
/// | `company_cash_settlement_confirmed` | the driver | `{driverName}`, `{amount}`, `{reference}`, `{companyName}` |
/// | `company_cash_settlement_rejected` | the driver | `{driverName}`, `{amount}`, `{reference}`, `{companyName}`, `{reason}` |
/// | `company_cash_adjustment` | the driver | `{driverName}`, `{amount}`, `{signedAmount}`, `{reference}`, `{companyName}`, `{reason}` |
abstract final class CompanyCashPush {
  /// A company driver collected cash on delivery (to the owner).
  static const String collected = 'company_cash_collected';

  /// A driver handed a cash settlement in for review (to the owner).
  static const String settlementSubmitted = 'company_cash_settlement_submitted';

  /// The owner confirmed a settlement (to the driver).
  static const String settlementConfirmed = 'company_cash_settlement_confirmed';

  /// The owner rejected a settlement (to the driver).
  static const String settlementRejected = 'company_cash_settlement_rejected';

  /// The owner adjusted the driver's cash ledger (to the driver).
  static const String adjustment = 'company_cash_adjustment';

  /// Every template type, for documentation and tests.
  static const List<String> templates = [collected, settlementSubmitted, settlementConfirmed, settlementRejected, adjustment];

  /// The placeholder values of one push. [amount] is already formatted in
  /// the record's currency; [isCredit] (adjustments) gives `{signedAmount}`
  /// as `+<amount>` / `-<amount>`. Absent values are left out, so their
  /// placeholders stay visible in the text.
  static Map<String, String> values({
    required String amount,
    String? driverName,
    String? companyName,
    String? orderId,
    String? reference,
    String? reason,
    bool? isCredit,
  }) {
    String? clean(String? v) {
      final String t = (v ?? '').trim();
      return t.isEmpty ? null : t;
    }

    return {
      'amount': amount,
      if (isCredit != null) 'signedAmount': '${isCredit ? '+' : '-'}$amount',
      if (clean(driverName) != null) 'driverName': clean(driverName)!,
      if (clean(companyName) != null) 'companyName': clean(companyName)!,
      if (clean(orderId) != null) 'orderId': clean(orderId)!,
      if (clean(reference) != null) 'reference': clean(reference)!,
      if (clean(reason) != null) 'reason': clean(reason)!,
    };
  }

  /// The company's name for `{companyName}`: the name of its CARRIER (the
  /// `delivery_carriers` record the admin bound the owner to - the name
  /// customers choose, client decision 13 Oct 2026), else the owner account's
  /// `companyName`, else the owner's own name.
  static String companyNameOf({String? carrierName, String? companyName, String? ownerName}) {
    for (final String? v in [carrierName, companyName, ownerName]) {
      final String t = (v ?? '').trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }
}

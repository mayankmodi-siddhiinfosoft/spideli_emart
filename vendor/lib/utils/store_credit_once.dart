/// The store's credit for an order, paid once - the same rule in the Store and
/// Driver apps (this file is mirrored in
/// `driver/lib/services/store_credit_once.dart`; keep the two identical).
///
/// Both apps credit the store: the Store app when it accepts, assigns its own
/// delivery man, ships or completes an order, the Driver app when it completes
/// the delivery. On a self-delivery order the store and its delivery man can
/// complete at the same moment, so a check-then-write could pay twice. The
/// rule both apps follow instead:
///
/// 1. Outside the transaction, any `wallet` row of the order that
///    [isCreditRow] means it was credited already - this is how rows an older
///    build wrote under random ids are still recognised.
/// 2. Inside ONE Firestore transaction: read the order and the credit row
///    `wallet/{creditRowId}`; if [alreadyCredited], write nothing. Otherwise
///    write the credit row and the tax row under their deterministic ids, add
///    the credit to the owner's `users/{ownerId}.wallet_amount` and to the
///    store's `vendors/{storeId}.wallet_amount`, and set the order's
///    [orderFlag] to true.
///
/// Two apps racing each other both read the credit row as missing; Firestore
/// lets one commit and re-runs the other, which then finds the row and pays
/// nothing.
abstract final class StoreCreditOnce {
  /// The order-amount row (`payment_method` 'Wallet'). The Driver app has
  /// written this id since it began crediting the store, so orders it already
  /// credited are recognised by both apps.
  static String creditRowId(String orderId) => 'vendorcredit_$orderId';

  /// The tax row (`payment_method` 'tax'), written with the credit row.
  static String taxRowId(String orderId) => 'vendortax_$orderId';

  /// Set on `vendor_orders/{orderId}` in the transaction that pays the credit.
  static const String orderFlag = 'vendorCredited';

  /// A `wallet` row that credits an order to the store, whatever its id.
  static bool isCreditRow(Map<String, dynamic>? row) =>
      row != null && row['transactionUser'] == 'vendor' && row['isTopUp'] == true && row['payment_method'] == 'Wallet';

  /// Whether some row among an order's `wallet` rows credits it to the store.
  static bool anyCreditRow(Iterable<Map<String, dynamic>?> rows) => rows.any(isCreditRow);

  /// Decided inside the transaction, from what it read: the credit row exists,
  /// or the order carries [orderFlag].
  static bool alreadyCredited({required bool creditRowExists, required Map<String, dynamic>? order}) =>
      creditRowExists || order?[orderFlag] == true;
}

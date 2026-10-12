import 'dart:developer';

/// How a wallet payment ended.
enum WalletPayOutcome {
  /// The wallet was debited AND the order (or its "paid" state) was written,
  /// in one Firestore transaction.
  paid,

  /// The balance (re-read inside the transaction) is below the amount:
  /// nothing was written, no money was taken.
  insufficient,

  /// The transaction failed (offline, refused, no user record): nothing was
  /// written, no money was taken.
  failed,
}

/// Wallet checkouts: money is never taken without the order it pays for.
///
/// Every customer checkout that pays from the wallet (parcel, food /
/// e-commerce cart, cab and intercity rides, rentals, on-demand bookings and
/// their extra charges, gift cards) commits, in ONE Firestore transaction
/// (`FireStoreUtils.payFromWallet`):
///
///  1. a re-read of `users/{uid}.wallet_amount`, refused when below the
///     amount ([debitedBalance]);
///  2. the debit of `wallet_amount` and its `wallet/{id}` row;
///  3. the order document itself (a new order), or its paid state
///     (`paymentStatus` / `paymentMethod` on an existing booking).
///
/// Firestore applies all of it or none of it, so there is no state where the
/// money is gone and the order is missing or still unpaid, and nothing to
/// cancel or refund afterwards. (Before: the debit was written first, the
/// order separately afterwards; a failed order save lost the money.)
///
/// Only once that commit succeeded ([pay]) do the side effects run: pushes to
/// the store / driver / company owner / provider, emails, stock updates. A
/// side effect that throws never turns a paid order into a failure.
abstract final class WalletCheckout {
  /// The wallet balance after debiting [amount] from [balance] (as stored:
  /// a number or a numeric string), or null when the debit must be refused
  /// (balance unreadable or below [amount], or [amount] not positive).
  static num? debitedBalance({required Object? balance, required num amount}) {
    if (!amount.isFinite || amount <= 0) return null;
    final num? current = balance is num ? balance : num.tryParse((balance ?? '').toString().trim());
    if (current == null || !current.isFinite) return null;
    // A cent of float noise (e.g. 30.000000000000004) is not a shortfall.
    if (current + 0.000001 < amount) return null;
    final num next = current - amount;
    return next < 0 ? 0 : next;
  }

  /// Runs [commit] (the single wallet + order transaction) and, only when it
  /// returned [WalletPayOutcome.paid], [afterPaid]. A [commit] that throws
  /// counts as [WalletPayOutcome.failed]; an [afterPaid] that throws is
  /// logged and the outcome stays [WalletPayOutcome.paid] (the money and the
  /// order are already consistent).
  static Future<WalletPayOutcome> pay({required Future<WalletPayOutcome> Function() commit, Future<void> Function()? afterPaid}) async {
    WalletPayOutcome outcome;
    try {
      outcome = await commit();
    } catch (e) {
      log('Wallet payment failed, nothing was taken: $e');
      outcome = WalletPayOutcome.failed;
    }
    if (outcome != WalletPayOutcome.paid || afterPaid == null) return outcome;
    try {
      await afterPaid();
    } catch (e) {
      log('Wallet payment done; a follow-up step failed: $e');
    }
    return outcome;
  }

  /// The message (translation key) for a payment that did not go through.
  static String failureMessage(WalletPayOutcome outcome) =>
      outcome == WalletPayOutcome.insufficient ? 'You do not have sufficient wallet balance' : 'Payment failed. No money was taken from your wallet. Please try again.';
}

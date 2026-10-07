/// A customer's rating added to a driver's review totals
/// (`users/{driverId}.reviewsCount` / `reviewsSum`).
///
/// Every app writes those two fields of a user document as strings ("12"),
/// while a store's and a worker's are numbers. `FieldValue.increment` would
/// turn a string "12" into the bare increment (Firestore replaces a
/// non-numeric value), so a driver's totals are re-read and written back in
/// a transaction - only these two fields, never the rest of the driver's
/// document - in the type they are stored in. Pure, unit tested.
abstract final class UserReviewTotals {
  /// The change a rating makes: a new review adds one review and its stars;
  /// an edited one ([previousRating] set) only the difference in stars.
  static ({num countDelta, num sumDelta}) delta({required num rating, num? previousRating}) =>
      previousRating == null ? (countDelta: 1, sumDelta: rating) : (countDelta: 0, sumDelta: rating - previousRating);

  /// `reviewsCount` and `reviewsSum` of [current] (the driver's document as
  /// read now) with [countDelta] / [sumDelta] added; never below zero. Each
  /// keeps its stored type: a number stays a number, anything else (the usual
  /// string, or a missing field) is written as a string.
  static Map<String, dynamic> applied(Map<String, dynamic>? current, {required num countDelta, required num sumDelta}) => {
        'reviewsCount': _add(current?['reviewsCount'], countDelta),
        'reviewsSum': _add(current?['reviewsSum'], sumDelta),
      };

  static Object _add(dynamic stored, num delta) {
    num before = stored is num ? stored : (num.tryParse(stored?.toString().trim() ?? '') ?? 0);
    if (!before.isFinite) before = 0;
    num after = before + delta;
    if (after < 0) after = 0;
    if (after == after.roundToDouble()) after = after.round();
    return stored is num ? after : after.toString();
  }
}

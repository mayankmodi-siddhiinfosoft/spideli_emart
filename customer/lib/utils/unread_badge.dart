/// How an unread count is shown on a badge (chat rows, the notification bell,
/// the Help & Support row). Pure, so it is unit tested.
abstract final class UnreadBadge {
  /// Above this the badge reads `99+`.
  static const int cap = 99;

  /// How many unread documents a live badge listener reads at most: one more
  /// than [cap], enough to know the badge reads `99+` without loading a whole
  /// thread or the whole notification history.
  static const int queryLimit = cap + 1;

  /// '' for no badge (zero or a negative count), the count, or `99+`.
  static String label(int count, {int max = cap}) {
    if (count <= 0) return '';
    if (count > max) return '$max+';
    return '$count';
  }
}

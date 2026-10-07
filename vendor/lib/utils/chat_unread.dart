/// Unread badge of one conversation in the store's chat inboxes
/// (`.claude/CUSTOMER-NOTIFICATIONS.md` section 2).
///
/// How the count is read (`FireStoreUtils.unreadChatCount`): a live,
/// limited listener on that conversation's thread,
/// `chat/{threadId}/thread where receiverId == storeSideId && seen == false
/// limit(queryLimit)` (an admin conversation: `senderId == 'admin'` instead of
/// `receiverId`). Equality filters only, so no composite index is needed, and
/// at most [queryLimit] small documents are read per row, never the whole
/// thread. Opening the conversation marks those same messages seen
/// (`FireStoreUtils.setSeenChatForOrder`), which drops the badge live.
///
/// Pure (test/customer_notification_test.dart).
class ChatUnread {
  ChatUnread._();

  /// Highest count shown as a number; above it the badge reads `99+`.
  static const int displayCap = 99;

  /// Documents the listener reads at most: one more than [displayCap], so
  /// `99+` can be told apart from `99`.
  static const int queryLimit = displayCap + 1;

  /// Badge text for [count] unread messages; empty when there is nothing to
  /// show (no badge).
  static String label(int? count) {
    final int n = count ?? 0;
    if (n <= 0) return '';
    if (n > displayCap) return '$displayCap+';
    return '$n';
  }

  /// True when a badge is shown for [count].
  static bool hasBadge(int? count) => (count ?? 0) > 0;
}

/// Chat unread badge rules (`.claude/CUSTOMER-NOTIFICATIONS.md` section 2).
///
/// A conversation's unread count is the number of messages in
/// `chat/{orderId}/thread` with `receiverId == <signed-in driver>` and
/// `seen == false`, read by a live listener limited to [queryLimit] documents
/// (`FireStoreUtils.unreadOrderChatCount`). Only equality filters, so no
/// composite index is needed and a long thread is never loaded whole.
library;

class ChatUnread {
  ChatUnread._();

  /// Highest count shown as a number; more is shown as `99+`.
  static const int displayCap = 99;

  /// Documents the listener reads at most: one more than [displayCap], so
  /// `99+` can be told apart from 99.
  static const int queryLimit = displayCap + 1;

  /// The badge text for [count]: empty (no badge) at zero or below, the
  /// number up to [displayCap], `99+` above it.
  static String label(int count) {
    if (count <= 0) return '';
    if (count > displayCap) return '$displayCap+';
    return '$count';
  }

  /// True when a message (thread document [data]) counts as unread for
  /// [myId]: addressed to me and not seen yet. Mirrors the query.
  static bool isUnreadFor(Map<String, dynamic>? data, String myId) {
    if (data == null || myId.trim().isEmpty) return false;
    return data['receiverId'] == myId && data['seen'] == false;
  }
}

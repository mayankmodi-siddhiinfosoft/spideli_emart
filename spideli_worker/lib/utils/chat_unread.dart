/// Chat unread badges (`.claude/CUSTOMER-NOTIFICATIONS.md` 2), pure parts.
///
/// A conversation's unread count is the number of messages in
/// `chat/{orderId}/thread` with `receiverId == <this worker>` and
/// `seen == false`. The inbox row listens to that query limited to
/// [chatUnreadQueryLimit] documents (two equality filters: served by the
/// automatic single-field indexes, no composite index), so a thread is never
/// loaded whole; the same filter is what opening the conversation marks seen
/// (FireStoreUtils.markOrderChatSeen). Unit tested in
/// test/chat_unread_test.dart.
library;

/// Highest count shown as a number; above it the badge reads `99+`.
const int chatUnreadDisplayMax = 99;

/// The listener reads at most this many unread messages: one more than
/// [chatUnreadDisplayMax], enough to know the badge says `99+`.
const int chatUnreadQueryLimit = chatUnreadDisplayMax + 1;

/// The badge text: '' (no badge) for 0 or less, the number up to 99, `99+`.
String chatUnreadBadgeLabel(int count) {
  if (count <= 0) return '';
  if (count > chatUnreadDisplayMax) return '$chatUnreadDisplayMax+';
  return '$count';
}

/// A message counts as unread for [me] when it is addressed to [me] and not
/// seen yet (`seen` missing on very old messages: not counted, they were never
/// tracked). Mirrors the Firestore query, so documents can be re-checked.
bool isUnreadChatMessageFor(Map<String, dynamic>? message, String me) {
  if (message == null || me.trim().isEmpty) return false;
  return (message['receiverId'] ?? '').toString() == me && message['seen'] == false;
}

/// The unread count of a snapshot's documents for [me].
int unreadChatCount(Iterable<Map<String, dynamic>?> messages, String me) => messages.where((m) => isUnreadChatMessageFor(m, me)).length;

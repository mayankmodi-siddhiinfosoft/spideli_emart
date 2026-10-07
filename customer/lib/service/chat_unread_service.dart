import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/unread_badge.dart';

/// Live unread counts of the customer's chats (`.claude/CUSTOMER-NOTIFICATIONS.md` §2).
///
/// A conversation is one thread, `chat/{threadId}/thread` (the order id for an
/// order chat with a store, driver, provider or worker; the customer's uid for
/// the Help & Support chat). Its unread count is the number of messages in it
/// still `seen == false` that were sent to this customer. One limited listener
/// per visible row, equality filters only (no composite index needed), at
/// most [UnreadBadge.queryLimit] documents read: the badge shows `99+` past
/// that. Opening the thread marks the same messages seen
/// (`FireStoreUtils.setSeenChatForOrder` / `setSeen`), so the badge clears live.
abstract final class ChatUnreadService {
  /// Unread messages of the order chat [threadId] sent by [peerId] to [uid].
  ///
  /// The store and driver chats of one order share `chat/{orderId}/thread`
  /// (so do the provider and worker chats of one booking), so a conversation
  /// is the thread AND the peer: without the `senderId` filter the store row
  /// and the driver row would show the same combined count. An empty
  /// [peerId] (inbox row without ids) counts the whole thread.
  static Stream<int> orderThread({required String threadId, required String uid, String peerId = ''}) {
    final String id = threadId.trim();
    if (id.isEmpty || uid.trim().isEmpty) return Stream<int>.value(0);
    return FireStoreUtils.unreadOrderChatQuery(threadId: id, receiverId: uid.trim(), senderId: peerId.trim())
        .limit(UnreadBadge.queryLimit)
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Unread admin messages of [uid]'s Help & Support chat (the same filter
  /// `FireStoreUtils.setSeen` marks seen).
  static Stream<int> supportThread({required String uid}) {
    final String id = uid.trim();
    if (id.isEmpty) return Stream<int>.value(0);
    return FireStoreUtils.fireStore
        .collection(CollectionName.chat)
        .doc(id)
        .collection('thread')
        .where('senderId', isEqualTo: Constant.adminType)
        .where('seen', isEqualTo: false)
        .limit(UnreadBadge.queryLimit)
        .snapshots()
        .map((snap) => snap.size);
  }
}

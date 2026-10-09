import 'package:customer/constant/constant.dart';
import 'package:customer/service/chat_unread_service.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/unread_sum.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// The four order inboxes of the profile screen's Communication group.
enum InboxKind { store, driver, provider, worker }

/// Live total unread count of a whole inbox, for the profile screen's inbox
/// rows (`.claude/CUSTOMER-NOTIFICATIONS.md` §2).
///
/// It listens to the inbox's newest [conversationCap] conversations (the same
/// query as the inbox screen, [FireStoreUtils.orderInboxQuery]) and, for each,
/// to the same per-conversation listener as that screen's row badge
/// ([ChatUnreadService.orderThread]: thread AND peer, `seen == false`,
/// equality filters only, at most 100 documents), and emits their sum
/// ([UnreadSum.sumOf]). Conversations entering or leaving the newest
/// [conversationCap] are subscribed / cancelled live; everything is cancelled
/// with the badge. Follows sign-in / sign-out on its own (0 while signed out).
abstract final class InboxUnreadService {
  /// How many conversations (newest first) an inbox total covers. Unread
  /// messages in older conversations are not counted on the profile badge
  /// (their row in the inbox screen still shows them); this bounds the
  /// listeners to [conversationCap] + 1 per inbox.
  static const int conversationCap = 50;

  /// The inbox document's `chatType` of [kind] (as the inbox screens filter).
  static String chatTypeOf(InboxKind kind) => switch (kind) {
    InboxKind.store => Constant.userRoleVendor,
    InboxKind.driver => Constant.userRoleDriver,
    InboxKind.provider => Constant.userRoleProvider,
    InboxKind.worker => Constant.userRoleWorker,
  };

  /// The signed-in customer's unread total of the [kind] inbox, live.
  static Stream<int> total(InboxKind kind) => UnreadSum.perUser(authUids(), (uid) => forUser(uid, kind));

  /// [uid]'s unread total of the [kind] inbox, live.
  static Stream<int> forUser(String uid, InboxKind kind) {
    final Stream<List<InboxThread>> threads = FireStoreUtils.orderInboxQuery(
      uid: uid,
      chatType: chatTypeOf(kind),
    ).limit(conversationCap).snapshots().map((snap) => UnreadSum.threadsOf(snap.docs.map((d) => d.data()), uid));
    return UnreadSum.sumOf<InboxThread>(threads, (t) => ChatUnreadService.orderThread(threadId: t.threadId, uid: uid, peerId: t.peerId));
  }

  /// The signed-in uid, now and on every sign-in / sign-out (null when out).
  static Stream<String?> authUids() => FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
}

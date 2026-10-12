import 'package:vendor/models/permission_model.dart';
import 'package:vendor/utils/store_chat.dart';

/// The store-chat topic: the customer app sends every chat message to a store
/// to the owner's token (as always) AND to the FCM topic
/// `store_chat_<vendorID>`. This device subscribes to that topic only while
/// the signed-in user is an EMPLOYEE of that store whose role allows Chat
/// ([StoreChat.allowed]); never for the owner, who already gets the token
/// push, so nobody is notified twice. See `.claude/PUSH-CHANNELS.md`,
/// "Store chat topic".
///
/// Pure (test/store_chat_topic_test.dart); subscribing is
/// `StoreChatTopicService`. The name rule is the same as the customer app's
/// (`customer/lib/utils/store_chat_push.dart`); both must stay identical.
class StoreChatTopic {
  StoreChatTopic._();

  /// Prefix of every store chat topic.
  static const String prefix = 'store_chat_';

  /// FCM topic names: `[a-zA-Z0-9-_.~%]{1,900}` (without `/topics/`).
  static final RegExp _validTopic = RegExp(r'^[a-zA-Z0-9\-_.~%]{1,900}$');

  static bool isValidTopic(String? topic) => _validTopic.hasMatch(topic ?? '');

  /// Whether [topic] is one of ours (only those are ever unsubscribed).
  static bool isStoreChatTopic(String? topic) => (topic ?? '').startsWith(prefix) && isValidTopic(topic);

  /// `store_chat_<vendorID>` for the store's `vendors/{id}` id, or null when
  /// the id is empty or makes a name FCM refuses.
  static String? forVendor(String? vendorId) {
    final String id = (vendorId ?? '').trim();
    if (id.isEmpty) return null;
    final String topic = '$prefix$id';
    return isValidTopic(topic) ? topic : null;
  }

  /// The topic this device should be subscribed to for the signed-in user,
  /// or null for none: signed out, the owner (or any non-employee), an
  /// employee whose role does not (or no longer) allow Chat, or an employee
  /// without a store.
  static String? desired({required bool signedIn, required String? role, required String? vendorId, List<PermissionModel>? permissions}) {
    if (!signedIn) return null;
    if (!StoreChat.isEmployee(role)) return null;
    if (!StoreChat.allowed(role: role, permissions: permissions)) return null;
    return forVendor(vendorId);
  }

  /// From the [remembered] topic (preferences) to the [desired] one.
  /// [resubscribe]: subscribe again even when it is unchanged (first check
  /// of a run, or a new FCM token), which is harmless for FCM.
  static StoreChatTopicChange change({required String? remembered, required String? desired, bool resubscribe = false}) {
    final String? from = isStoreChatTopic(remembered?.trim()) ? remembered!.trim() : null;
    final String? to = isValidTopic(desired?.trim()) ? desired!.trim() : null;
    if (from == to) return StoreChatTopicChange(subscribe: resubscribe ? to : null);
    return StoreChatTopicChange(unsubscribe: from, subscribe: to);
  }
}

/// What to do with the device's store chat topic. Unsubscribe first; only a
/// successful unsubscribe forgets the old topic, and only a successful
/// subscribe remembers the new one.
class StoreChatTopicChange {
  const StoreChatTopicChange({this.unsubscribe, this.subscribe});

  final String? unsubscribe;
  final String? subscribe;

  bool get isNone => unsubscribe == null && subscribe == null;

  @override
  bool operator ==(Object other) => other is StoreChatTopicChange && other.unsubscribe == unsubscribe && other.subscribe == subscribe;

  @override
  int get hashCode => Object.hash(unsubscribe, subscribe);

  @override
  String toString() => 'StoreChatTopicChange(unsubscribe: $unsubscribe, subscribe: $subscribe)';
}

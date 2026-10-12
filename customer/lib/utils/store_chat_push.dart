/// The store-chat topic push: a customer's chat message to a STORE also goes
/// to the FCM topic `store_chat_<vendorID>`, which the store app subscribes
/// for each EMPLOYEE whose role allows Chat (never for the owner, who keeps
/// getting the message on their own token, so nobody is notified twice).
/// See `.claude/PUSH-CHANNELS.md`, "Store chat topic".
///
/// Pure (test/store_chat_push_test.dart). The same name rule is in the store
/// app (`vendor/lib/utils/store_chat_topic.dart`); both must stay identical.
library;

import 'package:customer/service/push_message.dart';

abstract final class StoreChatTopic {
  /// Prefix of every store chat topic.
  static const String prefix = 'store_chat_';

  /// `store_chat_<vendorID>` for the store's `vendors/{id}` document id, or
  /// null when the id is empty or would make a topic FCM refuses (then no
  /// topic push is sent at all).
  static String? forVendor(String? vendorId) {
    final String id = (vendorId ?? '').trim();
    if (id.isEmpty) return null;
    final String topic = '$prefix$id';
    return PushPayload.isValidTopic(topic) ? topic : null;
  }

  /// The store a chat message goes to: the first non-empty of the chat
  /// arguments' id, the order's `vendorID`, and the owner's profile
  /// `vendorID` (last: an owner with several stores keeps only the selected
  /// one there).
  static String vendorIdFrom({String? argument, String? orderVendorId, String? receiverVendorId}) {
    for (final String? v in [argument, orderVendorId, receiverVendorId]) {
      final String id = (v ?? '').trim();
      if (id.isNotEmpty && id.toLowerCase() != 'null') return id;
    }
    return '';
  }
}

/// Why a message gets no store-chat topic push.
enum StoreChatTopicSkip {
  /// Sent: no reason.
  none,

  /// The other side of the chat is not a store (driver, provider, ...).
  notStore,

  /// The store's `vendors` id could not be found (or is not a valid topic).
  unknownStore,

  /// `serverPushUrl` is set: the `sendPush` function only takes topics from
  /// admin accounts (`.claude/SERVER-PUSH-CONTRACT.md`, `topic`).
  serverPath,
}

/// The pushes one customer chat message makes.
class StoreChatPushPlan {
  const StoreChatPushPlan({required this.ownerToken, required this.topic, required this.topicSkip});

  /// The recipient's own token push (today's push, unchanged): true when
  /// there is a usable token.
  final bool ownerToken;

  /// The extra topic push, or null ([topicSkip] says why).
  final String? topic;

  final StoreChatTopicSkip topicSkip;

  static bool _isStore(String? chatType) {
    switch ((chatType ?? '').trim().toLowerCase()) {
      case 'vendor':
      case 'store':
      case 'restaurant':
        return true;
      default:
        return false;
    }
  }

  /// [chatType] is the other side's role; [vendorId] the store's id when it
  /// is one; [hasOwnerToken] whether the recipient has a usable token;
  /// [serverPush] whether the server path is on.
  factory StoreChatPushPlan.of({required String? chatType, required String? vendorId, required bool hasOwnerToken, required bool serverPush}) {
    if (!_isStore(chatType)) return StoreChatPushPlan(ownerToken: hasOwnerToken, topic: null, topicSkip: StoreChatTopicSkip.notStore);
    final String? topic = StoreChatTopic.forVendor(vendorId);
    if (topic == null) return StoreChatPushPlan(ownerToken: hasOwnerToken, topic: null, topicSkip: StoreChatTopicSkip.unknownStore);
    if (serverPush) return StoreChatPushPlan(ownerToken: hasOwnerToken, topic: null, topicSkip: StoreChatTopicSkip.serverPath);
    return StoreChatPushPlan(ownerToken: hasOwnerToken, topic: topic, topicSkip: StoreChatTopicSkip.none);
  }

  /// Whether this message is a store chat at all (resolving the store id is
  /// only worth a read then).
  static bool isStoreChat(String? chatType) => _isStore(chatType);

  @override
  String toString() => 'StoreChatPushPlan(ownerToken: $ownerToken, topic: $topic, skip: ${topicSkip.name})';
}

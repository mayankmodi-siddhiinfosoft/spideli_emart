import 'package:vendor/models/permission_model.dart';

/// Who "the store" is in its chats, and who may use them.
///
/// Every chat the store takes part in is keyed on ONE id, the store's chat
/// identity: the store owner's user id (`vendors/{id}.author`). The customer
/// app opens a store conversation with `receivedId = order.vendor.author`
/// (the owner), lists it by `sender_receiver_id arrayContains <owner>`, counts
/// and marks seen the store's messages by `senderId == <owner>`, and pushes to
/// the owner's token. The admin panel reads the store's support thread at
/// `chat/{owner}` and the advertisement inbox by `restaurantId == <owner>`.
///
/// So an employee of the store reads and writes every chat AS the owner:
/// the inbox lists the owner's conversations, the badges count messages
/// addressed to the owner, "seen" marks those, and a reply is written with
/// `senderId = <owner>` (the customer then sees it in the same thread, on the
/// store's side). The employee's own uid is only recorded for audit in
/// `sentByUserId` / `sentByName`, which no reader filters on.
///
/// Before, every one of those keys was the signed-in uid, so an employee's
/// inbox query (`arrayContains <employee>`) matched nothing: "No conversion
/// found".
///
/// Pure (test/store_chat_test.dart); the Firestore lookup of the owner is
/// `StoreChatSession` in `store_chat_session.dart`.
class StoreChat {
  StoreChat._();

  /// The role permission that opens the store's chats (customer order chats
  /// and the admin chats). Also the permission's label (`'Chat'.tr`).
  static const String permission = 'Chat';

  /// `Constant.userRoleEmployee` (kept here as a literal so this file stays
  /// free of Flutter / Firebase imports).
  static const String employeeRole = 'employee';

  /// `chatType` of a customer <-> store conversation (`Constant.userRoleVendor`).
  static const String vendorChatType = 'vendor';

  /// `type` of an order conversation's inbox document.
  static const String orderChatType = 'orderChat';

  static bool isEmployee(String? role) => (role ?? '').trim() == employeeRole;

  /// Whether a user with [role] may open the store's chats.
  ///
  /// Anyone who is not an employee (the owner) always may. An employee may
  /// only when their role (`vendor_employee_roles/{employeePermissionId}`)
  /// has a [permission] entry (title compared case-insensitively) that is
  /// active - the same entry the store panel saves on a role
  /// (`{title: 'Chat', isActive}`). A role saved before that entry existed
  /// has none and is NOT allowed until it is saved again with it ticked; no
  /// role at all (not loaded, deleted) = no chat.
  static bool allowed({required String? role, List<PermissionModel>? permissions}) {
    if (!isEmployee(role)) return true;
    return _find(permissions, permission)?.isActive == true;
  }

  /// [permissions] with a [permission] entry added, switched off, when it has
  /// none (a role saved before the entry existed, opened for editing), so the
  /// role editor shows the switch. The list is returned unchanged otherwise.
  static List<PermissionModel> withChatPermission(List<PermissionModel>? permissions) {
    final List<PermissionModel> list = List<PermissionModel>.of(permissions ?? const []);
    if (_find(list, permission) == null) {
      list.add(PermissionModel(title: permission, isActive: false));
    }
    return list;
  }

  /// The store's chat identity for a signed-in user: their own uid for the
  /// owner (unchanged), the store owner's uid ([storeOwnerId],
  /// `vendors/{vendorID}.author`) for an employee. Empty when an employee's
  /// store owner is unknown - never the employee's own uid, which would put
  /// their messages in a conversation nobody else reads.
  static String storeChatId({required String? role, required String uid, String? storeOwnerId}) {
    if (!isEmployee(role)) return uid.trim();
    return (storeOwnerId ?? '').trim();
  }

  static PermissionModel? _find(List<PermissionModel>? permissions, String title) {
    for (final PermissionModel p in permissions ?? const <PermissionModel>[]) {
      if ((p.title ?? '').trim().toLowerCase() == title.toLowerCase()) return p;
    }
    return null;
  }
}

/// The store side of the chats for the signed-in user (see [StoreChat]).
class StoreChatIdentity {
  /// The store's chat id: the owner's uid. Every read and write uses it.
  final String storeId;

  /// The signed-in user (the owner, or the employee).
  final String actorId;

  /// The signed-in user's name, for the audit field of an employee's message.
  final String actorName;

  /// The name the store writes as: the owner's own name for the owner (as
  /// before), the store's name for an employee.
  final String displayName;

  /// Picture shown for the store side.
  final String photo;

  /// The signed-in user is an employee of the store.
  final bool isEmployee;

  /// The signed-in user may use the store's chats ([StoreChat.allowed]).
  final bool canChat;

  const StoreChatIdentity({
    required this.storeId,
    required this.actorId,
    this.actorName = '',
    this.displayName = '',
    this.photo = '',
    required this.isEmployee,
    required this.canChat,
  });

  /// Builds the identity from the signed-in user's profile and their store.
  factory StoreChatIdentity.of({
    required String uid,
    required String? role,
    String? actorName,
    String? storeOwnerId,
    String? ownerName,
    String? storeName,
    String? storePhoto,
    String? ownPhoto,
    List<PermissionModel>? permissions,
  }) {
    final bool employee = StoreChat.isEmployee(role);
    String pick(List<String?> values) => values.map((v) => (v ?? '').trim()).firstWhere((v) => v.isNotEmpty, orElse: () => '');
    return StoreChatIdentity(
      storeId: StoreChat.storeChatId(role: role, uid: uid, storeOwnerId: storeOwnerId),
      actorId: uid.trim(),
      actorName: (actorName ?? '').trim(),
      displayName: employee ? pick([storeName, ownerName]) : pick([actorName]),
      photo: employee ? pick([storePhoto]) : pick([ownPhoto]),
      isEmployee: employee,
      canChat: StoreChat.allowed(role: role, permissions: permissions),
    );
  }

  /// The store's chats can be read and written: the user may chat and the
  /// store's chat id is known.
  bool get ready => canChat && storeId.isNotEmpty;

  // ── What each query and write keys on: always the store, never the actor ──

  /// `chat where sender_receiver_id arrayContains ...` (the order inbox).
  String get inboxMemberId => storeId;

  /// `thread where receiverId == ... && seen == false` (badge and "seen").
  String get unreadReceiverId => storeId;

  /// `chat/{...}/thread` of the store's Help & Support conversation.
  String get supportThreadId => storeId;

  /// `chat_admin where restaurantId == ...` (the advertisement inbox).
  String get adminInboxStoreId => storeId;

  /// `senderId` of every message and inbox document the store writes.
  String get senderId => storeId;

  /// A message in a thread was written by the store side (by the owner, or
  /// by this employee before the store identity was used).
  bool isStoreSide(String? messageSenderId) {
    final String id = (messageSenderId ?? '').trim();
    return id.isNotEmpty && (id == storeId || id == actorId);
  }

  /// Extra fields of a message an employee writes (who actually wrote it);
  /// none for the owner, whose messages stay exactly as before.
  Map<String, String> get auditFields => isEmployee ? {'sentByUserId': actorId, if (actorName.isNotEmpty) 'sentByName': actorName} : const {};
}

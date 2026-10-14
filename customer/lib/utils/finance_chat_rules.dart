/// Spideli Finance chat: direct conversations between two members and one
/// group conversation per tontine (.claude/FINANCE-DIRECT-FIRESTORE.md 3.11).
/// Text only. The pure rules and the writes the app makes, unit tested in
/// test/finance_chat_test.dart.
///
/// `finance_chats/{chatId}`: `dm_{uidA}_{uidB}` (sorted) or `tontine_{tid}`,
/// `{id, type: direct | tontine, memberIds (direct), tontineId (group),
/// lastMessage {text, senderId, at}, updatedAt, lastReadAt {uid: time}}`;
/// `finance_chats/{chatId}/messages/{id}` `{id, senderId, senderName, text,
/// createdAt}`. Members read and write (a group: the tontine's active members).
library;

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/service/finance_ledger.dart';

List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : const [];

/// A conversation as stored.
class FinanceChat {
  final String id;

  /// `direct` or `tontine`.
  final String type;

  /// The two members of a direct conversation.
  final List<String> memberIds;
  final String? tontineId;
  final String lastText;
  final String lastSenderId;
  final DateTime? lastAt;
  final Map<String, DateTime?> lastReadAt;

  const FinanceChat({
    required this.id,
    required this.type,
    required this.memberIds,
    required this.tontineId,
    required this.lastText,
    required this.lastSenderId,
    required this.lastAt,
    required this.lastReadAt,
  });

  static FinanceChat fromMap(Map<String, dynamic> m, DateTime? Function(dynamic) toDate) {
    final last = m['lastMessage'] is Map ? Map<String, dynamic>.from(m['lastMessage'] as Map) : const <String, dynamic>{};
    final read = m['lastReadAt'] is Map ? Map<String, dynamic>.from(m['lastReadAt'] as Map) : const <String, dynamic>{};
    return FinanceChat(
      id: m['id']?.toString() ?? '',
      type: m['type']?.toString() == FinanceChatRules.group ? FinanceChatRules.group : FinanceChatRules.direct,
      memberIds: _strings(m['memberIds']),
      tontineId: m['tontineId']?.toString(),
      lastText: (last['text'] ?? '').toString(),
      lastSenderId: (last['senderId'] ?? '').toString(),
      // A message being sent has no server time yet: it is the latest.
      lastAt: toDate(last['at']) ?? (last.isNotEmpty ? toDate(m['updatedAt']) : null),
      lastReadAt: {for (final e in read.entries) e.key: toDate(e.value)},
    );
  }

  bool get isGroup => type == FinanceChatRules.group;
  bool get hasMessages => lastText.isNotEmpty;

  /// The other member of a direct conversation.
  String? otherOf(String uid) => memberIds.where((m) => m != uid).firstOrNull;

  bool unreadFor(String uid) => FinanceChatRules.unread(lastAt: lastAt, lastSenderId: lastSenderId, readAt: lastReadAt[uid], uid: uid, hasMessage: hasMessages);
}

abstract final class FinanceChatRules {
  static const String direct = 'direct';
  static const String group = 'tontine';

  /// The longest message.
  static const int maxLength = 1000;

  /// The conversation of two members: the same id whoever starts it.
  static String directId(String a, String b) {
    final ids = [a, b]..sort();
    return 'dm_${ids[0]}_${ids[1]}';
  }

  /// The group conversation of a tontine.
  static String tontineChatId(String tontineId) => 'tontine_$tontineId';

  /// The text sent: trimmed; null when empty or longer than [maxLength].
  static String? clean(String text) {
    final t = text.trim();
    return t.isEmpty || t.length > maxLength ? null : t;
  }

  /// Unread: there is a message from someone else after the user last read.
  static bool unread({required DateTime? lastAt, required String lastSenderId, required DateTime? readAt, required String uid, bool hasMessage = true}) {
    if (!hasMessage || lastSenderId == uid) return false;
    if (readAt == null) return true;
    return lastAt != null && lastAt.isAfter(readAt);
  }

  /// Whether a day separator goes before a message of [current] that
  /// follows one of [previous] (older). The first message always gets one.
  static bool newDay(DateTime? previous, DateTime current) =>
      previous == null || previous.year != current.year || previous.month != current.month || previous.day != current.day;

  /// The push preview of a message.
  static String preview(String text, [int max = 100]) {
    final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.length <= max ? t : '${t.substring(0, max - 1)}…';
  }

  /// Sends [text] (already [clean]ed): the message (create-only) and, on the
  /// conversation (created by its first message), the last message, the
  /// time, and the sender's own read time. A direct conversation carries its
  /// two [memberIds]; a group one its [tontineId].
  static List<FinanceWrite> send({
    required String chatId,
    required String messageId,
    required String uid,
    required String senderName,
    required String text,
    List<String> memberIds = const [],
    String? tontineId,
  }) {
    final bool isGroup = tontineId != null;
    return [
      FinanceWrite('finance_chats/$chatId/messages/$messageId', 'create', {
        'id': messageId,
        'senderId': uid,
        'senderName': senderName,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      }),
      FinanceWrite('finance_chats/$chatId', 'merge', {
        'id': chatId,
        'type': isGroup ? group : direct,
        if (isGroup) 'tontineId': tontineId else 'memberIds': [...memberIds]..sort(),
        'lastMessage': {'text': text, 'senderId': uid, 'at': FieldValue.serverTimestamp()},
        'updatedAt': FieldValue.serverTimestamp(),
        'lastReadAt': {uid: FieldValue.serverTimestamp()},
      }),
    ];
  }

  /// The user has read the conversation up to now.
  static List<FinanceWrite> markRead(String chatId, String uid) => [
        FinanceWrite('finance_chats/$chatId', 'update', {'lastReadAt.$uid': FieldValue.serverTimestamp()}),
      ];
}

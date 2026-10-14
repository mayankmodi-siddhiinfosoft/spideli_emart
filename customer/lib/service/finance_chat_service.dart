import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/utils/finance_chat_rules.dart';
import 'package:customer/utils/finance_group_rules.dart';

/// Who a conversation is with: what the chat screen needs to open it, send
/// in it and notify its members.
class FinanceChatTarget {
  final String chatId;

  /// The other member's name, or the tontine's.
  final String title;

  /// The tontine of a group conversation; null for a direct one.
  final String? tontineId;

  /// A direct conversation: its two members. A group: the tontine's active
  /// members (who are notified).
  final List<String> memberIds;

  const FinanceChatTarget._({required this.chatId, required this.title, required this.tontineId, required this.memberIds});

  /// The conversation of the user ([me]) with [other].
  factory FinanceChatTarget.direct(String me, String other, String otherName) =>
      FinanceChatTarget._(chatId: FinanceChatRules.directId(me, other), title: otherName, tontineId: null, memberIds: [me, other]);

  /// The group conversation of [t].
  factory FinanceChatTarget.tontine(Tontine t) => FinanceChatTarget._(chatId: FinanceChatRules.tontineChatId(t.id), title: t.name, tontineId: t.id, memberIds: t.memberIds);

  bool get isGroup => tontineId != null;
}

/// One row of the conversations list: a direct conversation, or the group
/// conversation of one of the user's tontines (listed even before its first
/// message).
class FinanceChatEntry {
  final String chatId;

  /// Null while the conversation has no message (or cannot be read yet).
  final FinanceChat? chat;
  final Tontine? tontine;

  const FinanceChatEntry({required this.chatId, this.chat, this.tontine});

  DateTime? get lastAt => chat?.lastAt;

  /// Latest activity first; conversations without a message last.
  static int byRecent(FinanceChatEntry a, FinanceChatEntry b) {
    final DateTime? x = a.lastAt;
    final DateTime? y = b.lastAt;
    if (x == null && y == null) return (a.tontine?.name ?? '').compareTo(b.tontine?.name ?? '');
    if (x == null) return 1;
    if (y == null) return -1;
    return y.compareTo(x);
  }
}

/// Spideli Finance chat (.claude/FINANCE-DIRECT-FIRESTORE.md 3.11): direct
/// conversations between members of a tontine or a savings goal, and each
/// tontine's group conversation. Text only, written to Firestore directly
/// (FinanceChatRules plans the writes; the security rules let members only);
/// members are notified by push (`finance_chat_message`, best effort).
abstract final class FinanceChatService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static DateTime? _toDate(dynamic v) => v is Timestamp ? v.toDate() : null;

  /// The conversation, live; null while it does not exist (no message yet) -
  /// or cannot be read yet, which the rules treat the same way.
  static Stream<FinanceChat?> chat(String chatId) {
    final source = _db.collection('finance_chats').doc(chatId).snapshots().map((s) => s.data() == null ? null : FinanceChat.fromMap({...s.data()!, 'id': s.id}, _toDate));
    return source.transform(StreamTransformer<FinanceChat?, FinanceChat?>.fromHandlers(handleError: (e, st, sink) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        sink.add(null);
      } else {
        sink.addError(e, st);
      }
    }));
  }

  /// The latest [limit] messages, newest first (the list is shown reversed:
  /// newest at the bottom).
  static Stream<List<Map<String, dynamic>>> messages(String chatId, {int limit = 300}) => _db
      .collection('finance_chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => [for (final d in s.docs) {...d.data(), 'id': d.id}]);

  /// The user's conversations: their direct conversations with a message,
  /// and the group conversation of each of their tontines; latest first.
  static Stream<List<FinanceChatEntry>> myChats() {
    final String uid = FinanceService.uid;
    late final StreamController<List<FinanceChatEntry>> out;
    StreamSubscription<List<FinanceChat>>? directSub;
    StreamSubscription<List<Tontine>>? tontineSub;
    final Map<String, StreamSubscription<FinanceChat?>> groupSubs = {};
    final Map<String, FinanceChat?> groups = {};
    List<FinanceChat>? directs;
    List<Tontine>? tontines;

    void emit() {
      if (directs == null || tontines == null || out.isClosed) return;
      out.add([
        for (final c in directs!)
          if (c.hasMessages && !c.isGroup && c.otherOf(uid) != null) FinanceChatEntry(chatId: c.id, chat: c),
        for (final t in tontines!) FinanceChatEntry(chatId: FinanceChatRules.tontineChatId(t.id), chat: groups[t.id], tontine: t),
      ]..sort(FinanceChatEntry.byRecent));
    }

    void syncGroups(List<Tontine> list) {
      final ids = list.map((t) => t.id).toSet();
      for (final id in groupSubs.keys.where((k) => !ids.contains(k)).toList()) {
        groupSubs.remove(id)?.cancel();
        groups.remove(id);
      }
      for (final id in ids.where((k) => !groupSubs.containsKey(k))) {
        groupSubs[id] = chat(FinanceChatRules.tontineChatId(id)).listen((c) {
          groups[id] = c;
          emit();
        }, onError: (Object _) {
          groups[id] = null;
          emit();
        });
      }
    }

    out = StreamController<List<FinanceChatEntry>>(
      onListen: () {
        directSub = _db
            .collection('finance_chats')
            .where('memberIds', arrayContains: uid)
            .snapshots()
            .map((s) => [for (final d in s.docs) FinanceChat.fromMap({...d.data(), 'id': d.id}, _toDate)])
            .listen((v) {
          directs = v;
          emit();
        }, onError: out.addError);
        tontineSub = FinanceGroupService.myTontines().listen((v) {
          tontines = v;
          syncGroups(v);
          emit();
        }, onError: out.addError);
      },
      onCancel: () async {
        await directSub?.cancel();
        await tontineSub?.cancel();
        for (final s in groupSubs.values) {
          await s.cancel();
        }
        groupSubs.clear();
      },
    );
    return out.stream;
  }

  /// Sends [text] in [target]'s conversation (text only, at most
  /// [FinanceChatRules.maxLength] characters) and notifies its other members.
  static Future<void> send(FinanceChatTarget target, String text) async {
    final String uid = FinanceService.uid;
    if (uid.isEmpty) throw const FinanceException('sign_in_required');
    final String? clean = FinanceChatRules.clean(text);
    if (clean == null) throw const FinanceException('message_invalid');
    final String name = (Constant.userModel?.fullName() ?? '').trim();
    final String messageId = _db.collection('finance_chats').doc(target.chatId).collection('messages').doc().id;
    final batch = _db.batch();
    FinanceLedger.apply(
      batch,
      FinanceChatRules.send(
        chatId: target.chatId,
        messageId: messageId,
        uid: uid,
        senderName: name,
        text: clean,
        memberIds: target.isGroup ? const [] : target.memberIds,
        tontineId: target.tontineId,
      ),
      db: _db,
    );
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw const FinanceException('permission_denied');
      rethrow;
    }
    FinancePeople.push(
      'finance_chat_message',
      target.memberIds,
      {'chatId': target.chatId, 'tontineId': ?target.tontineId},
      {'senderName': name, 'chatName': target.isGroup ? target.title : name, 'message': FinanceChatRules.preview(clean)},
    );
  }

  /// The user has read the conversation (best effort: a conversation that
  /// does not exist yet has nothing to read).
  static Future<void> markRead(String chatId) async {
    final String uid = FinanceService.uid;
    if (uid.isEmpty) return;
    try {
      final batch = _db.batch();
      FinanceLedger.apply(batch, FinanceChatRules.markRead(chatId, uid), db: _db);
      await batch.commit();
    } catch (_) {}
  }
}

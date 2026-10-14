import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/utils/finance_chat_rules.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime? _d(dynamic v) => v is DateTime ? v : (v is Timestamp ? v.toDate() : null);

/// Spideli Finance chat (.claude/FINANCE-DIRECT-FIRESTORE.md 3.11): ids,
/// validation, unread state, day separators and the writes.
void main() {
  test('ids: a direct conversation is the same whoever starts it', () {
    expect(FinanceChatRules.directId('bob', 'amy'), 'dm_amy_bob');
    expect(FinanceChatRules.directId('amy', 'bob'), FinanceChatRules.directId('bob', 'amy'));
    expect(FinanceChatRules.tontineChatId('t1'), 'tontine_t1');
  });

  test('text only, trimmed, not empty, at most 1000 characters', () {
    expect(FinanceChatRules.clean('  hello \n'), 'hello');
    expect(FinanceChatRules.clean('   '), isNull);
    expect(FinanceChatRules.clean('x' * 1000), hasLength(1000));
    expect(FinanceChatRules.clean('x' * 1001), isNull);
    expect(FinanceChatRules.preview('a  b\nc'), 'a b c');
    expect(FinanceChatRules.preview('x' * 150), hasLength(100));
  });

  test('unread: a message from someone else after the last read', () {
    final t1 = DateTime(2026, 10, 14, 9);
    final t2 = DateTime(2026, 10, 14, 10);
    expect(FinanceChatRules.unread(lastAt: t2, lastSenderId: 'b', readAt: t1, uid: 'a'), isTrue);
    expect(FinanceChatRules.unread(lastAt: t1, lastSenderId: 'b', readAt: t2, uid: 'a'), isFalse);
    expect(FinanceChatRules.unread(lastAt: t2, lastSenderId: 'b', readAt: null, uid: 'a'), isTrue, reason: 'never opened');
    expect(FinanceChatRules.unread(lastAt: t2, lastSenderId: 'a', readAt: null, uid: 'a'), isFalse, reason: 'my own message');
    expect(FinanceChatRules.unread(lastAt: null, lastSenderId: '', readAt: null, uid: 'a', hasMessage: false), isFalse);
  });

  test('a day separator before the first message of each day', () {
    expect(FinanceChatRules.newDay(null, DateTime(2026, 10, 14, 9)), isTrue);
    expect(FinanceChatRules.newDay(DateTime(2026, 10, 14, 8), DateTime(2026, 10, 14, 23)), isFalse);
    expect(FinanceChatRules.newDay(DateTime(2026, 10, 13, 23, 59), DateTime(2026, 10, 14, 0, 1)), isTrue);
  });

  test('a conversation as stored', () {
    final c = FinanceChat.fromMap({
      'id': 'dm_a_b',
      'type': 'direct',
      'memberIds': ['a', 'b'],
      'lastMessage': {'text': 'Hi', 'senderId': 'b', 'at': DateTime(2026, 10, 14, 10)},
      'lastReadAt': {'a': DateTime(2026, 10, 14, 9), 'b': DateTime(2026, 10, 14, 10)},
    }, _d);
    expect(c.isGroup, isFalse);
    expect(c.otherOf('a'), 'b');
    expect(c.unreadFor('a'), isTrue);
    expect(c.unreadFor('b'), isFalse);
    final g = FinanceChat.fromMap({'id': 'tontine_t1', 'type': 'tontine', 'tontineId': 't1'}, _d);
    expect(g.isGroup, isTrue);
    expect(g.hasMessages, isFalse);
    expect(g.unreadFor('a'), isFalse);
  });

  group('writes', () {
    test('a direct message: the message (create-only) and the conversation with its two members', () {
      final ws = FinanceChatRules.send(chatId: 'dm_a_b', messageId: 'm1', uid: 'b', senderName: 'Bob', text: 'Hi', memberIds: const ['b', 'a']);
      final m = ws.singleWhere((w) => w.path == 'finance_chats/dm_a_b/messages/m1');
      expect(m.op, 'create');
      expect(m.data['senderId'], 'b');
      expect(m.data['senderName'], 'Bob');
      expect(m.data['text'], 'Hi');
      expect(m.data['createdAt'], FieldValue.serverTimestamp());
      final c = ws.singleWhere((w) => w.path == 'finance_chats/dm_a_b');
      expect(c.op, 'merge', reason: 'created by the first message');
      expect(c.data['type'], 'direct');
      expect(c.data['memberIds'], ['a', 'b']);
      expect(c.data.containsKey('tontineId'), isFalse);
      expect(c.data['lastMessage'], {'text': 'Hi', 'senderId': 'b', 'at': FieldValue.serverTimestamp()});
      expect(c.data['lastReadAt'], {'b': FieldValue.serverTimestamp()}, reason: 'the sender has read it');
    });

    test('a group message names the tontine, not the members', () {
      final c = FinanceChatRules.send(chatId: 'tontine_t1', messageId: 'm2', uid: 'a', senderName: 'Amy', text: 'Due Friday', tontineId: 't1')
          .singleWhere((w) => w.path == 'finance_chats/tontine_t1');
      expect(c.data['type'], 'tontine');
      expect(c.data['tontineId'], 't1');
      expect(c.data.containsKey('memberIds'), isFalse);
    });

    test('read: the user\'s own read time only', () {
      final w = FinanceChatRules.markRead('dm_a_b', 'a').single;
      expect(w.op, 'update');
      expect(w.data, {'lastReadAt.a': FieldValue.serverTimestamp()});
    });
  });
}

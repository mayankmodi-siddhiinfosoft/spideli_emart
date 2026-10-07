import 'package:flutter_test/flutter_test.dart';
import 'package:spideliworker/utils/chat_unread.dart';

void main() {
  group('chatUnreadBadgeLabel', () {
    test('no badge for zero or less', () {
      expect(chatUnreadBadgeLabel(0), '');
      expect(chatUnreadBadgeLabel(-3), '');
    });
    test('the number up to 99, then 99+', () {
      expect(chatUnreadBadgeLabel(1), '1');
      expect(chatUnreadBadgeLabel(99), '99');
      expect(chatUnreadBadgeLabel(100), '99+');
      expect(chatUnreadBadgeLabel(chatUnreadQueryLimit), '99+');
    });
    test('the query limit is enough to tell 99 from 99+', () {
      expect(chatUnreadQueryLimit, chatUnreadDisplayMax + 1);
    });
  });

  group('unread messages', () {
    const String me = 'w1';
    test('addressed to me and not seen', () {
      expect(isUnreadChatMessageFor(<String, dynamic>{'receiverId': me, 'seen': false}, me), isTrue);
    });
    test('seen, missing seen, to someone else or no user: not unread', () {
      expect(isUnreadChatMessageFor(<String, dynamic>{'receiverId': me, 'seen': true}, me), isFalse);
      expect(isUnreadChatMessageFor(<String, dynamic>{'receiverId': me}, me), isFalse);
      expect(isUnreadChatMessageFor(<String, dynamic>{'receiverId': 'c1', 'seen': false}, me), isFalse);
      expect(isUnreadChatMessageFor(<String, dynamic>{'receiverId': '', 'seen': false}, ''), isFalse);
      expect(isUnreadChatMessageFor(null, me), isFalse);
    });
    test('counts only my unread messages', () {
      final List<Map<String, dynamic>?> messages = <Map<String, dynamic>?>[
        <String, dynamic>{'receiverId': me, 'seen': false},
        <String, dynamic>{'receiverId': me, 'seen': false},
        <String, dynamic>{'receiverId': me, 'seen': true},
        <String, dynamic>{'receiverId': 'c1', 'seen': false},
        null,
      ];
      expect(unreadChatCount(messages, me), 2);
      expect(unreadChatCount(const <Map<String, dynamic>?>[], me), 0);
    });
  });
}

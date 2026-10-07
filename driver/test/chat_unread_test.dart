import 'package:driver/utils/chat_unread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatUnread.label', () {
    test('no badge at zero or below', () {
      expect(ChatUnread.label(0), '');
      expect(ChatUnread.label(-3), '');
    });

    test('the number up to the cap', () {
      expect(ChatUnread.label(1), '1');
      expect(ChatUnread.label(42), '42');
      expect(ChatUnread.label(99), '99');
    });

    test('99+ above the cap', () {
      expect(ChatUnread.label(100), '99+');
      expect(ChatUnread.label(5000), '99+');
    });

    test('the listener limit tells 99 from more', () {
      expect(ChatUnread.queryLimit, ChatUnread.displayCap + 1);
      expect(ChatUnread.label(ChatUnread.queryLimit), '99+');
    });
  });

  group('ChatUnread.isUnreadFor', () {
    test('addressed to me and not seen', () {
      expect(ChatUnread.isUnreadFor({'receiverId': 'me', 'seen': false}, 'me'), isTrue);
    });

    test('seen, to someone else, missing fields or no user', () {
      expect(ChatUnread.isUnreadFor({'receiverId': 'me', 'seen': true}, 'me'), isFalse);
      expect(ChatUnread.isUnreadFor({'receiverId': 'other', 'seen': false}, 'me'), isFalse);
      expect(ChatUnread.isUnreadFor({'receiverId': 'me'}, 'me'), isFalse);
      expect(ChatUnread.isUnreadFor(null, 'me'), isFalse);
      expect(ChatUnread.isUnreadFor({'receiverId': '', 'seen': false}, ''), isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/models/permission_model.dart';
import 'package:vendor/utils/push_payload.dart';
import 'package:vendor/utils/store_chat_topic.dart';

/// Which store chat topic this device subscribes to (`store_chat_<vendorID>`,
/// `.claude/PUSH-CHANNELS.md` "Store chat topic").
void main() {
  final List<PermissionModel> withChat = [PermissionModel(title: 'Orders', isActive: true), PermissionModel(title: 'Chat', isActive: true)];
  final List<PermissionModel> chatOff = [PermissionModel(title: 'Orders', isActive: true), PermissionModel(title: 'Chat', isActive: false)];
  final List<PermissionModel> noChatEntry = [PermissionModel(title: 'Orders', isActive: true)];

  group('topic names', () {
    test('store_chat_<vendorID>, the same rule as the customer app', () {
      expect(StoreChatTopic.forVendor('Abc123xyz'), 'store_chat_Abc123xyz');
      expect(StoreChatTopic.forVendor(' v-1_2.3~4%5 '), 'store_chat_v-1_2.3~4%5');
      expect(StoreChatTopic.forVendor(null), isNull);
      expect(StoreChatTopic.forVendor(''), isNull);
      expect(StoreChatTopic.forVendor('a/b'), isNull);
      expect(StoreChatTopic.forVendor('a b'), isNull);
      expect(StoreChatTopic.forVendor('x' * 900), isNull);
    });

    test('only our own topics are ever unsubscribed', () {
      expect(StoreChatTopic.isStoreChatTopic('store_chat_v1'), isTrue);
      expect(StoreChatTopic.isStoreChatTopic('vendor'), isFalse);
      expect(StoreChatTopic.isStoreChatTopic(''), isFalse);
      expect(StoreChatTopic.isStoreChatTopic(null), isFalse);
    });
  });

  group('who subscribes', () {
    test('the owner never (the token push already reaches them)', () {
      expect(StoreChatTopic.desired(signedIn: true, role: 'vendor', vendorId: 'v1', permissions: withChat), isNull);
      expect(StoreChatTopic.desired(signedIn: true, role: 'vendor', vendorId: 'v1'), isNull);
      expect(StoreChatTopic.desired(signedIn: true, role: null, vendorId: 'v1'), isNull);
    });

    test('an employee whose role allows Chat', () {
      expect(StoreChatTopic.desired(signedIn: true, role: 'employee', vendorId: 'v1', permissions: withChat), 'store_chat_v1');
      expect(StoreChatTopic.desired(signedIn: true, role: 'employee', vendorId: 'v1', permissions: [PermissionModel(title: ' chat ', isActive: true)]), 'store_chat_v1');
    });

    test('an employee without Chat: switched off, no entry, no role', () {
      expect(StoreChatTopic.desired(signedIn: true, role: 'employee', vendorId: 'v1', permissions: chatOff), isNull);
      expect(StoreChatTopic.desired(signedIn: true, role: 'employee', vendorId: 'v1', permissions: noChatEntry), isNull);
      expect(StoreChatTopic.desired(signedIn: true, role: 'employee', vendorId: 'v1'), isNull);
    });

    test('an employee without a store, or nobody signed in', () {
      expect(StoreChatTopic.desired(signedIn: true, role: 'employee', vendorId: '', permissions: withChat), isNull);
      expect(StoreChatTopic.desired(signedIn: false, role: 'employee', vendorId: 'v1', permissions: withChat), isNull);
    });
  });

  group('from the remembered topic to the desired one', () {
    test('first subscription', () {
      expect(StoreChatTopic.change(remembered: '', desired: 'store_chat_v1'), const StoreChatTopicChange(subscribe: 'store_chat_v1'));
    });

    test('unchanged: nothing, unless a re-subscribe is asked for', () {
      expect(StoreChatTopic.change(remembered: 'store_chat_v1', desired: 'store_chat_v1').isNone, isTrue);
      expect(StoreChatTopic.change(remembered: 'store_chat_v1', desired: 'store_chat_v1', resubscribe: true), const StoreChatTopicChange(subscribe: 'store_chat_v1'));
      expect(StoreChatTopic.change(remembered: '', desired: null, resubscribe: true).isNone, isTrue);
    });

    test('Chat revoked, the user signed out, or the owner signed in: unsubscribe', () {
      expect(StoreChatTopic.change(remembered: 'store_chat_v1', desired: null), const StoreChatTopicChange(unsubscribe: 'store_chat_v1'));
      expect(StoreChatTopic.change(remembered: 'store_chat_v1', desired: null, resubscribe: true), const StoreChatTopicChange(unsubscribe: 'store_chat_v1'));
    });

    test('the employee moved to another store: leave the old, join the new', () {
      expect(StoreChatTopic.change(remembered: 'store_chat_v1', desired: 'store_chat_v2'), const StoreChatTopicChange(unsubscribe: 'store_chat_v1', subscribe: 'store_chat_v2'));
    });

    test('a remembered value that is not ours is never unsubscribed', () {
      expect(StoreChatTopic.change(remembered: 'vendor', desired: null).isNone, isTrue);
      expect(StoreChatTopic.change(remembered: 'junk value', desired: 'store_chat_v1'), const StoreChatTopicChange(subscribe: 'store_chat_v1'));
    });

    test('end to end: owner, employee with Chat, revoked, moved', () {
      String remembered = '';
      String apply(String? desired) {
        final StoreChatTopicChange c = StoreChatTopic.change(remembered: remembered, desired: desired);
        if (c.unsubscribe != null) remembered = '';
        if (c.subscribe != null) remembered = c.subscribe!;
        return remembered;
      }

      expect(apply(StoreChatTopic.desired(signedIn: true, role: 'vendor', vendorId: 'v1', permissions: withChat)), '');
      expect(apply(StoreChatTopic.desired(signedIn: true, role: 'employee', vendorId: 'v1', permissions: withChat)), 'store_chat_v1');
      expect(apply(StoreChatTopic.desired(signedIn: true, role: 'employee', vendorId: 'v1', permissions: chatOff)), '');
      expect(apply(StoreChatTopic.desired(signedIn: true, role: 'employee', vendorId: 'v1', permissions: withChat)), 'store_chat_v1');
      expect(apply(StoreChatTopic.desired(signedIn: true, role: 'employee', vendorId: 'v2', permissions: withChat)), 'store_chat_v2');
      expect(apply(StoreChatTopic.desired(signedIn: false, role: null, vendorId: null)), '');
    });
  });

  test('a topic push is routed like the owner\'s chat push (store inbox)', () {
    expect(NotificationRouting.targetFor(type: 'orderChat', chatType: 'vendor'), NotificationTarget.orderChat);
  });
}

import 'package:customer/constant/constant.dart';
import 'package:customer/service/push_message.dart';
import 'package:customer/service/send_notification.dart';
import 'package:customer/utils/store_chat_push.dart';
import 'package:flutter_test/flutter_test.dart';

/// A customer's chat message to a store: the owner's token push (unchanged)
/// plus one topic push to `store_chat_<vendorID>` for the store's employees
/// with the Chat permission (`.claude/PUSH-CHANNELS.md`, "Store chat topic").
void main() {
  group('topic names', () {
    test('store_chat_<vendorID>, trimmed', () {
      expect(StoreChatTopic.forVendor('Abc123xyz'), 'store_chat_Abc123xyz');
      expect(StoreChatTopic.forVendor('  v-1_2.3~4%5 '), 'store_chat_v-1_2.3~4%5');
    });

    test('no topic for an unknown or unusable store id', () {
      expect(StoreChatTopic.forVendor(null), isNull);
      expect(StoreChatTopic.forVendor(''), isNull);
      expect(StoreChatTopic.forVendor('   '), isNull);
      expect(StoreChatTopic.forVendor('a/b'), isNull);
      expect(StoreChatTopic.forVendor('a b'), isNull);
      expect(StoreChatTopic.forVendor('ü'), isNull);
      expect(StoreChatTopic.forVendor('x' * 900), isNull, reason: 'the prefix makes it longer than 900');
    });

    test('FCM topic name rule', () {
      expect(PushPayload.isValidTopic('vendor'), isTrue);
      expect(PushPayload.isValidTopic('a-Z_0.9~%'), isTrue);
      expect(PushPayload.isValidTopic('x' * 900), isTrue);
      expect(PushPayload.isValidTopic('x' * 901), isFalse);
      expect(PushPayload.isValidTopic(''), isFalse);
      expect(PushPayload.isValidTopic(null), isFalse);
      expect(PushPayload.isValidTopic('/topics/vendor'), isFalse);
      expect(PushPayload.isValidTopic('a:b'), isFalse);
    });

    test('the store id: argument, then the order, then the owner profile', () {
      expect(StoreChatTopic.vendorIdFrom(argument: 'arg', orderVendorId: 'ord', receiverVendorId: 'own'), 'arg');
      expect(StoreChatTopic.vendorIdFrom(argument: ' ', orderVendorId: 'ord', receiverVendorId: 'own'), 'ord');
      expect(StoreChatTopic.vendorIdFrom(argument: null, orderVendorId: '', receiverVendorId: 'own'), 'own');
      expect(StoreChatTopic.vendorIdFrom(argument: 'null', orderVendorId: null, receiverVendorId: null), '');
      expect(StoreChatTopic.vendorIdFrom(), '');
    });
  });

  group('push plan of one message', () {
    test('to a store: owner token + topic', () {
      for (final String type in ['vendor', 'store', 'restaurant', ' Vendor ']) {
        final plan = StoreChatPushPlan.of(chatType: type, vendorId: 'v1', hasOwnerToken: true, serverPush: false);
        expect(plan.ownerToken, isTrue);
        expect(plan.topic, 'store_chat_v1');
        expect(plan.topicSkip, StoreChatTopicSkip.none);
      }
    });

    test('the topic push does not depend on the owner having a token', () {
      final plan = StoreChatPushPlan.of(chatType: 'vendor', vendorId: 'v1', hasOwnerToken: false, serverPush: false);
      expect(plan.ownerToken, isFalse);
      expect(plan.topic, 'store_chat_v1');
    });

    test('store id unknown: owner token only', () {
      final plan = StoreChatPushPlan.of(chatType: 'vendor', vendorId: '', hasOwnerToken: true, serverPush: false);
      expect(plan.ownerToken, isTrue);
      expect(plan.topic, isNull);
      expect(plan.topicSkip, StoreChatTopicSkip.unknownStore);
    });

    test('server push path: owner token only (sendPush takes no topics from apps)', () {
      final plan = StoreChatPushPlan.of(chatType: 'vendor', vendorId: 'v1', hasOwnerToken: true, serverPush: true);
      expect(plan.ownerToken, isTrue);
      expect(plan.topic, isNull);
      expect(plan.topicSkip, StoreChatTopicSkip.serverPath);
    });

    test('not a store: no topic', () {
      for (final String? type in ['driver', 'provider', 'worker', 'customer', 'admin', '', null]) {
        final plan = StoreChatPushPlan.of(chatType: type, vendorId: 'v1', hasOwnerToken: true, serverPush: false);
        expect(plan.topic, isNull, reason: '$type');
        expect(plan.topicSkip, StoreChatTopicSkip.notStore);
        expect(StoreChatPushPlan.isStoreChat(type), isFalse);
      }
    });
  });

  group('FCM v1 topic message', () {
    final Map<String, String> data = PushPayload.stringData({'type': 'orderChat', 'chatType': 'vendor', 'orderId': 'o1', 'senderId': 'c1', 'senderName': 'Ann'}, spec: PushChannels.chat);
    final Map<String, dynamic> byToken = PushPayload.fcmV1Message(token: 'tok', title: 'Ann', body: 'Hi', data: data, spec: PushChannels.chat);
    final Map<String, dynamic> byTopic = PushPayload.fcmV1TopicMessage(topic: ' store_chat_v1 ', title: 'Ann', body: 'Hi', data: data, spec: PushChannels.chat);

    test('addressed to the topic, never to a token', () {
      expect(byTopic['topic'], 'store_chat_v1');
      expect(byTopic.containsKey('token'), isFalse);
    });

    test('the same notification, data, chat channel and sounds as the owner push', () {
      final Map<String, dynamic> a = Map.of(byToken)..remove('token');
      final Map<String, dynamic> b = Map.of(byTopic)..remove('topic');
      expect(b, a);
      expect(byTopic['android']['notification']['channel_id'], 'chat_messages');
      expect(byTopic['android']['notification']['sound'], 'chat_message');
      expect(byTopic['apns']['payload']['aps']['sound'], 'chat_message.wav');
      expect(byTopic['data']['type'], 'orderChat');
      expect(byTopic['data']['chatType'], 'vendor');
    });
  });

  group('SendNotification.sendChatFcmMessageToTopic', () {
    tearDown(() => Constant.serverPushUrl = '');

    test('server path: nothing sent', () async {
      Constant.serverPushUrl = 'https://example.invalid/sendPush';
      expect(await SendNotification.sendChatFcmMessageToTopic('Ann', 'Hi', 'store_chat_v1', {'type': 'orderChat'}, recipient: PushRecipient.store), isFalse);
    });

    test('invalid topic: nothing sent', () async {
      expect(await SendNotification.sendChatFcmMessageToTopic('Ann', 'Hi', 'store chat', {'type': 'orderChat'}, recipient: PushRecipient.store), isFalse);
    });
  });
}

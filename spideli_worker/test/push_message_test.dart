import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spideliworker/services/push_message.dart';

void main() {
  group('fcmDataPayload', () {
    test('every value is a string; nulls dropped; maps and lists JSON-encoded', () {
      final Map<String, String> data = fcmDataPayload({
        'type': 'provider_order',
        'orderId': 'o1',
        'count': 3,
        'paid': false,
        'price': 12.5,
        'missing': null,
        'author': {'id': 'u1', 'n': 2},
        'ids': ['a', 'b'],
      });
      expect(data, {
        'type': 'provider_order',
        'orderId': 'o1',
        'count': '3',
        'paid': 'false',
        'price': '12.5',
        'author': '{"id":"u1","n":2}',
        'ids': '["a","b"]',
      });
      expect(data.values.every((v) => v.runtimeType == String), isTrue);
    });

    test('type falls back to the template type; a caller type wins', () {
      expect(fcmDataPayload({'orderId': 'o1'}, fallbackType: 'service_intransit')['type'], 'service_intransit');
      expect(fcmDataPayload({'type': '', 'orderId': 'o1'}, fallbackType: 'stop_time')['type'], 'stop_time');
      expect(fcmDataPayload({'type': 'provider_order'}, fallbackType: 'stop_time')['type'], 'provider_order');
      expect(fcmDataPayload(null, fallbackType: 'orderChat'), {'type': 'orderChat'});
      expect(fcmDataPayload(null), isEmpty);
    });

    test('keys FCM refuses are dropped', () {
      final Map<String, String> data = fcmDataPayload({'from': 'x', 'google.c': 'x', 'gcm.n': 'x', 'notification': 'x', 'message_type': 'x', 'collapse_key': 'x', 'ok': 'y'});
      expect(data, {'ok': 'y'});
    });

    test('values that are not JSON-encodable do not throw', () {
      final Map<String, String> data = fcmDataPayload({'when': {'at': DateTime.utc(2026, 10, 3)}});
      expect(data['when'], contains('2026-10-03'));
    });
  });

  group('tokens', () {
    test('isUsableFcmToken rejects empty and "null"', () {
      expect(isUsableFcmToken(null), isFalse);
      expect(isUsableFcmToken(''), isFalse);
      expect(isUsableFcmToken('   '), isFalse);
      expect(isUsableFcmToken('null'), isFalse);
      expect(isUsableFcmToken('NULL'), isFalse);
      expect(isUsableFcmToken('dGVzdA:APA91b-token'), isTrue);
    });

    test('pickRecipientToken prefers the fresh profile token', () {
      expect(pickRecipientToken(fresh: 'fresh', snapshot: 'old'), 'fresh');
      expect(pickRecipientToken(fresh: '', snapshot: 'old'), 'old');
      expect(pickRecipientToken(fresh: 'null', snapshot: ' old '), 'old');
      expect(pickRecipientToken(fresh: null, snapshot: null), '');
    });

    test('shouldWriteDeviceToken never writes an empty token, nor the same one twice', () {
      expect(shouldWriteDeviceToken(newToken: '', lastWrittenToken: null), isFalse);
      expect(shouldWriteDeviceToken(newToken: 'null', lastWrittenToken: 'good'), isFalse);
      expect(shouldWriteDeviceToken(newToken: 'good', lastWrittenToken: null), isTrue);
      expect(shouldWriteDeviceToken(newToken: 'good', lastWrittenToken: 'good'), isFalse);
      expect(shouldWriteDeviceToken(newToken: 'rotated', lastWrittenToken: 'good'), isTrue);
    });

    test('shouldClearTokenOnSignOut only clears this device\'s token', () {
      expect(shouldClearTokenOnSignOut(storedToken: 'mine', deviceToken: 'mine'), isTrue);
      expect(shouldClearTokenOnSignOut(storedToken: 'other-phone', deviceToken: 'mine'), isFalse);
      expect(shouldClearTokenOnSignOut(storedToken: '', deviceToken: 'mine'), isFalse);
      expect(shouldClearTokenOnSignOut(storedToken: 'mine', deviceToken: ''), isFalse);
      expect(shouldClearTokenOnSignOut(storedToken: null, deviceToken: null), isFalse);
    });

    test('accessTokenUsable keeps a margin before expiry', () {
      final DateTime now = DateTime.utc(2026, 10, 3, 12);
      expect(accessTokenUsable(null, now), isFalse);
      expect(accessTokenUsable(now.add(const Duration(minutes: 30)), now), isTrue);
      expect(accessTokenUsable(now.add(const Duration(minutes: 4)), now), isFalse);
      expect(accessTokenUsable(now.subtract(const Duration(minutes: 1)), now), isFalse);
    });
  });

  group('project path', () {
    test('uses the Firebase project id, not the project number from settings', () {
      expect(fcmProjectId(optionsProjectId: 'spideli-870b0', settingsSenderId: '248496578266'), 'spideli-870b0');
      expect(fcmProjectId(optionsProjectId: '', settingsSenderId: '248496578266'), '248496578266');
      expect(fcmProjectId(optionsProjectId: null, settingsSenderId: 'null'), '');
    });
  });

  group('channels', () {
    test('each recipient app gets the channel it creates', () {
      expect(pushChannelFor(PushRecipient.customer).androidChannelId, 'high_importance_channel');
      expect(pushChannelFor(PushRecipient.worker).androidChannelId, workerChannelId);
      expect(pushChannelFor(PushRecipient.provider).androidChannelId, providerChannelId);
      for (final PushRecipient r in PushRecipient.values) {
        expect(pushChannelFor(r).androidSound, 'default');
        expect(pushChannelFor(r).apnsSound, 'default');
      }
    });

    test('the AndroidManifest default channel is the channel the app creates', () {
      final String manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      final RegExpMatch? match = RegExp(
        r'default_notification_channel_id"\s*android:value="([^"]+)"',
      ).firstMatch(manifest);
      expect(match, isNotNull, reason: 'the manifest must name a default channel');
      expect(match!.group(1), workerChannelId);
    });
  });

  group('buildFcmV1Message', () {
    final Map<String, dynamic> message = buildFcmV1Message(
      token: ' tok ',
      title: 'Title',
      body: 'Body',
      data: {'type': 'provider_order', 'orderId': 'o1'},
      channel: pushChannelFor(PushRecipient.customer),
    )['message'] as Map<String, dynamic>;

    test('carries token, notification and string data', () {
      expect(message['token'], 'tok');
      expect(message['notification'], {'title': 'Title', 'body': 'Body'});
      expect(message['data'], {'type': 'provider_order', 'orderId': 'o1'});
    });

    test('android: high priority, the recipient channel and a sound', () {
      expect(message['android'], {
        'priority': 'high',
        'notification': {'channel_id': 'high_importance_channel', 'sound': 'default'},
      });
    });

    test('apns: priority 10, a sound and content-available', () {
      expect(message['apns'], {
        'headers': {'apns-priority': '10'},
        'payload': {
          'aps': {'sound': 'default', 'content-available': 1},
        },
      });
    });

    test('is valid JSON and has no data block when there is no data', () {
      final Map<String, dynamic> m = buildFcmV1Message(token: 't', title: '', body: '', data: const {}, channel: pushChannelFor(PushRecipient.customer));
      expect(() => jsonEncode(m), returnsNormally);
      expect((m['message'] as Map).containsKey('data'), isFalse);
    });

    test('clips a long chat message', () {
      final Map<String, dynamic> m = buildFcmV1Message(token: 't', title: 'x' * 500, body: 'y' * 5000, data: const {}, channel: pushChannelFor(PushRecipient.customer));
      final Map notification = (m['message'] as Map)['notification'] as Map;
      expect((notification['title'] as String).length, maxPushTitleLength);
      expect((notification['body'] as String).length, maxPushBodyLength);
    });
  });

  group('server push', () {
    test('isHttpsUrl', () {
      expect(isHttpsUrl('https://us-central1-spideli-870b0.cloudfunctions.net/sendPush'), isTrue);
      expect(isHttpsUrl(' https://sendpush-abc-uc.a.run.app '), isTrue);
      expect(isHttpsUrl('http://example.com'), isFalse);
      expect(isHttpsUrl('https://'), isFalse);
      expect(isHttpsUrl(''), isFalse);
      expect(isHttpsUrl(null), isFalse);
    });

    test('body follows the contract with the same channel and data', () {
      final Map<String, dynamic> body = buildServerPushBody(
        token: 'tok',
        title: 'T',
        body: 'B',
        data: {'type': 'provider_order', 'orderId': 'o1'},
        channel: pushChannelFor(PushRecipient.customer),
        kind: 'service_intransit',
      );
      expect(body, {
        'token': 'tok',
        'title': 'T',
        'body': 'B',
        'data': {'type': 'provider_order', 'orderId': 'o1'},
        'kind': 'service_intransit',
        'android': {'channelId': 'high_importance_channel', 'sound': 'default'},
        'apns': {'sound': 'default'},
      });
      const Set<String> allowed = {'token', 'topic', 'title', 'body', 'data', 'kind', 'android', 'apns'};
      expect(allowed.containsAll(body.keys), isTrue);
    });
  });

  group('errors', () {
    test('an UNREGISTERED token is dead', () {
      final PushSendError e = parseFcmError(
        404,
        '{"error":{"code":404,"message":"Requested entity was not found.","status":"NOT_FOUND","details":[{"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError","errorCode":"UNREGISTERED"}]}}',
      );
      expect(e.status, 'NOT_FOUND');
      expect(e.errorCode, 'UNREGISTERED');
      expect(e.isDeadToken, isTrue);
    });

    test('an invalid registration token is dead; another bad argument is not', () {
      expect(
        parseFcmError(400, '{"error":{"status":"INVALID_ARGUMENT","message":"The registration token is not a valid FCM registration token","details":[{"errorCode":"INVALID_ARGUMENT"}]}}').isDeadToken,
        isTrue,
      );
      final PushSendError badData = parseFcmError(400, '{"error":{"status":"INVALID_ARGUMENT","message":"Invalid value at \'message.data[0].value\'"}}');
      expect(badData.isDeadToken, isFalse);
      expect(badData.toString(), 'HTTP 400 INVALID_ARGUMENT');
    });

    test('a body that is not JSON is read without throwing', () {
      final PushSendError e = parseFcmError(502, '<html>Bad gateway</html>');
      expect(e.statusCode, 502);
      expect(e.isDeadToken, isFalse);
    });

    test('server function errors', () {
      expect(parseServerPushError(404, '{"ok":false,"error":"unregistered"}').isDeadToken, isTrue);
      expect(parseServerPushError(429, '{"ok":false,"error":"rate_limited"}').isDeadToken, isFalse);
      expect(parseServerPushError(500, '').status, '');
    });
  });

  group('pushRouteFor', () {
    test('booking assigned by the provider opens the booking', () {
      expect(pushRouteFor({'type': 'provider_order', 'orderId': 'o1'}), PushRoute.booking);
      expect(pushRouteFor({'type': 'worker_assigned', 'orderId': 'o1'}), PushRoute.booking);
      expect(pushRouteFor({'type': 'provider_order'}), PushRoute.none);
      expect(pushRouteFor({'type': 'provider_order', 'orderId': 'null'}), PushRoute.none);
    });

    test('a customer chat (orderChat) opens the chat, or the inbox without a sender', () {
      expect(pushRouteFor({'type': 'orderChat', 'chatType': 'worker', 'orderId': 'o1', 'senderId': 'c1'}), PushRoute.chat);
      expect(pushRouteFor({'type': 'orderChat', 'orderId': 'o1'}), PushRoute.inbox);
      expect(pushRouteFor({'type': 'orderChat'}), PushRoute.inbox);
    });

    test('legacy provider_chat and admin chats', () {
      expect(pushRouteFor({'type': 'provider_chat', 'orderId': 'o1'}), PushRoute.legacyProviderChat);
      expect(pushRouteFor({'type': 'admin_chat'}), PushRoute.adminChat);
      expect(pushRouteFor({'type': 'admin'}), PushRoute.adminChat);
      expect(pushRouteFor({'type': 'orderChat', 'chatType': 'admin'}), PushRoute.adminChat);
    });

    test('missing data never throws', () {
      expect(pushRouteFor(<String, dynamic>{}), PushRoute.none);
      expect(pushRouteFor({'type': null, 'orderId': null}), PushRoute.none);
    });
  });

  test('decodeNotificationPayload', () {
    expect(decodeNotificationPayload('{"type":"provider_order","orderId":"o1"}'), {'type': 'provider_order', 'orderId': 'o1'});
    expect(decodeNotificationPayload(null), isEmpty);
    expect(decodeNotificationPayload(''), isEmpty);
    expect(decodeNotificationPayload('not json'), isEmpty);
    expect(decodeNotificationPayload('[1,2]'), isEmpty);
  });
}

import 'dart:convert';

import 'package:customer/constant/constant.dart';
import 'package:customer/service/push_message.dart';
import 'package:customer/service/send_notification.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the customer app sends to FCM (or to the sendPush function).
///
/// FCM HTTP v1 rejects a whole message with 400 when one data value is not a
/// string, and Android shows a push loud and heads-up only on a channel the
/// RECEIVING app created. These are the rules every push the customer sends
/// (orders and dine-in to stores, bookings to providers, chat) goes through.
void main() {
  group('PushPayload.stringData', () {
    test('every value becomes a string; nulls are dropped', () {
      final data = PushPayload.stringData({
        'orderId': 'o-1',
        'count': 3,
        'amount': 12.5,
        'paid': true,
        'missing': null,
      });
      expect(data, {'orderId': 'o-1', 'count': '3', 'amount': '12.5', 'paid': 'true'});
      expect(data.values.every((v) => v.runtimeType == String), isTrue);
    });

    test('maps and lists are JSON-encoded, even with values JSON cannot encode', () {
      final data = PushPayload.stringData({
        'items': [1, 'two'],
        'extra': {'a': 1, 'when': DateTime.utc(2026, 10, 3)},
      });
      expect(jsonDecode(data['items']!), [1, 'two']);
      final extra = jsonDecode(data['extra']!) as Map;
      expect(extra['a'], 1);
      expect(extra['when'], DateTime.utc(2026, 10, 3).toString());
    });

    test('type is always present: the caller\'s, else the template type', () {
      expect(PushPayload.stringData({}, type: 'order_placed')['type'], 'order_placed');
      expect(PushPayload.stringData(null, type: 'order_placed')['type'], 'order_placed');
      expect(PushPayload.stringData({'type': ''}, type: 'order_placed')['type'], 'order_placed');
      expect(PushPayload.stringData({'type': 'provider_order'}, type: 'booking_placed')['type'], 'provider_order');
      expect(PushPayload.stringData({'orderId': 'o-1'}).containsKey('type'), isFalse);
    });

    test('keys FCM refuses are dropped instead of failing the whole push', () {
      final data = PushPayload.stringData({
        'from': 'x',
        'notification': 'x',
        'message_type': 'x',
        'collapse_key': 'x',
        'google.c.a': 'x',
        'gcm.n.e': 'x',
        'GoogleThing': 'x',
        '  ': 'x',
        'orderId': 'o-1',
      });
      expect(data, {'orderId': 'o-1'});
    });

    test('the receiving channel rides along as channelId, unless the caller set one', () {
      const spec = PushChannelSpec(androidChannelId: 'new_order');
      expect(PushPayload.stringData({}, spec: spec)['channelId'], 'new_order');
      expect(PushPayload.stringData({'channelId': 'mine'}, spec: spec)['channelId'], 'mine');
      expect(PushPayload.stringData({}, spec: const PushChannelSpec()).containsKey('channelId'), isFalse);
    });
  });

  group('tokens and switches', () {
    test('an empty or "null" token is never sent to', () {
      for (final t in [null, '', '   ', 'null', 'NULL', ' null ']) {
        expect(PushPayload.isUsableToken(t), isFalse, reason: '$t');
      }
      expect(PushPayload.isUsableToken('fcm-token:abc'), isTrue);
    });

    test('serverPushUrl switches only for an https URL with a host', () {
      expect(PushPayload.isServerPushUrl('https://us-central1-spideli-870b0.cloudfunctions.net/sendPush'), isTrue);
      expect(PushPayload.isServerPushUrl('  https://sendpush-abc-uc.a.run.app  '), isTrue);
      expect(PushPayload.isServerPushUrl('http://example.com/sendPush'), isFalse);
      expect(PushPayload.isServerPushUrl('https://'), isFalse);
      expect(PushPayload.isServerPushUrl(''), isFalse);
      expect(PushPayload.isServerPushUrl(null), isFalse);
      expect(PushPayload.isServerPushUrl('not a url'), isFalse);
    });

    test('the FCM path uses the app\'s project id, the settings value only as fallback', () {
      expect(PushPayload.projectId(firebaseProjectId: 'spideli-870b0', settingsSenderId: '248496578266'), 'spideli-870b0');
      expect(PushPayload.projectId(firebaseProjectId: '', settingsSenderId: ' 248496578266 '), '248496578266');
      expect(PushPayload.projectId(firebaseProjectId: null, settingsSenderId: null), '');
      expect(PushPayload.fcmSendUri('spideli-870b0').toString(), 'https://fcm.googleapis.com/v1/projects/spideli-870b0/messages:send');
    });
  });

  group('PushChannels: the receiving app\'s channel', () {
    test('a new order or dine-in request is loud on the store\'s order channel', () {
      for (final kind in ['order_placed', 'schedule_order', 'dinein_placed', 'ORDER_PLACED']) {
        expect(
          PushChannels.forRecipient(PushRecipient.store, kind: kind),
          const PushChannelSpec(androidChannelId: 'new_order', androidSound: 'order_alert', apnsSound: 'order_alert.caf'),
          reason: kind,
        );
      }
    });

    test('anything else to a store uses its general channel', () {
      expect(PushChannels.forRecipient(PushRecipient.store, kind: 'chat'), const PushChannelSpec(androidChannelId: 'general'));
      expect(PushChannels.forRecipient(PushRecipient.store), const PushChannelSpec(androidChannelId: 'general'));
    });

    test('driver, worker, customer and provider', () {
      expect(PushChannels.forRecipient(PushRecipient.driver, kind: 'chat').androidChannelId, 'driver_notifications_channel');
      expect(PushChannels.forRecipient(PushRecipient.worker, kind: 'chat').androidChannelId, '01');
      expect(PushChannels.forRecipient(PushRecipient.customer).androidChannelId, 'high_importance_channel');
      expect(PushChannels.forRecipient(PushRecipient.provider, kind: 'booking_placed'), const PushChannelSpec(androidChannelId: '01'));
      expect(PushChannels.forRecipient(null), const PushChannelSpec());
    });

    test('a chat goes to the app of the thread\'s other side', () {
      expect(PushChannels.recipientForChatType('vendor'), PushRecipient.store);
      expect(PushChannels.recipientForChatType('driver'), PushRecipient.driver);
      expect(PushChannels.recipientForChatType('Provider'), PushRecipient.provider);
      expect(PushChannels.recipientForChatType('worker'), PushRecipient.worker);
      expect(PushChannels.recipientForChatType(''), isNull);
      expect(PushChannels.recipientForChatType(null), isNull);
    });
  });

  group('PushPayload.fcmV1Message', () {
    const spec = PushChannelSpec(androidChannelId: 'new_order', androidSound: 'order_alert', apnsSound: 'order_alert.caf');

    test('carries the platform blocks that make the push show and sound', () {
      final message = PushPayload.fcmV1Message(token: ' tok ', title: 'New order', body: 'Order #1', data: {'type': 'order_placed'}, spec: spec);
      expect(message['token'], 'tok');
      expect(message['notification'], {'title': 'New order', 'body': 'Order #1'});
      expect(message['data'], {'type': 'order_placed'});
      expect(message['android'], {
        'priority': 'high',
        'notification': {'channel_id': 'new_order', 'sound': 'order_alert'},
      });
      expect(message['apns'], {
        'headers': {'apns-priority': '10'},
        'payload': {
          'aps': {'sound': 'order_alert.caf', 'content-available': 1},
        },
      });
      // The request body is plain JSON.
      expect(() => jsonEncode({'message': message}), returnsNormally);
    });

    test('no channel id leaves the receiving app\'s default; empty data is left out', () {
      final message = PushPayload.fcmV1Message(token: 'tok', title: '', body: '', data: const {}, spec: const PushChannelSpec());
      expect(message.containsKey('data'), isFalse);
      expect((message['android'] as Map)['notification'], {'sound': 'default'});
    });
  });

  group('PushPayload.serverRequest (SERVER-PUSH-CONTRACT)', () {
    final channelRe = RegExp(r'^[A-Za-z0-9_.-]{1,64}$');
    final apnsSoundRe = RegExp(r'^[A-Za-z0-9_. -]{1,64}$');

    test('only fields the function accepts, with the same channel and sound', () {
      const spec = PushChannelSpec(androidChannelId: 'new_order', androidSound: 'order_alert', apnsSound: 'order_alert.caf');
      final body = PushPayload.serverRequest(token: 'tok', title: 't', body: 'b', data: {'type': 'order_placed'}, spec: spec, kind: 'order_placed');
      expect(body.keys.toSet().difference({'token', 'topic', 'title', 'body', 'data', 'kind', 'android', 'apns'}), isEmpty);
      expect(body['kind'], 'order_placed');
      expect(body['android'], {'channelId': 'new_order', 'sound': 'order_alert'});
      expect(body['apns'], {'sound': 'order_alert.caf'});
      expect(channelRe.hasMatch((body['android'] as Map)['channelId'] as String), isTrue);
      expect(apnsSoundRe.hasMatch((body['apns'] as Map)['sound'] as String), isTrue);
    });

    test('no kind and no channel id are left out', () {
      final body = PushPayload.serverRequest(token: 'tok', title: 't', body: 'b', data: const {}, spec: const PushChannelSpec(), kind: ' ');
      expect(body.containsKey('kind'), isFalse);
      expect(body['android'], {'sound': 'default'});
    });

    test('every channel the app can pick passes the function\'s validation', () {
      for (final recipient in [...PushRecipient.values, null]) {
        for (final kind in ['order_placed', 'chat', 'booking_placed']) {
          final spec = PushChannels.forRecipient(recipient, kind: kind);
          if (spec.androidChannelId != null) expect(channelRe.hasMatch(spec.androidChannelId!), isTrue);
          expect(channelRe.hasMatch(spec.androidSound), isTrue);
          expect(apnsSoundRe.hasMatch(spec.apnsSound), isTrue);
        }
      }
    });
  });

  group('FcmSendError', () {
    String fcmError(int code, String status, String? errorCode, String message) => jsonEncode({
      'error': {
        'code': code,
        'message': message,
        'status': status,
        if (errorCode != null)
          'details': [
            {'@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', 'errorCode': errorCode},
          ],
      },
    });

    test('UNREGISTERED is a dead token', () {
      final e = FcmSendError.parse(404, fcmError(404, 'NOT_FOUND', 'UNREGISTERED', 'Requested entity was not found.'));
      expect(e.errorCode, 'UNREGISTERED');
      expect(e.isDeadToken, isTrue);
    });

    test('an invalid registration token is dead; an invalid payload is not', () {
      final token = FcmSendError.parse(400, fcmError(400, 'INVALID_ARGUMENT', 'INVALID_ARGUMENT', 'The registration token is not a valid FCM registration token'));
      expect(token.isDeadToken, isTrue);
      final payload = FcmSendError.parse(400, fcmError(400, 'INVALID_ARGUMENT', 'INVALID_ARGUMENT', "Invalid value at 'message.data[0].value' (TYPE_STRING), 5"));
      expect(payload.isDeadToken, isFalse);
    });

    test('a non-JSON body still gives the status, and the log line never has the message', () {
      final e = FcmSendError.parse(502, '<html>Bad gateway</html>');
      expect(e.statusCode, 502);
      expect(e.errorCode, isNull);
      final logged = FcmSendError.parse(400, fcmError(400, 'INVALID_ARGUMENT', 'INVALID_ARGUMENT', 'token secret-token-value is bad')).toString();
      expect(logged, isNot(contains('secret-token-value')));
      expect(logged, contains('400'));
    });
  });

  group('CachedAccessToken', () {
    final now = DateTime.utc(2026, 10, 3, 12);

    test('is reused until five minutes before it expires', () {
      expect(CachedAccessToken(token: 'at', expiry: now.add(const Duration(minutes: 30))).isUsable(now), isTrue);
      expect(CachedAccessToken(token: 'at', expiry: now.add(const Duration(minutes: 4))).isUsable(now), isFalse);
      expect(CachedAccessToken(token: 'at', expiry: now.subtract(const Duration(minutes: 1))).isUsable(now), isFalse);
      expect(CachedAccessToken(token: '', expiry: now.add(const Duration(hours: 1))).isUsable(now), isFalse);
    });
  });

  group('SendNotification', () {
    tearDown(() => Constant.serverPushUrl = '');

    test('nothing is sent (and nothing downloaded) without a recipient token', () async {
      expect(await SendNotification.sendFcmMessage('order_placed', '', {}), isFalse);
      expect(await SendNotification.sendFcmMessage('order_placed', 'null', {}), isFalse);
      expect(await SendNotification.sendChatFcmMessage('Ann', 'hi', '  ', {'type': 'orderChat'}), isFalse);
      expect(await SendNotification.sendOneNotification(token: '', title: 't', body: 'b', payload: const {}), isFalse);
    });

    test('with serverPushUrl set, the service-account key is never fetched', () async {
      Constant.serverPushUrl = 'https://us-central1-spideli-870b0.cloudfunctions.net/sendPush';
      expect(SendNotification.useServerPush, isTrue);
      expect(() => SendNotification.getCharacters(), throwsStateError);
      await expectLater(SendNotification.getAccessToken(), throwsStateError);
      Constant.serverPushUrl = '';
      expect(SendNotification.useServerPush, isFalse);
    });
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:spideliprovider/services/push_message.dart';

/// The pure parts of sending and receiving pushes (lib/services/push_message.dart):
/// the FCM v1 payload, the channel per receiving app, the project path, error
/// handling, and when this device's token may be written or cleared.
void main() {
  group('data payload', () {
    test('every value is a string, nulls are dropped, maps and lists are JSON', () {
      final Map<String, String> data = stringifyPushData(<String, dynamic>{
        'type': 'provider_order',
        'orderId': 'abc',
        'amount': 12.5,
        'count': 3,
        'paid': true,
        'missing': null,
        'extra': <String, dynamic>{'a': 1, 'b': null},
        'list': <dynamic>[1, 'two'],
        'when': DateTime.utc(2026, 10, 3),
      });
      expect(data.values.every((v) => v.runtimeType == String), isTrue);
      expect(data.containsKey('missing'), isFalse);
      expect(data['amount'], '12.5');
      expect(data['count'], '3');
      expect(data['paid'], 'true');
      expect(jsonDecode(data['extra']!), <String, dynamic>{'a': 1, 'b': null});
      expect(jsonDecode(data['list']!), <dynamic>[1, 'two']);
      expect(data['when'], DateTime.utc(2026, 10, 3).toString());
    });

    test('a non-encodable value inside a map does not throw', () {
      final Map<String, String> data = stringifyPushData(<String, dynamic>{
        'nested': <String, dynamic>{'at': DateTime.utc(2026)},
      });
      expect(data['nested'], contains('2026'));
    });

    test('keys FCM refuses are dropped instead of failing the whole message', () {
      final Map<String, String> data = stringifyPushData(<String, dynamic>{
        'from': 'x',
        'notification': 'x',
        'message_type': 'x',
        'collapse_key': 'x',
        'google.c.a': 'x',
        'gcm.n.e': 'x',
        'orderId': 'o1',
      });
      expect(data, <String, String>{'orderId': 'o1'});
    });

    test('a null payload is an empty data block', () {
      expect(stringifyPushData(null), isEmpty);
    });

    test('type is always present: the kind fills it when the payload has none', () {
      expect(buildPushData(<String, dynamic>{'orderId': 'o1'}, kind: 'provider_accepted'), <String, String>{'orderId': 'o1', 'type': 'provider_accepted'});
      expect(buildPushData(null, kind: 'chat'), <String, String>{'type': 'chat'});
      expect(buildPushData(<String, dynamic>{'type': 'provider_order', 'orderId': 'o1'}, kind: 'service_completed')['type'], 'provider_order');
      expect(buildPushData(<String, dynamic>{'type': '', 'orderId': 'o1'}, kind: 'stop_time')['type'], 'stop_time');
    });
  });

  group('tokens', () {
    test('empty and "null" are not tokens', () {
      expect(isUsableFcmToken(null), isFalse);
      expect(isUsableFcmToken(''), isFalse);
      expect(isUsableFcmToken('   '), isFalse);
      expect(isUsableFcmToken('null'), isFalse);
      expect(isUsableFcmToken('NULL'), isFalse);
      expect(isUsableFcmToken('dXk2:APA91bH'), isTrue);
    });

    test('the recipient token read at send time beats the copy on the booking', () {
      expect(preferFreshToken(fresh: 'fresh', fallback: 'copy'), 'fresh');
      expect(preferFreshToken(fresh: '', fallback: 'copy'), 'copy', reason: 'record read but no token there');
      expect(preferFreshToken(fresh: null, fallback: ' copy '), 'copy');
      expect(preferFreshToken(fresh: 'null', fallback: ''), '');
      expect(preferFreshToken(), '');
    });

    test('fingerprint is short, stable and is not the token', () {
      const String token = 'dXk2abcdefghijklmnop:APA91bHxyz';
      final String fp = tokenFingerprint(token);
      expect(fp.length, 8);
      expect(fp, tokenFingerprint(token));
      expect(token.contains(fp), isFalse);
      expect(fp, isNot(tokenFingerprint('${token}x')));
    });
  });

  group('project path', () {
    test('the project id beats the project number held in settings', () {
      expect(fcmProjectId(optionsProjectId: 'spideli-870b0', settingsSenderId: '248496578266'), 'spideli-870b0');
    });

    test('falls back to the service account, then to the setting', () {
      expect(fcmProjectId(optionsProjectId: '', serviceAccountProjectId: 'spideli-870b0', settingsSenderId: '248496578266'), 'spideli-870b0');
      expect(fcmProjectId(optionsProjectId: null, serviceAccountProjectId: 'null', settingsSenderId: '248496578266'), '248496578266');
      expect(fcmProjectId(), '');
    });

    test('send URL', () {
      expect(fcmSendUri('spideli-870b0').toString(), 'https://fcm.googleapis.com/v1/projects/spideli-870b0/messages:send');
    });
  });

  group('channels', () {
    test('booking status goes to the customer, an assignment to the worker', () {
      for (final String kind in <String>['provider_accepted', 'provider_rejected', 'service_intransit', 'service_completed', 'service_charges', 'stop_time']) {
        expect(recipientForKind(kind), PushApp.customer, reason: kind);
      }
      expect(recipientForKind('worker_assigned'), PushApp.worker);
    });

    test('each receiving app gets its own channel and a sound', () {
      expect(pushRouteFor(PushApp.customer).channelId, 'high_importance_channel');
      expect(pushRouteFor(PushApp.worker).channelId, '01');
      expect(pushRouteFor(PushApp.provider).channelId, '01');
      for (final PushApp app in PushApp.values) {
        expect(pushRouteFor(app).androidSound, 'default');
        expect(pushRouteFor(app).apnsSound, 'default');
      }
    });
  });

  group('FCM v1 message', () {
    final Map<String, dynamic> body = buildFcmV1Message(
      token: ' tok123 ',
      title: 'Booking accepted',
      body: 'Your provider accepted the booking',
      data: buildPushData(<String, dynamic>{'type': 'provider_order', 'orderId': 'o1', 'n': 1}, kind: 'provider_accepted'),
      route: pushRouteFor(PushApp.customer),
    );
    final Map<String, dynamic> message = body['message'] as Map<String, dynamic>;

    test('token, notification and string-only data', () {
      expect(message['token'], 'tok123');
      expect(message['notification'], <String, String>{'title': 'Booking accepted', 'body': 'Your provider accepted the booking'});
      final Map<String, String> data = message['data'] as Map<String, String>;
      expect(data, <String, String>{'type': 'provider_order', 'orderId': 'o1', 'n': '1'});
    });

    test('android: high priority on the receiving app channel, with sound', () {
      expect(message['android'], <String, dynamic>{
        'priority': 'high',
        'notification': <String, String>{'channel_id': 'high_importance_channel', 'sound': 'default'},
      });
    });

    test('apns: priority 10 with a sound (a banner without one is silent)', () {
      expect(message['apns'], <String, dynamic>{
        'headers': <String, String>{'apns-priority': '10'},
        'payload': <String, dynamic>{
          'aps': <String, dynamic>{'sound': 'default', 'content-available': 1},
        },
      });
    });

    test('the body survives JSON encoding unchanged', () {
      expect(jsonDecode(jsonEncode(body)), body);
    });

    test('an empty data block is left out', () {
      final Map<String, dynamic> m = buildFcmV1Message(token: 't', title: 'a', body: 'b', data: const <String, String>{}, route: pushRouteFor(PushApp.worker))['message'] as Map<String, dynamic>;
      expect(m.containsKey('data'), isFalse);
    });
  });

  group('notification text', () {
    test('short text is unchanged', () {
      expect(clipPushText('Hello', 10), 'Hello');
      expect(clipPushText('', 10), '');
    });

    test('long text is cut with an ellipsis, within the limit', () {
      final String long = 'a' * 1500;
      final String clipped = clipPushText(long, maxPushBodyLength);
      expect(clipped.length, maxPushBodyLength);
      expect(clipped.endsWith('\u2026'), isTrue);
    });

    test('an emoji is never split in half', () {
      final String text = '${'a' * 8}\u{1F600}\u{1F600}';
      final String clipped = clipPushText(text, 10);
      expect(clipped.length <= 10, isTrue);
      expect(clipped, '${'a' * 8}\u2026');
    });

    test('both message builders clip title and body', () {
      final Map<String, dynamic> m = buildFcmV1Message(token: 't', title: 'T' * 300, body: 'B' * 2000, data: const <String, String>{}, route: pushRouteFor(PushApp.customer))['message'] as Map<String, dynamic>;
      expect((m['notification']['title'] as String).length, maxPushTitleLength);
      expect((m['notification']['body'] as String).length, maxPushBodyLength);
      final Map<String, dynamic> r = buildServerPushRequest(token: 't', title: 'T' * 300, body: 'B' * 2000, data: const <String, String>{}, kind: 'chat', route: pushRouteFor(PushApp.worker));
      expect((r['title'] as String).length, maxPushTitleLength);
      expect((r['body'] as String).length, maxPushBodyLength);
    });
  });

  group('server push', () {
    test('the switch needs an https URL with a host', () {
      expect(isUsableServerPushUrl(null), isFalse);
      expect(isUsableServerPushUrl(''), isFalse);
      expect(isUsableServerPushUrl('http://example.com/sendPush'), isFalse);
      expect(isUsableServerPushUrl('https://'), isFalse);
      expect(isUsableServerPushUrl('not a url'), isFalse);
      expect(isUsableServerPushUrl(' https://us-central1-spideli-870b0.cloudfunctions.net/sendPush '), isTrue);
    });

    test('request carries the same data, kind, channel and sound as the legacy path', () {
      final Map<String, dynamic> request = buildServerPushRequest(
        token: 'tok',
        title: 'New assignment',
        body: 'A booking was assigned to you',
        data: buildPushData(<String, dynamic>{'type': 'provider_order', 'orderId': 'o1'}, kind: 'worker_assigned'),
        kind: 'worker_assigned',
        route: pushRouteFor(recipientForKind('worker_assigned')),
      );
      expect(request, <String, dynamic>{
        'token': 'tok',
        'title': 'New assignment',
        'body': 'A booking was assigned to you',
        'data': <String, String>{'type': 'provider_order', 'orderId': 'o1'},
        'kind': 'worker_assigned',
        'android': <String, String>{'channelId': '01', 'sound': 'default'},
        'apns': <String, String>{'sound': 'default'},
      });
      // Only the fields the function accepts (unknown fields are a 400).
      expect(request.keys.toSet().difference(<String>{'token', 'title', 'body', 'data', 'kind', 'android', 'apns'}), isEmpty);
    });

    test('function errors', () {
      expect(parseServerPushError(404, '{"ok":false,"error":"unregistered"}').isDeadToken, isTrue);
      expect(parseServerPushError(400, '{"ok":false,"error":"invalid_token"}').isDeadToken, isTrue);
      final PushSendError limited = parseServerPushError(429, '{"ok":false,"error":"rate_limited"}');
      expect(limited.code, 'rate_limited');
      expect(limited.isDeadToken, isFalse);
      expect(parseServerPushError(400, '').code, '');
    });
  });

  group('FCM errors', () {
    String fcmError(int code, String status, String message, [String? errorCode]) => jsonEncode(<String, dynamic>{
          'error': <String, dynamic>{
            'code': code,
            'message': message,
            'status': status,
            if (errorCode != null)
              'details': <dynamic>[
                <String, dynamic>{'@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', 'errorCode': errorCode},
              ],
          },
        });

    test('UNREGISTERED is a dead token', () {
      final PushSendError e = parseFcmError(404, fcmError(404, 'NOT_FOUND', 'Requested entity was not found.', 'UNREGISTERED'));
      expect(e.code, 'UNREGISTERED');
      expect(e.isDeadToken, isTrue);
      expect(e.toString(), 'HTTP 404 UNREGISTERED (dead token)');
    });

    test('INVALID_ARGUMENT is a dead token only when it is about the token', () {
      expect(parseFcmError(400, fcmError(400, 'INVALID_ARGUMENT', 'The registration token is not a valid FCM registration token', 'INVALID_ARGUMENT')).isDeadToken, isTrue);
      final PushSendError payload = parseFcmError(400, fcmError(400, 'INVALID_ARGUMENT', 'Invalid value at \'message.data[0].value\' (TYPE_STRING), 12', 'INVALID_ARGUMENT'));
      expect(payload.code, 'INVALID_ARGUMENT');
      expect(payload.isDeadToken, isFalse);
    });

    test('status is used when there is no FCM error code; non-JSON keeps the HTTP status', () {
      final PushSendError e = parseFcmError(403, fcmError(403, 'PERMISSION_DENIED', 'denied'));
      expect(e.code, 'PERMISSION_DENIED');
      expect(e.isDeadToken, isFalse);
      final PushSendError html = parseFcmError(502, '<html>Bad gateway</html>');
      expect(html.code, '');
      expect(html.httpStatus, 502);
    });
  });

  group('access token cache', () {
    final DateTime now = DateTime.utc(2026, 10, 3, 12);

    test('reused while it has more than 5 minutes left', () {
      expect(isAccessTokenFresh(now.add(const Duration(minutes: 30)), now), isTrue);
      expect(isAccessTokenFresh(now.add(const Duration(minutes: 5, seconds: 1)), now), isTrue);
    });

    test('minted again when close to expiry, expired or unknown', () {
      expect(isAccessTokenFresh(now.add(const Duration(minutes: 4)), now), isFalse);
      expect(isAccessTokenFresh(now.subtract(const Duration(minutes: 1)), now), isFalse);
      expect(isAccessTokenFresh(null, now), isFalse);
    });
  });

  group('token-save decisions', () {
    test('this device token is written only onto an existing provider record, when it changes', () {
      expect(shouldWriteDeviceToken(token: 'new', docExists: true, role: 'provider', storedToken: 'old'), isTrue);
      expect(shouldWriteDeviceToken(token: 'new', docExists: true, role: 'provider', storedToken: ''), isTrue);
      expect(shouldWriteDeviceToken(token: 'new', docExists: true, role: 'provider', storedToken: null), isTrue);
      expect(shouldWriteDeviceToken(token: 'same', docExists: true, role: 'provider', storedToken: 'same'), isFalse);
      expect(shouldWriteDeviceToken(token: '', docExists: true, role: 'provider', storedToken: 'good'), isFalse, reason: "'' never replaces a token");
      expect(shouldWriteDeviceToken(token: 'null', docExists: true, role: 'provider', storedToken: 'good'), isFalse);
      expect(shouldWriteDeviceToken(token: 'new', docExists: false, role: null, storedToken: null), isFalse, reason: 'no stub record');
      expect(shouldWriteDeviceToken(token: 'new', docExists: true, role: 'customer', storedToken: 'theirs'), isFalse, reason: "a customer's token belongs to the customer app");
      expect(shouldWriteDeviceToken(token: 'new', docExists: true, role: 'vendor', storedToken: 'theirs'), isFalse);
    });

    test('a full record write carries this device token, else the record token, never ""', () {
      expect(tokenForUserWrite(deviceToken: 'device', modelToken: 'stale'), 'device');
      expect(tokenForUserWrite(deviceToken: '', modelToken: 'stored'), 'stored');
      expect(tokenForUserWrite(deviceToken: null, modelToken: 'stored'), 'stored');
      expect(tokenForUserWrite(deviceToken: '', modelToken: ''), isNull);
      expect(tokenForUserWrite(deviceToken: 'null', modelToken: 'null'), isNull);
    });

    test('sign-out clears the stored token only while it is this device token', () {
      expect(shouldClearTokenOnSignOut(storedToken: 'mine', deviceToken: 'mine'), isTrue);
      expect(shouldClearTokenOnSignOut(storedToken: 'other-device', deviceToken: 'mine'), isFalse);
      expect(shouldClearTokenOnSignOut(storedToken: '', deviceToken: 'mine'), isFalse);
      expect(shouldClearTokenOnSignOut(storedToken: 'mine', deviceToken: ''), isFalse, reason: 'unknown device token: leave it');
    });
  });

  group('tap payloads', () {
    test('a local notification payload decodes back to the push data', () {
      expect(decodeTapPayload('{"type":"provider_order","orderId":"o1"}'), <String, dynamic>{'type': 'provider_order', 'orderId': 'o1'});
    });

    test('missing or malformed payloads are empty, never a crash', () {
      expect(decodeTapPayload(null), isEmpty);
      expect(decodeTapPayload(''), isEmpty);
      expect(decodeTapPayload('not json'), isEmpty);
      expect(decodeTapPayload('[1,2]'), isEmpty);
    });

    test('values are read as strings whatever their type', () {
      final Map<String, dynamic> data = <String, dynamic>{'orderId': 42, 'type': 'provider_order', 'gone': null, 'n': 'null'};
      expect(pushDataString(data, 'orderId'), '42');
      expect(pushDataString(data, 'type'), 'provider_order');
      expect(pushDataString(data, 'gone'), '');
      expect(pushDataString(data, 'n'), '');
      expect(pushDataString(data, 'absent'), '');
      expect(pushDataString(null, 'type'), '');
    });
  });
}

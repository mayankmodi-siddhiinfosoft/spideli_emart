import 'dart:convert';
import 'dart:io';

import 'package:driver/services/push_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// A value jsonEncode cannot handle on its own (stands in for a Timestamp).
class _Opaque {
  @override
  String toString() => 'opaque-value';
}

void main() {
  group('PushMessage.stringData', () {
    test('every value is a String; nulls are dropped', () {
      final Map<String, String> data = PushMessage.stringData(<String, dynamic>{
        'orderId': 'o1',
        'amount': 12.5,
        'count': 3,
        'paid': true,
        'missing': null,
      });
      expect(data, <String, String>{'orderId': 'o1', 'amount': '12.5', 'count': '3', 'paid': 'true'});
      expect(data.containsKey('missing'), isFalse);
    });

    test('maps and lists are JSON-encoded, odd values stringified', () {
      final Map<String, String> data = PushMessage.stringData(<String, dynamic>{
        'author': <String, dynamic>{'id': 'u1', 'when': _Opaque(), 'n': null},
        'ids': <dynamic>['a', 1, _Opaque()],
      });
      expect(jsonDecode(data['author']!), <String, dynamic>{'id': 'u1', 'when': 'opaque-value', 'n': null});
      expect(jsonDecode(data['ids']!), <dynamic>['a', 1, 'opaque-value']);
    });

    test('type is always present: the caller\'s wins, else the template type', () {
      expect(PushMessage.stringData(<String, dynamic>{}, type: 'driver_accepted'), <String, String>{'type': 'driver_accepted'});
      expect(PushMessage.stringData(null, type: 'driver_completed'), <String, String>{'type': 'driver_completed'});
      expect(PushMessage.stringData(<String, dynamic>{'type': 'parcel_order'}, type: 'parcel_accepted')['type'], 'parcel_order');
      expect(PushMessage.stringData(<String, dynamic>{'type': ''}, type: 'rental_completed')['type'], 'rental_completed');
      expect(PushMessage.stringData(<String, dynamic>{'type': null}, type: 'x')['type'], 'x');
      expect(PushMessage.stringData(<String, dynamic>{'orderId': 'o'}).containsKey('type'), isFalse);
    });
  });

  group('tokens', () {
    test('isUsableToken refuses empty and stringified nulls', () {
      for (final String? t in <String?>[null, '', '   ', 'null', 'NULL', 'undefined', 'nil']) {
        expect(PushMessage.isUsableToken(t), isFalse, reason: '$t');
      }
      expect(PushMessage.isUsableToken('fcm-token:APA91b'), isTrue);
    });

    test('shouldSave: never an empty token over a good one, never a no-op write', () {
      expect(PushTokenRules.shouldSave(deviceToken: '', storedToken: 'good'), isFalse);
      expect(PushTokenRules.shouldSave(deviceToken: 'null', storedToken: 'good'), isFalse);
      expect(PushTokenRules.shouldSave(deviceToken: null, storedToken: ''), isFalse);
      expect(PushTokenRules.shouldSave(deviceToken: 'same', storedToken: 'same'), isFalse);
      expect(PushTokenRules.shouldSave(deviceToken: ' same ', storedToken: 'same'), isFalse);
      expect(PushTokenRules.shouldSave(deviceToken: 'new', storedToken: 'old'), isTrue);
      expect(PushTokenRules.shouldSave(deviceToken: 'new', storedToken: ''), isTrue);
      expect(PushTokenRules.shouldSave(deviceToken: 'new', storedToken: null), isTrue);
    });

    test('shouldClearOnSignOut: only when the stored token is this device\'s', () {
      expect(PushTokenRules.shouldClearOnSignOut(storedToken: 'mine', deviceToken: 'mine'), isTrue);
      expect(PushTokenRules.shouldClearOnSignOut(storedToken: 'other-phone', deviceToken: 'mine'), isFalse);
      expect(PushTokenRules.shouldClearOnSignOut(storedToken: '', deviceToken: 'mine'), isFalse);
      expect(PushTokenRules.shouldClearOnSignOut(storedToken: '', deviceToken: ''), isFalse);
      expect(PushTokenRules.shouldClearOnSignOut(storedToken: 'mine', deviceToken: null), isFalse);
    });
  });

  group('project path', () {
    test('uses the Firebase project id, falls back to the settings senderId', () {
      expect(PushMessage.projectId(firebaseProjectId: 'spideli-870b0', settingsSenderId: '248496578266'), 'spideli-870b0');
      expect(PushMessage.projectId(firebaseProjectId: '', settingsSenderId: '248496578266'), '248496578266');
      expect(PushMessage.projectId(firebaseProjectId: null, settingsSenderId: null), '');
    });

    test('v1 send URL', () {
      expect(PushMessage.fcmSendUri('spideli-870b0').toString(), 'https://fcm.googleapis.com/v1/projects/spideli-870b0/messages:send');
    });
  });

  group('channels', () {
    test('each recipient gets a channel its app creates', () {
      expect(PushChannels.forRecipient(PushRecipient.customer).androidChannelId, 'high_importance_channel');
      expect(PushChannels.forRecipient(PushRecipient.store).androidChannelId, 'general');
      final PushTarget newOrder = PushChannels.forRecipient(PushRecipient.storeNewOrder);
      expect(newOrder.androidChannelId, 'new_order');
      expect(newOrder.androidSound, 'order_alert');
      expect(newOrder.apnsSound, 'order_alert.caf');
      expect(PushChannels.forRecipient(PushRecipient.driver).androidChannelId, 'driver_notifications_channel');
      expect(PushChannels.forRecipient(PushRecipient.driverJob).androidChannelId, 'driver_jobs');
      expect(PushChannels.forRecipient(PushRecipient.provider).androidChannelId, '01');
      expect(PushChannels.forRecipient(PushRecipient.worker).androidChannelId, '01');
      for (final PushRecipient r in PushRecipient.values) {
        if (r == PushRecipient.storeNewOrder) continue;
        expect(PushChannels.forRecipient(r).androidSound, 'default', reason: r.name);
        expect(PushChannels.forRecipient(r).apnsSound, 'default', reason: r.name);
      }
    });

    test('the driver shows a push on the channel it belongs to', () {
      expect(PushChannels.driverChannelFor(type: 'new_delivery_order'), 'driver_jobs');
      expect(PushChannels.driverChannelFor(type: 'assign_order'), 'driver_jobs');
      expect(PushChannels.driverChannelFor(type: 'job_queue'), 'driver_jobs');
      expect(PushChannels.driverChannelFor(type: 'orderChat'), 'driver_notifications_channel');
      expect(PushChannels.driverChannelFor(type: 'customer_cancelled'), 'driver_notifications_channel');
      expect(PushChannels.driverChannelFor(type: null), 'driver_notifications_channel');
      // The sender's channel wins when it is one of the driver's...
      expect(PushChannels.driverChannelFor(type: 'orderChat', requestedChannelId: 'driver_jobs'), 'driver_jobs');
      expect(PushChannels.driverChannelFor(type: 'new_delivery_order', requestedChannelId: 'driver_notifications_channel'), 'driver_notifications_channel');
      // ...and is ignored when it belongs to another app.
      expect(PushChannels.driverChannelFor(type: 'new_delivery_order', requestedChannelId: 'new_order'), 'driver_jobs');
      expect(PushChannels.driverChannelFor(type: 'x', requestedChannelId: 'high_importance_channel'), 'driver_notifications_channel');
    });

    test('the driver manifest default is the general channel the app creates', () {
      final File manifest = File('android/app/src/main/AndroidManifest.xml');
      final String xml = manifest.readAsStringSync();
      final RegExpMatch? m = RegExp(
        r'com\.google\.firebase\.messaging\.default_notification_channel_id"\s*android:value="([^"]+)"',
      ).firstMatch(xml);
      expect(m?.group(1), PushChannels.driver);
      expect(xml, contains('android.permission.POST_NOTIFICATIONS'));
    });

    test('the other apps still create the channels the driver sends to', () {
      // Guards against a receiving app renaming its channel without the
      // senders following (PUSH-CHANNELS.md). Skipped outside the monorepo.
      final Map<String, List<String>> appChannels = <String, List<String>>{
        '../customer/lib': <String>[PushChannels.customer],
        '../vendor/lib': <String>[PushChannels.storeGeneral, PushChannels.storeNewOrder],
      };
      appChannels.forEach((String libDir, List<String> channels) {
        final Directory lib = Directory(libDir);
        if (!lib.existsSync()) return;
        final List<String> sources = lib
            .listSync(recursive: true)
            .whereType<File>()
            .where((File f) => f.path.endsWith('.dart'))
            .map((File f) => f.readAsStringSync())
            .toList();
        for (final String channel in channels) {
          expect(sources.any((String s) => s.contains("'$channel'")), isTrue, reason: '$libDir should define channel $channel');
        }
      });
    });
  });

  group('v1 message (legacy path)', () {
    final Map<String, dynamic> msg = PushMessage.v1Message(
      token: ' tok ',
      title: 'Driver accepted',
      body: 'On the way',
      data: PushMessage.stringData(<String, dynamic>{'orderId': 'o1', 'n': 2}, type: 'driver_accepted'),
      recipient: PushRecipient.customer,
    );
    final Map<String, dynamic> m = msg['message'] as Map<String, dynamic>;

    test('token, notification and string-only data', () {
      expect(m['token'], 'tok');
      expect(m['notification'], <String, String>{'title': 'Driver accepted', 'body': 'On the way'});
      expect(m['data'], <String, String>{'orderId': 'o1', 'n': '2', 'type': 'driver_accepted'});
      expect((m['data'] as Map).values.every((dynamic v) => v is String), isTrue);
    });

    test('android: high priority on the recipient channel', () {
      final Map<String, dynamic> android = m['android'] as Map<String, dynamic>;
      expect(android['priority'], 'high');
      expect(android['notification'], <String, String>{'channel_id': 'high_importance_channel', 'sound': 'default'});
    });

    test('apns: priority 10, sound, content-available', () {
      final Map<String, dynamic> apns = m['apns'] as Map<String, dynamic>;
      expect(apns['headers'], <String, String>{'apns-priority': '10'});
      expect(apns['payload'], <String, dynamic>{
        'aps': <String, dynamic>{'sound': 'default', 'content-available': 1},
      });
    });

    test('store recipient goes on the store general channel; encodes to JSON', () {
      final Map<String, dynamic> store = PushMessage.v1Message(
        token: 't',
        title: '',
        body: '',
        data: const <String, String>{},
        recipient: PushRecipient.store,
      );
      final Map<String, dynamic> sm = store['message'] as Map<String, dynamic>;
      expect((sm['android'] as Map)['notification'], <String, String>{'channel_id': 'general', 'sound': 'default'});
      expect(sm.containsKey('data'), isFalse);
      expect(() => jsonEncode(store), returnsNormally);
    });
  });

  group('server request', () {
    test('matches the sendPush contract fields', () {
      final Map<String, dynamic> req = PushMessage.serverRequest(
        token: 'tok',
        title: 'T',
        body: 'B',
        data: const <String, String>{'type': 'orderChat', 'orderId': 'o1'},
        recipient: PushRecipient.customer,
        kind: 'chat',
      );
      expect(req.keys.toSet(), <String>{'token', 'title', 'body', 'data', 'kind', 'android', 'apns'});
      expect(req['kind'], 'chat');
      expect(req['android'], <String, String>{'channelId': 'high_importance_channel', 'sound': 'default'});
      expect(req['apns'], <String, String>{'sound': 'default'});
      final Map<String, dynamic> noKind = PushMessage.serverRequest(
        token: 'tok',
        title: 'T',
        body: 'B',
        data: const <String, String>{},
        recipient: PushRecipient.store,
      );
      expect(noKind.containsKey('kind'), isFalse);
      expect(noKind['android'], <String, String>{'channelId': 'general', 'sound': 'default'});
    });

    test('isHttpsUrl is the switch', () {
      expect(PushMessage.isHttpsUrl('https://us-central1-spideli-870b0.cloudfunctions.net/sendPush'), isTrue);
      expect(PushMessage.isHttpsUrl(' https://sendpush-abc-uc.a.run.app '), isTrue);
      expect(PushMessage.isHttpsUrl('http://example.com/sendPush'), isFalse);
      expect(PushMessage.isHttpsUrl(''), isFalse);
      expect(PushMessage.isHttpsUrl(null), isFalse);
      expect(PushMessage.isHttpsUrl('https://'), isFalse);
      expect(PushMessage.isHttpsUrl('not a url'), isFalse);
    });
  });

  group('errors', () {
    test('FCM error code from the FcmError detail, else the status', () {
      const String unregistered =
          '{"error":{"code":404,"message":"Requested entity was not found.","status":"NOT_FOUND","details":[{"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError","errorCode":"UNREGISTERED"}]}}';
      final FcmFailure f = PushMessage.parseFcmError(404, unregistered);
      expect(f.code, 'UNREGISTERED');
      expect(f.statusCode, 404);
      expect(PushMessage.isDeadTokenError(fcmCode: f.code, fcmMessage: f.message), isTrue);

      const String badToken =
          '{"error":{"code":400,"message":"The registration token is not a valid FCM registration token","status":"INVALID_ARGUMENT"}}';
      final FcmFailure b = PushMessage.parseFcmError(400, badToken);
      expect(b.code, 'INVALID_ARGUMENT');
      expect(PushMessage.isDeadTokenError(fcmCode: b.code, fcmMessage: b.message), isTrue);

      const String badData =
          '{"error":{"code":400,"message":"Invalid value at \'message.data[0].value\' (TYPE_STRING), 5","status":"INVALID_ARGUMENT"}}';
      final FcmFailure d = PushMessage.parseFcmError(400, badData);
      expect(PushMessage.isDeadTokenError(fcmCode: d.code, fcmMessage: d.message), isFalse);

      final FcmFailure html = PushMessage.parseFcmError(502, '<html>Bad gateway</html>');
      expect(html.code, '');
      expect(html.toString(), 'HTTP 502 -');
    });

    test('server error codes', () {
      expect(PushMessage.parseServerError('{"ok":false,"error":"unregistered"}'), 'unregistered');
      expect(PushMessage.parseServerError('nope'), '');
      expect(PushMessage.isDeadTokenError(serverCode: 'unregistered'), isTrue);
      expect(PushMessage.isDeadTokenError(serverCode: 'invalid_token'), isTrue);
      expect(PushMessage.isDeadTokenError(serverCode: 'rate_limited'), isFalse);
    });
  });

  group('access token cache', () {
    test('reused until five minutes before expiry', () {
      final DateTime now = DateTime.utc(2026, 10, 3, 12);
      final CachedAccessToken t = CachedAccessToken('ya29.x', now.add(const Duration(minutes: 60)));
      expect(t.isFresh(now), isTrue);
      expect(t.isFresh(now.add(const Duration(minutes: 54))), isTrue);
      expect(t.isFresh(now.add(const Duration(minutes: 55))), isFalse);
      expect(t.isFresh(now.add(const Duration(minutes: 61))), isFalse);
      expect(CachedAccessToken('', now.add(const Duration(hours: 1))).isFresh(now), isFalse);
    });
  });
}

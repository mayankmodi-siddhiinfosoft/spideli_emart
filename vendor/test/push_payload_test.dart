import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/utils/push_payload.dart';

/// The pure pieces of the store's push sending / receiving
/// (lib/utils/push_payload.dart), plus file checks for the native wiring a
/// push needs to show and sound.
void main() {
  group('stringData (FCM v1 data must be string to string)', () {
    test('every value becomes a string; nulls are dropped', () {
      final data = PushPayload.stringData({
        'orderId': 'o1',
        'count': 3,
        'amount': 12.5,
        'paid': true,
        'missing': null,
        'items': ['a', 'b'],
        'meta': {'k': 1},
      });
      expect(data.values.every((v) => v.runtimeType == String), isTrue);
      expect(data.containsKey('missing'), isFalse);
      expect(data['count'], '3');
      expect(data['amount'], '12.5');
      expect(data['paid'], 'true');
      expect(jsonDecode(data['items']!), ['a', 'b']);
      expect(jsonDecode(data['meta']!), {'k': 1});
    });

    test('a nested value json cannot encode falls back to toString', () {
      final data = PushPayload.stringData({
        'when': [DateTime.utc(2026, 10, 3)],
      });
      expect(data['when'], contains('2026-10-03'));
    });

    test('type is added when the caller did not set one, and kept when it did', () {
      expect(PushPayload.stringData({}, type: 'restaurant_accepted'), {'type': 'restaurant_accepted'});
      expect(PushPayload.stringData(null, type: 'chat'), {'type': 'chat'});
      expect(PushPayload.stringData({'type': 'orderChat'}, type: 'chat')['type'], 'orderChat');
      expect(PushPayload.stringData({'type': ''}, type: 'chat')['type'], 'chat');
      expect(PushPayload.stringData({}), isEmpty);
    });

    test('keys FCM refuses are dropped', () {
      final data = PushPayload.stringData({'from': 'x', 'notification': 'x', 'message_type': 'x', 'collapse_key': 'x', 'google.c': 'x', 'gcm.n': 'x', 'ok': 'y'});
      expect(data, {'ok': 'y'});
    });
  });

  group('tokens', () {
    test('empty, blank and the string "null" are not sendable', () {
      expect(PushPayload.isUsableToken(null), isFalse);
      expect(PushPayload.isUsableToken(''), isFalse);
      expect(PushPayload.isUsableToken('   '), isFalse);
      expect(PushPayload.isUsableToken('null'), isFalse);
      expect(PushPayload.isUsableToken('dXk3:APA91b-abc'), isTrue);
    });

    test('save only a real token that differs from the stored one', () {
      expect(PushTokenPolicy.shouldSave(newToken: '', storedToken: 'good'), isFalse, reason: 'never write an empty token over a good one');
      expect(PushTokenPolicy.shouldSave(newToken: 'null', storedToken: 'good'), isFalse);
      expect(PushTokenPolicy.shouldSave(newToken: null, storedToken: ''), isFalse);
      expect(PushTokenPolicy.shouldSave(newToken: 'good', storedToken: 'good'), isFalse);
      expect(PushTokenPolicy.shouldSave(newToken: 'new', storedToken: 'old'), isTrue);
      expect(PushTokenPolicy.shouldSave(newToken: 'new', storedToken: null), isTrue);
      expect(PushTokenPolicy.shouldSave(newToken: 'new', storedToken: ''), isTrue);
    });

    test('sign-out clears the stored token only when it is still this device\'s', () {
      expect(PushTokenPolicy.shouldClearOnSignOut(storedToken: 'mine', deviceToken: 'mine'), isTrue);
      expect(PushTokenPolicy.shouldClearOnSignOut(storedToken: 'other-phone', deviceToken: 'mine'), isFalse);
      expect(PushTokenPolicy.shouldClearOnSignOut(storedToken: '', deviceToken: ''), isFalse);
      expect(PushTokenPolicy.shouldClearOnSignOut(storedToken: 'x', deviceToken: null), isFalse);
    });

    test('a dead token is cleared only while it is still the stored one', () {
      expect(PushTokenPolicy.shouldClearStale(storedToken: 'dead', badToken: 'dead'), isTrue);
      expect(PushTokenPolicy.shouldClearStale(storedToken: 'refreshed', badToken: 'dead'), isFalse);
      expect(PushTokenPolicy.shouldClearStale(storedToken: '', badToken: ''), isFalse);
    });
  });

  group('project path', () {
    test('the real project id wins over the settings senderId (a project number)', () {
      expect(PushPayload.fcmProjectId(firebaseProjectId: 'spideli-870b0', settingsSenderId: '248496578266'), 'spideli-870b0');
      expect(PushPayload.fcmProjectId(firebaseProjectId: '', settingsSenderId: '248496578266'), '248496578266');
      expect(PushPayload.fcmProjectId(firebaseProjectId: null, settingsSenderId: null), '');
      expect(PushPayload.fcmSendUri('spideli-870b0').toString(), 'https://fcm.googleapis.com/v1/projects/spideli-870b0/messages:send');
    });
  });

  group('channel by receiving app', () {
    test('customer and driver pushes name a channel their app creates', () {
      expect(PushPayload.channelFor(PushRecipient.customer, 'restaurant_accepted'), const PushChannel(androidChannelId: 'high_importance_channel', androidSound: 'default', apnsSound: 'default'));
      // A new job rings on the driver's loud job channel; anything else on
      // the driver's general channel (also its manifest default).
      expect(PushPayload.channelFor(PushRecipient.driver, 'new_delivery_order'), const PushChannel(androidChannelId: 'driver_jobs', androidSound: 'default', apnsSound: 'default'));
      expect(PushPayload.channelFor(PushRecipient.driver, 'driver_cancelled'), const PushChannel(androidChannelId: 'driver_notifications_channel', androidSound: 'default', apnsSound: 'default'));
      // Chat: the dedicated chat channel in every app (never a job channel).
      expect(PushPayload.channelFor(PushRecipient.driver, 'chat').androidChannelId, 'chat_messages');
    });

    test('a new order for the store rings on new_order with the alert tone', () {
      for (final type in ['order_placed', 'schedule_order', 'dinein_placed', 'new_order']) {
        expect(PushPayload.channelFor(PushRecipient.store, type), const PushChannel(androidChannelId: 'new_order', androidSound: 'order_alert', apnsSound: 'order_alert.caf'), reason: type);
      }
      expect(PushPayload.channelFor(PushRecipient.store, 'chat').androidChannelId, 'chat_messages');
      expect(PushPayload.channelFor(PushRecipient.store, null).androidChannelId, 'general');
    });

    test('recipient app from the user role', () {
      expect(PushPayload.recipientForRole('driver'), PushRecipient.driver);
      expect(PushPayload.recipientForRole('vendor'), PushRecipient.store);
      expect(PushPayload.recipientForRole('employee'), PushRecipient.store);
      expect(PushPayload.recipientForRole('customer'), PushRecipient.customer);
      expect(PushPayload.recipientForRole(null), PushRecipient.customer);
    });

    test('order alerts received by the store', () {
      expect(PushPayload.isStoreOrderAlert(type: 'order_placed'), isTrue);
      expect(PushPayload.isStoreOrderAlert(type: 'ORDER_PLACED'), isTrue);
      expect(PushPayload.isStoreOrderAlert(type: 'new_order_placed'), isTrue);
      expect(PushPayload.isStoreOrderAlert(type: 'orderChat'), isFalse);
      expect(PushPayload.isStoreOrderAlert(type: 'new_delivery_order'), isFalse);
      expect(PushPayload.isStoreOrderAlert(type: '', channelId: 'new_order'), isTrue);
      expect(PushPayload.isStoreOrderAlert(), isFalse);
    });
  });

  group('legacy FCM v1 message', () {
    final channel = PushPayload.channelFor(PushRecipient.customer, 'restaurant_accepted');

    test('has the android and apns blocks that make it show and sound in the background', () {
      final body = PushPayload.legacyMessage(token: ' tok ', title: 'T', body: 'B', data: {'type': 'restaurant_accepted', 'orderId': 'o1'}, channel: channel);
      final message = body['message'] as Map<String, dynamic>;
      expect(message['token'], 'tok');
      expect(message['notification'], {'title': 'T', 'body': 'B'});
      expect(message['data'], {'type': 'restaurant_accepted', 'orderId': 'o1'});
      expect(message['android'], {
        'priority': 'high',
        'notification': {'channel_id': 'high_importance_channel', 'sound': 'default'},
      });
      expect(message['apns'], {
        'headers': {'apns-priority': '10'},
        'payload': {
          'aps': {'sound': 'default', 'content-available': 1},
        },
      });
      // It must survive JSON encoding as is.
      expect(() => jsonEncode(body), returnsNormally);
    });

    test('no data key when there is no data; long text is clipped', () {
      final body = PushPayload.legacyMessage(token: 't', title: 'x' * 500, body: 'y' * 5000, data: const {}, channel: channel);
      final message = body['message'] as Map<String, dynamic>;
      expect(message.containsKey('data'), isFalse);
      expect((message['notification']['title'] as String).length, PushPayload.maxTitleLength);
      expect((message['notification']['body'] as String).length, PushPayload.maxBodyLength);
    });
  });

  group('server push (SERVER-PUSH-CONTRACT.md)', () {
    test('switch: only a non-empty https URL', () {
      expect(PushPayload.isServerPushUrl('https://us-central1-spideli-870b0.cloudfunctions.net/sendPush'), isTrue);
      expect(PushPayload.isServerPushUrl(' https://sendpush-abc-uc.a.run.app '), isTrue);
      expect(PushPayload.isServerPushUrl('http://example.com/sendPush'), isFalse);
      expect(PushPayload.isServerPushUrl(''), isFalse);
      expect(PushPayload.isServerPushUrl(null), isFalse);
      expect(PushPayload.isServerPushUrl('https://'), isFalse);
    });

    test('body uses only the fields the function accepts, with the same channel', () {
      final channel = PushPayload.channelFor(PushRecipient.driver, 'new_delivery_order');
      final body = PushPayload.serverBody(token: 't', title: 'T', body: 'B', data: {'type': 'new_delivery_order'}, kind: 'new_delivery_order', channel: channel);
      expect(body.keys.toSet().difference({'token', 'topic', 'title', 'body', 'data', 'kind', 'android', 'apns'}), isEmpty);
      expect(body['kind'], 'new_delivery_order');
      expect(body['android'], {'channelId': 'driver_jobs', 'sound': 'default'});
      expect(body['apns'], {'sound': 'default'});
      final noKind = PushPayload.serverBody(token: 't', title: '', body: '', data: const {}, kind: '', channel: channel);
      expect(noKind.containsKey('kind'), isFalse);
    });
  });

  group('responses', () {
    const unregistered =
        '{"error":{"code":404,"message":"Requested entity was not found.","status":"NOT_FOUND","details":[{"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError","errorCode":"UNREGISTERED"}]}}';
    const badToken =
        '{"error":{"code":400,"message":"The registration token is not a valid FCM registration token","status":"INVALID_ARGUMENT","details":[{"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError","errorCode":"INVALID_ARGUMENT"}]}}';
    const badPayload =
        '{"error":{"code":400,"message":"Invalid value at \'message.data[0].value\' (TYPE_STRING), 3","status":"INVALID_ARGUMENT","details":[{"@type":"type.googleapis.com/google.rpc.BadRequest"}]}}';

    test('error code from FCM and from the server function', () {
      expect(PushPayload.errorCode(unregistered), 'UNREGISTERED');
      expect(PushPayload.errorCode(badPayload), 'INVALID_ARGUMENT');
      expect(PushPayload.errorCode('{"ok":false,"error":"unregistered","message":"x"}'), 'unregistered');
      expect(PushPayload.errorCode('<html>'), '');
      expect(PushPayload.isSuccess(200), isTrue);
      expect(PushPayload.isSuccess(400), isFalse);
    });

    test('a dead token is told apart from a bad payload', () {
      expect(PushPayload.isDeadToken(404, unregistered), isTrue);
      expect(PushPayload.isDeadToken(400, badToken), isTrue);
      expect(PushPayload.isDeadToken(400, badPayload), isFalse);
      expect(PushPayload.isDeadToken(404, '{"ok":false,"error":"unregistered"}'), isTrue);
      expect(PushPayload.isDeadToken(400, '{"ok":false,"error":"invalid_token"}'), isTrue);
      expect(PushPayload.isDeadToken(429, '{"ok":false,"error":"rate_limited"}'), isFalse);
      expect(PushPayload.isDeadToken(500, ''), isFalse);
    });
  });

  group('tap routing', () {
    test('each type opens the right place; unknown or missing data does nothing', () {
      expect(NotificationRouting.targetFor(type: 'admin_chat'), NotificationTarget.adminChat);
      expect(NotificationRouting.targetFor(type: 'orderChat', chatType: 'admin'), NotificationTarget.adminChat);
      expect(NotificationRouting.targetFor(type: 'orderChat', chatType: 'vendor'), NotificationTarget.orderChat);
      expect(NotificationRouting.targetFor(type: 'order_placed'), NotificationTarget.orders);
      expect(NotificationRouting.targetFor(type: 'schedule_order'), NotificationTarget.orders);
      expect(NotificationRouting.targetFor(type: 'driver_accepted'), NotificationTarget.orders);
      expect(NotificationRouting.targetFor(type: 'dinein_placed'), NotificationTarget.dineIn);
      expect(NotificationRouting.targetFor(type: 'advertisement_approved'), NotificationTarget.none);
      expect(NotificationRouting.targetFor(), NotificationTarget.none);
    });
  });

  group('native wiring (files)', () {
    test('Android: the manifest default channel is the order channel the app creates, and its tone exists', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      final match = RegExp(r'default_notification_channel_id"\s*android:value="([^"]+)"').firstMatch(manifest);
      expect(match?.group(1), PushPayload.storeOrderChannelId);
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(File('android/app/src/main/res/raw/${PushPayload.storeOrderAndroidSound}.wav').existsSync(), isTrue);
      expect(File('android/app/src/main/res/raw/keep.xml').readAsStringSync(), contains('@raw/${PushPayload.storeOrderAndroidSound}'));
    });

    test('iOS: tone bundled, remote-notification mode, push entitlement in every configuration', () {
      expect(File('ios/Runner/${PushPayload.storeOrderApnsSound}').existsSync(), isTrue);
      final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      expect(project, contains('${PushPayload.storeOrderApnsSound} in Resources */,'));
      expect(RegExp(r'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;').allMatches(project).length, greaterThanOrEqualTo(3));
      expect(File('ios/Runner/Runner.entitlements').readAsStringSync(), contains('aps-environment'));
      expect(File('ios/Runner/Info.plist').readAsStringSync(), contains('<string>remote-notification</string>'));
      final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(appDelegate, contains('UNUserNotificationCenter.current().delegate = self'));
      expect(appDelegate, contains('registerForRemoteNotifications()'));
    });

    test('the receiving apps\' manifest defaults match the channels the store names', () {
      final customer = File('../customer/android/app/src/main/AndroidManifest.xml');
      final driver = File('../driver/android/app/src/main/AndroidManifest.xml');
      if (!customer.existsSync() || !driver.existsSync()) {
        markTestSkipped('sibling apps not checked out');
        return;
      }
      String defaultChannel(File f) => RegExp(r'default_notification_channel_id"\s*android:value="([^"]+)"').firstMatch(f.readAsStringSync())?.group(1) ?? '';
      expect(defaultChannel(customer), PushPayload.customerChannelId);
      expect(defaultChannel(driver), PushPayload.driverChannelId);
    });
  });
}

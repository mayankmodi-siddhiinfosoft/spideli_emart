import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/service/order_ringtone_service.dart';
import 'package:vendor/utils/push_payload.dart';

/// The admin's order sound in the store app: what the store sends (a new job
/// for its own delivery man), how it recognises a new-order push, the
/// no-double-sound decision, and the native wiring.
void main() {
  const String url = 'https://example.com/ring.mp3';

  group('sending (channelFor)', () {
    test('without a ringtone: exactly today\'s channels and sounds', () {
      for (final String? none in [null, '', '  ']) {
        expect(PushPayload.channelFor(PushRecipient.driver, 'new_delivery_order', orderRingtoneUrl: none), const PushChannel(androidChannelId: 'driver_jobs', androidSound: 'default', apnsSound: 'default'));
        expect(PushPayload.channelFor(PushRecipient.store, 'order_placed', orderRingtoneUrl: none), const PushChannel(androidChannelId: 'new_order', androidSound: 'order_alert', apnsSound: 'order_alert.caf'));
      }
      expect(PushPayload.channelFor(PushRecipient.driver, 'new_delivery_order'), const PushChannel(androidChannelId: 'driver_jobs', androidSound: 'default', apnsSound: 'default'));
    });

    test('with a ringtone: a new job / order names the versioned channel and iOS sound', () {
      expect(PushPayload.channelFor(PushRecipient.driver, 'new_delivery_order', orderRingtoneUrl: url),
          const PushChannel(androidChannelId: 'driver_jobs_rt_955470e2', androidSound: 'default', apnsSound: 'order_ringtone_955470e2.caf'));
      expect(PushPayload.channelFor(PushRecipient.store, 'order_placed', orderRingtoneUrl: url),
          const PushChannel(androidChannelId: 'new_order_rt_955470e2', androidSound: 'order_alert', apnsSound: 'order_ringtone_955470e2.caf'));
    });

    test('with a ringtone: everything else is unchanged', () {
      expect(PushPayload.channelFor(PushRecipient.driver, 'driver_cancelled', orderRingtoneUrl: url), const PushChannel(androidChannelId: 'driver_notifications_channel', androidSound: 'default', apnsSound: 'default'));
      expect(PushPayload.channelFor(PushRecipient.customer, 'restaurant_accepted', orderRingtoneUrl: url), const PushChannel(androidChannelId: 'high_importance_channel', androidSound: 'default', apnsSound: 'default'));
      expect(PushPayload.channelFor(PushRecipient.store, 'store_update', orderRingtoneUrl: url), const PushChannel(androidChannelId: 'general', androidSound: 'default', apnsSound: 'default'));
      expect(PushPayload.channelFor(PushRecipient.store, 'orderChat', orderRingtoneUrl: url), PushPayload.chatChannel);
    });

    test('the legacy and server bodies carry the versioned channel and sound', () {
      final PushChannel channel = PushPayload.channelFor(PushRecipient.driver, 'new_delivery_order', orderRingtoneUrl: url);
      final Map<String, dynamic> message = PushPayload.legacyMessage(token: 't', title: 'T', body: 'B', data: const {'type': 'new_delivery_order', 'orderId': 'o1'}, channel: channel)['message'] as Map<String, dynamic>;
      expect(message['android'], {
        'priority': 'high',
        'notification': {'channel_id': 'driver_jobs_rt_955470e2', 'sound': 'default'},
      });
      expect(message['apns'], {
        'headers': {'apns-priority': '10'},
        'payload': {
          'aps': {'sound': 'order_ringtone_955470e2.caf', 'content-available': 1},
        },
      });
      final Map<String, dynamic> server = PushPayload.serverBody(token: 't', title: 'T', body: 'B', data: const {}, kind: 'new_delivery_order', channel: channel);
      expect(server['android'], {'channelId': 'driver_jobs_rt_955470e2', 'sound': 'default'});
      expect(server['apns'], {'sound': 'order_ringtone_955470e2.caf'});
    });
  });

  group('receiving', () {
    test('a push on a ringtone order channel is an order alert (any key)', () {
      expect(PushPayload.isStoreOrderAlert(channelId: 'new_order_rt_955470e2'), isTrue);
      expect(PushPayload.isStoreOrderAlert(channelId: 'new_order_rt_7e9d3d28', type: 'something'), isTrue);
      expect(PushPayload.isStoreOrderAlert(channelId: 'new_order'), isTrue);
      expect(PushPayload.isStoreOrderAlert(channelId: 'general', type: 'orderChat'), isFalse);
    });

    test('iOS: the order sounds', () {
      expect(ForegroundOrderSound.isOrderSound('order_ringtone_955470e2.caf'), isTrue);
      expect(ForegroundOrderSound.isOrderSound('order_alert.caf'), isTrue);
      expect(ForegroundOrderSound.isOrderSound('default'), isFalse);
      expect(ForegroundOrderSound.isOrderSound(null), isFalse);
    });

    test('download file extension', () {
      expect(OrderRingtoneService.audioExtension(Uri.parse('https://firebasestorage.googleapis.com/v0/b/x/o/ringtones%2Forder.mp3?alt=media&token=1'), null), 'mp3');
      expect(OrderRingtoneService.audioExtension(Uri.parse('https://x.y/a/tone.WAV'), 'audio/mpeg'), 'wav');
      expect(OrderRingtoneService.audioExtension(Uri.parse('https://x.y/download?id=3'), 'audio/x-wav'), 'wav');
      expect(OrderRingtoneService.audioExtension(Uri.parse('https://x.y/download'), 'audio/mp4'), 'm4a');
      expect(OrderRingtoneService.audioExtension(Uri.parse('https://x.y/download'), null), 'mp3');
    });
  });

  group('no double sound (foreground)', () {
    test('silent only for a new-order alert in the foreground while the in-app alert rings', () {
      expect(ForegroundOrderSound.silent(orderAlert: true, foreground: true, inAppRinging: true), isTrue);
      expect(ForegroundOrderSound.silent(orderAlert: true, foreground: true, inAppRinging: false), isFalse, reason: 'nothing else rings: the notification does');
      expect(ForegroundOrderSound.silent(orderAlert: true, foreground: false, inAppRinging: true), isFalse, reason: 'background handler: unchanged');
      expect(ForegroundOrderSound.silent(orderAlert: false, foreground: true, inAppRinging: true), isFalse, reason: 'chat etc. keep their sound');
    });

    test('waits for the in-app alert only where the orders screen rings for it', () {
      expect(ForegroundOrderSound.inAppRingExpected(orderAlert: true, type: 'order_placed', ordersScreenAlive: true), isTrue);
      expect(ForegroundOrderSound.inAppRingExpected(orderAlert: true, type: 'scheduled_order_due', ordersScreenAlive: true), isTrue);
      expect(ForegroundOrderSound.inAppRingExpected(orderAlert: true, type: 'dinein_placed', ordersScreenAlive: true), isFalse);
      expect(ForegroundOrderSound.inAppRingExpected(orderAlert: true, type: 'order_placed', ordersScreenAlive: false), isFalse);
      expect(ForegroundOrderSound.inAppRingExpected(orderAlert: false, type: 'orderChat', ordersScreenAlive: true), isFalse);
    });
  });

  group('native wiring (files)', () {
    test('Android: provider, its paths, the Dart channel; manifest default stays new_order', () {
      final String manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:name=".OrderRingtoneProvider"'));
      expect(manifest, contains(r'android:authorities="${applicationId}.order_ringtone"'));
      expect(manifest, contains('android:exported="false"'));
      expect(manifest, contains('@xml/order_ringtone_paths'));
      expect(RegExp(r'default_notification_channel_id"\s*android:value="new_order"').hasMatch(manifest), isTrue);
      expect(File('android/app/src/main/res/xml/order_ringtone_paths.xml').readAsStringSync(), contains('path="order_ringtones/"'));
      final String kotlin = File('android/app/src/main/kotlin/com/emart/store/OrderRingtone.kt').readAsStringSync();
      expect(kotlin, contains('"spideli/order_ringtone"'));
      expect(kotlin, contains('com.android.systemui'));
      expect(kotlin, contains('order_ringtone"'));
      expect(File('android/app/src/main/kotlin/com/emart/store/MainActivity.kt').readAsStringSync(), contains('OrderRingtoneFiles.register('));
    });

    test('iOS: Library/Sounds conversion and the foreground presentation hook', () {
      final String appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(appDelegate, contains('"spideli/order_ringtone"'));
      expect(appDelegate, contains('appendingPathComponent("Sounds"'));
      expect(appDelegate, contains('kAudioFormatLinearPCM'));
      expect(appDelegate, contains('maxSeconds = 29.5'));
      expect(appDelegate, contains('willPresent notification'));
      expect(appDelegate, contains('"foregroundPushSilent"'));
    });
  });
}

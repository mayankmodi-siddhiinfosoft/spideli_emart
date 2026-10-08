import 'dart:io';

import 'package:driver/services/push_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// The admin's order sound in the driver app: channel choice for jobs and
/// dispatch offers, what the driver app would send, the no-double-sound
/// decision, and the native wiring.
void main() {
  const String url = 'https://example.com/ring.mp3';

  group('sending (forRecipient)', () {
    test('without a ringtone: exactly today\'s targets', () {
      for (final String? none in [null, '']) {
        final PushTarget job = PushChannels.forRecipient(PushRecipient.driverJob, orderRingtoneUrl: none);
        expect([job.androidChannelId, job.androidSound, job.apnsSound], ['driver_jobs', 'default', 'default']);
        final PushTarget store = PushChannels.forRecipient(PushRecipient.storeNewOrder, orderRingtoneUrl: none);
        expect([store.androidChannelId, store.androidSound, store.apnsSound], ['new_order', 'order_alert', 'order_alert.caf']);
      }
    });

    test('with a ringtone: new job / new order are versioned, the rest unchanged', () {
      final PushTarget job = PushChannels.forRecipient(PushRecipient.driverJob, orderRingtoneUrl: url);
      expect([job.androidChannelId, job.androidSound, job.apnsSound], ['driver_jobs_rt_955470e2', 'default', 'order_ringtone_955470e2.caf']);
      final PushTarget store = PushChannels.forRecipient(PushRecipient.storeNewOrder, orderRingtoneUrl: url);
      expect([store.androidChannelId, store.androidSound, store.apnsSound], ['new_order_rt_955470e2', 'order_alert', 'order_ringtone_955470e2.caf']);
      for (final PushRecipient r in [PushRecipient.customer, PushRecipient.store, PushRecipient.driver, PushRecipient.provider, PushRecipient.worker]) {
        final PushTarget before = PushChannels.forRecipient(r);
        final PushTarget after = PushChannels.forRecipient(r, orderRingtoneUrl: url);
        expect([after.androidChannelId, after.androidSound, after.apnsSound], [before.androidChannelId, before.androidSound, before.apnsSound], reason: '$r');
      }
    });

    test('the v1 message and the server body carry them', () {
      final Map<String, dynamic> message = PushMessage.v1Message(token: 't', title: 'T', body: 'B', data: const {'type': 'job_assigned'}, recipient: PushRecipient.driverJob, orderRingtoneUrl: url)['message'] as Map<String, dynamic>;
      expect((message['android'] as Map)['notification'], {'channel_id': 'driver_jobs_rt_955470e2', 'sound': 'default'});
      expect(((message['apns'] as Map)['payload'] as Map)['aps'], {'sound': 'order_ringtone_955470e2.caf', 'content-available': 1});
      final Map<String, dynamic> server = PushMessage.serverRequest(token: 't', title: 'T', body: 'B', data: const {}, recipient: PushRecipient.driverJob, orderRingtoneUrl: url);
      expect(server['android'], {'channelId': 'driver_jobs_rt_955470e2', 'sound': 'default'});
      expect(server['apns'], {'sound': 'order_ringtone_955470e2.caf'});
    });
  });

  group('receiving: channel of a local notification', () {
    test('a push on any driver_jobs_rt_<key> is a job', () {
      expect(PushChannels.driverChannelFor(requestedChannelId: 'driver_jobs_rt_955470e2'), 'driver_jobs');
      expect(PushChannels.driverChannelFor(requestedChannelId: 'driver_jobs_rt_7e9d3d28', type: 'job_assigned'), 'driver_jobs');
      expect(PushChannels.driverChannelFor(requestedChannelId: 'driver_jobs_rt_7e9d3d28', type: 'orderChat'), 'chat_messages', reason: 'chat never on a ringtone channel');
      expect(PushChannels.driverChannelFor(requestedChannelId: 'spideli'), 'spideli');
      expect(PushChannels.driverChannelFor(requestedChannelId: 'driver_notifications_channel', type: 'customer_cancelled'), 'driver_notifications_channel');
    });

    test('jobs and dispatch offers use the prepared ringtone channel; nothing else does', () {
      expect(JobAlertChannels.localChannelFor('driver_jobs', preparedKey: '955470e2'), 'driver_jobs_rt_955470e2');
      expect(JobAlertChannels.localChannelFor('spideli', preparedKey: '955470e2'), 'driver_jobs_rt_955470e2');
      expect(JobAlertChannels.localChannelFor('driver_notifications_channel', preparedKey: '955470e2'), 'driver_notifications_channel');
      expect(JobAlertChannels.localChannelFor('driver_jobs'), 'driver_jobs', reason: 'not prepared: today\'s channel');
      expect(JobAlertChannels.localChannelFor('spideli', preparedKey: ''), 'spideli');
    });
  });

  group('no double sound', () {
    test('silent only for a job / offer while the in-app alert rings', () {
      expect(ForegroundJobSound.silent(jobAlert: true, foreground: true, inAppRinging: true), isTrue);
      expect(ForegroundJobSound.silent(jobAlert: true, foreground: true, inAppRinging: false), isFalse);
      expect(ForegroundJobSound.silent(jobAlert: true, foreground: false, inAppRinging: true), isFalse);
      expect(ForegroundJobSound.silent(jobAlert: false, foreground: true, inAppRinging: true), isFalse);
    });

    test('iOS: which pushes presented in the foreground are job alerts', () {
      // The dispatch Cloud Functions' offer (sound "default" today).
      expect(ForegroundJobSound.isJobAlertPush({'type': 'order', 'orderId': 'o1', 'click_action': 'FLUTTER_NOTIFICATION_CLICK', 'status': 'Driver Pending'}, apsSound: 'default'), isTrue);
      expect(ForegroundJobSound.isJobAlertPush({'type': 'new_delivery_order', 'orderId': 'o1'}, apsSound: 'default'), isTrue);
      expect(ForegroundJobSound.isJobAlertPush({'type': 'x'}, apsSound: 'order_ringtone_955470e2.caf'), isTrue);
      expect(ForegroundJobSound.isJobAlertPush({'type': 'orderChat', 'orderId': 'o1'}, apsSound: 'default'), isFalse);
      expect(ForegroundJobSound.isJobAlertPush({'type': 'driver_cancelled'}, apsSound: 'default'), isFalse);
    });
  });

  group('native wiring (files)', () {
    test('Android: provider, paths, Dart channel; manifest default unchanged', () {
      final String manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:name=".OrderRingtoneProvider"'));
      expect(manifest, contains(r'android:authorities="${applicationId}.order_ringtone"'));
      expect(manifest, contains('@xml/order_ringtone_paths'));
      expect(RegExp(r'default_notification_channel_id"\s*android:value="driver_notifications_channel"').hasMatch(manifest), isTrue);
      expect(File('android/app/src/main/res/xml/order_ringtone_paths.xml').readAsStringSync(), contains('path="order_ringtones/"'));
      expect(File('android/app/src/main/kotlin/com/emart/driver/OrderRingtone.kt').readAsStringSync(), contains('com.android.systemui'));
      expect(File('android/app/src/main/kotlin/com/emart/driver/MainActivity.kt').readAsStringSync(), contains('OrderRingtoneFiles.register('));
    });

    test('iOS: Library/Sounds conversion and the foreground presentation hook', () {
      final String appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(appDelegate, contains('appendingPathComponent("Sounds"'));
      expect(appDelegate, contains('kAudioFormatLinearPCM'));
      expect(appDelegate, contains('"foregroundPushSilent"'));
    });

    test('the store and driver native files are the same apart from the package', () {
      final File store = File('../vendor/android/app/src/main/kotlin/com/emart/store/OrderRingtone.kt');
      if (!store.existsSync()) {
        markTestSkipped('vendor not checked out');
        return;
      }
      final String driver = File('android/app/src/main/kotlin/com/emart/driver/OrderRingtone.kt').readAsStringSync();
      expect(store.readAsStringSync().replaceFirst('package com.spideli.store', 'package com.spideli.driver'), driver);
      String ringtonePart(String s) => s.substring(s.indexOf('// MARK: - Order ringtone'));
      expect(ringtonePart(File('../vendor/ios/Runner/AppDelegate.swift').readAsStringSync()), ringtonePart(File('ios/Runner/AppDelegate.swift').readAsStringSync()));
    });
  });
}

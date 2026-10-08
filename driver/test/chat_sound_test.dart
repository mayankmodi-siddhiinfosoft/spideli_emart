import 'dart:io';

import 'package:driver/services/chat_sound.dart';
import 'package:driver/services/push_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chat pushes have their own channel and sound; job / offer pushes keep the
/// job channels (and the admin's ringtone). Never mixed.
void main() {
  const String url = 'https://example.com/ring.mp3';

  test('a chat push the driver sends: chat channel and sound, to every app', () {
    for (final PushRecipient r in PushRecipient.values) {
      for (final String? u in [null, url]) {
        final PushTarget t = PushChannels.forRecipient(r, orderRingtoneUrl: u, kind: 'chat');
        expect([t.androidChannelId, t.androidSound, t.apnsSound], ['chat_messages', 'chat_message', 'chat_message.wav'], reason: '$r $u');
      }
    }
    final Map<String, dynamic> message = PushMessage.v1Message(token: 't', title: 'T', body: 'B', data: const {'type': 'orderChat'}, recipient: PushRecipient.customer, kind: 'orderChat')['message'] as Map<String, dynamic>;
    expect((message['android'] as Map)['notification'], {'channel_id': 'chat_messages', 'sound': 'chat_message'});
    expect(((message['apns'] as Map)['payload'] as Map)['aps'], {'sound': 'chat_message.wav', 'content-available': 1});
  });

  test('order pushes never use the chat channel', () {
    expect(PushChannels.forRecipient(PushRecipient.driverJob, kind: 'job_assigned').androidChannelId, 'driver_jobs');
    expect(PushChannels.forRecipient(PushRecipient.customer, kind: 'driver_accepted').androidChannelId, 'high_importance_channel');
  });

  test('a received chat push: chat channel, never a job / offer / ringtone channel, not a job alert', () {
    for (final String? requested in [null, 'driver_jobs', 'spideli', 'driver_jobs_rt_955470e2', 'chat_messages', 'driver_notifications_channel']) {
      expect(PushChannels.driverChannelFor(type: 'orderChat', requestedChannelId: requested), ChatSound.channelId, reason: '$requested');
    }
    expect(PushChannels.driverChannelFor(type: 'admin_chat'), ChatSound.channelId);
    expect(JobAlertChannels.isJobAlert(ChatSound.channelId), isFalse);
    expect(JobAlertChannels.localChannelFor(ChatSound.channelId, preparedKey: '955470e2'), ChatSound.channelId);
    expect(ForegroundJobSound.isJobAlertPush({'type': 'orderChat', 'orderId': 'o1'}, apsSound: 'chat_message.wav'), isFalse);
    expect(PushChannels.driverChannelFor(type: 'new_delivery_order'), 'driver_jobs');
  });

  test('the chat sound ships on both platforms', () {
    final List<int> wav = File('android/app/src/main/res/raw/chat_message.wav').readAsBytesSync();
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(File('ios/Runner/chat_message.wav').readAsBytesSync(), wav);
    expect(File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(), contains('chat_message.wav in Resources */,'));
    expect(File('lib/utils/notification_service.dart').readAsStringSync(), contains('RawResourceAndroidNotificationSound(ChatSound.androidSound)'));
  });

  test('every app has the identical chat_sound.dart and the same chat sound file', () {
    final List<String> dirs = ['../customer/lib/service', '../vendor/lib/utils', '../driver/lib/services', '../spideli_provider/lib/services', '../spideli_worker/lib/services'];
    final List<String> apps = ['../customer', '../vendor', '../driver', '../spideli_provider', '../spideli_worker'];
    if (dirs.any((d) => !File('$d/chat_sound.dart').existsSync())) {
      markTestSkipped('sibling apps not checked out');
      return;
    }
    final String first = File('${dirs.first}/chat_sound.dart').readAsStringSync();
    for (final String d in dirs) {
      expect(File('$d/chat_sound.dart').readAsStringSync(), first, reason: d);
    }
    final List<int> wav = File('android/app/src/main/res/raw/chat_message.wav').readAsBytesSync();
    for (final String a in apps) {
      expect(File('$a/android/app/src/main/res/raw/chat_message.wav').readAsBytesSync(), wav, reason: a);
      expect(File('$a/ios/Runner/chat_message.wav').readAsBytesSync(), wav, reason: a);
      expect(File('$a/ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(), contains('chat_message.wav in Resources */,'), reason: a);
    }
  });
}

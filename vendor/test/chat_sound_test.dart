import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/utils/chat_sound.dart';
import 'package:vendor/utils/push_payload.dart';

/// Chat pushes have their own channel and sound in every app; order pushes
/// keep the order channels (and the admin's ringtone). Never mixed.
void main() {
  const String url = 'https://example.com/ring.mp3';
  const PushChannel chat = PushChannel(androidChannelId: 'chat_messages', androidSound: 'chat_message', apnsSound: 'chat_message.wav');

  test('a chat push the store sends uses the chat channel and sound, to every app, with or without a ringtone', () {
    for (final PushRecipient r in PushRecipient.values) {
      for (final String? u in [null, url]) {
        expect(PushPayload.channelFor(r, 'chat', orderRingtoneUrl: u), chat, reason: '$r $u');
        expect(PushPayload.channelFor(r, 'orderChat', orderRingtoneUrl: u), chat, reason: '$r $u');
      }
    }
  });

  test('order / job pushes never use the chat channel', () {
    expect(PushPayload.channelFor(PushRecipient.store, 'order_placed').androidChannelId, 'new_order');
    expect(PushPayload.channelFor(PushRecipient.store, 'order_placed', orderRingtoneUrl: url).androidChannelId, 'new_order_rt_955470e2');
    expect(PushPayload.channelFor(PushRecipient.driver, 'new_delivery_order', orderRingtoneUrl: url).androidChannelId, 'driver_jobs_rt_955470e2');
  });

  test('a received chat push is never an order alert (no order channel, no in-app ring)', () {
    expect(PushPayload.isStoreOrderAlert(type: 'orderChat', channelId: 'chat_messages'), isFalse);
    expect(PushPayload.isStoreOrderAlert(type: 'orderChat', channelId: 'new_order'), isFalse, reason: 'an older sender naming new_order for chat');
    expect(PushPayload.isStoreOrderAlert(type: 'new_order_chat'), isFalse);
    expect(PushPayload.isStoreOrderAlert(type: 'order_placed', channelId: 'new_order'), isTrue);
    expect(ChatSound.isChatPush(type: 'admin_chat'), isTrue);
    expect(ChatSound.isChatPush(type: 'x', channelId: 'chat_messages'), isTrue);
    expect(ChatSound.isChatPush(type: 'order_placed', channelId: 'new_order'), isFalse);
  });

  test('the chat sound ships on both platforms', () {
    final List<int> wav = File('android/app/src/main/res/raw/chat_message.wav').readAsBytesSync();
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(File('android/app/src/main/res/raw/keep_chat_message.xml').readAsStringSync(), contains('@raw/chat_message'));
    expect(File('ios/Runner/chat_message.wav').readAsBytesSync(), wav);
    final String project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(project, contains('chat_message.wav in Resources */,'));
    expect(File('lib/utils/notification_service.dart').readAsStringSync(), contains('RawResourceAndroidNotificationSound(ChatSound.androidSound)'));
  });
}

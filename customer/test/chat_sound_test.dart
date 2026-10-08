import 'dart:io';

import 'package:customer/service/chat_sound.dart';
import 'package:customer/service/push_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chat pushes have their own channel and sound in every app; new orders to
/// a store keep the order channel (and the admin's ringtone). Never mixed.
void main() {
  const String url = 'https://example.com/ring.mp3';

  test('a chat push the customer sends: chat channel and sound, to every app, with or without a ringtone', () {
    for (final PushRecipient? r in [...PushRecipient.values, null]) {
      for (final String? u in [null, url]) {
        expect(PushChannels.forRecipient(r, kind: 'chat', orderRingtoneUrl: u), const PushChannelSpec(androidChannelId: 'chat_messages', androidSound: 'chat_message', apnsSound: 'chat_message.wav'), reason: '$r $u');
      }
    }
    final PushChannelSpec spec = PushChannels.forRecipient(PushRecipient.store, kind: 'chat');
    expect(PushPayload.stringData({'type': 'orderChat'}, spec: spec)['channelId'], 'chat_messages');
  });

  test('new orders to a store never use the chat channel', () {
    expect(PushChannels.forRecipient(PushRecipient.store, kind: 'order_placed').androidChannelId, 'new_order');
    expect(PushChannels.forRecipient(PushRecipient.store, kind: 'order_placed', orderRingtoneUrl: url).androidChannelId, 'new_order_rt_955470e2');
  });

  test('received: chat types / the chat channel are chat; order updates are not', () {
    expect(ChatSound.isChatPush(type: 'orderChat'), isTrue);
    expect(ChatSound.isChatPush(type: 'admin_chat'), isTrue);
    expect(ChatSound.isChatPush(type: 'x', channelId: 'chat_messages'), isTrue);
    expect(ChatSound.isChatPush(type: 'driver_accepted', channelId: 'high_importance_channel'), isFalse);
    expect(File('lib/utils/notification_service.dart').readAsStringSync(), contains('RawResourceAndroidNotificationSound(ChatSound.androidSound)'));
  });

  test('the chat sound ships on both platforms', () {
    final List<int> wav = File('android/app/src/main/res/raw/chat_message.wav').readAsBytesSync();
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(File('android/app/src/main/res/raw/keep_chat_message.xml').readAsStringSync(), contains('@raw/chat_message'));
    expect(File('ios/Runner/chat_message.wav').readAsBytesSync(), wav);
    expect(File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(), contains('chat_message.wav in Resources */,'));
  });
}

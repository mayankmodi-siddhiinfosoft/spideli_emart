import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spideliworker/services/chat_sound.dart';
import 'package:spideliworker/services/push_message.dart';

/// Chat pushes: their own channel and sound in every app; jobs keep `01`.
void main() {
  test('a chat push the worker sends: chat channel and sound, to every app', () {
    for (final PushRecipient r in PushRecipient.values) {
      final PushChannel c = pushChannelFor(r, kind: 'chat');
      expect([c.androidChannelId, c.androidSound, c.apnsSound], ['chat_messages', 'chat_message', 'chat_message.wav'], reason: '$r');
    }
  });

  test('job pushes keep their channels', () {
    expect(pushChannelFor(PushRecipient.customer, kind: 'service_intransit').androidChannelId, 'high_importance_channel');
    expect(pushChannelFor(PushRecipient.provider).androidChannelId, '01');
  });

  test('received chat pushes are recognised; the sound ships on both platforms', () {
    expect(ChatSound.isChatPush(type: 'orderChat'), isTrue);
    expect(ChatSound.isChatPush(type: 'provider_order', channelId: '01'), isFalse);
    final List<int> wav = File('android/app/src/main/res/raw/chat_message.wav').readAsBytesSync();
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(File('ios/Runner/chat_message.wav').readAsBytesSync(), wav);
    expect(File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(), contains('chat_message.wav in Resources */,'));
    expect(File('lib/services/notification_service.dart').readAsStringSync(), contains('RawResourceAndroidNotificationSound(ChatSound.androidSound)'));
  });
}

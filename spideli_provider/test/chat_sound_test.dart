import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spideliprovider/services/chat_sound.dart';
import 'package:spideliprovider/services/push_message.dart';

/// Chat pushes: their own channel and sound in every app; bookings keep `01`.
void main() {
  test('a chat push the provider sends: chat channel and sound, to every app', () {
    for (final PushApp app in PushApp.values) {
      final PushRoute r = pushRouteFor(app, kind: 'chat');
      expect([r.channelId, r.androidSound, r.apnsSound], ['chat_messages', 'chat_message', 'chat_message.wav'], reason: '$app');
    }
    final Map<String, dynamic> message = buildFcmV1Message(token: 't', title: 'T', body: 'B', data: const {'type': 'orderChat'}, route: pushRouteFor(PushApp.customer, kind: 'chat'))['message'] as Map<String, dynamic>;
    expect((message['android'] as Map)['notification'], {'channel_id': 'chat_messages', 'sound': 'chat_message'});
    expect(((message['apns'] as Map)['payload'] as Map)['aps'], {'sound': 'chat_message.wav', 'content-available': 1});
  });

  test('booking pushes keep their channels', () {
    expect(pushRouteFor(PushApp.customer, kind: 'provider_accepted').channelId, 'high_importance_channel');
    expect(pushRouteFor(PushApp.worker, kind: 'worker_assigned').channelId, '01');
    expect(pushRouteFor(PushApp.customer).channelId, 'high_importance_channel');
  });

  test('received chat pushes are recognised; the sound ships on both platforms', () {
    expect(ChatSound.isChatPush(type: 'orderChat'), isTrue);
    expect(ChatSound.isChatPush(type: 'provider_chat'), isTrue);
    expect(ChatSound.isChatPush(type: 'provider_order', channelId: '01'), isFalse);
    final List<int> wav = File('android/app/src/main/res/raw/chat_message.wav').readAsBytesSync();
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(File('ios/Runner/chat_message.wav').readAsBytesSync(), wav);
    expect(File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(), contains('chat_message.wav in Resources */,'));
    expect(File('lib/services/notification_service.dart').readAsStringSync(), contains('RawResourceAndroidNotificationSound(ChatSound.androidSound)'));
  });
}

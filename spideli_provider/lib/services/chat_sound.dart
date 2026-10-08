// Chat notifications have their own sound, never the order ringtone
// (`.claude/PUSH-CHANNELS.md`, "Chat sound").
//
// THIS FILE IS IDENTICAL in customer/lib/service/, vendor/lib/utils/,
// driver/lib/services/, spideli_provider/lib/services/ and
// spideli_worker/lib/services/ (chat_sound.dart). Pure Dart, unit tested in
// each app (test/chat_sound_test.dart).
//
// Every app creates the Android channel [ChatSound.channelId] at start-up
// with the bundled `res/raw/chat_message.wav`, ships the same file in its iOS
// bundle (`Runner/chat_message.wav`), and every chat push it sends names that
// channel and sound. A device without the channel (an older build) shows the
// push on its manifest default channel.

abstract final class ChatSound {
  /// Android channel for chat messages, in every app.
  static const String channelId = 'chat_messages';
  static const String channelName = 'Chat messages';
  static const String channelDescription = 'Chat messages and support replies';

  /// `res/raw/chat_message.wav` (Android `sound`, no extension).
  static const String androidSound = 'chat_message';

  /// `Runner/chat_message.wav` in the iOS bundle (`aps.sound`).
  static const String apnsSound = 'chat_message.wav';

  /// The kind every sender uses for a chat message push.
  static const String kind = 'chat';

  /// A push the app is sending is a chat message.
  static bool isChatKind(String? kind) => (kind ?? '').trim().toLowerCase() == ChatSound.kind;

  /// A push the app received is a chat message: it names the chat channel,
  /// or its `data.type` is a chat type (`orderChat`, `chat`, `admin_chat`,
  /// `provider_chat`, ...).
  static bool isChatPush({String? type, String? channelId}) {
    if ((channelId ?? '').trim() == ChatSound.channelId) return true;
    final String t = (type ?? '').trim().toLowerCase();
    return t == 'orderchat' || t == 'chat' || t.endsWith('_chat');
  }
}

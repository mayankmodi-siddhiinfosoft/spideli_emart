import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:vendor/utils/preferences.dart';

/// The looping in-app alert that sounds while a new order is waiting
/// (report #11, foreground half - the background half is the FCM channel in
/// `NotificationService`).
class AudioPlayerService {
  /// Created on first use. It used to be a `late` field written only by
  /// [initAudio], which `FireStoreUtils.getSettings` calls *only* when
  /// `globalSettings.order_ringtone_url` is set - and after an await. Until
  /// then every [playSound] threw a LateInitializationError that the catch
  /// below swallowed, so the alert was silent on any install whose ringtone
  /// had not been configured, and on every order that arrived before the
  /// settings document had loaded.
  static AudioPlayer? _audioPlayer;

  static AudioPlayer get _player => _audioPlayer ??= AudioPlayer(playerId: "playerId");

  /// Kept for the existing call sites; creating the player is now enough.
  static Future<void> initAudio() async {
    _player;
  }

  /// Bundled copy of the push channel's tone (`res/raw/order_alert.wav`),
  /// played when no `order_ringtone_url` is configured.
  static const String fallbackAsset = 'sounds/order_alert.wav';

  static Future<void> playSound(bool isPlay) async {
    try {
      final String ringtone = Preferences.getString(Preferences.orderRingtone);
      if (isPlay) {
        if (_player.state != PlayerState.playing) {
          log("PlaySound :: 11 :: $isPlay :: $ringtone");
          // An install with no ringtone configured used to stay silent here;
          // it now plays the same tone as the `new_order` push channel.
          await _player.setSource(ringtone.isEmpty ? AssetSource(fallbackAsset) : UrlSource(ringtone));
          await _player.setReleaseMode(ReleaseMode.loop);
          await _player.resume();
        }
      } else {
        // Stopping must not create a player just to stop it.
        final AudioPlayer? player = _audioPlayer;
        if (player != null && player.state != PlayerState.stopped) {
          log("PlaySound :: 22 :: $isPlay :: $ringtone");
          await player.stop();
        }
      }
    } catch (e) {
      log("Error in playSound: $e");
    }
  }
}

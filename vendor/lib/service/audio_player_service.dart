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

  /// True from the moment the alert is asked to ring until it is stopped
  /// (or failed to start). A new-order notification posted while it is true
  /// is posted silently: the loop already plays the order sound
  /// (`NotificationService.display`, no double sound).
  static bool _ringing = false;

  static bool get isRinging => _ringing;

  /// Waits up to [max] for the alert to start ringing (a push and the order
  /// listener that starts the ring arrive at about the same time). True when
  /// it rings.
  static Future<bool> waitForRing(Duration max) async {
    final DateTime until = DateTime.now().add(max);
    while (!_ringing && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return _ringing;
  }

  /// The admin changed `order_ringtone_url` while the alert rings: start it
  /// again with the new sound (no restart of the app needed).
  static Future<void> refreshSource() async {
    final AudioPlayer? player = _audioPlayer;
    if (!_ringing || player == null) return;
    try {
      await player.stop();
    } catch (_) {}
    await playSound(true);
  }

  static Future<void> playSound(bool isPlay) async {
    _ringing = isPlay;
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
      if (isPlay) _ringing = false;
      log("Error in playSound: $e");
    }
  }
}

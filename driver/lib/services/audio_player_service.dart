import 'package:audioplayers/audioplayers.dart';
import 'package:driver/utils/preferences.dart';

class AudioPlayerService {
  /// Created on first use (it used to be `late`, set only when a ringtone
  /// URL was configured at start-up, so a URL set later never rang).
  static AudioPlayer? _audioPlayer;

  static AudioPlayer get _player => _audioPlayer ??= AudioPlayer(playerId: "playerId");

  /// Holds on the alert taken by the incoming-order dialog ([hold]). While
  /// one is held, `playSound(false)` from a module screen — which stops the
  /// shared player whenever ITS list has nothing to ring for, on every
  /// `users/{me}` snapshot — leaves the dialog's ring alone; only [release]
  /// stops it.
  static int _holds = 0;

  /// The incoming-order dialog holds the alert.
  static bool get held => _holds > 0;

  /// True from the moment the alert is asked to ring until it stops (or
  /// failed to start). A job / offer notification posted while it is true is
  /// posted silently: the alert already loops the order sound
  /// (`NotificationService.display`, no double sound).
  static bool _ringing = false;

  static bool get isRinging => _ringing;

  /// Waits up to [max] for the alert to start (the push and the listener or
  /// dialog that starts it arrive at about the same time). True when it rings.
  static Future<bool> waitForRing(Duration max) async {
    final DateTime until = DateTime.now().add(max);
    while (!_ringing && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return _ringing;
  }

  static Future<void> initAudio() async {
    _audioPlayer = AudioPlayer(playerId: "playerId");
  }

  static Future<void> playSound(bool isPlay) async {
    if (!isPlay && _holds > 0) return;
    await _set(isPlay);
  }

  /// The incoming-order dialog starts ringing and keeps the ring until it
  /// [release]s it.
  static Future<void> hold() async {
    _holds++;
    await _set(true);
  }

  /// The incoming-order dialog closed: its ring stops (a screen that still
  /// has an offer of its own rings again on its next update).
  static Future<void> release() async {
    if (_holds > 0) _holds--;
    if (_holds == 0) await _set(false);
  }

  /// The admin changed `order_ringtone_url` while the alert rings: start it
  /// again with the new sound (no restart of the app needed).
  static Future<void> refreshSource() async {
    final AudioPlayer? player = _audioPlayer;
    if (!_ringing || player == null) return;
    try {
      await player.stop();
    } catch (_) {}
    await _set(true);
  }

  static Future<void> _set(bool isPlay) async {
    _ringing = isPlay;
    try {
      final String url = Preferences.getString(Preferences.orderRingtone);
      if (isPlay) {
        // No ringtone configured: no in-app alert (as before).
        if (url.isEmpty) {
          _ringing = false;
          return;
        }
        if (url.isEmpty) return;
        if (_player.state != PlayerState.playing) {
          await _player.setSource(UrlSource(url));
          await _player.setReleaseMode(ReleaseMode.loop);
          await _player.resume();
        }
      } else {
        final AudioPlayer? player = _audioPlayer;
        if (player != null && player.state != PlayerState.stopped) {
          await player.stop();
        }
      }
    } catch (e) {
      if (isPlay) _ringing = false;
      print("Error in playSound: $e");
    }
  }
}

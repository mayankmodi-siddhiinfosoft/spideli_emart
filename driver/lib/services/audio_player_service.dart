import 'package:audioplayers/audioplayers.dart';
import 'package:driver/utils/preferences.dart';

class AudioPlayerService {
  static late AudioPlayer _audioPlayer;

  /// Holds on the alert taken by the incoming-order dialog ([hold]). While
  /// one is held, `playSound(false)` from a module screen — which stops the
  /// shared player whenever ITS list has nothing to ring for, on every
  /// `users/{me}` snapshot — leaves the dialog's ring alone; only [release]
  /// stops it.
  static int _holds = 0;

  /// The incoming-order dialog holds the alert.
  static bool get held => _holds > 0;

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

  static Future<void> _set(bool isPlay) async {
    try {
      if (isPlay) {
        if (_audioPlayer.state != PlayerState.playing) {
          await _audioPlayer.setSource(UrlSource(Preferences.getString(Preferences.orderRingtone)));
          await _audioPlayer.setReleaseMode(ReleaseMode.loop);
          await _audioPlayer.resume();
        }
      } else {
        if (_audioPlayer.state != PlayerState.stopped) {
          await _audioPlayer.stop();
        }
      }
    } catch (e) {
      print("Error in playSound: $e");
    }
  }
}

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Replaces an FCM token restored from an Android backup, once per install.
///
/// Found on a Redmi Note 12 (3 Oct 2026): after a reinstall, Android's app
/// backup restored the previous install's Firebase registration. The SDK kept
/// returning that token, FCM answered UNREGISTERED ("Topic subscribe failed:
/// Not Found"), and every push to the account was lost. Backup is now off in
/// the manifest; this repairs installs that already hold a restored token by
/// deleting it once, so the next getToken() registers a fresh one (which the
/// caller then saves on the user's record).
class FcmTokenReset {
  FcmTokenReset._();

  static const String _doneKey = 'fcm_token_reset_v1';
  static Future<void>? _running;

  /// Call before getToken(). Android only; never throws. Not marked done when
  /// it fails (e.g. offline), so it is tried again on the next launch.
  static Future<void> runOnce() => _running ??= _run();

  static Future<void> _run() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_doneKey) == true) return;
      await FirebaseMessaging.instance.deleteToken();
      await prefs.setBool(_doneKey, true);
      debugPrint('FcmTokenReset: previous FCM token replaced');
    } catch (e) {
      debugPrint('FcmTokenReset: $e');
    }
  }
}

import 'dart:async';

/// Decisions about this device's FCM token, kept free of Firebase so they can
/// be unit tested. `PushTokenSync` does the reads and writes.
abstract final class PushToken {
  /// The last usable token FirebaseMessaging gave this device, or null.
  static String? device;

  /// Not empty and not the string 'null'.
  static bool isUsable(String? token) {
    final String t = token?.trim() ?? '';
    return t.isNotEmpty && t.toLowerCase() != 'null';
  }

  /// The value to write to `users/{uid}.fcmToken`, or null for "write
  /// nothing": an empty token is never written (on iOS `getToken()` fails
  /// until the APNs token arrives, and writing '' wiped the good token so the
  /// iPhone received nothing), and the stored token is not written again.
  static String? toWrite({required String? deviceToken, required String? storedToken}) {
    if (!isUsable(deviceToken)) return null;
    final String t = deviceToken!.trim();
    if (t == storedToken?.trim()) return null;
    return t;
  }

  /// Signing out clears `users/{uid}.fcmToken` only while it still holds THIS
  /// device's token: the customer may have signed in on another phone since,
  /// and that phone's token must stay.
  static bool shouldClearOnSignOut({required String? storedToken, required String? deviceToken}) {
    if (!isUsable(deviceToken) || !isUsable(storedToken)) return false;
    return storedToken!.trim() == deviceToken!.trim();
  }

  /// The token a saved copy of the signed-in user should carry: this device's
  /// token when it has one, otherwise what the copy already had.
  static String? preferDevice(String? existing) => isUsable(device) ? device!.trim() : existing;

  /// Polls [probe] (FirebaseMessaging.getAPNSToken) until it returns a token or
  /// [maxWait] has passed. iOS hands out an FCM token only after the APNs token
  /// has arrived; asking earlier throws `apns-token-not-set`.
  static Future<bool> waitForApns(
    Future<String?> Function() probe, {
    Duration maxWait = const Duration(seconds: 10),
    Duration step = const Duration(milliseconds: 500),
  }) async {
    final Stopwatch clock = Stopwatch()..start();
    while (true) {
      try {
        if (isUsable(await probe())) return true;
      } catch (_) {
        // Not available yet; keep polling until the deadline.
      }
      if (clock.elapsed >= maxWait) return false;
      await Future<void>.delayed(step);
    }
  }
}

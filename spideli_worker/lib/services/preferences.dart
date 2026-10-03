import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static const languageKey = "languageKey";
  static const themeKey = "themeKey";
  static const isFinishOnBoardingKey = "isFinishOnBoardingKey";

  static const isClickOnNotification = "isClickOnNotification";

  /// The app never stores the login password (the FirebaseAuth session keeps
  /// the worker signed in). Builds from the shared template saved it under
  /// this key in plain text, so any copy left from one is removed at startup.
  static const _legacyPasswordKey = "password";

  static late SharedPreferences pref;

  static Future<void> initPref() async {
    pref = await SharedPreferences.getInstance();
    await _removeLegacyPassword();
  }

  static Future<void> _removeLegacyPassword() async {
    try {
      if (pref.containsKey(_legacyPasswordKey)) {
        await pref.remove(_legacyPasswordKey);
      }
    } catch (_) {
      // Best effort: never block startup on this cleanup.
    }
  }

  static String getString(String key) {
    return pref.getString(key) ?? "";
  }

  static Future<void> setString(String key, String value) async {
    await pref.setString(key, value);
  }

  static Future<void> clearSharPreference() async {
    await pref.clear();
  }

  static bool getBoolean(String key) {
    return pref.getBool(key) ?? false;
  }

  static Future<void> setBoolean(String key, bool value) async {
    await pref.setBool(key, value);
  }
}

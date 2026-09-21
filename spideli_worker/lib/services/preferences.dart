import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static const languageKey = "languageKey";
  static const themeKey = "themeKey";
  static const isFinishOnBoardingKey = "isFinishOnBoardingKey";

  static const isClickOnNotification = "isClickOnNotification";

  static late SharedPreferences pref;

  static Future<void> initPref() async {
    pref = await SharedPreferences.getInstance();
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

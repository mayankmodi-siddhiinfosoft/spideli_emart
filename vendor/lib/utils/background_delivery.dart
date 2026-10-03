import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notifications for a CLOSED app on phones whose system blocks it.
///
/// On Xiaomi / Redmi / POCO (and Oppo, Realme, Vivo, Huawei, Honor, OnePlus)
/// "Autostart" is off by default: swiping the app away from Recents stops it,
/// and Android then delivers no push until it is opened again. Verified on a
/// Redmi Note 12 (HyperOS, Android 14): received open and in the background,
/// nothing once stopped. Only the user can allow it, so the app explains it
/// once and opens the phone's Autostart screen (native side: MainActivity,
/// channel `spideli/background_delivery`).
class BackgroundDelivery {
  BackgroundDelivery._();

  static const MethodChannel _channel = MethodChannel('spideli/background_delivery');
  static const String _askedAtKey = 'background_delivery_asked_at';
  static const List<String> _brands = ['xiaomi', 'redmi', 'poco', 'oppo', 'realme', 'vivo', 'iqoo', 'huawei', 'honor', 'oneplus'];
  static bool _askedThisRun = false;

  /// Shows the explanation once (on Xiaomi, again at most weekly while
  /// Autostart is still off). Never throws; does nothing on other phones,
  /// on iOS and on the web.
  static Future<void> maybePrompt() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || _askedThisRun) return;
    _askedThisRun = true;
    try {
      final String brand = ((await _channel.invokeMethod<String>('manufacturer')) ?? '').toLowerCase();
      if (!_brands.any(brand.contains)) return;
      final bool? allowed = await _channel.invokeMethod<bool>('autostartAllowed');
      if (allowed == true) return;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int askedAt = prefs.getInt(_askedAtKey) ?? 0;
      final int now = DateTime.now().millisecondsSinceEpoch;
      // Unknown state (not Xiaomi): asked once. Xiaomi with it still off:
      // asked again after a week.
      if (askedAt != 0 && (allowed == null || now - askedAt < const Duration(days: 7).inMilliseconds)) return;
      // Let the screen that called this finish appearing first.
      await Future<void>.delayed(const Duration(seconds: 2));
      if (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) return;
      await prefs.setInt(_askedAtKey, now);
      final String phone = brand.isEmpty ? 'phone' : brand[0].toUpperCase() + brand.substring(1);
      final bool? open = await Get.dialog<bool>(
        AlertDialog(
          title: Text("Allow notifications when the app is closed".tr),
          content: Text(
            "Your @phone phone stops apps from receiving notifications after you close them. Turn on Autostart for this app, and set its battery use to No restrictions, so you never miss an update.".trParams({'phone': phone}),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(result: false), child: Text("Not now".tr)),
            FilledButton(onPressed: () => Get.back(result: true), child: Text("Open settings".tr)),
          ],
        ),
      );
      if (open == true) await _channel.invokeMethod<bool>('openAutostartSettings');
    } catch (e) {
      debugPrint('BackgroundDelivery: $e');
    }
  }
}

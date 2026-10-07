import 'dart:developer';

import 'package:driver/services/dispatch_offer_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads and writes [OfferSeenLog] — when this device first saw each dispatch
/// offer, and whether a dispatch push announced it (D3: the countdown starts
/// at the earliest known moment and survives a restart).
///
/// Opens SharedPreferences itself: the background push isolate never runs
/// `Preferences.initPref`, and the main isolate re-reads ([SharedPreferences.reload])
/// what that isolate wrote while the app was in the background.
abstract final class OfferSeenStore {
  static Future<SharedPreferences> _prefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload();
    } catch (e) {
      log("OfferSeenStore: reload failed: $e");
    }
    return prefs;
  }

  /// The whole log ({} when it cannot be read).
  static Future<Map<String, OfferSeen>> read() async {
    try {
      final SharedPreferences prefs = await _prefs();
      return OfferSeenLog.decode(prefs.getString(OfferSeenLog.prefKey));
    } catch (e) {
      log("OfferSeenStore.read failed: $e");
      return <String, OfferSeen>{};
    }
  }

  /// Records [orderId] as seen at [at] (the earliest time is kept; [push]
  /// marks a dispatch push) and returns the updated log.
  static Future<Map<String, OfferSeen>> record(String orderId, DateTime at, {bool push = false}) async {
    try {
      final SharedPreferences prefs = await _prefs();
      final Map<String, OfferSeen> stored = OfferSeenLog.decode(prefs.getString(OfferSeenLog.prefKey));
      final Map<String, OfferSeen> updated = OfferSeenLog.prune(OfferSeenLog.record(stored, orderId, at, push: push), DateTime.now());
      await prefs.setString(OfferSeenLog.prefKey, OfferSeenLog.encode(updated));
      return updated;
    } catch (e) {
      log("OfferSeenStore.record($orderId) failed: $e");
      return OfferSeenLog.record(const <String, OfferSeen>{}, orderId, at, push: push);
    }
  }

  /// Forgets answered offers.
  static Future<void> forget(Iterable<String> orderIds) async {
    final Set<String> ids = orderIds.toSet();
    if (ids.isEmpty) return;
    try {
      final SharedPreferences prefs = await _prefs();
      final Map<String, OfferSeen> kept = OfferSeenLog.decode(prefs.getString(OfferSeenLog.prefKey))..removeWhere((id, _) => ids.contains(id));
      await prefs.setString(OfferSeenLog.prefKey, OfferSeenLog.encode(kept));
    } catch (e) {
      log("OfferSeenStore.forget failed: $e");
    }
  }
}

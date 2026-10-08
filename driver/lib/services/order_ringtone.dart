// The admin's order ring sound (`settings/globalSettings.order_ringtone_url`)
// as the sound of new-order / new-job notifications.
//
// THIS FILE IS IDENTICAL in customer/lib/service/order_ringtone.dart,
// vendor/lib/utils/order_ringtone.dart and driver/lib/services/order_ringtone.dart
// (and must stay identical: senders and receivers have to agree on every
// name). Pure Dart, no Flutter / Firebase, unit tested in each app
// (test/order_ringtone_test.dart). The rule is in `.claude/PUSH-CHANNELS.md`,
// section "Order ringtone".
//
// Why versioned names: an Android channel's sound is fixed when the channel
// is created, and a deleted channel re-created with the same id gets its old
// settings back, so every ringtone URL gets its own channel id. iOS plays
// `aps.sound` only from the app bundle or `Library/Sounds`, so the converted
// file gets a name of its own too.

import 'dart:convert';

abstract final class OrderRingtone {
  /// Store (vendor) app: new-order channel for the admin sound,
  /// `new_order_rt_<key>`. Without a ringtone: `new_order`.
  static const String storeChannelPrefix = 'new_order_rt_';

  /// Driver app: new / assigned job channel for the admin sound,
  /// `driver_jobs_rt_<key>`. Without a ringtone: `driver_jobs`.
  static const String driverJobChannelPrefix = 'driver_jobs_rt_';

  /// iOS sound file (store and driver), `order_ringtone_<key>.caf`, in the
  /// receiving app's `Library/Sounds`.
  static const String iosSoundPrefix = 'order_ringtone_';
  static const String iosSoundExtension = '.caf';

  /// The URL as compared everywhere: surrounding whitespace removed.
  static String normalize(String? url) => (url ?? '').trim();

  /// True when [url] is an http(s) URL. Anything else (empty, a bare file
  /// name, junk) means "no ringtone": every app then behaves exactly as
  /// before (`new_order` / `driver_jobs` / `spideli`, bundled sounds).
  static bool isConfigured(String? url) {
    final String u = normalize(url).toLowerCase();
    return u.startsWith('https://') || u.startsWith('http://');
  }

  /// 32-bit FNV-1a over the UTF-8 bytes of [text], as 8 lowercase hex
  /// digits. Deterministic in every app and on the server
  /// (JavaScript: `h ^= byte; h = Math.imul(h, 0x01000193) >>> 0`, starting
  /// at `0x811c9dc5`). Written without 64-bit products so it is exact on
  /// every Dart platform.
  static String fnv1a32Hex(String text) {
    int hash = 0x811c9dc5;
    for (final int byte in utf8.encode(text)) {
      hash ^= byte;
      // hash * 0x01000193 (= 2^24 + 403), modulo 2^32.
      hash = (hash * 403 + ((hash << 24) & 0xffffffff)) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Short stable key of [url]: [fnv1a32Hex] of the trimmed URL, or `''`
  /// when no ringtone is configured.
  static String keyFor(String? url) => isConfigured(url) ? fnv1a32Hex(normalize(url)) : '';

  /// True for a key this file produces (8 lowercase hex digits).
  static bool isValidKey(String? key) => RegExp(r'^[0-9a-f]{8}$').hasMatch(key ?? '');

  /// `new_order_rt_<key>`, or null without a ringtone.
  static String? storeChannelIdFor(String? url) => isConfigured(url) ? '$storeChannelPrefix${keyFor(url)}' : null;

  /// `driver_jobs_rt_<key>`, or null without a ringtone.
  static String? driverJobChannelIdFor(String? url) => isConfigured(url) ? '$driverJobChannelPrefix${keyFor(url)}' : null;

  /// `order_ringtone_<key>.caf`, or null without a ringtone.
  static String? iosSoundFor(String? url) => isConfigured(url) ? iosSoundForKey(keyFor(url)) : null;

  static String iosSoundForKey(String key) => '$iosSoundPrefix$key$iosSoundExtension';

  static bool isStoreRingtoneChannel(String? channelId) => (channelId ?? '').trim().startsWith(storeChannelPrefix);

  static bool isDriverJobRingtoneChannel(String? channelId) => (channelId ?? '').trim().startsWith(driverJobChannelPrefix);

  /// True for an iOS sound name this file produces (any key).
  static bool isRingtoneSoundName(String? sound) {
    final String s = (sound ?? '').trim();
    return s.startsWith(iosSoundPrefix) && s.endsWith(iosSoundExtension);
  }

  /// A channel of [prefix] that belongs to another ringtone than
  /// [currentKey] (or to any ringtone, when [currentKey] is empty): the
  /// receiving app deletes it.
  static bool isStaleChannel(String channelId, {required String prefix, required String currentKey}) {
    if (!channelId.startsWith(prefix)) return false;
    return currentKey.isEmpty || channelId != '$prefix$currentKey';
  }

  /// What a receiving app does to keep its notification sound in step with
  /// [url] (the CURRENT `order_ringtone_url`), given the key it prepared
  /// last ([preparedKey]) and whether the file for the current key is
  /// already on the device ([fileReady]).
  ///
  /// - URL unchanged and its file there: nothing to do.
  /// - The file for the current key is there but not recorded (preferences
  ///   cleared): adopt it (channel, record, clean-up), no download.
  /// - URL changed (or never prepared): prepare the new key; the old key's
  ///   channel and file stay until the new ones are ready ([RingtonePlan.keep]).
  /// - No ringtone any more: clear (in the foreground always, so channels
  ///   left by an earlier run go too; in the background only when something
  ///   was prepared).
  static RingtonePlan plan({required String? url, required String? preparedKey, required bool fileReady, bool foreground = true}) {
    final String? prepared = isValidKey(preparedKey) ? preparedKey : null;
    if (!isConfigured(url)) {
      return (foreground || prepared != null) ? const RingtonePlan(RingtoneAction.clear) : const RingtonePlan(RingtoneAction.none);
    }
    final String key = keyFor(url);
    if (fileReady) {
      return prepared == key ? RingtonePlan(RingtoneAction.none, key: key) : RingtonePlan(RingtoneAction.adopt, key: key, keep: prepared);
    }
    return RingtonePlan(RingtoneAction.prepare, key: key, keep: prepared);
  }

  /// A background push (Android background isolate / iOS woken app) reads
  /// the settings to catch up with a changed ringtone at most every
  /// [interval] - or always for a `ringtone_changed` push ([forced]).
  static bool shouldCheckInBackground({DateTime? lastCheck, required DateTime now, bool forced = false, Duration interval = const Duration(minutes: 10)}) {
    if (forced || lastCheck == null) return true;
    return now.difference(lastCheck).abs() >= interval;
  }

  /// `data.type` of the optional admin data push that tells stores and
  /// drivers to prepare a changed ringtone now (`.claude/PUSH-CHANNELS.md`).
  static const String changedPushType = 'ringtone_changed';

  /// The key a device may use for its own local notifications: the key it
  /// prepared ([preparedKey], stored once the sound file and channel were
  /// made) when that is the key of the CURRENT [url]; otherwise null, and
  /// the app uses its existing channel and sound.
  static String? usableKey({required String? url, required String? preparedKey}) {
    final String current = keyFor(url);
    if (current.isEmpty || !isValidKey(preparedKey)) return null;
    return preparedKey == current ? current : null;
  }
}

enum RingtoneAction {
  /// Nothing to do: the current ringtone is prepared (or there is none).
  none,

  /// The file for the current key is on the device: create / re-assert its
  /// channel, record it, then remove other ringtones.
  adopt,

  /// Download and prepare the current key, then remove other ringtones.
  prepare,

  /// No ringtone configured: remove every ringtone channel and file.
  clear,
}

/// [OrderRingtone.plan]'s answer.
class RingtonePlan {
  final RingtoneAction action;

  /// The current key (adopt / prepare / none with a ringtone).
  final String? key;

  /// The previously prepared key, kept until [key] is ready.
  final String? keep;

  const RingtonePlan(this.action, {this.key, this.keep});

  @override
  bool operator ==(Object other) => other is RingtonePlan && other.action == action && other.key == key && other.keep == keep;

  @override
  int get hashCode => Object.hash(action, key, keep);

  @override
  String toString() => 'RingtonePlan($action, key: $key, keep: $keep)';
}

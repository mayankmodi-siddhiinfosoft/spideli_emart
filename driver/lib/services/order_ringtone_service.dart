import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/services/order_ringtone.dart';
import 'package:driver/utils/preferences.dart';

/// The admin's order sound as this device prepared it for notifications.
class PreparedOrderRingtone {
  /// [OrderRingtone.keyFor] of the URL it was made from.
  final String key;

  /// Android: `content://<applicationId>.order_ringtone/...` (the channel's
  /// sound). Empty on iOS.
  final String androidSoundUri;

  const PreparedOrderRingtone({required this.key, required this.androidSoundUri});

  /// Android channel `driver_jobs_rt_<key>`.
  String get jobChannelId => '${OrderRingtone.driverJobChannelPrefix}$key';

  /// iOS `Library/Sounds/order_ringtone_<key>.caf`.
  String get iosSound => OrderRingtone.iosSoundForKey(key);
}

/// Prepares `globalSettings.order_ringtone_url` (the sound the in-app alert
/// loops) as the sound of new / assigned job and dispatch-offer
/// notifications (`.claude/PUSH-CHANNELS.md`, "Order ringtone"), and keeps
/// it in step when the admin changes it:
///
/// - a live listener on `settings/globalSettings` while the app runs, a
///   re-check on every return to the foreground, and a bounded catch-up from
///   the FCM background handler ([catchUpInBackground]);
/// - [OrderRingtone.plan] decides: nothing (unchanged), adopt a file already
///   on the device, prepare a new key, or clear;
/// - preparing: download (bounded in size and time); Android: the file is
///   stored under `files/order_ringtones/` and served by
///   `OrderRingtoneProvider` (`MainActivity` / `OrderRingtone.kt`), and the
///   channel `driver_jobs_rt_<key>` is created with it; iOS: [AppDelegate]
///   converts it to Linear PCM `.caf` (< 30 s) in
///   `Library/Sounds/order_ringtone_<key>.caf`;
/// - the previous key's channel and file are removed only after the new one
///   is ready.
///
/// Any failure keeps today's behaviour: `driver_jobs` / `spideli` and the
/// default tone. Nothing here throws.
class OrderRingtoneService {
  OrderRingtoneService._();

  static const MethodChannel _native = MethodChannel('spideli/order_ringtone');

  /// SharedPreferences keys (read from the background isolate too, so
  /// [Preferences] is not used for reading).
  static const String preparedKeyPref = 'orderRingtonePreparedKey';
  static const String androidUriPref = 'orderRingtoneAndroidUri';
  static const String androidDirPref = 'orderRingtoneAndroidDir';
  static const String androidAuthorityPref = 'orderRingtoneAndroidAuthority';
  static const String lastBackgroundCheckPref = 'orderRingtoneBackgroundCheckMs';

  /// `<files>/order_ringtones` (`res/xml/order_ringtone_paths.xml`).
  static const String androidPathName = 'order_ringtones';

  /// Download bounds.
  static const int maxBytes = 10 * 1024 * 1024;
  static const Duration downloadTimeout = Duration(seconds: 30);

  /// A failed download of the same URL is retried at most this often.
  static const Duration retryAfter = Duration(minutes: 2);

  // ── Reading the prepared sound (any isolate) ──

  /// The prepared ringtone for the CURRENT URL (`Preferences.orderRingtone`,
  /// kept current by [start]), or null: then the existing `driver_jobs` /
  /// `spideli` channels and the default tone are used.
  static Future<PreparedOrderRingtone?> current() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      // The background isolate keeps its own cache; the main isolate writes.
      await prefs.reload();
      final String? key = OrderRingtone.usableKey(url: prefs.getString(Preferences.orderRingtone), preparedKey: prefs.getString(preparedKeyPref));
      if (key == null) return null;
      final String uri = prefs.getString(androidUriPref) ?? '';
      if (Platform.isAndroid && !uri.startsWith('content://')) return null;
      return PreparedOrderRingtone(key: key, androidSoundUri: Platform.isAndroid ? uri : '');
    } catch (e) {
      log('order ringtone: reading the prepared sound failed: $e');
      return null;
    }
  }

  // ── Keeping it prepared ──

  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _settingsSub;
  static AppLifecycleListener? _lifecycle;
  static Future<void>? _running;
  static ({String url, bool background})? _queued;
  static final Map<String, DateTime> _failedAt = <String, DateTime>{};

  /// Starts keeping the sound in step with the settings: now, on every change
  /// of `globalSettings.order_ringtone_url` (live listener while the app
  /// runs: senders, the in-app alert and the notification sound switch
  /// without a restart), and on every return to the foreground. Idempotent.
  static void start() {
    _lifecycle ??= AppLifecycleListener(onResume: () => unawaited(sync(Constant.orderRingtoneUrl)));
    _settingsSub ??= FireStoreUtils.fireStore.collection(CollectionName.settings).doc('globalSettings').snapshots().listen(
      (DocumentSnapshot<Map<String, dynamic>> snap) {
        if (!snap.exists) return;
        final String url = (snap.data()?['order_ringtone_url'] ?? '').toString();
        if (url != Constant.orderRingtoneUrl) {
          // Senders and the in-app alert use the new sound from now on.
          Constant.orderRingtoneUrl = url;
          unawaited(Preferences.setString(Preferences.orderRingtone, url));
          unawaited(AudioPlayerService.refreshSource());
        }
        unawaited(sync(url));
      },
      onError: (Object e) => log('order ringtone: globalSettings listener failed: $e'),
    );
    unawaited(sync(Constant.orderRingtoneUrl));
  }

  /// From the FCM background handler (Android: its own isolate; iOS: the
  /// woken app): reads `order_ringtone_url` (bounded) at most every 10
  /// minutes - always for a `ringtone_changed` push ([forced]) - and
  /// prepares a changed ringtone, so the NEXT push rings with it. The push
  /// being handled is not shown again (the system already showed it).
  static Future<void> catchUpInBackground({bool forced = false}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final int? lastMs = prefs.getInt(lastBackgroundCheckPref);
      final DateTime now = DateTime.now();
      if (!OrderRingtone.shouldCheckInBackground(lastCheck: lastMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastMs), now: now, forced: forced)) return;
      await prefs.setInt(lastBackgroundCheckPref, now.millisecondsSinceEpoch);
      final DocumentSnapshot<Map<String, dynamic>> snap = await FireStoreUtils.fireStore.collection(CollectionName.settings).doc('globalSettings').get().timeout(const Duration(seconds: 8));
      if (!snap.exists) return;
      final String url = (snap.data()?['order_ringtone_url'] ?? '').toString();
      if (url != (prefs.getString(Preferences.orderRingtone) ?? '')) {
        await prefs.setString(Preferences.orderRingtone, url);
        Constant.orderRingtoneUrl = url;
      }
      await sync(url, background: true).timeout(const Duration(seconds: 20));
    } catch (e) {
      log('order ringtone: background catch-up failed: $e');
    }
  }

  /// Prepares [url] (or clears everything when no ringtone is configured).
  /// One run at a time; a call during a run is done after it.
  static Future<void> sync(String? url, {bool background = false}) {
    final Future<void>? running = _running;
    if (running != null) {
      _queued = (url: url ?? '', background: background);
      return running;
    }
    final Future<void> run = _sync(url, background: background).whenComplete(() {
      _running = null;
      final ({String url, bool background})? next = _queued;
      _queued = null;
      if (next != null) unawaited(sync(next.url, background: next.background));
    });
    _running = run;
    return run;
  }

  static bool get _inForeground {
    final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  /// Android, from the background isolate: the native channel only exists in
  /// the foreground engine, so files are handled here with the paths the
  /// foreground recorded.
  static bool _dartFiles(bool background) => Platform.isAndroid && background;

  static Future<void> _sync(String? url, {required bool background}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    // In the main isolate this runs only in the foreground (a return to the
    // foreground runs it again); the background handler asks explicitly.
    if (!background && !_inForeground) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (Platform.isAndroid && !background) await _recordAndroidPaths(prefs);
      final String key = OrderRingtone.keyFor(url);
      final String? ready = key.isEmpty ? null : await _existing(prefs, key, background);
      final RingtonePlan plan = OrderRingtone.plan(url: url, preparedKey: prefs.getString(preparedKeyPref), fileReady: ready != null, foreground: !background);
      switch (plan.action) {
        case RingtoneAction.none:
          // Unchanged. Re-assert the channel (idempotent) in the foreground.
          if (ready != null && Platform.isAndroid && !background) await _createChannel(key, ready);
          return;
        case RingtoneAction.clear:
          await prefs.remove(preparedKeyPref);
          await prefs.remove(androidUriPref);
          await _deleteStaleChannels('');
          await _clearFiles(prefs, background);
          return;
        case RingtoneAction.adopt:
        case RingtoneAction.prepare:
          String? ref = ready;
          if (plan.action == RingtoneAction.prepare) {
            final DateTime? failed = _failedAt[key];
            if (failed != null && DateTime.now().difference(failed) < retryAfter) return;
            ref = await _downloadAndStore(prefs, OrderRingtone.normalize(url), key, background);
            if (ref == null) {
              // The previous ringtone (if any) stays as it is; pushes for
              // the new key show on `driver_notifications_channel` meanwhile.
              _failedAt[key] = DateTime.now();
              return;
            }
          }
          _failedAt.remove(key);
          if (Platform.isAndroid) {
            await _createChannel(key, ref!);
            await prefs.setString(androidUriPref, ref);
          }
          await prefs.setString(preparedKeyPref, key);
          // Only now that the new one is ready: the old channel and file go.
          await _deleteStaleChannels(key);
          await _pruneFiles(prefs, key, background);
          log('order ringtone $key ready (${plan.action.name}${background ? ', background' : ''})');
      }
    } catch (e) {
      log('order ringtone: preparing failed, the bundled order tone stays: $e');
    }
  }

  static Future<void> _recordAndroidPaths(SharedPreferences prefs) async {
    final Map<Object?, Object?>? paths = await _native.invokeMethod<Map<Object?, Object?>>('paths');
    final String dir = (paths?['dir'] ?? '').toString();
    final String authority = (paths?['authority'] ?? '').toString();
    if (dir.isNotEmpty && authority.isNotEmpty) {
      await prefs.setString(androidDirPref, dir);
      await prefs.setString(androidAuthorityPref, authority);
    }
  }

  static String _fileStem(String key) => '${OrderRingtone.iosSoundPrefix}$key.';

  /// The stored sound for [key]: Android content URI / iOS sound name, or null.
  static Future<String?> _existing(SharedPreferences prefs, String key, bool background) async {
    if (!_dartFiles(background)) return _native.invokeMethod<String>('existing', <String, String>{'key': key});
    final String dir = prefs.getString(androidDirPref) ?? '';
    final String authority = prefs.getString(androidAuthorityPref) ?? '';
    if (dir.isEmpty || authority.isEmpty) return null;
    final Directory folder = Directory(dir);
    if (!folder.existsSync()) return null;
    for (final FileSystemEntity f in folder.listSync()) {
      final String name = f.uri.pathSegments.last;
      if (f is File && name.startsWith(_fileStem(key)) && f.lengthSync() > 0) return 'content://$authority/$androidPathName/$name';
    }
    return null;
  }

  /// Downloads [url] and stores it as this key's sound (Android: the file
  /// itself; iOS: converted by the native side). Returns what [_existing]
  /// returns, or null.
  static Future<String?> _downloadAndStore(SharedPreferences prefs, String url, String key, bool background) async {
    final Directory tmpDir = await getTemporaryDirectory();
    final File tmp = File('${tmpDir.path}/order_ringtone_download_$key');
    final Uri uri = Uri.parse(url);
    try {
      final String? contentType = await _download(uri, tmp);
      if (contentType == null) return null;
      if (Platform.isIOS) {
        return await _native.invokeMethod<String>('install', <String, String>{'path': tmp.path, 'key': key});
      }
      final String dir = prefs.getString(androidDirPref) ?? '';
      if (dir.isEmpty) return null;
      await Directory(dir).create(recursive: true);
      final File incoming = File('$dir/.incoming_$key');
      await tmp.copy(incoming.path);
      await incoming.rename('$dir/${_fileStem(key)}${audioExtension(uri, contentType)}');
      // Foreground: the native side also grants the system UI read access.
      return await _existing(prefs, key, background);
    } catch (e) {
      log('order ringtone: storing the download failed: $e');
      return null;
    } finally {
      try {
        if (tmp.existsSync()) tmp.deleteSync();
      } catch (_) {}
    }
  }

  /// GET [uri] into [into], at most [maxBytes] within [downloadTimeout].
  /// Returns the content type ('' when none), or null on any failure.
  static Future<String?> _download(Uri uri, File into) async {
    final HttpClient client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final HttpClientRequest request = await client.getUrl(uri).timeout(downloadTimeout);
      final HttpClientResponse response = await request.close().timeout(downloadTimeout);
      if (response.statusCode != 200) {
        log('order ringtone: download refused (HTTP ${response.statusCode})');
        return null;
      }
      if (response.contentLength > maxBytes) {
        log('order ringtone: file too large (${response.contentLength} bytes)');
        return null;
      }
      final IOSink sink = into.openWrite();
      int total = 0;
      bool tooLarge = false;
      try {
        await for (final List<int> chunk in response.timeout(downloadTimeout)) {
          total += chunk.length;
          if (total > maxBytes) {
            tooLarge = true;
            break;
          }
          sink.add(chunk);
        }
      } finally {
        await sink.close();
      }
      if (tooLarge || total == 0) {
        log('order ringtone: download rejected (${tooLarge ? 'over $maxBytes bytes' : 'empty'})');
        return null;
      }
      return response.headers.contentType?.mimeType ?? '';
    } catch (e) {
      log('order ringtone: download failed: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> _pruneFiles(SharedPreferences prefs, String keepKey, bool background) async {
    if (!_dartFiles(background)) {
      await _native.invokeMethod<void>('prune', <String, String>{'key': keepKey});
      return;
    }
    _deleteFiles(prefs, (String name) => !name.startsWith(_fileStem(keepKey)));
  }

  static Future<void> _clearFiles(SharedPreferences prefs, bool background) async {
    if (!_dartFiles(background)) {
      await _native.invokeMethod<void>('clear');
      return;
    }
    _deleteFiles(prefs, (_) => true);
  }

  static void _deleteFiles(SharedPreferences prefs, bool Function(String name) which) {
    final String dir = prefs.getString(androidDirPref) ?? '';
    if (dir.isEmpty || !Directory(dir).existsSync()) return;
    for (final FileSystemEntity f in Directory(dir).listSync()) {
      try {
        if (f is File && which(f.uri.pathSegments.last)) f.deleteSync();
      } catch (_) {}
    }
  }

  /// File extension for the downloaded sound (decoders and the content
  /// provider's MIME type go by it): the URL's own, else from the
  /// content type, else `mp3`.
  static String audioExtension(Uri uri, String? contentType) {
    const Set<String> known = {'mp3', 'm4a', 'aac', 'wav', 'ogg', 'oga', 'opus', 'caf', 'aif', 'aiff', 'flac', 'amr', 'mp4', '3gp'};
    final String last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last.toLowerCase();
    final int dot = last.lastIndexOf('.');
    if (dot >= 0 && known.contains(last.substring(dot + 1))) return last.substring(dot + 1);
    final String type = (contentType ?? '').toLowerCase();
    if (type.contains('wav')) return 'wav';
    if (type.contains('ogg')) return 'ogg';
    if (type.contains('mp4') || type.contains('m4a') || type.contains('aac')) return 'm4a';
    if (type.contains('caf')) return 'caf';
    if (type.contains('aiff')) return 'aiff';
    return 'mp3';
  }

  // ── Android channels ──

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      Platform.isAndroid ? FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>() : null;

  /// The `driver_jobs_rt_<key>` channel: the `driver_jobs` channel's name,
  /// description and settings, with the admin's sound.
  static AndroidNotificationChannel channelFor(PreparedOrderRingtone ringtone) => AndroidNotificationChannel(
        ringtone.jobChannelId,
        'New jobs',
        description: 'Loud alert for a new or assigned delivery, ride, parcel or rental job',
        importance: Importance.max,
        playSound: true,
        sound: UriAndroidNotificationSound(ringtone.androidSoundUri),
        enableVibration: true,
        enableLights: true,
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      );

  static Future<void> _createChannel(String key, String contentUri) async {
    await _android?.createNotificationChannel(channelFor(PreparedOrderRingtone(key: key, androidSoundUri: contentUri)));
  }

  /// Deletes `driver_jobs_rt_*` channels of other ringtones (all of them
  /// when [currentKey] is empty). A push that still names one lands on the
  /// manifest default `driver_notifications_channel`.
  static Future<void> _deleteStaleChannels(String currentKey) async {
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android == null) return;
    try {
      final List<AndroidNotificationChannel> channels = await android.getNotificationChannels() ?? const <AndroidNotificationChannel>[];
      for (final AndroidNotificationChannel channel in channels) {
        if (OrderRingtone.isStaleChannel(channel.id, prefix: OrderRingtone.driverJobChannelPrefix, currentKey: currentKey)) {
          await android.deleteNotificationChannel(channelId: channel.id);
        }
      }
    } catch (e) {
      log('order ringtone: removing old channels failed: $e');
    }
  }

  // ── iOS foreground presentation ──

  /// Registers the handler the iOS [AppDelegate] asks, for a push that
  /// arrives in the foreground, whether to present it without its sound
  /// ([decide] returns true while the in-app ring plays the same sound).
  static void handleForegroundPresentation(Future<bool> Function(Map<String, dynamic> data, String apsSound) decide) {
    if (!Platform.isIOS) return;
    _native.setMethodCallHandler((MethodCall call) async {
      if (call.method != 'foregroundPushSilent') return null;
      try {
        final Map<String, dynamic> data = Map<String, dynamic>.from((call.arguments as Map?) ?? const <String, dynamic>{});
        final String apsSound = (data.remove('__apsSound') ?? '').toString();
        return await decide(data, apsSound);
      } catch (e) {
        log('order ringtone: foreground presentation check failed: $e');
        return false;
      }
    });
  }
}

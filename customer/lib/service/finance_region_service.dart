import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/models/region_model.dart';
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/utils/finance_region_rules.dart';
import 'package:customer/utils/preferences.dart';
import 'package:customer/utils/region_service.dart';

/// Spideli Finance follows the customer's region (the admin panel's
/// APP-SPEC-FINANCE-REGION-SETTINGS; the rules are FinanceRegionRules):
///
/// * **The region** is the one the app resolved for the customer
///   ([RegionService]: an explicit choice, else the delivery zone around
///   them, else their country, else `settings/RegionDefaults`), never
///   widened to the rest of the country, as for every amount of money. Only
///   a region with `financeEnabled == true` offers Finance. Where several
///   regions serve the same place, the most specific one is used and the
///   customer may switch ([choose]).
/// * **The settings** are `finance_settings/{regionId}_{module}`
///   ([settings]); a record already made keeps the settings of its own
///   region (`regionId`). Never `platform_settings`.
/// * **Live.** While a Finance dashboard is open ([retain] / [release]),
///   `regions` and the settings documents read so far are listened to:
///   when the admin switches Finance on or off, changes the region's
///   currency or saves a module, [changes] fires and the open screens
///   reload them (FinConfig, [live]).
/// * **Requests** carry their region ([stamp]); before the first one the
///   region joins `users/{uid}.regionIds`, which the security rules check
///   ([require]).
abstract final class FinanceRegion {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Preferences key of the region the customer chose among several.
  static const String choiceKey = 'financeRegionId';

  static int _sessions = 0;
  static final StreamController<void> _changes = StreamController<void>.broadcast();
  static final Map<String, _LiveDoc> _docs = {};
  static final Set<String> _registered = {};

  // `regions`, live while a dashboard is open (financeEnabled can be
  // switched at any time); RegionService's copy (read at start) otherwise.
  static final Map<String, RegionModel> _regions = {};
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _regionsSub;
  static Completer<void>? _regionsFirst;
  static bool _regionsLive = false;
  static FinanceRegionPick? _last;

  /// Fires when the customer's Finance region changes, or one of its
  /// settings documents read so far changes (the admin saved it).
  static Stream<void> get changes => _changes.stream;

  /// The region last resolved (null before the first [current], or when
  /// Finance is not offered).
  static String? get currentId => _last?.regionId;

  /// A Finance dashboard opened: listen to the admin's changes.
  static void retain() {
    _sessions++;
    _listenRegions();
  }

  /// The dashboard closed: the last one stops listening.
  static void release() {
    if (_sessions > 0) _sessions--;
    if (_sessions > 0) return;
    _regionsSub?.cancel();
    _regionsSub = null;
    _regionsFirst = null;
    _regionsLive = false;
    for (final d in _docs.values) {
      d.close();
    }
    _docs.removeWhere((_, d) => d.closed);
  }

  static void _listenRegions() {
    if (_regionsSub != null) return;
    final first = _regionsFirst = Completer<void>();
    _regionsSub = _db.collection('regions').snapshots().listen((s) {
      _regions
        ..clear()
        ..addEntries(s.docs.map((d) => MapEntry(d.id, RegionModel.fromJson(d.data(), docId: d.id))));
      _regionsLive = true;
      if (!first.isCompleted) first.complete();
      _repick();
    }, onError: (Object e) {
      log('finance regions not listened: $e');
      _regionsSub = null;
      _regionsLive = false;
      if (!first.isCompleted) first.complete();
    });
  }

  static RegionModel? _region(String id) => _regionsLive ? _regions[id] : RegionService.regionById(id);

  /// The region offers Finance (published, `financeEnabled`).
  static bool offersFinance(String id) {
    final r = _region(id);
    return r != null && r.publish && r.financeEnabled;
  }

  /// The region's name, for the screens.
  static String nameOf(String id) => _region(id)?.name ?? RegionService.regionById(id)?.name ?? id;

  /// The regions the app resolved for the customer, on the first rung of
  /// RegionService's ladder that found any (never bridged to the country).
  static List<String> _candidates() {
    final String? chosen = RegionService.selectedRegionId;
    if (chosen != null) return [chosen];
    final List<String> zone = RegionService.zoneRegionIds.where((id) => RegionService.regionById(id)?.publish != false).toList();
    if (zone.isNotEmpty) return zone;
    final List<String> country = RegionService.regionIdsForCountry(RegionService.customerCountryCode);
    if (country.isNotEmpty) return country;
    final String? fallback = RegionService.defaultRegionId;
    if (RegionService.isPublished(fallback)) return [fallback!];
    return const [];
  }

  static String? get _remembered {
    try {
      final String v = Preferences.getString(choiceKey);
      return v.isEmpty ? null : v;
    } catch (_) {
      return null;
    }
  }

  static FinanceRegionPick _pick() {
    final lists = RegionService.publishedZoneRegionLists;
    return FinanceRegionRules.pick(
      candidates: _candidates(),
      offersFinance: offersFinance,
      zoneCount: (id) => lists.where((l) => l.contains(id)).length,
      name: nameOf,
      remembered: _remembered,
    );
  }

  /// Recomputes the region (the admin changed `regions`): the screens
  /// reload when it differs.
  static void _repick() {
    final next = _pick();
    final bool changed = _last != null && next != _last;
    _last = next;
    if (changed) _changes.add(null);
  }

  /// The customer's Finance region now.
  static Future<FinanceRegionPick> current() async {
    await RegionService.ensureLoaded();
    // While a dashboard is open, its first answer is today's `regions`, not the copy read at start.
    final first = _regionsFirst;
    if (_sessions > 0 && first != null && !first.isCompleted) await first.future.timeout(const Duration(seconds: 8), onTimeout: () {});
    // The country rung needs the country; nothing waits for it when a zone answers.
    if (RegionService.selectedRegionId == null && RegionService.zoneRegionIds.isEmpty) await RegionService.ensureCustomerCountry();
    final next = _pick();
    final bool changed = _last != null && next != _last;
    _last = next;
    if (changed) _changes.add(null);
    return next;
  }

  /// The region now, then again after every change: the dashboard's gate.
  static Stream<FinanceRegionPick> watch() => live(current);

  /// [load] now, then again after every [changes] (the admin's settings,
  /// the region). Each listener gets its own; a failed load is an error
  /// event, the next change loads again.
  static Stream<T> live<T>(Future<T> Function() load) => Stream<T>.multi((c) {
        Future<void> run() async {
          try {
            final T v = await load();
            if (!c.isClosed) c.add(v);
          } catch (e, s) {
            if (!c.isClosed) c.addError(e, s);
          }
        }

        final sub = changes.listen((_) => run());
        c.onCancel = sub.cancel;
        run();
      });

  /// The customer chose [regionId] among [FinanceRegionPick.choices].
  static Future<void> choose(String regionId) async {
    await Preferences.setString(choiceKey, regionId);
    await current();
  }

  /// The settings of [module] in [regionId] (a record's own region), else
  /// in the customer's Finance region; null when Finance is not offered
  /// there or the admin has not set the module up ("not available yet").
  static Future<Map<String, dynamic>?> settings(String module, {String? regionId}) async {
    final String? id = (regionId ?? '').isNotEmpty ? regionId : (await current()).regionId;
    if (id == null) return null;
    final String docId = FinanceRegionRules.settingsId(id, module);
    final DocumentReference<Map<String, dynamic>> ref = _db.collection(FinanceRegionRules.settingsCollection).doc(docId);
    final Map<String, dynamic>? data = _sessions > 0 ? await _docs.putIfAbsent(docId, () => _LiveDoc(ref, () => _changes.add(null))).read() : (await ref.get()).data();
    return FinanceRegionRules.settingsOf(data, id, module);
  }

  /// The region of a stored record (`regionId`), else the customer's.
  static Future<String?> regionOf(Map<String, dynamic>? record) async => FinanceRegionRules.regionOf(record, (await current()).regionId);

  /// The region a new request is made in: `finance_region_unavailable`
  /// where Finance is not offered. The region joins `users/{uid}.regionIds`
  /// first (once per session), which the security rules require.
  static Future<String> require() async {
    final pick = await current();
    final String? id = pick.regionId;
    if (!pick.isReady || id == null) throw const FinanceException('finance_region_unavailable');
    await register(id);
    return id;
  }

  /// Adds [regionId] to the customer's `users/{uid}.regionIds` (once).
  static Future<void> register(String regionId) async {
    final String uid = FinanceService.uid;
    if (uid.isEmpty) throw const FinanceException('sign_in_required');
    if (_registered.contains('$uid/$regionId')) return;
    try {
      await _db.collection('users').doc(uid).update({
        'regionIds': FieldValue.arrayUnion([regionId]),
      });
    } on FirebaseException catch (e) {
      throw FinanceException(e.code == 'permission-denied' ? 'permission_denied' : (e.code == 'unavailable' ? 'network' : e.code));
    }
    final user = Constant.userModel;
    if (user != null && user.id == uid) user.regionIds = {...?user.regionIds, regionId}.toList();
    _registered.add('$uid/$regionId');
  }

  /// [writes] with [regionId] on the requests and postings they create.
  static List<FinanceWrite> stamp(Iterable<FinanceWrite> writes, String? regionId) => FinanceRegionRules.stamp(writes, regionId);
}

/// One settings document, listened to while a dashboard is open; a read
/// before its first snapshot reads it once (offline: the cache, or the
/// error the screen shows with Retry, never "not available").
class _LiveDoc {
  _LiveDoc(this._ref, this._onChange);

  final DocumentReference<Map<String, dynamic>> _ref;
  final void Function() _onChange;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  bool _has = false;
  Map<String, dynamic>? _data;
  int _reading = 0;
  bool closed = false;

  Future<Map<String, dynamic>?> read() async {
    closed = false;
    _listen();
    if (_has) return _data;
    _reading++;
    try {
      final s = await _ref.get();
      if (!_has) {
        _data = s.data();
        _has = true;
      }
      return _data;
    } finally {
      _reading--;
    }
  }

  void _listen() {
    _sub ??= _ref.snapshots().listen((s) {
      // Offline with nothing cached says nothing about the document.
      if (s.metadata.isFromCache && !s.exists) return;
      final next = s.data();
      final bool changed = _has && !FinanceRegionRules.same(next, _data);
      _data = next;
      _has = true;
      if (changed) _onChange();
    }, onError: (Object e) {
      log('finance settings not listened (${_ref.id}): $e');
      _sub = null;
      _has = false;
    });
  }

  void close() {
    if (_reading > 0) return;
    _sub?.cancel();
    _sub = null;
    _has = false;
    _data = null;
    closed = true;
  }
}

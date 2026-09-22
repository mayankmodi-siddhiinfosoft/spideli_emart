import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/models/section_model.dart';
import 'package:customer/models/service_group_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:get/get.dart';

/// A group of the "More" panel: a heading and its services, in order.
class ServiceGroupView {
  final String id;
  final String title;
  final List<SectionModel> services;

  ServiceGroupView({required this.id, required this.title, required this.services});
}

/// A home banner image, optionally linking to a service.
class HomeBanner {
  final String imageUrl;
  final String? sectionId;

  HomeBanner({required this.imageUrl, this.sectionId});

  /// Accepts a plain image URL (what `settings/AppHomeBanners.banners` holds
  /// today) or a map `{photo|image|url, sectionId}`.
  static HomeBanner? parse(dynamic value) {
    if (value is String) return value.trim().isEmpty ? null : HomeBanner(imageUrl: value.trim());
    if (value is Map) {
      final String url = (value['photo'] ?? value['image'] ?? value['url'] ?? '').toString().trim();
      if (url.isEmpty || value['is_publish'] == false || value['publish'] == false) return null;
      final String sectionId = (value['sectionId'] ?? value['section_id'] ?? '').toString();
      return HomeBanner(imageUrl: url, sectionId: sectionId.isEmpty ? null : sectionId);
    }
    return null;
  }

  static List<HomeBanner> parseList(dynamic value) => value is List ? value.map(parse).whereType<HomeBanner>().toList() : <HomeBanner>[];
}

/// Everything the circular home (spec 7.1) and the "More" panel (spec 7.2 /
/// 18.11) need beyond the region-filtered `sections` list.
///
/// Rules implemented here, in this order:
/// 1. Region filter first (done by the caller through `RegionService`), then
///    grouping.
/// 2. `service_groups` ordered by `order`, `publish == false` dropped; a
///    service goes under its `sections.serviceGroup` group; services inside a
///    group keep the section `order`.
/// 3. A service with no group, or pointing at a deleted / unpublished group, is
///    UNGROUPED and is shown under "Others" (blocking question 19.1 #3): merged
///    into the published group whose id is `others` when there is one (the
///    seeded id), else in a trailing "Others" group.
/// 4. A group with no services is hidden.
class HomeServices {
  HomeServices._();

  static const int favouriteCount = 8;
  static const String othersGroupId = 'others';

  static FirebaseFirestore get _db => FireStoreUtils.fireStore;

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Published service groups, ordered by `order`. Empty on error / no data.
  static Future<List<ServiceGroupModel>> loadGroups() async {
    try {
      final snap = await _db.collection(CollectionName.serviceGroups).get();
      final groups = snap.docs.map((d) => ServiceGroupModel.fromJson(d.data(), docId: d.id)).where((g) => g.publish).toList();
      groups.sort((a, b) => a.order.compareTo(b.order));
      return groups;
    } catch (e) {
      log("service_groups not loaded: $e");
      return [];
    }
  }

  /// Optional admin list of favourites: `settings/homeFavorites.sectionIds`
  /// = `{ regions: { <regionId>: [ids] }, default: [ids] }`. Null when absent.
  static Future<Map<String, dynamic>?> loadFavouritesConfig() async {
    try {
      final doc = await _db.collection(CollectionName.settings).doc('homeFavorites').get();
      final dynamic ids = doc.data()?['sectionIds'];
      return ids is Map ? Map<String, dynamic>.from(ids) : null;
    } catch (e) {
      log("homeFavorites not loaded: $e");
      return null;
    }
  }

  /// Home banners from `settings/AppHomeBanners` (the app's existing home
  /// banner document): `banners` = top carousel (as before); optional
  /// `lowerBanners` = the banners under the circle (first one full width, the
  /// rest in a grid). Each area is hidden when its list is empty.
  static Future<({List<HomeBanner> top, List<HomeBanner> lower})> loadBanners() async {
    try {
      final doc = await _db.collection(CollectionName.settings).doc('AppHomeBanners').get();
      final data = doc.data() ?? const <String, dynamic>{};
      return (top: HomeBanner.parseList(data['banners']), lower: HomeBanner.parseList(data['lowerBanners']));
    } catch (e) {
      log("AppHomeBanners not loaded: $e");
      return (top: <HomeBanner>[], lower: <HomeBanner>[]);
    }
  }

  // ---------------------------------------------------------------------------
  // Favourites
  // ---------------------------------------------------------------------------

  /// The (up to) 8 services on the home circle, chosen from [available]
  /// (already region-filtered, ordered by the section `order`).
  ///
  /// The ONLY place favourites are decided: an admin-configured list
  /// ([config], see [loadFavouritesConfig]) for the first of [customerRegions]
  /// that has one, else its `default` list; ids not available here are
  /// skipped. Without a usable configured list: the first 8 available services
  /// by section `order`.
  static List<SectionModel> favourites(List<SectionModel> available, {List<String> customerRegions = const [], Map<String, dynamic>? config}) {
    // Region list first, then the admin's `default` list, then section order.
    final Map<String, SectionModel> byId = {for (final s in available) if (s.id != null) s.id!: s};
    for (final configured in _configuredLists(config, customerRegions)) {
      final List<SectionModel> picked = [];
      for (final id in configured) {
        final SectionModel? s = byId[id];
        if (s != null && !picked.contains(s)) picked.add(s);
        if (picked.length == favouriteCount) break;
      }
      if (picked.isNotEmpty) return picked;
    }
    return _byOrder(available).take(favouriteCount).toList();
  }

  static List<List<String>> _configuredLists(Map<String, dynamic>? config, List<String> customerRegions) {
    if (config == null) return const [];
    final List<List<String>> lists = [];
    final dynamic regions = config['regions'];
    if (regions is Map) {
      for (final regionId in customerRegions) {
        final dynamic ids = regions[regionId];
        if (ids is List && ids.isNotEmpty) {
          lists.add(ids.map((e) => e.toString()).toList());
          break;
        }
      }
    }
    final dynamic fallback = config['default'];
    if (fallback is List && fallback.isNotEmpty) lists.add(fallback.map((e) => e.toString()).toList());
    return lists;
  }

  // ---------------------------------------------------------------------------
  // Grouping
  // ---------------------------------------------------------------------------

  /// Groups [available] (already region-filtered) by `serviceGroup` under the
  /// published [groups]; see the class comment for the rules.
  static List<ServiceGroupView> group(List<SectionModel> available, List<ServiceGroupModel> groups) {
    final List<SectionModel> ordered = _byOrder(available);
    final Map<String, ServiceGroupModel> byId = {for (final g in groups) g.id: g};
    final Map<String, List<SectionModel>> members = {for (final g in groups) g.id: <SectionModel>[]};
    final List<SectionModel> ungrouped = [];
    for (final s in ordered) {
      final String groupId = (s.serviceGroup ?? '').trim();
      if (groupId.isNotEmpty && byId.containsKey(groupId)) {
        members[groupId]!.add(s);
      } else {
        ungrouped.add(s);
      }
    }

    final List<ServiceGroupView> result = [];
    bool ungroupedPlaced = false;
    for (final g in groups) {
      List<SectionModel> services = members[g.id]!;
      if (g.id == othersGroupId && ungrouped.isNotEmpty) {
        services = _byOrder([...services, ...ungrouped]);
        ungroupedPlaced = true;
      }
      if (services.isEmpty) continue;
      result.add(ServiceGroupView(id: g.id, title: g.name.isEmpty ? 'Others'.tr : g.name, services: services));
    }
    if (!ungroupedPlaced && ungrouped.isNotEmpty) {
      result.add(ServiceGroupView(id: othersGroupId, title: 'Others'.tr, services: ungrouped));
    }
    return result;
  }

  /// Stable sort by the section `order`; services without one keep their
  /// place after those with one (the query already orders by `order`).
  static List<SectionModel> _byOrder(List<SectionModel> sections) {
    final indexed = sections.asMap().entries.toList();
    indexed.sort((a, b) {
      final num? oa = a.value.order;
      final num? ob = b.value.order;
      if (oa != null && ob != null && oa != ob) return oa.compareTo(ob);
      if (oa == null && ob != null) return 1;
      if (oa != null && ob == null) return -1;
      return a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList();
  }

  /// Case-insensitive name filter used by the panel search bar.
  static bool matches(SectionModel section, String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return (section.name ?? '').toLowerCase().contains(q) || (section.name ?? '').tr.toLowerCase().contains(q);
  }
}

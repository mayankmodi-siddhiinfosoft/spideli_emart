import 'package:cloud_firestore/cloud_firestore.dart';

class ZoneModel {
  List<GeoPoint>? area;
  bool? publish;
  double? latitude;
  String? name;
  String? id;
  String? sectionId;
  double? longitude;

  /// Region this delivery zone belongs to (optional).
  String? regionId;

  /// Every region the zone serves. The admin panel can attach one zone to
  /// several regions (e.g. a "Worldwide" zone); `regionId` is only the first.
  List<String>? regionIds;

  ZoneModel({this.area, this.publish, this.latitude, this.name, this.id, this.longitude,this.sectionId, this.regionId, this.regionIds});

  ZoneModel.fromJson(Map<String, dynamic> json) {
    if (json['area'] != null) {
      area = <GeoPoint>[];
      json['area'].forEach((v) {
        area!.add(v);
      });
    }

    publish = json['publish'];
    latitude = json['latitude'];
    name = json['name'];
    id = json['id'];
    longitude = json['longitude'];
    sectionId = json['sectionId'];
    final dynamic region = json['regionId'];
    regionId = (region == null || region.toString().isEmpty) ? null : region.toString();
    final dynamic regions = json['regionIds'];
    regionIds = regions is List ? regions.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (area != null) {
      data['area'] = area!.map((v) => v).toList();
    }
    data['publish'] = publish;
    data['latitude'] = latitude;
    data['name'] = name;
    data['id'] = id;
    data['longitude'] = longitude;
    data['sectionId'] = sectionId;
    if (regionIds != null) {
      data['regionIds'] = regionIds;
    }
    if (regionId != null) {
      data['regionId'] = regionId;
    }
    return data;
  }

  /// Whether the zone can be chosen for a store in [region]. A zone with no
  /// region data serves every region (the platform rule for anything
  /// region-scoped: empty means everywhere).
  bool belongsToRegion(String region) {
    final ids = regionIds ?? const <String>[];
    if (ids.isEmpty && (regionId == null || regionId!.isEmpty)) return true;
    return regionId == region || ids.contains(region);
  }
}

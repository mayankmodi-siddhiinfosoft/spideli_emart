import 'package:cloud_firestore/cloud_firestore.dart';

class ZoneModel {
  List<GeoPoint>? area;
  bool? publish;
  double? latitude;
  String? name;
  String? id;
  double? longitude;

  /// Deprecated by the admin panel: first entry of [regionIds] only.
  String? regionId;

  /// Every region this delivery zone serves (the truth). A zone can serve
  /// several regions; see `RegionService.regionOfZone`.
  List<String>? regionIds;

  ZoneModel({this.area, this.publish, this.latitude, this.name, this.id, this.longitude, this.regionId, this.regionIds});

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
    final dynamic region = json['regionId'];
    regionId = (region == null || region.toString().isEmpty) ? null : region.toString();
    final dynamic regions = json['regionIds'];
    regionIds = regions is List ? regions.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList() : null;
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
    if (regionIds != null) data['regionIds'] = regionIds;
    if (regionId != null) data['regionId'] = regionId;
    return data;
  }
}

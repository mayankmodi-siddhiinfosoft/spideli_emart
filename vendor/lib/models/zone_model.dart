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

  ZoneModel({this.area, this.publish, this.latitude, this.name, this.id, this.longitude,this.sectionId, this.regionId});

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
    if (regionId != null) {
      data['regionId'] = regionId;
    }
    return data;
  }
}

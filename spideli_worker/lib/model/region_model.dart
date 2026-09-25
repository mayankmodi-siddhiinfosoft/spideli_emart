/// A row of the `regions` collection (management zone), managed from the
/// admin panel: `{ name, code, currencyId }`.
///
/// Parsing is tolerant: every field is optional and extra fields are ignored.
class RegionModel {
  String? id;
  String? name;

  /// Free-text label the admin chose (Gabon reads "GB"). Display only:
  /// **never match a country on it** - use [countryCode].
  String? code;

  /// ISO country code of the region (admin spec 1). The only field a country
  /// may be matched on.
  String? countryCode;
  String? currencyId;

  /// Delivery zones the admin attached to this region.
  List<String> zoneIds;

  /// Only an explicit `publish: false` hides a region from lists.
  bool publish;

  RegionModel({this.id, this.name, this.code, this.countryCode, this.currencyId, this.zoneIds = const [], this.publish = true});

  RegionModel.fromJson(Map<String, dynamic> json, {String? docId})
    : zoneIds = _idList(json['zoneIds']),
      publish = json['publish'] != false {
    id = (json['id']?.toString().isNotEmpty == true) ? json['id'].toString() : docId;
    name = json['name']?.toString();
    code = json['code']?.toString();
    countryCode = json['countryCode']?.toString();
    currencyId = json['currencyId']?.toString();
  }

  static List<String> _idList(dynamic value) {
    if (value is Iterable) return value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
    return const [];
  }

  /// True when this region is in [countryCode] (case-insensitive). Always
  /// false when either side is empty - never falls back to [code].
  bool isInCountry(String? value) {
    final String a = (countryCode ?? '').trim().toUpperCase();
    final String b = (value ?? '').trim().toUpperCase();
    return a.isNotEmpty && a == b;
  }

  /// "Name (CODE)" when a code exists.
  String get displayName {
    final String label = (name == null || name!.isEmpty) ? (id ?? '') : name!;
    return (code == null || code!.isEmpty) ? label : "$label ($code)";
  }
}

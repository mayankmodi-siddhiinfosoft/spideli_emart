/// A row of the `regions` collection (management zone), managed from the
/// admin panel: `{ name, code, currencyId }`.
///
/// Parsing is tolerant: every field is optional and extra fields are ignored.
class RegionModel {
  String? id;
  String? name;
  String? code;
  String? currencyId;

  RegionModel({this.id, this.name, this.code, this.currencyId});

  RegionModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    id = (json['id']?.toString().isNotEmpty == true) ? json['id'].toString() : docId;
    name = json['name']?.toString();
    code = json['code']?.toString();
    currencyId = json['currencyId']?.toString();
  }

  /// Label for pickers: "Name (CODE)" when a code exists.
  String get displayName {
    final String label = (name == null || name!.isEmpty) ? (id ?? '') : name!;
    return (code == null || code!.isEmpty) ? label : "$label ($code)";
  }

  @override
  bool operator ==(Object other) => other is RegionModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

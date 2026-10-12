double? _num(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final String s = v.toString().trim();
  if (s.isEmpty) return null;
  return double.tryParse(s.replaceAll(',', ''));
}

class ParcelWeightModel {
  String? deliveryCharge;
  String? id;
  String? title;
  double? minKg;
  double? maxKg;

  ParcelWeightModel({this.deliveryCharge, this.id, this.title, this.minKg, this.maxKg});

  ParcelWeightModel.fromJson(Map<String, dynamic> json) {
    deliveryCharge = json['delivery_charge']?.toString();
    id = json['id']?.toString();
    title = json['title']?.toString();
    minKg = _num(json['minKg'] ?? json['min_kg']);
    maxKg = _num(json['maxKg'] ?? json['max_kg']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['delivery_charge'] = deliveryCharge;
    data['id'] = id;
    data['title'] = title;
    if (minKg != null) data['minKg'] = minKg;
    if (maxKg != null) data['maxKg'] = maxKg;
    return data;
  }
}

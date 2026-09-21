class CarMakes {
  String? name;
  String? id;
  bool? isActive;

  CarMakes({this.name, this.id, this.isActive});

  CarMakes.fromJson(Map<String, dynamic> json) {
    name = json['name'] ?? '';
    id = json['id'] ?? '';
    isActive = json['isActive'] ?? false;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['id'] = id;
    data['isActive'] = isActive;
    return data;
  }
}

class CarModel {
  String? name;
  String? carMakeName;
  String? id;
  bool? isActive;
  String? carMakeId;

  CarModel({this.name, this.carMakeName, this.id, this.isActive, this.carMakeId});

  CarModel.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    carMakeName = json['car_make_name'];
    id = json['id'];
    isActive = json['isActive'];
    carMakeId = json['car_make_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['car_make_name'] = carMakeName;
    data['id'] = id;
    data['isActive'] = isActive;
    data['car_make_id'] = carMakeId;
    return data;
  }
}

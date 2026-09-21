import 'package:vendor/models/permission_model.dart';

class EmployeeRoleModel {
  String? id;
  String? title;
  List<PermissionModel>? permissions;
  String? vendorId;
  bool? isEnable;

  EmployeeRoleModel({
    this.id,
    this.title,
    this.permissions,
    this.vendorId,
    this.isEnable,
  });

  factory EmployeeRoleModel.fromJson(Map<String, dynamic> json) {
    return EmployeeRoleModel(
      id: json['id'],
      title: json['title'],
      permissions: json['permissions'] != null ? (json['permissions'] as List).map((e) => PermissionModel.fromJson(e)).toList() : null,
      vendorId: json['vendorId'],
      isEnable: json['isEnable'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'permissions': permissions?.map((e) => e.toJson()).toList(),
      'vendorId': vendorId,
      'isEnable': isEnable,
    };
  }
}

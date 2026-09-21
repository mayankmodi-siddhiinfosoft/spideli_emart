class PermissionModel {
  String? title;
  bool? isActive;

  PermissionModel({
    required this.title,
    this.isActive,
  });

  factory PermissionModel.fromJson(Map<String, dynamic> json) {
    return PermissionModel(
      title: json['title'] ?? '',
      isActive: json['isActive'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (isActive != null) 'isActive': isActive,
    };
  }
}

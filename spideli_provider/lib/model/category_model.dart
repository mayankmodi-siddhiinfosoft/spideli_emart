class CategoryModel {
  String? id;
  String? title;
  String? image;
  String? parentCategoryId;
  bool? publish;

  CategoryModel({
    this.id,
    this.title,
    this.image,
    this.parentCategoryId,
    this.publish,
  });

  CategoryModel.fromJson(Map<String, dynamic> json) {
    id = json['id'] ?? '';
    title = json['title'] ?? '';
    image = json['image'] ?? '';
    parentCategoryId = json['parentCategoryId'] ?? '';
    publish = json['publish'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    data['parentCategoryId'] = parentCategoryId;
    data['image'] = image;
    data['publish'] = publish;
    return data;
  }
}

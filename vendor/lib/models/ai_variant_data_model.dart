
import 'package:vendor/models/product_model.dart';

class AIVariationDataModel {
  String? status;
  int? code;
  String? message;
  AIVariationData? data;

  AIVariationDataModel({this.status, this.code, this.message, this.data});

  AIVariationDataModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    code = json['code'];
    message = json['message'];
    data = json['data'] != null ? AIVariationData.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['code'] = code;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class AIVariationData {
  String? categoryId;
  String? categoryName;
  bool? isNonveg;
  ItemAttribute? itemAttribute;

  AIVariationData({this.categoryId, this.categoryName, this.isNonveg, this.itemAttribute});

  AIVariationData.fromJson(Map<String, dynamic> json) {
    categoryId = json['category_id'];
    categoryName = json['category_name'];
    isNonveg = json['is_nonveg'];
    itemAttribute = json['item_attribute'] != null
        ? ItemAttribute.fromJson(json['item_attribute'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['category_id'] = categoryId;
    data['category_name'] = categoryName;
    data['is_nonveg'] = isNonveg;
    if (itemAttribute != null) {
      data['item_attribute'] = itemAttribute!.toJson();
    }
    return data;
  }
}

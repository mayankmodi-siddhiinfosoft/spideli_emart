import 'package:get/get.dart';

/// A heading of the "More" services panel (spec 6.11 / 18.11), from the
/// admin-managed `service_groups` collection. The id is what
/// `sections.serviceGroup` stores; the name is what customers see and may be
/// changed by the client at any time, so it is never hardcoded in the app.
class ServiceGroupModel {
  String id;
  String name;
  num order;
  bool publish;

  ServiceGroupModel({required this.id, required this.name, required this.order, required this.publish});

  factory ServiceGroupModel.fromJson(Map<String, dynamic> json, {required String docId}) {
    final dynamic rawOrder = json['order'];
    return ServiceGroupModel(
      id: (json['id']?.toString().isNotEmpty == true) ? json['id'].toString() : docId,
      name: _localizedName(json['name']),
      order: rawOrder is num ? rawOrder : (num.tryParse(rawOrder?.toString() ?? '') ?? 0),
      // Only an explicit false hides a group.
      publish: json['publish'] != false,
    );
  }

  /// `name` is a plain string today; a per-language map (`{en: .., fr: ..}`)
  /// is accepted too (spec 6.11 "label per language").
  static String _localizedName(dynamic value) {
    if (value is Map) {
      final String lang = Get.locale?.languageCode ?? 'en';
      final dynamic picked = value[lang] ?? value['en'] ?? (value.values.isNotEmpty ? value.values.first : null);
      return picked?.toString() ?? '';
    }
    return value?.toString() ?? '';
  }
}

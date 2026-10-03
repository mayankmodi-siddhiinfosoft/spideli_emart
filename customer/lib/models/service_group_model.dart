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
      return decodeHtmlEntities(picked?.toString() ?? '');
    }
    return decodeHtmlEntities(value?.toString() ?? '');
  }

  /// The panel saves names HTML-escaped ("Online Shopping &amp; Restaurant");
  /// shown as typed. Handles the named entities a name can contain and
  /// numeric ones (&#39; / &#x27;).
  static String decodeHtmlEntities(String text) {
    if (!text.contains('&')) return text;
    const Map<String, String> named = {'&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&apos;': "'", '&nbsp;': ' '};
    return text.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);'), (m) {
      final String entity = m.group(0)!;
      final String body = m.group(1)!;
      if (body.startsWith('#x') || body.startsWith('#X')) {
        final int? code = int.tryParse(body.substring(2), radix: 16);
        return code == null ? entity : String.fromCharCode(code);
      }
      if (body.startsWith('#')) {
        final int? code = int.tryParse(body.substring(1));
        return code == null ? entity : String.fromCharCode(code);
      }
      return named[entity.toLowerCase()] ?? entity;
    });
  }
}

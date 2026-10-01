/// A row of `delivery_carriers` — admin spec §11 ("Carriers / delivery
/// companies"), client point 18.
///
/// The admin panel owns this document; the driver app only reads it and may
/// edit the commercial settings a carrier maintains itself. Every field is read
/// tolerantly (the panel has written more than one spelling over time) and
/// written back under **the key the document already uses**, so saving from the
/// app never creates a second spelling of a field the panel reads.
///
/// The verification flag is deliberately absent from [editableFields]: only the
/// admin may verify a carrier.
class DeliveryCarrierModel {
  /// Document id in `delivery_carriers`.
  final String id;

  /// The document exactly as stored, so a save only touches known fields.
  final Map<String, dynamic> raw;

  DeliveryCarrierModel({required this.id, required this.raw});

  /// Field → the spellings accepted when reading, most canonical first.
  static const Map<String, List<String>> fieldKeys = {
    'name': ['name', 'title', 'carrierName', 'companyName'],
    'contactName': ['contactName', 'contactPerson', 'contact'],
    'phone': ['phone', 'phoneNumber', 'contactPhone', 'mobile'],
    'email': ['email', 'contactEmail'],
    'rates': ['rates', 'rate', 'deliveryRate', 'pricePerKg', 'price'],
    'maxWeight': ['maxWeight', 'maximumWeight', 'max_weight', 'weightLimit'],
    'deliveryTimes': ['deliveryTimes', 'deliveryTime', 'delivery_times', 'deliveryDuration'],
    'conditions': ['conditions', 'terms', 'conditionsOfCarriage', 'notes'],
  };

  /// The fields a carrier may maintain from the app. `isVerified` / `verified`
  /// and anything else the panel owns are never written.
  static const List<String> editableFields = ['name', 'contactName', 'phone', 'email', 'rates', 'maxWeight', 'deliveryTimes', 'conditions'];

  String value(String field) {
    for (final key in fieldKeys[field] ?? const <String>[]) {
      final dynamic v = raw[key];
      if (v == null) continue;
      final String text = v.toString().trim();
      if (text.isEmpty || text == 'null') continue;
      return text;
    }
    return '';
  }

  /// The key a save must write [field] to: the one already in the document,
  /// else the canonical name.
  String writeKey(String field) {
    final List<String> keys = fieldKeys[field] ?? const <String>[];
    for (final key in keys) {
      if (raw.containsKey(key)) return key;
    }
    return keys.isEmpty ? field : keys.first;
  }

  /// True when the admin marked this carrier verified. Read only.
  bool get isVerified {
    for (final key in const ['isVerified', 'verified', 'isVerify', 'verification']) {
      final dynamic v = raw[key];
      if (v is bool) return v;
      if (v != null && v.toString().toLowerCase() == 'true') return true;
    }
    return false;
  }
}

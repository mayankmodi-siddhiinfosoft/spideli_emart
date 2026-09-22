import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/region_service.dart';

/// One saved method in `users/{uid}.savedPaymentMethods`.
class SavedPaymentMethod {
  static const String typeMobileMoney = "mobile_money";
  static const String typeWave = "wave";

  /// Mobile Money operators offered in the form ("Other" = free text).
  static const List<String> operators = ["Orange Money", "MTN Mobile Money", "Moov Money", "Airtel Money", "Other"];

  String id;
  String type;
  String? operator;
  String number;
  String? label;
  bool isDefault;

  /// Additive: the customer region the method was saved in. Methods are only
  /// offered in that region (null = every region).
  String? regionId;

  SavedPaymentMethod({required this.id, required this.type, this.operator, required this.number, this.label, this.isDefault = false, this.regionId});

  factory SavedPaymentMethod.fromJson(Map<String, dynamic> json) => SavedPaymentMethod(
    id: json['id']?.toString() ?? '',
    type: json['type']?.toString() ?? typeMobileMoney,
    operator: json['operator']?.toString(),
    number: json['number']?.toString() ?? '',
    label: json['label']?.toString(),
    isDefault: json['isDefault'] == true,
    regionId: (json['regionId'] == null || json['regionId'].toString().isEmpty) ? null : json['regionId'].toString(),
  );

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{'id': id, 'type': type, 'number': number, 'isDefault': isDefault};
    if (type == typeMobileMoney && (operator ?? '').isNotEmpty) data['operator'] = operator;
    if ((label ?? '').isNotEmpty) data['label'] = label;
    if (regionId != null) data['regionId'] = regionId;
    return data;
  }

  String get title => type == typeWave ? "Wave" : (operator ?? "Mobile Money");

  bool usableIn(String? region) => regionId == null || region == null || regionId == region;
}

/// Saved Mobile Money numbers and Wave accounts (spec 3.4 / 7.8).
///
/// Cards are deliberately NOT stored: card data must never be kept by the
/// app; tokenisation is the gateway's job and needs a server-side
/// integration that does not exist yet.
///
/// Writes only the `savedPaymentMethods` field of the user document.
class SavedPaymentMethods {
  SavedPaymentMethods._();

  static List<SavedPaymentMethod> _parse(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => SavedPaymentMethod.fromJson(Map<String, dynamic>.from(e))).where((m) => m.number.isNotEmpty).toList();
  }

  /// Everything saved (read fresh from Firestore).
  static Future<List<SavedPaymentMethod>> load() async {
    final doc = await FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).get();
    final list = _parse(doc.data()?['savedPaymentMethods']);
    Constant.userModel?.savedPaymentMethods = list.map((e) => e.toJson()).toList();
    return list;
  }

  static Future<void> _save(List<SavedPaymentMethod> list) async {
    // Exactly one default when anything is saved.
    if (list.isNotEmpty && !list.any((m) => m.isDefault)) list.first.isDefault = true;
    final data = list.map((e) => e.toJson()).toList();
    await FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).update({'savedPaymentMethods': data});
    Constant.userModel?.savedPaymentMethods = data;
  }

  static Future<void> add(SavedPaymentMethod method) async {
    final list = await load();
    if (method.isDefault) {
      for (final m in list) {
        m.isDefault = false;
      }
    }
    list.add(method);
    await _save(list);
  }

  static Future<void> setDefault(String id) async {
    final list = await load();
    for (final m in list) {
      m.isDefault = m.id == id;
    }
    await _save(list);
  }

  static Future<void> remove(String id) async {
    final list = await load();
    list.removeWhere((m) => m.id == id);
    await _save(list);
  }

  /// Methods usable in [regionId] (default: the customer's current region).
  static List<SavedPaymentMethod> usable({String? regionId}) {
    final region = regionId ?? RegionService.customerRegionId;
    return _parse(Constant.userModel?.savedPaymentMethods).where((m) => m.usableIn(region)).toList();
  }

  /// Phone number to prefill in a gateway that takes one (Flutterwave mobile
  /// money, Razorpay contact): the default saved method usable in
  /// [regionId], else the first usable one, else [fallback].
  static String? checkoutPhone({String? regionId, String? fallback}) {
    final list = usable(regionId: regionId);
    if (list.isEmpty) return fallback;
    final m = list.firstWhere((e) => e.isDefault, orElse: () => list.first);
    return m.number;
  }
}

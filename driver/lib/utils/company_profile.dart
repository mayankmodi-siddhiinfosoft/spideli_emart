import 'package:driver/models/user_model.dart';
import 'package:driver/models/zone_model.dart';

/// A delivery company's own details on its `users` document (report Doc 38),
/// under the exact keys the admin panel's Company details card reads.
class CompanyProfile {
  CompanyProfile._();

  /// The reference numbers, in the panel's order.
  static const List<String> numberFields = ['commercialRegister', 'operatingLicence', 'uniqueIdNumber'];

  /// The three documents: `<number field>File`, each a Firebase Storage URL.
  static const List<String> fileFields = ['commercialRegisterFile', 'operatingLicenceFile', 'uniqueIdNumberFile'];

  /// Translation keys of the labels, per field.
  static const Map<String, String> labels = {
    'companyName': 'Company Name',
    'companyAddress': 'Company Address',
    'commercialRegister': 'Commercial Register',
    'operatingLicence': 'Operating Licence',
    'uniqueIdNumber': 'Unique Identification Number',
    'commercialRegisterFile': 'Commercial register',
    'operatingLicenceFile': 'Operating licence',
    'uniqueIdNumberFile': 'Unique identification number',
  };

  /// Trimmed text, or null when there is nothing (so the field is not written).
  static String? text(String? value) {
    final String trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// The stored value of a company field on [user] ('' when absent).
  static String valueOf(UserModel user, String field) {
    switch (field) {
      case 'companyName':
        return user.companyName ?? '';
      case 'companyAddress':
        return user.companyAddress ?? '';
      case 'commercialRegister':
        return user.commercialRegister ?? '';
      case 'operatingLicence':
        return user.operatingLicence ?? '';
      case 'uniqueIdNumber':
        return user.uniqueIdNumber ?? '';
      case 'commercialRegisterFile':
        return user.commercialRegisterFile ?? '';
      case 'operatingLicenceFile':
        return user.operatingLicenceFile ?? '';
      case 'uniqueIdNumberFile':
        return user.uniqueIdNumberFile ?? '';
    }
    return '';
  }

  /// Writes [value] (trimmed, null when blank) into a company field of [user].
  static void setValue(UserModel user, String field, String? value) {
    final String? v = text(value);
    switch (field) {
      case 'companyName':
        user.companyName = v;
        break;
      case 'companyAddress':
        user.companyAddress = v;
        break;
      case 'commercialRegister':
        user.commercialRegister = v;
        break;
      case 'operatingLicence':
        user.operatingLicence = v;
        break;
      case 'uniqueIdNumber':
        user.uniqueIdNumber = v;
        break;
      case 'commercialRegisterFile':
        user.commercialRegisterFile = v;
        break;
      case 'operatingLicenceFile':
        user.operatingLicenceFile = v;
        break;
      case 'uniqueIdNumberFile':
        user.uniqueIdNumberFile = v;
        break;
    }
  }

  /// The file fields with nothing picked / stored, in [fileFields] order.
  static List<String> missingFiles(Map<String, String?> files) =>
      fileFields.where((field) => (files[field] ?? '').trim().isEmpty).toList();

  /// The URL to open, exactly as stored. A Firebase Storage download URL is
  /// already encoded (`%2F` in the path, a `token` query): encoding it again
  /// breaks the token, so it is only parsed, never re-encoded. Null when it is
  /// not an http(s) URL.
  static Uri? fileUri(String? url) {
    final String value = (url ?? '').trim();
    if (value.isEmpty) return null;
    final Uri? uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) return null;
    return uri;
  }

  static const Set<String> _imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic', '.heif', '.bmp'};

  /// True when the stored file is an image (previewed in the app); anything
  /// else — a PDF, or a name without an extension — is opened outside the
  /// app. Decided on the DECODED path, so a Storage URL
  /// `…/o/driverDocument%2Fx%2Ffile.jpg?alt=media&token=…` counts.
  static bool isImage(String? url) {
    final Uri? uri = fileUri(url);
    if (uri == null) return false;
    String path;
    try {
      path = Uri.decodeComponent(uri.path);
    } catch (_) {
      path = uri.path;
    }
    path = path.toLowerCase();
    return _imageExtensions.any(path.endsWith);
  }
}

/// The zones a delivery company serves (report Doc 43, app half).
///
/// Stored on the company's `users` document as `zoneIds` (list). `zoneId`
/// stays the FIRST of them so every existing reader of the single field keeps
/// working. A fleet driver still has one `zoneId`, chosen from these.
class CompanyZones {
  CompanyZones._();

  /// Trimmed, non-empty and de-duplicated, in the order given.
  static List<String> normalize(Iterable<String?> ids) {
    final List<String> out = [];
    for (final String? id in ids) {
      final String value = (id ?? '').trim();
      if (value.isEmpty || out.contains(value)) continue;
      out.add(value);
    }
    return out;
  }

  /// The `zoneId` kept for older readers: the first zone, or null.
  static String? primary(Iterable<String?> ids) {
    final List<String> list = normalize(ids);
    return list.isEmpty ? null : list.first;
  }

  /// The zones of a company account: `zoneIds`, or its single legacy
  /// `zoneId` when it has no list yet.
  static List<String> of(UserModel? company) {
    if (company == null) return const [];
    final List<String> ids = normalize(company.zoneIds ?? const []);
    if (ids.isNotEmpty) return ids;
    return normalize([company.zoneId]);
  }

  /// The zones a company may give one of its drivers: its own zones when it
  /// has chosen any, otherwise (an older company) every zone of its region —
  /// the rule this screen used before. [allZones] order is kept.
  static List<ZoneModel> forDriverPicker({required List<ZoneModel> allZones, required List<String> companyZoneIds, String? regionId}) {
    final List<String> own = normalize(companyZoneIds);
    if (own.isNotEmpty) {
      return allZones.where((zone) => zone.id != null && own.contains(zone.id)).toList();
    }
    final String region = (regionId ?? '').trim();
    if (region.isEmpty) return allZones.toList();
    return allZones.where((zone) => zone.belongsToRegion(region)).toList();
  }
}

import 'dart:developer';

import 'package:customer/constant/collection_name.dart';
import 'package:customer/service/fire_store_utils.dart';

/// Point 54 (BUG-REPORT-01-APP.md section 4, app-spec-parcel-sms.md): the
/// sender may opt in, at parcel checkout, for the receiver to be told by SMS
/// that a parcel was sent to them, for `regions/{regionId}.parcelSmsFee` of
/// the sender's region.
///
/// The app only RECORDS the choice on `parcel_orders` (`receiverName`,
/// `receiverPhone`, `receiverCountryCode`, `sendReceiverSms`, `smsCharge`,
/// `smsOptOut`). It never composes a message and never writes `smsSent`: the
/// server-side trigger on `parcel_orders` sends the SMS with the wording of
/// `settings/SMSGateway.templates` for the events in `eventsEnabled`, and
/// keeps `smsSent` so each message goes once.
class ParcelReceiverSms {
  ParcelReceiverSms._();

  /// The fee when the sender's region has no `parcelSmsFee` (or the region is
  /// unknown / unreadable).
  static const double defaultParcelSmsFee = 50;

  /// `parcelSmsFee` of a `regions/{regionId}` document (a number or a numeric
  /// string; 0 means free); [defaultParcelSmsFee] when the region, the field or
  /// a readable value is missing, never negative.
  static double feeFrom(Map<String, dynamic>? region) {
    final dynamic raw = region?['parcelSmsFee'];
    final double? fee = raw is num ? raw.toDouble() : double.tryParse(raw?.toString().trim().replaceAll(',', '.') ?? '');
    if (fee == null || !fee.isFinite || fee < 0) return defaultParcelSmsFee;
    return fee;
  }

  /// What parcel checkout offers, read fresh (the fee is money): whether a
  /// receiver SMS can be sent at all (`settings/SMSGateway.isEnabled`) and its
  /// fee for the sender's region [regionId]. A gateway that cannot be read is
  /// "off" (nothing offered, nothing charged).
  static Future<({bool enabled, double fee})> offer({String? regionId}) async {
    bool enabled = false;
    try {
      final snap = await FireStoreUtils.fireStore.collection(CollectionName.settings).doc('SMSGateway').get();
      enabled = snap.data()?['isEnabled'] == true;
    } catch (e) {
      log('ParcelReceiverSms: settings/SMSGateway not read ($e) - receiver SMS not offered');
    }
    Map<String, dynamic>? region;
    final String id = (regionId ?? '').trim();
    if (id.isNotEmpty) {
      try {
        region = (await FireStoreUtils.fireStore.collection(CollectionName.regions).doc(id).get()).data();
      } catch (e) {
        log('ParcelReceiverSms: regions/$id not read ($e) - default SMS fee used');
      }
    }
    return (enabled: enabled, fee: feeFrom(region));
  }

  // ── the receiver's number ─────────────────────────────────────────────

  static String _digits(String? value) => (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');

  /// The dialling code the phone field's country picker wrote ("+237",
  /// "237", " +1 ", "+1876"), as `+<digits>`: 1 to 3 digits, or the picker's
  /// 4-digit North American codes (+1 and the area code, e.g. +1876 Jamaica,
  /// +1242 Bahamas), which are kept whole so an edit screen preselects the
  /// right country. Null when it is empty or not a dialling code (an ISO
  /// code such as "CM", or too many digits).
  static String? dialCode(String? raw) {
    final String value = (raw ?? '').trim().replaceAll(' ', '');
    final RegExpMatch? m = RegExp(r'^\+?(\d{1,3}|1\d{3})$').firstMatch(value);
    return m == null ? null : '+${m.group(1)}';
  }

  /// Dialling codes whose national numbers really begin with 0, even after
  /// the country code (no trunk prefix to drop): Italy (landlines, 06...),
  /// San Marino, Vatican City, Cote d'Ivoire (07..., 10 digits since 2021),
  /// Benin (01..., since 2024), Gabon (06 / 07...) and Congo-Brazzaville
  /// (06 / 05 / 04...).
  static const Set<String> leadingZeroKept = {'+39', '+378', '+379', '+225', '+229', '+241', '+242'};

  /// The national number as stored in `receiverPhone`: digits only, no
  /// country code. Where a dialled number drops its trunk 0 after the country
  /// code ("0677 12 34 56" -> "677123456"), the leading zeros are removed;
  /// for a [leadingZeroKept] country ([countryCode]) the digits stay as
  /// typed ("+242" "06 123 4567" -> "061234567").
  static String nationalNumber(String? raw, {String? countryCode}) {
    final String digits = _digits(raw);
    if (leadingZeroKept.contains(dialCode(countryCode))) return digits;
    return digits.replaceFirst(RegExp(r'^0+'), '');
  }

  /// Shortest national number accepted.
  static const int minNationalDigits = 6;

  /// E.164: country code and national number together.
  static const int maxTotalDigits = 15;

  /// Why the receiver's number cannot be used, as a translation key; null when
  /// it can. The country code is required: an SMS needs it and it cannot be
  /// worked out later (app-spec-parcel-sms.md, message format trap 3).
  static String? validationError({required String? countryCode, required String? mobile}) {
    final String national = nationalNumber(mobile, countryCode: countryCode);
    if (national.isEmpty) return 'Please enter receiver mobile';
    final String? code = dialCode(countryCode);
    if (code == null) return "Please select the receiver's country code";
    if (national.length < minNationalDigits || code.length - 1 + national.length > maxTotalDigits) return 'Please enter a valid receiver mobile number';
    return null;
  }
}

import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/parcel_order_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:get/get.dart';

/// The receiver of a parcel is not a platform user: no account, no device token,
/// so push cannot reach them (APP-SPEC-ADMIN §17). SMS can, but the apps must
/// never hold the gateway key — so the app only writes a *request* next to the
/// status that triggered it and something server-side sends it.
///
/// One document per message in `parcel_sms_outbox`, written in the same batch as
/// the tracking status, so a message request can never exist for a status change
/// that failed. See `.claude/PARCEL-SMS-OUTBOX.md` for the contract.
class ParcelSmsOutbox {
  ParcelSmsOutbox._();

  /// `source` of every document this app writes.
  static const String source = 'customer_app';

  static const String statePending = 'pending';

  /// Statuses texted when `settings/SMSGateway.parcelEvents` is absent.
  static const List<String> defaultEvents = <String>[
    ParcelShipping.collected,
    ParcelShipping.inTransit,
    ParcelShipping.atDestinationPickupPoint,
    ParcelShipping.outForDelivery,
    ParcelShipping.delivered,
    ParcelShipping.returned,
  ];

  /// Every status a message can be composed for — the values `parcelEvents` may
  /// name. Anything else in that array is ignored.
  static List<String> get supportedEvents => _templates.keys.toList(growable: false);

  /// English message templates; also the translation keys (the `.tr` convention
  /// of both apps). `{tracking}` and `{code}` are substituted here, not by GetX.
  static const Map<String, String> _templates = <String, String>{
    ParcelShipping.created: 'A parcel is on its way to you. Tracking number {tracking}.',
    ParcelShipping.collected: 'Your parcel {tracking} has been collected and is on its way.',
    ParcelShipping.inTransit: 'Your parcel {tracking} is in transit.',
    ParcelShipping.arrivedDestination: 'Your parcel {tracking} has arrived in the destination city.',
    ParcelShipping.atDestinationPickupPoint: 'Your parcel {tracking} is ready for collection at the pickup point.',
    ParcelShipping.outForDelivery: 'Your parcel {tracking} is out for delivery today.',
    ParcelShipping.delivered: 'Your parcel {tracking} has been delivered.',
    ParcelShipping.returned: 'Your parcel {tracking} is on its way back to the sender.',
    ParcelShipping.cancelled: 'Your parcel {tracking} has been cancelled.',
  };

  /// Appended to the pickup-point message when the order carries a pickup code.
  static const String _pickupCodeSuffix = 'Pickup code {code}.';

  // ── settings/SMSGateway ────────────────────────────────────────────────

  static Map<String, dynamic>? _gateway;

  /// Read once per session. A missing document, a read that is refused and a
  /// document without `isEnabled: true` all mean "write nothing".
  static Future<Map<String, dynamic>> _gatewaySettings() async {
    if (_gateway != null) return _gateway!;
    try {
      final snap = await FireStoreUtils.fireStore.collection(CollectionName.settings).doc('SMSGateway').get();
      _gateway = snap.data() ?? const <String, dynamic>{};
    } catch (e) {
      log('ParcelSmsOutbox: SMSGateway not read ($e) — no SMS requests will be written');
      _gateway = const <String, dynamic>{};
    }
    return _gateway!;
  }

  static bool _isEnabled(Map<String, dynamic> gateway) => gateway['isEnabled'] == true;

  static List<String> _events(Map<String, dynamic> gateway) {
    final dynamic configured = gateway['parcelEvents'];
    if (configured is! List) return defaultEvents;
    return configured.map((e) => e.toString().trim()).where((e) => _templates.containsKey(e)).toList();
  }

  // ── phone normalisation ────────────────────────────────────────────────

  /// A receiver number OBITSMS can accept: plain digits, country code first.
  static ParcelSmsNumber? normalise(String? raw, {String? fallbackDialCode}) {
    final String value = (raw ?? '').trim();
    if (value.isEmpty) return null;

    // The platform's own dial code — the only country code an app may assume.
    final String fallback = _digits(fallbackDialCode ?? Constant.defaultCountryCode);
    String code = '';
    String national = '';
    final RegExpMatch? bracketed = RegExp(r'^\(([^)]*)\)(.*)$').firstMatch(value);
    if (bracketed != null) {
      // The booking form writes "(+237) 6 12 34 56 78".
      code = _digits(bracketed.group(1));
      national = _digits(bracketed.group(2));
    } else {
      final String digits = _digits(value);
      if (value.startsWith('+')) {
        // Already E.164: the country code can only be split off when it is ours.
        if (fallback.isEmpty || !digits.startsWith(fallback) || digits.length <= fallback.length) return null;
        code = fallback;
        national = digits.substring(fallback.length);
      } else {
        national = digits;
      }
    }
    if (code.isEmpty) code = fallback;

    national = national.replaceFirst(RegExp(r'^0+'), '');
    if (code.isEmpty || national.isEmpty) return null;
    final String to = '$code$national';
    // E.164: 1-3 digit country code, 15 digits in total.
    if (code.length > 3 || to.length < 8 || to.length > 15) return null;
    return ParcelSmsNumber(to: to, countryCode: code);
  }

  static String _digits(String? value) => (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');

  // ── message ────────────────────────────────────────────────────────────

  static String? _message(ParcelOrderModel order, String status) {
    final String? template = _templates[status];
    if (template == null) return null;
    String text = template.tr;
    if (status == ParcelShipping.atDestinationPickupPoint && (order.pickupCode ?? '').trim().isNotEmpty) {
      text = '$text ${_pickupCodeSuffix.tr}';
    }
    return text.replaceAll('{tracking}', order.trackingNumber ?? '').replaceAll('{code}', (order.pickupCode ?? '').trim()).trim();
  }

  // ── the request ────────────────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> get _outbox => FireStoreUtils.fireStore.collection(CollectionName.parcelSmsOutbox);

  /// One request per order + status: the id is derived from both, so a repeated
  /// status can never queue a second message.
  static String documentId(String orderId, String status) => '${orderId}_${status.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';

  /// The outbox document for [order] moving to [status], or null when nothing is
  /// to be sent (gateway off, status not texted, no usable receiver number, or
  /// this message was queued before). Never throws.
  static Future<ParcelSmsRequest?> requestFor(ParcelOrderModel order, String status) async {
    try {
      final String orderId = (order.id ?? '').trim();
      final String tracking = (order.trackingNumber ?? '').trim();
      // Parcel orders under the tracking contract only.
      if (orderId.isEmpty || tracking.isEmpty) return null;

      final Map<String, dynamic> gateway = await _gatewaySettings();
      if (!_isEnabled(gateway)) return null;
      if (!_events(gateway).contains(status)) return null;

      final String? message = _message(order, status);
      if (message == null || message.isEmpty) return null;

      final ParcelSmsNumber? number = normalise(order.receiver?.phone);
      if (number == null) {
        log('ParcelSmsOutbox: $tracking / $status not queued — the receiver phone cannot be normalised to a country code and digits');
        return null;
      }

      final String id = documentId(orderId, status);
      final DocumentSnapshot<Map<String, dynamic>> existing = await _outbox.doc(id).get();
      if (existing.exists) return null;

      final String? language = Get.locale?.languageCode;
      return ParcelSmsRequest(id, <String, dynamic>{
        'id': id,
        'orderId': orderId,
        'trackingNumber': tracking,
        'parcelStatus': status,
        'to': number.to,
        'countryCode': number.countryCode,
        if (language != null && language.isNotEmpty) 'language': language,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'sendState': statePending,
        'source': source,
      });
    } catch (e) {
      log('ParcelSmsOutbox: request not built ($e)');
      return null;
    }
  }

  /// Queues [request] in the batch that writes the status itself.
  static void addToBatch(WriteBatch batch, ParcelSmsRequest request) => batch.set(_outbox.doc(request.id), request.data);
}

/// A receiver number OBITSMS can dial.
class ParcelSmsNumber {
  final String to;
  final String countryCode;

  const ParcelSmsNumber({required this.to, required this.countryCode});
}

/// A ready outbox document and the id it is written under.
class ParcelSmsRequest {
  final String id;
  final Map<String, dynamic> data;

  const ParcelSmsRequest(this.id, this.data);
}

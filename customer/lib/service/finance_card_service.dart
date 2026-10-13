import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/service/finance_service.dart';
import 'package:customer/utils/finance_card_rules.dart';

/// Virtual cards for the customer app (.claude/FINANCE-APP-CONTRACT.md
/// section 14). Reads the display metadata the server keeps in sync with
/// the issuer; every action is a request to a callable function. Nothing
/// secret is read from or written to Firestore.
abstract final class FinanceCardService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get _uid => FinanceService.uid;

  static Future<CardConfig?> config() async => CardConfig.parse((await _db.collection('platform_settings').doc('cards').get()).data());

  static Stream<List<VirtualCard>> cards() => _db
      .collection('virtual_cards')
      .where('userId', isEqualTo: _uid)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((s) => s.docs.map((d) => VirtualCard.fromMap({...d.data(), 'id': d.id})).toList());

  static Stream<VirtualCard?> card(String id) =>
      _db.collection('virtual_cards').doc(id).snapshots().map((s) => s.data() == null ? null : VirtualCard.fromMap({...s.data()!, 'id': s.id}));

  static Stream<List<Map<String, dynamic>>> _ofCard(String collection, String cardId, int limit) => _db
      .collection(collection)
      .where('userId', isEqualTo: _uid)
      .where('cardId', isEqualTo: cardId)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());

  static Stream<List<Map<String, dynamic>>> transactions(String cardId) => _ofCard('card_transactions', cardId, 50);

  static Stream<List<Map<String, dynamic>>> fundingRequests(String cardId) => _ofCard('card_funding_requests', cardId, 10);

  /// The limits the user set (`card_limit_settings/{cardId}`), or null.
  static Stream<Map<String, dynamic>?> limits(String cardId) => _db.collection('card_limit_settings').doc(cardId).snapshots().map((s) => s.data());

  /// Requests a card under terms [termsVersion]; [payment] pays the issuance fee when there is one.
  static Future<Map<String, dynamic>> create({required String label, required String currency, required int termsVersion, Map<String, dynamic>? payment, required String requestKey}) =>
      FinanceService.call('cardCreate', {
        if (label.isNotEmpty) 'label': label,
        'currency': currency,
        'termsVersion': termsVersion,
        'payment': ?payment,
        'idempotencyKey': requestKey,
      });

  static Future<Map<String, dynamic>> fund(String cardId, int amount, Map<String, dynamic> payment, String requestKey) =>
      FinanceService.call('cardFund', {'cardId': cardId, 'amount': amount, 'payment': payment, 'idempotencyKey': requestKey});

  static Future<Map<String, dynamic>> withdraw(String cardId, int amount, Map<String, dynamic> destination, String requestKey) =>
      FinanceService.call('cardWithdraw', {'cardId': cardId, 'amount': amount, 'destination': destination, 'idempotencyKey': requestKey});

  static Future<void> freeze(String cardId) => FinanceService.call('cardFreeze', {'cardId': cardId});

  static Future<void> unfreeze(String cardId) => FinanceService.call('cardUnfreeze', {'cardId': cardId});

  /// Null limits = the issuer's maximum.
  static Future<void> setLimits(String cardId, CardLimits l, {bool? allowOnline, bool? allowInternational}) => FinanceService.call('cardSetLimits', {
        'cardId': cardId,
        'perTransaction': l.perTransaction,
        'daily': l.daily,
        'monthly': l.monthly,
        'allowOnline': ?allowOnline,
        'allowInternational': ?allowInternational,
      });

  /// A short-lived link to the issuer's secure page showing the card details.
  static Future<Uri> secureDetailsLink(String cardId) async {
    final r = await FinanceService.call('cardSecureDetailsLink', {'cardId': cardId});
    final uri = Uri.parse(r['url'].toString());
    if (uri.scheme != 'https') throw const FormatException('not https');
    return uri;
  }

  /// The card details from the server's PCI-compliant relay. Shown once, never stored or logged.
  static Future<Map<String, dynamic>> revealDetails(String cardId) => FinanceService.call('cardRevealDetails', {'cardId': cardId});

  static Future<Map<String, dynamic>> renew(String cardId, Map<String, dynamic>? payment, String requestKey) =>
      FinanceService.call('cardRenew', {'cardId': cardId, 'payment': ?payment, 'idempotencyKey': requestKey});

  static Future<void> terminate(String cardId) => FinanceService.call('cardTerminate', {'cardId': cardId});
}

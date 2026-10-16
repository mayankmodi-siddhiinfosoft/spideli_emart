import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/service/finance_direct.dart';
import 'package:customer/service/finance_ledger.dart';
import 'package:customer/service/finance_region_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/utils/finance_card_rules.dart';
import 'package:customer/utils/finance_region_rules.dart';

/// Virtual cards for the customer app (.claude/FINANCE-APP-CONTRACT.md
/// section 14, .claude/FINANCE-DIRECT-FIRESTORE.md section 3.5). Reads the
/// display metadata the admin keeps in sync with the issuer; every action is
/// a request written to Firestore (checked by the security rules) that the
/// admin completes with the issuer. Nothing secret is read or written.
abstract final class FinanceCardService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String get _uid => FinanceService.uid;

  /// The cards settings of [regionId] (a card's own region), else of the
  /// customer's Finance region; null when cards are not offered there.
  static Future<CardConfig?> config({String? regionId}) async => CardConfig.parse(await FinanceRegion.settings(FinanceModules.cards, regionId: regionId));

  /// The settings a card follows: those of the region it was requested in.
  static Future<CardConfig?> _configOf(VirtualCard card) => config(regionId: card.regionId.isEmpty ? null : card.regionId);

  /// The region a card's requests are made in: its own.
  static Future<String> _regionOf(VirtualCard card) async => card.regionId.isNotEmpty ? card.regionId : await FinanceRegion.require();

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

  /// The card [cardId] as it is now, when it is the user's and [allowed].
  static Future<VirtualCard> _card(String cardId, bool Function(VirtualCard c) allowed) async {
    final data = await FinanceDirect.get('virtual_cards/$cardId');
    final VirtualCard? c = data == null ? null : VirtualCard.fromMap({...data, 'id': cardId});
    if (c == null || data!['userId'] != _uid || !allowed(c)) throw const FinanceException('card_not_active');
    return c;
  }

  /// Requests a card (`virtual_cards/{requestKey}` `requested`) under terms
  /// [termsVersion], paying the creation fee with [funding] when there is
  /// one. The admin issues it with the issuer. Idempotent on [requestKey].
  static Future<Map<String, dynamic>> create({
    required String label,
    required String currency,
    required int termsVersion,
    required FinanceFunding funding,
    required String requestKey,
  }) async {
    final String regionId = await FinanceRegion.require();
    final cfg = await config(regionId: regionId);
    if (cfg == null || !cfg.currencies.contains(currency)) throw const FinanceException('not_supported');
    if (cfg.termsVersion != termsVersion) throw const FinanceException('terms_outdated');
    final String path = 'virtual_cards/$requestKey';
    final done = await FinanceDirect.existing(path);
    if (done != null) return {'status': 'succeeded', 'reference': done['reference'] ?? ''};
    final List<VirtualCard> mine;
    try {
      mine = (await _db.collection('virtual_cards').where('userId', isEqualTo: _uid).get()).docs.map((d) => VirtualCard.fromMap({...d.data(), 'id': d.id})).toList();
    } on FirebaseException catch (e) {
      throw e.code == 'permission-denied' ? const FinanceException('permission_denied') : e;
    }
    if (!CardActions.canCreate(mine, cfg)) throw const FinanceException('card_limit_reached');
    final int fee = cfg.feeFor(cfg.issuanceFee, currency);
    List<FinanceWrite> writes(FinancePosting? posting) => CardWrites.request(
          cardId: requestKey,
          uid: _uid,
          label: label,
          currency: currency,
          network: cfg.network,
          termsVersion: termsVersion,
          fee: fee,
          feePosting: posting,
          paidWith: posting == null ? null : funding.toMap(),
          reference: FinanceLedger.newReference(),
        );
    if (fee <= 0) {
      await FinanceDirect.commit(FinanceRegion.stamp(writes(null), regionId));
      return {'status': 'succeeded'};
    }
    return FinanceDirect.payPlatform(
      funding: funding,
      type: 'card_fee',
      currency: currency,
      amount: fee,
      sourceKind: 'virtual_cards',
      sourceId: requestKey,
      description: 'Card creation fee',
      existing: () => FinanceDirect.existing(path),
      writes: writes,
      regionId: regionId,
    );
  }

  /// Tops up [cardId] with [amount] (the card receives it; the fee is added
  /// on top): `card_funding_requests/{requestKey}` `pending` with its posting
  /// to the platform. The admin loads the card. Idempotent on [requestKey].
  static Future<Map<String, dynamic>> fund(String cardId, int amount, FinanceFunding funding, String requestKey) async {
    final card = await _card(cardId, CardActions.canFund);
    final cfg = await _configOf(card);
    if (cfg == null) throw const FinanceException('not_supported');
    final String regionId = await _regionOf(card);
    final int? min = cfg.minFunding[card.currency];
    final int? max = cfg.maxFunding[card.currency];
    if ((min != null && amount < min) || (max != null && amount > max)) throw const FinanceException('amount_out_of_range');
    final q = FundingQuote.of(amount, cfg.fundingFeePercent);
    final String path = 'card_funding_requests/$requestKey';
    return FinanceDirect.payPlatform(
      funding: funding,
      type: 'card_funding',
      currency: card.currency,
      amount: q.total,
      sourceKind: 'card_funding_requests',
      sourceId: requestKey,
      description: 'Card top-up',
      regionId: regionId,
      existing: () => FinanceDirect.existing(path),
      writes: (posting) => CardWrites.fund(
        requestId: requestKey,
        uid: _uid,
        cardId: cardId,
        currency: card.currency,
        amount: q.amount,
        fee: q.fee,
        posting: posting,
        paidWith: funding.toMap(),
      ),
    );
  }

  /// The card balance not already promised to a withdrawal or a transfer
  /// still waiting for the admin.
  static Future<int> _available(VirtualCard card) async {
    final QuerySnapshot<Map<String, dynamic>> open;
    try {
      open = await _db.collection('card_funding_requests').where('userId', isEqualTo: _uid).where('cardId', isEqualTo: card.id).get();
    } on FirebaseException catch (e) {
      throw e.code == 'permission-denied' ? const FinanceException('permission_denied') : e;
    }
    return card.balance - CardFunds.promised([for (final d in open.docs) d.data()]);
  }

  /// Asks for [amount] of the card balance back in the wallet (`withdraw`
  /// `pending`; the admin unloads the card and credits the wallet).
  static Future<void> withdraw(String cardId, int amount, String requestKey) async {
    final card0 = await _card(cardId, (_) => true);
    final cfg = await _configOf(card0);
    if (cfg == null || !cfg.canWithdraw) throw const FinanceException('not_supported');
    final card = await _card(cardId, (c) => CardActions.canWithdraw(c, cfg));
    final String regionId = await _regionOf(card);
    final String path = 'card_funding_requests/$requestKey';
    if (await FinanceDirect.existing(path) != null) return;
    if (amount <= 0 || amount > await _available(card)) throw const FinanceException('insufficient_funds');
    await FinanceDirect.commit(FinanceRegion.stamp(
        CardWrites.withdraw(
          requestId: requestKey,
          uid: _uid,
          cardId: cardId,
          currency: card.currency,
          amount: amount,
          reference: FinanceLedger.newReference(),
        ),
        regionId));
  }

  /// The Spideli user with the e-mail or phone number [contact]:
  /// `recipient_not_found`, or `self_transfer` for the user themself.
  static Future<({String id, String name})> findRecipient(String contact) async {
    final q = CardRecipient.query(contact);
    if (q == null) throw const FinanceException('recipient_not_found');
    final QuerySnapshot<Map<String, dynamic>> found;
    try {
      found = await _db.collection('users').where(q.$1, whereIn: q.$2).limit(2).get();
    } on FirebaseException catch (e) {
      throw e.code == 'permission-denied' ? const FinanceException('permission_denied') : e;
    }
    // Two accounts with the same contact: never guess which one.
    if (found.docs.length != 1) throw const FinanceException('recipient_not_found');
    final d = found.docs.single;
    if (d.id == _uid) throw const FinanceException('self_transfer');
    return (id: d.id, name: CardRecipient.displayName(d.data()['firstName']?.toString(), d.data()['lastName']?.toString()));
  }

  /// Sends [amount] of the card balance to the card of [recipientId]
  /// (`transfer` `pending`; the admin moves it at the issuer).
  static Future<void> transfer(String cardId, int amount, {required String recipientId, required String recipientName, required String contact, required String requestKey}) async {
    final card0 = await _card(cardId, (_) => true);
    final cfg = await _configOf(card0);
    if (cfg == null || !cfg.canTransfer) throw const FinanceException('not_supported');
    final card = await _card(cardId, (c) => CardActions.canTransfer(c, cfg));
    final String regionId = await _regionOf(card);
    if (recipientId == _uid) throw const FinanceException('self_transfer');
    final String path = 'card_funding_requests/$requestKey';
    if (await FinanceDirect.existing(path) != null) return;
    if (amount <= 0 || amount > await _available(card)) throw const FinanceException('insufficient_funds');
    await FinanceDirect.commit(FinanceRegion.stamp(CardWrites.transfer(
      requestId: requestKey,
      uid: _uid,
      cardId: cardId,
      currency: card.currency,
      amount: amount,
      recipientId: recipientId,
      recipientName: recipientName,
      recipientContact: contact.trim(),
      reference: FinanceLedger.newReference(),
    ), regionId));
  }

  static Future<void> freeze(String cardId) async {
    await _card(cardId, CardActions.canFreeze);
    await FinanceDirect.commit(CardWrites.freeze(cardId));
  }

  /// Only a card the user froze (re-authenticated first).
  static Future<void> unfreeze(String cardId) async {
    await _card(cardId, CardActions.canUnfreeze);
    await FinanceDirect.commit(CardWrites.unfreeze(cardId));
  }

  /// Null limits = the issuer's maximum (re-authenticated first).
  static Future<void> setLimits(String cardId, CardLimits l, {bool? allowOnline, bool? allowInternational}) async {
    await _card(cardId, CardActions.canSetLimits);
    await FinanceDirect.commit(CardWrites.limits(cardId: cardId, uid: _uid, limits: l, allowOnline: allowOnline, allowInternational: allowInternational));
  }

  /// Showing the full card details needs the issuer's secure page or a
  /// PCI-compliant relay (contract section 14.3): neither is connected, so
  /// the app says so instead of asking for them.
  static bool get detailsAvailable => false;

  /// A short-lived link to the issuer's secure page showing the card details.
  static Future<Uri> secureDetailsLink(String cardId) async => throw const FinanceException('not_supported');

  /// The card details from a PCI-compliant relay. Shown once, never stored or logged.
  static Future<Map<String, dynamic>> revealDetails(String cardId) async => throw const FinanceException('not_supported');

  /// Asks for the renewal of [cardId], paying the renewal fee with
  /// [funding] when there is one. Idempotent: a card already asked for is done.
  static Future<Map<String, dynamic>> renew(String cardId, FinanceFunding funding) async {
    final cfg = await _configOf(await _card(cardId, (_) => true));
    if (cfg == null || !cfg.canRenew) throw const FinanceException('not_supported');
    final String path = 'virtual_cards/$cardId';
    Future<Map<String, dynamic>?> requested() async {
      final data = await FinanceDirect.get(path);
      return data?['renewalRequestedAt'] != null ? {'reference': data!['renewalReference'] ?? ''} : null;
    }

    if (await requested() != null) return {'status': 'succeeded'};
    final card = await _card(cardId, (c) => CardActions.canRenew(c, cfg, DateTime.now()));
    final int fee = cfg.feeFor(cfg.renewalFee, card.currency);
    if (fee <= 0) {
      await FinanceDirect.commit(CardWrites.renew(cardId: cardId, fee: 0));
      return {'status': 'succeeded'};
    }
    return FinanceDirect.payPlatform(
      funding: funding,
      type: 'card_fee',
      currency: card.currency,
      amount: fee,
      sourceKind: 'virtual_cards',
      sourceId: cardId,
      description: 'Card renewal fee',
      regionId: await _regionOf(card),
      existing: requested,
      writes: (posting) => CardWrites.renew(cardId: cardId, fee: fee, feePosting: posting, paidWith: funding.toMap()),
    );
  }

  /// Asks for the card to be closed (re-authenticated first); the admin
  /// returns its balance to the wallet.
  static Future<void> terminate(String cardId) async {
    final card = await _card(cardId, CardActions.canTerminate);
    await FinanceDirect.commit(CardWrites.terminate(card));
  }
}

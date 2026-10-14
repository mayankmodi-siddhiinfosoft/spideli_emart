import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;

/// How a money movement is funded: the user's Spideli Finance wallet, or a
/// payment a gateway has just taken (Stripe, PayPal, Flutterwave, Orange
/// Money…: the app's own gateways, `settings/*`, per region).
class FinanceFunding {
  /// `wallet`, or the gateway key (`stripe`, `paypal`, `flutterwave`…).
  final String method;

  /// The gateway's transaction id (gateway funding only).
  final String? reference;

  const FinanceFunding.wallet()
      : method = 'wallet',
        reference = null;

  const FinanceFunding.gateway(this.method, this.reference);

  bool get isWallet => method == 'wallet';

  /// The `payment_receipts` id of a gateway payment: one posting per payment.
  String? get receiptId => isWallet || (reference ?? '').isEmpty ? null : '${method}_$reference'.replaceAll('/', '_');

  Map<String, dynamic> toMap() => {'method': method, if (reference != null) 'reference': reference};

  @override
  String toString() => isWallet ? 'wallet' : '$method:$reference';
}

/// One write of a batch, as data (testable without Firestore).
class FinanceWrite {
  final String path;

  /// `create` (set of a new document), `update` (fields of an existing one)
  /// or `merge` (set with merge).
  final String op;
  final Map<String, dynamic> data;

  const FinanceWrite(this.path, this.op, this.data);

  @override
  String toString() => '$op $path $data';
}

/// The result of a posting: its transaction id, reference and writes.
class FinancePosting {
  final String txId;
  final String reference;
  final List<FinanceWrite> writes;

  const FinancePosting(this.txId, this.reference, this.writes);
}

/// The money of Spideli Finance (.claude/FINANCE-DIRECT-FIRESTORE.md section 2):
/// accounts in `financial_accounts` and double-entry postings in
/// `ledger_transactions`. Every balance change is a posting of 2 lines
/// (debit -> credit) or 3 (plus a fee credited to the platform account),
/// written in ONE batch with the balance of each account it touches; the
/// security rules check that the lines balance and match the accounts.
abstract final class FinanceLedger {
  static String walletId(String uid, String currency) => 'wallet_${uid}_$currency';
  static String platformId(String currency) => 'platform_$currency';
  static String goalAccountId(String goalId) => 'goal_$goalId';
  static String tontineAccountId(String tontineId) => 'tontine_$tontineId';
  static String loanAccountId(String loanId) => 'loan_$loanId';

  static final Random _random = Random.secure();
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String _code(int n) => List.generate(n, (_) => _alphabet[_random.nextInt(_alphabet.length)]).join();

  /// A ledger transaction id: unique, sortable by time.
  static String newTxId([DateTime? now]) => 'tx_${(now ?? DateTime.now()).millisecondsSinceEpoch}_${_code(8)}';

  /// A reference shown to users and support: `SPF-261014-7K2Q9A`.
  static String newReference([DateTime? now]) {
    final d = now ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'SPF-${two(d.year % 100)}${two(d.month)}${two(d.day)}-${_code(6)}';
  }

  /// The fields of a new account (balance and ledger fields are added by the
  /// posting that creates it).
  static Map<String, dynamic> walletFields(String uid, String currency) => {'kind': 'wallet', 'userId': uid, 'currency': currency};

  static Map<String, dynamic> poolFields(String kind, String refId, String currency, {List<String> memberIds = const []}) =>
      {'kind': kind, 'refId': refId, 'currency': currency, if (memberIds.isNotEmpty) 'memberIds': memberIds};

  /// The writes of a posting of [amount] from [from] to [to], plus [fee]
  /// to the platform account (never on a gateway-funded posting: the
  /// gateway took the fee with the payment). Accounts listed in
  /// [newAccounts] (id -> fields) are created by this posting, which must
  /// then credit them.
  static FinancePosting plan({
    required String type,
    required String currency,
    required String from,
    required String to,
    required int amount,
    int fee = 0,
    Map<String, Map<String, dynamic>> newAccounts = const {},
    required List<String> userIds,
    required String sourceKind,
    required String sourceId,
    required String createdBy,
    FinanceFunding funding = const FinanceFunding.wallet(),
    String description = '',
    String? txId,
    String? reference,
  }) {
    assert(amount > 0, 'a posting moves a positive amount');
    assert(from != to, 'a posting moves money between two accounts');
    final String id = txId ?? newTxId();
    final String ref = reference ?? newReference();
    final String platform = platformId(currency);
    final bool feeLine = fee > 0 && from != platform && to != platform;
    final int debit = amount + (feeLine ? fee : 0);
    final lines = <Map<String, dynamic>>[
      {'accountId': from, 'direction': 'debit', 'amount': debit},
      {'accountId': to, 'direction': 'credit', 'amount': amount},
      if (feeLine) {'accountId': platform, 'direction': 'credit', 'amount': fee},
    ];
    final writes = <FinanceWrite>[
      FinanceWrite('ledger_transactions/$id', 'create', {
        'id': id,
        'type': type,
        'status': 'posted',
        'reference': ref,
        'currency': currency,
        'lines': lines,
        'userIds': userIds.toSet().toList(),
        'accountIds': [for (final l in lines) l['accountId']],
        'source': {'kind': sourceKind, 'id': sourceId},
        'funding': funding.isWallet ? 'wallet' : 'gateway',
        if (!funding.isWallet) 'gateway': funding.toMap(),
        'description': description,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    ];
    for (final l in lines) {
      final String account = l['accountId'] as String;
      final int delta = l['direction'] == 'debit' ? -(l['amount'] as int) : l['amount'] as int;
      final Map<String, dynamic>? create = newAccounts[account];
      if (create != null) {
        assert(delta > 0, 'a new account starts with a credit');
        writes.add(FinanceWrite('financial_accounts/$account', 'create', {
          ...create,
          'id': account,
          'currency': currency,
          'balance': delta,
          'normalSide': 'credit',
          'status': 'active',
          'lastTxId': id,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }));
      } else {
        writes.add(FinanceWrite('financial_accounts/$account', 'update', {
          'balance': FieldValue.increment(delta),
          'lastTxId': id,
          'updatedAt': FieldValue.serverTimestamp(),
        }));
      }
    }
    final String? receipt = funding.receiptId;
    if (receipt != null) {
      writes.add(FinanceWrite('payment_receipts/$receipt', 'create', {
        'method': funding.method,
        'reference': funding.reference,
        'txId': id,
        // What the gateway charged: the amount and any fee.
        'amount': amount + fee,
        'currency': currency,
        'userId': createdBy,
        'verified': false,
        'createdAt': FieldValue.serverTimestamp(),
      }));
    }
    return FinancePosting(id, ref, writes);
  }

  /// Adds [writes] to [batch].
  static void apply(WriteBatch batch, Iterable<FinanceWrite> writes, {FirebaseFirestore? db}) {
    final store = db ?? FirebaseFirestore.instance;
    for (final w in writes) {
      final ref = store.doc(w.path);
      switch (w.op) {
        case 'create':
          batch.set(ref, w.data);
        case 'update':
          batch.update(ref, w.data);
        default:
          batch.set(ref, w.data, SetOptions(merge: true));
      }
    }
  }

  /// The user's wallet in [currency]: an older active wallet of the user in
  /// that currency keeps its id; else `wallet_{uid}_{CUR}` (created by its
  /// first credit). [balance] is 0 for a wallet that does not exist yet.
  static Future<({String id, bool exists, int balance})> wallet(String uid, String currency, {FirebaseFirestore? db}) async {
    final store = db ?? FirebaseFirestore.instance;
    final String standard = walletId(uid, currency);
    final own = await store.collection('financial_accounts').where('userId', isEqualTo: uid).get();
    QueryDocumentSnapshot<Map<String, dynamic>>? found;
    for (final d in own.docs) {
      final m = d.data();
      if (m['currency'] == currency && (m['kind'] ?? 'wallet') == 'wallet' && m['status'] == 'active') {
        if (d.id == standard || found == null) found = d;
      }
    }
    if (found == null) return (id: standard, exists: false, balance: 0);
    return (id: found.id, exists: true, balance: (found.data()['balance'] as num?)?.toInt() ?? 0);
  }

  /// Whether the account [id] exists.
  static Future<bool> exists(String id, {FirebaseFirestore? db}) async => (await (db ?? FirebaseFirestore.instance).doc('financial_accounts/$id').get()).exists;
}
